#include "sx/sketch.hpp"
#include "sx/shape_utils.hpp"
#include "sx/variables.hpp"

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <Geom_Circle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>

#include <algorithm>
#include <cmath>
#include <set>
#include <vector>

namespace sx {

const char* to_string(ConstraintType t) {
    switch (t) {
        case ConstraintType::Coincident: return "coincident";
        case ConstraintType::Horizontal: return "horizontal";
        case ConstraintType::Vertical: return "vertical";
        case ConstraintType::Parallel: return "parallel";
        case ConstraintType::Perpendicular: return "perpendicular";
        case ConstraintType::PointOnLine: return "point_on_line";
        case ConstraintType::Tangent: return "tangent";
        case ConstraintType::Equal: return "equal";
        case ConstraintType::Distance: return "distance";
        case ConstraintType::Radius: return "radius";
        case ConstraintType::Angle: return "angle";
        case ConstraintType::Midpoint: return "midpoint";
        case ConstraintType::Symmetric: return "symmetric";
        case ConstraintType::Fix: return "fix";
        case ConstraintType::Diameter: return "diameter";
    }
    return "unknown";
}

std::optional<ConstraintType> constraint_type_from_string(const std::string& s) {
    using CT = ConstraintType;
    for (CT ct : {CT::Coincident, CT::Horizontal, CT::Vertical, CT::Parallel,
                  CT::Perpendicular, CT::PointOnLine, CT::Tangent, CT::Equal,
                  CT::Distance, CT::Radius, CT::Angle, CT::Midpoint, CT::Symmetric,
                  CT::Fix, CT::Diameter}) {
        if (s == to_string(ct)) return ct;
    }
    return std::nullopt;
}

std::array<double, 3> SketchPlane::normal() const {
    return {x_dir[1] * y_dir[2] - x_dir[2] * y_dir[1],
            x_dir[2] * y_dir[0] - x_dir[0] * y_dir[2],
            x_dir[0] * y_dir[1] - x_dir[1] * y_dir[0]};
}

Sketch::Sketch(std::string name, SketchPlane plane)
    : id_(EntityId::generate()), name_(std::move(name)), plane_(plane) {}

size_t Sketch::push_params(std::initializer_list<double> values) {
    size_t first = params_.size();
    for (double v : values) params_.push_back(v);
    return first;
}

EntityId Sketch::add_point(double x, double y) {
    SketchEntity e;
    e.id = EntityId::generate();
    e.type = SketchEntityType::Point;
    size_t base = push_params({x, y});
    e.params = {base, base + 1};
    entities_.push_back(e);
    ++revision_;
    return e.id;
}

EntityId Sketch::add_line(double x1, double y1, double x2, double y2) {
    SketchEntity e;
    e.id = EntityId::generate();
    e.type = SketchEntityType::Line;
    size_t base = push_params({x1, y1, x2, y2});
    e.params = {base, base + 1, base + 2, base + 3};
    entities_.push_back(e);
    ++revision_;
    return e.id;
}

EntityId Sketch::add_circle(double cx, double cy, double r) {
    SketchEntity e;
    e.id = EntityId::generate();
    e.type = SketchEntityType::Circle;
    size_t base = push_params({cx, cy, r});
    e.params = {base, base + 1, base + 2};
    entities_.push_back(e);
    ++revision_;
    return e.id;
}

EntityId Sketch::add_arc(double cx, double cy, double r, double start_angle,
                         double end_angle) {
    SketchEntity e;
    e.id = EntityId::generate();
    e.type = SketchEntityType::Arc;
    double sx = cx + r * std::cos(start_angle), sy = cy + r * std::sin(start_angle);
    double ex = cx + r * std::cos(end_angle), ey = cy + r * std::sin(end_angle);
    size_t base = push_params({cx, cy, r, start_angle, end_angle, sx, sy, ex, ey});
    e.params.resize(9);
    for (size_t i = 0; i < 9; ++i) e.params[i] = base + i;
    entities_.push_back(e);
    ++revision_;
    return e.id;
}

EntityId Sketch::add_spline(const std::vector<std::array<double, 2>>& fit_points) {
    if (fit_points.size() < 2) return {};
    SketchEntity e;
    e.id = EntityId::generate();
    e.type = SketchEntityType::Spline;
    // Layout: [n, x0, y0, x1, y1, ...]
    std::vector<double> vals;
    vals.push_back(static_cast<double>(fit_points.size()));
    for (const auto& pt : fit_points) {
        vals.push_back(pt[0]);
        vals.push_back(pt[1]);
    }
    size_t base = params_.size();
    for (double v : vals) params_.push_back(v);
    e.params.resize(vals.size());
    for (size_t i = 0; i < vals.size(); ++i) e.params[i] = base + i;
    entities_.push_back(e);
    ++revision_;
    return e.id;
}

bool Sketch::remove_entity(const EntityId& id) {
    auto it = std::find_if(entities_.begin(), entities_.end(),
                           [&](const SketchEntity& e) { return e.id == id; });
    if (it == entities_.end()) return false;
    entities_.erase(it);
    // Drop constraints referencing the removed entity. Parameters stay
    // allocated in the deque (addresses of live params must not move).
    constraints_.erase(
        std::remove_if(constraints_.begin(), constraints_.end(),
                       [&](const SketchConstraint& c) {
                           for (const auto& r : c.refs)
                               if (r.entity == id) return true;
                           return false;
                       }),
        constraints_.end());
    ++revision_;
    return true;
}

void Sketch::set_construction(const EntityId& id, bool construction) {
    for (auto& e : entities_)
        if (e.id == id) {
            e.construction = construction;
            ++revision_;
            return;
        }
}

bool Sketch::is_construction(const EntityId& id) const {
    const SketchEntity* e = entity(id);
    return e != nullptr && e->construction;
}

void Sketch::set_external(const EntityId& id, bool external, const std::string& projected_from) {
    for (auto& e : entities_)
        if (e.id == id) {
            e.external = external;
            e.projected_from = projected_from;
            ++revision_;
            return;
        }
}

bool Sketch::is_external(const EntityId& id) const {
    const SketchEntity* e = entity(id);
    return e != nullptr && e->external;
}

const SketchEntity* Sketch::entity(const EntityId& id) const {
    for (const auto& e : entities_)
        if (e.id == id) return &e;
    return nullptr;
}

SketchEntity* Sketch::entity_mut(const EntityId& id) {
    for (auto& e : entities_)
        if (e.id == id) return &e;
    return nullptr;
}

EntityId Sketch::add_constraint(ConstraintType type, std::vector<PointRef> refs,
                                double value, bool driving) {
    SketchConstraint c;
    c.id = EntityId::generate();
    c.type = type;
    c.refs = std::move(refs);
    c.value = value;
    c.driving = driving;
    // Snapshot geometry for Fix.
    if (type == ConstraintType::Fix && !c.refs.empty()) {
        const SketchEntity* e = entity(c.refs[0].entity);
        if (e) {
            if (e->type == SketchEntityType::Point) {
                c.locked = {params_[e->params[0]], params_[e->params[1]]};
            } else if (e->type == SketchEntityType::Line) {
                c.locked = {params_[e->params[0]], params_[e->params[1]],
                            params_[e->params[2]], params_[e->params[3]]};
            } else if (e->type == SketchEntityType::Circle) {
                c.locked = {params_[e->params[0]], params_[e->params[1]], params_[e->params[2]]};
            }
        }
    }
    constraints_.push_back(c);
    ++revision_;
    return c.id;
}

bool Sketch::remove_constraint(const EntityId& id) {
    auto it = std::find_if(constraints_.begin(), constraints_.end(),
                           [&](const SketchConstraint& c) { return c.id == id; });
    if (it == constraints_.end()) return false;
    constraints_.erase(it);
    ++revision_;
    return true;
}

bool Sketch::set_constraint_value(const EntityId& id, double value) {
    for (auto& c : constraints_)
        if (c.id == id) {
            c.value = value;
            c.expr.clear();
            ++revision_;
            return true;
        }
    return false;
}

SketchConstraint* Sketch::constraint_mut(const EntityId& id) {
    for (auto& c : constraints_)
        if (c.id == id) return &c;
    return nullptr;
}

bool Sketch::set_constraint_expr(const EntityId& id, const std::string& expr) {
    for (auto& c : constraints_)
        if (c.id == id) {
            c.expr = expr;
            ++revision_;
            return true;
        }
    return false;
}

bool Sketch::set_constraint_driving(const EntityId& id, bool driving) {
    for (auto& c : constraints_)
        if (c.id == id) {
            c.driving = driving;
            ++revision_;
            return true;
        }
    return false;
}

bool Sketch::resolve_expressions(const std::map<std::string, double>& env, std::string* err) {
    for (auto& c : constraints_) {
        if (c.expr.empty()) continue;
        std::string e = c.expr;
        if (!e.empty() && e[0] == '=') e = e.substr(1);
        try {
            c.value = eval_expression(e, env);
        } catch (const std::exception& ex) {
            if (err) *err = ex.what();
            return false;
        }
    }
    return true;
}

std::optional<std::array<double, 2>> Sketch::point_pos(const PointRef& ref) const {
    const SketchEntity* e = entity(ref.entity);
    if (!e) return std::nullopt;
    auto p = [&](size_t i) { return params_[e->params[i]]; };
    switch (e->type) {
        case SketchEntityType::Point:
            return std::array<double, 2>{p(0), p(1)};
        case SketchEntityType::Line:
            if (ref.role == PointRole::Start) return std::array<double, 2>{p(0), p(1)};
            if (ref.role == PointRole::End) return std::array<double, 2>{p(2), p(3)};
            return std::nullopt;
        case SketchEntityType::Circle:
            if (ref.role == PointRole::Center || ref.role == PointRole::Self)
                return std::array<double, 2>{p(0), p(1)};
            return std::nullopt;
        case SketchEntityType::Arc:
            if (ref.role == PointRole::Center) return std::array<double, 2>{p(0), p(1)};
            if (ref.role == PointRole::Start) return std::array<double, 2>{p(5), p(6)};
            if (ref.role == PointRole::End) return std::array<double, 2>{p(7), p(8)};
            return std::nullopt;
        case SketchEntityType::Spline: {
            auto fits = spline_fit_points(ref.entity);
            if (fits.empty()) return std::nullopt;
            if (ref.role == PointRole::End) return fits.back();
            return fits.front();  // Self / Start
        }
    }
    return std::nullopt;
}

std::vector<std::array<double, 2>> Sketch::spline_fit_points(const EntityId& id) const {
    std::vector<std::array<double, 2>> out;
    const SketchEntity* e = entity(id);
    if (!e || e->type != SketchEntityType::Spline || e->params.size() < 3) return out;
    int n = static_cast<int>(params_[e->params[0]]);
    if (n < 2 || e->params.size() < static_cast<size_t>(1 + 2 * n)) return out;
    for (int i = 0; i < n; ++i) {
        out.push_back({params_[e->params[1 + 2 * i]], params_[e->params[2 + 2 * i]]});
    }
    return out;
}

// --- profile face construction ---

namespace {
struct Segment {
    gp_Pnt start, end;
    TopoDS_Edge edge;
    bool used = false;
};
}  // namespace

TopoDS_Shape Sketch::profile_face(std::string* err) const {
    const auto n = plane_.normal();
    gp_Pln pln(gp_Pnt(plane_.origin[0], plane_.origin[1], plane_.origin[2]),
               gp_Dir(n[0], n[1], n[2]));
    gp_Dir xd(plane_.x_dir[0], plane_.x_dir[1], plane_.x_dir[2]);
    gp_Dir nd(n[0], n[1], n[2]);
    gp_Ax2 ax(gp_Pnt(plane_.origin[0], plane_.origin[1], plane_.origin[2]), nd, xd);

    auto to3d = [&](double u, double v) {
        gp_Pnt o = ax.Location();
        gp_XYZ x = ax.XDirection().XYZ(), y = ax.YDirection().XYZ();
        return gp_Pnt(o.XYZ() + x * u + y * v);
    };
    auto p = [&](const SketchEntity& e, size_t i) { return params_[e.params[i]]; };

    // Special case: a single non-construction circle -> disk.
    std::vector<const SketchEntity*> drawn;
    for (const auto& e : entities_)
        if (!e.construction && e.type != SketchEntityType::Point) drawn.push_back(&e);

    if (drawn.size() == 1 && drawn[0]->type == SketchEntityType::Circle) {
        const auto& e = *drawn[0];
        gp_Circ circ(gp_Ax2(to3d(p(e, 0), p(e, 1)), nd, xd), p(e, 2));
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circ).Edge();
        TopoDS_Wire wire = BRepBuilderAPI_MakeWire(edge).Wire();
        return BRepBuilderAPI_MakeFace(pln, wire).Face();
    }

    // General case: chain line/arc/spline segments into closed loops; full
    // circles become their own closed wires (holes or lone disks).
    std::vector<Segment> segs;
    std::vector<TopoDS_Wire> circle_wires;
    for (const auto* ep : drawn) {
        const auto& e = *ep;
        if (e.type == SketchEntityType::Line) {
            gp_Pnt a = to3d(p(e, 0), p(e, 1)), b = to3d(p(e, 2), p(e, 3));
            if (a.Distance(b) < 1e-9) continue;
            segs.push_back({a, b, BRepBuilderAPI_MakeEdge(a, b).Edge()});
        } else if (e.type == SketchEntityType::Arc) {
            gp_Pnt c = to3d(p(e, 0), p(e, 1));
            gp_Pnt a = to3d(p(e, 5), p(e, 6)), b = to3d(p(e, 7), p(e, 8));
            double mid_angle = (p(e, 3) + p(e, 4)) / 2.0;
            // Wrap if end < start (ccw convention).
            if (p(e, 4) < p(e, 3)) mid_angle += 3.14159265358979323846;
            gp_Pnt m = to3d(p(e, 0) + p(e, 2) * std::cos(mid_angle),
                            p(e, 1) + p(e, 2) * std::sin(mid_angle));
            (void)c;
            GC_MakeArcOfCircle mk(a, m, b);
            if (!mk.IsDone()) continue;
            segs.push_back({a, b, BRepBuilderAPI_MakeEdge(mk.Value()).Edge()});
        } else if (e.type == SketchEntityType::Spline) {
            auto fits = spline_fit_points(e.id);
            if (fits.size() < 2) continue;
            TColgp_Array1OfPnt poles(1, static_cast<int>(fits.size()));
            for (int i = 0; i < static_cast<int>(fits.size()); ++i)
                poles.SetValue(i + 1, to3d(fits[static_cast<size_t>(i)][0],
                                           fits[static_cast<size_t>(i)][1]));
            GeomAPI_PointsToBSpline mk(poles);
            if (!mk.IsDone()) continue;
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(mk.Curve()).Edge();
            gp_Pnt a = poles.Value(1);
            gp_Pnt b = poles.Value(poles.Upper());
            segs.push_back({a, b, edge});
        } else if (e.type == SketchEntityType::Circle) {
            gp_Circ circ(gp_Ax2(to3d(p(e, 0), p(e, 1)), nd, xd), p(e, 2));
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circ).Edge();
            circle_wires.push_back(BRepBuilderAPI_MakeWire(edge).Wire());
        }
    }
    if (segs.empty() && circle_wires.empty()) {
        if (err) *err = "no profile entities in sketch";
        return {};
    }

    // Greedy-chain every unused segment group into a closed wire (outer + holes).
    constexpr double tol = 1e-6;
    std::vector<TopoDS_Wire> wires;
    auto unused = [&]() -> Segment* {
        for (auto& s : segs)
            if (!s.used) return &s;
        return nullptr;
    };
    while (Segment* seed = unused()) {
        BRepBuilderAPI_MakeWire wire;
        wire.Add(seed->edge);
        seed->used = true;
        gp_Pnt loop_start = seed->start;
        gp_Pnt cursor = seed->end;
        bool progressing = true;
        while (progressing && cursor.Distance(loop_start) > tol) {
            progressing = false;
            for (auto& s : segs) {
                if (s.used) continue;
                if (s.start.Distance(cursor) < tol) {
                    wire.Add(s.edge);
                    cursor = s.end;
                } else if (s.end.Distance(cursor) < tol) {
                    wire.Add(s.edge);
                    cursor = s.start;
                } else {
                    continue;
                }
                s.used = true;
                progressing = true;
                break;
            }
        }
        if (cursor.Distance(loop_start) > tol) {
            if (err) *err = "profile has an open loop";
            return {};
        }
        if (!wire.IsDone()) {
            if (err) *err = "wire construction failed";
            return {};
        }
        wires.push_back(wire.Wire());
    }
    for (auto& cw : circle_wires) wires.push_back(cw);
    if (wires.empty()) {
        if (err) *err = "no closed profile";
        return {};
    }
    if (wires.size() == 1) {
        return BRepBuilderAPI_MakeFace(pln, wires[0]).Face();
    }

    // Largest-area wire is the outer; remaining wires are holes (Fusion/Onshape).
    size_t outer_i = 0;
    double best_area = -1.0;
    for (size_t i = 0; i < wires.size(); ++i) {
        BRepBuilderAPI_MakeFace mf(pln, wires[i]);
        if (!mf.IsDone()) continue;
        double a = shape::area(mf.Face());
        if (a > best_area) {
            best_area = a;
            outer_i = i;
        }
    }
    if (best_area <= 0.0) {
        if (err) *err = "could not measure outer profile wire";
        return {};
    }

    auto make_with_holes = [&](bool reverse_holes) -> TopoDS_Shape {
        BRepBuilderAPI_MakeFace mk(pln, wires[outer_i]);
        for (size_t i = 0; i < wires.size(); ++i) {
            if (i == outer_i) continue;
            TopoDS_Wire hole = wires[i];
            if (reverse_holes) hole = TopoDS::Wire(hole.Reversed());
            mk.Add(hole);
        }
        if (!mk.IsDone()) return {};
        return mk.Face();
    };

    TopoDS_Shape face = make_with_holes(true);
    if (face.IsNull()) face = make_with_holes(false);
    if (face.IsNull()) {
        if (err) *err = "face with holes failed";
        return {};
    }
    // Holes must reduce area vs the solid outer silhouette.
    if (shape::area(face) >= best_area - 1e-6) {
        TopoDS_Shape alt = make_with_holes(false);
        if (!alt.IsNull() && shape::area(alt) < best_area - 1e-6) face = alt;
    }
    return face;
}

TopoDS_Shape Sketch::thin_profile_face(double thickness, bool midplane, bool flip_side,
                                       std::string* err) const {
    if (!(thickness > 0.0)) {
        if (err) *err = "thin thickness must be > 0";
        return {};
    }

    auto p = [&](const SketchEntity& e, size_t i) { return params_[e.params[i]]; };

    struct UVSeg {
        double x1, y1, x2, y2;
        bool used = false;
    };
    std::vector<UVSeg> segs;
    for (const auto& e : entities_) {
        if (e.construction || e.type != SketchEntityType::Line) continue;
        double x1 = p(e, 0), y1 = p(e, 1), x2 = p(e, 2), y2 = p(e, 3);
        if (std::hypot(x2 - x1, y2 - y1) < 1e-9) continue;
        segs.push_back({x1, y1, x2, y2, false});
    }
    if (segs.empty()) {
        if (err) *err = "no usable open line chain for thin profile";
        return {};
    }

    constexpr double tol = 1e-6;
    auto near = [&](double ax, double ay, double bx, double by) {
        return std::hypot(ax - bx, ay - by) < tol;
    };

    // Greedy-chain line segments into one UV polyline (open allowed).
    UVSeg* seed = &segs[0];
    seed->used = true;
    std::vector<std::array<double, 2>> pts;
    pts.push_back({seed->x1, seed->y1});
    pts.push_back({seed->x2, seed->y2});

    auto extend = [&](bool forward) {
        bool progressing = true;
        while (progressing) {
            progressing = false;
            double cx = forward ? pts.back()[0] : pts.front()[0];
            double cy = forward ? pts.back()[1] : pts.front()[1];
            for (auto& s : segs) {
                if (s.used) continue;
                std::array<double, 2> nxt{};
                bool hit = false;
                if (near(s.x1, s.y1, cx, cy)) {
                    nxt = {s.x2, s.y2};
                    hit = true;
                } else if (near(s.x2, s.y2, cx, cy)) {
                    nxt = {s.x1, s.y1};
                    hit = true;
                }
                if (!hit) continue;
                s.used = true;
                if (forward) pts.push_back(nxt);
                else pts.insert(pts.begin(), nxt);
                progressing = true;
                break;
            }
        }
    };
    extend(true);
    extend(false);

    for (const auto& s : segs) {
        if (!s.used) {
            // Prefer a single chain for MVP; leftover segments are ignored only if
            // we already have a usable polyline. Fail if chain is degenerate.
            break;
        }
    }
    if (pts.size() < 2) {
        if (err) *err = "no usable open line chain for thin profile";
        return {};
    }

    auto left_normal = [](double x1, double y1, double x2, double y2) {
        double dx = x2 - x1, dy = y2 - y1;
        double len = std::hypot(dx, dy);
        if (len < 1e-12) return std::array<double, 2>{0.0, 0.0};
        return std::array<double, 2>{-dy / len, dx / len};
    };

    auto offset_poly = [&](const std::vector<std::array<double, 2>>& src, double dist) {
        std::vector<std::array<double, 2>> out(src.size());
        for (size_t i = 0; i < src.size(); ++i) {
            double nx = 0.0, ny = 0.0;
            if (i + 1 < src.size()) {
                auto n = left_normal(src[i][0], src[i][1], src[i + 1][0], src[i + 1][1]);
                nx += n[0];
                ny += n[1];
            }
            if (i > 0) {
                auto n = left_normal(src[i - 1][0], src[i - 1][1], src[i][0], src[i][1]);
                nx += n[0];
                ny += n[1];
            }
            double len = std::hypot(nx, ny);
            if (len < 1e-12) {
                out[i] = src[i];
            } else {
                out[i] = {src[i][0] + dist * nx / len, src[i][1] + dist * ny / len};
            }
        }
        return out;
    };

    std::vector<std::array<double, 2>> path_a, path_b;
    if (midplane) {
        double d = thickness * 0.5;
        if (flip_side) d = -d;
        path_a = offset_poly(pts, d);
        path_b = offset_poly(pts, -d);
    } else {
        double d = flip_side ? -thickness : thickness;
        path_a = pts;
        path_b = offset_poly(pts, d);
    }

    const auto n = plane_.normal();
    gp_Pln pln(gp_Pnt(plane_.origin[0], plane_.origin[1], plane_.origin[2]),
               gp_Dir(n[0], n[1], n[2]));
    gp_Dir xd(plane_.x_dir[0], plane_.x_dir[1], plane_.x_dir[2]);
    gp_Dir nd(n[0], n[1], n[2]);
    gp_Ax2 ax(gp_Pnt(plane_.origin[0], plane_.origin[1], plane_.origin[2]), nd, xd);
    auto to3d = [&](double u, double v) {
        gp_Pnt o = ax.Location();
        gp_XYZ x = ax.XDirection().XYZ(), y = ax.YDirection().XYZ();
        return gp_Pnt(o.XYZ() + x * u + y * v);
    };

    // Closed wire: forward path_a, endcap, reverse path_b, endcap.
    if (path_a.size() < 2 || path_b.size() < 2) {
        if (err) *err = "thin profile path degenerate";
        return {};
    }
    BRepBuilderAPI_MakeWire wire;
    auto add_edge = [&](const std::array<double, 2>& u, const std::array<double, 2>& v) {
        gp_Pnt a = to3d(u[0], u[1]);
        gp_Pnt b = to3d(v[0], v[1]);
        if (a.Distance(b) < 1e-9) return;
        wire.Add(BRepBuilderAPI_MakeEdge(a, b).Edge());
    };
    for (size_t i = 0; i + 1 < path_a.size(); ++i) add_edge(path_a[i], path_a[i + 1]);
    add_edge(path_a.back(), path_b.back());
    for (size_t i = path_b.size(); i-- > 1;) add_edge(path_b[i], path_b[i - 1]);
    add_edge(path_b.front(), path_a.front());
    if (!wire.IsDone()) {
        if (err) *err = "thin wire construction failed";
        return {};
    }
    BRepBuilderAPI_MakeFace mk(pln, wire.Wire());
    if (!mk.IsDone()) {
        if (err) *err = "thin face construction failed";
        return {};
    }
    return mk.Face();
}

std::array<double, 2> Sketch::to_sketch_uv(const std::array<double, 3>& p) const {
    double dx = p[0] - plane_.origin[0];
    double dy = p[1] - plane_.origin[1];
    double dz = p[2] - plane_.origin[2];
    double u = dx * plane_.x_dir[0] + dy * plane_.x_dir[1] + dz * plane_.x_dir[2];
    double v = dx * plane_.y_dir[0] + dy * plane_.y_dir[1] + dz * plane_.y_dir[2];
    return {u, v};
}

EntityId Sketch::project_line_edge(const std::array<double, 3>& a,
                                   const std::array<double, 3>& b,
                                   const std::string& edge_id) {
    auto ua = to_sketch_uv(a), ub = to_sketch_uv(b);
    EntityId id = add_line(ua[0], ua[1], ub[0], ub[1]);
    set_external(id, true, edge_id);
    // Lock projected geometry.
    add_constraint(ConstraintType::Fix, {{id, PointRole::Self}}, 0.0, true);
    return id;
}

EntityId Sketch::project_circle_edge(const std::array<double, 3>& center, double radius,
                                     const std::string& edge_id) {
    auto uc = to_sketch_uv(center);
    EntityId id = add_circle(uc[0], uc[1], radius);
    set_external(id, true, edge_id);
    add_constraint(ConstraintType::Fix, {{id, PointRole::Self}}, 0.0, true);
    return id;
}

bool Sketch::update_projected_line(const EntityId& id, const std::array<double, 3>& a,
                                   const std::array<double, 3>& b) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::Line || !e->external) return false;
    auto ua = to_sketch_uv(a), ub = to_sketch_uv(b);
    params_[e->params[0]] = ua[0];
    params_[e->params[1]] = ua[1];
    params_[e->params[2]] = ub[0];
    params_[e->params[3]] = ub[1];
    // Refresh Fix locked values.
    for (auto& c : constraints_) {
        if (c.type == ConstraintType::Fix && !c.refs.empty() && c.refs[0].entity == id)
            c.locked = {ua[0], ua[1], ub[0], ub[1]};
    }
    ++revision_;
    return true;
}

bool Sketch::update_projected_circle(const EntityId& id, const std::array<double, 3>& center,
                                     double radius) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::Circle || !e->external) return false;
    auto uc = to_sketch_uv(center);
    params_[e->params[0]] = uc[0];
    params_[e->params[1]] = uc[1];
    params_[e->params[2]] = radius;
    for (auto& c : constraints_) {
        if (c.type == ConstraintType::Fix && !c.refs.empty() && c.refs[0].entity == id)
            c.locked = {uc[0], uc[1], radius};
    }
    ++revision_;
    return true;
}

int Sketch::mark_dangling_external(const std::vector<std::string>& live_edge_ids) {
    int n = 0;
    std::set<std::string> live(live_edge_ids.begin(), live_edge_ids.end());
    for (auto& e : entities_) {
        if (!e.external || e.projected_from.empty()) continue;
        if (live.count(e.projected_from)) continue;
        e.construction = true;  // dangling: keep but exclude from profile
        e.projected_from.clear();
        ++n;
        ++revision_;
    }
    return n;
}

std::vector<SketchIssue> Sketch::analyze(double gap_tol) const {
    std::vector<SketchIssue> issues;
    for (const auto& e : entities_) {
        if (e.construction || e.type != SketchEntityType::Line) continue;
        double dx = params_[e.params[2]] - params_[e.params[0]];
        double dy = params_[e.params[3]] - params_[e.params[1]];
        if (dx * dx + dy * dy < 1e-18) {
            issues.push_back({"zero_length", "zero-length line", {e.id}});
        }
    }
    // Endpoint degree for open-loop detection (non-construction lines/arcs/splines).
    struct EP {
        double x, y;
        EntityId id;
    };
    std::vector<EP> ends;
    auto add_end = [&](double x, double y, EntityId id) { ends.push_back({x, y, id}); };
    for (const auto& e : entities_) {
        if (e.construction) continue;
        if (e.type == SketchEntityType::Line) {
            add_end(params_[e.params[0]], params_[e.params[1]], e.id);
            add_end(params_[e.params[2]], params_[e.params[3]], e.id);
        } else if (e.type == SketchEntityType::Arc) {
            add_end(params_[e.params[5]], params_[e.params[6]], e.id);
            add_end(params_[e.params[7]], params_[e.params[8]], e.id);
        } else if (e.type == SketchEntityType::Spline) {
            auto fits = spline_fit_points(e.id);
            if (fits.size() >= 2) {
                add_end(fits.front()[0], fits.front()[1], e.id);
                add_end(fits.back()[0], fits.back()[1], e.id);
            }
        }
    }
    std::vector<bool> matched(ends.size(), false);
    for (size_t i = 0; i < ends.size(); ++i) {
        if (matched[i]) continue;
        int count = 1;
        for (size_t j = i + 1; j < ends.size(); ++j) {
            if (matched[j]) continue;
            double dx = ends[i].x - ends[j].x, dy = ends[i].y - ends[j].y;
            if (dx * dx + dy * dy <= gap_tol * gap_tol) {
                matched[j] = true;
                ++count;
            }
        }
        matched[i] = true;
        if (count == 1) {
            // Unmatched endpoint → open loop / gap.
            issues.push_back({"open_loop", "open profile endpoint", {ends[i].id}});
        }
    }
    return issues;
}

int Sketch::fully_define() {
    int added = 0;
    // H/V near-axis lines.
    constexpr double tol = 0.5;
    for (const auto& e : entities_) {
        if (e.construction || e.type != SketchEntityType::Line) continue;
        double dx = params_[e.params[2]] - params_[e.params[0]];
        double dy = params_[e.params[3]] - params_[e.params[1]];
        bool has_hv = false;
        for (const auto& c : constraints_) {
            if ((c.type == ConstraintType::Horizontal || c.type == ConstraintType::Vertical) &&
                !c.refs.empty() && c.refs[0].entity == e.id)
                has_hv = true;
        }
        if (has_hv) continue;
        if (std::abs(dy) <= tol && std::abs(dx) > tol) {
            add_constraint(ConstraintType::Horizontal, {{e.id, PointRole::Self}});
            ++added;
        } else if (std::abs(dx) <= tol && std::abs(dy) > tol) {
            add_constraint(ConstraintType::Vertical, {{e.id, PointRole::Self}});
            ++added;
        }
    }
    // Anchor nearest point/line endpoint to origin if nothing is fixed near origin.
    bool has_origin = false;
    for (const auto& c : constraints_) {
        if (c.type == ConstraintType::Fix) has_origin = true;
        if (c.type == ConstraintType::Coincident) {
            // Check if any ref is near origin via a dedicated origin point — skip heuristic.
        }
    }
    if (!has_origin) {
        // Create origin point + coincident to nearest endpoint, then Fix origin.
        EntityId origin = add_point(0, 0);
        set_construction(origin, true);
        add_constraint(ConstraintType::Fix, {{origin, PointRole::Self}});
        ++added;
        double best = 1e300;
        PointRef best_ref;
        bool found = false;
        for (const auto& e : entities_) {
            if (e.construction || e.id == origin) continue;
            if (e.type == SketchEntityType::Line) {
                for (auto role : {PointRole::Start, PointRole::End}) {
                    auto pos = point_pos({e.id, role});
                    if (!pos) continue;
                    double d = (*pos)[0] * (*pos)[0] + (*pos)[1] * (*pos)[1];
                    if (d < best) {
                        best = d;
                        best_ref = {e.id, role};
                        found = true;
                    }
                }
            }
        }
        if (found) {
            add_constraint(ConstraintType::Coincident,
                           {{origin, PointRole::Self}, best_ref});
            ++added;
        }
    }
    // Driving length dims on unconstrained line lengths.
    for (const auto& e : entities_) {
        if (e.construction || e.type != SketchEntityType::Line) continue;
        bool has_dist = false;
        for (const auto& c : constraints_) {
            if (c.type == ConstraintType::Distance && c.refs.size() >= 2 &&
                c.refs[0].entity == e.id && c.refs[1].entity == e.id)
                has_dist = true;
        }
        if (has_dist) continue;
        double dx = params_[e.params[2]] - params_[e.params[0]];
        double dy = params_[e.params[3]] - params_[e.params[1]];
        double len = std::sqrt(dx * dx + dy * dy);
        if (len < 1e-9) continue;
        add_constraint(ConstraintType::Distance,
                       {{e.id, PointRole::Start}, {e.id, PointRole::End}}, len, true);
        ++added;
    }
    // Driving radii on circles without radius/diameter.
    for (const auto& e : entities_) {
        if (e.construction || e.type != SketchEntityType::Circle) continue;
        bool has_r = false;
        for (const auto& c : constraints_) {
            if ((c.type == ConstraintType::Radius || c.type == ConstraintType::Diameter) &&
                !c.refs.empty() && c.refs[0].entity == e.id)
                has_r = true;
        }
        if (has_r) continue;
        add_constraint(ConstraintType::Radius, {{e.id, PointRole::Self}},
                       params_[e.params[2]], true);
        ++added;
    }
    return added;
}

}  // namespace sx
