#include "ops.hpp"

#include <BRepBuilderAPI_Transform.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cmath>

#include "sx/shape_utils.hpp"
#include "sx/variables.hpp"

namespace sx::feature_ops {

bool apply_mirror(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    gp_Trsf t;
    t.SetMirror(gp_Ax2(pnt_from(ctx.params.at("plane_point")),
                       dir_from(ctx.params.at("plane_normal"))));
    TopoDS_Shape mirrored =
        BRepBuilderAPI_Transform(tb->shape, t, /*copy=*/true).Shape();
    if (mirrored.IsNull() || !shape::is_valid(mirrored))
        return ctx.fail("mirror failed");
    put_body(ctx.doc, ctx.feature.output_body, mirrored, "Mirror of " + tb->name);
    return true;
}

bool apply_linear_pattern(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    int count = ctx.params.value("count", 0);
    double spacing = num_param(ctx.params, "spacing", 0.0, ctx.env);
    ensure_pattern_slots(ctx.feature, count, ctx.doc);
    gp_Dir dir = dir_from(ctx.params.at("direction"));
    for (int i = 1; i < count; ++i) {
        gp_Trsf t;
        t.SetTranslation(gp_Vec(dir.XYZ() * (spacing * i)));
        TopoDS_Shape copy =
            BRepBuilderAPI_Transform(tb->shape, t, /*copy=*/true).Shape();
        if (copy.IsNull() || !shape::is_valid(copy))
            return ctx.fail("linear pattern failed");
        const std::string name = tb->name + " [" + std::to_string(i + 1) + "]";
        put_body(ctx.doc, ctx.feature.output_bodies[static_cast<size_t>(i - 1)], copy, name);
    }
    return true;
}

bool apply_circular_pattern(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    int count = ctx.params.value("count", 0);
    ensure_pattern_slots(ctx.feature, count, ctx.doc);
    gp_Ax1 axis(pnt_from(ctx.params.at("axis_point")),
               dir_from(ctx.params.at("axis_dir")));
    double total = num_param(ctx.params, "total_angle", 2.0 * M_PI, ctx.env);
    double step = total / static_cast<double>(count);
    for (int i = 1; i < count; ++i) {
        gp_Trsf t;
        t.SetRotation(axis, step * i);
        TopoDS_Shape copy =
            BRepBuilderAPI_Transform(tb->shape, t, /*copy=*/true).Shape();
        if (copy.IsNull() || !shape::is_valid(copy))
            return ctx.fail("circular pattern failed");
        const std::string name = tb->name + " [" + std::to_string(i + 1) + "]";
        put_body(ctx.doc, ctx.feature.output_bodies[static_cast<size_t>(i - 1)], copy, name);
    }
    return true;
}

}  // namespace sx::feature_ops
