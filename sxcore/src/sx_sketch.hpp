#pragma once
// SxSketch: Godot-facing wrapper for sx::Sketch + solver. Entities and
// constraints are addressed by UUID strings; point roles by string
// ("self"|"start"|"end"|"center"); constraint types by string matching
// sx::to_string(ConstraintType).

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <memory>

#include "sx/sketch.hpp"
#include "sx/solver.hpp"

namespace sx_godot {

class SxSketch : public godot::RefCounted {
    GDCLASS(SxSketch, godot::RefCounted)

public:
    SxSketch();
    ~SxSketch() override = default;

    // Adopt an existing kernel sketch (e.g. from the feature graph).
    void adopt(std::shared_ptr<sx::Sketch> sketch);

    void set_plane(const godot::Vector3& origin, const godot::Vector3& x_dir,
                   const godot::Vector3& y_dir);

    // Sketch plane frame in model space (empty dict if unset).
    godot::Dictionary plane_info() const;

    // --- entities (sketch 2D coordinates) ---
    godot::String add_point(double x, double y);
    godot::String add_line(double x1, double y1, double x2, double y2);
    godot::String add_circle(double cx, double cy, double r);
    godot::String add_arc(double cx, double cy, double r, double start_angle, double end_angle);
    bool remove_entity(const godot::String& id);
    void set_construction(const godot::String& id, bool construction);
    bool is_construction(const godot::String& id) const;
    godot::PackedStringArray entity_ids() const;

    // --- geometry tools ---
    godot::String fillet_corner(const godot::String& line_a_id,
                                const godot::String& line_b_id, double radius);
    godot::PackedStringArray offset_entities(const godot::PackedStringArray& ids,
                                             double distance);
    bool trim_entity(const godot::String& id, double px, double py);
    bool extend_entity(const godot::String& id, double px, double py);
    godot::PackedStringArray pattern_entities(const godot::PackedStringArray& ids,
                                              double dx, double dy, int count);

    // Geometry snapshot for rendering:
    // {type: "line", start: Vector2, end: Vector2, construction: bool} etc.
    godot::Dictionary entity_info(const godot::String& id) const;
    // Writes geometry params from a dict shaped like entity_info's output
    // (any subset of keys). Callers re-solve afterwards.
    bool set_entity_geometry(const godot::String& id, const godot::Dictionary& geo);

    // --- constraints ---
    // refs: Array of Dictionaries {entity: String, role: String}.
    godot::String add_constraint(const godot::String& type, const godot::Array& refs,
                                 double value);
    bool remove_constraint(const godot::String& id);
    bool set_constraint_value(const godot::String& id, double value);
    bool set_constraint_weak(const godot::String& id, bool weak);
    int drop_weak_constraints();
    godot::PackedStringArray constraint_ids() const;
    // Snapshot for UI glyphs: {type: String, value: float,
    //   refs: Array of {entity: String, role: String}}. Empty if unknown id.
    godot::Dictionary constraint_info(const godot::String& id) const;

    // --- solving ---
    // Returns {status: "success"|"converged"|"failed", dofs: int,
    //          conflicting: PackedStringArray, redundant: PackedStringArray}.
    godot::Dictionary solve();

    // Shared access for SxDocument::extrude_sketch / revolve_sketch.
    std::shared_ptr<sx::Sketch> sketch() const { return sketch_; }

protected:
    static void _bind_methods();

private:
    std::shared_ptr<sx::Sketch> sketch_;
    std::unique_ptr<sx::SolverBackend> solver_;
};

}  // namespace sx_godot
