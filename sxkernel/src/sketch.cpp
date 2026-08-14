#include "sx/sketch.hpp"
#include "sx/shape_utils.hpp"

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <Geom_Circle.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>

#include <algorithm>
#include <cmath>
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
        case ConstraintType::Concentric: return "concentric";
        case ConstraintType::Symmetric: return "symmetric";
        case ConstraintType::Midpoint: return "midpoint";
        case ConstraintType::Fix: return "fix";
        case ConstraintType::Collinear: return "collinear";
    }
    return "unknown";
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

const SketchEntity* Sketch::entity(const EntityId& id) const {
    for (const auto& e : entities_)
        if (e.id == id) return &e;
    return nullptr;
}

EntityId Sketch::add_constraint(ConstraintType type, std::vector<PointRef> refs,
                                double value) {
    SketchConstraint c;
    c.id = EntityId::generate();
    c.type = type;
    c.refs = std::move(refs);
    c.value = value;
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
            ++revision_;
            return true;
        }
    return false;
}

bool Sketch::set_constraint_weak(const EntityId& id, bool weak) {
    for (auto& c : constraints_)
        if (c.id == id) {
            c.weak = weak;
            ++revision_;
            return true;
        }
    return false;
}

int Sketch::drop_weak_constraints() {
    const auto before = constraints_.size();
    std::erase_if(constraints_, [](const SketchConstraint& c) { return c.weak; });
    const int n = static_cast<int>(before - constraints_.size());
    if (n > 0) ++revision_;
    return n;
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
    }
    return std::nullopt;
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

    // General case: chain line/arc segments into a closed loop.
    std::vector<Segment> segs;
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
        } else if (e.type == SketchEntityType::Circle) {
            if (err) *err = "mixed circle + open profile not supported yet";
            return {};
        }
    }
    if (segs.empty()) {
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
    if (shape::area(face) >= best_area - 1e-6) {
        if (err) *err = "inner loops did not form holes";
        return {};
    }
    return face;
}

}  // namespace sx
