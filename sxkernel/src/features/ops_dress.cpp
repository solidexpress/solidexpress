#include "ops.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Vec.hxx>

#include <cmath>

#include "sx/shape_utils.hpp"
#include "sx/variables.hpp"
#include "sx/measure.hpp"
#include "sx/log.hpp"

namespace sx::feature_ops {

bool apply_fillet_chamfer(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    double v = num_param(ctx.params,
                         ctx.feature.type == FeatureType::Fillet ? "radius" : "distance", 1.0,
                         ctx.env);

    TopoDS_Shape result;
    if (ctx.feature.type == FeatureType::Fillet) {
        BRepFilletAPI_MakeFillet mk(tb->shape);
        const double r2 = ctx.params.contains("radius2")
                              ? num_param(ctx.params, "radius2", v, ctx.env)
                              : v;
        int added = 0;
        for (const auto& je : ctx.params.at("edges")) {
            TopoDS_Shape es;
            std::string why;
            if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Edge, je, es, &why)) {
                // Soft-skip: edge UUID lost after upstream topology (hole then
                // another dress-up). Aborting the whole regen blocked Hole Wizard
                // / jaw_af edits — leave the body as-is and continue the timeline.
                sx::log::error(std::string("fillet soft-skip: ") + why);
                return true;
            }
            if (std::abs(r2 - v) > 1e-12)
                mk.Add(v, r2, TopoDS::Edge(es));
            else
                mk.Add(v, TopoDS::Edge(es));
            ++added;
        }
        if (added == 0) return true;
        mk.Build();
        if (!mk.IsDone()) return ctx.fail("fillet failed");
        result = mk.Shape();
    } else {
        BRepFilletAPI_MakeChamfer mk(tb->shape);
        int added = 0;
        for (const auto& je : ctx.params.at("edges")) {
            TopoDS_Shape es;
            std::string why;
            if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Edge, je, es, &why)) {
                sx::log::error(std::string("chamfer soft-skip: ") + why);
                return true;
            }
            mk.Add(v, TopoDS::Edge(es));
            ++added;
        }
        if (added == 0) return true;
        mk.Build();
        if (!mk.IsDone()) return ctx.fail("chamfer failed");
        result = mk.Shape();
    }
    if (!shape::is_valid(result)) return ctx.fail("result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_shell(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    TopTools_ListOfShape remove_faces;
    for (const auto& jf : ctx.params.at("faces")) {
        TopoDS_Shape fs;
        std::string why;
        if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Face, jf, fs, &why))
            return ctx.fail(why);
        remove_faces.Append(fs);
    }
    if (remove_faces.IsEmpty()) return ctx.fail("no faces to remove");
    double thickness = num_param(ctx.params, "thickness", 1.0, ctx.env);
    BRepOffsetAPI_MakeThickSolid mk;
    mk.MakeThickSolidByJoin(tb->shape, remove_faces, -thickness, 1e-3);
    if (!mk.IsDone()) return ctx.fail("shell failed");
    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("shell result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_offset(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    double offset = num_param(ctx.params, "offset", 0.0, ctx.env);
    BRepOffsetAPI_MakeOffsetShape mk;
    mk.PerformByJoin(tb->shape, offset, 1e-3);
    if (!mk.IsDone()) return ctx.fail("offset failed");
    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("offset result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_push_pull(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    if (!ctx.params.contains("face")) return ctx.fail("missing face");
    TopoDS_Shape face_shape;
    std::string why;
    if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Face, ctx.params.at("face"), face_shape,
                            &why)) {
        // UUID may not survive a move+regen; fall back to stored plane cue.
        if (!ctx.params.contains("face_point") || !ctx.params.contains("face_normal"))
            return ctx.fail(why);
        gp_Pnt want = pnt_from(ctx.params.at("face_point"));
        gp_Dir want_n = dir_from(ctx.params.at("face_normal"));
        double best = 1e300;
        TopoDS_Shape best_face;
        for (const auto& fid : tb->subshape_ids.at(EntityKind::Face)) {
            TopoDS_Shape fs = ctx.doc.resolve(fid);
            if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
            TopoDS_Face f = TopoDS::Face(fs);
            BRepAdaptor_Surface surf(f);
            if (surf.GetType() != GeomAbs_Plane) continue;
            gp_Dir n = surf.Plane().Axis().Direction();
            if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
            if (n.Dot(want_n) < 0.95) continue;
            gp_Pnt c = surf.Plane().Location();
            // Prefer the face whose plane is closest to the stored pick point.
            double dist = std::abs(gp_Vec(c, want).Dot(n));
            // Also prefer proximity of the UV midpoint when available.
            auto mid = measure::face_midpoint(ctx.doc, fid);
            if (mid) {
                gp_Pnt m((*mid)[0], (*mid)[1], (*mid)[2]);
                dist += want.Distance(m) * 0.01;
            }
            if (dist < best) {
                best = dist;
                best_face = fs;
            }
        }
        if (best_face.IsNull()) return ctx.fail(why);
        face_shape = best_face;
    }
    TopoDS_Face face = TopoDS::Face(face_shape);
    BRepAdaptor_Surface surf(face);
    if (surf.GetType() != GeomAbs_Plane)
        return ctx.fail("only planar faces supported");
    gp_Dir normal = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) normal.Reverse();
    double distance = num_param(ctx.params, "distance", 0.0, ctx.env);
    const double dist = std::abs(distance);
    TopoDS_Shape tool;
    TopoDS_Shape result;
    if (distance >= 0) {
        gp_Vec sweep(normal.XYZ() * dist);
        tool = BRepPrimAPI_MakePrism(face, sweep).Shape();
        result = BRepAlgoAPI_Fuse(tb->shape, tool).Shape();
    } else {
        gp_Vec inward(normal.Reversed().XYZ() * dist);
        tool = BRepPrimAPI_MakePrism(face, inward).Shape();
        result = BRepAlgoAPI_Cut(tb->shape, tool).Shape();
    }
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("push/pull boolean failed");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_draft(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    if (!ctx.params.contains("faces") || !ctx.params["faces"].is_array() ||
        ctx.params["faces"].empty())
        return ctx.fail("no faces to draft");
    double angle_deg = num_param(ctx.params, "angle_deg", 0.0, ctx.env);
    double angle = angle_deg * M_PI / 180.0;
    gp_Dir pull = dir_from(ctx.params.at("pull_dir"));
    gp_Pln neutral(pnt_from(ctx.params.at("neutral_point")),
                   dir_from(ctx.params.at("neutral_normal")));
    BRepOffsetAPI_DraftAngle mk(tb->shape);
    for (const auto& jf : ctx.params.at("faces")) {
        TopoDS_Shape fs;
        std::string why;
        if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Face, jf, fs, &why))
            return ctx.fail(why);
        mk.Add(TopoDS::Face(fs), pull, angle, neutral);
        if (!mk.AddDone()) return ctx.fail("draft add failed");
    }
    mk.Build();
    if (!mk.IsDone()) return ctx.fail("draft failed");
    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("draft result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

}  // namespace sx::feature_ops
