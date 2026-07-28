#include "ops.hpp"

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>

namespace sx::feature_ops {

bool apply_boolean(ApplyCtx& ctx) {
    if (ctx.target_inactive("target") || ctx.target_inactive("tool")) return true;
    EntityId target = ctx.find_feature_body("target");
    EntityId tool = ctx.find_feature_body("tool");
    const Body* tb = ctx.doc.body(target);
    const Body* ob = ctx.doc.body(tool);
    if (!tb || !ob) return ctx.fail("missing boolean operand body");
    std::string op = ctx.params.value("op", "fuse");
    TopoDS_Shape result;
    if (op == "fuse") result = BRepAlgoAPI_Fuse(tb->shape, ob->shape).Shape();
    else if (op == "cut") result = BRepAlgoAPI_Cut(tb->shape, ob->shape).Shape();
    else result = BRepAlgoAPI_Common(tb->shape, ob->shape).Shape();
    if (result.IsNull()) return ctx.fail("boolean failed");
    ctx.doc.replace_body_shape(target, result);
    ctx.doc.remove_body(tool);
    return true;
}

}  // namespace sx::feature_ops
