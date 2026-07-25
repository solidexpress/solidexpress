#pragma once
// 2D parametric sketch: entities + constraints on a 3D plane.
//
// Parameter storage uses a std::deque<double> so parameter addresses are
// stable for the lifetime of the sketch — constraint solvers (PlaneGCS today,
// AI-first backends later) hold raw pointers into it during a solve.

#include <array>
#include <deque>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include <TopoDS_Shape.hxx>

#include "sx/entity.hpp"
#include "sx/ids.hpp"

namespace sx {

enum class SketchEntityType { Point, Line, Circle, Arc, Spline };

// Which point of an entity a constraint references.
enum class PointRole { Self, Start, End, Center };

struct SketchEntity {
    EntityId id;
    SketchEntityType type = SketchEntityType::Point;
    bool construction = false;
    // Associative Convert Entities: locked external geometry from a model edge.
    bool external = false;
    std::string projected_from;  // durable edge id (empty if not projected)
    // Indices into Sketch parameter storage:
    //   Point:  [x, y]
    //   Line:   [x1, y1, x2, y2]
    //   Circle: [cx, cy, r]
    //   Arc:    [cx, cy, r, start_angle, end_angle, sx, sy, ex, ey]
    //   Spline: [n, x0, y0, x1, y1, ...]  n = fit-point count (as double)
    std::vector<size_t> params;
};

enum class ConstraintType {
    Coincident,     // point, point
    Horizontal,     // line
    Vertical,       // line
    Parallel,       // line, line
    Perpendicular,  // line, line
    PointOnLine,    // point, line
    Tangent,        // line-circle, circle-circle, arc-arc, circle-arc
    Equal,          // line,line (length) or circle,circle (radius)
    Distance,       // point, point, value
    Radius,         // circle|arc, value
    Angle,          // line, line, value (radians)
    Midpoint,       // point, line  (point is midpoint of line)
    Symmetric,      // point, point, line  (mirror across line)
    Fix,            // point or line  (lock current coordinates)
    Diameter,       // circle|arc, value (diameter = 2*r presentation)
};

const char* to_string(ConstraintType t);
std::optional<ConstraintType> constraint_type_from_string(const std::string& s);

struct PointRef {
    EntityId entity;
    PointRole role = PointRole::Self;
};

struct SketchConstraint {
    EntityId id;
    ConstraintType type = ConstraintType::Coincident;
    std::vector<PointRef> refs;   // interpretation depends on type
    double value = 0.0;           // for dimensional constraints
    bool driving = true;
    // Optional expression (e.g. "=w/2"); resolved against VariableTable before solve.
    std::string expr;
    // Locked coordinate snapshot for Fix (point: x,y; line: x1,y1,x2,y2).
    std::vector<double> locked;
};

// Plane the sketch lives on (kernel/model space, Z-up world).
struct SketchPlane {
    std::array<double, 3> origin{0, 0, 0};
    std::array<double, 3> x_dir{1, 0, 0};
    std::array<double, 3> y_dir{0, 1, 0};
    std::array<double, 3> normal() const;  // x_dir cross y_dir
};

// Sketch analysis diagnostics (open loops, gaps, etc.).
struct SketchIssue {
    std::string code;     // "open_loop" | "gap" | "zero_length" | "self_intersect"
    std::string message;
    std::vector<EntityId> entities;
};

class Sketch {
public:
    explicit Sketch(std::string name = "Sketch", SketchPlane plane = {});

    const EntityId& id() const { return id_; }
    const std::string& name() const { return name_; }
    const SketchPlane& plane() const { return plane_; }

    // --- entities ---
    EntityId add_point(double x, double y);
    EntityId add_line(double x1, double y1, double x2, double y2);
    EntityId add_circle(double cx, double cy, double r);
    // Arc counter-clockwise from start_angle to end_angle (radians).
    EntityId add_arc(double cx, double cy, double r, double start_angle, double end_angle);
    // Fit-point spline (n >= 2). Stored as B-spline for profile/path output.
    EntityId add_spline(const std::vector<std::array<double, 2>>& fit_points);
    bool remove_entity(const EntityId& id);  // drops dependent constraints too
    void set_construction(const EntityId& id, bool construction);
    bool is_construction(const EntityId& id) const;
    void set_external(const EntityId& id, bool external, const std::string& projected_from = "");
    bool is_external(const EntityId& id) const;

    const SketchEntity* entity(const EntityId& id) const;
    SketchEntity* entity_mut(const EntityId& id);
    const std::vector<SketchEntity>& entities() const { return entities_; }

    // --- constraints ---
    EntityId add_constraint(ConstraintType type, std::vector<PointRef> refs,
                            double value = 0.0, bool driving = true);
    bool remove_constraint(const EntityId& id);
    const std::vector<SketchConstraint>& constraints() const { return constraints_; }
    SketchConstraint* constraint_mut(const EntityId& id);
    // Update a dimension value (does not re-solve). Clears expr unless keep_expr.
    bool set_constraint_value(const EntityId& id, double value);
    bool set_constraint_expr(const EntityId& id, const std::string& expr);
    bool set_constraint_driving(const EntityId& id, bool driving);

    // Resolve constraint expressions against env; writes numeric value.
    // Returns false if any expression fails.
    bool resolve_expressions(const std::map<std::string, double>& env, std::string* err = nullptr);

    // --- parameter access ---
    double param(size_t index) const { return params_[index]; }
    double& param_mut(size_t index) { return params_[index]; }
    size_t param_count() const { return params_.size(); }

    // Convenience: current 2D coordinates of a referenced point.
    std::optional<std::array<double, 2>> point_pos(const PointRef& ref) const;

    // Fit points of a spline entity (empty if not a spline).
    std::vector<std::array<double, 2>> spline_fit_points(const EntityId& id) const;

    // --- geometry output ---
    // Builds a planar face from the closed profile formed by all
    // non-construction entities (single circle, or a loop of lines/arcs/splines).
    // Returns a null shape if no closed profile exists.
    TopoDS_Shape profile_face(std::string* err = nullptr) const;

    // Diagnostics for open profiles / gaps / zero-length.
    std::vector<SketchIssue> analyze(double gap_tol = 1e-4) const;

    // Auto-constrain: add H/V, origin anchors, and minimal driving dims toward DOF=0.
    // Returns number of constraints added. Caller must re-solve.
    int fully_define();

    // Project a model-space edge (as 3D endpoints or circle) onto the sketch plane
    // as a line/circle entity marked external.
    EntityId project_line_edge(const std::array<double, 3>& a,
                               const std::array<double, 3>& b,
                               const std::string& edge_id);
    EntityId project_circle_edge(const std::array<double, 3>& center,
                                 double radius,
                                 const std::string& edge_id);

    // Update external entity geometry from new 3D edge data (associative regen).
    bool update_projected_line(const EntityId& id, const std::array<double, 3>& a,
                               const std::array<double, 3>& b);
    bool update_projected_circle(const EntityId& id, const std::array<double, 3>& center,
                                 double radius);
    // Mark projected_from empty entities still external as dangling (construction).
    int mark_dangling_external(const std::vector<std::string>& live_edge_ids);

    uint64_t revision() const { return revision_; }

private:
    friend class PlaneGCSBackend;
    friend struct SketchSerde;  // JSON persistence (sketch_json.cpp)
    size_t push_params(std::initializer_list<double> values);
    std::array<double, 2> to_sketch_uv(const std::array<double, 3>& p) const;

    EntityId id_;
    std::string name_;
    SketchPlane plane_;
    std::deque<double> params_;  // stable addresses
    std::vector<SketchEntity> entities_;
    std::vector<SketchConstraint> constraints_;
    uint64_t revision_ = 0;
};

}  // namespace sx
