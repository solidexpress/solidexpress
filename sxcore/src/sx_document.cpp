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
#include "sx/assembly_ops.hpp"
#include "sx/autodim.hpp"
#include "sx/cam.hpp"
#include "sx/catalog.hpp"
#include "sx/diagnose.hpp"
#include "sx/drawing_doc.hpp"
#include "sx/drawings.hpp"
#include "sx/dxf.hpp"
#include "sx/fea.hpp"
#include "sx/joints.hpp"
#include "sx/pdf.hpp"
#include "sx/print.hpp"
#include "sx/query.hpp"
#include "sx/rules.hpp"
#include "sx/sheet_metal.hpp"
#include "sx/sketch3d.hpp"
#include "sx/specialized.hpp"
#include "sx/user_feature.hpp"
#include "sx/xref.hpp"
#include "sx/materials.hpp"
#include "sx/mates.hpp"
#include "sx/measure.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/sketch_json.hpp"
#include "sx_sketch.hpp"
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
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
    if (!c) return String();
    String md = to_gd(c->to_markdown());
    // Surface the feature digest on the selection card (Wave 3.2).
    for (const auto& f : doc_->graph().timeline()) {
        if (f.output_body == c->id || (!c->relations.empty() && f.output_body == c->relations[0])) {
            md += "\n\n## Feature\n\n";
            md += to_gd(sx::card_digest(f));
            break;
        }
    }
    return md;
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
        String ctx_id;
        if (f.params.contains("context")) ctx_id = to_gd(f.params["context"].get<std::string>());
        d["context_id"] = ctx_id;
        d["context_stale"] = !ctx_id.is_empty() && sx::is_context_stale(*doc_, parse_id(ctx_id));
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
                                     const String& target_fid, const String& end,
                                     double thin_thickness, const String& thin_type,
                                     bool flip_side, const Array& selected_contours) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("extrude", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Extrude;
        std::string end_s = to_std(end);
        if (end_s.empty()) end_s = "blind";
        bool sym = symmetric || end_s == "midplane";
        f.params = {{"sketch", to_std(sketch_fid)}, {"distance", distance},
                    {"symmetric", sym}, {"op", to_std(op)}, {"end", end_s}};
        if (!target_fid.is_empty()) f.params["target"] = to_std(target_fid);
        if (thin_thickness > 0.0) {
            f.params["thin_thickness"] = thin_thickness;
            std::string tt = to_std(thin_type);
            if (tt.empty()) tt = "one_side";
            f.params["thin_type"] = tt;
        }
        // Flip Side applies to thin wall OR open-profile cut (SW Flip Side to Cut).
        if (flip_side) f.params["flip_side"] = true;
        if (selected_contours.size() > 0) {
            nlohmann::json arr = nlohmann::json::array();
            for (int i = 0; i < selected_contours.size(); ++i) {
                arr.push_back(static_cast<int>(selected_contours[i]));
            }
            f.params["selected_contours"] = arr;
        }
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
    if (sketch_fids.size() < 1) return {};
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

Dictionary SxDocument::insert_sxp(const String& path, const Vector3& translation) {
    Dictionary out;
    sx::InsertSxpResult result;
    std::string err;
    bool ok = sx::insert_sxp(*doc_, to_std(path),
                             {translation.x, translation.y, translation.z}, &result, &err);
    out["ok"] = ok;
    out["error"] = to_gd(err);
    PackedStringArray bodies;
    PackedStringArray instances;
    for (const auto& id : result.body_ids) bodies.push_back(to_gd(id.str()));
    for (const auto& id : result.instance_ids) instances.push_back(to_gd(id.str()));
    out["body_ids"] = bodies;
    out["instance_ids"] = instances;
    if (!ok) sx::log::error("insert_sxp failed: " + err);
    return out;
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
        d["fixed"] = inst.fixed;
        d["source_path"] = to_gd(inst.source_path);
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

bool SxDocument::set_instance_fixed(const String& id, bool fixed) {
    auto eid = parse_id(id);
    if (eid.is_null()) return false;
    return doc_->set_instance_fixed(eid, fixed);
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

Dictionary SxDocument::implicit_connector(const String& instance, const String& face) const {
    Dictionary out;
    auto c = sx::implicit_connector(*doc_, parse_id(instance), parse_id(face));
    if (!c) return out;
    out["id"] = to_gd(c->id.str());
    out["instance"] = c->instance.is_null() ? String() : to_gd(c->instance.str());
    out["face"] = to_gd(c->face.str());
    out["origin"] = Vector3(c->origin[0], c->origin[1], c->origin[2]);
    out["z_dir"] = Vector3(c->z_dir[0], c->z_dir[1], c->z_dir[2]);
    out["x_dir"] = Vector3(c->x_dir[0], c->x_dir[1], c->x_dir[2]);
    out["name"] = to_gd(c->name);
    return out;
}

String SxDocument::add_joint(const String& type, const String& instance_a, const String& face_a,
                             const String& instance_b, const String& face_b, const String& name) {
    sx::Joint j;
    try {
        j.type = sx::joint_type_from_string(to_std(type));
    } catch (const std::exception&) {
        return {};
    }
    // Joints ride on connectors, so the two picked faces become the frames.
    // B is captured in the source body's own coordinates: apply_joint places
    // that frame onto A absolutely, so driving a value is repeatable.
    auto ca = sx::implicit_connector(*doc_, parse_id(instance_a), parse_id(face_a));
    auto cb = sx::implicit_connector(*doc_, sx::EntityId{}, parse_id(face_b));
    if (!ca || !cb) return {};
    j.a = *ca;
    j.b = *cb;
    j.b.instance = parse_id(instance_b);
    j.name = to_std(name);
    auto id = doc_->add_joint(std::move(j));
    if (id.is_null()) return {};
    const sx::Joint* stored = doc_->joint(id);
    if (stored) sx::apply_joint(*doc_, *stored, stored->value);
    return to_gd(id.str());
}

Array SxDocument::joint_list() const {
    Array out;
    for (const auto& j : doc_->joints()) {
        Dictionary d;
        d["id"] = to_gd(j.id.str());
        d["type"] = to_gd(sx::to_string(j.type));
        d["instance_b"] = j.b.instance.is_null() ? String() : to_gd(j.b.instance.str());
        d["face_a"] = j.a.face.is_null() ? String() : to_gd(j.a.face.str());
        d["face_b"] = j.b.face.is_null() ? String() : to_gd(j.b.face.str());
        d["value"] = j.value;
        d["unit"] = to_gd(sx::joint_unit(j.type));
        d["limit_min"] = j.limit_min;
        d["limit_max"] = j.limit_max;
        d["has_limits"] = j.has_limits;
        d["name"] = to_gd(j.name);
        out.push_back(d);
    }
    return out;
}

bool SxDocument::remove_joint(const String& id) {
    auto jid = parse_id(id);
    return !jid.is_null() && doc_->remove_joint(jid);
}

bool SxDocument::set_joint_value(const String& id, double value) {
    auto jid = parse_id(id);
    if (jid.is_null() || !doc_->set_joint_value(jid, value)) return false;
    const sx::Joint* j = doc_->joint(jid);
    return j != nullptr && sx::apply_joint(*doc_, *j, j->value);
}

int SxDocument::solve_joints() { return sx::solve_joints(*doc_); }

int SxDocument::explode_assembly(double factor) { return sx::explode(*doc_, factor); }

bool SxDocument::is_exploded() const { return sx::is_exploded(*doc_); }

PackedStringArray SxDocument::pattern_instance(const String& instance, int count,
                                               double total_angle) {
    PackedStringArray out;
    std::string err;
    for (const auto& id : sx::pattern_instance(*doc_, parse_id(instance), count, total_angle, &err))
        out.push_back(to_gd(id.str()));
    if (out.is_empty() && !err.empty()) sx::log::warn("pattern_instance: " + err);
    return out;
}

Array SxDocument::connector_list() const {
    Array out;
    for (const auto& c : doc_->connectors()) {
        Dictionary d;
        d["id"] = to_gd(c.id.str());
        d["instance"] = c.instance.is_null() ? String() : to_gd(c.instance.str());
        d["face"] = c.face.is_null() ? String() : to_gd(c.face.str());
        d["origin"] = Vector3(c.origin[0], c.origin[1], c.origin[2]);
        d["z_dir"] = Vector3(c.z_dir[0], c.z_dir[1], c.z_dir[2]);
        d["x_dir"] = Vector3(c.x_dir[0], c.x_dir[1], c.x_dir[2]);
        d["name"] = to_gd(c.name);
        out.push_back(d);
    }
    return out;
}

String SxDocument::graph_add_extrude_end(const String& sketch_fid, double distance,
                                         const String& end, const String& op,
                                         const String& target_fid) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("extrude", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Extrude;
        const std::string end_s = to_std(end);
        f.params = {{"sketch", to_std(sketch_fid)},
                    {"distance", distance},
                    {"end", end_s.empty() ? "blind" : end_s},
                    {"symmetric", end_s == "symmetric"},
                    {"op", to_std(op)}};
        if (!target_fid.is_empty()) f.params["target"] = to_std(target_fid);
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_fillet_var(const String& target_fid, const PackedStringArray& edge_ids,
                                        double radius, double radius2) {
    String id = graph_add_dressup(true, target_fid, edge_ids, radius);
    if (id.is_empty() || std::abs(radius2 - radius) < 1e-12) return id;
    sx::Feature* f = doc_->graph().feature(parse_id(id));
    if (f == nullptr) return id;
    f->params["radius2"] = radius2;
    apply_graph_edit("fillet radius2", [&] { return true; });
    return id;
}

String SxDocument::graph_add_direct_edit(const String& target_fid, const String& kind,
                                         const String& face_id, double distance,
                                         const Vector3& direction) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("direct edit", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::DirectEdit;
        f.params = {{"target", to_std(target_fid)},
                    {"kind", to_std(kind)},
                    {"face", to_std(face_id)},
                    {"distance", distance},
                    {"direction", {direction.x, direction.y, direction.z}}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_shell(const String& target_fid, const PackedStringArray& face_ids,
                                   double thickness) {
    nlohmann::json faces = nlohmann::json::array();
    for (int i = 0; i < face_ids.size(); ++i) {
        auto ref = doc_->find_subshape(parse_id(face_ids[i]));
        if (!ref || ref->kind != sx::EntityKind::Face) {
            sx::log::error("graph_add_shell: not a face id");
            return {};
        }
        faces.push_back(to_std(face_ids[i]));
    }
    if (faces.empty()) return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("shell", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Shell;
        f.params = {{"target", to_std(target_fid)}, {"faces", faces}, {"thickness", thickness}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_helix(float profile_radius, float helix_radius, float pitch,
                                   float turns, bool left_handed, const Vector3& axis_point,
                                   const Vector3& axis_dir) {
    if (profile_radius <= 0.0f || helix_radius <= 0.0f || pitch <= 0.0f || turns <= 0.0f)
        return {};
    if (axis_dir.length_squared() < 1e-12f) return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("helix", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::HelixSweep;
        f.params = {{"profile_radius", static_cast<double>(profile_radius)},
                    {"radius", static_cast<double>(helix_radius)},
                    {"pitch", static_cast<double>(pitch)},
                    {"turns", static_cast<double>(turns)},
                    {"left_handed", left_handed},
                    {"axis_point", {axis_point.x, axis_point.y, axis_point.z}},
                    {"axis_dir", {axis_dir.x, axis_dir.y, axis_dir.z}}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_holes(const String& target_fid, const String& type,
                                   const PackedVector3Array& positions, const Vector3& direction,
                                   float diameter, float depth, float cb_diameter, float cb_depth,
                                   float cs_diameter, float cs_angle_deg) {
    if (diameter <= 0.0f || positions.is_empty()) return {};
    if (direction.length_squared() < 1e-12f) return {};
    std::string htype = to_std(type);
    if (htype != "simple" && htype != "counterbore" && htype != "countersink") return {};
    nlohmann::json pos_json = nlohmann::json::array();
    for (int i = 0; i < positions.size(); ++i) {
        const Vector3& p = positions[i];
        pos_json.push_back({p.x, p.y, p.z});
    }
    sx::EntityId fid;
    bool ok = apply_graph_edit("holes", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Hole;
        f.params = {{"target", to_std(target_fid)},
                    {"type", htype},
                    {"positions", pos_json},
                    {"position", {positions[0].x, positions[0].y, positions[0].z}},
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

double SxDocument::interference_volume(const String& body_a, const String& body_b) const {
    auto v = sx::measure::interference_volume(*doc_, parse_id(body_a), parse_id(body_b));
    return v ? *v : -1.0;
}

String SxDocument::import_dxf(const String& path) {
    std::string err;
    auto id = sx::import_dxf_sketch(*doc_, to_std(path), &err);
    return id.is_null() ? String() : to_gd(id.str());
}

static Dictionary report_to_dict(const sx::PrintReport& r) {
    Dictionary d;
    d["min_wall"] = r.min_wall;
    d["overhang_area"] = r.overhang_area;
    d["height"] = r.height;
    d["bbox_x"] = r.bbox_x;
    d["bbox_y"] = r.bbox_y;
    d["fits_bed"] = r.fits_bed;
    d["wall_ok"] = r.wall_ok;
    d["overhang_ok"] = r.overhang_ok;
    d["digest"] = to_gd(r.digest);
    return d;
}

Dictionary SxDocument::print_analyze(const String& body_id) {
    sx::EntityId id = parse_id(body_id);
    if (id.is_null() && !doc_->body_ids().empty()) id = doc_->body_ids().front();
    return report_to_dict(sx::print_analyze(*doc_, id));
}

Dictionary SxDocument::print_orient(const String& body_id) {
    sx::EntityId id = parse_id(body_id);
    if (id.is_null() && !doc_->body_ids().empty()) id = doc_->body_ids().front();
    return report_to_dict(sx::print_orient(*doc_, id));
}

void SxDocument::set_print_min_wall(double mm) {
    sx::PrintSetup s = doc_->print_setup();
    s.min_wall = mm;
    doc_->set_print_setup(s);
}

Dictionary SxDocument::print_setup() const {
    const sx::PrintSetup& s = doc_->print_setup();
    Dictionary d;
    d["bed_x"] = s.bed_x;
    d["bed_y"] = s.bed_y;
    d["bed_z"] = s.bed_z;
    d["layer_height"] = s.layer_height;
    d["min_wall"] = s.min_wall;
    d["overhang_deg"] = s.overhang_deg;
    return d;
}

bool SxDocument::export_3mf(const String& path) {
    std::string err;
    return sx::interop::export_3mf(*doc_, to_std(path), &err);
}

bool SxDocument::export_gltf(const String& path) {
    std::string err;
    return sx::interop::export_gltf(*doc_, to_std(path), &err);
}

String SxDocument::graph_add_rib(const String& target_fid, const String& sketch_fid,
                                 double thickness, double height, bool flip) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("rib", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Rib;
        f.params = {{"target", to_std(target_fid)},
                    {"sketch", to_std(sketch_fid)},
                    {"thickness", thickness},
                    {"height", height},
                    {"flip", flip}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_flange(double length, double thickness, double k_factor, double radius,
                                    double width) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("flange", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Flange;
        f.params = {{"length", length},
                    {"thickness", thickness},
                    {"k_factor", k_factor},
                    {"radius", radius},
                    {"width", width},
                    {"angle_rad", 1.5707963267948966}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_frame(const PackedVector3Array& path, double profile_w,
                                   double profile_h) {
    if (path.size() < 2) return {};
    nlohmann::json pj = nlohmann::json::array();
    for (int i = 0; i < path.size(); ++i)
        pj.push_back({path[i].x, path[i].y, path[i].z});
    sx::EntityId fid;
    bool ok = apply_graph_edit("frame", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::FrameMember;
        f.params = {{"path", pj}, {"profile_w", profile_w}, {"profile_h", profile_h}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

Array SxDocument::run_query(const String& query) const {
    Array out;
    for (const auto& h : sx::run_query(*doc_, to_std(query))) {
        Dictionary d;
        d["id"] = to_gd(h.id.str());
        d["kind"] = to_gd(h.kind);
        out.push_back(d);
    }
    return out;
}

String SxDocument::card_digest(const String& fid) const {
    const sx::Feature* f = doc_->graph().feature(parse_id(fid));
    return f ? to_gd(sx::card_digest(*f)) : String();
}

int SxDocument::apply_rule(const String& when, const String& then) {
    sx::Rule r{"ui", to_std(when), to_std(then)};
    return sx::apply_rules(doc_->graph(), {r});
}

double SxDocument::crank_slider_x(double crank, double rod, double theta) const {
    return sx::crank_slider_x(crank, rod, theta);
}

double SxDocument::sheet_flat_length(double leg1, double leg2, double thickness, double k_factor,
                                     double radius) const {
    return sx::sheet::flat_length(leg1, leg2, thickness, k_factor, radius);
}

PackedVector3Array SxDocument::cam_pocket(double x0, double y0, double x1, double y1, double depth,
                                          double stepover) const {
    auto tp = sx::cam::pocket_rect(x0, y0, x1, y1, depth, stepover);
    PackedVector3Array out;
    for (const auto& p : tp.points) out.push_back(Vector3(p[0], p[1], p[2]));
    return out;
}

double SxDocument::fea_cantilever(double force_n, double length_mm, double e_mpa, double width_mm,
                                  double thickness_mm) const {
    return sx::fea::cantilever_deflection(force_n, length_mm, e_mpa,
                                          sx::fea::rect_inertia(width_mm, thickness_mm));
}

Dictionary SxDocument::catalog_fastener(const String& designation) const {
    Dictionary d;
    auto f = sx::catalog::find_fastener(to_std(designation));
    if (!f) return d;
    d["designation"] = to_gd(f->designation);
    d["diameter"] = f->diameter_mm;
    d["length"] = f->length_mm;
    d["kind"] = to_gd(f->kind);
    return d;
}

String SxDocument::heal_report(const String& fid) const {
    const sx::Feature* f = doc_->graph().feature(parse_id(fid));
    if (f == nullptr || !f->params.contains("heal_report")) return {};
    return to_gd(f->params["heal_report"].get<std::string>());
}

bool SxDocument::export_drawing_svg(const String& path, double scale) {
    return sx::drawings::export_three_view_svg(*doc_, to_std(path), scale);
}

String SxDocument::capture_context(const String& source_body, const String& name) {
    std::string err;
    auto id = sx::capture_context(*doc_, parse_id(source_body), to_std(name), &err);
    if (id.is_null() && !err.empty()) sx::log::warn("capture_context: " + err);
    return id.is_null() ? String() : to_gd(id.str());
}

bool SxDocument::is_context_stale(const String& context_id) const {
    return sx::is_context_stale(*doc_, parse_id(context_id));
}

bool SxDocument::update_context(const String& context_id) {
    std::string err;
    if (!sx::update_context(*doc_, parse_id(context_id), &err)) return false;
    std::string regen_err;
    return doc_->graph().regenerate(*doc_, &regen_err);
}

String SxDocument::graph_add_in_context(const String& context_id, double a, double b) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("in_context", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::InContext;
        f.params = {{"context", to_std(context_id)}, {"a", a}, {"b", b}};
        fid = doc_->graph().add(std::move(f));
        if (auto* ctx = doc_->context_mut(parse_id(context_id))) ctx->consumer_feature = fid;
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

Array SxDocument::context_list() const {
    Array out;
    for (const auto& c : doc_->contexts()) {
        Dictionary d;
        d["id"] = to_gd(c.id.str());
        d["name"] = to_gd(c.name);
        d["source_body"] = to_gd(c.source_body.str());
        d["stale"] = sx::is_context_stale(*doc_, c.id);
        d["height"] = c.height;
        out.push_back(d);
    }
    return out;
}

String SxDocument::ensure_drawing_sheet() {
    return to_gd(sx::ensure_drawing_sheet(*doc_).str());
}

String SxDocument::add_drawing_dim(const String& entity_a, const String& entity_b) {
    const sx::EntityId sheet = sx::ensure_drawing_sheet(*doc_);
    sx::EntityId view;
    if (const auto* s = doc_->drawing_sheet(sheet); s && !s->views.empty()) view = s->views.front().id;
    return to_gd(sx::add_drawing_dim(*doc_, sheet, view, parse_id(entity_a),
                                     entity_b.is_empty() ? sx::EntityId{} : parse_id(entity_b))
                     .str());
}

int SxDocument::refresh_drawing_dims() { return sx::refresh_drawing_dims(*doc_); }

Array SxDocument::bom_rows() const {
    Array out;
    for (const auto& r : sx::bom_from_instances(*doc_)) {
        Dictionary d;
        d["item"] = r.item;
        d["name"] = to_gd(r.name);
        d["qty"] = r.qty;
        d["source"] = to_gd(r.source);
        out.push_back(d);
    }
    return out;
}

Dictionary SxDocument::drawing_preview() const {
    Dictionary out;
    if (doc_->drawing_sheets().empty()) {
        const_cast<SxDocument*>(this)->ensure_drawing_sheet();
    }
    if (doc_->drawing_sheets().empty()) return out;
    const auto& sheet = doc_->drawing_sheets().front();
    out["title"] = to_gd(sheet.title);
    out["scale"] = sheet.scale;
    Array views;
    for (const auto& v : sheet.views) {
        Dictionary dv;
        dv["id"] = to_gd(v.id.str());
        dv["name"] = to_gd(v.name);
        dv["kind"] = to_gd(v.kind);
        dv["offset_x"] = v.offset_x;
        dv["offset_y"] = v.offset_y;
        auto proj = sx::project_drawing_view(*doc_, v);
        auto pack = [](const std::vector<sx::drawings::Polyline2>& pls) {
            Array a;
            for (const auto& pl : pls) {
                PackedVector2Array pv;
                for (const auto& p : pl) pv.push_back(Vector2(p[0], p[1]));
                a.push_back(pv);
            }
            return a;
        };
        dv["visible"] = pack(proj.visible);
        dv["hidden"] = pack(proj.hidden);
        dv["hatch"] = pack(sx::section_hatch(*doc_, v));
        views.push_back(dv);
    }
    out["views"] = views;
    Array dims;
    for (const auto& d : sheet.dims) {
        Dictionary dd;
        dd["id"] = to_gd(d.id.str());
        dd["value"] = d.value;
        dd["kind"] = to_gd(d.kind);
        dims.push_back(dd);
    }
    out["dims"] = dims;
    out["bom"] = bom_rows();
    Array welds;
    for (const auto& w : doc_->welds()) {
        Dictionary dw;
        dw["symbol"] = to_gd(w.symbol);
        dw["size"] = w.size;
        welds.push_back(dw);
    }
    out["welds"] = welds;
    return out;
}

bool SxDocument::export_drawing_dxf(const String& path) {
    std::string err;
    return sx::export_drawing_dxf(*doc_, to_std(path), &err);
}

bool SxDocument::export_drawing_pdf(const String& path) {
    if (doc_->drawing_sheets().empty()) sx::ensure_drawing_sheet(*doc_);
    std::vector<sx::drawings::PlacedView> views;
    if (!doc_->drawing_sheets().empty()) {
        for (const auto& v : doc_->drawing_sheets().front().views) {
            sx::drawings::PlacedView pv;
            pv.view = sx::project_drawing_view(*doc_, v);
            pv.label = v.name;
            pv.offset_x = v.offset_x;
            pv.offset_y = v.offset_y;
            views.push_back(pv);
        }
    }
    return sx::write_pdf(views, to_std(path), 1.0, "SOLIDEXPRESS");
}

String SxDocument::graph_add_convert_sheet(const String& target_fid) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("convert_sheet", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::ConvertSheet;
        f.params = {{"target", to_std(target_fid)}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::add_weld(const String& edge, const String& symbol, double size) {
    sx::CosmeticWeld w;
    w.edge = parse_id(edge);
    w.symbol = to_std(symbol);
    w.size = size;
    return to_gd(doc_->add_weld(std::move(w)).str());
}

Array SxDocument::weld_list() const {
    Array out;
    for (const auto& w : doc_->welds()) {
        Dictionary d;
        d["id"] = to_gd(w.id.str());
        d["edge"] = to_gd(w.edge.str());
        d["symbol"] = to_gd(w.symbol);
        d["size"] = w.size;
        out.push_back(d);
    }
    return out;
}

Dictionary SxDocument::diagnose_feature(const String& fid) const {
    Dictionary d;
    auto diag = sx::diagnose_failed_feature(*doc_, parse_id(fid), last_graph_error_);
    d["feature"] = to_gd(diag.feature.str());
    d["name"] = to_gd(diag.feature_name);
    d["error"] = to_gd(diag.error);
    PackedStringArray released;
    for (const auto& id : diag.released) released.push_back(to_gd(id.str()));
    d["released"] = released;
    PackedStringArray repairs;
    for (const auto& r : diag.repairs) repairs.push_back(to_gd(r));
    d["repairs"] = repairs;
    return d;
}

int SxDocument::auto_dimension() {
    for (auto it = doc_->graph().timeline().rbegin(); it != doc_->graph().timeline().rend(); ++it) {
        if (it->type == sx::FeatureType::Sketch && it->sketch)
            return sx::auto_dimension(*it->sketch);
    }
    return 0;
}

Array SxDocument::propose_chips() const {
    Array out;
    for (auto it = doc_->graph().timeline().rbegin(); it != doc_->graph().timeline().rend(); ++it) {
        if (it->type != sx::FeatureType::Sketch || !it->sketch) continue;
        for (const auto& c : sx::propose_on_select(*it->sketch, {})) {
            Dictionary d;
            d["verb"] = to_gd(c.verb);
            d["a"] = to_gd(c.a.str());
            d["b"] = to_gd(c.b.str());
            d["score"] = c.score;
            out.push_back(d);
        }
        break;
    }
    return out;
}

String SxDocument::graph_add_user_csink(const String& target_fid, const Vector3& pos, double diameter,
                                        double depth, double cs_diameter) {
    std::string err;
    nlohmann::json args = {{"target", to_std(target_fid)},
                           {"x", pos.x},
                           {"y", pos.y},
                           {"z", pos.z},
                           {"diameter", diameter},
                           {"depth", depth},
                           {"cs_diameter", cs_diameter}};
    auto id = sx::instantiate_user_feature(*doc_, sx::user_csink_recipe(), args, &err);
    return id.is_null() ? String() : to_gd(id.str());
}

String SxDocument::add_sketch3d(const PackedVector3Array& points) {
    sx::Sketch3D s;
    for (int i = 0; i < points.size(); ++i) {
        const Vector3 p = points[i];
        s.points.push_back({p.x, p.y, p.z});
    }
    return to_gd(doc_->add_sketch3d(std::move(s)).str());
}

int SxDocument::convert_edges(const String& sketch_fid, const PackedStringArray& edge_ids) {
    std::vector<sx::EntityId> ids;
    for (int i = 0; i < edge_ids.size(); ++i) ids.push_back(parse_id(edge_ids[i]));
    std::string err;
    return sx::convert_edges_to_sketch(*doc_, parse_id(sketch_fid), ids, &err);
}

int SxDocument::pdm_commit(const String& message) {
    sx::pdm_commit(*doc_, to_std(message));
    return static_cast<int>(doc_->pdm_entries().size());
}

Array SxDocument::pdm_log() const {
    Array out;
    for (const auto& e : sx::pdm_log(*doc_)) {
        Dictionary d;
        d["message"] = to_gd(e.message);
        d["revision"] = static_cast<int>(e.revision);
        out.push_back(d);
    }
    return out;
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
    ClassDB::bind_method(D_METHOD("graph_add_extrude", "sketch_fid", "distance", "symmetric", "op",
                                  "target_fid", "end", "thin_thickness", "thin_type", "flip_side",
                                  "selected_contours"),
                         &SxDocument::graph_add_extrude, DEFVAL(String("blind")), DEFVAL(0.0),
                         DEFVAL(String("one_side")), DEFVAL(false), DEFVAL(Array()));
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
    ClassDB::bind_method(D_METHOD("insert_sxp", "path", "translation"), &SxDocument::insert_sxp);
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
    ClassDB::bind_method(D_METHOD("set_instance_fixed", "id", "fixed"),
                         &SxDocument::set_instance_fixed);
    ClassDB::bind_method(D_METHOD("add_mate", "type", "instance_a", "face_a", "instance_b",
                                  "face_b", "offset", "flip", "name"),
                         &SxDocument::add_mate);
    ClassDB::bind_method(D_METHOD("mate_list"), &SxDocument::mate_list);
    ClassDB::bind_method(D_METHOD("remove_mate", "id"), &SxDocument::remove_mate);
    ClassDB::bind_method(D_METHOD("solve_mates"), &SxDocument::solve_mates);
    ClassDB::bind_method(D_METHOD("implicit_connector", "instance", "face"),
                         &SxDocument::implicit_connector);
    ClassDB::bind_method(D_METHOD("connector_list"), &SxDocument::connector_list);
    ClassDB::bind_method(D_METHOD("add_joint", "type", "instance_a", "face_a", "instance_b",
                                  "face_b", "name"),
                         &SxDocument::add_joint);
    ClassDB::bind_method(D_METHOD("joint_list"), &SxDocument::joint_list);
    ClassDB::bind_method(D_METHOD("remove_joint", "id"), &SxDocument::remove_joint);
    ClassDB::bind_method(D_METHOD("set_joint_value", "id", "value"), &SxDocument::set_joint_value);
    ClassDB::bind_method(D_METHOD("solve_joints"), &SxDocument::solve_joints);
    ClassDB::bind_method(D_METHOD("explode_assembly", "factor"), &SxDocument::explode_assembly);
    ClassDB::bind_method(D_METHOD("is_exploded"), &SxDocument::is_exploded);
    ClassDB::bind_method(D_METHOD("pattern_instance", "instance", "count", "total_angle"),
                         &SxDocument::pattern_instance);
    ClassDB::bind_method(D_METHOD("graph_add_extrude_end", "sketch_fid", "distance", "end", "op",
                                  "target_fid"),
                         &SxDocument::graph_add_extrude_end);
    ClassDB::bind_method(D_METHOD("graph_add_fillet_var", "target_fid", "edge_ids", "radius",
                                  "radius2"),
                         &SxDocument::graph_add_fillet_var);
    ClassDB::bind_method(D_METHOD("graph_add_direct_edit", "target_fid", "kind", "face_id",
                                  "distance", "direction"),
                         &SxDocument::graph_add_direct_edit);
    ClassDB::bind_method(D_METHOD("graph_add_holes", "target_fid", "type", "positions", "direction",
                                  "diameter", "depth", "cb_diameter", "cb_depth", "cs_diameter",
                                  "cs_angle_deg"),
                         &SxDocument::graph_add_holes, DEFVAL(0.0f), DEFVAL(0.0f), DEFVAL(0.0f),
                         DEFVAL(90.0f));
    ClassDB::bind_method(D_METHOD("graph_add_shell", "target_fid", "face_ids", "thickness"),
                         &SxDocument::graph_add_shell);
    ClassDB::bind_method(D_METHOD("graph_add_helix", "profile_radius", "helix_radius", "pitch",
                                  "turns", "left_handed", "axis_point", "axis_dir"),
                         &SxDocument::graph_add_helix);
    ClassDB::bind_method(D_METHOD("interference_volume", "body_a", "body_b"),
                         &SxDocument::interference_volume);
    ClassDB::bind_method(D_METHOD("import_dxf", "path"), &SxDocument::import_dxf);
    ClassDB::bind_method(D_METHOD("export_3mf", "path"), &SxDocument::export_3mf);
    ClassDB::bind_method(D_METHOD("export_gltf", "path"), &SxDocument::export_gltf);
    ClassDB::bind_method(D_METHOD("heal_report", "fid"), &SxDocument::heal_report);
    ClassDB::bind_method(
        D_METHOD("graph_add_rib", "target_fid", "sketch_fid", "thickness", "height", "flip"),
        &SxDocument::graph_add_rib, DEFVAL(false));
    ClassDB::bind_method(
        D_METHOD("graph_add_flange", "length", "thickness", "k_factor", "radius", "width"),
        &SxDocument::graph_add_flange, DEFVAL(30.0));
    ClassDB::bind_method(D_METHOD("graph_add_frame", "path", "profile_w", "profile_h"),
                         &SxDocument::graph_add_frame);
    ClassDB::bind_method(D_METHOD("run_query", "query"), &SxDocument::run_query);
    ClassDB::bind_method(D_METHOD("card_digest", "fid"), &SxDocument::card_digest);
    ClassDB::bind_method(D_METHOD("apply_rule", "when", "then"), &SxDocument::apply_rule);
    ClassDB::bind_method(D_METHOD("crank_slider_x", "crank", "rod", "theta"),
                         &SxDocument::crank_slider_x);
    ClassDB::bind_method(D_METHOD("sheet_flat_length", "leg1", "leg2", "thickness", "k_factor",
                                  "radius"),
                         &SxDocument::sheet_flat_length);
    ClassDB::bind_method(D_METHOD("cam_pocket", "x0", "y0", "x1", "y1", "depth", "stepover"),
                         &SxDocument::cam_pocket);
    ClassDB::bind_method(D_METHOD("fea_cantilever", "force_n", "length_mm", "e_mpa", "width_mm",
                                  "thickness_mm"),
                         &SxDocument::fea_cantilever);
    ClassDB::bind_method(D_METHOD("catalog_fastener", "designation"),
                         &SxDocument::catalog_fastener);
    ClassDB::bind_method(D_METHOD("export_drawing_svg", "path", "scale"),
                         &SxDocument::export_drawing_svg);
    ClassDB::bind_method(D_METHOD("capture_context", "source_body", "name"),
                         &SxDocument::capture_context);
    ClassDB::bind_method(D_METHOD("is_context_stale", "context_id"), &SxDocument::is_context_stale);
    ClassDB::bind_method(D_METHOD("update_context", "context_id"), &SxDocument::update_context);
    ClassDB::bind_method(D_METHOD("graph_add_in_context", "context_id", "a", "b"),
                         &SxDocument::graph_add_in_context);
    ClassDB::bind_method(D_METHOD("context_list"), &SxDocument::context_list);
    ClassDB::bind_method(D_METHOD("ensure_drawing_sheet"), &SxDocument::ensure_drawing_sheet);
    ClassDB::bind_method(D_METHOD("add_drawing_dim", "entity_a", "entity_b"),
                         &SxDocument::add_drawing_dim, DEFVAL(String()));
    ClassDB::bind_method(D_METHOD("refresh_drawing_dims"), &SxDocument::refresh_drawing_dims);
    ClassDB::bind_method(D_METHOD("bom_rows"), &SxDocument::bom_rows);
    ClassDB::bind_method(D_METHOD("drawing_preview"), &SxDocument::drawing_preview);
    ClassDB::bind_method(D_METHOD("export_drawing_dxf", "path"), &SxDocument::export_drawing_dxf);
    ClassDB::bind_method(D_METHOD("export_drawing_pdf", "path"), &SxDocument::export_drawing_pdf);
    ClassDB::bind_method(D_METHOD("graph_add_convert_sheet", "target_fid"),
                         &SxDocument::graph_add_convert_sheet);
    ClassDB::bind_method(D_METHOD("add_weld", "edge", "symbol", "size"), &SxDocument::add_weld);
    ClassDB::bind_method(D_METHOD("weld_list"), &SxDocument::weld_list);
    ClassDB::bind_method(D_METHOD("diagnose_feature", "fid"), &SxDocument::diagnose_feature);
    ClassDB::bind_method(D_METHOD("auto_dimension"), &SxDocument::auto_dimension);
    ClassDB::bind_method(D_METHOD("propose_chips"), &SxDocument::propose_chips);
    ClassDB::bind_method(D_METHOD("graph_add_user_csink", "target_fid", "pos", "diameter", "depth",
                                  "cs_diameter"),
                         &SxDocument::graph_add_user_csink);
    ClassDB::bind_method(D_METHOD("add_sketch3d", "points"), &SxDocument::add_sketch3d);
    ClassDB::bind_method(D_METHOD("convert_edges", "sketch_fid", "edge_ids"),
                         &SxDocument::convert_edges);
    ClassDB::bind_method(D_METHOD("pdm_commit", "message"), &SxDocument::pdm_commit);
    ClassDB::bind_method(D_METHOD("pdm_log"), &SxDocument::pdm_log);
    ClassDB::bind_method(D_METHOD("print_analyze", "body_id"), &SxDocument::print_analyze,
                         DEFVAL(String()));
    ClassDB::bind_method(D_METHOD("print_orient", "body_id"), &SxDocument::print_orient,
                         DEFVAL(String()));
    ClassDB::bind_method(D_METHOD("print_setup"), &SxDocument::print_setup);
    ClassDB::bind_method(D_METHOD("set_print_min_wall", "mm"), &SxDocument::set_print_min_wall);
}

}  // namespace sx_godot
