#include "sx_interop.hpp"

#include "sx_document.hpp"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace sx_godot {

void SxInterop::bind(const Ref<SxDocument>& doc) { doc_ = doc; }

bool SxInterop::export_step(const String& path) {
    if (doc_.is_null()) return false;
    return doc_->export_step(path);
}

bool SxInterop::export_stl(const String& path, bool binary) {
    if (doc_.is_null()) return false;
    return doc_->export_stl(path, binary);
}

PackedStringArray SxInterop::import_step(const String& path) {
    if (doc_.is_null()) return {};
    return doc_->import_step(path);
}

PackedStringArray SxInterop::import_stl(const String& path) {
    if (doc_.is_null()) return {};
    return doc_->import_stl(path);
}

bool SxInterop::export_drawing_svg(const String& path, double scale) {
    if (doc_.is_null()) return false;
    return doc_->export_drawing_svg(path, scale);
}

void SxInterop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("bind", "doc"), &SxInterop::bind);
    ClassDB::bind_method(D_METHOD("export_step", "path"), &SxInterop::export_step);
    ClassDB::bind_method(D_METHOD("export_stl", "path", "binary"), &SxInterop::export_stl);
    ClassDB::bind_method(D_METHOD("import_step", "path"), &SxInterop::import_step);
    ClassDB::bind_method(D_METHOD("import_stl", "path"), &SxInterop::import_stl);
    ClassDB::bind_method(D_METHOD("export_drawing_svg", "path", "scale"),
                         &SxInterop::export_drawing_svg);
}

}  // namespace sx_godot
