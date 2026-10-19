// PlaneGCS-backed SolverBackend. Translates a sx::Sketch into GCS::System
// geometry (raw double* into a scratch parameter buffer), solves, and writes
// results back. PlaneGCS is LGPL and dynamically linked (see THIRD_PARTY.md).

#include <GCS.h>

#include <algorithm>
#include <cmath>
#include <unordered_map>

#include "sx/log.hpp"
#include "sx/sketch.hpp"
#include "sx/solver.hpp"

namespace sx {

namespace {

class PlaneGCSBackendImpl : public SolverBackend {
public:
    const char* name() const override { return "planegcs"; }
    SolveResult solve(Sketch& sketch) override;
};

// PlaneGCS line–circle tangency is a signed distance of +radius when the
// centre lies to the left of p1→p2. A shaft drawn small→large along +X at
// y = +r has the centre on the right, so the error is −2r. DogLeg then flips
// the line or the rank check paints that tangent (and its H badge) conflicting.
// Swap only this constraint's endpoint pointers so the drawn side is the
// zero-error side. The sketch geometry is not reversed.
GCS::Line tangent_line_oriented(const GCS::Line& line, const GCS::Point& center) {
    GCS::Line oriented = line;
    double x0 = *center.x;
    double y0 = *center.y;
    double x1 = *line.p1.x;
    double y1 = *line.p1.y;
    double x2 = *line.p2.x;
    double y2 = *line.p2.y;
    double dx = x2 - x1;
    double dy = y2 - y1;
    double area = -x0 * dy + y0 * dx + x1 * y2 - x2 * y1;
    if (area < 0.0) {
        std::swap(oriented.p1, oriented.p2);
    }
    return oriented;
}

// The point keeps the side it already occupies.
static bool point_left_of_line(const GCS::Point& point, const GCS::Line& line) {
    const double x0 = *point.x, y0 = *point.y;
    const double x1 = *line.p1.x, y1 = *line.p1.y;
    const double x2 = *line.p2.x, y2 = *line.p2.y;
    const double area = -x0 * (y2 - y1) + y0 * (x2 - x1) + x1 * y2 - x2 * y1;
    return area >= 0.0;
}

// Per-solve translation state.
struct Xlate {
    Sketch& sketch;
    GCS::System sys;
    // Scratch copy of parameters; GCS solves against these addresses.
    std::vector<double*> owned;
    std::unordered_map<size_t, double*> by_index;  // sketch param index -> scratch
    std::unordered_map<EntityId, GCS::Point> points;
    std::unordered_map<EntityId, GCS::Line> lines;
    std::unordered_map<EntityId, GCS::Circle> circles;
    std::unordered_map<EntityId, GCS::Arc> arcs;
    std::unordered_map<EntityId, GCS::BSpline> splines;
    std::unordered_map<EntityId, GCS::Ellipse> ellipses;
    std::unordered_map<EntityId, GCS::ArcOfEllipse> ellipse_arcs;
    struct EllipseVerts {
        GCS::Point major_p;
        GCS::Point major_m;
        GCS::Point minor_p;
        GCS::Point minor_m;
    };
    std::unordered_map<EntityId, EllipseVerts> ellipse_verts;
    // Axis-end points live outside Sketch params; declare them so Horizontal
    // / Distance on major/minor ends can move the ellipse instead of locking
    // two constant coordinates (and so diagnose counts their 8 extra DOF).
    std::vector<double*> extra_unknowns;
    std::vector<EntityId> constraint_by_tag;  // tag-1 -> constraint id

    explicit Xlate(Sketch& s) : sketch(s) {}
    ~Xlate() {
        for (double* p : owned) delete p;
    }

    double* param(size_t index) {
        auto it = by_index.find(index);
        if (it != by_index.end()) return it->second;
        double* p = new double(sketch.param(index));
        owned.push_back(p);
        by_index[index] = p;
        return p;
    }

    void build_geometry() {
        for (const auto& e : sketch.entities()) {
            switch (e.type) {
                case SketchEntityType::Point: {
                    GCS::Point pt;
                    pt.x = param(e.params[0]);
                    pt.y = param(e.params[1]);
                    points[e.id] = pt;
                    break;
                }
                case SketchEntityType::Line: {
                    GCS::Line ln;
                    ln.p1.x = param(e.params[0]);
                    ln.p1.y = param(e.params[1]);
                    ln.p2.x = param(e.params[2]);
                    ln.p2.y = param(e.params[3]);
                    lines[e.id] = ln;
                    break;
                }
                case SketchEntityType::Circle: {
                    GCS::Circle c;
                    c.center.x = param(e.params[0]);
                    c.center.y = param(e.params[1]);
                    c.rad = param(e.params[2]);
                    circles[e.id] = c;
                    break;
                }
                case SketchEntityType::Arc: {
                    GCS::Arc a;
                    a.center.x = param(e.params[0]);
                    a.center.y = param(e.params[1]);
                    a.rad = param(e.params[2]);
                    a.startAngle = param(e.params[3]);
                    a.endAngle = param(e.params[4]);
                    a.start.x = param(e.params[5]);
                    a.start.y = param(e.params[6]);
                    a.end.x = param(e.params[7]);
                    a.end.y = param(e.params[8]);
                    arcs[e.id] = a;
                    sys.addConstraintArcRules(arcs[e.id]);
                    break;
                }
                case SketchEntityType::Spline: {
                    // Same Interpolate curve the kernel uses: poles/knots from
                    // Sketch::spline_geom. Fit-point start/end stay addressable.
                    auto geom = sketch.spline_geom(e.id);
                    if (!geom.ok || geom.poles.size() < 2) break;
                    GCS::BSpline bsp;
                    bsp.degree = geom.degree;
                    bsp.periodic = false;
                    bsp.poles.reserve(geom.poles.size());
                    bsp.weights.reserve(geom.poles.size());
                    for (const auto& uv : geom.poles) {
                        GCS::Point pt;
                        double* x = new double(uv[0]);
                        double* y = new double(uv[1]);
                        owned.push_back(x);
                        owned.push_back(y);
                        pt.x = x;
                        pt.y = y;
                        bsp.poles.push_back(pt);
                        double* w = new double(1.0);
                        owned.push_back(w);
                        bsp.weights.push_back(w);
                    }
                    if (e.params.size() >= 5) {
                        bsp.start.x = param(e.params[1]);
                        bsp.start.y = param(e.params[2]);
                        const int nfit = static_cast<int>(*param(e.params[0]));
                        bsp.end.x = param(e.params[static_cast<size_t>(1 + 2 * (nfit - 1))]);
                        bsp.end.y = param(e.params[static_cast<size_t>(2 + 2 * (nfit - 1))]);
                    } else {
                        bsp.start = bsp.poles.front();
                        bsp.end = bsp.poles.back();
                    }
                    for (size_t k = 0; k < geom.knots.size(); ++k) {
                        double* kv = new double(geom.knots[k]);
                        owned.push_back(kv);
                        bsp.knots.push_back(kv);
                        bsp.mult.push_back(k < geom.multiplicities.size()
                                               ? geom.multiplicities[k]
                                               : 1);
                    }
                    bsp.setupFlattenedKnots();
                    splines[e.id] = bsp;
                    points[e.id] = bsp.start;
                    break;
                }
                case SketchEntityType::Ellipse: {
                    if (e.params.size() < 5) break;
                    GCS::Ellipse el;
                    el.center.x = param(e.params[0]);
                    el.center.y = param(e.params[1]);
                    el.focus1.x = param(e.params[2]);
                    el.focus1.y = param(e.params[3]);
                    el.radmin = param(e.params[4]);
                    ellipses[e.id] = el;
                    const double cx = *el.center.x;
                    const double cy = *el.center.y;
                    const double dx = *el.focus1.x - cx;
                    const double dy = *el.focus1.y - cy;
                    const double c = std::hypot(dx, dy);
                    const double b = std::abs(*el.radmin);
                    const double a = std::sqrt(c * c + b * b);
                    const double ca = (c < 1e-12) ? 1.0 : dx / c;
                    const double sa = (c < 1e-12) ? 0.0 : dy / c;
                    auto mkpt = [&](double x, double y) {
                        GCS::Point pt;
                        pt.x = new double(x);
                        pt.y = new double(y);
                        owned.push_back(pt.x);
                        owned.push_back(pt.y);
                        extra_unknowns.push_back(pt.x);
                        extra_unknowns.push_back(pt.y);
                        return pt;
                    };
                    EllipseVerts v;
                    v.major_p = mkpt(cx + a * ca, cy + a * sa);
                    v.major_m = mkpt(cx - a * ca, cy - a * sa);
                    v.minor_p = mkpt(cx - b * sa, cy + b * ca);
                    v.minor_m = mkpt(cx + b * sa, cy - b * ca);
                    sys.addConstraintInternalAlignmentEllipseMajorDiameter(
                        ellipses[e.id], v.major_p, v.major_m);
                    sys.addConstraintInternalAlignmentEllipseMinorDiameter(
                        ellipses[e.id], v.minor_p, v.minor_m);
                    ellipse_verts[e.id] = v;
                    break;
                }
                case SketchEntityType::EllipticalArc: {
                    if (e.params.size() < 11) break;
                    GCS::ArcOfEllipse a;
                    a.center.x = param(e.params[0]);
                    a.center.y = param(e.params[1]);
                    a.focus1.x = param(e.params[2]);
                    a.focus1.y = param(e.params[3]);
                    a.radmin = param(e.params[4]);
                    a.startAngle = param(e.params[5]);
                    a.endAngle = param(e.params[6]);
                    a.start.x = param(e.params[7]);
                    a.start.y = param(e.params[8]);
                    a.end.x = param(e.params[9]);
                    a.end.y = param(e.params[10]);
                    ellipse_arcs[e.id] = a;
                    ellipses[e.id] = a;
                    sys.addConstraintArcOfEllipseRules(ellipse_arcs[e.id]);
                    break;
                }
            }
        }
    }

    GCS::Point point_of(const PointRef& ref, bool& ok) {
        ok = true;
        auto pit = points.find(ref.entity);
        if (pit != points.end()) {
            auto sit = splines.find(ref.entity);
            if (sit != splines.end() && ref.role == PointRole::End)
                return sit->second.end;
            return pit->second;
        }
        auto lit = lines.find(ref.entity);
        if (lit != lines.end()) {
            if (ref.role == PointRole::Start) return lit->second.p1;
            if (ref.role == PointRole::End) return lit->second.p2;
        }
        auto cit = circles.find(ref.entity);
        if (cit != circles.end()) return cit->second.center;
        auto ait = arcs.find(ref.entity);
        if (ait != arcs.end()) {
            if (ref.role == PointRole::Start) return ait->second.start;
            if (ref.role == PointRole::End) return ait->second.end;
            if (ref.role == PointRole::Center) return ait->second.center;
        }
        auto sit = splines.find(ref.entity);
        if (sit != splines.end()) {
            if (ref.role == PointRole::End) return sit->second.end;
            return sit->second.start;
        }
        auto eait = ellipse_arcs.find(ref.entity);
        if (eait != ellipse_arcs.end()) {
            if (ref.role == PointRole::Start) return eait->second.start;
            if (ref.role == PointRole::End) return eait->second.end;
            if (ref.role == PointRole::Center || ref.role == PointRole::Self)
                return eait->second.center;
        }
        auto eit = ellipses.find(ref.entity);
        if (eit != ellipses.end()) {
            auto vit = ellipse_verts.find(ref.entity);
            if (ref.role == PointRole::Center || ref.role == PointRole::Self)
                return eit->second.center;
            if (vit != ellipse_verts.end()) {
                if (ref.role == PointRole::Start) return vit->second.major_p;
                if (ref.role == PointRole::End) return vit->second.major_m;
                if (ref.role == PointRole::MinorStart) return vit->second.minor_p;
                if (ref.role == PointRole::MinorEnd) return vit->second.minor_m;
            }
        }
        ok = false;
        return {};
    }

    bool add(const SketchConstraint& c, int tag, std::vector<double>& dim_values) {
        bool ok1 = true, ok2 = true;
        const bool drv = c.driving;
        switch (c.type) {
            case ConstraintType::Coincident: {
                if (c.refs.size() != 2) return false;
                auto point_on_curve = [&](const PointRef& curve, const PointRef& pt) -> bool {
                    if (curve.role != PointRole::Self) return false;
                    GCS::Point p = point_of(pt, ok1);
                    if (!ok1) return false;
                    auto eit = ellipses.find(curve.entity);
                    if (eit != ellipses.end()) {
                        sys.addConstraintPointOnEllipse(p, eit->second, tag, drv);
                        return true;
                    }
                    auto cit = circles.find(curve.entity);
                    if (cit != circles.end()) {
                        sys.addConstraintPointOnCircle(p, cit->second, tag, drv);
                        return true;
                    }
                    auto ait = arcs.find(curve.entity);
                    if (ait != arcs.end()) {
                        sys.addConstraintPointOnArc(p, ait->second, tag, drv);
                        return true;
                    }
                    return false;
                };
                if (point_on_curve(c.refs[0], c.refs[1])) return true;
                if (point_on_curve(c.refs[1], c.refs[0])) return true;
                GCS::Point a = point_of(c.refs[0], ok1), b = point_of(c.refs[1], ok2);
                if (!ok1 || !ok2) return false;
                sys.addConstraintP2PCoincident(a, b, tag, drv);
                return true;
            }
            case ConstraintType::Horizontal: {
                // Two centres (or other points): same Y, no construction line.
                if (c.refs.size() >= 2) {
                    GCS::Point a = point_of(c.refs[0], ok1);
                    GCS::Point b = point_of(c.refs[1], ok2);
                    if (!ok1 || !ok2) return false;
                    sys.addConstraintHorizontal(a, b, tag, drv);
                    return true;
                }
                auto it = lines.find(c.refs.at(0).entity);
                if (it == lines.end()) return false;
                sys.addConstraintHorizontal(it->second, tag, drv);
                return true;
            }
            case ConstraintType::Vertical: {
                // Two points: same X, the form Horizontal already has.
                if (c.refs.size() >= 2) {
                    GCS::Point a = point_of(c.refs[0], ok1);
                    GCS::Point b = point_of(c.refs[1], ok2);
                    if (!ok1 || !ok2) return false;
                    sys.addConstraintVertical(a, b, tag, drv);
                    return true;
                }
                auto it = lines.find(c.refs.at(0).entity);
                if (it == lines.end()) return false;
                sys.addConstraintVertical(it->second, tag, drv);
                return true;
            }
            case ConstraintType::Parallel: {
                auto a = lines.find(c.refs.at(0).entity), b = lines.find(c.refs.at(1).entity);
                if (a == lines.end() || b == lines.end()) return false;
                sys.addConstraintParallel(a->second, b->second, tag, drv);
                return true;
            }
            case ConstraintType::Perpendicular: {
                auto a = lines.find(c.refs.at(0).entity), b = lines.find(c.refs.at(1).entity);
                if (a == lines.end() || b == lines.end()) return false;
                sys.addConstraintPerpendicular(a->second, b->second, tag, drv);
                return true;
            }
            case ConstraintType::PointOnLine: {
                GCS::Point p = point_of(c.refs.at(0), ok1);
                auto l = lines.find(c.refs.at(1).entity);
                if (!ok1 || l == lines.end()) return false;
                sys.addConstraintPointOnLine(p, l->second, tag, drv);
                return true;
            }
            case ConstraintType::Tangent: {
                // line-circle
                auto l = lines.find(c.refs.at(0).entity);
                auto ci = circles.find(c.refs.at(1).entity);
                if (l != lines.end() && ci != circles.end()) {
                    GCS::Line oriented = tangent_line_oriented(l->second, ci->second.center);
                    sys.addConstraintTangent(oriented, ci->second, /*ccw=*/true, tag, drv);
                    return true;
                }
                // circle-circle
                auto c1 = circles.find(c.refs.at(0).entity), c2 = circles.find(c.refs.at(1).entity);
                if (c1 != circles.end() && c2 != circles.end()) {
                    sys.addConstraintTangent(c1->second, c2->second, tag, drv);
                    return true;
                }
                // arc-arc
                auto a1 = arcs.find(c.refs.at(0).entity), a2 = arcs.find(c.refs.at(1).entity);
                if (a1 != arcs.end() && a2 != arcs.end()) {
                    sys.addConstraintTangent(a1->second, a2->second, tag, drv);
                    return true;
                }
                // circle-arc
                if (c1 != circles.end() && a2 != arcs.end()) {
                    sys.addConstraintTangent(c1->second, a2->second, tag, drv);
                    return true;
                }
                auto c2b = circles.find(c.refs.at(1).entity);
                auto a1b = arcs.find(c.refs.at(0).entity);
                if (c2b != circles.end() && a1b != arcs.end()) {
                    sys.addConstraintTangent(c2b->second, a1b->second, tag, drv);
                    return true;
                }
                // line-arc (either order)
                auto ai = arcs.find(c.refs.at(1).entity);
                if (l != lines.end() && ai != arcs.end()) {
                    GCS::Line oriented = tangent_line_oriented(l->second, ai->second.center);
                    sys.addConstraintTangent(oriented, ai->second, /*ccw=*/true, tag, drv);
                    return true;
                }
                auto l2 = lines.find(c.refs.at(1).entity);
                auto a0 = arcs.find(c.refs.at(0).entity);
                if (l2 != lines.end() && a0 != arcs.end()) {
                    GCS::Line oriented = tangent_line_oriented(l2->second, a0->second.center);
                    sys.addConstraintTangent(oriented, a0->second, /*ccw=*/true, tag, drv);
                    return true;
                }
                // Spline end to a line: Load() on the interpolant (see
                // Sketch::sync_spline_line_tangents). Clamped end knots are
                // multiplicity degree+1, so PlaneGCS SlopeAtBSplineKnot asserts.
                const SketchEntity* ea = sketch.entity(c.refs.at(0).entity);
                const SketchEntity* eb = sketch.entity(c.refs.at(1).entity);
                if (ea && eb) {
                    const bool spline_line =
                        (ea->type == SketchEntityType::Spline && eb->type == SketchEntityType::Line) ||
                        (ea->type == SketchEntityType::Line && eb->type == SketchEntityType::Spline) ||
                        (ea->type == SketchEntityType::Spline && eb->type == SketchEntityType::Arc) ||
                        (ea->type == SketchEntityType::Arc && eb->type == SketchEntityType::Spline);
                    if (spline_line) return true;
                }
                return false;
            }
            case ConstraintType::Equal: {
                auto l1 = lines.find(c.refs.at(0).entity), l2 = lines.find(c.refs.at(1).entity);
                if (l1 != lines.end() && l2 != lines.end()) {
                    sys.addConstraintEqualLength(l1->second, l2->second, tag, drv);
                    return true;
                }
                auto circ1 = circles.find(c.refs.at(0).entity),
                     circ2 = circles.find(c.refs.at(1).entity);
                if (circ1 != circles.end() && circ2 != circles.end()) {
                    sys.addConstraintEqualRadius(circ1->second, circ2->second, tag, drv);
                    return true;
                }
                auto ar1 = arcs.find(c.refs.at(0).entity), ar2 = arcs.find(c.refs.at(1).entity);
                if (ar1 != arcs.end() && ar2 != arcs.end()) {
                    sys.addConstraintEqualRadius(ar1->second, ar2->second, tag, drv);
                    return true;
                }
                if (circ1 != circles.end() && ar2 != arcs.end()) {
                    sys.addConstraintEqualRadius(circ1->second, ar2->second, tag, drv);
                    return true;
                }
                return false;
            }
            case ConstraintType::Distance: {
                // Point-to-line when exactly one ref is a line used as itself
                // (centre → hex flat). Two points stay point-to-point.
                if (c.refs.size() >= 2) {
                    auto l0 = lines.find(c.refs[0].entity);
                    auto l1 = lines.find(c.refs[1].entity);
                    bool line0 = l0 != lines.end() && c.refs[0].role == PointRole::Self;
                    bool line1 = l1 != lines.end() && c.refs[1].role == PointRole::Self;
                    if (line0 != line1) {
                        GCS::Point p = point_of(line0 ? c.refs[1] : c.refs[0], ok1);
                        if (!ok1) return false;
                        dim_values.push_back(c.value);
                        GCS::Line& ln = line0 ? l0->second : l1->second;
                        sys.addConstraintP2LDistance(p, ln, &dim_values.back(),
                                                     point_left_of_line(p, ln), tag, drv);
                        return true;
                    }
                }
                GCS::Point a = point_of(c.refs.at(0), ok1), b = point_of(c.refs.at(1), ok2);
                if (!ok1 || !ok2) return false;
                dim_values.push_back(c.value);
                sys.addConstraintP2PDistance(a, b, &dim_values.back(), tag, drv);
                return true;
            }
            case ConstraintType::Radius: {
                dim_values.push_back(c.value);
                auto ci = circles.find(c.refs.at(0).entity);
                if (ci != circles.end()) {
                    sys.addConstraintCircleRadius(ci->second, &dim_values.back(), tag, drv);
                    return true;
                }
                auto ai = arcs.find(c.refs.at(0).entity);
                if (ai != arcs.end()) {
                    sys.addConstraintArcRadius(ai->second, &dim_values.back(), tag, drv);
                    return true;
                }
                return false;
            }
            case ConstraintType::Diameter: {
                dim_values.push_back(c.value);
                auto ci = circles.find(c.refs.at(0).entity);
                if (ci != circles.end()) {
                    sys.addConstraintCircleDiameter(ci->second, &dim_values.back(), tag, drv);
                    return true;
                }
                auto ai = arcs.find(c.refs.at(0).entity);
                if (ai != arcs.end()) {
                    sys.addConstraintArcDiameter(ai->second, &dim_values.back(), tag, drv);
                    return true;
                }
                auto eit = ellipses.find(c.refs.at(0).entity);
                if (eit != ellipses.end()) {
                    auto vit = ellipse_verts.find(c.refs.at(0).entity);
                    if (vit == ellipse_verts.end()) return false;
                    const bool minor = c.refs[0].role == PointRole::MinorStart
                            || c.refs[0].role == PointRole::MinorEnd;
                    GCS::Point a = minor ? vit->second.minor_p : vit->second.major_p;
                    GCS::Point b = minor ? vit->second.minor_m : vit->second.major_m;
                    sys.addConstraintP2PDistance(a, b, &dim_values.back(), tag, drv);
                    return true;
                }
                return false;
            }
            case ConstraintType::Angle: {
                auto a = lines.find(c.refs.at(0).entity), b = lines.find(c.refs.at(1).entity);
                if (a == lines.end() || b == lines.end()) return false;
                dim_values.push_back(c.value);
                sys.addConstraintL2LAngle(a->second, b->second, &dim_values.back(), tag, drv);
                return true;
            }
            case ConstraintType::Midpoint: {
                // Point is midpoint of line: on line + on perpendicular bisector.
                GCS::Point p = point_of(c.refs.at(0), ok1);
                auto l = lines.find(c.refs.at(1).entity);
                if (!ok1 || l == lines.end()) {
                    // Allow (line, point) order.
                    p = point_of(c.refs.at(1), ok1);
                    l = lines.find(c.refs.at(0).entity);
                    if (!ok1 || l == lines.end()) return false;
                }
                sys.addConstraintPointOnLine(p, l->second, tag, drv);
                sys.addConstraintPointOnPerpBisector(p, l->second, tag, drv);
                return true;
            }
            case ConstraintType::Symmetric: {
                // refs: point A, point B, mirror line
                if (c.refs.size() < 3) return false;
                GCS::Point a = point_of(c.refs[0], ok1);
                GCS::Point b = point_of(c.refs[1], ok2);
                auto l = lines.find(c.refs[2].entity);
                if (!ok1 || !ok2 || l == lines.end()) return false;
                sys.addConstraintP2PSymmetric(a, b, l->second, tag, drv);
                return true;
            }
            case ConstraintType::Fix: {
                if (c.refs.empty() || c.locked.empty()) return false;
                auto eit = points.find(c.refs[0].entity);
                if (eit != points.end() && c.locked.size() >= 2) {
                    dim_values.push_back(c.locked[0]);
                    sys.addConstraintCoordinateX(eit->second, &dim_values.back(), tag, drv);
                    dim_values.push_back(c.locked[1]);
                    sys.addConstraintCoordinateY(eit->second, &dim_values.back(), tag, drv);
                    return true;
                }
                auto lit = lines.find(c.refs[0].entity);
                if (lit != lines.end() && c.locked.size() >= 4) {
                    dim_values.push_back(c.locked[0]);
                    sys.addConstraintCoordinateX(lit->second.p1, &dim_values.back(), tag, drv);
                    dim_values.push_back(c.locked[1]);
                    sys.addConstraintCoordinateY(lit->second.p1, &dim_values.back(), tag, drv);
                    dim_values.push_back(c.locked[2]);
                    sys.addConstraintCoordinateX(lit->second.p2, &dim_values.back(), tag, drv);
                    dim_values.push_back(c.locked[3]);
                    sys.addConstraintCoordinateY(lit->second.p2, &dim_values.back(), tag, drv);
                    return true;
                }
                auto cit = circles.find(c.refs[0].entity);
                if (cit != circles.end() && c.locked.size() >= 2) {
                    dim_values.push_back(c.locked[0]);
                    sys.addConstraintCoordinateX(cit->second.center, &dim_values.back(), tag, drv);
                    dim_values.push_back(c.locked[1]);
                    sys.addConstraintCoordinateY(cit->second.center, &dim_values.back(), tag, drv);
                    // Two locked values are a centre pin. Three also lock radius.
                    if (c.locked.size() >= 3) {
                        dim_values.push_back(c.locked[2]);
                        sys.addConstraintCircleRadius(cit->second, &dim_values.back(), tag, drv);
                    }
                    return true;
                }
                auto sit = splines.find(c.refs[0].entity);
                if (sit != splines.end() && c.locked.size() >= 2 * sit->second.poles.size()) {
                    for (size_t i = 0; i < sit->second.poles.size(); ++i) {
                        dim_values.push_back(c.locked[2 * i]);
                        sys.addConstraintCoordinateX(sit->second.poles[i], &dim_values.back(), tag,
                                                    drv);
                        dim_values.push_back(c.locked[2 * i + 1]);
                        sys.addConstraintCoordinateY(sit->second.poles[i], &dim_values.back(), tag,
                                                    drv);
                    }
                    return true;
                }
                return false;
            }
            case ConstraintType::Concentric: {
                if (c.refs.size() < 2) return false;
                GCS::Point a = point_of({c.refs[0].entity, PointRole::Center}, ok1);
                GCS::Point b = point_of({c.refs[1].entity, PointRole::Center}, ok2);
                if (!ok1 || !ok2) return false;
                sys.addConstraintP2PCoincident(a, b, tag, drv);
                return true;
            }
            case ConstraintType::Collinear: {
                if (c.refs.size() >= 2) {
                    auto a = lines.find(c.refs[0].entity);
                    auto b = lines.find(c.refs[1].entity);
                    if (a != lines.end() && b != lines.end()) {
                        sys.addConstraintPointOnLine(b->second.p1, a->second, tag, drv);
                        sys.addConstraintPointOnLine(b->second.p2, a->second, tag, drv);
                        return true;
                    }
                }
                if (c.refs.size() >= 3) {
                    GCS::Point p0 = point_of(c.refs[0], ok1);
                    GCS::Point p1 = point_of(c.refs[1], ok2);
                    bool ok3 = true;
                    GCS::Point p2 = point_of(c.refs[2], ok3);
                    if (!ok1 || !ok2 || !ok3) return false;
                    sys.addConstraintPointOnLine(p2, p0, p1, tag, drv);
                    return true;
                }
                return false;
            }
        }
        return false;
    }
};

SolveResult PlaneGCSBackendImpl::solve(Sketch& sketch) {
    SolveResult result;
    sketch.reconcile_arc_angles();
    sketch.sync_spline_line_tangents();
    Xlate x(sketch);
    x.build_geometry();

    std::vector<double> dim_values;
    dim_values.reserve(sketch.constraints().size() * 4);

    int tag = 0;
    for (const auto& c : sketch.constraints()) {
        ++tag;
        x.constraint_by_tag.push_back(c.id);
        if (!x.add(c, tag, dim_values)) {
            log::warn("planegcs: could not translate constraint " + c.id.str() + " (" +
                      std::string(to_string(c.type)) + ")");
        }
    }

    GCS::VEC_pD unknowns;
    for (auto& [idx, p] : x.by_index) unknowns.push_back(p);
    for (double* p : x.extra_unknowns) unknowns.push_back(p);

    x.sys.declareUnknowns(unknowns);
    x.sys.initSolution();
    int status = x.sys.solve(true, GCS::DogLeg);
    if (status == GCS::Success || status == GCS::Converged) {
        x.sys.applySolution();
        for (auto& [idx, p] : x.by_index) sketch.param_mut(idx) = *p;
        sketch.sync_spline_line_tangents();
        result.status = (status == GCS::Success) ? SolveStatus::Success : SolveStatus::Converged;
    } else {
        result.status = SolveStatus::Failed;
    }

    result.dofs = x.sys.diagnose();
    GCS::VEC_I conflicting, redundant;
    x.sys.getConflicting(conflicting);
    x.sys.getRedundant(redundant);
    auto tag_to_id = [&](int t) -> EntityId {
        size_t i = static_cast<size_t>(std::abs(t)) - 1;
        return i < x.constraint_by_tag.size() ? x.constraint_by_tag[i] : EntityId{};
    };
    for (int t : conflicting) result.conflicting.push_back(tag_to_id(t));
    for (int t : redundant) result.redundant.push_back(tag_to_id(t));

    // Creo-style weak dims yield: if the solve failed, drop any conflicting
    // weak constraint and re-solve (Inventor Relax / conflict yield).
    if (result.status == SolveStatus::Failed) {
        bool dropped = false;
        for (const auto& id : result.conflicting) {
            for (const auto& c : sketch.constraints()) {
                if (c.id == id && c.weak) {
                    sketch.remove_constraint(id);
                    dropped = true;
                    break;
                }
            }
        }
        if (dropped) return solve(sketch);
    }
    return result;
}

}  // namespace

std::unique_ptr<SolverBackend> make_planegcs_backend() {
    return std::make_unique<PlaneGCSBackendImpl>();
}

}  // namespace sx
