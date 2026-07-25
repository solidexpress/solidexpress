#include "sx_document.hpp"

#include <godot_cpp/core/class_db.hpp>

#include "sx/commands_boolean.hpp"
#include "sx/commands_draft.hpp"
#include "sx/commands_dress.hpp"
#include "sx/commands_graph.hpp"
#include "sx/commands_hollow.hpp"
#include "sx/commands_sketch.hpp"
#include "sx/commands_transform.hpp"
#include <cmath>
#include <limits>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Vec.hxx>
#include <type_traits>
#include <variant>
#include "sx/drawings.hpp"
#include "sx/materials.hpp"
#include "sx/mates.hpp"
#include "sx/measure.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/sketch_json.hpp"
#include "sx_sketch.hpp"
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include "sx/cards.hpp"
#include "sx/context.hpp"
#include "sx/log.hpp"
#include "sx/pick.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"
#include "sx/tessellate.hpp"

using namespace godot;

namespace sx_godot {

static std::string to_std(const String& s) { return s.utf8().get_data(); }
static String to_gd(const std::string& s) { return String::utf8(s.c_str()); }

static sx::EntityId parse_id(const String& s) {
    try {
        return sx::EntityId::from_string(to_std(s));
    } catch (...) {
        return {};
    }
}

SxDocument::SxDocument() : doc_(std::make_unique<sx::Document>()) {}

String SxDocument::add_primitive(sx::PrimitiveType type, double a, double b, double c,
                                 const Vector3& origin) {
    sx::PrimitiveParams p;
    p.type = type;
    p.a = a;
    p.b = b;
    p.c = c;
    p.placement.origin = {origin.x, origin.y, origin.z};
    auto cmd = std::make_unique<sx::AddPrimitiveCommand>(p);
    sx::AddPrimitiveCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("add_primitive failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

String SxDocument::add_box(double dx, double dy, double dz, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Box, dx, dy, dz, origin);
}
String SxDocument::add_cylinder(double radius, double height, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Cylinder, radius, height, 0, origin);
}
String SxDocument::add_sphere(double radius, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Sphere, radius, 0, 0, origin);
}
String SxDocument::add_cone(double r1, double r2, double height, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Cone, r1, r2, height, origin);
}
String SxDocument::add_torus(double major_r, double minor_r, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Torus, major_r, minor_r, 0, origin);
}

String SxDocument::extrude_sketch(const Ref<SxSketch>& sketch, double distance,
                                  bool symmetric) {
    if (sketch.is_null()) return {};
    auto cmd = std::make_unique<sx::ExtrudeCommand>(sketch->sketch(), distance, symmetric);
    sx::ExtrudeCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("extrude failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

String SxDocument::revolve_sketch(const Ref<SxSketch>& sketch, const Vector2& axis_point,
                                  const Vector2& axis_dir, double angle) {
    if (sketch.is_null()) return {};
    auto cmd = std::make_unique<sx::RevolveCommand>(
        sketch->sketch(), std::array<double, 2>{axis_point.x, axis_point.y},
        std::array<double, 2>{axis_dir.x, axis_dir.y}, angle);
    sx::RevolveCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("revolve failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

bool SxDocument::delete_body(const String& body_id) {
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::DeleteBodyCommand>(id));
    } catch (const std::exception& e) {
        sx::log::error(std::string("delete_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::translate_body(const String& body_id, const Vector3& delta) {
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::TranslateBodyCommand>(
                               id, std::array<double, 3>{delta.x, delta.y, delta.z}));
    } catch (const std::exception& e) {
        sx::log::error(std::string("translate_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::push_pull(const String& face_id, double distance) {
    auto id = parse_id(face_id);
    if (id.is_null()) return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::PushPullCommand>(id, distance));
    } catch (const std::exception& e) {
        sx::log::error(std::string("push_pull failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::boolean_op(const String& target_body, const String& tool_body,
                            const String& op, bool keep_tool) {
    auto target = parse_id(target_body);
    auto tool = parse_id(tool_body);
    std::string op_name = to_std(op);
    sx::BooleanOp bop;
    if (op_name == "fuse") bop = sx::BooleanOp::Fuse;
    else if (op_name == "cut") bop = sx::BooleanOp::Cut;
    else if (op_name == "common") bop = sx::BooleanOp::Common;
    else return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::BooleanCommand>(target, tool, bop, keep_tool));
    } catch (const std::exception& e) {
        sx::log::error(std::string("boolean_op failed: ") + e.what());
        return false;
    }
    return true;
}

static std::vector<sx::EntityId> parse_ids(const PackedStringArray& arr) {
    std::vector<sx::EntityId> out;
    for (int i = 0; i < arr.size(); ++i) {
        auto id = parse_id(arr[i]);
        if (!id.is_null()) out.push_back(id);
    }
    return out;
}

bool SxDocument::fillet_edges(const PackedStringArray& edge_ids, double radius) {
    try {
        stack_.push(*doc_, std::make_unique<sx::FilletCommand>(parse_ids(edge_ids), radius));
    } catch (const std::exception& e) {
        sx::log::error(std::string("fillet failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::chamfer_edges(const PackedStringArray& edge_ids, double distance) {
    try {
        stack_.push(*doc_, std::make_unique<sx::ChamferCommand>(parse_ids(edge_ids), distance));
    } catch (const std::exception& e) {
        sx::log::error(std::string("chamfer failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::export_step(const String& path) {
    std::string err;
    bool ok = sx::interop::export_step(*doc_, to_std(path), &err);
    if (!ok) sx::log::error("export_step: " + err);
    return ok;
}

bool SxDocument::export_stl(const String& path, bool binary) {
    std::string err;
    bool ok = sx::interop::export_stl(*doc_, to_std(path), binary, &err);
    if (!ok) sx::log::error("export_stl: " + err);
    return ok;
}

String SxDocument::mirror_body(const String& body_id, const Vector3& plane_point,
                               const Vector3& plane_normal, bool keep_original) {
    auto cmd = std::make_unique<sx::MirrorBodyCommand>(
        parse_id(body_id), std::array<double, 3>{plane_point.x, plane_point.y, plane_point.z},
        std::array<double, 3>{plane_normal.x, plane_normal.y, plane_normal.z}, keep_original);
    sx::MirrorBodyCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("mirror_body failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

PackedStringArray SxDocument::linear_pattern(const String& body_id, const Vector3& direction,
                                             double spacing, int count) {
    auto cmd = std::make_unique<sx::LinearPatternCommand>(
        parse_id(body_id), std::array<double, 3>{direction.x, direction.y, direction.z},
        spacing, count);
    sx::LinearPatternCommand* raw = cmd.get();
    PackedStringArray out;
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("linear_pattern failed: ") + e.what());
        return out;
    }
    for (const auto& id : raw->created_bodies()) out.push_back(to_gd(id.str()));
    return out;
}

PackedStringArray SxDocument::circular_pattern(const String& body_id, const Vector3& axis_point,
                                               const Vector3& axis_dir, int count,
                                               double total_angle) {
    auto cmd = std::make_unique<sx::CircularPatternCommand>(
        parse_id(body_id), std::array<double, 3>{axis_point.x, axis_point.y, axis_point.z},
        std::array<double, 3>{axis_dir.x, axis_dir.y, axis_dir.z}, count, total_angle);
    sx::CircularPatternCommand* raw = cmd.get();
    PackedStringArray out;
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("circular_pattern failed: ") + e.what());
        return out;
    }
    for (const auto& id : raw->created_bodies()) out.push_back(to_gd(id.str()));
    return out;
}

bool SxDocument::rotate_body(const String& body_id, const Vector3& axis_point,
                             const Vector3& axis_dir, double angle) {
    try {
        stack_.push(*doc_, std::make_unique<sx::RotateBodyCommand>(
                               parse_id(body_id),
                               std::array<double, 3>{axis_point.x, axis_point.y, axis_point.z},
                               std::array<double, 3>{axis_dir.x, axis_dir.y, axis_dir.z}, angle));
    } catch (const std::exception& e) {
        sx::log::error(std::string("rotate_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::shell_body(const PackedStringArray& faces_to_remove, double thickness) {
    try {
        stack_.push(*doc_, std::make_unique<sx::ShellCommand>(parse_ids(faces_to_remove),
                                                              thickness));
    } catch (const std::exception& e) {
        sx::log::error(std::string("shell_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::offset_body(const String& body_id, double offset) {
    try {
        stack_.push(*doc_, std::make_unique<sx::OffsetBodyCommand>(parse_id(body_id), offset));
    } catch (const std::exception& e) {
        sx::log::error(std::string("offset_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::draft_faces(const PackedStringArray& face_ids, double angle_deg,
                             const Vector3& pull_dir, const Vector3& neutral_point,
                             const Vector3& neutral_normal) {
    auto faces = parse_ids(face_ids);
    if (faces.empty()) return false;
    auto owner = doc_->owning_body(faces.front());
    if (!owner) return false;

    const double angle = angle_deg * M_PI / 180.0;
    const gp_Dir pull(pull_dir.x, pull_dir.y, pull_dir.z);
    const gp_Pln neutral(gp_Pnt(neutral_point.x, neutral_point.y, neutral_point.z),
                         gp_Dir(neutral_normal.x, neutral_normal.y, neutral_normal.z));

    auto cmd = std::make_unique<sx::DraftCommand>(*owner, std::move(faces), angle, pull,
                                                  neutral);
    // Fallible: only adopt into the undo stack when the algorithm succeeds.
    // try_execute mutates the doc; undo restores it so stack_.push can
    // re-execute cleanly (face ids are preserved by topological naming, so a
    // second try_execute without undo would clobber the undo snapshots).
    if (!cmd->try_execute(*doc_)) return false;
    cmd->undo(*doc_);
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("draft_faces failed: ") + e.what());
        return false;
    }
    return true;
}

Dictionary SxDocument::measure_distance(const String& a, const String& b) const {
    Dictionary out;
    auto r = sx::measure::min_distance(*doc_, parse_id(a), parse_id(b));
    if (!r) return out;
    out["distance"] = r->distance;
    out["point_a"] = Vector3(r->point_a[0], r->point_a[1], r->point_a[2]);
    out["point_b"] = Vector3(r->point_b[0], r->point_b[1], r->point_b[2]);
    return out;
}

Dictionary SxDocument::closest_point_on(const String& shape_id, const Vector3& from) const {
    Dictionary out;
    auto r = sx::measure::closest_point(*doc_, parse_id(shape_id),
                                        {from.x, from.y, from.z});
    if (!r) return out;
    out["distance"] = r->distance;
    out["point_a"] = Vector3(r->point_a[0], r->point_a[1], r->point_a[2]);
    out["point_b"] = Vector3(r->point_b[0], r->point_b[1], r->point_b[2]);
    return out;
}

Vector3 SxDocument::face_midpoint(const String& face_id) const {
    auto r = sx::measure::face_midpoint(*doc_, parse_id(face_id));
    if (!r) return Vector3();
    return Vector3((*r)[0], (*r)[1], (*r)[2]);
}

Dictionary SxDocument::measure_bbox(const String& id) const {
    Dictionary out;
    auto r = sx::measure::bounding_box(*doc_, parse_id(id));
    if (!r) return out;
    out["min"] = Vector3(r->min[0], r->min[1], r->min[2]);
    out["max"] = Vector3(r->max[0], r->max[1], r->max[2]);
    return out;
}

Dictionary SxDocument::measure_mass(const String& body_id) const {
    Dictionary out;
    auto r = sx::measure::mass_properties(*doc_, parse_id(body_id));
    if (!r) return out;
    out["volume"] = r->volume;
    out["surface_area"] = r->surface_area;
    out["center_of_mass"] =
        Vector3(r->center_of_mass[0], r->center_of_mass[1], r->center_of_mass[2]);
    // Mass in grams from the body's material density (volume is mm^3).
    const sx::Body* b = doc_->body(parse_id(body_id));
    double density = 1.0;
    String mat_name = "Unspecified";
    if (b) {
        if (auto m = sx::materials::find(b->material)) {
            density = m->density_g_cm3;
            mat_name = to_gd(m->name);
        }
    }
    out["material"] = mat_name;
    out["density_g_cm3"] = density;
    out["mass_g"] = r->volume / 1000.0 * density;
    return out;
}

double SxDocument::measure_edge_length(const String& edge_id) const {
    return sx::measure::edge_length(*doc_, parse_id(edge_id));
}

double SxDocument::measure_face_area(const String& face_id) const {
    return sx::measure::face_area(*doc_, parse_id(face_id));
}

double SxDocument::measure_face_angle(const String& f1, const String& f2) const {
    auto r = sx::measure::angle_between_faces(*doc_, parse_id(f1), parse_id(f2));
    return r ? *r : -1.0;
}

PackedStringArray SxDocument::import_step(const String& path) {
    PackedStringArray out;
    std::string err;
    auto ids = sx::interop::import_step(*doc_, to_std(path), &err);
    if (ids.empty() && !err.empty()) sx::log::error("import_step: " + err);
    for (const auto& id : ids) out.push_back(to_gd(id.str()));
    return out;
}

PackedStringArray SxDocument::import_stl(const String& path) {
    PackedStringArray out;
    std::string err;
    auto ids = sx::interop::import_stl(*doc_, to_std(path), &err);
    if (ids.empty() && !err.empty()) sx::log::error("import_stl: " + err);
    for (const auto& id : ids) out.push_back(to_gd(id.str()));
    return out;
}

bool SxDocument::undo() { return stack_.undo(*doc_); }
bool SxDocument::redo() { return stack_.redo(*doc_); }
bool SxDocument::can_undo() const { return stack_.can_undo(); }
bool SxDocument::can_redo() const { return stack_.can_redo(); }

PackedStringArray SxDocument::body_ids() const {
    PackedStringArray out;
    for (const auto& id : doc_->body_ids()) out.push_back(to_gd(id.str()));
    return out;
}

String SxDocument::body_name(const String& body_id) const {
    const sx::Body* b = doc_->body(parse_id(body_id));
    return b ? to_gd(b->name) : String();
}

bool SxDocument::rename_body(const String& body_id, const String& name) {
    return doc_->rename_body(parse_id(body_id), to_std(name));
}

bool SxDocument::set_body_color(const String& body_id, const Color& color) {
    sx::Body* b = doc_->body_mut(parse_id(body_id));
    if (!b) return false;
    b->color = {color.r, color.g, color.b};
    doc_->bump_revision();
    return true;
}

Color SxDocument::get_body_color(const String& body_id) const {
    const sx::Body* b = doc_->body(parse_id(body_id));
    if (!b) return Color(0.7f, 0.7f, 0.75f);
    return Color(b->color[0], b->color[1], b->color[2]);
}

bool SxDocument::set_body_material(const String& body_id, const String& material) {
    return doc_->set_body_material(parse_id(body_id), to_std(material));
}

String SxDocument::body_material(const String& body_id) const {
    const sx::Body* b = doc_->body(parse_id(body_id));
    return b ? to_gd(b->material) : String();
}

Array SxDocument::material_list() const {
    Array out;
    for (const auto& m : sx::materials::standard()) {
        Dictionary d;
        d["name"] = to_gd(m.name);
        d["density_g_cm3"] = m.density_g_cm3;
        out.push_back(d);
    }
    return out;
}

bool SxDocument::save_configuration(const String& name) {
    return doc_->save_configuration(to_std(name));
}

bool SxDocument::activate_configuration(const String& name) {
    if (!doc_->activate_configuration(to_std(name))) return false;
    doc_->graph().regenerate(*doc_);
    return true;
}

bool SxDocument::remove_configuration(const String& name) {
    return doc_->remove_configuration(to_std(name));
}

Array SxDocument::configuration_list() const {
    Array out;
    for (const auto& c : doc_->configurations()) {
        Dictionary d;
        d["name"] = to_gd(c.name);
        Dictionary vars;
        for (const auto& [var, expr] : c.variables) vars[to_gd(var)] = to_gd(expr);
        d["variables"] = vars;
        out.push_back(d);
    }
    return out;
}

String SxDocument::active_configuration() const {
    return to_gd(doc_->active_configuration());
}

double SxDocument::body_volume(const String& body_id) const {
    const sx::Body* b = doc_->body(parse_id(body_id));
    return b ? sx::shape::volume(b->shape) : 0.0;
}

uint64_t SxDocument::revision() const { return doc_->revision(); }

Ref<ArrayMesh> SxDocument::get_mesh(const String& body_id) const {
    Ref<ArrayMesh> mesh;
    mesh.instantiate();
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return mesh;

    sx::BodyMesh bm;
    try {
        bm = sx::tessellate_body(*doc_, id);
    } catch (const std::exception& e) {
        sx::log::error(std::string("tessellate failed: ") + e.what());
        return mesh;
    }

    for (const auto& fm : bm.faces) {
        PackedVector3Array positions;
        PackedVector3Array normals;
        PackedInt32Array indices;
        const size_t n = fm.positions.size() / 3;
        positions.resize(static_cast<int64_t>(n));
        normals.resize(static_cast<int64_t>(n));
        for (size_t i = 0; i < n; ++i) {
            positions[static_cast<int64_t>(i)] =
                Vector3(fm.positions[3 * i], fm.positions[3 * i + 1], fm.positions[3 * i + 2]);
            normals[static_cast<int64_t>(i)] =
                Vector3(fm.normals[3 * i], fm.normals[3 * i + 1], fm.normals[3 * i + 2]);
        }
        indices.resize(static_cast<int64_t>(fm.indices.size()));
        for (size_t i = 0; i < fm.indices.size(); ++i)
            indices[static_cast<int64_t>(i)] = static_cast<int32_t>(fm.indices[i]);

        Array arrays;
        arrays.resize(Mesh::ARRAY_MAX);
        arrays[Mesh::ARRAY_VERTEX] = positions;
        arrays[Mesh::ARRAY_NORMAL] = normals;
        arrays[Mesh::ARRAY_INDEX] = indices;
        mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
    }
    return mesh;
}

PackedStringArray SxDocument::get_face_ids(const String& body_id) const {
    PackedStringArray out;
    const sx::Body* b = doc_->body(parse_id(body_id));
    if (!b) return out;
    for (const auto& fid : b->subshape_ids.at(sx::EntityKind::Face))
        out.push_back(to_gd(fid.str()));
    return out;
}

PackedStringArray SxDocument::get_edge_ids(const String& body_id) const {
    PackedStringArray out;
    const sx::Body* b = doc_->body(parse_id(body_id));
    if (!b) return out;
    for (const auto& eid : b->subshape_ids.at(sx::EntityKind::Edge))
        out.push_back(to_gd(eid.str()));
    return out;
}

Dictionary SxDocument::get_edge_lines(const String& body_id) const {
    Dictionary out;
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return out;
    sx::BodyMesh bm;
    try {
        bm = sx::tessellate_body(*doc_, id);
    } catch (...) {
        return out;
    }
    for (const auto& el : bm.edges) {
        PackedVector3Array pts;
        const size_t n = el.points.size() / 3;
        pts.resize(static_cast<int64_t>(n));
        for (size_t i = 0; i < n; ++i)
            pts[static_cast<int64_t>(i)] =
                Vector3(el.points[3 * i], el.points[3 * i + 1], el.points[3 * i + 2]);
        out[to_gd(el.edge.str())] = pts;
    }
    return out;
}

Dictionary SxDocument::pick(const Vector3& origin, const Vector3& direction) const {
    Dictionary out;
    auto hit = sx::pick_ray(*doc_, {origin.x, origin.y, origin.z},
                            {direction.x, direction.y, direction.z});
    if (!hit) return out;
    out["body"] = to_gd(hit->body.str());
    out["face"] = to_gd(hit->face.str());
    out["point"] = Vector3(static_cast<float>(hit->point[0]),
                           static_cast<float>(hit->point[1]),
                           static_cast<float>(hit->point[2]));
    out["distance"] = hit->distance;
    return out;
}

String SxDocument::card_markdown(const String& entity_id) const {
    const sx::Card* c = doc_->cards().find(parse_id(entity_id));
    return c ? to_gd(c->to_markdown()) : String();
}

void SxDocument::set_card_alias(const String& entity_id, const String& text) {
    doc_->cards().set_alias(parse_id(entity_id), to_std(text));
}

void SxDocument::set_card_notes(const String& entity_id, const String& text) {
    doc_->cards().set_notes(parse_id(entity_id), to_std(text));
}

String SxDocument::get_card_alias(const String& entity_id) const {
    const sx::Card* c = doc_->cards().find(parse_id(entity_id));
    return c ? to_gd(c->aliases) : String();
}

String SxDocument::get_card_notes(const String& entity_id) const {
    const sx::Card* c = doc_->cards().find(parse_id(entity_id));
    return c ? to_gd(c->notes) : String();
}

String SxDocument::export_context() const {
    return to_gd(sx::export_context_markdown(*doc_));
}

Array SxDocument::graph_features() const {
    Array out;
    for (const auto& f : doc_->graph().timeline()) {
        Dictionary d;
        d["id"] = to_gd(f.id.str());
        d["name"] = to_gd(f.name);
        d["type"] = to_gd(sx::to_string(f.type));
        d["suppressed"] = f.suppressed;
        d["params"] = to_gd(f.params.dump());
        d["output_body"] = f.output_body.is_null() ? String() : to_gd(f.output_body.str());
        const bool failed = !last_failed_fid_.empty() && f.id.str() == last_failed_fid_;
        d["failed"] = failed;
        d["error"] = failed ? to_gd(last_graph_error_) : String();
        out.push_back(d);
    }
    return out;
}

// Applies a graph mutation as an undoable command. `mutate` edits the graph
// data in place (no regenerate); the command's execute performs the actual
// regenerate. On regeneration failure the graph is rolled back to `before`
// and false is returned.
bool SxDocument::apply_graph_edit(const std::string& label,
                                  const std::function<bool()>& mutate) {
    nlohmann::json before = doc_->graph().to_json();
    if (!mutate()) return false;
    nlohmann::json after = doc_->graph().to_json();
    std::string err;
    if (!doc_->graph().regenerate(*doc_, &err)) {
        sx::log::error(label + ": " + err);
        // Blame the offending feature before the revert wipes the graph state;
        // the timeline badges the row if the feature still exists afterwards.
        const sx::EntityId failed = doc_->graph().last_failed_feature();
        last_failed_fid_ = failed.is_null() ? std::string() : failed.str();
        last_graph_error_ = err;
        doc_->set_graph(sx::FeatureGraph::from_json(before));
        doc_->graph().regenerate(*doc_, nullptr);
        return false;
    }
    last_failed_fid_.clear();
    last_graph_error_.clear();
    stack_.push(*doc_, std::make_unique<sx::GraphSnapshotCommand>(label, std::move(before),
                                                                  std::move(after)));
    return true;
}

String SxDocument::graph_add_primitive(const String& kind, double a, double b, double c,
                                       const Vector3& origin) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("add " + to_std(kind), [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Primitive;
        f.params = {{"kind", to_std(kind)}, {"a", a}, {"b", b}, {"c", c},
                    {"origin", {origin.x, origin.y, origin.z}}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_sketch(const Ref<SxSketch>& sketch) {
    if (sketch.is_null()) return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("add sketch", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Sketch;
        f.sketch = sketch->sketch();
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

Ref<SxSketch> SxDocument::graph_get_sketch(const String& fid) const {
    const sx::Feature* f = doc_->graph().feature(parse_id(fid));
    if (f == nullptr || f->type != sx::FeatureType::Sketch || !f->sketch) {
        return {};
    }
    // Deep copy so edits don't mutate the graph until graph_update_sketch.
    auto copy = sx::sketch_from_json(sx::sketch_to_json(*f->sketch));
    Ref<SxSketch> out;
    out.instantiate();
    out->adopt(std::move(copy));
    return out;
}

bool SxDocument::graph_update_sketch(const String& fid, const Ref<SxSketch>& sketch) {
    if (sketch.is_null()) return false;
    return apply_graph_edit("edit sketch", [&] {
        sx::Feature* f = doc_->graph().feature(parse_id(fid));
        if (f == nullptr || f->type != sx::FeatureType::Sketch) return false;
        f->sketch = sketch->sketch();
        return true;
    });
}

String SxDocument::graph_add_extrude(const String& sketch_fid, double distance,
                                     bool symmetric, const String& op,
                                     const String& target_fid) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("extrude", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Extrude;
        f.params = {{"sketch", to_std(sketch_fid)}, {"distance", distance},
                    {"symmetric", symmetric}, {"op", to_std(op)}};
        if (!target_fid.is_empty()) f.params["target"] = to_std(target_fid);
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_revolve(const String& sketch_fid, const Vector2& axis_point,
                                     const Vector2& axis_dir, double angle, const String& op,
                                     const String& target_fid) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("revolve", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Revolve;
        f.params = {{"sketch", to_std(sketch_fid)},
                    {"axis_point", {axis_point.x, axis_point.y}},
                    {"axis_dir", {axis_dir.x, axis_dir.y}},
                    {"angle", angle},
                    {"op", to_std(op)}};
        if (!target_fid.is_empty()) f.params["target"] = to_std(target_fid);
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_sweep(const String& sketch_fid, const PackedVector3Array& path) {
    if (path.size() < 2) return {};
    nlohmann::json path_json = nlohmann::json::array();
    for (int i = 0; i < path.size(); ++i) {
        const Vector3& p = path[i];
        path_json.push_back({p.x, p.y, p.z});
    }
    sx::EntityId fid;
    bool ok = apply_graph_edit("sweep", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Sweep;
        f.params["sketch"] = to_std(sketch_fid);
        f.params["path"] = path_json;
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_sweep_along_path(const String& sketch_fid, const String& path_fid) {
    if (sketch_fid.is_empty() || path_fid.is_empty()) return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("sweep", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Sweep;
        f.params["sketch"] = to_std(sketch_fid);
        f.params["path_feature"] = to_std(path_fid);
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_path(const PackedStringArray& sketch_fids, const String& mode) {
    if (sketch_fids.size() < 2) return {};
    nlohmann::json sketches = nlohmann::json::array();
    for (int i = 0; i < sketch_fids.size(); ++i) sketches.push_back(to_std(sketch_fids[i]));
    std::string m = to_std(mode);
    if (m.empty()) m = "join_endpoints";
    sx::EntityId fid;
    bool ok = apply_graph_edit("path", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Path;
        f.params["sketches"] = sketches;
        f.params["mode"] = m;
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_loft(const PackedStringArray& sketch_fids, bool ruled,
                                  const PackedStringArray& guide_fids) {
    if (sketch_fids.size() < 2) return {};
    nlohmann::json sketches = nlohmann::json::array();
    for (int i = 0; i < sketch_fids.size(); ++i) sketches.push_back(to_std(sketch_fids[i]));
    nlohmann::json guides = nlohmann::json::array();
    for (int i = 0; i < guide_fids.size(); ++i) guides.push_back(to_std(guide_fids[i]));
    sx::EntityId fid;
    bool ok = apply_graph_edit("loft", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Loft;
        f.params["sketches"] = sketches;
        f.params["ruled"] = ruled;
        if (!guides.empty()) f.params["guides"] = guides;
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_dressup(bool fillet, const String& target_fid,
                                     const PackedStringArray& edge_ids, double value) {
    // Convert stable edge ids to the 1-based map indices stored in params.
    std::vector<int> indices;
    for (int i = 0; i < edge_ids.size(); ++i) {
        auto ref = doc_->find_subshape(parse_id(edge_ids[i]));
        if (!ref || ref->kind != sx::EntityKind::Edge) {
            sx::log::error("graph_add_dressup: not an edge id");
            return {};
        }
        indices.push_back(ref->index);
    }
    sx::EntityId fid;
    bool ok = apply_graph_edit(fillet ? "fillet" : "chamfer", [&] {
        sx::Feature f;
        f.type = fillet ? sx::FeatureType::Fillet : sx::FeatureType::Chamfer;
        f.params = {{"target", to_std(target_fid)},
                    {fillet ? "radius" : "distance", value},
                    {"edges", indices}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_fillet(const String& target_fid, const PackedStringArray& edge_ids,
                                    double radius) {
    return graph_add_dressup(true, target_fid, edge_ids, radius);
}

String SxDocument::graph_add_chamfer(const String& target_fid, const PackedStringArray& edge_ids,
                                     double distance) {
    return graph_add_dressup(false, target_fid, edge_ids, distance);
}

String SxDocument::graph_add_hole(const String& target_fid, const String& type,
                                  const Vector3& position, const Vector3& direction,
                                  float diameter, float depth, float cb_diameter, float cb_depth,
                                  float cs_diameter, float cs_angle_deg) {
    if (diameter <= 0.0f) return {};
    std::string htype = to_std(type);
    if (htype != "simple" && htype != "counterbore" && htype != "countersink") return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("hole", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Hole;
        f.params = {{"target", to_std(target_fid)},
                    {"type", htype},
                    {"position", {position.x, position.y, position.z}},
                    {"direction", {direction.x, direction.y, direction.z}},
                    {"diameter", static_cast<double>(diameter)},
                    {"depth", static_cast<double>(depth)},
                    {"cb_diameter", static_cast<double>(cb_diameter)},
                    {"cb_depth", static_cast<double>(cb_depth)},
                    {"cs_diameter", static_cast<double>(cs_diameter)},
                    {"cs_angle_deg", static_cast<double>(cs_angle_deg)}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_import_step(const String& path, float scale) {
    if (path.is_empty()) return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("import step", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::ImportStep;
        f.params = {{"path", to_std(path)},
                    {"index", 0},
                    {"scale", static_cast<double>(scale)}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_import_stl(const String& path, float scale) {
    if (path.is_empty()) return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("import stl", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::ImportStl;
        f.params = {{"path", to_std(path)},
                    {"scale", static_cast<double>(scale)}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_boolean(const String& op, const String& target_fid,
                                     const String& tool_fid) {
    if (target_fid.is_empty() || tool_fid.is_empty() || target_fid == tool_fid) return {};
    std::string op_name = to_std(op);
    if (op_name != "fuse" && op_name != "cut" && op_name != "common") return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit(op_name, [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Boolean;
        f.params = {{"op", op_name},
                    {"target", to_std(target_fid)},
                    {"tool", to_std(tool_fid)}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

bool SxDocument::graph_set_params(const String& fid, const String& params_json) {
    nlohmann::json p;
    try {
        p = nlohmann::json::parse(to_std(params_json));
    } catch (...) {
        return false;
    }
    return apply_graph_edit("edit feature", [&] {
        return doc_->graph().set_params(parse_id(fid), std::move(p));
    });
}

bool SxDocument::graph_set_params_no_regen(const String& fid, const String& params_json) {
    nlohmann::json p;
    try {
        p = nlohmann::json::parse(to_std(params_json));
    } catch (...) {
        return false;
    }
    return doc_->graph().set_params(parse_id(fid), std::move(p));
}

bool SxDocument::graph_set_suppressed(const String& fid, bool suppressed) {
    return apply_graph_edit(suppressed ? "suppress feature" : "unsuppress feature", [&] {
        return doc_->graph().set_suppressed(parse_id(fid), suppressed);
    });
}

bool SxDocument::graph_remove(const String& fid) {
    return apply_graph_edit("delete feature", [&] {
        return doc_->graph().remove(parse_id(fid));
    });
}

bool SxDocument::graph_move(const String& fid, int new_index) {
    return apply_graph_edit("move feature", [&] {
        return doc_->graph().move(parse_id(fid), new_index);
    });
}

bool SxDocument::graph_rename(const String& fid, const String& name) {
    return apply_graph_edit("rename feature", [&] {
        return doc_->graph().rename(parse_id(fid), to_std(name));
    });
}

Dictionary SxDocument::graph_regenerate() {
    Dictionary out;
    std::string err;
    bool ok = doc_->graph().regenerate(*doc_, &err);
    if (ok) {
        last_failed_fid_.clear();
        last_graph_error_.clear();
    } else {
        const sx::EntityId failed = doc_->graph().last_failed_feature();
        last_failed_fid_ = failed.is_null() ? std::string() : failed.str();
        last_graph_error_ = err;
    }
    out["ok"] = ok;
    out["error"] = to_gd(err);
    return out;
}

bool SxDocument::graph_set_rollback(int index) {
    return apply_graph_edit("rollback", [&] {
        return doc_->graph().set_rollback(index);
    });
}

int SxDocument::graph_rollback() const {
    return doc_->graph().rollback();
}

bool SxDocument::set_variable(const String& name, const String& expr) {
    if (name.is_empty()) return false;
    return apply_graph_edit("set variable", [&] {
        doc_->graph().variables().set(to_std(name), to_std(expr));
        return true;
    });
}

bool SxDocument::remove_variable(const String& name) {
    // Unlike other graph edits, keep the removal even when regenerate fails
    // (features may still reference the name). Undo restores the prior
    // snapshot; graph_regenerate exposes the error.
    nlohmann::json before = doc_->graph().to_json();
    if (!doc_->graph().variables().remove(to_std(name))) return false;
    nlohmann::json after = doc_->graph().to_json();
    std::string err;
    if (!doc_->graph().regenerate(*doc_, &err) && !err.empty()) {
        sx::log::error(std::string("remove variable: ") + err);
    }
    stack_.push(*doc_, std::make_unique<sx::GraphSnapshotCommand>(
        "remove variable", std::move(before), std::move(after)));
    return true;
}

Array SxDocument::list_variables() const {
    Array out;
    std::map<std::string, double> values;
    std::string eval_err;
    try {
        values = doc_->graph().variables().evaluate();
    } catch (const std::exception& e) {
        eval_err = e.what();
    }
    const double nan = std::numeric_limits<double>::quiet_NaN();
    for (const auto& e : doc_->graph().variables().entries()) {
        Dictionary d;
        d["name"] = to_gd(e.first);
        d["expr"] = to_gd(e.second);
        auto it = values.find(e.first);
        if (it != values.end()) {
            d["value"] = it->second;
            d["error"] = String();
        } else {
            d["value"] = nan;
            d["error"] = to_gd(eval_err.empty() ? "evaluation failed" : eval_err);
        }
        out.push_back(d);
    }
    return out;
}

bool SxDocument::save(const String& path) {
    std::string err;
    bool ok = sx::save_sxp(*doc_, to_std(path), &err);
    if (!ok) sx::log::error("save failed: " + err);
    return ok;
}

bool SxDocument::load(const String& path) {
    std::string err;
    bool ok = sx::load_sxp(*doc_, to_std(path), &err);
    if (!ok) sx::log::error("load failed: " + err);
    return ok;
}

String SxDocument::add_datum_plane(const Vector3& point, const Vector3& normal) {
    auto id = doc_->add_datum_plane({point.x, point.y, point.z},
                                    {normal.x, normal.y, normal.z});
    return to_gd(id.str());
}

String SxDocument::add_datum_axis(const Vector3& point, const Vector3& dir) {
    auto id =
        doc_->add_datum_axis({point.x, point.y, point.z}, {dir.x, dir.y, dir.z});
    return to_gd(id.str());
}

String SxDocument::add_datum_point(const Vector3& p) {
    auto id = doc_->add_datum_point({p.x, p.y, p.z});
    return to_gd(id.str());
}

Array SxDocument::datum_list() const {
    Array out;
    for (const auto& d : doc_->datums()) {
        Dictionary dict;
        std::visit(
            [&](const auto& x) {
                using T = std::decay_t<decltype(x)>;
                dict["id"] = to_gd(x.id.str());
                dict["name"] = to_gd(x.name);
                if constexpr (std::is_same_v<T, sx::DatumPlane>) {
                    dict["kind"] = "plane";
                    dict["origin"] = Vector3(x.origin[0], x.origin[1], x.origin[2]);
                    dict["normal"] = Vector3(x.normal[0], x.normal[1], x.normal[2]);
                    dict["x_dir"] = Vector3(x.x_dir[0], x.x_dir[1], x.x_dir[2]);
                } else if constexpr (std::is_same_v<T, sx::DatumAxis>) {
                    dict["kind"] = "axis";
                    dict["point"] = Vector3(x.point[0], x.point[1], x.point[2]);
                    dict["direction"] =
                        Vector3(x.direction[0], x.direction[1], x.direction[2]);
                } else if constexpr (std::is_same_v<T, sx::DatumPoint>) {
                    dict["kind"] = "point";
                    dict["position"] =
                        Vector3(x.position[0], x.position[1], x.position[2]);
                }
            },
            d);
        out.push_back(dict);
    }
    return out;
}

bool SxDocument::remove_datum(const String& id) {
    auto eid = parse_id(id);
    if (eid.is_null()) return false;
    return doc_->remove_datum(eid);
}

// Axis-angle (degrees) → unit quaternion (x, y, z, w). Degenerate axis → identity.
static std::array<double, 4> axis_angle_to_quat(const Vector3& axis, double angle_deg) {
    gp_Vec ax(axis.x, axis.y, axis.z);
    if (ax.SquareMagnitude() < 1e-24) return {0, 0, 0, 1};
    ax.Normalize();
    gp_Quaternion q;
    q.SetVectorAndAngle(ax, angle_deg * M_PI / 180.0);
    return {q.X(), q.Y(), q.Z(), q.W()};
}

static void quat_to_axis_angle(const std::array<double, 4>& quat, Vector3& axis_out,
                               double& angle_deg_out) {
    gp_Quaternion q(quat[0], quat[1], quat[2], quat[3]);
    if (q.Norm() < 1e-12) {
        axis_out = Vector3(0, 0, 1);
        angle_deg_out = 0.0;
        return;
    }
    q.Normalize();
    gp_Vec ax;
    Standard_Real angle = 0.0;
    q.GetVectorAndAngle(ax, angle);
    if (ax.SquareMagnitude() < 1e-24) {
        axis_out = Vector3(0, 0, 1);
        angle_deg_out = 0.0;
        return;
    }
    axis_out = Vector3(static_cast<float>(ax.X()), static_cast<float>(ax.Y()),
                       static_cast<float>(ax.Z()));
    angle_deg_out = angle * 180.0 / M_PI;
}

String SxDocument::add_instance(const String& source_body, const Vector3& translation,
                                const Vector3& rotation_axis, double rotation_angle_deg,
                                const String& name) {
    auto src = parse_id(source_body);
    if (src.is_null()) return {};
    auto quat = axis_angle_to_quat(rotation_axis, rotation_angle_deg);
    auto id = doc_->add_instance(src, {translation.x, translation.y, translation.z}, quat,
                                 to_std(name));
    return id.is_null() ? String() : to_gd(id.str());
}

Array SxDocument::instance_list() const {
    Array out;
    for (const auto& inst : doc_->instances()) {
        Dictionary d;
        d["id"] = to_gd(inst.id.str());
        d["source_body"] = to_gd(inst.source_body.str());
        d["name"] = to_gd(inst.name);
        d["translation"] =
            Vector3(static_cast<float>(inst.translation[0]),
                    static_cast<float>(inst.translation[1]),
                    static_cast<float>(inst.translation[2]));
        Vector3 axis;
        double angle_deg = 0.0;
        quat_to_axis_angle(inst.rotation_quat, axis, angle_deg);
        d["rotation_axis"] = axis;
        d["rotation_angle_deg"] = angle_deg;
        out.push_back(d);
    }
    return out;
}

bool SxDocument::remove_instance(const String& id) {
    auto eid = parse_id(id);
    if (eid.is_null()) return false;
    return doc_->remove_instance(eid);
}

bool SxDocument::set_instance_transform(const String& id, const Vector3& translation,
                                        const Vector3& rotation_axis,
                                        double rotation_angle_deg) {
    auto eid = parse_id(id);
    if (eid.is_null()) return false;
    auto quat = axis_angle_to_quat(rotation_axis, rotation_angle_deg);
    return doc_->set_instance_transform(eid, {translation.x, translation.y, translation.z},
                                        quat);
}

String SxDocument::add_mate(const String& type, const String& instance_a, const String& face_a,
                            const String& instance_b, const String& face_b, double offset,
                            bool flip, const String& name) {
    sx::Mate m;
    try {
        m.type = sx::mate_type_from_string(to_std(type));
    } catch (const std::exception&) {
        return {};
    }
    m.instance_a = parse_id(instance_a);
    m.face_a = parse_id(face_a);
    m.instance_b = parse_id(instance_b);
    m.face_b = parse_id(face_b);
    m.offset = offset;
    m.flip = flip;
    m.name = to_std(name);
    auto id = doc_->add_mate(std::move(m));
    return id.is_null() ? String() : to_gd(id.str());
}

Array SxDocument::mate_list() const {
    Array out;
    for (const auto& m : doc_->mates()) {
        Dictionary d;
        d["id"] = to_gd(m.id.str());
        d["type"] = to_gd(sx::to_string(m.type));
        d["instance_a"] = m.instance_a.is_null() ? String() : to_gd(m.instance_a.str());
        d["face_a"] = m.face_a.is_null() ? String() : to_gd(m.face_a.str());
        d["instance_b"] = m.instance_b.is_null() ? String() : to_gd(m.instance_b.str());
        d["face_b"] = m.face_b.is_null() ? String() : to_gd(m.face_b.str());
        d["offset"] = m.offset;
        d["flip"] = m.flip;
        d["name"] = to_gd(m.name);
        out.push_back(d);
    }
    return out;
}

bool SxDocument::remove_mate(const String& id) {
    auto mid = parse_id(id);
    return !mid.is_null() && doc_->remove_mate(mid);
}

bool SxDocument::solve_mates() { return sx::solve_mates(*doc_); }

bool SxDocument::export_drawing_svg(const String& path, double scale) {
    return sx::drawings::export_three_view_svg(*doc_, to_std(path), scale);
}

void SxDocument::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add_box", "dx", "dy", "dz", "origin"), &SxDocument::add_box);
    ClassDB::bind_method(D_METHOD("add_cylinder", "radius", "height", "origin"), &SxDocument::add_cylinder);
    ClassDB::bind_method(D_METHOD("add_sphere", "radius", "origin"), &SxDocument::add_sphere);
    ClassDB::bind_method(D_METHOD("add_cone", "r1", "r2", "height", "origin"), &SxDocument::add_cone);
    ClassDB::bind_method(D_METHOD("add_torus", "major_r", "minor_r", "origin"), &SxDocument::add_torus);
    ClassDB::bind_method(D_METHOD("extrude_sketch", "sketch", "distance", "symmetric"), &SxDocument::extrude_sketch);
    ClassDB::bind_method(D_METHOD("revolve_sketch", "sketch", "axis_point", "axis_dir", "angle"), &SxDocument::revolve_sketch);
    ClassDB::bind_method(D_METHOD("delete_body", "body_id"), &SxDocument::delete_body);
    ClassDB::bind_method(D_METHOD("translate_body", "body_id", "delta"), &SxDocument::translate_body);
    ClassDB::bind_method(D_METHOD("push_pull", "face_id", "distance"), &SxDocument::push_pull);
    ClassDB::bind_method(D_METHOD("boolean_op", "target_body", "tool_body", "op", "keep_tool"), &SxDocument::boolean_op);
    ClassDB::bind_method(D_METHOD("fillet_edges", "edge_ids", "radius"), &SxDocument::fillet_edges);
    ClassDB::bind_method(D_METHOD("chamfer_edges", "edge_ids", "distance"), &SxDocument::chamfer_edges);
    ClassDB::bind_method(D_METHOD("mirror_body", "body_id", "plane_point", "plane_normal", "keep_original"), &SxDocument::mirror_body);
    ClassDB::bind_method(D_METHOD("linear_pattern", "body_id", "direction", "spacing", "count"), &SxDocument::linear_pattern);
    ClassDB::bind_method(D_METHOD("circular_pattern", "body_id", "axis_point", "axis_dir", "count", "total_angle"), &SxDocument::circular_pattern);
    ClassDB::bind_method(D_METHOD("rotate_body", "body_id", "axis_point", "axis_dir", "angle"), &SxDocument::rotate_body);
    ClassDB::bind_method(D_METHOD("shell_body", "faces_to_remove", "thickness"), &SxDocument::shell_body);
    ClassDB::bind_method(D_METHOD("offset_body", "body_id", "offset"), &SxDocument::offset_body);
    ClassDB::bind_method(D_METHOD("draft_faces", "face_ids", "angle_deg", "pull_dir", "neutral_point",
                                  "neutral_normal"),
                         &SxDocument::draft_faces);
    ClassDB::bind_method(D_METHOD("measure_distance", "a", "b"), &SxDocument::measure_distance);
    ClassDB::bind_method(D_METHOD("closest_point_on", "shape_id", "from"),
                         &SxDocument::closest_point_on);
    ClassDB::bind_method(D_METHOD("face_midpoint", "face_id"), &SxDocument::face_midpoint);
    ClassDB::bind_method(D_METHOD("measure_bbox", "id"), &SxDocument::measure_bbox);
    ClassDB::bind_method(D_METHOD("measure_mass", "body_id"), &SxDocument::measure_mass);
    ClassDB::bind_method(D_METHOD("measure_edge_length", "edge_id"), &SxDocument::measure_edge_length);
    ClassDB::bind_method(D_METHOD("measure_face_area", "face_id"), &SxDocument::measure_face_area);
    ClassDB::bind_method(D_METHOD("measure_face_angle", "f1", "f2"), &SxDocument::measure_face_angle);
    ClassDB::bind_method(D_METHOD("export_step", "path"), &SxDocument::export_step);
    ClassDB::bind_method(D_METHOD("export_stl", "path", "binary"), &SxDocument::export_stl);
    ClassDB::bind_method(D_METHOD("import_step", "path"), &SxDocument::import_step);
    ClassDB::bind_method(D_METHOD("import_stl", "path"), &SxDocument::import_stl);
    ClassDB::bind_method(D_METHOD("get_edge_ids", "body_id"), &SxDocument::get_edge_ids);
    ClassDB::bind_method(D_METHOD("undo"), &SxDocument::undo);
    ClassDB::bind_method(D_METHOD("redo"), &SxDocument::redo);
    ClassDB::bind_method(D_METHOD("can_undo"), &SxDocument::can_undo);
    ClassDB::bind_method(D_METHOD("can_redo"), &SxDocument::can_redo);
    ClassDB::bind_method(D_METHOD("body_ids"), &SxDocument::body_ids);
    ClassDB::bind_method(D_METHOD("body_name", "body_id"), &SxDocument::body_name);
    ClassDB::bind_method(D_METHOD("rename_body", "body_id", "name"), &SxDocument::rename_body);
    ClassDB::bind_method(D_METHOD("set_body_color", "body_id", "color"), &SxDocument::set_body_color);
    ClassDB::bind_method(D_METHOD("get_body_color", "body_id"), &SxDocument::get_body_color);
    ClassDB::bind_method(D_METHOD("set_body_material", "body_id", "material"),
                         &SxDocument::set_body_material);
    ClassDB::bind_method(D_METHOD("body_material", "body_id"), &SxDocument::body_material);
    ClassDB::bind_method(D_METHOD("material_list"), &SxDocument::material_list);
    ClassDB::bind_method(D_METHOD("save_configuration", "name"), &SxDocument::save_configuration);
    ClassDB::bind_method(D_METHOD("activate_configuration", "name"),
                         &SxDocument::activate_configuration);
    ClassDB::bind_method(D_METHOD("remove_configuration", "name"),
                         &SxDocument::remove_configuration);
    ClassDB::bind_method(D_METHOD("configuration_list"), &SxDocument::configuration_list);
    ClassDB::bind_method(D_METHOD("active_configuration"), &SxDocument::active_configuration);
    ClassDB::bind_method(D_METHOD("body_volume", "body_id"), &SxDocument::body_volume);
    ClassDB::bind_method(D_METHOD("revision"), &SxDocument::revision);
    ClassDB::bind_method(D_METHOD("get_mesh", "body_id"), &SxDocument::get_mesh);
    ClassDB::bind_method(D_METHOD("get_face_ids", "body_id"), &SxDocument::get_face_ids);
    ClassDB::bind_method(D_METHOD("get_edge_lines", "body_id"), &SxDocument::get_edge_lines);
    ClassDB::bind_method(D_METHOD("pick", "origin", "direction"), &SxDocument::pick);
    ClassDB::bind_method(D_METHOD("card_markdown", "entity_id"), &SxDocument::card_markdown);
    ClassDB::bind_method(D_METHOD("set_card_alias", "entity_id", "text"), &SxDocument::set_card_alias);
    ClassDB::bind_method(D_METHOD("set_card_notes", "entity_id", "text"), &SxDocument::set_card_notes);
    ClassDB::bind_method(D_METHOD("get_card_alias", "entity_id"), &SxDocument::get_card_alias);
    ClassDB::bind_method(D_METHOD("get_card_notes", "entity_id"), &SxDocument::get_card_notes);
    ClassDB::bind_method(D_METHOD("export_context"), &SxDocument::export_context);
    ClassDB::bind_method(D_METHOD("graph_features"), &SxDocument::graph_features);
    ClassDB::bind_method(D_METHOD("graph_add_primitive", "kind", "a", "b", "c", "origin"), &SxDocument::graph_add_primitive);
    ClassDB::bind_method(D_METHOD("graph_add_sketch", "sketch"), &SxDocument::graph_add_sketch);
    ClassDB::bind_method(D_METHOD("graph_get_sketch", "fid"), &SxDocument::graph_get_sketch);
    ClassDB::bind_method(D_METHOD("graph_update_sketch", "fid", "sketch"),
                         &SxDocument::graph_update_sketch);
    ClassDB::bind_method(D_METHOD("graph_add_extrude", "sketch_fid", "distance", "symmetric", "op", "target_fid"), &SxDocument::graph_add_extrude);
    ClassDB::bind_method(D_METHOD("graph_add_revolve", "sketch_fid", "axis_point", "axis_dir", "angle", "op", "target_fid"), &SxDocument::graph_add_revolve);
    ClassDB::bind_method(D_METHOD("graph_add_sweep", "sketch_fid", "path"), &SxDocument::graph_add_sweep);
    ClassDB::bind_method(D_METHOD("graph_add_sweep_along_path", "sketch_fid", "path_fid"),
                         &SxDocument::graph_add_sweep_along_path);
    ClassDB::bind_method(D_METHOD("graph_add_path", "sketch_fids", "mode"), &SxDocument::graph_add_path);
    ClassDB::bind_method(D_METHOD("graph_add_loft", "sketch_fids", "ruled", "guide_fids"),
                         &SxDocument::graph_add_loft, DEFVAL(PackedStringArray()));
    ClassDB::bind_method(D_METHOD("graph_add_fillet", "target_fid", "edge_ids", "radius"), &SxDocument::graph_add_fillet);
    ClassDB::bind_method(D_METHOD("graph_add_chamfer", "target_fid", "edge_ids", "distance"), &SxDocument::graph_add_chamfer);
    ClassDB::bind_method(D_METHOD("graph_add_hole", "target_fid", "type", "position", "direction",
                                  "diameter", "depth", "cb_diameter", "cb_depth", "cs_diameter",
                                  "cs_angle_deg"),
                         &SxDocument::graph_add_hole);
    ClassDB::bind_method(D_METHOD("graph_add_import_step", "path", "scale"),
                         &SxDocument::graph_add_import_step);
    ClassDB::bind_method(D_METHOD("graph_add_import_stl", "path", "scale"),
                         &SxDocument::graph_add_import_stl);
    ClassDB::bind_method(D_METHOD("graph_add_boolean", "op", "target_fid", "tool_fid"),
                         &SxDocument::graph_add_boolean);
    ClassDB::bind_method(D_METHOD("graph_set_params", "fid", "params_json"), &SxDocument::graph_set_params);
    ClassDB::bind_method(D_METHOD("graph_set_params_no_regen", "fid", "params_json"),
                         &SxDocument::graph_set_params_no_regen);
    ClassDB::bind_method(D_METHOD("graph_set_suppressed", "fid", "suppressed"), &SxDocument::graph_set_suppressed);
    ClassDB::bind_method(D_METHOD("graph_remove", "fid"), &SxDocument::graph_remove);
    ClassDB::bind_method(D_METHOD("graph_move", "fid", "new_index"), &SxDocument::graph_move);
    ClassDB::bind_method(D_METHOD("graph_rename", "fid", "name"), &SxDocument::graph_rename);
    ClassDB::bind_method(D_METHOD("graph_set_rollback", "index"), &SxDocument::graph_set_rollback);
    ClassDB::bind_method(D_METHOD("graph_rollback"), &SxDocument::graph_rollback);
    ClassDB::bind_method(D_METHOD("graph_regenerate"), &SxDocument::graph_regenerate);
    ClassDB::bind_method(D_METHOD("set_variable", "name", "expr"), &SxDocument::set_variable);
    ClassDB::bind_method(D_METHOD("remove_variable", "name"), &SxDocument::remove_variable);
    ClassDB::bind_method(D_METHOD("list_variables"), &SxDocument::list_variables);
    ClassDB::bind_method(D_METHOD("save", "path"), &SxDocument::save);
    ClassDB::bind_method(D_METHOD("load", "path"), &SxDocument::load);
    ClassDB::bind_method(D_METHOD("add_datum_plane", "point", "normal"),
                         &SxDocument::add_datum_plane);
    ClassDB::bind_method(D_METHOD("add_datum_axis", "point", "dir"),
                         &SxDocument::add_datum_axis);
    ClassDB::bind_method(D_METHOD("add_datum_point", "p"), &SxDocument::add_datum_point);
    ClassDB::bind_method(D_METHOD("datum_list"), &SxDocument::datum_list);
    ClassDB::bind_method(D_METHOD("remove_datum", "id"), &SxDocument::remove_datum);
    ClassDB::bind_method(D_METHOD("add_instance", "source_body", "translation", "rotation_axis",
                                  "rotation_angle_deg", "name"),
                         &SxDocument::add_instance);
    ClassDB::bind_method(D_METHOD("instance_list"), &SxDocument::instance_list);
    ClassDB::bind_method(D_METHOD("remove_instance", "id"), &SxDocument::remove_instance);
    ClassDB::bind_method(D_METHOD("set_instance_transform", "id", "translation", "rotation_axis",
                                  "rotation_angle_deg"),
                         &SxDocument::set_instance_transform);
    ClassDB::bind_method(D_METHOD("add_mate", "type", "instance_a", "face_a", "instance_b",
                                  "face_b", "offset", "flip", "name"),
                         &SxDocument::add_mate);
    ClassDB::bind_method(D_METHOD("mate_list"), &SxDocument::mate_list);
    ClassDB::bind_method(D_METHOD("remove_mate", "id"), &SxDocument::remove_mate);
    ClassDB::bind_method(D_METHOD("solve_mates"), &SxDocument::solve_mates);
    ClassDB::bind_method(D_METHOD("export_drawing_svg", "path", "scale"),
                         &SxDocument::export_drawing_svg);
}

}  // namespace sx_godot
