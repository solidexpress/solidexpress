#include "sx/pick.hpp"

#include <IntCurvesFace_ShapeIntersector.hxx>
#include <TopExp.hxx>
#include "sx/occt_types.hpp"
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>

#include <limits>

#include "sx/document.hpp"

namespace sx {
namespace {

std::optional<PickHit> hit_body(const Body& b, const EntityId& body_id, const gp_Lin& ray) {
    if (b.shape.IsNull()) return std::nullopt;

    IntCurvesFace_ShapeIntersector inter;
    inter.Load(b.shape, 1e-6);
    // Only hits in front of the ray origin (parameter W >= 0).
    inter.Perform(ray, 0.0, std::numeric_limits<double>::max());
    if (!inter.IsDone()) return std::nullopt;

    std::optional<PickHit> best;
    double best_w = std::numeric_limits<double>::max();
    auto faces = b.subshape_ids.find(EntityKind::Face);
    if (faces == b.subshape_ids.end()) return std::nullopt;
    const auto& face_ids = faces->second;
    sx::occt::ShapeIndexedMap face_map;
    TopExp::MapShapes(b.shape, TopAbs_FACE, face_map);

    for (int i = 1; i <= inter.NbPnt(); ++i) {
        double w = inter.WParameter(i);
        if (w >= best_w) continue;

        int face_index = face_map.FindIndex(inter.Face(i));
        if (face_index < 1) continue;
        if (static_cast<size_t>(face_index) > face_ids.size()) continue;

        PickHit hit;
        hit.body = body_id;
        hit.face = face_ids[static_cast<size_t>(face_index - 1)];
        gp_Pnt p = inter.Pnt(i);
        hit.point = {p.X(), p.Y(), p.Z()};
        hit.distance = w;
        best = hit;
        best_w = w;
    }
    return best;
}

gp_Lin make_ray(const std::array<double, 3>& origin, const std::array<double, 3>& direction) {
    return gp_Lin(gp_Pnt(origin[0], origin[1], origin[2]),
                  gp_Dir(direction[0], direction[1], direction[2]));
}

}  // namespace

std::optional<PickHit> pick_ray_body(const Document& doc, const EntityId& body,
                                     const std::array<double, 3>& origin,
                                     const std::array<double, 3>& direction) {
    const Body* b = doc.body(body);
    if (!b) return std::nullopt;
    return hit_body(*b, body, make_ray(origin, direction));
}

std::optional<PickHit> pick_ray(const Document& doc,
                                const std::array<double, 3>& origin,
                                const std::array<double, 3>& direction) {
    gp_Lin ray = make_ray(origin, direction);

    std::optional<PickHit> best;
    double best_w = std::numeric_limits<double>::max();

    for (const auto& body_id : doc.body_ids()) {
        const Body* b = doc.body(body_id);
        if (!b) continue;
        auto hit = hit_body(*b, body_id, ray);
        if (!hit || hit->distance >= best_w) continue;
        best = hit;
        best_w = hit->distance;
    }
    return best;
}

}  // namespace sx
