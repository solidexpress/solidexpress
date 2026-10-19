#include "ops.hpp"

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <BRepFill_TypeOfContact.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRep_Tool.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepTools.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <ShapeFix_Solid.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <Standard_Failure.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Wire.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>

#include "sx/occt_types.hpp"
#include "sx/curves.hpp"
#include "sx/document.hpp"
#include "sx/interop.hpp"
#include "sx/log.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sheet_metal.hpp"
#include "sx/sketch3d.hpp"
#include "sx/solver.hpp"
#include "sx/surface_ops.hpp"
#include "sx/xref.hpp"

#include <algorithm>
#include <cmath>
#include <sstream>
#include <vector>

using nlohmann::json;

namespace sx::feature_ops {

bool apply_path(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                if (!params.contains("sketches") || !params["sketches"].is_array() ||
                    params["sketches"].empty())
                    return fail("path needs at least one sketch feature");
                std::string mode = params.value("mode", "join_endpoints");
                json path = json::array();
                std::vector<json> sketch_polys;
                for (const auto& js : params["sketches"]) {
                    EntityId sketch_fid = EntityId::from_string(js.get<std::string>());
                    const Feature* skf = feature(sketch_fid);
                    if (!skf || !skf->sketch)
                        return fail("missing sketch for path");
                    json pl = sketch_ordered_polyline(*skf->sketch);
                    if (pl.size() >= 2) sketch_polys.push_back(std::move(pl));
                }
                if (sketch_polys.empty()) return fail("path sketches have insufficient geometry");
                if (mode == "bridge_spline") {
                    std::vector<gp_Pnt> controls;
                    for (const auto& pl : sketch_polys) {
                        controls.push_back(pnt_from(pl[0]));
                        if (pl.size() >= 2) controls.push_back(pnt_from(pl[pl.size() - 1]));
                    }
                    const double eps = 1e-9;
                    std::vector<gp_Pnt> uniq;
                    for (const auto& p : controls) {
                        if (uniq.empty() || uniq.back().Distance(p) >= eps) uniq.push_back(p);
                    }
                    if (uniq.size() < 2) return fail("bridge_spline needs >=2 control points");
                    if (uniq.size() > 24) {
                        std::vector<gp_Pnt> thin;
                        for (size_t i = 0; i < uniq.size(); i += uniq.size() / 12 + 1)
                            thin.push_back(uniq[i]);
                        if (thin.back().Distance(uniq.back()) > 1e-6) thin.push_back(uniq.back());
                        uniq = std::move(thin);
                    }
                    TopoDS_Wire exact = interpolate_wire(uniq);
                    if (!exact.IsNull()) {
                        path = sample_wire_polyline(exact, 8);
                    } else {
                        ctx.graph.add_warning(f.id, std::string(kApproxPathWarning));
                        path = densify_catmull(uniq);
                    }
                } else {
                    // join_endpoints / composite: sketch order + endpoint join (not global NN).
                    path = sketch_polys[0];
                    for (size_t i = 1; i < sketch_polys.size(); ++i)
                        path = join_polylines(std::move(path), sketch_polys[i]);
                }
                if (path.size() < 2) return fail("path rebuild produced <2 points");
                path = simplify_path_polyline(path);
                if (path.size() < 2) return fail("path rebuild produced <2 points");
                f.params["path"] = path;
                return true;
            
}

struct SweepFuse {
    static constexpr double KEEP_RATIO = kHonestKeepRatio;
    static constexpr double XMAX_TIE_MM = 0.5;
    static constexpr double MIN_VOLUME = 1.0e-3;
    static constexpr double FUZZIES[] = {0.0, 1.0e-4, 1.0e-3, 0.05};

    static bool usable(const TopoDS_Shape& s) {
        return !s.IsNull() && shape::count(s).solids >= 1
               && std::abs(shape::volume(s)) > MIN_VOLUME;
    }

    static bool keeps_target(const TopoDS_Shape& body, const TopoDS_Shape& merged) {
        if (!usable(merged)) return false;
        const double bv = std::abs(shape::volume(body));
        if (bv <= 1.0) return true;
        return std::abs(shape::volume(merged)) >= bv * KEEP_RATIO;
    }

    static double xmax(const TopoDS_Shape& s) {
        if (s.IsNull()) return -1.0e99;
        Bnd_Box box;
        BRepBndLib::Add(s, box);
        if (box.IsVoid()) return -1.0e99;
        double x0, y0, z0, x1, y1, z1;
        box.Get(x0, y0, z0, x1, y1, z1);
        return x1;
    }

    static TopoDS_Shape pick_xmax_then_volume(const std::vector<TopoDS_Shape>& shapes) {
        if (shapes.empty()) return {};
        double best_x = -1.0e99;
        for (const auto& s : shapes)
            best_x = std::max(best_x, xmax(s));
        TopoDS_Shape result = shapes.front();
        double best_vol = -1.0;
        for (const auto& s : shapes) {
            if (xmax(s) < best_x - XMAX_TIE_MM) continue;
            const double v = std::abs(shape::volume(s));
            if (v > best_vol) {
                best_vol = v;
                result = s;
            }
        }
        return result;
    }

    static TopoDS_Shape keep_solid(const TopoDS_Shape& s) {
        if (!usable(s)) return s;
        std::string report;
        TopoDS_Shape healed = interop::heal_shape(s, &report);
        return usable(healed) ? healed : s;
    }

    static TopoDS_Shape run_fuse(const TopoDS_Shape& a, const TopoDS_Shape& b, double fuzzy) {
        BRepAlgoAPI_Fuse opf;
        TopTools_ListOfShape args;
        TopTools_ListOfShape tools;
        args.Append(a);
        tools.Append(b);
        opf.SetArguments(args);
        opf.SetTools(tools);
        opf.SetFuzzyValue(fuzzy);
        opf.Build();
        if (opf.IsDone() && usable(opf.Shape())) return opf.Shape();
        return {};
    }

    static TopoDS_Shape run_cut(const TopoDS_Shape& a, const TopoDS_Shape& b, double fuzzy) {
        BRepAlgoAPI_Cut opc;
        TopTools_ListOfShape args;
        TopTools_ListOfShape tools;
        args.Append(a);
        tools.Append(b);
        opc.SetArguments(args);
        opc.SetTools(tools);
        opc.SetFuzzyValue(fuzzy);
        opc.Build();
        if (opc.IsDone() && usable(opc.Shape())) return opc.Shape();
        return {};
    }

    static TopoDS_Shape fuse_ribbon(const TopoDS_Shape& body, const TopoDS_Shape& ribbon,
                                    std::string* warning = nullptr) {
        HonestBoolean hb = HonestBoolean::fuse(body, ribbon);
        if (keeps_target(body, hb.shape)) {
            if (warning && !hb.warning.empty()) *warning = hb.warning;
            return hb.shape;
        }
        const TopoDS_Shape left = keep_solid(body);
        const TopoDS_Shape right = keep_solid(ribbon);
        const double silent = HonestBoolean::silent_limit(body, ribbon);
        auto note = [&](double fuzzy) {
            if (!warning) return;
            if (fuzzy > silent) {
                std::ostringstream os;
                os << kBooleanFuzzWarning << fuzzy;
                *warning = os.str();
            }
        };
        for (double fuzzy : FUZZIES) {
            TopoDS_Shape m = run_fuse(body, ribbon, fuzzy);
            if (keeps_target(body, m)) {
                note(fuzzy);
                return m;
            }
            m = run_fuse(left, right, fuzzy);
            if (keeps_target(body, m)) {
                note(fuzzy);
                return m;
            }
        }
        for (double fuzzy : FUZZIES) {
            TopoDS_Shape outside = run_cut(ribbon, body, fuzzy);
            if (!usable(outside)) outside = run_cut(right, left, fuzzy);
            if (!usable(outside)) continue;
            TopoDS_Shape m = run_fuse(body, outside, fuzzy);
            if (keeps_target(body, m)) {
                if (warning) *warning = "boolean fallback cut-then-fuse";
                return m;
            }
            m = run_fuse(left, outside, fuzzy);
            if (keeps_target(body, m)) {
                if (warning) *warning = "boolean fallback cut-then-fuse";
                return m;
            }
        }
        return {};
    }
};

bool apply_sweep(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId sketch_fid =
                    EntityId::from_string(params.at("sketch").get<std::string>());
                const Feature* skf = feature(sketch_fid);
                if (!skf || !skf->sketch) return fail("missing sketch feature");
                {
                    std::string xerr;
                    skf->sketch->resolve_expressions(env, &xerr);
                    std::string closed_err;
                    // A fully defined ellipse is already a closed profile.
                    // Solving leftover dims warps it and the pipe then
                    // fails to fuse onto the revolve.
                    if (skf->sketch->profile_face(&closed_err).IsNull()) {
                        auto solver = make_planegcs_backend();
                        solver->solve(*skf->sketch);
                    }
                }
                std::string perr;
                TopoDS_Shape face = skf->sketch->profile_face(&perr);
                if (face.IsNull()) return fail("profile: " + perr);
                json path = params.value("path", json::array());
                TopoDS_Wire spine;
                if (params.contains("path_feature") && params["path_feature"].is_string()) {
                    const Feature* pf =
                        feature(EntityId::from_string(params["path_feature"].get<std::string>()));
                    if (pf && pf->type == FeatureType::Path) {
                        // Prefer live params on the path feature (regenerated earlier).
                        path = pf->params.value("path", json::array());
                        const json& rails = pf->params.value("sketches", json::array());
                        const std::string mode = pf->params.value("mode", "join_endpoints");
                        if (mode == "bridge_spline" && rails.is_array()) {
                            std::vector<gp_Pnt> controls;
                            for (const auto& js : rails) {
                                const Feature* psk =
                                    feature(EntityId::from_string(js.get<std::string>()));
                                if (!psk || !psk->sketch) continue;
                                json pl = sketch_ordered_polyline(*psk->sketch);
                                if (pl.size() < 2) continue;
                                controls.push_back(pnt_from(pl[0]));
                                controls.push_back(pnt_from(pl[pl.size() - 1]));
                            }
                            std::vector<gp_Pnt> uniq;
                            for (const auto& p : controls) {
                                if (uniq.empty() || uniq.back().Distance(p) >= 1e-9)
                                    uniq.push_back(p);
                            }
                            if (uniq.size() >= 2) spine = interpolate_wire(uniq);
                        } else if (rails.is_array()) {
                            std::vector<TopoDS_Wire> wires;
                            for (const auto& js : rails) {
                                const Feature* psk =
                                    feature(EntityId::from_string(js.get<std::string>()));
                                if (psk && psk->sketch) {
                                    TopoDS_Wire w = sketch_exact_wire(*psk->sketch);
                                    if (!w.IsNull()) wires.push_back(w);
                                }
                            }
                            spine = join_exact_wires(wires);
                        }
                    } else if (pf && pf->sketch) {
                        spine = sketch_exact_wire(*pf->sketch);
                    } else if (!pf) {
                        return fail("missing path feature");
                    }
                }
                if (!path.is_array() || path.size() < 2)
                    return fail("sweep needs a path with at least two points");

                // Optional guide: first guide sketch becomes MakePipeShell auxiliary spine.
                json guide_path;
                const json* guide_ptr = nullptr;
                TopoDS_Wire guide_wire;
                if (params.contains("guides") && params["guides"].is_array() &&
                    !params["guides"].empty()) {
                    EntityId gid = EntityId::from_string(params["guides"][0].get<std::string>());
                    const Feature* gf = feature(gid);
                    if (!gf || !gf->sketch) return fail("missing guide sketch");
                    guide_wire = sketch_exact_wire(*gf->sketch);
                    if (guide_wire.IsNull()) {
                        guide_path = sketch_ordered_polyline(*gf->sketch);
                        if (!guide_path.is_array() || guide_path.size() < 2)
                            return fail("guide needs >=2 points");
                        guide_ptr = &guide_path;
                    }
                }
                const double thin = num_param(params, "thin_thickness", 0.0, env);
                const bool contact = params.value("contact", false);
                const TopoDS_Wire* exact_guide =
                    guide_wire.IsNull() ? nullptr : &guide_wire;

                auto pipe = [&](bool frenet, bool corr) -> TopoDS_Shape {
                    if (spine.IsNull()) return {};
                    if (guide_ptr != nullptr && exact_guide == nullptr) return {};
                    try {
                        return sweep_along_spine(face, spine, thin, contact, frenet, corr,
                                                 exact_guide);
                    } catch (...) {
                        return {};
                    }
                };
                auto polyline = [&]() -> TopoDS_Shape {
                    try {
                        return sweep_along_polyline(face, path, guide_ptr, thin, contact);
                    } catch (...) {
                        return {};
                    }
                };
                std::vector<TopoDS_Shape> ribbons;
                auto add_ribbon = [&](const TopoDS_Shape& s) {
                    if (SweepFuse::usable(s)) ribbons.push_back(s);
                };
                add_ribbon(pipe(true, true));
                add_ribbon(pipe(true, false));
                add_ribbon(pipe(false, true));
                add_ribbon(pipe(false, false));
                if (ribbons.empty()) {
                    ctx.graph.add_warning(f.id, std::string(kApproxPathWarning));
                    add_ribbon(polyline());
                    if (ribbons.empty()) {
                        try {
                            add_ribbon(sweep_along_polyline(face, path, guide_ptr, thin, contact));
                        } catch (const Standard_Failure& e) {
                            return fail(std::string("sweep failed: ") + e.GetMessageString());
                        } catch (const std::runtime_error& e) {
                            return fail(e.what());
                        }
                    }
                }
                if (ribbons.empty()) return fail("sweep result is not a solid");
                // Frenet follow-path is first in `ribbons` and reaches ~5 mm
                // past the hook. A later polyline ribbon can still fuse when
                // Frenet's boolean is messy — keep the farthest +X solid.
                // Same xmax: pick the larger volume so a 0-volume Transformed
                // pipe does not beat a filled cylinder.
                TopoDS_Shape result = SweepFuse::pick_xmax_then_volume(ribbons);

                std::string op = params.value("op", "new");
                auto close_solid = [&](TopoDS_Shape s) -> TopoDS_Shape {
                    if (s.IsNull()) return s;
                    const TopoDS_Shape orig = s;
                    std::string report;
                    TopoDS_Shape healed = interop::heal_shape(s, &report);
                    if (SweepFuse::usable(healed)) s = healed;
                    try {
                        ShapeUpgrade_UnifySameDomain unify(s, true, true, true);
                        unify.SetLinearTolerance(1.0e-4);
                        unify.Build();
                        if (SweepFuse::usable(unify.Shape())) s = unify.Shape();
                    } catch (...) {
                    }
                    if (!s.IsNull() && shape::volume(s) < 0.0) s.Reverse();
                    return SweepFuse::usable(s) ? s : orig;
                };
                if (op == "new") {
                    put_body(doc, f.output_body, result, f.name);
                } else {
                    EntityId target = find_feature_body("target");
                    const Body* tb = doc.body(target);
                    if (!tb) return fail("missing target body");
                    TopoDS_Shape merged;
                    if (op == "cut") {
                        merged = BRepAlgoAPI_Cut(tb->shape, result).Shape();
                    } else {
                        std::vector<TopoDS_Shape> fused;
                        std::string bool_warn;
                        for (const auto& ribbon : ribbons) {
                            std::string w;
                            TopoDS_Shape m = SweepFuse::fuse_ribbon(tb->shape, ribbon, &w);
                            if (SweepFuse::keeps_target(tb->shape, m)) {
                                fused.push_back(m);
                                if (bool_warn.empty()) bool_warn = w;
                            }
                        }
                        merged = SweepFuse::pick_xmax_then_volume(fused);
                        if (!bool_warn.empty()) ctx.graph.add_warning(f.id, bool_warn);
                    }
                    if (!SweepFuse::usable(merged)) return fail("boolean failed");
                    TopoDS_Shape closed = close_solid(merged);
                    if (SweepFuse::usable(closed)) merged = closed;
                    doc.replace_body_shape(target, merged);
                }
                return true;
            
}
bool apply_loft(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                if (!params.contains("sketches") || !params["sketches"].is_array() ||
                    params["sketches"].size() < 2)
                    return fail("need at least two sketch features");
                bool ruled = params.value("ruled", false);
                std::vector<TopoDS_Wire> sections;
                size_t i = 0;
                for (const auto& js : params["sketches"]) {
                    EntityId sketch_fid = EntityId::from_string(js.get<std::string>());
                    const Feature* skf = feature(sketch_fid);
                    if (!skf || !skf->sketch)
                        return fail("missing sketch feature " + std::to_string(i));
                    {
                        std::string xerr;
                        skf->sketch->resolve_expressions(env, &xerr);
                        auto solver = make_planegcs_backend();
                        solver->solve(*skf->sketch);
                    }
                    std::string perr;
                    auto chained = skf->sketch->chained_faces(&perr);
                    TopoDS_Shape face_shape;
                    double best_a = -1.0;
                    for (const auto& c : chained) {
                        if (c.IsNull() || c.ShapeType() != TopAbs_FACE) continue;
                        const double a = std::abs(shape::area(c));
                        if (a > best_a) {
                            best_a = a;
                            face_shape = c;
                        }
                    }
                    if (face_shape.IsNull())
                        face_shape = skf->sketch->profile_face(&perr);
                    if (face_shape.IsNull())
                        return fail("profile " + std::to_string(i) + ": " + perr);
                    TopoDS_Wire wire;
                    if (face_shape.ShapeType() == TopAbs_FACE) {
                        wire = BRepTools::OuterWire(TopoDS::Face(face_shape));
                    } else {
                        wire = sketch_exact_wire(*skf->sketch, /*closed=*/true);
                        if (wire.IsNull()) {
                            json pl = sketch_ordered_polyline(*skf->sketch);
                            if (pl.is_array() && pl.size() >= 3) {
                                if (pnt_from(pl.front()).Distance(pnt_from(pl.back())) > 1e-6)
                                    pl.push_back(pl.front());
                                try {
                                    wire = make_polyline_wire(pl);
                                    ctx.graph.add_warning(f.id, std::string(kApproxPathWarning));
                                } catch (...) {
                                    wire = {};
                                }
                            }
                        }
                    }
                    if (wire.IsNull())
                        return fail("profile " + std::to_string(i) + ": no outer wire");
                    sections.push_back(wire);
                    ++i;
                }

                auto wire_center = [](const TopoDS_Wire& w) -> gp_Pnt {
                    BRepBuilderAPI_MakeFace mkf(w, /*OnlyPlane=*/true);
                    if (mkf.IsDone()) {
                        GProp_GProps props;
                        BRepGProp::SurfaceProperties(mkf.Face(), props);
                        return props.CentreOfMass();
                    }
                    TopoDS_Iterator it(w);
                    if (it.More()) {
                        TopoDS_Vertex v = TopExp::FirstVertex(TopoDS::Edge(it.Value()));
                        return BRep_Tool::Pnt(v);
                    }
                    return gp_Pnt(0, 0, 0);
                };
                auto pipe_ok = [](const TopoDS_Shape& s) {
                    return !s.IsNull() && shape::count(s).solids >= 1 &&
                           std::abs(shape::volume(s)) > 1.0e-3;
                };
                auto guide_on_solid = [](const TopoDS_Wire& guide, const TopoDS_Shape& solid) {
                    if (guide.IsNull() || solid.IsNull()) return false;
                    for (TopExp_Explorer ex(guide, TopAbs_EDGE); ex.More(); ex.Next()) {
                        BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
                        for (int s = 0; s <= 8; ++s) {
                            const double t = static_cast<double>(s) / 8.0;
                            const double u =
                                c.FirstParameter() + t * (c.LastParameter() - c.FirstParameter());
                            TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(c.Value(u)).Vertex();
                            BRepExtrema_DistShapeShape dist(v, solid);
                            if (!dist.IsDone() || dist.NbSolution() < 1) return false;
                            if (dist.Value() > 1e-4) return false;
                        }
                    }
                    return true;
                };
                auto try_pipe = [&](const TopoDS_Wire& spine, const TopoDS_Wire& aux,
                                    BRepFill_TypeOfContact contact, bool with_contact,
                                    bool with_corr) -> TopoDS_Shape {
                    if (spine.IsNull()) return {};
                    try {
                        BRepOffsetAPI_MakePipeShell shell(spine);
                        if (!aux.IsNull())
                            shell.SetMode(aux, /*CurvilinearEquivalence=*/false, contact);
                        else
                            shell.SetMode(false);
                        shell.SetTransitionMode(BRepBuilderAPI_Transformed);
                        for (const auto& sec : sections) shell.Add(sec, with_contact, with_corr);
                        shell.Build();
                        if (!shell.IsDone() || !shell.MakeSolid()) return {};
                        TopoDS_Shape s = shell.Shape();
                        return pipe_ok(s) ? s : TopoDS_Shape{};
                    } catch (const Standard_Failure&) {
                        return {};
                    }
                };

                TopoDS_Shape result;
                if (params.contains("guides") && params["guides"].is_array() &&
                    !params["guides"].empty() && sections.size() >= 2) {
                    std::vector<TopoDS_Wire> guides;
                    for (const auto& jg : params["guides"]) {
                        EntityId gid = EntityId::from_string(jg.get<std::string>());
                        const Feature* gf = feature(gid);
                        if (!gf || !gf->sketch) return fail("missing guide sketch");
                        TopoDS_Wire gw = sketch_exact_wire(*gf->sketch);
                        if (gw.IsNull()) {
                            json pl = sketch_ordered_polyline(*gf->sketch);
                            if (pl.is_array() && pl.size() >= 2) {
                                try {
                                    gw = make_polyline_wire(pl);
                                } catch (...) {
                                    gw = {};
                                }
                            }
                        }
                        if (gw.IsNull()) return fail("guide needs a usable wire");
                        guides.push_back(gw);
                    }
                    gp_Pnt c0 = wire_center(sections.front());
                    gp_Pnt c1 = wire_center(sections.back());
                    if (c0.Distance(c1) < 1e-9) return fail("loft sections coincide");
                    TopoDS_Wire centre_spine =
                        BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c0, c1).Edge()).Wire();
                    const BRepFill_TypeOfContact contacts[] = {BRepFill_ContactOnBorder,
                                                               BRepFill_Contact};
                    const bool flags[] = {false, true};
                    bool followed = false;
                    for (const auto& g : guides) {
                        for (auto c : contacts) {
                            for (bool wc : flags) {
                                for (bool wr : flags) {
                                    result = try_pipe(centre_spine, g, c, wc, wr);
                                    if (pipe_ok(result) && guide_on_solid(g, result)) {
                                        followed = true;
                                        break;
                                    }
                                    result = try_pipe(g, centre_spine, c, wc, wr);
                                    if (pipe_ok(result) && guide_on_solid(g, result)) {
                                        followed = true;
                                        break;
                                    }
                                }
                                if (followed) break;
                            }
                            if (followed) break;
                        }
                        if (followed) break;
                    }
                    if (!followed) return fail("guided loft: OCCT could not follow the guide");
                } else {
                    BRepOffsetAPI_ThruSections loft(/*isSolid=*/true, ruled);
                    for (const auto& w : sections) loft.AddWire(w);
                    try {
                        loft.Build();
                        if (!loft.IsDone()) return fail("ThruSections failed");
                        result = loft.Shape();
                    } catch (const Standard_Failure& e) {
                        return fail(std::string("ThruSections failed: ") + e.GetMessageString());
                    }
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("loft result invalid");
                if (shape::count(result).solids < 1) return fail("loft result is not a solid");
                put_body(doc, f.output_body, result, f.name);
                return true;
            
}
bool apply_helix_sweep(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                if (!params.contains("axis_point") || !params.contains("axis_dir"))
                    return fail("missing axis_point/axis_dir");
                const double profile_r = num_param(params, "profile_radius", 1.0, env);
                const double radius = num_param(params, "radius", 0.0, env);
                const double pitch = num_param(params, "pitch", 0.0, env);
                const double turns = num_param(params, "turns", 0.0, env);
                const bool left_handed = params.value("left_handed", false);
                gp_Ax2 axis(pnt_from(params.at("axis_point")),
                           dir_from(params.at("axis_dir")));
                TopoDS_Shape result;
                try {
                    result = helix_sweep_solid(axis, radius, pitch, turns, left_handed,
                                               profile_r);
                } catch (const Standard_Failure& e) {
                    return fail(std::string("helix sweep failed: ") + e.GetMessageString());
                } catch (const std::runtime_error& e) {
                    return fail(e.what());
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("helix sweep result invalid");
                if (shape::count(result).solids < 1)
                    return fail("helix sweep result is not a solid");
                put_body(doc, f.output_body, result, f.name);
                return true;
            
}
bool apply_thread(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                if (!params.contains("axis_point") || !params.contains("axis_dir"))
                    return fail("missing axis_point/axis_dir");
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                const double major_radius = num_param(params, "major_radius", 0.0, env);
                const double pitch = num_param(params, "pitch", 0.0, env);
                const double turns = num_param(params, "turns", 0.0, env);
                const double depth = num_param(params, "depth", pitch * 0.6, env);
                const double angle_deg = num_param(params, "profile_angle_deg", 60.0, env);
                gp_Ax2 axis(pnt_from(params.at("axis_point")),
                           dir_from(params.at("axis_dir")));
                TopoDS_Shape cutter;
                try {
                    cutter = thread_cutter_solid(axis, major_radius, pitch, turns, depth,
                                                 angle_deg);
                } catch (const Standard_Failure& e) {
                    return fail(std::string("thread cutter failed: ") + e.GetMessageString());
                } catch (const std::runtime_error& e) {
                    return fail(e.what());
                }
                if (cutter.IsNull() || !shape::is_valid(cutter))
                    return fail("thread cutter invalid");
                BRepAlgoAPI_Cut cut(tb->shape, cutter);
                if (!cut.IsDone()) return fail("thread cut failed");
                TopoDS_Shape result = cut.Shape();
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("thread result invalid");
                if (shape::count(result).solids < 1 || shape::volume(result) <= 0.0)
                    return fail("thread destroyed the solid");
                doc.replace_body_shape(target, result);
                return true;
            
}
}
