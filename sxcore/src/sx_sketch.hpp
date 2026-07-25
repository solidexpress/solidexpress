#pragma once
// SxSketch: Godot-facing wrapper for sx::Sketch + solver. Entities and
// constraints are addressed by UUID strings; point roles by string
// ("self"|"start"|"end"|"center"); constraint types by string matching
// sx::to_string(ConstraintType).

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <memory>

#include "sx/sketch.hpp"
#include "sx/solver.hpp"

namespace sx_godot {

class SxSketch : public godot::RefCounted {
    GDCLASS(SxSketch, godot::RefCounted)

public:
    SxSketch();
    ~SxSketch() override = default;

    void adopt(std::shared_ptr<sx::Sketch> sketch);

    void set_plane(const godot::Vector3& origin, const godot::Vector3& x_dir,
                   const godot::Vector3& y_dir);
    godot::Dictionary plane_info() const;

    godot::String add_point(double x, double y);
    godot::String add_line(double x1, double y1, double x2, double y2);
    godot::String add_circle(double cx, double cy, double r);
    godot::String add_arc(double cx, double cy, double r, double start_angle, double end_angle);
    godot::String add_spline(const godot::PackedVector2Array& fit_points);
    bool remove_entity(const godot::String& id);
    void set_construction(const godot::String& id, bool construction);
    bool is_construction(const godot::String& id) const;
    void set_external(const godot::String& id, bool external, const godot::String& projected_from);
    bool is_external(const godot::String& id) const;
    godot::PackedStringArray entity_ids() const;

    godot::String fillet_corner(const godot::String& line_a_id,
                                const godot::String& line_b_id, double radius);
    godot::PackedStringArray offset_entities(const godot::PackedStringArray& ids,
                                             double distance);
    bool trim_entity(const godot::String& id, double px, double py);
    bool extend_entity(const godot::String& id, double px, double py);
    godot::PackedStringArray pattern_entities(const godot::PackedStringArray& ids,
                                              double dx, double dy, int count);

    godot::Dictionary entity_info(const godot::String& id) const;
    bool set_entity_geometry(const godot::String& id, const godot::Dictionary& geo);

    // refs: Array of Dictionaries {entity: String, role: String}.
    // Optional 4th arg driving (default true).
    godot::String add_constraint(const godot::String& type, const godot::Array& refs,
                                 double value, bool driving = true);
    bool remove_constraint(const godot::String& id);
    bool set_constraint_value(const godot::String& id, double value);
    bool set_constraint_expr(const godot::String& id, const godot::String& expr);
    bool set_constraint_driving(const godot::String& id, bool driving);
    bool resolve_expressions(const godot::Dictionary& env);
    godot::PackedStringArray constraint_ids() const;
    godot::Dictionary constraint_info(const godot::String& id) const;

    godot::Dictionary solve();
    godot::Array analyze(double gap_tol = 1e-4) const;
    int fully_define();

    godot::String project_line_edge(const godot::Vector3& a, const godot::Vector3& b,
                                    const godot::String& edge_id);
    godot::String project_circle_edge(const godot::Vector3& center, double radius,
                                      const godot::String& edge_id);
    bool update_projected_line(const godot::String& id, const godot::Vector3& a,
                               const godot::Vector3& b);
    bool update_projected_circle(const godot::String& id, const godot::Vector3& center,
                                 double radius);
    int mark_dangling_external(const godot::PackedStringArray& live_edge_ids);

    std::shared_ptr<sx::Sketch> sketch() const { return sketch_; }

protected:
    static void _bind_methods();

private:
    std::shared_ptr<sx::Sketch> sketch_;
    std::unique_ptr<sx::SolverBackend> solver_;
};

}  // namespace sx_godot
