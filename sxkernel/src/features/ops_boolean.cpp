#include "ops.hpp"

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <TopTools_ListOfShape.hxx>

#include <cmath>
#include <sstream>
#include <vector>

#include "sx/interop.hpp"
#include "sx/shape_utils.hpp"

namespace sx::feature_ops {
namespace {

constexpr double kLargeFuzz[] = {1.0e-4, 1.0e-3, 0.05, 0.1};

double bbox_diag_of(const TopoDS_Shape& s) {
    if (s.IsNull()) return 0.0;
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    if (box.IsVoid()) return 0.0;
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    return std::hypot(x1 - x0, std::hypot(y1 - y0, z1 - z0));
}

bool usable(const TopoDS_Shape& s) {
    return !s.IsNull() && shape::count(s).solids >= 1 && std::abs(shape::volume(s)) > 1.0e-9;
}

TopoDS_Shape run_op(bool cutting, const TopoDS_Shape& a, const TopoDS_Shape& b, double fuzzy) {
    if (cutting) {
        BRepAlgoAPI_Cut op;
        TopTools_ListOfShape args, tools;
        args.Append(a);
        tools.Append(b);
        op.SetArguments(args);
        op.SetTools(tools);
        if (fuzzy > 0.0) op.SetFuzzyValue(fuzzy);
        op.Build();
        if (op.IsDone() && usable(op.Shape())) return op.Shape();
        return {};
    }
    BRepAlgoAPI_Fuse op;
    TopTools_ListOfShape args, tools;
    args.Append(a);
    tools.Append(b);
    op.SetArguments(args);
    op.SetTools(tools);
    if (fuzzy > 0.0) op.SetFuzzyValue(fuzzy);
    op.Build();
    if (!op.IsDone() || !usable(op.Shape())) return {};
    // Two input solids should become one. A compound of both is not a fuse.
    if (shape::count(a).solids >= 1 && shape::count(b).solids >= 1 &&
        shape::count(op.Shape()).solids > 1)
        return {};
    return op.Shape();
}

HonestBoolean finish(HonestBoolean out, const TopoDS_Shape& raw) {
    out.shape = raw;
    if (raw.IsNull()) return out;
    if (!shape::is_valid(raw)) {
        std::string report;
        TopoDS_Shape healed = interop::heal_shape(raw, &report);
        if (usable(healed)) {
            out.shape = healed;
            out.healed = true;
            if (out.warning.empty()) out.warning = "boolean heal";
        }
    }
    return out;
}

HonestBoolean run_ladder(bool cutting, const TopoDS_Shape& a, const TopoDS_Shape& b) {
    HonestBoolean out;
    const double silent = HonestBoolean::silent_limit(a, b);
    const double first[] = {0.0, silent};
    for (double fuzzy : first) {
        TopoDS_Shape s = run_op(cutting, a, b, fuzzy);
        if (!usable(s)) continue;
        out.fuzz_used = fuzzy;
        return finish(out, s);
    }
    for (double fuzzy : kLargeFuzz) {
        if (fuzzy <= silent) continue;
        TopoDS_Shape s = run_op(cutting, a, b, fuzzy);
        if (!usable(s)) continue;
        out.fuzz_used = fuzzy;
        std::ostringstream os;
        os << kBooleanFuzzWarning << fuzzy;
        out.warning = os.str();
        return finish(out, s);
    }
    return out;
}

}  // namespace

double HonestBoolean::bbox_diag(const TopoDS_Shape& s) { return bbox_diag_of(s); }

double HonestBoolean::silent_limit(const TopoDS_Shape& a, const TopoDS_Shape& b) {
    return 1.0e-6 * std::max(bbox_diag_of(a), bbox_diag_of(b));
}

HonestBoolean HonestBoolean::fuse(const TopoDS_Shape& a, const TopoDS_Shape& b) {
    return run_ladder(false, a, b);
}

HonestBoolean HonestBoolean::cut(const TopoDS_Shape& a, const TopoDS_Shape& b) {
    return run_ladder(true, a, b);
}

bool apply_boolean(ApplyCtx& ctx) {
    if (ctx.target_inactive("target") || ctx.target_inactive("tool")) return true;
    EntityId target = ctx.find_feature_body("target");
    EntityId tool = ctx.find_feature_body("tool");
    const Body* tb = ctx.doc.body(target);
    const Body* ob = ctx.doc.body(tool);
    if (!tb || !ob) return ctx.fail("missing boolean operand body");
    std::string op = ctx.params.value("op", "fuse");
    HonestBoolean hb;
    if (op == "cut")
        hb = HonestBoolean::cut(tb->shape, ob->shape);
    else if (op == "common") {
        TopoDS_Shape result = BRepAlgoAPI_Common(tb->shape, ob->shape).Shape();
        if (result.IsNull()) return ctx.fail("boolean failed");
        ctx.doc.replace_body_shape(target, result);
        ctx.doc.remove_body(tool);
        return true;
    } else
        hb = HonestBoolean::fuse(tb->shape, ob->shape);
    if (!usable(hb.shape)) return ctx.fail("boolean failed");
    if (!hb.warning.empty()) ctx.graph.add_warning(ctx.feature.id, hb.warning);
    ctx.doc.replace_body_shape(target, hb.shape);
    ctx.doc.remove_body(tool);
    return true;
}

}  // namespace sx::feature_ops
