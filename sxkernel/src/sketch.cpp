#include "sx/sketch.hpp"
#include "sx/sketch_regions.hpp"
#include "sx/shape_utils.hpp"
#include "sx/variables.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBndLib.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs_State.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <BRep_Builder.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_HArray1.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <ShapeExtend_WireData.hxx>
#include <ShapeFix_Wire.hxx>
#include "sx/occt_types.hpp"
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Elips.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <algorithm>
#include <cmath>
#include <optional>
#include <set>
#include <sstream>
#include <vector>

namespace sx {

namespace {

gp_Pnt plane_to3d(const SketchPlane& pl, double u, double v) {
    return gp_Pnt(pl.origin[0] + u * pl.x_dir[0] + v * pl.y_dir[0],
                  pl.origin[1] + u * pl.x_dir[1] + v * pl.y_dir[1],
                  pl.origin[2] + u * pl.x_dir[2] + v * pl.y_dir[2]);
}

Handle(Geom_BSplineCurve) interpolate_fits(
    const SketchPlane& pl, const std::vector<std::array<double, 2>>& fits,
    const std::optional<std::array<double, 2>>& start_t = std::nullopt,
    const std::optional<std::array<double, 2>>& end_t = std::nullopt) {
    if (fits.size() < 2) return {};
    const int n = static_cast<int>(fits.size());
    Handle(TColgp_HArray1OfPnt) arr = new TColgp_HArray1OfPnt(1, n);
    for (int i = 0; i < n; ++i)
        arr->SetValue(i + 1, plane_to3d(pl, fits[static_cast<size_t>(i)][0],
                                        fits[static_cast<size_t>(i)][1]));
    GeomAPI_Interpolate interp(arr, false, 1.0e-7);
    if (start_t || end_t) {
        NCollection_Array1<gp_Vec> tans(1, n);
        Handle(NCollection_HArray1<bool>) flags = new NCollection_HArray1<bool>(1, n);
        for (int i = 1; i <= n; ++i) {
            tans.SetValue(i, gp_Vec(0, 0, 0));
            flags->SetValue(i, false);
        }
        auto to_vec = [&](const std::array<double, 2>& uv) {
            const gp_Pnt a = plane_to3d(pl, 0, 0);
            const gp_Pnt b = plane_to3d(pl, uv[0], uv[1]);
            return gp_Vec(a, b);
        };
        if (start_t && std::hypot((*start_t)[0], (*start_t)[1]) > 1e-6) {
            tans.SetValue(1, to_vec(*start_t));
            flags->SetValue(1, true);
        }
        if (end_t && std::hypot((*end_t)[0], (*end_t)[1]) > 1e-6) {
            tans.SetValue(n, to_vec(*end_t));
            flags->SetValue(n, true);
        }
        interp.Load(tans, flags, false);
    }
    interp.Perform();
    if (!interp.IsDone()) return {};
    return interp.Curve();
}

constexpr double kPi = 3.14159265358979323846;
constexpr double kTwoPi = 2.0 * kPi;
// Far enough to catch a 2π branch swap, tight enough to keep float noise.
constexpr double kArcAngleTol = 1e-2;

double wrap_signed_angle(double d) {
    d = std::fmod(d, kTwoPi);
    if (d > kPi) d -= kTwoPi;
    if (d <= -kPi) d += kTwoPi;
    return d;
}

double ccw_sweep(double from, double to) {
    double s = to - from;
    while (s <= 0.0) s += kTwoPi;
    while (s > kTwoPi) s -= kTwoPi;
    return s;
}

// True when start_angle/end_angle do not name the stored endpoints. Writes
// the CCW sweep of those endpoints (end = start + sweep, sweep in (0, 2π]).
bool arc_angles_from_endpoints(double cx, double cy, double sa, double ea,
                               double sx, double sy, double ex, double ey,
                               double& sa_out, double& ea_out) {
    const double sa_pt = std::atan2(sy - cy, sx - cx);
    const double ea_pt = std::atan2(ey - cy, ex - cx);
    if (std::abs(wrap_signed_angle(sa - sa_pt)) <= kArcAngleTol &&
        std::abs(wrap_signed_angle(ea - ea_pt)) <= kArcAngleTol)
        return false;
    double sweep = ccw_sweep(sa_pt, ea_pt);
    if (sweep < 1e-9) sweep = kTwoPi;
    sa_out = sa_pt;
    ea_out = sa_pt + sweep;
    return true;
}

}  // namespace

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
        case ConstraintType::Concentric: return "concentric";
        case ConstraintType::Collinear: return "collinear";
    }
    return "unknown";
}

std::optional<ConstraintType> constraint_type_from_string(const std::string& s) {
    using CT = ConstraintType;
    for (CT ct : {CT::Coincident, CT::Horizontal, CT::Vertical, CT::Parallel,
                  CT::Perpendicular, CT::PointOnLine, CT::Tangent, CT::Equal,
                  CT::Distance, CT::Radius, CT::Angle, CT::Midpoint, CT::Symmetric,
                  CT::Fix, CT::Diameter, CT::Concentric, CT::Collinear}) {
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

void Sketch::set_plane(SketchPlane plane) {
    plane_ = std::move(plane);
    revision_++;
}

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

EntityId Sketch::add_ellipse(double cx, double cy, double rx, double ry, double angle) {
    if (rx < 0.0) rx = -rx;
    if (ry < 0.0) ry = -ry;
    if (rx < 1e-9 || ry < 1e-9) return {};
    if (rx < ry) {
        std::swap(rx, ry);
        angle += kPi * 0.5;
    }
    const double c = std::sqrt(std::max(0.0, rx * rx - ry * ry));
    const double f1x = cx + c * std::cos(angle);
    const double f1y = cy + c * std::sin(angle);
    SketchEntity e;
    e.id = EntityId::generate();
    e.type = SketchEntityType::Ellipse;
    size_t base = push_params({cx, cy, f1x, f1y, ry});
    e.params = {base, base + 1, base + 2, base + 3, base + 4};
    entities_.push_back(e);
    ++revision_;
    return e.id;
}

EntityId Sketch::add_elliptical_arc(double cx, double cy, double rx, double ry, double angle,
                                    double start_angle, double end_angle) {
    if (rx < 0.0) rx = -rx;
    if (ry < 0.0) ry = -ry;
    if (rx < 1e-9 || ry < 1e-9) return {};
    if (rx < ry) {
        std::swap(rx, ry);
        angle += kPi * 0.5;
        start_angle -= kPi * 0.5;
        end_angle -= kPi * 0.5;
    }
    const double c = std::sqrt(std::max(0.0, rx * rx - ry * ry));
    const double ca = std::cos(angle), sa = std::sin(angle);
    const double f1x = cx + c * ca;
    const double f1y = cy + c * sa;
    auto at = [&](double t) {
        const double u = rx * std::cos(t), v = ry * std::sin(t);
        return std::array<double, 2>{cx + u * ca - v * sa, cy + u * sa + v * ca};
    };
    const auto ps = at(start_angle);
    const auto pe = at(end_angle);
    SketchEntity e;
    e.id = EntityId::generate();
    e.type = SketchEntityType::EllipticalArc;
    size_t base = push_params({cx, cy, f1x, f1y, ry, start_angle, end_angle,
                               ps[0], ps[1], pe[0], pe[1]});
    e.params.resize(11);
    for (size_t i = 0; i < 11; ++i) e.params[i] = base + i;
    entities_.push_back(e);
    ++revision_;
    return e.id;
}

void Sketch::reconcile_arc_angles() {
    bool changed = false;
    for (const auto& e : entities_) {
        if (e.type != SketchEntityType::Arc || e.params.size() < 9) continue;
        const double cx = param(e.params[0]);
        const double cy = param(e.params[1]);
        const double sa = param(e.params[3]);
        const double ea = param(e.params[4]);
        double sa_fix = sa, ea_fix = ea;
        if (!arc_angles_from_endpoints(cx, cy, sa, ea, param(e.params[5]), param(e.params[6]),
                                       param(e.params[7]), param(e.params[8]), sa_fix, ea_fix))
            continue;
        param_mut(e.params[3]) = sa_fix;
        param_mut(e.params[4]) = ea_fix;
        changed = true;
    }
    if (changed) ++revision_;
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
                // role center locks the centre only. A full Fix also locks the
                // radius and makes a driving radius dimension redundant.
                if (c.refs[0].role == PointRole::Center)
                    c.locked = {params_[e->params[0]], params_[e->params[1]]};
                else
                    c.locked = {params_[e->params[0]], params_[e->params[1]], params_[e->params[2]]};
            } else if (e->type == SketchEntityType::Spline) {
                c.locked.clear();
                for (size_t i = 1; i < e->params.size(); ++i)
                    c.locked.push_back(params_[e->params[i]]);
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
        case SketchEntityType::Ellipse: {
            auto ax = ellipse_axes(ref.entity);
            if (!ax) return std::nullopt;
            const double cx = (*ax)[0], cy = (*ax)[1], rx = (*ax)[2], ry = (*ax)[3], ang = (*ax)[4];
            const double ca = std::cos(ang), sa = std::sin(ang);
            if (ref.role == PointRole::Center || ref.role == PointRole::Self)
                return std::array<double, 2>{cx, cy};
            if (ref.role == PointRole::Start) return std::array<double, 2>{cx + rx * ca, cy + rx * sa};
            if (ref.role == PointRole::End) return std::array<double, 2>{cx - rx * ca, cy - rx * sa};
            if (ref.role == PointRole::MinorStart)
                return std::array<double, 2>{cx - ry * sa, cy + ry * ca};
            if (ref.role == PointRole::MinorEnd)
                return std::array<double, 2>{cx + ry * sa, cy - ry * ca};
            return std::nullopt;
        }
        case SketchEntityType::EllipticalArc: {
            if (e->params.size() < 11) return std::nullopt;
            if (ref.role == PointRole::Center || ref.role == PointRole::Self)
                return std::array<double, 2>{p(0), p(1)};
            if (ref.role == PointRole::Start) return std::array<double, 2>{p(7), p(8)};
            if (ref.role == PointRole::End) return std::array<double, 2>{p(9), p(10)};
            return std::nullopt;
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

static Handle(Geom_BSplineCurve) interpolating_curve(const Sketch& sk, const EntityId& id) {
    return interpolate_fits(sk.plane(), sk.spline_fit_points(id),
                            sk.spline_end_tangent(id, true),
                            sk.spline_end_tangent(id, false));
}

TopoDS_Edge Sketch::spline_edge(const EntityId& id) const {
    Handle(Geom_BSplineCurve) c = interpolating_curve(*this, id);
    if (c.IsNull()) return {};
    BRepBuilderAPI_MakeEdge mk(c);
    return mk.IsDone() ? mk.Edge() : TopoDS_Edge{};
}

std::vector<std::array<double, 2>> Sketch::spline_samples(const EntityId& id, int n) const {
    std::vector<std::array<double, 2>> out;
    Handle(Geom_BSplineCurve) c = interpolating_curve(*this, id);
    if (c.IsNull() || n < 2) return spline_fit_points(id);
    const double u0 = c->FirstParameter();
    const double u1 = c->LastParameter();
    out.reserve(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        const double t = u0 + (u1 - u0) * (static_cast<double>(i) / (n - 1));
        out.push_back(to_sketch_uv({c->Value(t).X(), c->Value(t).Y(), c->Value(t).Z()}));
    }
    return out;
}

Sketch::SplineGeom Sketch::spline_geom(const EntityId& id) const {
    SplineGeom g;
    Handle(Geom_BSplineCurve) c = interpolating_curve(*this, id);
    if (c.IsNull()) return g;
    g.degree = c->Degree();
    g.ok = true;
    for (int i = 1; i <= c->NbPoles(); ++i) {
        const gp_Pnt p = c->Pole(i);
        g.poles.push_back(to_sketch_uv({p.X(), p.Y(), p.Z()}));
    }
    for (int i = 1; i <= c->NbKnots(); ++i) {
        g.knots.push_back(c->Knot(i));
        g.multiplicities.push_back(c->Multiplicity(i));
    }
    return g;
}

std::vector<std::array<double, 2>> Sketch::interpolate_samples(
    const std::vector<std::array<double, 2>>& fit_points, int n) {
    SketchPlane pl;
    Handle(Geom_BSplineCurve) c = interpolate_fits(pl, fit_points);
    if (c.IsNull() || n < 2) return fit_points;
    const double u0 = c->FirstParameter();
    const double u1 = c->LastParameter();
    std::vector<std::array<double, 2>> out;
    out.reserve(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        const double t = u0 + (u1 - u0) * (static_cast<double>(i) / (n - 1));
        const gp_Pnt p = c->Value(t);
        out.push_back({p.X(), p.Y()});
    }
    return out;
}

namespace {

constexpr int kTanStart = 1;
constexpr int kTanEnd = 2;
// Extra block after [n, x0, y0, ...]: flags, stx, sty, etx, ety
constexpr int kTanBlock = 5;

int spline_n(const Sketch& sk, const SketchEntity& e) {
    if (e.params.empty()) return 0;
    return static_cast<int>(sk.param(e.params[0]));
}

int tan_index(const SketchEntity& e, int n) { return 1 + 2 * n; }

bool has_tan_block(const SketchEntity& e, int n) {
    return static_cast<int>(e.params.size()) >= 1 + 2 * n + kTanBlock;
}

}  // namespace

bool Sketch::set_spline_fit_point(const EntityId& id, int index, double x, double y) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::Spline) return false;
    const int n = spline_n(*this, *e);
    if (index < 0 || index >= n) return false;
    param_mut(e->params[static_cast<size_t>(1 + 2 * index)]) = x;
    param_mut(e->params[static_cast<size_t>(2 + 2 * index)]) = y;
    ++revision_;
    return true;
}

bool Sketch::set_spline_pole(const EntityId& id, int index, double x, double y) {
    Handle(Geom_BSplineCurve) oldc = interpolating_curve(*this, id);
    if (oldc.IsNull()) return false;
    if (index < 0 || index >= oldc->NbPoles()) return false;
    Handle(Geom_BSplineCurve) neu = new Geom_BSplineCurve(*oldc);
    neu->SetPole(index + 1, plane_to3d(plane_, x, y));
    auto fits = spline_fit_points(id);
    for (auto& fp : fits) {
        GeomAPI_ProjectPointOnCurve proj(plane_to3d(plane_, fp[0], fp[1]), oldc);
        if (proj.NbPoints() < 1) continue;
        const gp_Pnt q = neu->Value(proj.LowerDistanceParameter());
        fp = to_sketch_uv({q.X(), q.Y(), q.Z()});
    }
    SketchEntity* e = entity_mut(id);
    if (!e) return false;
    const int n = spline_n(*this, *e);
    const int m = std::min(n, static_cast<int>(fits.size()));
    for (int i = 0; i < m; ++i) {
        param_mut(e->params[static_cast<size_t>(1 + 2 * i)]) = fits[static_cast<size_t>(i)][0];
        param_mut(e->params[static_cast<size_t>(2 + 2 * i)]) = fits[static_cast<size_t>(i)][1];
    }
    ++revision_;
    return true;
}

bool Sketch::set_spline_end_tangent(const EntityId& id, bool at_start, double tx, double ty,
                                    bool enabled) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::Spline) return false;
    const int n = spline_n(*this, *e);
    if (n < 2) return false;
    if (!has_tan_block(*e, n)) {
        const size_t base = push_params({0.0, 0.0, 0.0, 0.0, 0.0});
        for (int i = 0; i < kTanBlock; ++i) e->params.push_back(base + static_cast<size_t>(i));
    }
    const int t0 = tan_index(*e, n);
    int flags = static_cast<int>(param(e->params[static_cast<size_t>(t0)]));
    const int bit = at_start ? kTanStart : kTanEnd;
    if (enabled)
        flags |= bit;
    else
        flags &= ~bit;
    param_mut(e->params[static_cast<size_t>(t0)]) = static_cast<double>(flags);
    const int ox = t0 + (at_start ? 1 : 3);
    const int oy = t0 + (at_start ? 2 : 4);
    param_mut(e->params[static_cast<size_t>(ox)]) = tx;
    param_mut(e->params[static_cast<size_t>(oy)]) = ty;
    ++revision_;
    return true;
}

std::optional<std::array<double, 2>> Sketch::spline_end_tangent(const EntityId& id,
                                                               bool at_start) const {
    const SketchEntity* e = entity(id);
    if (!e || e->type != SketchEntityType::Spline) return std::nullopt;
    const int n = spline_n(*this, *e);
    if (!has_tan_block(*e, n)) return std::nullopt;
    const int t0 = tan_index(*e, n);
    const int flags = static_cast<int>(param(e->params[static_cast<size_t>(t0)]));
    const int bit = at_start ? kTanStart : kTanEnd;
    if ((flags & bit) == 0) return std::nullopt;
    const int ox = t0 + (at_start ? 1 : 3);
    const int oy = t0 + (at_start ? 2 : 4);
    return std::array<double, 2>{param(e->params[static_cast<size_t>(ox)]),
                                 param(e->params[static_cast<size_t>(oy)])};
}

std::array<double, 2> Sketch::spline_end_derivative(const EntityId& id, bool at_start) const {
    Handle(Geom_BSplineCurve) c = interpolating_curve(*this, id);
    if (c.IsNull()) return {0, 0};
    const double u = at_start ? c->FirstParameter() : c->LastParameter();
    gp_Pnt p;
    gp_Vec v;
    c->D1(u, p, v);
    const auto a = to_sketch_uv({p.X(), p.Y(), p.Z()});
    const auto b = to_sketch_uv({p.X() + v.X(), p.Y() + v.Y(), p.Z() + v.Z()});
    return {b[0] - a[0], b[1] - a[1]};
}

std::vector<Sketch::CombTooth> Sketch::spline_comb(const EntityId& id, int n, double scale) const {
    std::vector<CombTooth> out;
    Handle(Geom_BSplineCurve) c = interpolating_curve(*this, id);
    if (c.IsNull() || n < 2) return out;
    const auto nn = plane_.normal();
    gp_Dir nd(nn[0], nn[1], nn[2]);
    const double u0 = c->FirstParameter();
    const double u1 = c->LastParameter();
    out.reserve(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        const double t = u0 + (u1 - u0) * (static_cast<double>(i) / (n - 1));
        gp_Pnt p;
        gp_Vec d1, d2;
        c->D2(t, p, d1, d2);
        CombTooth tooth;
        tooth.at = to_sketch_uv({p.X(), p.Y(), p.Z()});
        const double mag = d1.Magnitude();
        if (mag < 1e-12) {
            tooth.tip = tooth.at;
            out.push_back(tooth);
            continue;
        }
        const double k = d1.Crossed(d2).Magnitude() / (mag * mag * mag);
        gp_Vec side = nd.Crossed(d1);
        if (side.Magnitude() < 1e-12) {
            tooth.tip = tooth.at;
            out.push_back(tooth);
            continue;
        }
        side.Normalize();
        const gp_Pnt tip = p.Translated(side * (k * scale));
        tooth.tip = to_sketch_uv({tip.X(), tip.Y(), tip.Z()});
        out.push_back(tooth);
    }
    return out;
}

void Sketch::sync_spline_line_tangents() {
    for (const auto& c : constraints_) {
        if (c.type != ConstraintType::Tangent || c.refs.size() < 2) continue;
        const SketchEntity* a = entity(c.refs[0].entity);
        const SketchEntity* b = entity(c.refs[1].entity);
        if (!a || !b) continue;
        const SketchEntity* sp = nullptr;
        const SketchEntity* ln = nullptr;
        bool at_start = false;
        if (a->type == SketchEntityType::Spline && b->type == SketchEntityType::Line) {
            sp = a;
            ln = b;
            at_start = c.refs[0].role == PointRole::Start;
        } else if (a->type == SketchEntityType::Line && b->type == SketchEntityType::Spline) {
            sp = b;
            ln = a;
            at_start = c.refs[1].role == PointRole::Start;
        } else {
            continue;
        }
        if (ln->params.size() < 4) continue;
        const double x1 = param(ln->params[0]), y1 = param(ln->params[1]);
        const double x2 = param(ln->params[2]), y2 = param(ln->params[3]);
        auto fits = spline_fit_points(sp->id);
        if (fits.size() < 2) continue;
        const auto& ep = at_start ? fits.front() : fits.back();
        double dx = x2 - x1, dy = y2 - y1;
        const double d1 = std::hypot(x1 - ep[0], y1 - ep[1]);
        const double d2 = std::hypot(x2 - ep[0], y2 - ep[1]);
        if (d2 + 1e-9 < d1) {
            dx = x1 - x2;
            dy = y1 - y2;
        }
        const double len = std::hypot(dx, dy);
        if (len < 1e-9) continue;
        auto cur = spline_end_tangent(sp->id, at_start);
        double mag = cur ? std::hypot((*cur)[0], (*cur)[1]) : 0.0;
        if (mag < 1e-6) {
            const auto der = spline_end_derivative(sp->id, at_start);
            mag = std::hypot(der[0], der[1]);
        }
        if (mag < 1e-6) mag = len;
        set_spline_end_tangent(sp->id, at_start, dx / len * mag, dy / len * mag, true);
    }
}

std::optional<std::array<double, 5>> Sketch::ellipse_axes(const EntityId& id) const {
    const SketchEntity* e = entity(id);
    if (!e || (e->type != SketchEntityType::Ellipse && e->type != SketchEntityType::EllipticalArc) ||
        e->params.size() < 5)
        return std::nullopt;
    const double cx = params_[e->params[0]];
    const double cy = params_[e->params[1]];
    const double f1x = params_[e->params[2]];
    const double f1y = params_[e->params[3]];
    const double b = std::abs(params_[e->params[4]]);
    const double dx = f1x - cx;
    const double dy = f1y - cy;
    const double c = std::hypot(dx, dy);
    const double a = std::sqrt(c * c + b * b);
    const double ang = (c < 1e-12) ? 0.0 : std::atan2(dy, dx);
    return std::array<double, 5>{cx, cy, a, b, ang};
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
    // All selectable solid regions (Selected Contours default = all). Nested
    // wires remain outer+holes; disjoint regions fuse as a compound of faces.
    // A dangling open chain does not erase contour_faces, but a whole-sketch
    // extrude still refuses it with the existing open-loop message.
    bool stray = false;
    std::string ignored;
    contour_faces_impl(&ignored, &stray);
    if (stray) {
        if (err) *err = "profile has an open loop";
        return {};
    }
    return profile_face_selected({}, err);
}

namespace {

gp_Pnt face_com(const TopoDS_Shape& face) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    return props.CentreOfMass();
}

bool point_inside_face(const TopoDS_Face& face, const gp_Pnt& p) {
    BRepClass_FaceClassifier cls(face, p, 1e-6);
    return cls.State() == TopAbs_IN || cls.State() == TopAbs_ON;
}

TopoDS_Face wire_face(const gp_Pln& pln, const TopoDS_Wire& wire) {
    BRepBuilderAPI_MakeFace mk(pln, wire);
    if (mk.IsDone()) return mk.Face();
    BRepBuilderAPI_MakeFace rev(pln, TopoDS::Wire(wire.Reversed()));
    if (rev.IsDone()) return rev.Face();
    return {};
}

TopoDS_Shape largest_face_below(const TopoDS_Shape& shape, double below) {
    TopoDS_Shape best;
    double best_a = -1.0;
    for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next()) {
        const TopoDS_Shape f = ex.Current();
        const double a = std::abs(shape::area(f));
        if (a < below - 1e-6 && a > best_a) {
            best_a = a;
            best = f;
        }
    }
    return best;
}

// Nested interior wires that overlap (two AF hexes, leftover 12-point
// triangles) do not punch through MakeFace. Fuse the hole faces first so
// a sequential cut cannot nibble the ring wall, then cut once.
TopoDS_Shape cut_holes_from_outer(const gp_Pln& pln, const TopoDS_Wire& outer,
                                  const std::vector<TopoDS_Wire>& holes) {
    TopoDS_Face outer_face = wire_face(pln, outer);
    if (outer_face.IsNull()) return {};
    const double outer_area = std::abs(shape::area(outer_face));
    TopoDS_Shape cutter;
    for (const auto& h : holes) {
        TopoDS_Face hf = wire_face(pln, h);
        if (hf.IsNull()) continue;
        if (cutter.IsNull()) {
            cutter = hf;
            continue;
        }
        BRepAlgoAPI_Fuse fuse(cutter, hf);
        fuse.SetFuzzyValue(0.05);
        fuse.Build();
        if (fuse.IsDone() && !fuse.Shape().IsNull()) cutter = fuse.Shape();
    }
    if (cutter.IsNull()) return {};
    BRepAlgoAPI_Cut cut(outer_face, cutter);
    cut.SetFuzzyValue(0.05);
    cut.Build();
    if (!cut.IsDone() || cut.Shape().IsNull()) return {};
    TopoDS_Shape ring = largest_face_below(cut.Shape(), outer_area);
    if (ring.IsNull() || std::abs(shape::area(ring)) >= outer_area - 1e-4) return {};
    return ring;
}

TopoDS_Shape face_with_holes(const gp_Pln& pln, const TopoDS_Wire& outer,
                             const std::vector<TopoDS_Wire>& holes) {
    auto try_build = [&](bool reverse_holes) -> TopoDS_Shape {
        BRepBuilderAPI_MakeFace mk(pln, outer);
        for (const auto& h : holes) {
            TopoDS_Wire hw = h;
            if (reverse_holes) hw = TopoDS::Wire(h.Reversed());
            mk.Add(hw);
        }
        if (!mk.IsDone()) return {};
        return mk.Face();
    };
    TopoDS_Shape face = try_build(true);
    if (face.IsNull()) face = try_build(false);
    double outer_area = 0.0;
    {
        TopoDS_Face of = wire_face(pln, outer);
        if (!of.IsNull()) outer_area = std::abs(shape::area(of));
    }
    // Overlapping interior wires (two AF hexes) make MakeFace over-punch.
    // Two or more holes: boolean-fuse then cut so the union is one hole.
    if (holes.size() >= 2) {
        TopoDS_Shape cut = cut_holes_from_outer(pln, outer, holes);
        if (!cut.IsNull()) return cut;
    }
    if (!face.IsNull() && (holes.empty() || std::abs(shape::area(face)) < outer_area - 1e-4))
        return face;
    if (!face.IsNull() && std::abs(shape::area(face)) >= outer_area - 1e-6) {
        TopoDS_Shape alt = try_build(false);
        if (!alt.IsNull() && std::abs(shape::area(alt)) < outer_area - 1e-6) face = alt;
    }
    if (!holes.empty()) {
        TopoDS_Shape cut = cut_holes_from_outer(pln, outer, holes);
        if (!cut.IsNull()) return cut;
    }
    return face;
}

std::vector<TopoDS_Shape> nest_solid_contours(const gp_Pln& pln,
                                              const std::vector<TopoDS_Face>& simple_faces,
                                              const std::vector<TopoDS_Wire>& wires,
                                              std::string* err) {
    std::vector<double> areas;
    areas.reserve(simple_faces.size());
    for (const auto& f : simple_faces) areas.push_back(shape::area(f));

    std::vector<int> parent(simple_faces.size(), -1);
    for (size_t i = 0; i < simple_faces.size(); ++i) {
        gp_Pnt ci = face_com(simple_faces[i]);
        int best = -1;
        double best_area = 1e300;
        for (size_t j = 0; j < simple_faces.size(); ++j) {
            if (i == j) continue;
            if (areas[j] <= areas[i] + 1e-9) continue;
            if (!point_inside_face(simple_faces[j], ci)) continue;
            if (areas[j] < best_area) {
                best_area = areas[j];
                best = static_cast<int>(j);
            }
        }
        parent[i] = best;
    }

    std::vector<TopoDS_Shape> contours;
    for (size_t i = 0; i < simple_faces.size(); ++i) {
        if (parent[i] != -1) continue;
        std::vector<TopoDS_Wire> holes;
        for (size_t j = 0; j < simple_faces.size(); ++j) {
            if (parent[j] == static_cast<int>(i)) holes.push_back(wires[j]);
        }
        TopoDS_Shape face = holes.empty() ? TopoDS_Shape(simple_faces[i])
                                          : face_with_holes(pln, wires[i], holes);
        if (face.IsNull()) {
            if (err) *err = "contour with holes failed";
            return {};
        }
        contours.push_back(face);
    }
    std::sort(contours.begin(), contours.end(), [](const TopoDS_Shape& a, const TopoDS_Shape& b) {
        double aa = shape::area(a), ba = shape::area(b);
        if (std::abs(aa - ba) > 1e-9) return aa > ba;
        gp_Pnt ca = face_com(a), cb = face_com(b);
        if (std::abs(ca.X() - cb.X()) > 1e-9) return ca.X() < cb.X();
        return ca.Y() < cb.Y();
    });
    return contours;
}

// SW Selected Contours for sketches whose edges share arcs (circle + chord,
// pliers head circle + nose). Split a padded planar face by every sketch edge
// and keep interior regions; leftover frame (touches the pad) is discarded.
std::vector<TopoDS_Shape> contours_by_planar_split(const gp_Pln& pln, const gp_Ax2& ax,
                                                   const std::vector<TopoDS_Edge>& edges,
                                                   std::string* err) {
    if (edges.empty()) return {};
    Bnd_Box box;
    for (const auto& e : edges) BRepBndLib::Add(e, box);
    if (box.IsVoid()) return {};
    box.Enlarge(1.0);
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    gp_Pnt corners[8] = {{xmin, ymin, zmin}, {xmax, ymin, zmin}, {xmin, ymax, zmin},
                         {xmax, ymax, zmin}, {xmin, ymin, zmax}, {xmax, ymin, zmax},
                         {xmin, ymax, zmax}, {xmax, ymax, zmax}};
    gp_Pnt o = ax.Location();
    gp_Vec xv(ax.XDirection()), yv(ax.YDirection());
    double umin = 1e300, umax = -1e300, vmin = 1e300, vmax = -1e300;
    for (const auto& c : corners) {
        gp_Vec d(o, c);
        const double u = d.Dot(xv), v = d.Dot(yv);
        umin = std::min(umin, u);
        umax = std::max(umax, u);
        vmin = std::min(vmin, v);
        vmax = std::max(vmax, v);
    }
    const double span = std::max(umax - umin, vmax - vmin);
    const double m = span * 0.35 + 2.0;
    umin -= m;
    umax += m;
    vmin -= m;
    vmax += m;
    auto at = [&](double u, double v) {
        return gp_Pnt(o.XYZ() + xv.XYZ() * u + yv.XYZ() * v);
    };
    BRepBuilderAPI_MakePolygon poly(at(umin, vmin), at(umax, vmin), at(umax, vmax),
                                    at(umin, vmax), true);
    if (!poly.IsDone()) {
        if (err) *err = "contour pad failed";
        return {};
    }
    BRepBuilderAPI_MakeFace pad(pln, poly.Wire());
    if (!pad.IsDone()) {
        if (err) *err = "contour pad face failed";
        return {};
    }

    BRepAlgoAPI_Splitter splitter;
    sx::occt::ShapeList args, tools;
    args.Append(pad.Face());
    splitter.SetArguments(args);
    for (const auto& e : edges) tools.Append(e);
    splitter.SetTools(tools);
    splitter.SetFuzzyValue(0.05);
    splitter.Build();
    if (!splitter.IsDone()) {
        if (err) *err = "planar contour split failed";
        return {};
    }

    Bnd_Box pad_box;
    BRepBndLib::Add(pad.Face(), pad_box);
    double px0, py0, pz0, px1, py1, pz1;
    pad_box.Get(px0, py0, pz0, px1, py1, pz1);
    const double tolb = std::max(1e-4, span * 1e-4);

    std::vector<TopoDS_Face> simple_faces;
    std::vector<TopoDS_Wire> wires;
    for (TopExp_Explorer ex(splitter.Shape(), TopAbs_FACE); ex.More(); ex.Next()) {
        TopoDS_Face f = TopoDS::Face(ex.Current());
        Bnd_Box fb;
        BRepBndLib::Add(f, fb);
        double fx0, fy0, fz0, fx1, fy1, fz1;
        fb.Get(fx0, fy0, fz0, fx1, fy1, fz1);
        int hits = 0;
        if (std::abs(fx0 - px0) < tolb) ++hits;
        if (std::abs(fy0 - py0) < tolb) ++hits;
        if (std::abs(fz0 - pz0) < tolb) ++hits;
        if (std::abs(fx1 - px1) < tolb) ++hits;
        if (std::abs(fy1 - py1) < tolb) ++hits;
        if (std::abs(fz1 - pz1) < tolb) ++hits;
        // Leftover frame matches the pad bbox on most sides.
        if (hits >= 4) continue;
        if (shape::area(f) < 1e-8) continue;
        simple_faces.push_back(f);
        wires.push_back(BRepTools::OuterWire(f));
    }
    if (simple_faces.empty()) {
        if (err) *err = "no solid contours";
        return {};
    }
    return nest_solid_contours(pln, simple_faces, wires, err);
}

struct CircPad {
    gp_Pnt c;
    double r = 0.0;
};

bool face_has_inner_wire(const TopoDS_Shape& s) {
    if (s.IsNull() || s.ShapeType() != TopAbs_FACE) return false;
    int nw = 0;
    for (TopExp_Explorer wx(TopoDS::Face(s), TopAbs_WIRE); wx.More(); wx.Next()) ++nw;
    return nw > 1;
}

bool any_face_has_inner_wire(const std::vector<TopoDS_Shape>& faces) {
    for (const auto& f : faces) {
        if (face_has_inner_wire(f)) return true;
    }
    return false;
}

constexpr double kPadArea = 50.0;

bool com_inside_circle(const gp_Pnt& p, const std::vector<CircPad>& circs) {
    for (const auto& c : circs) {
        if (c.r > 0.5 && p.Distance(c.c) < c.r - 0.2) return true;
    }
    return false;
}

// Hex leftover cells (~6.5 mm²) sit inside Ø33. A disjoint r=3 disk
// (area ~28) is itself a CircPad, not a sliver of a larger one.
bool sliver_inside_larger_pad(const gp_Pnt& com, double area,
                              const std::vector<CircPad>& circs) {
    if (area >= kPadArea) return false;
    for (const auto& c : circs) {
        if (!(c.r > 0.5) || com.Distance(c.c) >= c.r - 0.2) continue;
        const double pad = kPi * c.r * c.r;
        if (area < 0.25 * pad) return true;
    }
    return false;
}

void sort_faces_by_area(std::vector<TopoDS_Shape>& faces) {
    std::sort(faces.begin(), faces.end(), [](const TopoDS_Shape& a, const TopoDS_Shape& b) {
        const double aa = std::abs(shape::area(a)), ba = std::abs(shape::area(b));
        if (std::abs(aa - ba) > 1e-9) return aa > ba;
        const gp_Pnt ca = face_com(a), cb = face_com(b);
        if (std::abs(ca.X() - cb.X()) > 1e-9) return ca.X() < cb.X();
        return ca.Y() < cb.Y();
    });
}

// Power Trim of overlapping hexes leaves ~6.5 mm² star-tip cells inside Ø33.
// They are not Selected Contours (film/boss show C + ring + handle).
std::vector<TopoDS_Shape> drop_circle_slivers(std::vector<TopoDS_Shape> faces,
                                              const std::vector<CircPad>& circs) {
    if (circs.empty() || faces.size() < 2) return faces;
    std::vector<TopoDS_Shape> out;
    out.reserve(faces.size());
    for (const auto& f : faces) {
        const double a = std::abs(shape::area(f));
        if (sliver_inside_larger_pad(face_com(f), a, circs)) continue;
        out.push_back(f);
    }
    sort_faces_by_area(out);
    return out;
}

struct PntSeg {
    gp_Pnt a, b;
};

// Walk A14 Power Trim opens hex sides, so nest never sees hole wires and the
// Ø33 reads as a full disc (~823). Vertices of the two AF hexes still sit on
// a common circumradius; rebuild those polygons so overlapping holes punch.
std::vector<TopoDS_Wire> recover_concentric_polygon_holes(
    const gp_Ax2& ax, const std::vector<CircPad>& circs,
    const std::vector<PntSeg>& segs) {
    std::vector<TopoDS_Wire> extra;
    const gp_Vec xd(ax.XDirection()), yd(ax.YDirection());
    auto ang = [&](const gp_Pnt& p, const gp_Pnt& c) {
        gp_Vec v(c, p);
        return std::atan2(v.Dot(yd), v.Dot(xd));
    };
    auto make_closed = [&](const std::vector<gp_Pnt>& pts) -> TopoDS_Wire {
        if (pts.size() < 3) return {};
        BRepBuilderAPI_MakePolygon poly;
        for (const auto& p : pts) poly.Add(p);
        poly.Close();
        if (!poly.IsDone()) return {};
        return poly.Wire();
    };
    for (const auto& circ : circs) {
        if (!(circ.r > 1.0)) continue;
        std::vector<gp_Pnt> interior;
        auto consider = [&](const gp_Pnt& p) {
            const double d = p.Distance(circ.c);
            if (d < 0.5 || d > circ.r - 0.25) return;
            for (const auto& q : interior)
                if (p.Distance(q) < 0.12) return;
            interior.push_back(p);
        };
        for (const auto& s : segs) {
            consider(s.a);
            consider(s.b);
        }
        if (interior.size() < 6) continue;
        std::vector<char> claimed(interior.size(), 0);
        std::vector<int> best_idx;
        double best_r = -1.0;
        for (int i = 0; i < static_cast<int>(interior.size()); ++i) {
            if (claimed[static_cast<size_t>(i)]) continue;
            const double ri = interior[static_cast<size_t>(i)].Distance(circ.c);
            std::vector<int> idx;
            for (int j = 0; j < static_cast<int>(interior.size()); ++j) {
                const double rj = interior[static_cast<size_t>(j)].Distance(circ.c);
                if (std::abs(rj - ri) < 0.3) {
                    idx.push_back(j);
                    claimed[static_cast<size_t>(j)] = 1;
                }
            }
            if (static_cast<int>(idx.size()) >= 6 && ri > best_r) {
                best_r = ri;
                best_idx = std::move(idx);
            }
        }
        if (best_idx.size() < 6) continue;
        std::vector<gp_Pnt> ring;
        ring.reserve(best_idx.size());
        for (int i : best_idx) ring.push_back(interior[static_cast<size_t>(i)]);
        std::sort(ring.begin(), ring.end(), [&](const gp_Pnt& a, const gp_Pnt& b) {
            return ang(a, circ.c) < ang(b, circ.c);
        });
        const int n = static_cast<int>(ring.size());
        if (n != 6 && n != 12) continue;
        const double step = 2.0 * 3.14159265358979323846 / static_cast<double>(n);
        bool regular = true;
        for (int i = 0; i < n; ++i) {
            double a0 = ang(ring[static_cast<size_t>(i)], circ.c);
            double a1 = ang(ring[static_cast<size_t>((i + 1) % n)], circ.c);
            double d = a1 - a0;
            if (d < 0.0) d += 2.0 * 3.14159265358979323846;
            if (std::abs(d - step) > 0.14) {
                regular = false;
                break;
            }
        }
        if (!regular) continue;
        int hex_sides = 0;
        for (const auto& s : segs) {
            if (std::abs(s.a.Distance(s.b) - best_r) > 0.6) continue;
            bool a_on = false, b_on = false;
            for (const auto& p : ring) {
                if (s.a.Distance(p) < 0.2) a_on = true;
                if (s.b.Distance(p) < 0.2) b_on = true;
            }
            if (a_on && b_on) ++hex_sides;
        }
        if (hex_sides < 3) continue;
        const int nhex = n / 6;
        for (int h = 0; h < nhex; ++h) {
            std::vector<gp_Pnt> hex;
            hex.reserve(6);
            for (int k = 0; k < 6; ++k)
                hex.push_back(ring[static_cast<size_t>(h + k * nhex)]);
            TopoDS_Wire w = make_closed(hex);
            if (!w.IsNull()) extra.push_back(w);
        }
    }
    return extra;
}

// Punch recovered hexes into the concentric circle pad only — they must not
// enter nest as first-class faces (a leftover C copy can steal them as holes
// and the Ø33 then loses one hex, area 314 instead of 275).
std::vector<TopoDS_Shape> punch_recovered_into_circles(
    std::vector<TopoDS_Shape> faces, const gp_Pln& pln,
    const std::vector<CircPad>& circs, const std::vector<TopoDS_Wire>& holes) {
    if (faces.empty() || holes.empty() || circs.empty()) return faces;
    TopoDS_Shape cutter;
    for (const auto& h : holes) {
        TopoDS_Face hf = wire_face(pln, h);
        if (hf.IsNull()) continue;
        if (cutter.IsNull()) {
            cutter = hf;
            continue;
        }
        BRepAlgoAPI_Fuse fuse(cutter, hf);
        fuse.SetFuzzyValue(0.05);
        fuse.Build();
        if (fuse.IsDone() && !fuse.Shape().IsNull()) cutter = fuse.Shape();
    }
    if (cutter.IsNull()) return faces;
    for (auto& f : faces) {
        const gp_Pnt c = face_com(f);
        bool on_circ = false;
        for (const auto& circ : circs) {
            if (c.Distance(circ.c) < 1.0) {
                on_circ = true;
                break;
            }
        }
        if (!on_circ) continue;
        const double before = std::abs(shape::area(f));
        BRepAlgoAPI_Cut cut(f, cutter);
        cut.SetFuzzyValue(0.05);
        cut.Build();
        if (!cut.IsDone() || cut.Shape().IsNull()) continue;
        TopoDS_Shape ring = largest_face_below(cut.Shape(), before);
        if (!ring.IsNull() && std::abs(shape::area(ring)) < before - 1e-4) f = ring;
    }
    sort_faces_by_area(faces);
    return faces;
}

// A leftover elliptical-arc fragment can chain a second C that sits inside
// the real C. One Selected Contour per pad.
std::vector<TopoDS_Shape> drop_contained_duplicates(std::vector<TopoDS_Shape> faces) {
    if (faces.size() < 2) return faces;
    auto aabb_inside = [](const TopoDS_Shape& inner, const TopoDS_Shape& outer) {
        Bnd_Box bi, bo;
        BRepBndLib::Add(inner, bi);
        BRepBndLib::Add(outer, bo);
        if (bi.IsVoid() || bo.IsVoid()) return false;
        double ix0, iy0, iz0, ix1, iy1, iz1;
        double ox0, oy0, oz0, ox1, oy1, oz1;
        bi.Get(ix0, iy0, iz0, ix1, iy1, iz1);
        bo.Get(ox0, oy0, oz0, ox1, oy1, oz1);
        constexpr double eps = 0.4;
        return ix0 >= ox0 - eps && iy0 >= oy0 - eps && iz0 >= oz0 - eps &&
               ix1 <= ox1 + eps && iy1 <= oy1 + eps && iz1 <= oz1 + eps;
    };
    std::vector<char> drop(faces.size(), 0);
    for (size_t i = 0; i < faces.size(); ++i) {
        if (drop[i] || faces[i].ShapeType() != TopAbs_FACE) continue;
        for (size_t j = 0; j < faces.size(); ++j) {
            if (i == j || drop[j]) continue;
            if (std::abs(shape::area(faces[j])) >= std::abs(shape::area(faces[i])) - 1e-6)
                continue;
            if (!aabb_inside(faces[j], faces[i])) continue;
            if (!point_inside_face(TopoDS::Face(faces[i]), face_com(faces[j]))) continue;
            drop[j] = 1;
        }
    }
    std::vector<TopoDS_Shape> out;
    out.reserve(faces.size());
    for (size_t i = 0; i < faces.size(); ++i)
        if (!drop[i]) out.push_back(faces[i]);
    sort_faces_by_area(out);
    return out;
}

// Nested holes punch the 12-point (area 275). Handle lines only appear in
// the planar split. Add those exterior pads; skip leftover hex cells, the
// hole's own cell (COM inside the un-punched outer), and C-fragments.
std::vector<TopoDS_Shape> nest_plus_split_outers(const gp_Pln& pln,
                                                 const std::vector<TopoDS_Shape>& nested,
                                                 const std::vector<TopoDS_Shape>& split,
                                                 const std::vector<CircPad>& circs) {
    std::vector<TopoDS_Face> outers;
    for (const auto& n : nested) {
        if (!face_has_inner_wire(n)) continue;
        TopoDS_Face of = wire_face(pln, BRepTools::OuterWire(TopoDS::Face(n)));
        if (!of.IsNull()) outers.push_back(of);
    }
    auto inside = [&](const gp_Pnt& p, const TopoDS_Shape& s) {
        if (s.IsNull() || s.ShapeType() != TopAbs_FACE) return false;
        return point_inside_face(TopoDS::Face(s), p);
    };
    std::vector<TopoDS_Shape> out = nested;
    for (const auto& f : split) {
        const double a = std::abs(shape::area(f));
        if (a < kPadArea) continue;
        const gp_Pnt c = face_com(f);
        if (com_inside_circle(c, circs)) continue;
        bool skip = false;
        for (const auto& n : nested) {
            if (inside(c, n)) {
                skip = true;
                break;
            }
        }
        if (skip) continue;
        for (const auto& d : outers) {
            if (inside(c, d)) {
                skip = true;
                break;
            }
        }
        if (skip) continue;
        out.push_back(f);
    }
    sort_faces_by_area(out);
    return out;
}

// Collect closed wires the same way profile_face does (shared by contour APIs).
}  // namespace

std::vector<TopoDS_Shape> Sketch::contour_faces(std::string* err) const {
    return contour_faces_impl(err, nullptr, false);
}

std::vector<TopoDS_Shape> Sketch::arrangement_faces(std::string* err) const {
    return contour_faces_impl(err, nullptr, true);
}

std::vector<TopoDS_Shape> Sketch::chained_faces(std::string* err) const {
    return contour_faces_impl(err, nullptr, false, false);
}

std::vector<TopoDS_Shape> Sketch::contour_faces_impl(std::string* err, bool* stray_open,
                                                     bool prefer_split, bool allow_split) const {
    if (stray_open) *stray_open = false;
    // Build closed wires (same chaining as profile_face), then classify
    // nesting: nested → holes; disjoint → separate Selected Contours solids.
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

    struct Segment {
        gp_Pnt start, end;
        TopoDS_Edge edge;
        bool used = false;
    };
    std::vector<const SketchEntity*> drawn;
    for (const auto& e : entities_)
        if (!e.construction && e.type != SketchEntityType::Point) drawn.push_back(&e);

    if (drawn.size() == 1 && drawn[0]->type == SketchEntityType::Circle) {
        const auto& e = *drawn[0];
        gp_Circ circ(gp_Ax2(to3d(p(e, 0), p(e, 1)), nd, xd), p(e, 2));
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circ).Edge();
        TopoDS_Wire wire = BRepBuilderAPI_MakeWire(edge).Wire();
        BRepBuilderAPI_MakeFace mf(pln, wire);
        if (!mf.IsDone()) {
            if (err) *err = "circle contour failed";
            return {};
        }
        return {mf.Face()};
    }
    if (drawn.size() == 1 && drawn[0]->type == SketchEntityType::Ellipse) {
        auto axes = ellipse_axes(drawn[0]->id);
        if (!axes) {
            if (err) *err = "ellipse params missing";
            return {};
        }
        const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3],
                     ang = (*axes)[4];
        gp_XYZ xell = ax.XDirection().XYZ() * std::cos(ang) + ax.YDirection().XYZ() * std::sin(ang);
        gp_Elips el(gp_Ax2(to3d(cx, cy), nd, gp_Dir(xell)), rx, ry);
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(el).Edge();
        TopoDS_Wire wire = BRepBuilderAPI_MakeWire(edge).Wire();
        BRepBuilderAPI_MakeFace mf(pln, wire);
        if (!mf.IsDone()) {
            if (err) *err = "ellipse contour failed";
            return {};
        }
        return {mf.Face()};
    }

    std::vector<Segment> segs;
    std::vector<TopoDS_Wire> circle_wires;
    for (const auto* ep : drawn) {
        const auto& e = *ep;
        if (e.type == SketchEntityType::Line) {
            gp_Pnt a = to3d(p(e, 0), p(e, 1)), b = to3d(p(e, 2), p(e, 3));
            if (a.Distance(b) < 1e-9) continue;
            segs.push_back({a, b, BRepBuilderAPI_MakeEdge(a, b).Edge()});
        } else if (e.type == SketchEntityType::Arc) {
            gp_Pnt a = to3d(p(e, 5), p(e, 6)), b = to3d(p(e, 7), p(e, 8));
            double sa = p(e, 3), ea = p(e, 4);
            double sa_fix = sa, ea_fix = ea;
            if (arc_angles_from_endpoints(p(e, 0), p(e, 1), sa, ea, p(e, 5), p(e, 6),
                                          p(e, 7), p(e, 8), sa_fix, ea_fix)) {
                sa = sa_fix;
                ea = ea_fix;
            }
            if (ea < sa) ea += kTwoPi;
            gp_Circ circ(gp_Ax2(to3d(p(e, 0), p(e, 1)), nd, xd), p(e, 2));
            TopoDS_Edge edge;
            Handle(Geom_Circle) gc = new Geom_Circle(circ);
            Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(gc, sa, ea);
            BRepBuilderAPI_MakeEdge mk(tr);
            if (mk.IsDone()) {
                edge = mk.Edge();
            } else {
                double mid_angle = 0.5 * (sa + ea);
                gp_Pnt m = to3d(p(e, 0) + p(e, 2) * std::cos(mid_angle),
                                p(e, 1) + p(e, 2) * std::sin(mid_angle));
                GC_MakeArcOfCircle mk3(a, m, b);
                if (!mk3.IsDone()) continue;
                edge = BRepBuilderAPI_MakeEdge(mk3.Value()).Edge();
            }
            segs.push_back({a, b, edge});
        } else if (e.type == SketchEntityType::Spline) {
            TopoDS_Edge edge = spline_edge(e.id);
            if (edge.IsNull()) continue;
            auto fits = spline_fit_points(e.id);
            gp_Pnt a = to3d(fits.front()[0], fits.front()[1]);
            gp_Pnt b = to3d(fits.back()[0], fits.back()[1]);
            segs.push_back({a, b, edge});
        } else if (e.type == SketchEntityType::Circle) {
            gp_Circ circ(gp_Ax2(to3d(p(e, 0), p(e, 1)), nd, xd), p(e, 2));
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circ).Edge();
            circle_wires.push_back(BRepBuilderAPI_MakeWire(edge).Wire());
        } else if (e.type == SketchEntityType::Ellipse) {
            auto axes = ellipse_axes(e.id);
            if (!axes) continue;
            const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3],
                         ang = (*axes)[4];
            gp_XYZ xell = ax.XDirection().XYZ() * std::cos(ang) + ax.YDirection().XYZ() * std::sin(ang);
            gp_Elips el(gp_Ax2(to3d(cx, cy), nd, gp_Dir(xell)), rx, ry);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(el).Edge();
            circle_wires.push_back(BRepBuilderAPI_MakeWire(edge).Wire());
        } else if (e.type == SketchEntityType::EllipticalArc && e.params.size() >= 11) {
            auto axes = ellipse_axes(e.id);
            if (!axes) continue;
            const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3],
                         ang = (*axes)[4];
            gp_XYZ xell = ax.XDirection().XYZ() * std::cos(ang) + ax.YDirection().XYZ() * std::sin(ang);
            gp_Elips el(gp_Ax2(to3d(cx, cy), nd, gp_Dir(xell)), rx, ry);
            Handle(Geom_Ellipse) ge = new Geom_Ellipse(el);
            gp_Pnt a = to3d(p(e, 7), p(e, 8));
            gp_Pnt b = to3d(p(e, 9), p(e, 10));
            BRepBuilderAPI_MakeEdge mk(ge, a, b);
            if (!mk.IsDone()) {
                double sa = p(e, 5), ea = p(e, 6);
                if (ea < sa) ea += kTwoPi;
                Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(ge, sa, ea);
                BRepBuilderAPI_MakeEdge mk2(tr);
                if (!mk2.IsDone()) continue;
                segs.push_back({a, b, mk2.Edge()});
            } else {
                segs.push_back({a, b, mk.Edge()});
            }
        }
    }
    if (segs.empty() && circle_wires.empty()) {
        if (err) *err = "no profile entities in sketch";
        return {};
    }

    // 1e-6 loses float32 arc-angle round-trips (r=60 → ~6e-6 mm). 0.05 mm is
    // still tiny on millimetre parts and matches the pre-revolve endpoint weld.
    constexpr double tol = 0.05;
    std::vector<TopoDS_Edge> all_edges;
    for (const auto& s : segs) all_edges.push_back(s.edge);
    for (const auto& cw : circle_wires) {
        for (TopExp_Explorer ex(cw, TopAbs_EDGE); ex.More(); ex.Next())
            all_edges.push_back(TopoDS::Edge(ex.Current()));
    }
    std::vector<CircPad> circs;
    for (const auto* ep : drawn) {
        if (ep->type != SketchEntityType::Circle) continue;
        circs.push_back({to3d(p(*ep, 0), p(*ep, 1)), p(*ep, 2)});
    }
    std::vector<TopoDS_Wire> wires;
    struct OpenEnds {
        gp_Pnt a, b;
    };
    std::vector<OpenEnds> opens;
    auto unused = [&]() -> Segment* {
        for (auto& s : segs)
            if (!s.used) return &s;
        return nullptr;
    };
    while (Segment* seed = unused()) {
        std::vector<Segment*> chain{seed};
        seed->used = true;
        gp_Pnt loop_start = seed->start;
        gp_Pnt cursor = seed->end;
        bool progressing = true;
        while (progressing && cursor.Distance(loop_start) > tol) {
            progressing = false;
            for (auto& s : segs) {
                if (s.used) continue;
                if (s.start.Distance(cursor) < tol) {
                    chain.push_back(&s);
                    cursor = s.end;
                } else if (s.end.Distance(cursor) < tol) {
                    chain.push_back(&s);
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
            opens.push_back({loop_start, cursor});
            continue;
        }
        BRepBuilderAPI_MakeWire mk_wire;
        for (auto* s : chain) mk_wire.Add(s->edge);
        TopoDS_Wire w;
        if (mk_wire.IsDone()) {
            w = mk_wire.Wire();
        } else {
            Handle(ShapeExtend_WireData) wd = new ShapeExtend_WireData();
            for (auto* s : chain) wd->Add(s->edge);
            ShapeFix_Wire fix;
            fix.Load(wd);
            fix.SetPrecision(tol);
            fix.ClosedWireMode() = true;
            fix.FixConnectedMode() = 1;
            fix.Perform();
            fix.FixConnected(tol);
            fix.FixClosed(tol);
            w = fix.Wire();
            if (w.IsNull()) {
                if (err) *err = "wire construction failed";
                return {};
            }
        }
        wires.push_back(w);
    }
    for (auto& cw : circle_wires) wires.push_back(cw);
    std::vector<TopoDS_Wire> recovered;
    {
        std::vector<PntSeg> psegs;
        psegs.reserve(segs.size());
        for (const auto& s : segs) psegs.push_back({s.start, s.end});
        recovered = recover_concentric_polygon_holes(ax, circs, psegs);
    }
    auto finish_contours = [&](std::vector<TopoDS_Shape> fs) {
        fs = punch_recovered_into_circles(std::move(fs), pln, circs, recovered);
        fs = drop_contained_duplicates(std::move(fs));
        return drop_circle_slivers(std::move(fs), circs);
    };

    bool shared_opens = false;
    if (!opens.empty()) {
        TopoDS_Compound closed_comp;
        BRep_Builder bb;
        bb.MakeCompound(closed_comp);
        int nclosed = 0;
        for (const auto& w : wires) {
            bb.Add(closed_comp, w);
            ++nclosed;
        }
        auto on_closed = [&](const gp_Pnt& p) {
            if (nclosed == 0) return false;
            TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(p).Vertex();
            BRepExtrema_DistShapeShape ds(v, closed_comp);
            return ds.IsDone() && ds.Value() < 1e-4;
        };
        bool shared = nclosed > 0;
        for (const auto& oc : opens) {
            if (!on_closed(oc.a) || !on_closed(oc.b)) {
                shared = false;
                break;
            }
        }
        shared_opens = shared;
        if (!wires.empty()) {
            // Dangling chains only. Shared opens (chord, pliers, leftover hex
            // on Ø33) still nest or split below so overlapping hex holes punch.
            if (!shared && stray_open) *stray_open = true;
        } else if (!shared) {
            if (err) *err = "profile has an open loop";
            return {};
        } else {
            auto split = contours_by_planar_split(pln, ax, all_edges, err);
            if (!split.empty()) return finish_contours(std::move(split));
            if (err) *err = "profile has an open loop";
            return {};
        }
    }

    if (wires.empty()) {
        if (err) *err = "no closed profile";
        return {};
    }

    std::vector<TopoDS_Face> simple_faces;
    for (const auto& w : wires) {
        BRepBuilderAPI_MakeFace mf(pln, w);
        if (!mf.IsDone()) {
            if (err) *err = "contour face failed";
            return {};
        }
        simple_faces.push_back(mf.Face());
    }

    auto contours = nest_solid_contours(pln, simple_faces, wires, err);
    auto split = contours_by_planar_split(pln, ax, all_edges, nullptr);
    auto max_area = [](const std::vector<TopoDS_Shape>& fs) {
        double m = 0.0;
        for (const auto& f : fs) m = std::max(m, std::abs(shape::area(f)));
        return m;
    };
    const double split_a = max_area(split);
    const double chain_a = max_area(contours);
    auto sliverless = drop_circle_slivers(split, circs);
    if (any_face_has_inner_wire(contours) && !contours.empty())
        return finish_contours(nest_plus_split_outers(pln, contours, split, circs));
    if (shared_opens && !sliverless.empty())
        return finish_contours(std::move(sliverless));
    if (prefer_split && split_a >= chain_a * 0.8 && !sliverless.empty())
        return finish_contours(std::move(sliverless));
    if (allow_split && split_a > chain_a * 1.2)
        return finish_contours(std::move(sliverless));
    if (contours.empty()) {
        if (!sliverless.empty()) return finish_contours(std::move(sliverless));
        if (err && err->empty()) *err = "no solid contours";
        return {};
    }
    return finish_contours(std::move(contours));
}

namespace {

bool uv_near(const std::array<double, 2>& a, const std::array<double, 2>& b) {
    return std::hypot(a[0] - b[0], a[1] - b[1]) <= 1e-9;
}

void append_uv(std::vector<std::array<double, 2>>& loop, const std::array<double, 2>& p) {
    if (!loop.empty() && uv_near(loop.back(), p)) return;
    loop.push_back(p);
}

void sample_wire_uv(const TopoDS_Wire& wire, const TopoDS_Face& face, double deflection,
                    const gp_Pnt& origin, const gp_Vec& x_dir, const gp_Vec& y_dir,
                    std::vector<std::array<double, 2>>& loop) {
    auto project = [&](const gp_Pnt& p) {
        gp_Vec d(origin, p);
        return std::array<double, 2>{d.Dot(x_dir), d.Dot(y_dir)};
    };
    auto take_edge = [&](const TopoDS_Edge& edge) {
        BRepAdaptor_Curve curve(edge);
        std::vector<gp_Pnt> pts;
        if (curve.GetType() == GeomAbs_Line) {
            pts.push_back(curve.Value(curve.FirstParameter()));
            pts.push_back(curve.Value(curve.LastParameter()));
        } else {
            try {
                GCPnts_QuasiUniformDeflection samp(curve, deflection);
                if (samp.IsDone()) {
                    for (int i = 1; i <= samp.NbPoints(); ++i)
                        pts.push_back(samp.Value(i));
                }
            } catch (...) {
            }
            if (pts.size() < 2) {
                pts.clear();
                pts.push_back(curve.Value(curve.FirstParameter()));
                pts.push_back(curve.Value(curve.LastParameter()));
            }
            // A full circle at deflection 0.05 is dozens of points; tiny
            // circles (and short arcs the sampler under-samples) clamp to 48.
            if (curve.GetType() == GeomAbs_Circle && static_cast<int>(pts.size()) < 48) {
                const double u0 = curve.FirstParameter();
                const double u1 = curve.LastParameter();
                const double span = std::abs(u1 - u0);
                const bool full = std::abs(span - 6.283185307179586) < 1e-4;
                pts.clear();
                constexpr int n = 48;
                const int last = full ? n - 1 : n;
                for (int i = 0; i <= last; ++i) {
                    const double u =
                        u0 + (u1 - u0) * (static_cast<double>(i) / static_cast<double>(n));
                    pts.push_back(curve.Value(u));
                }
            }
        }
        if (edge.Orientation() == TopAbs_REVERSED) std::reverse(pts.begin(), pts.end());
        for (const auto& p : pts) append_uv(loop, project(p));
    };
    bool any = false;
    for (BRepTools_WireExplorer exp(wire, face); exp.More(); exp.Next()) {
        any = true;
        take_edge(TopoDS::Edge(exp.Current()));
    }
    if (!any) {
        for (TopExp_Explorer ex(wire, TopAbs_EDGE); ex.More(); ex.Next())
            take_edge(TopoDS::Edge(ex.Current()));
    }
    if (loop.size() >= 2 && uv_near(loop.front(), loop.back())) loop.pop_back();
}

}  // namespace

std::vector<Sketch::ContourOutline> Sketch::contour_outlines(double deflection,
                                                            std::string* err) const {
    auto faces = contour_faces(err);
    if (faces.empty()) return {};
    if (!(deflection > 0.0)) deflection = 0.05;
    const gp_Pnt origin(plane_.origin[0], plane_.origin[1], plane_.origin[2]);
    const gp_Vec x_dir(plane_.x_dir[0], plane_.x_dir[1], plane_.x_dir[2]);
    const gp_Vec y_dir(plane_.y_dir[0], plane_.y_dir[1], plane_.y_dir[2]);
    std::vector<ContourOutline> out;
    out.reserve(faces.size());
    for (const auto& shape : faces) {
        if (shape.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(shape);
        const TopoDS_Wire outer_wire = BRepTools::OuterWire(face);
        ContourOutline region;
        region.area = shape::area(face);
        for (TopExp_Explorer wx(face, TopAbs_WIRE); wx.More(); wx.Next()) {
            const TopoDS_Wire wire = TopoDS::Wire(wx.Current());
            std::vector<std::array<double, 2>> loop;
            sample_wire_uv(wire, face, deflection, origin, x_dir, y_dir, loop);
            if (wire.IsSame(outer_wire)) region.outer = std::move(loop);
            else region.holes.push_back(std::move(loop));
        }
        if (!region.outer.empty()) {
            double minx = region.outer[0][0], miny = region.outer[0][1];
            double maxx = minx, maxy = miny;
            for (const auto& p : region.outer) {
                minx = std::min(minx, p[0]);
                miny = std::min(miny, p[1]);
                maxx = std::max(maxx, p[0]);
                maxy = std::max(maxy, p[1]);
            }
            region.min = {minx, miny};
            region.size = {maxx - minx, maxy - miny};
            region.center = {(minx + maxx) * 0.5, (miny + maxy) * 0.5};
        }
        out.push_back(std::move(region));
    }
    return out;
}

TopoDS_Shape Sketch::profile_face_selected(const std::vector<int>& indices,
                                           std::string* err) const {
    return profile_face_selected(indices, {}, err);
}

TopoDS_Shape Sketch::profile_face_selected(const std::vector<int>& indices,
                                           const TopoDS_Shape& host_face,
                                           std::string* err) const {
    auto arranged = SketchRegions::arrange(*this, host_face);
    auto contours = arranged.faces;
    if (contours.empty()) {
        if (err) *err = arranged.error.empty() ? "no contours" : arranged.error;
        return {};
    }
    std::vector<int> grown = indices;
    if (!grown.empty()) {
        constexpr double kSliver = 20.0;
        std::set<int> want(grown.begin(), grown.end());
        auto aabb_touch = [](const TopoDS_Shape& a, const TopoDS_Shape& b) {
            Bnd_Box ba, bb;
            BRepBndLib::Add(a, ba);
            BRepBndLib::Add(b, bb);
            if (ba.IsVoid() || bb.IsVoid()) return false;
            ba.Enlarge(0.2);
            return !ba.IsOut(bb);
        };
        // Hex leftovers sit inside the ring AABB. Absorbing them fills the
        // 12-point. Chord crumbs that bridge handle-to-head stick out.
        auto aabb_inside = [](const TopoDS_Shape& inner, const TopoDS_Shape& outer) {
            Bnd_Box bi, bo;
            BRepBndLib::Add(inner, bi);
            BRepBndLib::Add(outer, bo);
            if (bi.IsVoid() || bo.IsVoid()) return false;
            double ix0, iy0, iz0, ix1, iy1, iz1;
            double ox0, oy0, oz0, ox1, oy1, oz1;
            bi.Get(ix0, iy0, iz0, ix1, iy1, iz1);
            bo.Get(ox0, oy0, oz0, ox1, oy1, oz1);
            constexpr double eps = 0.05;
            return ix0 >= ox0 - eps && iy0 >= oy0 - eps && iz0 >= oz0 - eps &&
                   ix1 <= ox1 + eps && iy1 <= oy1 + eps && iz1 <= oz1 + eps;
        };
        bool progressed = true;
        while (progressed) {
            progressed = false;
            for (int i = 0; i < static_cast<int>(contours.size()); ++i) {
                if (want.count(i)) continue;
                const double a = shape::area(contours[static_cast<size_t>(i)]);
                if (a <= 0.0 || a >= kSliver) continue;
                for (int j : want) {
                    if (j < 0 || j >= static_cast<int>(contours.size())) continue;
                    const TopoDS_Shape& sliver = contours[static_cast<size_t>(i)];
                    const TopoDS_Shape& pad = contours[static_cast<size_t>(j)];
                    if (aabb_inside(sliver, pad)) continue;
                    if (!aabb_touch(sliver, pad)) continue;
                    want.insert(i);
                    progressed = true;
                    break;
                }
            }
        }
        grown.assign(want.begin(), want.end());
    }
    std::vector<TopoDS_Shape> picked;
    if (grown.empty()) {
        picked = contours;
    } else {
        for (int idx : grown) {
            if (idx < 0 || idx >= static_cast<int>(contours.size())) {
                if (err) *err = "selected contour index out of range";
                return {};
            }
            picked.push_back(contours[static_cast<size_t>(idx)]);
        }
    }
    if (picked.size() == 1) return picked[0];
    TopoDS_Compound comp;
    BRep_Builder builder;
    builder.MakeCompound(comp);
    for (const auto& f : picked) builder.Add(comp, f);
    return comp;
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
        bool arc = false;
        double cx = 0, cy = 0, r = 0, sa = 0, ea = 0;
        bool used = false;
    };
    std::vector<UVSeg> segs;
    for (const auto& e : entities_) {
        if (e.construction) continue;
        if (e.type == SketchEntityType::Line) {
            double x1 = p(e, 0), y1 = p(e, 1), x2 = p(e, 2), y2 = p(e, 3);
            if (std::hypot(x2 - x1, y2 - y1) < 1e-9) continue;
            segs.push_back({x1, y1, x2, y2, false, 0, 0, 0, 0, 0, false});
        } else if (e.type == SketchEntityType::Arc && e.params.size() >= 9) {
            segs.push_back({p(e, 5), p(e, 6), p(e, 7), p(e, 8), true, p(e, 0), p(e, 1),
                            p(e, 2), p(e, 3), p(e, 4), false});
        }
    }
    if (segs.empty()) {
        // Circles and arcs are closed (or curved) profiles, not a missing line
        // chain. Same sentence FeatureGraph reports for a closed contour.
        bool curve = false;
        bool line = false;
        for (const auto& e : entities_) {
            if (e.construction) continue;
            if (e.type == SketchEntityType::Line) line = true;
            else if (e.type == SketchEntityType::Circle || e.type == SketchEntityType::Arc
                     || e.type == SketchEntityType::Ellipse
                     || e.type == SketchEntityType::EllipticalArc)
                curve = true;
        }
        if (err) {
            if (curve && !line) {
                std::ostringstream os;
                os << "Thin wall is on (" << thickness << " mm) — set 0 for a solid";
                *err = os.str();
            } else {
                *err = "no usable open line chain for thin profile";
            }
        }
        return {};
    }

    constexpr double tol = 1e-6;
    auto near = [&](double ax, double ay, double bx, double by) {
        return std::hypot(ax - bx, ay - by) < tol;
    };

    // Greedy-chain line/arc segments into one open path.
    struct Link {
        UVSeg* s = nullptr;
        bool rev = false;
    };
    UVSeg* seed = &segs[0];
    seed->used = true;
    std::vector<Link> chain{{seed, false}};
    auto extend = [&](bool forward) {
        bool progressing = true;
        while (progressing) {
            progressing = false;
            const Link& tip = forward ? chain.back() : chain.front();
            const double cx = (!tip.rev) == forward ? tip.s->x2 : tip.s->x1;
            const double cy = (!tip.rev) == forward ? tip.s->y2 : tip.s->y1;
            for (auto& s : segs) {
                if (s.used) continue;
                bool rev = false;
                bool hit = false;
                if (near(s.x1, s.y1, cx, cy)) {
                    hit = true;
                    rev = !forward;
                } else if (near(s.x2, s.y2, cx, cy)) {
                    hit = true;
                    rev = forward;
                }
                if (!hit) continue;
                s.used = true;
                if (forward) chain.push_back({&s, rev});
                else chain.insert(chain.begin(), {&s, rev});
                progressing = true;
                break;
            }
        }
    };
    extend(true);
    extend(false);
    if (chain.size() < 1) {
        if (err) *err = "no usable open line chain for thin profile";
        return {};
    }

    const double dist = midplane ? (flip_side ? -thickness * 0.5 : thickness * 0.5)
                                 : (flip_side ? -thickness : thickness);
    const double dist_b = midplane ? -dist : 0.0;

    auto left_n = [](double x1, double y1, double x2, double y2) {
        double dx = x2 - x1, dy = y2 - y1, len = std::hypot(dx, dy);
        if (len < 1e-12) return std::array<double, 2>{0.0, 0.0};
        return std::array<double, 2>{-dy / len, dx / len};
    };
    auto shift = [&](double x, double y, double x2, double y2, double d) {
        auto nrm = left_n(x, y, x2, y2);
        return std::array<double, 2>{x + d * nrm[0], y + d * nrm[1]};
    };

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

    auto add_seg = [&](BRepBuilderAPI_MakeWire& wire, const Link& ln, double d, bool reverse_dir) {
        UVSeg& s = *ln.s;
        bool rev = ln.rev != reverse_dir;
        if (s.arc) {
            // Left of a CCW traveler points toward the centre, so +d shrinks r.
            const double nr = std::abs(s.r - (rev ? -d : d));
            if (nr < 1e-9) return;
            double sa = rev ? s.ea : s.sa;
            double ea = rev ? s.sa : s.ea;
            gp_Circ circ(gp_Ax2(to3d(s.cx, s.cy), nd, xd), nr);
            Handle(Geom_Circle) gc = new Geom_Circle(circ);
            if (ea < sa) ea += kTwoPi;
            Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(gc, sa, ea);
            BRepBuilderAPI_MakeEdge mk(tr);
            if (mk.IsDone()) wire.Add(mk.Edge());
        } else {
            double x1 = s.x1, y1 = s.y1, x2 = s.x2, y2 = s.y2;
            if (rev) {
                std::swap(x1, x2);
                std::swap(y1, y2);
            }
            auto a = shift(x1, y1, x2, y2, d);
            auto b = shift(x2, y2, x1, y1, -d);
            // Endpoints share the same left normal along the line.
            b = shift(x2, y2, x2 + (x2 - x1), y2 + (y2 - y1), d);
            gp_Pnt pa = to3d(a[0], a[1]), pb = to3d(b[0], b[1]);
            if (pa.Distance(pb) > 1e-9) wire.Add(BRepBuilderAPI_MakeEdge(pa, pb).Edge());
        }
    };

    BRepBuilderAPI_MakeWire wire;
    for (const auto& ln : chain) add_seg(wire, ln, dist, false);
    // Caps and return path at dist_b (0 = original).
    auto end_uv = [&](const Link& ln, bool at_end, double d) {
        UVSeg& s = *ln.s;
        bool rev = ln.rev;
        double x1 = s.x1, y1 = s.y1, x2 = s.x2, y2 = s.y2;
        if (rev) {
            std::swap(x1, x2);
            std::swap(y1, y2);
        }
        if (s.arc) {
            const double nr = std::abs(s.r - (rev ? -d : d));
            double ang = at_end ? (rev ? s.sa : s.ea) : (rev ? s.ea : s.sa);
            return std::array<double, 2>{s.cx + nr * std::cos(ang), s.cy + nr * std::sin(ang)};
        }
        return at_end ? shift(x2, y2, x2 + (x2 - x1), y2 + (y2 - y1), d)
                      : shift(x1, y1, x2, y2, d);
    };
    auto a_end = end_uv(chain.back(), true, dist);
    auto b_end = end_uv(chain.back(), true, dist_b);
    auto a_st = end_uv(chain.front(), false, dist);
    auto b_st = end_uv(chain.front(), false, dist_b);
    {
        gp_Pnt pa = to3d(a_end[0], a_end[1]), pb = to3d(b_end[0], b_end[1]);
        if (pa.Distance(pb) > 1e-9) wire.Add(BRepBuilderAPI_MakeEdge(pa, pb).Edge());
    }
    for (size_t i = chain.size(); i-- > 0;) add_seg(wire, chain[i], dist_b, true);
    {
        gp_Pnt pa = to3d(b_st[0], b_st[1]), pb = to3d(a_st[0], a_st[1]);
        if (pa.Distance(pb) > 1e-9) wire.Add(BRepBuilderAPI_MakeEdge(pa, pb).Edge());
    }
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

TopoDS_Shape Sketch::open_cut_profile_face(bool flip_side, double pad_extent,
                                           std::string* err) const {
    // Half-plane cut tool: walk the open line chain, then close with a far
    // offset on the cut side. Matches SW Flip Side to Cut (not Thin Feature).
    if (!(pad_extent > 0.0)) {
        if (err) *err = "open-cut pad extent must be > 0";
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
        if (err) *err = "open-cut needs a non-construction line chain";
        return {};
    }

    constexpr double tol = 1e-6;
    auto near = [&](double ax, double ay, double bx, double by) {
        return std::hypot(ax - bx, ay - by) < tol;
    };
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
    if (pts.size() < 2) {
        if (err) *err = "open-cut chain degenerate";
        return {};
    }
    // Closed chain → not an open cut (caller should use profile_face).
    if (near(pts.front()[0], pts.front()[1], pts.back()[0], pts.back()[1])) {
        if (err) *err = "profile is closed — use solid cut, not open-cut";
        return {};
    }

    // Average left-hand normals along the chain → cut side.
    double nx = 0.0, ny = 0.0;
    for (size_t i = 0; i + 1 < pts.size(); ++i) {
        double dx = pts[i + 1][0] - pts[i][0];
        double dy = pts[i + 1][1] - pts[i][1];
        double len = std::hypot(dx, dy);
        if (len < 1e-12) continue;
        nx += -dy / len;
        ny += dx / len;
    }
    double nlen = std::hypot(nx, ny);
    if (nlen < 1e-12) {
        if (err) *err = "open-cut normal undefined";
        return {};
    }
    nx /= nlen;
    ny /= nlen;
    if (flip_side) {
        nx = -nx;
        ny = -ny;
    }

    std::vector<std::array<double, 2>> poly = pts;
    // Far corners on the cut side (pad past the body silhouette).
    poly.push_back({pts.back()[0] + nx * pad_extent, pts.back()[1] + ny * pad_extent});
    poly.push_back({pts.front()[0] + nx * pad_extent, pts.front()[1] + ny * pad_extent});

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

    BRepBuilderAPI_MakeWire wire;
    for (size_t i = 0; i < poly.size(); ++i) {
        const auto& a = poly[i];
        const auto& b = poly[(i + 1) % poly.size()];
        gp_Pnt pa = to3d(a[0], a[1]);
        gp_Pnt pb = to3d(b[0], b[1]);
        if (pa.Distance(pb) < 1e-9) continue;
        wire.Add(BRepBuilderAPI_MakeEdge(pa, pb).Edge());
    }
    if (!wire.IsDone()) {
        if (err) *err = "open-cut wire failed";
        return {};
    }
    BRepBuilderAPI_MakeFace mk(pln, wire.Wire());
    if (!mk.IsDone()) {
        if (err) *err = "open-cut face failed";
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

EntityId Sketch::project_arc_edge(const std::array<double, 3>& center, double radius,
                                  const std::array<double, 3>& a, const std::array<double, 3>& b,
                                  double span, const std::string& edge_id) {
    auto uc = to_sketch_uv(center);
    auto ua = to_sketch_uv(a);
    auto ub = to_sketch_uv(b);
    double sa = std::atan2(ua[1] - uc[1], ua[0] - uc[0]);
    double ea = std::atan2(ub[1] - uc[1], ub[0] - uc[0]);
    if (ea <= sa) ea += 2.0 * kPi;
    double sweep = ea - sa;
    const double want = std::abs(span);
    if (want > 1e-9 && std::abs(sweep - want) > 0.2 &&
        std::abs((2.0 * kPi - sweep) - want) < 0.2) {
        std::swap(sa, ea);
        if (ea <= sa) ea += 2.0 * kPi;
    }
    EntityId id = add_arc(uc[0], uc[1], radius, sa, ea);
    set_external(id, true, edge_id);
    add_constraint(ConstraintType::Fix, {{id, PointRole::Self}}, 0.0, true);
    return id;
}

EntityId Sketch::project_spline_edge(const std::vector<std::array<double, 2>>& fit_points,
                                     const std::string& edge_id) {
    EntityId id = add_spline(fit_points);
    if (id.is_null()) return {};
    set_external(id, true, edge_id);
    add_constraint(ConstraintType::Fix, {{id, PointRole::Self}}, 0.0, true);
    return id;
}

EntityId Sketch::project_ellipse_edge(double cx, double cy, double rx, double ry, double angle,
                                      const std::string& edge_id) {
    EntityId id = add_ellipse(cx, cy, rx, ry, angle);
    if (id.is_null()) return {};
    set_external(id, true, edge_id);
    add_constraint(ConstraintType::Fix, {{id, PointRole::Self}}, 0.0, true);
    return id;
}

EntityId Sketch::project_elliptical_arc_edge(double cx, double cy, double rx, double ry, double angle,
                                             double start_angle, double end_angle,
                                             const std::string& edge_id) {
    EntityId id = add_elliptical_arc(cx, cy, rx, ry, angle, start_angle, end_angle);
    if (id.is_null()) return {};
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

bool Sketch::update_projected_arc(const EntityId& id, const std::array<double, 3>& center,
                                  double radius, const std::array<double, 3>& a,
                                  const std::array<double, 3>& b, double span) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::Arc || !e->external || e->params.size() < 9)
        return false;
    auto uc = to_sketch_uv(center);
    auto ua = to_sketch_uv(a);
    auto ub = to_sketch_uv(b);
    double sa = std::atan2(ua[1] - uc[1], ua[0] - uc[0]);
    double ea = std::atan2(ub[1] - uc[1], ub[0] - uc[0]);
    if (ea <= sa) ea += 2.0 * kPi;
    double sweep = ea - sa;
    const double want = std::abs(span);
    if (want > 1e-9 && std::abs(sweep - want) > 0.2 &&
        std::abs((2.0 * kPi - sweep) - want) < 0.2) {
        std::swap(sa, ea);
        if (ea <= sa) ea += 2.0 * kPi;
    }
    params_[e->params[0]] = uc[0];
    params_[e->params[1]] = uc[1];
    params_[e->params[2]] = radius;
    params_[e->params[3]] = sa;
    params_[e->params[4]] = ea;
    params_[e->params[5]] = ua[0];
    params_[e->params[6]] = ua[1];
    params_[e->params[7]] = ub[0];
    params_[e->params[8]] = ub[1];
    ++revision_;
    return true;
}

bool Sketch::update_projected_ellipse(const EntityId& id, double cx, double cy, double rx, double ry,
                                      double angle) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::Ellipse || !e->external || e->params.size() < 5)
        return false;
    if (rx < 0.0) rx = -rx;
    if (ry < 0.0) ry = -ry;
    if (rx < 1e-9 || ry < 1e-9) return false;
    if (rx < ry) {
        std::swap(rx, ry);
        angle += kPi * 0.5;
    }
    const double c = std::sqrt(std::max(0.0, rx * rx - ry * ry));
    params_[e->params[0]] = cx;
    params_[e->params[1]] = cy;
    params_[e->params[2]] = cx + c * std::cos(angle);
    params_[e->params[3]] = cy + c * std::sin(angle);
    params_[e->params[4]] = ry;
    ++revision_;
    return true;
}

bool Sketch::update_projected_elliptical_arc(const EntityId& id, double cx, double cy, double rx,
                                             double ry, double angle, double start_angle,
                                             double end_angle) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::EllipticalArc || !e->external || e->params.size() < 11)
        return false;
    if (rx < 0.0) rx = -rx;
    if (ry < 0.0) ry = -ry;
    if (rx < 1e-9 || ry < 1e-9) return false;
    if (rx < ry) {
        std::swap(rx, ry);
        angle += kPi * 0.5;
        start_angle -= kPi * 0.5;
        end_angle -= kPi * 0.5;
    }
    const double c = std::sqrt(std::max(0.0, rx * rx - ry * ry));
    const double ca = std::cos(angle), sa = std::sin(angle);
    auto at = [&](double t) {
        const double u = rx * std::cos(t), v = ry * std::sin(t);
        return std::array<double, 2>{cx + u * ca - v * sa, cy + u * sa + v * ca};
    };
    const auto ps = at(start_angle);
    const auto pe = at(end_angle);
    params_[e->params[0]] = cx;
    params_[e->params[1]] = cy;
    params_[e->params[2]] = cx + c * ca;
    params_[e->params[3]] = cy + c * sa;
    params_[e->params[4]] = ry;
    params_[e->params[5]] = start_angle;
    params_[e->params[6]] = end_angle;
    params_[e->params[7]] = ps[0];
    params_[e->params[8]] = ps[1];
    params_[e->params[9]] = pe[0];
    params_[e->params[10]] = pe[1];
    ++revision_;
    return true;
}

bool Sketch::update_projected_spline(const EntityId& id,
                                     const std::vector<std::array<double, 2>>& fit_points) {
    SketchEntity* e = entity_mut(id);
    if (!e || e->type != SketchEntityType::Spline || !e->external) return false;
    if (fit_points.size() < 2) return false;
    const int n = static_cast<int>(params_[e->params[0]]);
    if (n < 2 || static_cast<int>(fit_points.size()) != n) return false;
    if (e->params.size() < static_cast<size_t>(1 + 2 * n)) return false;
    for (int i = 0; i < n; ++i) {
        params_[e->params[static_cast<size_t>(1 + 2 * i)]] = fit_points[static_cast<size_t>(i)][0];
        params_[e->params[static_cast<size_t>(2 + 2 * i)]] = fit_points[static_cast<size_t>(i)][1];
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
        } else if (e.type == SketchEntityType::EllipticalArc && e.params.size() >= 11) {
            add_end(params_[e.params[7]], params_[e.params[8]], e.id);
            add_end(params_[e.params[9]], params_[e.params[10]], e.id);
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
