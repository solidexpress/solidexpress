#pragma once
// Thin GDExtension facade over SxDocument measurement APIs. Compatibility
// layer toward a split measure service — SxDocument keeps the same methods.

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace sx_godot {

class SxDocument;

class SxMeasure : public godot::RefCounted {
    GDCLASS(SxMeasure, godot::RefCounted)

public:
    SxMeasure() = default;
    ~SxMeasure() override = default;

    void bind(const godot::Ref<SxDocument>& doc);

    godot::Dictionary measure_distance(const godot::String& a, const godot::String& b) const;
    godot::Dictionary closest_point_on(const godot::String& shape_id,
                                       const godot::Vector3& from) const;
    godot::Vector3 face_midpoint(const godot::String& face_id) const;
    godot::Dictionary measure_bbox(const godot::String& id) const;
    godot::Dictionary measure_mass(const godot::String& body_id) const;
    double measure_edge_length(const godot::String& edge_id) const;
    double measure_face_area(const godot::String& face_id) const;
    double measure_face_angle(const godot::String& f1, const godot::String& f2) const;

protected:
    static void _bind_methods();

private:
    godot::Ref<SxDocument> doc_;
};

}  // namespace sx_godot
