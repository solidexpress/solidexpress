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
                    // Fit points as GCS BSpline poles (degree ≤ 3); start/end
                    // addressable for Coincident / Distance / Fix.
                    if (e.params.size() < 3) break;
                    int n = static_cast<int>(*param(e.params[0]));
                    if (n < 2) break;
                    GCS::BSpline bsp;
                    bsp.degree = std::min(3, n - 1);
                    bsp.periodic = false;
                    bsp.poles.reserve(static_cast<size_t>(n));
                    bsp.weights.reserve(static_cast<size_t>(n));
                    for (int i = 0; i < n; ++i) {
                        GCS::Point pt;
                        pt.x = param(e.params[static_cast<size_t>(1 + 2 * i)]);
                        pt.y = param(e.params[static_cast<size_t>(2 + 2 * i)]);
                        bsp.poles.push_back(pt);
                        double* w = new double(1.0);
                        owned.push_back(w);
                        bsp.weights.push_back(w);
                    }
                    bsp.start = bsp.poles.front();
                    bsp.end = bsp.poles.back();
                    // Open clamped uniform knots: flattened length = n + degree + 1.
                    int n_distinct = n - bsp.degree + 1;
                    if (n_distinct < 2) n_distinct = 2;
                    for (int k = 0; k < n_distinct; ++k) {
                        double* kv = new double(static_cast<double>(k) /
                                                std::max(1, n_distinct - 1));
                        owned.push_back(kv);
                        bsp.knots.push_back(kv);
                        int m = 1;
                        if (k == 0 || k == n_distinct - 1) m = bsp.degree + 1;
                        bsp.mult.push_back(m);
                    }
                    bsp.setupFlattenedKnots();
                    splines[e.id] = bsp;
                    points[e.id] = bsp.start;
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
        ok = false;
        return {};
    }

    bool add(const SketchConstraint& c, int tag, std::vector<double>& dim_values) {
        bool ok1 = true, ok2 = true;
        const bool drv = c.driving;
        switch (c.type) {
            case ConstraintType::Coincident: {
                if (c.refs.size() != 2) return false;
                GCS::Point a = point_of(c.refs[0], ok1), b = point_of(c.refs[1], ok2);
                if (!ok1 || !ok2) return false;
                sys.addConstraintP2PCoincident(a, b, tag, drv);
                return true;
            }
            case ConstraintType::Horizontal: {
                auto it = lines.find(c.refs.at(0).entity);
                if (it == lines.end()) return false;
                sys.addConstraintHorizontal(it->second, tag, drv);
                return true;
            }
            case ConstraintType::Vertical: {
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
                    sys.addConstraintTangent(l->second, ci->second, /*ccw=*/true, tag, drv);
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
                // line-arc
                auto ai = arcs.find(c.refs.at(1).entity);
                if (l != lines.end() && ai != arcs.end()) {
                    sys.addConstraintTangent(l->second, ai->second, /*ccw=*/true, tag, drv);
                    return true;
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
                if (cit != circles.end() && c.locked.size() >= 3) {
                    dim_values.push_back(c.locked[0]);
                    sys.addConstraintCoordinateX(cit->second.center, &dim_values.back(), tag, drv);
                    dim_values.push_back(c.locked[1]);
                    sys.addConstraintCoordinateY(cit->second.center, &dim_values.back(), tag, drv);
                    dim_values.push_back(c.locked[2]);
                    sys.addConstraintCircleRadius(cit->second, &dim_values.back(), tag, drv);
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

    x.sys.declareUnknowns(unknowns);
    x.sys.initSolution();
    int status = x.sys.solve(true, GCS::DogLeg);
    if (status == GCS::Success || status == GCS::Converged) {
        x.sys.applySolution();
        for (auto& [idx, p] : x.by_index) sketch.param_mut(idx) = *p;
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
    return result;
}

}  // namespace

std::unique_ptr<SolverBackend> make_planegcs_backend() {
    return std::make_unique<PlaneGCSBackendImpl>();
}

}  // namespace sx
