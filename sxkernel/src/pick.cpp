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

std::optional<PickHit> pick_ray(const Document& doc,
                                const std::array<double, 3>& origin,
                                const std::array<double, 3>& direction) {
    gp_Lin ray(gp_Pnt(origin[0], origin[1], origin[2]),
               gp_Dir(direction[0], direction[1], direction[2]));

    std::optional<PickHit> best;
    double best_w = std::numeric_limits<double>::max();

    for (const auto& body_id : doc.body_ids()) {
        const Body* b = doc.body(body_id);
        if (!b || b->shape.IsNull()) continue;

        IntCurvesFace_ShapeIntersector inter;
        inter.Load(b->shape, 1e-6);
        // Only hits in front of the ray origin (parameter W >= 0).
        inter.Perform(ray, 0.0, std::numeric_limits<double>::max());
        if (!inter.IsDone()) continue;

        for (int i = 1; i <= inter.NbPnt(); ++i) {
            double w = inter.WParameter(i);
            if (w >= best_w) continue;

            // Map the hit face back to its stable id.
            sx::occt::ShapeIndexedMap face_map;
            TopExp::MapShapes(b->shape, TopAbs_FACE, face_map);
            int face_index = face_map.FindIndex(inter.Face(i));
            if (face_index < 1) continue;

            const auto& face_ids = b->subshape_ids.at(EntityKind::Face);
            PickHit hit;
            hit.body = body_id;
            hit.face = face_ids[static_cast<size_t>(face_index - 1)];
            gp_Pnt p = inter.Pnt(i);
            hit.point = {p.X(), p.Y(), p.Z()};
            hit.distance = w;
            best = hit;
            best_w = w;
        }
    }
    return best;
}

}  // namespace sx
