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

#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>

#include "sx/entity.hpp"
#include "sx/ids.hpp"

namespace sx {

enum class SketchEntityType { Point, Line, Circle, Arc, Spline, Ellipse, EllipticalArc };

// Which point of an entity a constraint references.
enum class PointRole { Self, Start, End, Center, MinorStart, MinorEnd };

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
    //   Ellipse:[cx, cy, f1x, f1y, radmin]  GCS native; rx/ry/angle derived
    //   EllipticalArc: ellipse native + [sa, ea, sx, sy, ex, ey]
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
    Concentric,     // circle|arc, circle|arc (centers coincident)
    Collinear,      // line, line (or three points)
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
    bool weak = false;  // Creo-style: yields when a strong dim conflicts / Relax
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
    void set_plane(SketchPlane plane);

    // --- entities ---
    EntityId add_point(double x, double y);
    EntityId add_line(double x1, double y1, double x2, double y2);
    EntityId add_circle(double cx, double cy, double r);
    // Arc counter-clockwise from start_angle to end_angle (radians).
    EntityId add_arc(double cx, double cy, double r, double start_angle, double end_angle);
    // Fit-point spline (n >= 2). Stored as B-spline for profile/path output.
    EntityId add_spline(const std::vector<std::array<double, 2>>& fit_points);
    // Full ellipse. rx/ry are semi-axes; angle is the major-axis direction.
    // Stored as centre + focus1 + radmin for PlaneGCS.
    EntityId add_ellipse(double cx, double cy, double rx, double ry, double angle = 0.0);
    // Trimmed ellipse. Angles are the ellipse parameter (from the major axis).
    // Stored as ellipse GCS native plus start/end angles and endpoints.
    EntityId add_elliptical_arc(double cx, double cy, double rx, double ry, double angle,
                                double start_angle, double end_angle);
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
    // Weak (Creo-style) dimensions: yield when a strong dim conflicts / Relax.
    bool set_constraint_weak(const EntityId& id, bool weak);
    // Drop every weak constraint (Inventor Relax / conflict yield).
    int drop_weak_constraints();

    // Resolve constraint expressions against env; writes numeric value.
    // Returns false if any expression fails.
    bool resolve_expressions(const std::map<std::string, double>& env, std::string* err = nullptr);

    // Arc rules are 2π-periodic. A weld that rewrites start/end and leaves
    // start_angle/end_angle on another branch makes the profile take the
    // complementary bulge. When the stored angles disagree with the
    // endpoints, snap them to the CCW sweep of those endpoints. Angles that
    // already match (including a consistent major arc) are left alone.
    void reconcile_arc_angles();

    // --- parameter access ---
    double param(size_t index) const { return params_[index]; }
    double& param_mut(size_t index) { return params_[index]; }
    size_t param_count() const { return params_.size(); }

    // Convenience: current 2D coordinates of a referenced point.
    std::optional<std::array<double, 2>> point_pos(const PointRef& ref) const;

    // Fit points of a spline entity (empty if not a spline).
    std::vector<std::array<double, 2>> spline_fit_points(const EntityId& id) const;
    // One interpolating BSpline through the fit points (GeomAPI_Interpolate).
    // Profile, solver, overlay and picking all use this curve.
    TopoDS_Edge spline_edge(const EntityId& id) const;
    std::vector<std::array<double, 2>> spline_samples(const EntityId& id, int n = 64) const;
    struct SplineGeom {
        std::vector<std::array<double, 2>> poles;
        std::vector<double> knots;
        std::vector<int> multiplicities;
        int degree = 3;
        bool ok = false;
    };
    SplineGeom spline_geom(const EntityId& id) const;
    // UV interpolant for live preview (same GeomAPI_Interpolate, XY plane).
    static std::vector<std::array<double, 2>> interpolate_samples(
        const std::vector<std::array<double, 2>>& fit_points, int n = 64);
    bool set_spline_fit_point(const EntityId& id, int index, double x, double y);
    bool set_spline_pole(const EntityId& id, int index, double x, double y);
    // End tangent in sketch UV. `enabled` false drops the Load() pin (C2 end).
    bool set_spline_end_tangent(const EntityId& id, bool at_start, double tx, double ty,
                                bool enabled);
    std::optional<std::array<double, 2>> spline_end_tangent(const EntityId& id,
                                                            bool at_start) const;
    std::array<double, 2> spline_end_derivative(const EntityId& id, bool at_start) const;
    struct CombTooth {
        std::array<double, 2> at{0, 0};
        std::array<double, 2> tip{0, 0};
    };
    std::vector<CombTooth> spline_comb(const EntityId& id, int n = 32, double scale = 8.0) const;
    // Driving Tangent(spline, line): Load() end tangent from the line direction.
    void sync_spline_line_tangents();
    // cx, cy, rx, ry, angle. Empty if `id` is not an ellipse or elliptical arc.
    std::optional<std::array<double, 5>> ellipse_axes(const EntityId& id) const;

    // --- geometry output ---
    // Builds a planar face from the closed profile formed by all
    // non-construction entities (single circle, or a loop of lines/arcs/splines).
    // Multiple disjoint closed regions fuse as solid faces (Selected Contours
    // default = all). Nested wires keep outer+holes semantics.
    // Returns a null shape if no closed profile exists.
    TopoDS_Shape profile_face(std::string* err = nullptr) const;

    // Selectable solid regions for Selected Contours (SW). Empty on failure.
    // Disjoint closed wires are separate solids; nested wires are holes.
    // Edges that share arcs (circle split by a chord, pliers head + nose)
    // are split into planar regions (BRepAlgoAPI_Splitter). A stray open
    // chain that does not meet those wires is ignored so it cannot erase
    // the closed regions. Whole-sketch profile_face still refuses that sketch.
    std::vector<TopoDS_Shape> contour_faces(std::string* err = nullptr) const;
    // Planar-split regions. A chained wire of the same area can still be a
    // complement that MakeRevol rejects; the arrangement cell does not.
    std::vector<TopoDS_Shape> arrangement_faces(std::string* err = nullptr) const;
    // Closed chained loops only — no planar-split upgrade. Loft sections
    // need that single wire; a dense polyline's split is a cell compound.
    std::vector<TopoDS_Shape> chained_faces(std::string* err = nullptr) const;

    // Closed region outlines in sketch UV, same order as contour_faces()
    // (area descending, then centroid x, then y). Chip i is entry i.
    struct ContourOutline {
        std::vector<std::array<double, 2>> outer;  // last point != first
        std::vector<std::vector<std::array<double, 2>>> holes;
        double area = 0.0;  // outer minus holes, mm^2
        std::array<double, 2> min{0, 0}, size{0, 0}, center{0, 0};  // bbox of outer
    };
    std::vector<ContourOutline> contour_outlines(double deflection = 0.05,
                                                 std::string* err = nullptr) const;

    // profile_face restricted to contour indices (empty = all). Indices match
    // contour_faces() order. Host face empty uses sketch-only contours; a
    // planar host splits that face by the sketch curves (region pick).
    TopoDS_Shape profile_face_selected(const std::vector<int>& indices,
                                       std::string* err = nullptr) const;
    TopoDS_Shape profile_face_selected(const std::vector<int>& indices,
                                       const TopoDS_Shape& host_face,
                                       std::string* err) const;

    // Builds a planar face by in-plane offsetting an open (or closed)
    // non-construction polyline profile to the given wall thickness.
    TopoDS_Shape thin_profile_face(double thickness, bool midplane, bool flip_side,
                                   std::string* err = nullptr) const;

    // SolidWorks Extruded Cut "Flip Side to Cut" for an open sketch: a large
    // half-plane on one side of the open chain (not a thin wall). pad_extent
    // must exceed the target body silhouette on that side.
    TopoDS_Shape open_cut_profile_face(bool flip_side, double pad_extent,
                                       std::string* err = nullptr) const;

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
    // Partial circle in the sketch plane. `span` is the 3D parameter length so
    // the UV arc takes the matching bulge (minor vs major).
    EntityId project_arc_edge(const std::array<double, 3>& center, double radius,
                              const std::array<double, 3>& a, const std::array<double, 3>& b,
                              double span, const std::string& edge_id);
    // In-plane BSpline/Bezier Convert: interpolating fit points in sketch UV.
    EntityId project_spline_edge(const std::vector<std::array<double, 2>>& fit_points,
                                 const std::string& edge_id);
    EntityId project_ellipse_edge(double cx, double cy, double rx, double ry, double angle,
                                  const std::string& edge_id);
    EntityId project_elliptical_arc_edge(double cx, double cy, double rx, double ry, double angle,
                                         double start_angle, double end_angle,
                                         const std::string& edge_id);

    // Update external entity geometry from new 3D edge data (associative regen).
    bool update_projected_line(const EntityId& id, const std::array<double, 3>& a,
                               const std::array<double, 3>& b);
    bool update_projected_circle(const EntityId& id, const std::array<double, 3>& center,
                                 double radius);
    bool update_projected_arc(const EntityId& id, const std::array<double, 3>& center, double radius,
                              const std::array<double, 3>& a, const std::array<double, 3>& b,
                              double span);
    bool update_projected_ellipse(const EntityId& id, double cx, double cy, double rx, double ry,
                                  double angle);
    bool update_projected_elliptical_arc(const EntityId& id, double cx, double cy, double rx,
                                         double ry, double angle, double start_angle,
                                         double end_angle);
    bool update_projected_spline(const EntityId& id,
                                 const std::vector<std::array<double, 2>>& fit_points);
    // Mark projected_from empty entities still external as dangling (construction).
    int mark_dangling_external(const std::vector<std::string>& live_edge_ids);

    uint64_t revision() const { return revision_; }

private:
    friend class PlaneGCSBackend;
    friend struct SketchSerde;  // JSON persistence (sketch_json.cpp)
    size_t push_params(std::initializer_list<double> values);
    std::array<double, 2> to_sketch_uv(const std::array<double, 3>& p) const;

    // stray_open is set when a dangling chain was ignored so closed regions
    // could still be returned. Whole-sketch extrude treats that as open.
    std::vector<TopoDS_Shape> contour_faces_impl(std::string* err, bool* stray_open,
                                                 bool prefer_split = false,
                                                 bool allow_split = true) const;

    EntityId id_;
    std::string name_;
    SketchPlane plane_;
    std::deque<double> params_;  // stable addresses
    std::vector<SketchEntity> entities_;
    std::vector<SketchConstraint> constraints_;
    uint64_t revision_ = 0;
};

}  // namespace sx
