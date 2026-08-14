#include "sx_sketch.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include "sx/sketch_tools.hpp"

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

static sx::PointRole parse_role(const String& s) {
    std::string r = to_std(s);
    if (r == "start") return sx::PointRole::Start;
    if (r == "end") return sx::PointRole::End;
    if (r == "center") return sx::PointRole::Center;
    return sx::PointRole::Self;
}

static std::optional<sx::ConstraintType> parse_constraint_type(const String& s) {
    std::string t = to_std(s);
    using CT = sx::ConstraintType;
    for (CT ct : {CT::Coincident, CT::Horizontal, CT::Vertical, CT::Parallel,
                  CT::Perpendicular, CT::PointOnLine, CT::Tangent, CT::Equal,
                  CT::Distance, CT::Radius, CT::Angle, CT::Concentric, CT::Symmetric,
                  CT::Midpoint, CT::Fix, CT::Collinear}) {
        if (t == sx::to_string(ct)) return ct;
    }
    return std::nullopt;
}

SxSketch::SxSketch()
    : sketch_(std::make_shared<sx::Sketch>("Sketch")),
      solver_(sx::make_planegcs_backend()) {}

void SxSketch::adopt(std::shared_ptr<sx::Sketch> sketch) {
    if (sketch) sketch_ = std::move(sketch);
}

void SxSketch::set_plane(const Vector3& origin, const Vector3& x_dir, const Vector3& y_dir) {
    sx::SketchPlane plane;
    plane.origin = {origin.x, origin.y, origin.z};
    plane.x_dir = {x_dir.x, x_dir.y, x_dir.z};
    plane.y_dir = {y_dir.x, y_dir.y, y_dir.z};
    // Sketch plane is immutable per sketch (features depend on it); recreate,
    // carrying nothing — callers set the plane before drawing.
    sketch_ = std::make_shared<sx::Sketch>(sketch_->name(), plane);
}

Dictionary SxSketch::plane_info() const {
    Dictionary out;
    if (!sketch_) return out;
    const auto& p = sketch_->plane();
    out["origin"] = Vector3(p.origin[0], p.origin[1], p.origin[2]);
    out["x_dir"] = Vector3(p.x_dir[0], p.x_dir[1], p.x_dir[2]);
    out["y_dir"] = Vector3(p.y_dir[0], p.y_dir[1], p.y_dir[2]);
    auto n = p.normal();
    out["normal"] = Vector3(n[0], n[1], n[2]);
    return out;
}

String SxSketch::add_point(double x, double y) {
    return to_gd(sketch_->add_point(x, y).str());
}
String SxSketch::add_line(double x1, double y1, double x2, double y2) {
    return to_gd(sketch_->add_line(x1, y1, x2, y2).str());
}
String SxSketch::add_circle(double cx, double cy, double r) {
    return to_gd(sketch_->add_circle(cx, cy, r).str());
}
String SxSketch::add_arc(double cx, double cy, double r, double a0, double a1) {
    return to_gd(sketch_->add_arc(cx, cy, r, a0, a1).str());
}

bool SxSketch::remove_entity(const String& id) {
    return sketch_->remove_entity(parse_id(id));
}

void SxSketch::set_construction(const String& id, bool construction) {
    sketch_->set_construction(parse_id(id), construction);
}

bool SxSketch::is_construction(const String& id) const {
    return sketch_->is_construction(parse_id(id));
}

PackedStringArray SxSketch::entity_ids() const {
    PackedStringArray out;
    for (const auto& e : sketch_->entities()) out.push_back(to_gd(e.id.str()));
    return out;
}

String SxSketch::fillet_corner(const String& line_a_id, const String& line_b_id,
                               double radius) {
    return to_gd(sx::sketch_tools::fillet_corner(*sketch_, to_std(line_a_id),
                                                 to_std(line_b_id), radius));
}

PackedStringArray SxSketch::offset_entities(const PackedStringArray& ids,
                                            double distance) {
    std::vector<std::string> entity_ids;
    entity_ids.reserve(ids.size());
    for (int i = 0; i < ids.size(); ++i) entity_ids.push_back(to_std(ids[i]));
    auto result = sx::sketch_tools::offset_entities(*sketch_, entity_ids, distance);
    PackedStringArray out;
    for (const auto& id : result) out.push_back(to_gd(id));
    return out;
}

bool SxSketch::trim_entity(const String& id, double px, double py) {
    return sx::sketch_tools::trim_entity(*sketch_, to_std(id), px, py);
}

bool SxSketch::extend_entity(const String& id, double px, double py) {
    return sx::sketch_tools::extend_entity(*sketch_, to_std(id), px, py);
}

PackedStringArray SxSketch::pattern_entities(const PackedStringArray& ids,
                                             double dx, double dy, int count) {
    std::vector<std::string> entity_ids;
    entity_ids.reserve(ids.size());
    for (int i = 0; i < ids.size(); ++i) entity_ids.push_back(to_std(ids[i]));
    auto result = sx::sketch_tools::pattern_entities(*sketch_, entity_ids, dx, dy, count);
    PackedStringArray out;
    for (const auto& rid : result) out.push_back(to_gd(rid));
    return out;
}

Dictionary SxSketch::entity_info(const String& id) const {
    Dictionary out;
    const sx::SketchEntity* e = sketch_->entity(parse_id(id));
    if (!e) return out;
    auto p = [&](size_t i) { return sketch_->param(e->params[i]); };
    out["construction"] = e->construction;
    switch (e->type) {
        case sx::SketchEntityType::Point:
            out["type"] = "point";
            out["position"] = Vector2(p(0), p(1));
            break;
        case sx::SketchEntityType::Line:
            out["type"] = "line";
            out["start"] = Vector2(p(0), p(1));
            out["end"] = Vector2(p(2), p(3));
            break;
        case sx::SketchEntityType::Circle:
            out["type"] = "circle";
            out["center"] = Vector2(p(0), p(1));
            out["radius"] = p(2);
            break;
        case sx::SketchEntityType::Arc:
            out["type"] = "arc";
            out["center"] = Vector2(p(0), p(1));
            out["radius"] = p(2);
            out["start_angle"] = p(3);
            out["end_angle"] = p(4);
            out["start"] = Vector2(p(5), p(6));
            out["end"] = Vector2(p(7), p(8));
            break;
    }
    return out;
}

bool SxSketch::set_entity_geometry(const String& id, const Dictionary& geo) {
    const sx::SketchEntity* e = sketch_->entity(parse_id(id));
    if (!e) return false;
    auto set = [&](size_t i, double v) { sketch_->param_mut(e->params[i]) = v; };
    auto set_vec = [&](const char* key, size_t ix, size_t iy) {
        if (!geo.has(key)) return;
        Vector2 v = geo[key];
        set(ix, v.x);
        set(iy, v.y);
    };
    auto set_num = [&](const char* key, size_t i) {
        if (geo.has(key)) set(i, static_cast<double>(geo[key]));
    };
    switch (e->type) {
        case sx::SketchEntityType::Point:
            set_vec("position", 0, 1);
            break;
        case sx::SketchEntityType::Line:
            set_vec("start", 0, 1);
            set_vec("end", 2, 3);
            break;
        case sx::SketchEntityType::Circle:
            set_vec("center", 0, 1);
            set_num("radius", 2);
            break;
        case sx::SketchEntityType::Arc:
            set_vec("center", 0, 1);
            set_num("radius", 2);
            set_num("start_angle", 3);
            set_num("end_angle", 4);
            set_vec("start", 5, 6);
            set_vec("end", 7, 8);
            break;
    }
    return true;
}

String SxSketch::add_constraint(const String& type, const Array& refs, double value) {
    auto ct = parse_constraint_type(type);
    if (!ct) return {};
    std::vector<sx::PointRef> prefs;
    for (int i = 0; i < refs.size(); ++i) {
        Dictionary d = refs[i];
        sx::PointRef pr;
        pr.entity = parse_id(d.get("entity", ""));
        pr.role = parse_role(d.get("role", "self"));
        if (pr.entity.is_null()) return {};
        prefs.push_back(pr);
    }
    return to_gd(sketch_->add_constraint(*ct, std::move(prefs), value).str());
}

bool SxSketch::remove_constraint(const String& id) {
    return sketch_->remove_constraint(parse_id(id));
}

bool SxSketch::set_constraint_value(const String& id, double value) {
    return sketch_->set_constraint_value(parse_id(id), value);
}

bool SxSketch::set_constraint_weak(const String& id, bool weak) {
    return sketch_->set_constraint_weak(parse_id(id), weak);
}

int SxSketch::drop_weak_constraints() {
    return sketch_->drop_weak_constraints();
}

PackedStringArray SxSketch::constraint_ids() const {
    PackedStringArray out;
    for (const auto& c : sketch_->constraints()) out.push_back(to_gd(c.id.str()));
    return out;
}

static const char* role_to_string(sx::PointRole r) {
    switch (r) {
        case sx::PointRole::Start: return "start";
        case sx::PointRole::End: return "end";
        case sx::PointRole::Center: return "center";
        case sx::PointRole::Self: break;
    }
    return "self";
}

Dictionary SxSketch::constraint_info(const String& id) const {
    Dictionary out;
    sx::EntityId cid = parse_id(id);
    for (const auto& c : sketch_->constraints()) {
        if (c.id != cid) continue;
        out["type"] = to_gd(sx::to_string(c.type));
        out["value"] = c.value;
        out["weak"] = c.weak;
        Array refs;
        for (const auto& r : c.refs) {
            Dictionary ref;
            ref["entity"] = to_gd(r.entity.str());
            ref["role"] = String(role_to_string(r.role));
            refs.push_back(ref);
        }
        out["refs"] = refs;
        break;
    }
    return out;
}

Dictionary SxSketch::solve() {
    sx::SolveResult res = solver_->solve(*sketch_);
    Dictionary out;
    switch (res.status) {
        case sx::SolveStatus::Success: out["status"] = "success"; break;
        case sx::SolveStatus::Converged: out["status"] = "converged"; break;
        case sx::SolveStatus::Failed: out["status"] = "failed"; break;
    }
    out["dofs"] = res.dofs;
    PackedStringArray conflicting, redundant;
    for (const auto& id : res.conflicting) conflicting.push_back(to_gd(id.str()));
    for (const auto& id : res.redundant) redundant.push_back(to_gd(id.str()));
    out["conflicting"] = conflicting;
    out["redundant"] = redundant;
    return out;
}

void SxSketch::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_plane", "origin", "x_dir", "y_dir"), &SxSketch::set_plane);
    ClassDB::bind_method(D_METHOD("plane_info"), &SxSketch::plane_info);
    ClassDB::bind_method(D_METHOD("add_point", "x", "y"), &SxSketch::add_point);
    ClassDB::bind_method(D_METHOD("add_line", "x1", "y1", "x2", "y2"), &SxSketch::add_line);
    ClassDB::bind_method(D_METHOD("add_circle", "cx", "cy", "r"), &SxSketch::add_circle);
    ClassDB::bind_method(D_METHOD("add_arc", "cx", "cy", "r", "start_angle", "end_angle"), &SxSketch::add_arc);
    ClassDB::bind_method(D_METHOD("remove_entity", "id"), &SxSketch::remove_entity);
    ClassDB::bind_method(D_METHOD("set_construction", "id", "construction"), &SxSketch::set_construction);
    ClassDB::bind_method(D_METHOD("is_construction", "id"), &SxSketch::is_construction);
    ClassDB::bind_method(D_METHOD("entity_ids"), &SxSketch::entity_ids);
    ClassDB::bind_method(D_METHOD("fillet_corner", "line_a_id", "line_b_id", "radius"),
                         &SxSketch::fillet_corner);
    ClassDB::bind_method(D_METHOD("offset_entities", "ids", "distance"),
                         &SxSketch::offset_entities);
    ClassDB::bind_method(D_METHOD("trim_entity", "id", "px", "py"),
                         &SxSketch::trim_entity);
    ClassDB::bind_method(D_METHOD("extend_entity", "id", "px", "py"),
                         &SxSketch::extend_entity);
    ClassDB::bind_method(D_METHOD("pattern_entities", "ids", "dx", "dy", "count"),
                         &SxSketch::pattern_entities);
    ClassDB::bind_method(D_METHOD("entity_info", "id"), &SxSketch::entity_info);
    ClassDB::bind_method(D_METHOD("set_entity_geometry", "id", "geo"),
                         &SxSketch::set_entity_geometry);
    ClassDB::bind_method(D_METHOD("add_constraint", "type", "refs", "value"), &SxSketch::add_constraint);
    ClassDB::bind_method(D_METHOD("remove_constraint", "id"), &SxSketch::remove_constraint);
    ClassDB::bind_method(D_METHOD("set_constraint_value", "id", "value"), &SxSketch::set_constraint_value);
    ClassDB::bind_method(D_METHOD("set_constraint_weak", "id", "weak"), &SxSketch::set_constraint_weak);
    ClassDB::bind_method(D_METHOD("drop_weak_constraints"), &SxSketch::drop_weak_constraints);
    ClassDB::bind_method(D_METHOD("constraint_ids"), &SxSketch::constraint_ids);
    ClassDB::bind_method(D_METHOD("constraint_info", "id"), &SxSketch::constraint_info);
    ClassDB::bind_method(D_METHOD("solve"), &SxSketch::solve);
}

}  // namespace sx_godot
