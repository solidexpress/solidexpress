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

bool apply_sketch(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                rebind_sketch_support(ctx.graph, doc, f);
                if (f.params.contains("converted_edges")) rebuild_converted_points(doc, f.id);
                return true;
}
bool apply_rib(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                const Feature* skf = params.contains("sketch")
                                         ? feature(EntityId::from_string(
                                               params["sketch"].get<std::string>()))
                                         : nullptr;
                if (!skf || !skf->sketch) return fail("rib needs a sketch profile");
                {
                    std::string xerr;
                    skf->sketch->resolve_expressions(env, &xerr);
                    auto solver = make_planegcs_backend();
                    solver->solve(*skf->sketch);
                }
                std::vector<gp_Pnt> profile;
                for (const auto& jp : sketch_ordered_polyline(*skf->sketch))
                    profile.push_back(pnt_from(jp));
                const auto n = skf->sketch->plane().normal();
                gp_Dir up(n[0], n[1], n[2]);
                double h = num_param(params, "height", 10.0, env);
                if (params.value("flip", false)) h = -h;
                std::string rerr;
                TopoDS_Shape rib = surf::rib_solid(profile, num_param(params, "thickness", 2.0, env),
                                                   h, up, &rerr);
                if (rib.IsNull()) return fail(rerr);
                BRepAlgoAPI_Fuse fuse(tb->shape, rib);
                if (!fuse.IsDone()) return fail("rib fuse failed");
                doc.replace_body_shape(target, fuse.Shape());
                return true;
            
}
bool apply_thicken(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                std::string terr;
                TopoDS_Shape solid =
                    surf::thicken(tb->shape, num_param(params, "offset", 1.0, env), &terr);
                if (solid.IsNull()) return fail(terr);
                doc.replace_body_shape(target, solid);
                return true;
            
}
bool apply_wrap(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                const Feature* skf = params.contains("sketch")
                                         ? feature(EntityId::from_string(
                                               params["sketch"].get<std::string>()))
                                         : nullptr;
                if (!skf || !skf->sketch) return fail("wrap needs a sketch profile");
                {
                    std::string xerr;
                    skf->sketch->resolve_expressions(env, &xerr);
                    auto solver = make_planegcs_backend();
                    solver->solve(*skf->sketch);
                }
                std::string perr;
                TopoDS_Shape profile = skf->sketch->profile_face(&perr);
                if (profile.IsNull()) return fail("wrap profile: " + perr);
                const double depth = num_param(params, "depth", 1.0, env);
                // Project the profile clear through the body, then keep only the
                // part inside the skin so the stamp follows the surface.
                Bnd_Box box;
                BRepBndLib::Add(tb->shape, box);
                if (box.IsVoid()) return fail("wrap target has no extent");
                double xmin, ymin, zmin, xmax, ymax, zmax;
                box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                const double reach = gp_Vec(xmax - xmin, ymax - ymin, zmax - zmin).Magnitude() + 4.0;
                const auto n = skf->sketch->plane().normal();
                gp_Vec dir(n[0], n[1], n[2]);
                dir.Normalize();
                gp_Trsf back;
                back.SetTranslation(dir * -reach);
                TopoDS_Shape start = BRepBuilderAPI_Transform(profile, back, true).Shape();
                TopoDS_Shape column = BRepPrimAPI_MakePrism(start, dir * (2.0 * reach)).Shape();
                if (column.IsNull()) return fail("wrap projection failed");
                const bool emboss = params.value("mode", "deboss") == "emboss";
                std::string serr;
                TopoDS_Shape stamp = surf::surface_stamp(tb->shape, column, depth, emboss, &serr);
                if (stamp.IsNull()) return fail("wrap: " + serr);
                TopoDS_Shape result;
                if (emboss) {
                    BRepAlgoAPI_Fuse fuse(tb->shape, stamp);
                    if (!fuse.IsDone()) return fail("emboss fuse failed");
                    result = fuse.Shape();
                } else {
                    BRepAlgoAPI_Cut cut(tb->shape, stamp);
                    if (!cut.IsDone()) return fail("deboss cut failed");
                    result = cut.Shape();
                }
                if (result.IsNull() || shape::volume(result) <= 1e-9)
                    return fail("wrap destroyed the body");
                doc.replace_body_shape(target, result);
                return true;
            
}
bool apply_flange(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                sheet::FlangeParams sp;
                sp.length = num_param(params, "length", 20.0, env);
                sp.thickness = num_param(params, "thickness", 1.5, env);
                sp.k_factor = num_param(params, "k_factor", 0.44, env);
                sp.radius = num_param(params, "radius", 1.5, env);
                sp.angle_rad = num_param(params, "angle_rad", 1.5707963267948966, env);
                const double base_leg = num_param(params, "base_length", sp.length, env);
                const double width = num_param(params, "width", 30.0, env);
                std::string serr;
                auto build = sheet::build_flange(base_leg, sp.length, width, sp,
                                                 placement_from(params), &serr);
                if (build.folded.IsNull()) return fail("flange: " + serr);
                f.params["flat_length"] = build.flat_length;
                f.params["flat_width"] = width;
                f.params["bend_allowance"] = build.bend_allowance;
                if (params.contains("target") && params["target"].is_string()) {
                    EntityId target = find_feature_body("target");
                    const Body* tb = doc.body(target);
                    if (!tb) return fail("missing flange target");
                    BRepAlgoAPI_Fuse onto(tb->shape, build.folded);
                    if (!onto.IsDone()) return fail("flange onto target failed");
                    doc.replace_body_shape(target, onto.Shape());
                } else {
                    put_body(doc, f.output_body, build.folded, f.name);
                }
                return true;
            
}
bool apply_knit(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                // Surfaces to sew come from earlier features ("targets") or from
                // loose bodies ("bodies", e.g. imported sheets).
                std::vector<TopoDS_Shape> parts;
                std::vector<EntityId> ids;
                auto take = [&](const EntityId& id) {
                    const Body* b = doc.body(id);
                    if (!b || b->shape.IsNull()) return;
                    parts.push_back(b->shape);
                    ids.push_back(id);
                };
                if (params.contains("targets") && params["targets"].is_array()) {
                    for (const auto& jt : params["targets"]) {
                        const Feature* ref = feature(EntityId::from_string(jt.get<std::string>()));
                        if (ref) take(ref->output_body);
                    }
                }
                if (params.contains("bodies") && params["bodies"].is_array()) {
                    for (const auto& jb : params["bodies"])
                        take(EntityId::from_string(jb.get<std::string>()));
                }
                if (parts.size() < 2) return fail("knit needs two or more surfaces");
                std::string kerr;
                TopoDS_Shape knitted = surf::knit(parts, 1e-6, &kerr);
                if (knitted.IsNull()) return fail("knit: " + kerr);
                doc.replace_body_shape(ids.front(), knitted);
                // The sewn sheets are consumed, like boolean tool bodies.
                for (size_t i = 1; i < ids.size(); ++i) doc.remove_body(ids[i]);
                return true;
            
}
bool apply_frame_member(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                if (!params.contains("path") || !params["path"].is_array() ||
                    params["path"].size() < 2)
                    return fail("frame path needs two points");
                const double w = num_param(params, "profile_w", 20.0, env);
                const double h = num_param(params, "profile_h", 20.0, env);
                gp_Pnt a = pnt_from(params["path"][0]);
                gp_Pnt b = pnt_from(params["path"][1]);
                gp_Vec v(a, b);
                const double len = v.Magnitude();
                if (len < 1e-9) return fail("zero-length frame");
                shape::Placement pl;
                pl.origin = {a.X(), a.Y(), a.Z()};
                gp_Dir z(v);
                pl.z_dir = {z.X(), z.Y(), z.Z()};
                const gp_Dir ref = (std::abs(z.Dot(gp_Dir(0, 0, 1))) < 0.9) ? gp_Dir(0, 0, 1)
                                                                            : gp_Dir(1, 0, 0);
                const gp_Dir x = z.Crossed(ref);
                pl.x_dir = {x.X(), x.Y(), x.Z()};
                TopoDS_Shape bar = shape::make_box(w, h, len, pl);
                put_body(doc, f.output_body, bar, f.name);
                f.params["cut_length"] = len;
                return true;
            
}
bool apply_in_context(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                const std::string ctx_s = params.value("context", "");
                const ContextSnapshot* snap =
                    ctx_s.empty() ? nullptr : doc.context(EntityId::from_string(ctx_s));
                const double height = snap ? snap->height : num_param(params, "c", 10.0, env);
                const double a = num_param(params, "a", 20.0, env);
                const double b = num_param(params, "b", 20.0, env);
                put_body(doc, f.output_body, shape::make_box(a, b, height), f.name);
                return true;
            
}
bool apply_convert_sheet(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("convert sheet needs a solid");
                double thickness = 0.0;
                if (!sheet::is_thin_solid(tb->shape, &thickness))
                    return fail("solid is not thin enough to convert");
                f.params["thickness"] = thickness;
                f.params["flat_area"] = sheet::flat_area(tb->shape);
                return true;
            
}
bool apply_user_feature(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                const auto steps = params.value("steps", json::array());
                if (steps.empty()) return fail("user feature has no steps");
                for (const auto& step : steps) {
                    const std::string st = step.value("type", "");
                    if (st == "hole") {
                        EntityId target;
                        try {
                            target = EntityId::from_string(step.value("target", params.value("target", "")));
                        } catch (...) {
                            return fail("user feature hole needs a target");
                        }
                        // Target may be a feature id or a body id.
                        if (!doc.body(target)) {
                            if (const Feature* tf = feature(target)) target = tf->output_body;
                        }
                        const Body* tb = doc.body(target);
                        if (!tb) return fail("user feature missing target body");
                        const double diameter = step.value("diameter", params.value("diameter", 6.0));
                        const double depth = step.value("depth", params.value("depth", 10.0));
                        json pos = step.contains("position") ? step["position"]
                                                             : json::array({params.value("x", 0.0),
                                                                            params.value("y", 0.0),
                                                                            params.value("z", 0.0)});
                        TopoDS_Shape tool = build_feature_hole_tool(
                            pnt_from(pos), gp_Dir(0, 0, -1), diameter, depth,
                            step.value("hole_type", "countersink"), 0.0, 0.0,
                            step.value("cs_diameter", params.value("cs_diameter", 12.0)),
                            step.value("cs_angle_deg", params.value("cs_angle_deg", 90.0)));
                        if (tool.IsNull()) return fail("user feature hole tool failed");
                        BRepAlgoAPI_Cut cut(tb->shape, tool);
                        if (!cut.IsDone()) return fail("user feature hole cut failed");
                        doc.replace_body_shape(target, cut.Shape());
                    } else if (st == "box") {
                        put_body(doc, f.output_body,
                                 shape::make_box(step.value("a", 10.0), step.value("b", 10.0),
                                                 step.value("c", 10.0)),
                                 f.name);
                    } else {
                        return fail("user feature step not supported: " + st);
                    }
                }
                return true;
            
}
bool apply_noop(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                return true;
}
bool apply_datum(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                const std::string kind = params.value("kind", "plane");
                EntityId did;
                if (params.contains("datum_id") && params["datum_id"].is_string()) {
                    did = EntityId::from_string(params["datum_id"].get<std::string>());
                } else {
                    did = EntityId::generate();
                    f.params["datum_id"] = did.str();
                }
                // Regenerating replaces the same UUID so cards/aliases survive.
                doc.remove_datum(did);
                if (kind == "axis") {
                    gp_Pnt p = pnt_from(params.at("point"));
                    gp_Dir d = dir_from(params.at("direction"));
                    doc.add_datum_axis({p.X(), p.Y(), p.Z()}, {d.X(), d.Y(), d.Z()}, did);
                } else if (kind == "point") {
                    gp_Pnt p = pnt_from(params.at("position"));
                    doc.add_datum_point({p.X(), p.Y(), p.Z()}, did);
                } else {
                    gp_Pnt o = pnt_from(params.at("origin"));
                    gp_Dir n = dir_from(params.at("normal"));
                    doc.add_datum_plane({o.X(), o.Y(), o.Z()}, {n.X(), n.Y(), n.Z()}, did);
                }
                return true;
            
}
}
