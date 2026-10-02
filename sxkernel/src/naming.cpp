#include "sx/naming.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include "sx/occt_types.hpp"
#include <TopoDS.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Pln.hxx>

#include <algorithm>
#include <cmath>
#include <limits>

namespace sx::naming {

namespace {

Signature face_signature(const TopoDS_Face& face) {
    Signature s;
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    gp_Pnt c = props.CentreOfMass();
    s.center = {c.X(), c.Y(), c.Z()};
    s.size = props.Mass();

    BRepAdaptor_Surface surf(face);
    s.geom_type = static_cast<int>(surf.GetType());
    if (surf.GetType() == GeomAbs_Plane) {
        gp_Dir n = surf.Plane().Axis().Direction();
        s.dir = {n.X(), n.Y(), n.Z()};
    } else if (surf.GetType() == GeomAbs_Cylinder) {
        gp_Dir a = surf.Cylinder().Axis().Direction();
        s.dir = {a.X(), a.Y(), a.Z()};
    }
    return s;
}

Signature edge_signature(const TopoDS_Edge& edge) {
    Signature s;
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    gp_Pnt c = props.CentreOfMass();
    s.center = {c.X(), c.Y(), c.Z()};
    s.size = props.Mass();

    BRepAdaptor_Curve curve(edge);
    s.geom_type = static_cast<int>(curve.GetType());
    if (curve.GetType() == GeomAbs_Line) {
        gp_Dir d = curve.Line().Direction();
        s.dir = {d.X(), d.Y(), d.Z()};
    } else if (curve.GetType() == GeomAbs_Circle) {
        gp_Dir a = curve.Circle().Axis().Direction();
        s.dir = {a.X(), a.Y(), a.Z()};
    }
    return s;
}

Signature vertex_signature(const TopoDS_Vertex& v) {
    Signature s;
    gp_Pnt p = BRep_Tool::Pnt(v);
    s.center = {p.X(), p.Y(), p.Z()};
    return s;
}

TopAbs_ShapeEnum occt_kind(EntityKind kind) {
    switch (kind) {
        case EntityKind::Face: return TopAbs_FACE;
        case EntityKind::Edge: return TopAbs_EDGE;
        default: return TopAbs_VERTEX;
    }
}

double dist(const std::array<double, 3>& a, const std::array<double, 3>& b) {
    return std::sqrt((a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]) +
                     (a[2] - b[2]) * (a[2] - b[2]));
}

// Cost of pairing two same-kind subshapes; infinity when they cannot match.
// Distances are normalized by the subshape's own scale so the threshold works
// for both millimeter-sized details and large bodies.
double match_cost(const Signature& a, const Signature& b) {
    constexpr double kInf = std::numeric_limits<double>::infinity();
    if (a.geom_type != b.geom_type) return kInf;

    double scale = std::max({1.0, std::sqrt(std::max(a.size, 0.0)), std::sqrt(std::max(b.size, 0.0))});
    double center_term = dist(a.center, b.center) / scale;

    double size_term = 0.0;
    double max_size = std::max(a.size, b.size);
    if (max_size > 1e-12) size_term = std::abs(a.size - b.size) / max_size;

    // Directions compare as unsigned axes (OCCT face orientation can flip
    // the plane normal across a rebuild).
    double dir_term = 0.0;
    double la = dist(a.dir, {0, 0, 0}), lb = dist(b.dir, {0, 0, 0});
    if (la > 0.5 && lb > 0.5) {
        double dot = std::abs(a.dir[0] * b.dir[0] + a.dir[1] * b.dir[1] + a.dir[2] * b.dir[2]);
        dir_term = 1.0 - std::min(dot, 1.0);
    }

    return center_term + size_term + 4.0 * dir_term;
}

// Pairs above this cost are considered different subshapes. An exact survivor
// costs ~0; a face whose area doubled while its centroid moved by its own
// width costs roughly 1.5.
constexpr double kMaxCost = 2.0;

}  // namespace

std::vector<Signature> signatures(const TopoDS_Shape& shape, EntityKind kind) {
    sx::occt::ShapeIndexedMap map;
    TopExp::MapShapes(shape, occt_kind(kind), map);
    std::vector<Signature> out;
    out.reserve(static_cast<size_t>(map.Extent()));
    for (int i = 1; i <= map.Extent(); ++i) {
        switch (kind) {
            case EntityKind::Face: out.push_back(face_signature(TopoDS::Face(map(i)))); break;
            case EntityKind::Edge: out.push_back(edge_signature(TopoDS::Edge(map(i)))); break;
            default: out.push_back(vertex_signature(TopoDS::Vertex(map(i)))); break;
        }
    }
    return out;
}

MatchResult match_subshapes(const TopoDS_Shape& old_shape,
                            const std::map<EntityKind, std::vector<EntityId>>& old_ids,
                            const TopoDS_Shape& new_shape) {
    MatchResult result;
    for (EntityKind kind : {EntityKind::Face, EntityKind::Edge, EntityKind::Vertex}) {
        auto new_sigs = signatures(new_shape, kind);
        auto& ids = result.ids[kind];
        ids.assign(new_sigs.size(), EntityId{});

        auto it = old_ids.find(kind);
        std::vector<Signature> old_sigs;
        size_t n_old = 0;
        if (it != old_ids.end()) {
            old_sigs = signatures(old_shape, kind);
            n_old = std::min(old_sigs.size(), it->second.size());
        }

        // All candidate pairs under the threshold, cheapest first; greedy
        // one-to-one assignment (optimal enough at CAD subshape counts).
        struct Pair {
            double cost;
            size_t old_idx, new_idx;
        };
        std::vector<Pair> pairs;
        for (size_t o = 0; o < n_old; ++o)
            for (size_t n = 0; n < new_sigs.size(); ++n) {
                double c = match_cost(old_sigs[o], new_sigs[n]);
                if (c < kMaxCost) pairs.push_back({c, o, n});
            }
        std::sort(pairs.begin(), pairs.end(),
                  [](const Pair& a, const Pair& b) { return a.cost < b.cost; });

        std::vector<bool> old_used(n_old, false), new_used(new_sigs.size(), false);
        for (const auto& p : pairs) {
            if (old_used[p.old_idx] || new_used[p.new_idx]) continue;
            old_used[p.old_idx] = true;
            new_used[p.new_idx] = true;
            ids[p.new_idx] = it->second[p.old_idx];
        }

        for (size_t n = 0; n < ids.size(); ++n)
            if (ids[n].is_null()) ids[n] = EntityId::generate();
        for (size_t o = 0; o < n_old; ++o)
            if (!old_used[o]) result.released.push_back(it->second[o]);
    }
    return result;
}

}  // namespace sx::naming
