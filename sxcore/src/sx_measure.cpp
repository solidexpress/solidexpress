#include "sx_measure.hpp"

#include "sx_document.hpp"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace sx_godot {

void SxMeasure::bind(const Ref<SxDocument>& doc) { doc_ = doc; }

Dictionary SxMeasure::measure_distance(const String& a, const String& b) const {
    if (doc_.is_null()) return {};
    return doc_->measure_distance(a, b);
}

Dictionary SxMeasure::closest_point_on(const String& shape_id, const Vector3& from) const {
    if (doc_.is_null()) return {};
    return doc_->closest_point_on(shape_id, from);
}

Vector3 SxMeasure::face_midpoint(const String& face_id) const {
    if (doc_.is_null()) return {};
    return doc_->face_midpoint(face_id);
}

Dictionary SxMeasure::measure_bbox(const String& id) const {
    if (doc_.is_null()) return {};
    return doc_->measure_bbox(id);
}

Dictionary SxMeasure::measure_mass(const String& body_id) const {
    if (doc_.is_null()) return {};
    return doc_->measure_mass(body_id);
}

double SxMeasure::measure_edge_length(const String& edge_id) const {
    if (doc_.is_null()) return 0.0;
    return doc_->measure_edge_length(edge_id);
}

double SxMeasure::measure_face_area(const String& face_id) const {
    if (doc_.is_null()) return 0.0;
    return doc_->measure_face_area(face_id);
}

double SxMeasure::measure_face_angle(const String& f1, const String& f2) const {
    if (doc_.is_null()) return -1.0;
    return doc_->measure_face_angle(f1, f2);
}

void SxMeasure::_bind_methods() {
    ClassDB::bind_method(D_METHOD("bind", "doc"), &SxMeasure::bind);
    ClassDB::bind_method(D_METHOD("measure_distance", "a", "b"), &SxMeasure::measure_distance);
    ClassDB::bind_method(D_METHOD("closest_point_on", "shape_id", "from"),
                         &SxMeasure::closest_point_on);
    ClassDB::bind_method(D_METHOD("face_midpoint", "face_id"), &SxMeasure::face_midpoint);
    ClassDB::bind_method(D_METHOD("measure_bbox", "id"), &SxMeasure::measure_bbox);
    ClassDB::bind_method(D_METHOD("measure_mass", "body_id"), &SxMeasure::measure_mass);
    ClassDB::bind_method(D_METHOD("measure_edge_length", "edge_id"),
                         &SxMeasure::measure_edge_length);
    ClassDB::bind_method(D_METHOD("measure_face_area", "face_id"), &SxMeasure::measure_face_area);
    ClassDB::bind_method(D_METHOD("measure_face_angle", "f1", "f2"),
                         &SxMeasure::measure_face_angle);
}

}  // namespace sx_godot
