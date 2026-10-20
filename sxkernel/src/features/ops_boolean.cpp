#include "ops.hpp"

#include <BOPAlgo_GlueEnum.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopTools_ListOfShape.hxx>

#include <cmath>
#include <sstream>
#include <vector>

#include "sx/interop.hpp"
#include "sx/shape_utils.hpp"

namespace sx::feature_ops {
namespace {

constexpr double kLargeFuzz[] = {1.0e-4, 1.0e-3, 0.05, 0.1};
constexpr BOPAlgo_GlueEnum kGlue[] = {BOPAlgo_GlueOff, BOPAlgo_GlueShift, BOPAlgo_GlueFull};

double bbox_diag_of(const TopoDS_Shape& s) {
    if (s.IsNull()) return 0.0;
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    if (box.IsVoid()) return 0.0;
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    return std::hypot(x1 - x0, std::hypot(y1 - y0, z1 - z0));
}

bool has_solid(const TopoDS_Shape& s) {
    return !s.IsNull() && shape::count(s).solids >= 1 && std::abs(shape::volume(s)) > 1.0e-9;
}

bool bbox_covers(const TopoDS_Shape& outer, const TopoDS_Shape& inner, double slop) {
    if (outer.IsNull() || inner.IsNull()) return false;
    Bnd_Box a, b;
    BRepBndLib::Add(outer, a);
    BRepBndLib::Add(inner, b);
    if (a.IsVoid() || b.IsVoid()) return false;
    double ax0, ay0, az0, ax1, ay1, az1;
    double bx0, by0, bz0, bx1, by1, bz1;
    a.Get(ax0, ay0, az0, ax1, ay1, az1);
    b.Get(bx0, by0, bz0, bx1, by1, bz1);
    return ax0 <= bx0 + slop && ay0 <= by0 + slop && az0 <= bz0 + slop &&
           ax1 + slop >= bx1 && ay1 + slop >= by1 && az1 + slop >= bz1;
}

TopoDS_Shape run_op(bool cutting, const TopoDS_Shape& a, const TopoDS_Shape& b, double fuzzy,
                    BOPAlgo_GlueEnum glue) {
    if (cutting) {
        BRepAlgoAPI_Cut op;
        TopTools_ListOfShape args, tools;
        args.Append(a);
        tools.Append(b);
        op.SetArguments(args);
        op.SetTools(tools);
        if (fuzzy > 0.0) op.SetFuzzyValue(fuzzy);
        if (glue != BOPAlgo_GlueOff) op.SetGlue(glue);
        op.Build();
        if (op.IsDone() && has_solid(op.Shape())) return op.Shape();
        return {};
    }
    BRepAlgoAPI_Fuse op;
    TopTools_ListOfShape args, tools;
    args.Append(a);
    tools.Append(b);
    op.SetArguments(args);
    op.SetTools(tools);
    if (fuzzy > 0.0) op.SetFuzzyValue(fuzzy);
    if (glue != BOPAlgo_GlueOff) op.SetGlue(glue);
    op.Build();
    if (!op.IsDone() || !has_solid(op.Shape())) return {};
    // Two input solids should become one. A compound of both is not a fuse.
    if (shape::count(a).solids >= 1 && shape::count(b).solids >= 1 &&
        shape::count(op.Shape()).solids > 1)
        return {};
    return op.Shape();
}

HonestBoolean finish(HonestBoolean out, const TopoDS_Shape& raw) {
    out.shape = {};
    if (raw.IsNull()) return out;
    TopoDS_Shape s = raw;
    if (!shape::is_valid(s)) {
        std::string report;
        TopoDS_Shape healed = interop::heal_shape(s, &report);
        if (!has_solid(healed) || !shape::is_valid(healed)) return out;
        s = healed;
        out.healed = true;
        if (out.warning.empty()) out.warning = "boolean heal";
    }
    if (!has_solid(s) || !shape::is_valid(s)) return out;
    out.shape = s;
    return out;
}

bool take(HonestBoolean& out, bool cutting, const TopoDS_Shape& a, const TopoDS_Shape& b,
          double fuzzy, BOPAlgo_GlueEnum glue, const char* extra_warn = nullptr) {
    TopoDS_Shape s = run_op(cutting, a, b, fuzzy, glue);
    if (!has_solid(s)) return false;
    HonestBoolean done = finish(out, s);
    if (!HonestBoolean::usable(done.shape)) return false;
    if (!cutting && !HonestBoolean::fuse_keeps(a, b, done.shape)) return false;
    out = done;
    out.fuzz_used = fuzzy;
    if (extra_warn && out.warning.empty()) out.warning = extra_warn;
    return true;
}

HonestBoolean run_ladder(bool cutting, const TopoDS_Shape& a, const TopoDS_Shape& b) {
    HonestBoolean out;
    const double silent = HonestBoolean::silent_limit(a, b);
    const double first[] = {0.0, silent};
    // GlueShift/Full is the named path for pads that only share a face
    // (spanner handle 6 mm onto heads 10 mm). Try it before large fuzz so
    // an open-shell default Fuse does not get committed.
    for (double fuzzy : first) {
        for (auto glue : kGlue) {
            if (take(out, cutting, a, b, fuzzy, glue)) return out;
        }
    }
    for (double fuzzy : kLargeFuzz) {
        if (fuzzy <= silent) continue;
        for (auto glue : kGlue) {
            std::ostringstream os;
            os << kBooleanFuzzWarning << fuzzy;
            if (take(out, cutting, a, b, fuzzy, glue, os.str().c_str())) return out;
        }
    }
    return out;
}

}  // namespace

double HonestBoolean::bbox_diag(const TopoDS_Shape& s) { return bbox_diag_of(s); }

double HonestBoolean::silent_limit(const TopoDS_Shape& a, const TopoDS_Shape& b) {
    return 1.0e-6 * std::max(bbox_diag_of(a), bbox_diag_of(b));
}

bool HonestBoolean::usable(const TopoDS_Shape& s) {
    return has_solid(s) && shape::is_valid(s);
}

bool HonestBoolean::fuse_keeps(const TopoDS_Shape& body, const TopoDS_Shape& tool,
                              const TopoDS_Shape& fused) {
    if (!usable(fused)) return false;
    const double bv = std::abs(shape::volume(body));
    const double tv = std::abs(shape::volume(tool));
    const double fv = std::abs(shape::volume(fused));
    if (bv <= 1.0) return true;
    if (fv < bv * kHonestKeepRatio) return false;
    // Adjacent pads share a face: the union must grow. Heads-only after a
    // "successful" Fuse is how the handle used to vanish.
    if (tv > 1.0e-3 && fv < bv + 1.0e-3) return false;
    // A fuse that grows volume by eating the C while adding the handle still
    // "grows". The union bbox must keep both operands.
    if (!bbox_covers(fused, body, 0.2) || !bbox_covers(fused, tool, 0.2)) return false;
    return true;
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
    if (!HonestBoolean::usable(hb.shape)) return ctx.fail("boolean failed");
    if (!hb.warning.empty()) ctx.graph.add_warning(ctx.feature.id, hb.warning);
    ctx.doc.replace_body_shape(target, hb.shape);
    ctx.doc.remove_body(tool);
    return true;
}

}  // namespace sx::feature_ops
