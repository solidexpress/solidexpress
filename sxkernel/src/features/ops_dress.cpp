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

namespace sx::feature_ops {

bool apply_fillet_chamfer(ApplyCtx& ctx) {
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    double v = num_param(ctx.params,
                         ctx.feature.type == FeatureType::Fillet ? "radius" : "distance", 1.0,
                         ctx.env);

    TopoDS_Shape result;
    if (ctx.feature.type == FeatureType::Fillet) {
        BRepFilletAPI_MakeFillet mk(tb->shape);
        for (const auto& je : ctx.params.at("edges")) {
            TopoDS_Shape es;
            std::string why;
            if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Edge, je, es, &why))
                return ctx.fail(why);
            mk.Add(v, TopoDS::Edge(es));
        }
        mk.Build();
        if (!mk.IsDone()) return ctx.fail("fillet failed");
        result = mk.Shape();
    } else {
        BRepFilletAPI_MakeChamfer mk(tb->shape);
        for (const auto& je : ctx.params.at("edges")) {
            TopoDS_Shape es;
            std::string why;
            if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Edge, je, es, &why))
                return ctx.fail(why);
            mk.Add(v, TopoDS::Edge(es));
        }
        mk.Build();
        if (!mk.IsDone()) return ctx.fail("chamfer failed");
        result = mk.Shape();
    }
    if (!shape::is_valid(result)) return ctx.fail("result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_shell(ApplyCtx& ctx) {
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
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    if (!ctx.params.contains("face")) return ctx.fail("missing face");
    TopoDS_Shape face_shape;
    std::string why;
    if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Face, ctx.params.at("face"), face_shape,
                            &why))
        return ctx.fail(why);
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
