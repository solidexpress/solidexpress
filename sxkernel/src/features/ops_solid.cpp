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

bool apply_primitive(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                TopoDS_Shape shape = build_primitive_feature(params, env);
                // Rebuilding into a live body routes through replace_body_shape,
                // which runs the naming service so subshape ids survive edits.
                put_body(doc, f.output_body, shape, f.name);
                return true;
            
}
bool apply_extrude_revolve(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId sketch_fid = EntityId::from_string(params.at("sketch").get<std::string>());
                const Feature* skf = feature(sketch_fid);
                if (!skf || !skf->sketch) return fail("missing sketch feature");
                // Resolve "=expr" dimensions from VariableTable and solve before use.
                {
                    std::string xerr;
                    skf->sketch->resolve_expressions(env, &xerr);
                    auto solver = make_planegcs_backend();
                    solver->solve(*skf->sketch);
                }
                std::string perr;
                TopoDS_Shape face;
                double thin_thickness = num_param(params, "thin_thickness", 0.0, env);
                bool flip_side = params.value("flip_side", false);
                if (thin_thickness > 0.0) {
                    std::string thin_type = params.value("thin_type", "one_side");
                    bool thin_midplane = (thin_type == "midplane");
                    face = skf->sketch->thin_profile_face(thin_thickness, thin_midplane, flip_side,
                                                          &perr);
                    if (face.IsNull() && sketch_closed_contour(*skf->sketch))
                        return fail(thin_wall_on_error(thin_thickness));
                } else {
                    std::vector<int> contour_idxs;
                    if (params.contains("selected_contours") &&
                        params["selected_contours"].is_array()) {
                        for (const auto& v : params["selected_contours"]) {
                            if (v.is_number_integer()) contour_idxs.push_back(v.get<int>());
                        }
                    }
                    if (!contour_idxs.empty()) {
                        face = skf->sketch->profile_face_selected(contour_idxs, &perr);
                    } else {
                        face = skf->sketch->profile_face(&perr);
                    }
                    // Open-profile Extruded Cut (SW Flip Side to Cut): half-plane
                    // tool — not a thin wall. Only for cut/fuse when a closed
                    // profile is absent.
                    std::string op_early = params.value("op", "new");
                    if (face.IsNull() && (op_early == "cut" || op_early == "fuse")) {
                        double pad = 1.0e5;
                        if (params.contains("target") && params["target"].is_string()) {
                            const Body* tb = doc.body(find_feature_body("target"));
                            if (tb && !tb->shape.IsNull()) {
                                Bnd_Box box;
                                BRepBndLib::Add(tb->shape, box);
                                if (!box.IsVoid()) {
                                    double xmin, ymin, zmin, xmax, ymax, zmax;
                                    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                                    double diag = std::hypot(xmax - xmin,
                                                             std::hypot(ymax - ymin, zmax - zmin));
                                    pad = std::max(diag * 4.0, 100.0);
                                }
                            }
                        }
                        std::string oerr;
                        face = skf->sketch->open_cut_profile_face(flip_side, pad, &oerr);
                        if (face.IsNull())
                            perr = perr.empty() ? oerr : (perr + "; open-cut: " + oerr);
                        else
                            perr.clear();
                    }
                }
                if (face.IsNull()) return fail("profile: " + perr);

                TopoDS_Shape result;
                if (f.type == FeatureType::Extrude) {
                    auto n = skf->sketch->plane().normal();
                    gp_Vec dir(n[0], n[1], n[2]);
                    dir.Normalize();
                    double dist = num_param(params, "distance", 10.0, env);
                    std::string end = params.value("end", "");
                    if (end.empty())
                        end = params.value("symmetric", false) ? "symmetric" : "blind";
                    const bool symmetric = (end == "symmetric") || params.value("symmetric", false);
                    const std::string op_early = params.value("op", "new");
                    // Up To Surface / Through All keep the sign of `distance`.
                    // A cut stores a negative distance (opposite the sketch normal).
                    const double extrude_sign = dist < 0.0 ? -1.0 : 1.0;
                    // Material that appeared on the far side of a face sketch whose
                    // plane did not move when the boss was thickened (top-face cut
                    // to the bottom face, then base distance 10 → 14).
                    double to_face_back = 0.0;
                    if ((end == "through_all" || end == "to_next" || end == "to_face") &&
                        op_early != "new") {
                        EntityId target = find_feature_body("target");
                        const Body* tb = doc.body(target);
                        if (tb && !tb->shape.IsNull()) {
                            Bnd_Box box;
                            BRepBndLib::Add(tb->shape, box);
                            if (!box.IsVoid()) {
                                double xmin, ymin, zmin, xmax, ymax, zmax;
                                box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                                gp_Vec ext(xmax - xmin, ymax - ymin, zmax - zmin);
                                // Peer Through All: long enough to exit the target,
                                // preserving the requested extrude direction (sign).
                                dist = extrude_sign * (ext.Magnitude() + 4.0);
                            }
                            if (end == "to_face" && params.contains("to_face") &&
                                params["to_face"].is_string()) {
                                TopoDS_Shape tf = doc.resolve(
                                    EntityId::from_string(params["to_face"].get<std::string>()));
                                if (!tf.IsNull() && tf.ShapeType() == TopAbs_FACE && !box.IsVoid()) {
                                    const auto& o = skf->sketch->plane().origin;
                                    gp_Pnt orig(o[0], o[1], o[2]);
                                    // Signed extrude direction (unit): sketch normal,
                                    // reversed when the feature distance is negative.
                                    gp_Vec travel = dir;
                                    travel.Multiply(extrude_sign);
                                    double along = 0.0;
                                    bool have_along = false;
                                    BRepAdaptor_Surface surf(TopoDS::Face(tf));
                                    if (surf.GetType() == GeomAbs_Plane) {
                                        gp_Pln pln = surf.Plane();
                                        gp_Vec n(pln.Axis().Direction());
                                        double denom = travel.Dot(n);
                                        if (std::abs(denom) > 1e-9) {
                                            along = gp_Vec(orig, pln.Location()).Dot(n) / denom;
                                            have_along = true;
                                        }
                                    }
                                    if (!have_along) {
                                        BRepExtrema_DistShapeShape ds(
                                            BRepBuilderAPI_MakeVertex(orig).Vertex(), tf);
                                        if (ds.IsDone() && ds.NbSolution() >= 1) {
                                            along = gp_Vec(orig, ds.PointOnShape2(1)).Dot(travel);
                                            have_along = true;
                                        }
                                    }
                                    if (have_along) {
                                        double xmin, ymin, zmin, xmax, ymax, zmax;
                                        box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                                        gp_Pnt corners[8] = {
                                            {xmin, ymin, zmin}, {xmax, ymin, zmin},
                                            {xmin, ymax, zmin}, {xmax, ymax, zmin},
                                            {xmin, ymin, zmax}, {xmax, ymin, zmax},
                                            {xmin, ymax, zmax}, {xmax, ymax, zmax}};
                                        gp_Vec opposite = travel;
                                        opposite.Reverse();
                                        double back = 0.0;
                                        for (const auto& c : corners)
                                            back = std::max(back, gp_Vec(orig, c).Dot(opposite));
                                        const double forward = std::max(1e-3, along);
                                        to_face_back = back;
                                        dist = extrude_sign * (forward + back);
                                    }
                                }
                            }
                        }
                    }
                    TopoDS_Shape profile = face;
                    if (to_face_back > 1e-4) {
                        gp_Vec travel = dir;
                        travel.Multiply(extrude_sign);
                        gp_Trsf back_tr;
                        back_tr.SetTranslation(travel.Reversed() * to_face_back);
                        profile = BRepBuilderAPI_Transform(face, back_tr, true).Shape();
                    }
                    if (symmetric) {
                        gp_Trsf t;
                        t.SetTranslation(dir * (-dist / 2.0));
                        profile = BRepBuilderAPI_Transform(profile, t, true).Shape();
                    }
                    result = BRepPrimAPI_MakePrism(profile, dir * dist).Shape();
                } else {
                    const auto& pl = skf->sketch->plane();
                    auto at = [&](double u, double v) {
                        return gp_Pnt(pl.origin[0] + pl.x_dir[0] * u + pl.y_dir[0] * v,
                                      pl.origin[1] + pl.x_dir[1] * u + pl.y_dir[1] * v,
                                      pl.origin[2] + pl.x_dir[2] * u + pl.y_dir[2] * v);
                    };
                    auto ap = params.at("axis_point");
                    auto ad = params.at("axis_dir");
                    gp_Pnt p0 = at(ap[0].get<double>(), ap[1].get<double>());
                    gp_Pnt p1 = at(ap[0].get<double>() + ad[0].get<double>(),
                                   ap[1].get<double>() + ad[1].get<double>());
                    result = BRepPrimAPI_MakeRevol(face, gp_Ax1(p0, gp_Dir(gp_Vec(p0, p1))),
                                                   num_param(params, "angle", 6.283185307179586, env))
                                 .Shape();
                }
                if (result.IsNull()) return fail("geometry generation failed");

                std::string op = params.value("op", "new");
                if (op == "new") {
                    put_body(doc, f.output_body, result, f.name);
                } else {
                    EntityId target = find_feature_body("target");
                    const Body* tb = doc.body(target);
                    if (!tb) return fail("missing target body");
                    TopoDS_Shape merged;
                    if (op == "cut") {
                        BRepAlgoAPI_Cut cutter_op;
                        TopTools_ListOfShape args;
                        TopTools_ListOfShape tools;
                        args.Append(tb->shape);
                        tools.Append(result);
                        cutter_op.SetArguments(args);
                        cutter_op.SetTools(tools);
                        cutter_op.SetFuzzyValue(1e-4);
                        cutter_op.Build();
                        merged = cutter_op.Shape();
                    } else {
                        merged = TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, result).Shape());
                    }
                    if (merged.IsNull()) return fail("boolean failed");
                    doc.replace_body_shape(target, merged);
                }
                return true;
            
}
}
