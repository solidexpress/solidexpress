// PlaneGCS-backed SolverBackend. Translates a sx::Sketch into GCS::System
// geometry (raw double* into a scratch parameter buffer), solves, and writes
// results back. PlaneGCS is LGPL and dynamically linked (see THIRD_PARTY.md).

#include <GCS.h>

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
                    // Keep start/end consistent with center/radius/angles.
                    sys.addConstraintArcRules(arcs[e.id]);
                    break;
                }
            }
        }
    }

    GCS::Point point_of(const PointRef& ref, bool& ok) {
        ok = true;
        auto pit = points.find(ref.entity);
        if (pit != points.end()) return pit->second;
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
        ok = false;
        return {};
    }

    // Returns false if the constraint couldn't be translated.
    bool add(const SketchConstraint& c, int tag, std::vector<double>& dim_values) {
        bool ok1 = true, ok2 = true;
        switch (c.type) {
            case ConstraintType::Coincident: {
                if (c.refs.size() != 2) return false;
                GCS::Point a = point_of(c.refs[0], ok1), b = point_of(c.refs[1], ok2);
                if (!ok1 || !ok2) return false;
                sys.addConstraintP2PCoincident(a, b, tag);
                return true;
            }
            case ConstraintType::Horizontal: {
                auto it = lines.find(c.refs.at(0).entity);
                if (it == lines.end()) return false;
                sys.addConstraintHorizontal(it->second, tag);
                return true;
            }
            case ConstraintType::Vertical: {
                auto it = lines.find(c.refs.at(0).entity);
                if (it == lines.end()) return false;
                sys.addConstraintVertical(it->second, tag);
                return true;
            }
            case ConstraintType::Parallel: {
                auto a = lines.find(c.refs.at(0).entity), b = lines.find(c.refs.at(1).entity);
                if (a == lines.end() || b == lines.end()) return false;
                sys.addConstraintParallel(a->second, b->second, tag);
                return true;
            }
            case ConstraintType::Perpendicular: {
                auto a = lines.find(c.refs.at(0).entity), b = lines.find(c.refs.at(1).entity);
                if (a == lines.end() || b == lines.end()) return false;
                sys.addConstraintPerpendicular(a->second, b->second, tag);
                return true;
            }
            case ConstraintType::PointOnLine: {
                GCS::Point p = point_of(c.refs.at(0), ok1);
                auto l = lines.find(c.refs.at(1).entity);
                if (!ok1 || l == lines.end()) return false;
                sys.addConstraintPointOnLine(p, l->second, tag);
                return true;
            }
            case ConstraintType::Tangent: {
                auto l = lines.find(c.refs.at(0).entity);
                auto ci = circles.find(c.refs.at(1).entity);
                if (l == lines.end() || ci == circles.end()) return false;
                sys.addConstraintTangent(l->second, ci->second, tag);
                return true;
            }
            case ConstraintType::Equal: {
                auto l1 = lines.find(c.refs.at(0).entity), l2 = lines.find(c.refs.at(1).entity);
                if (l1 != lines.end() && l2 != lines.end()) {
                    sys.addConstraintEqualLength(l1->second, l2->second, tag);
                    return true;
                }
                auto c1 = circles.find(c.refs.at(0).entity), c2 = circles.find(c.refs.at(1).entity);
                if (c1 != circles.end() && c2 != circles.end()) {
                    sys.addConstraintEqualRadius(c1->second, c2->second, tag);
                    return true;
                }
                return false;
            }
            case ConstraintType::Distance: {
                GCS::Point a = point_of(c.refs.at(0), ok1), b = point_of(c.refs.at(1), ok2);
                if (!ok1 || !ok2) return false;
                dim_values.push_back(c.value);
                sys.addConstraintP2PDistance(a, b, &dim_values.back(), tag);
                return true;
            }
            case ConstraintType::Radius: {
                dim_values.push_back(c.value);
                auto ci = circles.find(c.refs.at(0).entity);
                if (ci != circles.end()) {
                    sys.addConstraintCircleRadius(ci->second, &dim_values.back(), tag);
                    return true;
                }
                auto ai = arcs.find(c.refs.at(0).entity);
                if (ai != arcs.end()) {
                    sys.addConstraintArcRadius(ai->second, &dim_values.back(), tag);
                    return true;
                }
                return false;
            }
            case ConstraintType::Angle: {
                auto a = lines.find(c.refs.at(0).entity), b = lines.find(c.refs.at(1).entity);
                if (a == lines.end() || b == lines.end()) return false;
                dim_values.push_back(c.value);
                sys.addConstraintL2LAngle(a->second, b->second, &dim_values.back(), tag);
                return true;
            }
            case ConstraintType::Concentric: {
                if (c.refs.size() < 2) return false;
                GCS::Point a = point_of({c.refs[0].entity, PointRole::Center}, ok1);
                GCS::Point b = point_of({c.refs[1].entity, PointRole::Center}, ok2);
                if (!ok1 || !ok2) return false;
                sys.addConstraintP2PCoincident(a, b, tag);
                return true;
            }
            case ConstraintType::Symmetric: {
                if (c.refs.size() < 3) return false;
                GCS::Point p1 = point_of(c.refs[0], ok1);
                GCS::Point p2 = point_of(c.refs[1], ok2);
                auto l = lines.find(c.refs[2].entity);
                if (!ok1 || !ok2 || l == lines.end()) return false;
                sys.addConstraintMidpointOnLine(p1, p2, l->second.p1, l->second.p2, tag);
                sys.addConstraintPerpendicular(p1, p2, l->second, tag);
                return true;
            }
            case ConstraintType::Midpoint: {
                if (c.refs.size() < 2) return false;
                GCS::Point p = point_of(c.refs[0], ok1);
                auto l = lines.find(c.refs[1].entity);
                if (!ok1 || l == lines.end()) return false;
                sys.addConstraintPointOnLine(p, l->second, tag);
                sys.addConstraintPointOnPerpBisector(p, l->second, tag);
                return true;
            }
            case ConstraintType::Fix: {
                GCS::Point p = point_of(c.refs.at(0), ok1);
                if (!ok1) return false;
                auto pos = sketch.point_pos(c.refs[0]);
                if (!pos) return false;
                dim_values.push_back((*pos)[0]);
                sys.addConstraintCoordinateX(p, &dim_values.back(), tag);
                dim_values.push_back((*pos)[1]);
                sys.addConstraintCoordinateY(p, &dim_values.back(), tag);
                return true;
            }
            case ConstraintType::Collinear: {
                if (c.refs.size() >= 2) {
                    auto a = lines.find(c.refs[0].entity);
                    auto b = lines.find(c.refs[1].entity);
                    if (a != lines.end() && b != lines.end()) {
                        sys.addConstraintPointOnLine(b->second.p1, a->second, tag);
                        sys.addConstraintPointOnLine(b->second.p2, a->second, tag);
                        return true;
                    }
                }
                if (c.refs.size() >= 3) {
                    GCS::Point p0 = point_of(c.refs[0], ok1);
                    GCS::Point p1 = point_of(c.refs[1], ok2);
                    bool ok3 = true;
                    GCS::Point p2 = point_of(c.refs[2], ok3);
                    if (!ok1 || !ok2 || !ok3) return false;
                    sys.addConstraintPointOnLine(p2, p0, p1, tag);
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

    // Dimensional values live here so their addresses are stable during solve.
    // Reserve to avoid reallocation (addresses are handed to GCS).
    std::vector<double> dim_values;
    dim_values.reserve(sketch.constraints().size());

    int tag = 0;
    for (const auto& c : sketch.constraints()) {
        ++tag;
        x.constraint_by_tag.push_back(c.id);
        if (!x.add(c, tag, dim_values)) {
            log::warn("planegcs: could not translate constraint " + c.id.str() + " (" +
                      std::string(to_string(c.type)) + ")");
        }
    }

    // Unknowns: every scratch parameter.
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

    // Diagnostics: DOFs, conflicting/redundant constraint tags -> EntityIds.
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
