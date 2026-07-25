#include "sx_sketch.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <algorithm>
#include <map>

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
    return sx::constraint_type_from_string(to_std(s));
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
String SxSketch::add_spline(const PackedVector2Array& fit_points) {
    std::vector<std::array<double, 2>> pts;
    pts.reserve(fit_points.size());
    for (int i = 0; i < fit_points.size(); ++i) {
        Vector2 v = fit_points[i];
        pts.push_back({v.x, v.y});
    }
    auto id = sketch_->add_spline(pts);
    return id.is_null() ? String() : to_gd(id.str());
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

void SxSketch::set_external(const String& id, bool external, const String& projected_from) {
    sketch_->set_external(parse_id(id), external, to_std(projected_from));
}

bool SxSketch::is_external(const String& id) const {
    return sketch_->is_external(parse_id(id));
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
    out["external"] = e->external;
    out["projected_from"] = to_gd(e->projected_from);
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
        case sx::SketchEntityType::Spline: {
            out["type"] = "spline";
            Array pts;
            for (const auto& fp : sketch_->spline_fit_points(e->id))
                pts.push_back(Vector2(fp[0], fp[1]));
            out["fit_points"] = pts;
            break;
        }
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
        case sx::SketchEntityType::Spline:
            if (geo.has("fit_points")) {
                Array pts = geo["fit_points"];
                int n = static_cast<int>(sketch_->param(e->params[0]));
                int m = std::min(n, static_cast<int>(pts.size()));
                for (int i = 0; i < m; ++i) {
                    Vector2 v = pts[i];
                    set(static_cast<size_t>(1 + 2 * i), v.x);
                    set(static_cast<size_t>(2 + 2 * i), v.y);
                }
            }
            break;
    }
    return true;
}

String SxSketch::add_constraint(const String& type, const Array& refs, double value,
                                bool driving) {
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
    return to_gd(sketch_->add_constraint(*ct, std::move(prefs), value, driving).str());
}

bool SxSketch::remove_constraint(const String& id) {
    return sketch_->remove_constraint(parse_id(id));
}

bool SxSketch::set_constraint_value(const String& id, double value) {
    return sketch_->set_constraint_value(parse_id(id), value);
}

bool SxSketch::set_constraint_expr(const String& id, const String& expr) {
    return sketch_->set_constraint_expr(parse_id(id), to_std(expr));
}

bool SxSketch::set_constraint_driving(const String& id, bool driving) {
    return sketch_->set_constraint_driving(parse_id(id), driving);
}

bool SxSketch::resolve_expressions(const Dictionary& env) {
    std::map<std::string, double> m;
    Array keys = env.keys();
    for (int i = 0; i < keys.size(); ++i) {
        String k = keys[i];
        m[to_std(k)] = static_cast<double>(env[k]);
    }
    return sketch_->resolve_expressions(m);
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
        out["driving"] = c.driving;
        out["expr"] = to_gd(c.expr);
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

Array SxSketch::analyze(double gap_tol) const {
    Array out;
    for (const auto& issue : sketch_->analyze(gap_tol)) {
        Dictionary d;
        d["code"] = to_gd(issue.code);
        d["message"] = to_gd(issue.message);
        PackedStringArray ents;
        for (const auto& id : issue.entities) ents.push_back(to_gd(id.str()));
        d["entities"] = ents;
        out.push_back(d);
    }
    return out;
}

int SxSketch::fully_define() {
    return sketch_->fully_define();
}

String SxSketch::project_line_edge(const Vector3& a, const Vector3& b, const String& edge_id) {
    auto id = sketch_->project_line_edge({a.x, a.y, a.z}, {b.x, b.y, b.z}, to_std(edge_id));
    return to_gd(id.str());
}

String SxSketch::project_circle_edge(const Vector3& center, double radius,
                                     const String& edge_id) {
    auto id = sketch_->project_circle_edge({center.x, center.y, center.z}, radius,
                                           to_std(edge_id));
    return to_gd(id.str());
}

bool SxSketch::update_projected_line(const String& id, const Vector3& a, const Vector3& b) {
    return sketch_->update_projected_line(parse_id(id), {a.x, a.y, a.z}, {b.x, b.y, b.z});
}

bool SxSketch::update_projected_circle(const String& id, const Vector3& center, double radius) {
    return sketch_->update_projected_circle(parse_id(id), {center.x, center.y, center.z},
                                            radius);
}

int SxSketch::mark_dangling_external(const PackedStringArray& live_edge_ids) {
    std::vector<std::string> live;
    for (int i = 0; i < live_edge_ids.size(); ++i) live.push_back(to_std(live_edge_ids[i]));
    return sketch_->mark_dangling_external(live);
}

void SxSketch::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_plane", "origin", "x_dir", "y_dir"), &SxSketch::set_plane);
    ClassDB::bind_method(D_METHOD("plane_info"), &SxSketch::plane_info);
    ClassDB::bind_method(D_METHOD("add_point", "x", "y"), &SxSketch::add_point);
    ClassDB::bind_method(D_METHOD("add_line", "x1", "y1", "x2", "y2"), &SxSketch::add_line);
    ClassDB::bind_method(D_METHOD("add_circle", "cx", "cy", "r"), &SxSketch::add_circle);
    ClassDB::bind_method(D_METHOD("add_arc", "cx", "cy", "r", "start_angle", "end_angle"),
                         &SxSketch::add_arc);
    ClassDB::bind_method(D_METHOD("add_spline", "fit_points"), &SxSketch::add_spline);
    ClassDB::bind_method(D_METHOD("remove_entity", "id"), &SxSketch::remove_entity);
    ClassDB::bind_method(D_METHOD("set_construction", "id", "construction"),
                         &SxSketch::set_construction);
    ClassDB::bind_method(D_METHOD("is_construction", "id"), &SxSketch::is_construction);
    ClassDB::bind_method(D_METHOD("set_external", "id", "external", "projected_from"),
                         &SxSketch::set_external);
    ClassDB::bind_method(D_METHOD("is_external", "id"), &SxSketch::is_external);
    ClassDB::bind_method(D_METHOD("entity_ids"), &SxSketch::entity_ids);
    ClassDB::bind_method(D_METHOD("fillet_corner", "line_a_id", "line_b_id", "radius"),
                         &SxSketch::fillet_corner);
    ClassDB::bind_method(D_METHOD("offset_entities", "ids", "distance"),
                         &SxSketch::offset_entities);
    ClassDB::bind_method(D_METHOD("trim_entity", "id", "px", "py"), &SxSketch::trim_entity);
    ClassDB::bind_method(D_METHOD("extend_entity", "id", "px", "py"), &SxSketch::extend_entity);
    ClassDB::bind_method(D_METHOD("pattern_entities", "ids", "dx", "dy", "count"),
                         &SxSketch::pattern_entities);
    ClassDB::bind_method(D_METHOD("entity_info", "id"), &SxSketch::entity_info);
    ClassDB::bind_method(D_METHOD("set_entity_geometry", "id", "geo"),
                         &SxSketch::set_entity_geometry);
    ClassDB::bind_method(D_METHOD("add_constraint", "type", "refs", "value", "driving"),
                         &SxSketch::add_constraint, DEFVAL(true));
    ClassDB::bind_method(D_METHOD("remove_constraint", "id"), &SxSketch::remove_constraint);
    ClassDB::bind_method(D_METHOD("set_constraint_value", "id", "value"),
                         &SxSketch::set_constraint_value);
    ClassDB::bind_method(D_METHOD("set_constraint_expr", "id", "expr"),
                         &SxSketch::set_constraint_expr);
    ClassDB::bind_method(D_METHOD("set_constraint_driving", "id", "driving"),
                         &SxSketch::set_constraint_driving);
    ClassDB::bind_method(D_METHOD("resolve_expressions", "env"), &SxSketch::resolve_expressions);
    ClassDB::bind_method(D_METHOD("constraint_ids"), &SxSketch::constraint_ids);
    ClassDB::bind_method(D_METHOD("constraint_info", "id"), &SxSketch::constraint_info);
    ClassDB::bind_method(D_METHOD("solve"), &SxSketch::solve);
    ClassDB::bind_method(D_METHOD("analyze", "gap_tol"), &SxSketch::analyze, DEFVAL(1e-4));
    ClassDB::bind_method(D_METHOD("fully_define"), &SxSketch::fully_define);
    ClassDB::bind_method(D_METHOD("project_line_edge", "a", "b", "edge_id"),
                         &SxSketch::project_line_edge);
    ClassDB::bind_method(D_METHOD("project_circle_edge", "center", "radius", "edge_id"),
                         &SxSketch::project_circle_edge);
    ClassDB::bind_method(D_METHOD("update_projected_line", "id", "a", "b"),
                         &SxSketch::update_projected_line);
    ClassDB::bind_method(D_METHOD("update_projected_circle", "id", "center", "radius"),
                         &SxSketch::update_projected_circle);
    ClassDB::bind_method(D_METHOD("mark_dangling_external", "live_edge_ids"),
                         &SxSketch::mark_dangling_external);
}

}  // namespace sx_godot
