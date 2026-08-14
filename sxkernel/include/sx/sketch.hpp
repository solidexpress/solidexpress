#pragma once
// 2D parametric sketch: entities + constraints on a 3D plane.
//
// Parameter storage uses a std::deque<double> so parameter addresses are
// stable for the lifetime of the sketch — constraint solvers (PlaneGCS today,
// AI-first backends later) hold raw pointers into it during a solve.

#include <deque>
#include <optional>
#include <string>
#include <vector>

#include <TopoDS_Shape.hxx>

#include "sx/entity.hpp"
#include "sx/ids.hpp"

namespace sx {

enum class SketchEntityType { Point, Line, Circle, Arc };

// Which point of an entity a constraint references.
enum class PointRole { Self, Start, End, Center };

struct SketchEntity {
    EntityId id;
    SketchEntityType type = SketchEntityType::Point;
    bool construction = false;
    // Indices into Sketch parameter storage:
    //   Point:  [x, y]
    //   Line:   [x1, y1, x2, y2]
    //   Circle: [cx, cy, r]
    //   Arc:    [cx, cy, r, start_angle, end_angle, sx, sy, ex, ey]
    std::vector<size_t> params;
};

enum class ConstraintType {
    Coincident,     // point, point
    Horizontal,     // line
    Vertical,       // line
    Parallel,       // line, line
    Perpendicular,  // line, line
    PointOnLine,    // point, line
    Tangent,        // line, circle
    Equal,          // line,line (length) or circle,circle (radius)
    Distance,       // point, point, value
    Radius,         // circle|arc, value
    Angle,          // line, line, value (radians)
    Concentric,     // circle|arc, circle|arc (centers coincident)
    Symmetric,      // point, point, line (mirror about line)
    Midpoint,       // point, line
    Fix,            // point (lock x,y)
    Collinear,      // line, line (or three points)
};

const char* to_string(ConstraintType t);

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
    bool weak = false;  // Creo-style: yields when a strong dim conflicts / Relax
};

// Plane the sketch lives on (kernel/model space, Z-up world).
struct SketchPlane {
    std::array<double, 3> origin{0, 0, 0};
    std::array<double, 3> x_dir{1, 0, 0};
    std::array<double, 3> y_dir{0, 1, 0};
    std::array<double, 3> normal() const;  // x_dir cross y_dir
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
    bool remove_entity(const EntityId& id);  // drops dependent constraints too
    void set_construction(const EntityId& id, bool construction);
    bool is_construction(const EntityId& id) const;

    const SketchEntity* entity(const EntityId& id) const;
    const std::vector<SketchEntity>& entities() const { return entities_; }

    // --- constraints ---
    EntityId add_constraint(ConstraintType type, std::vector<PointRef> refs,
                            double value = 0.0);
    bool remove_constraint(const EntityId& id);
    const std::vector<SketchConstraint>& constraints() const { return constraints_; }
    // Update a dimension value (does not re-solve).
    bool set_constraint_value(const EntityId& id, double value);
    bool set_constraint_weak(const EntityId& id, bool weak);
    // Drop every weak constraint (Inventor Relax / conflict yield).
    int drop_weak_constraints();

    // --- parameter access ---
    double param(size_t index) const { return params_[index]; }
    double& param_mut(size_t index) { return params_[index]; }
    size_t param_count() const { return params_.size(); }

    // Convenience: current 2D coordinates of a referenced point.
    std::optional<std::array<double, 2>> point_pos(const PointRef& ref) const;

    // --- geometry output ---
    // Builds a planar face from the closed profile formed by all
    // non-construction entities (single circle, or a loop of lines/arcs).
    // Returns a null shape if no closed profile exists.
    TopoDS_Shape profile_face(std::string* err = nullptr) const;

    uint64_t revision() const { return revision_; }

private:
    friend class PlaneGCSBackend;
    friend struct SketchSerde;  // JSON persistence (sketch_json.cpp)
    size_t push_params(std::initializer_list<double> values);

    EntityId id_;
    std::string name_;
    SketchPlane plane_;
    std::deque<double> params_;  // stable addresses
    std::vector<SketchEntity> entities_;
    std::vector<SketchConstraint> constraints_;
    uint64_t revision_ = 0;
};

}  // namespace sx
