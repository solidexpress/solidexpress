#pragma once
// Thin GDExtension facade over SxDocument import/export APIs. Compatibility
// layer toward a split interop service — SxDocument keeps the same methods.

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace sx_godot {

class SxDocument;

class SxInterop : public godot::RefCounted {
    GDCLASS(SxInterop, godot::RefCounted)

public:
    SxInterop() = default;
    ~SxInterop() override = default;

    void bind(const godot::Ref<SxDocument>& doc);

    bool export_step(const godot::String& path);
    bool export_stl(const godot::String& path, bool binary);
    godot::PackedStringArray import_step(const godot::String& path);
    godot::PackedStringArray import_stl(const godot::String& path);
    bool export_drawing_svg(const godot::String& path, double scale);

protected:
    static void _bind_methods();

private:
    godot::Ref<SxDocument> doc_;
};

}  // namespace sx_godot
