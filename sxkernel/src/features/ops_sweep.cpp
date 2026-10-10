#include "ops.hpp"

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepTools.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Wire.hxx>
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
                    path = densify_catmull(uniq);
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
                    auto solver = make_planegcs_backend();
                    solver->solve(*skf->sketch);
                }
                std::string perr;
                TopoDS_Shape face = skf->sketch->profile_face(&perr);
                if (face.IsNull()) return fail("profile: " + perr);
                json path = params.value("path", json::array());
                if (params.contains("path_feature") && params["path_feature"].is_string()) {
                    const Feature* pf =
                        feature(EntityId::from_string(params["path_feature"].get<std::string>()));
                    if (!pf || pf->type != FeatureType::Path)
                        return fail("missing path feature");
                    // Prefer live params on the path feature (regenerated earlier).
                    path = pf->params.value("path", json::array());
                }
                if (!path.is_array() || path.size() < 2)
                    return fail("sweep needs a path with at least two points");

                // Optional guide: first guide sketch becomes MakePipeShell auxiliary spine.
                json guide_path;
                const json* guide_ptr = nullptr;
                if (params.contains("guides") && params["guides"].is_array() &&
                    !params["guides"].empty()) {
                    EntityId gid = EntityId::from_string(params["guides"][0].get<std::string>());
                    const Feature* gf = feature(gid);
                    if (!gf || !gf->sketch) return fail("missing guide sketch");
                    guide_path = sketch_ordered_polyline(*gf->sketch);
                    if (!guide_path.is_array() || guide_path.size() < 2)
                        return fail("guide needs >=2 points");
                    guide_ptr = &guide_path;
                }
                const double thin = num_param(params, "thin_thickness", 0.0, env);

                TopoDS_Shape result;
                try {
                    result = sweep_along_polyline(face, path, guide_ptr, thin);
                } catch (const Standard_Failure& e) {
                    return fail(std::string("sweep failed: ") + e.what());
                } catch (const std::runtime_error& e) {
                    return fail(e.what());
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("sweep result invalid");
                if (shape::count(result).solids < 1) return fail("sweep result is not a solid");

                std::string op = params.value("op", "new");
                if (op == "new") {
                    put_body(doc, f.output_body, result, f.name);
                } else {
                    EntityId target = find_feature_body("target");
                    const Body* tb = doc.body(target);
                    if (!tb) return fail("missing target body");
                    TopoDS_Shape merged =
                        (op == "cut")
                            ? TopoDS_Shape(BRepAlgoAPI_Cut(tb->shape, result).Shape())
                            : TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, result).Shape());
                    if (merged.IsNull()) return fail("boolean failed");
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
                    TopoDS_Shape face_shape = skf->sketch->profile_face(&perr);
                    if (face_shape.IsNull())
                        return fail("profile " + std::to_string(i) + ": " + perr);
                    TopoDS_Wire wire = BRepTools::OuterWire(TopoDS::Face(face_shape));
                    if (wire.IsNull())
                        return fail("profile " + std::to_string(i) + ": no outer wire");
                    sections.push_back(wire);
                    ++i;
                }
                // Optional guide curves (OCCT ThruSections has no AddGuide): sample each
                // guide and insert intermediate circular sections so the loft waist
                // follows the guide — volume differs from an unguided loft.
                if (params.contains("guides") && params["guides"].is_array() &&
                    !params["guides"].empty() && sections.size() >= 2) {
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
                    auto sample_poly = [](const std::vector<gp_Pnt>& pts, double t) -> gp_Pnt {
                        if (pts.empty()) return gp_Pnt();
                        if (pts.size() == 1) return pts[0];
                        double total = 0;
                        for (size_t k = 1; k < pts.size(); ++k)
                            total += pts[k - 1].Distance(pts[k]);
                        if (total < 1e-12) return pts[0];
                        double target = std::clamp(t, 0.0, 1.0) * total;
                        double acc = 0;
                        for (size_t k = 1; k < pts.size(); ++k) {
                            double seg = pts[k - 1].Distance(pts[k]);
                            if (acc + seg >= target - 1e-12) {
                                double u = seg > 1e-12 ? (target - acc) / seg : 0;
                                return pts[k - 1].Translated(gp_Vec(pts[k - 1], pts[k]) * u);
                            }
                            acc += seg;
                        }
                        return pts.back();
                    };
                    gp_Pnt c0 = wire_center(sections.front());
                    gp_Pnt c1 = wire_center(sections.back());
                    gp_Vec axis_vec(c0, c1);
                    if (axis_vec.Magnitude() < 1e-9) return fail("loft sections coincide");
                    gp_Dir axis_dir(axis_vec);
                    auto wire_radius = [](const TopoDS_Wire& w, const gp_Pnt& c) -> double {
                        double rmax = 0;
                        for (TopExp_Explorer ex(w, TopAbs_VERTEX); ex.More(); ex.Next()) {
                            gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(ex.Current()));
                            rmax = std::max(rmax, c.Distance(p));
                        }
                        return std::max(rmax, 1e-3);
                    };
                    const double r0 = wire_radius(sections.front(), c0);
                    const double r1 = wire_radius(sections.back(), c1);
                    const double r_lo = std::min(r0, r1) * 0.35;
                    const double r_hi = std::max(r0, r1) * 2.5;
                    std::vector<TopoDS_Wire> mids;
                    for (const auto& jg : params["guides"]) {
                        EntityId gid = EntityId::from_string(jg.get<std::string>());
                        const Feature* gf = feature(gid);
                        if (!gf || !gf->sketch) return fail("missing guide sketch");
                        json pl = sketch_ordered_polyline(*gf->sketch);
                        if (!pl.is_array() || pl.size() < 2) return fail("guide needs >=2 points");
                        std::vector<gp_Pnt> gpts;
                        for (const auto& jp : pl) gpts.push_back(pnt_from(jp));
                        for (double t : {0.35, 0.65}) {
                            gp_Pnt gp = sample_poly(gpts, t);
                            gp_Lin axis_line(c0, axis_dir);
                            double along = gp_Vec(axis_line.Location(), gp).Dot(axis_dir);
                            along = std::clamp(along, 0.0, axis_vec.Magnitude());
                            gp_Pnt foot = axis_line.Location().Translated(gp_Vec(axis_dir) * along);
                            double r_blend =
                                r0 + (r1 - r0) * (along / std::max(axis_vec.Magnitude(), 1e-9));
                            double r_off = foot.Distance(gp);
                            double r = std::clamp(0.5 * (r_blend + r_off), r_lo, r_hi);
                            if (r < 1e-6) r = 1e-3;
                            gp_Vec lateral(foot, gp);
                            lateral -= gp_Vec(axis_dir) * lateral.Dot(axis_dir);
                            gp_Pnt center = foot;
                            if (lateral.Magnitude() > 1e-9) {
                                double nudge = std::min(lateral.Magnitude(), r * 0.35);
                                center = foot.Translated(lateral.Normalized() * nudge);
                            }
                            gp_Circ circ(gp_Ax2(center, axis_dir), r);
                            TopoDS_Wire mw =
                                BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(circ).Edge()).Wire();
                            mids.push_back(mw);
                        }
                    }
                    std::vector<TopoDS_Wire> ordered;
                    ordered.push_back(sections.front());
                    for (auto& m : mids) ordered.push_back(m);
                    ordered.push_back(sections.back());
                    for (size_t si = 1; si + 1 < sections.size(); ++si)
                        ordered.insert(ordered.end() - 1, sections[si]);
                    sections = std::move(ordered);
                    ruled = false;  // smoothed loft through guide sections
                }
                BRepOffsetAPI_ThruSections loft(/*isSolid=*/true, ruled);
                for (const auto& w : sections) loft.AddWire(w);
                TopoDS_Shape result;
                try {
                    loft.Build();
                    if (!loft.IsDone()) return fail("ThruSections failed");
                    result = loft.Shape();
                } catch (const Standard_Failure& e) {
                    return fail(std::string("ThruSections failed: ") + e.what());
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
                    return fail(std::string("helix sweep failed: ") + e.what());
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
                    return fail(std::string("thread cutter failed: ") + e.what());
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
