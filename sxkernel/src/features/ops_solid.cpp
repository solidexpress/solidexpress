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
#include "sx/sketch_regions.hpp"
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
namespace {

std::vector<double> sketch_params(const Sketch& sk) {
    std::vector<double> out;
    out.reserve(sk.param_count());
    for (size_t i = 0; i < sk.param_count(); ++i) out.push_back(sk.param(i));
    return out;
}

void restore_sketch_params(Sketch& sk, const std::vector<double>& saved) {
    const size_t n = std::min(saved.size(), sk.param_count());
    for (size_t i = 0; i < n; ++i) sk.param_mut(i) = saved[i];
}

bool sketch_has_closed_region(const Sketch& sk) {
    std::string ignored;
    return !sk.profile_face_selected({}, &ignored).IsNull();
}

}  // namespace

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
                // A click-built profile can already be closed while leftover
                // constraints still fight; PlaneGCS then splits coincident
                // joints. Keep the pre-solve geometry when that happens.
                {
                    std::string xerr;
                    skf->sketch->resolve_expressions(env, &xerr);
                    auto saved = sketch_params(*skf->sketch);
                    const bool closed_before = sketch_has_closed_region(*skf->sketch);
                    std::string arr_err;
                    const bool revolve_region =
                        f.type == FeatureType::Revolve &&
                        (closed_before || !skf->sketch->arrangement_faces(&arr_err).empty());
                    // Click-built revolved rims are already a closed arrangement
                    // cell even when chained profile_face still reports open.
                    // PlaneGCS leftover dims then self-intersect the toe
                    // (candlestick R12.5). Keep the drawn region.
                    if (!revolve_region) {
                        auto solver = make_planegcs_backend();
                        solver->solve(*skf->sketch);
                        skf->sketch->reconcile_arc_angles();
                        if (closed_before && !sketch_has_closed_region(*skf->sketch)) {
                            restore_sketch_params(*skf->sketch, saved);
                            skf->sketch->reconcile_arc_angles();
                        }
                    }
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
                    std::vector<int> contour_idxs = selected_contour_indices(params);
                    TopoDS_Shape host;
                    if (skf->params.contains("host_face") && skf->params["host_face"].is_string()) {
                        host = doc.resolve(EntityId::from_string(
                            skf->params["host_face"].get<std::string>()));
                        if (!host.IsNull() && host.ShapeType() != TopAbs_FACE) host.Nullify();
                    }
                    if (!contour_idxs.empty()) {
                        face = skf->sketch->profile_face_selected(contour_idxs, host, &perr);
                    } else if (f.type == FeatureType::Revolve) {
                        // Sketch-only closed regions. A leftover open chain is
                        // common on a click-built revolve profile and must not
                        // refuse. Do not split a host datum — that face is the
                        // whole plane and MakeRevol then throws BRep_API.
                        // A compound of two regions (lens + candlestick) also
                        // makes MakeRevol IsDone false; take the largest face.
                        auto pick_largest = [](const std::vector<TopoDS_Shape>& regions) {
                            TopoDS_Shape best;
                            double best_a = 0.0;
                            for (const auto& c : regions) {
                                const double a = std::abs(shape::area(c));
                                if (a > best_a) {
                                    best_a = a;
                                    best = c;
                                }
                            }
                            return best;
                        };
                        auto regions = skf->sketch->arrangement_faces(&perr);
                        face = pick_largest(regions);
                        if (face.IsNull())
                            face = pick_largest(skf->sketch->contour_faces(&perr));
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
                    const double draft_deg = num_param(params, "draft_deg", 0.0, env);
                    const bool draft_inward = params.value("draft_inward", true);
                    if (std::abs(draft_deg) >= 75.0)
                        return fail("draft angle too large");
                    if (std::abs(draft_deg) > 1e-9) {
                        TopoDS_Face pface;
                        if (profile.ShapeType() == TopAbs_FACE)
                            pface = TopoDS::Face(profile);
                        else {
                            TopExp_Explorer fx(profile, TopAbs_FACE);
                            if (fx.More()) pface = TopoDS::Face(fx.Current());
                        }
                        if (pface.IsNull()) return fail("draft needs a planar profile");
                        TopoDS_Wire w0 = BRepTools::OuterWire(pface);
                        if (w0.IsNull()) return fail("draft profile has no outer wire");
                        GProp_GProps props;
                        BRepGProp::SurfaceProperties(pface, props);
                        const gp_Pnt c = props.CentreOfMass();
                        const double area = std::abs(props.Mass());
                        const double r = std::sqrt(std::max(area, 0.0) / 3.14159265358979323846);
                        const gp_Vec travel = dir * dist;
                        const double len = travel.Magnitude();
                        const double tan_a = std::tan(std::abs(draft_deg) * 3.14159265358979323846 / 180.0);
                        const double r2 = draft_inward ? (r - len * tan_a) : (r + len * tan_a);
                        if (r2 <= 1e-3) return fail("draft angle too large");
                        gp_Trsf move;
                        move.SetTranslation(travel);
                        TopoDS_Shape moved = BRepBuilderAPI_Transform(w0, move, true).Shape();
                        gp_Trsf scal;
                        scal.SetScale(c.Translated(travel), r2 / std::max(r, 1e-9));
                        TopoDS_Shape scaled = BRepBuilderAPI_Transform(moved, scal, true).Shape();
                        if (scaled.ShapeType() != TopAbs_WIRE)
                            return fail("draft scale failed");
                        BRepOffsetAPI_ThruSections loft(Standard_True);
                        loft.AddWire(w0);
                        loft.AddWire(TopoDS::Wire(scaled));
                        loft.Build();
                        if (!loft.IsDone()) return fail("draft frustum failed");
                        result = loft.Shape();
                    } else {
                        result = BRepPrimAPI_MakePrism(profile, dir * dist).Shape();
                    }
                } else {
                    if (face.IsNull())
                        return fail(std::string("revolve profile: ") +
                                    (perr.empty() ? "empty" : perr));
                    const double raw_area = shape::area(face);
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
                    if (p0.Distance(p1) < 1e-9)
                        return fail("revolve axis is degenerate");
                    gp_Ax1 axis(p0, gp_Dir(gp_Vec(p0, p1)));
                    const double ang = num_param(params, "angle", 6.283185307179586, env);
                    auto revol = [&](const TopoDS_Shape& src, bool copy = false) -> TopoDS_Shape {
                        try {
                            BRepPrimAPI_MakeRevol mk(src, axis, ang, copy);
                            return mk.IsDone() ? mk.Shape() : TopoDS_Shape();
                        } catch (const Standard_Failure&) {
                            return {};
                        }
                    };
                    auto revol_any = [&](const TopoDS_Shape& src) -> TopoDS_Shape {
                        TopoDS_Shape out = revol(src, false);
                        if (out.IsNull()) out = revol(src.Reversed(), false);
                        if (out.IsNull()) out = revol(src, true);
                        if (out.IsNull()) out = revol(src.Reversed(), true);
                        if (out.IsNull()) {
                            // A cell that micrometer-crosses the axis (xmin≈-1e-5)
                            // makes MakeRevol IsDone false. Nudge to the +side.
                            const auto& nrm = skf->sketch->plane().normal();
                            gp_Vec away = gp_Vec(axis.Direction())
                                              .Crossed(gp_Vec(nrm[0], nrm[1], nrm[2]));
                            if (away.Magnitude() > 1e-12) {
                                away.Normalize();
                                away *= 1.0e-4;
                                gp_Trsf nudge;
                                nudge.SetTranslation(away);
                                TopoDS_Shape moved =
                                    BRepBuilderAPI_Transform(src, nudge, true).Shape();
                                out = revol(moved, true);
                                if (out.IsNull()) out = revol(moved.Reversed(), true);
                            }
                        }
                        return out;
                    };
                    result = revol_any(face);
                    if (result.IsNull()) {
                        auto regions = skf->sketch->contour_faces(nullptr);
                        for (const auto& c : regions) {
                            result = revol_any(c);
                            if (!result.IsNull()) break;
                        }
                    }
                    if (!result.IsNull() && shape::volume(result) < 0.0)
                        result.Reverse();
                    if (!result.IsNull()) {
                        std::string report;
                        TopoDS_Shape healed = interop::heal_shape(result, &report);
                        if (!healed.IsNull() && shape::count(healed).solids >= 1)
                            result = healed;
                        if (shape::volume(result) < 0.0) result.Reverse();
                    }
                    if (result.IsNull()) {
                        const double fa = face.IsNull() ? 0.0 : shape::area(face);
                        Bnd_Box fb;
                        if (!face.IsNull()) BRepBndLib::Add(face, fb);
                        std::ostringstream os;
                        os << "geometry generation failed raw=" << raw_area << " area=" << fa;
                        if (!fb.IsVoid()) {
                            double x0, y0, z0, x1, y1, z1;
                            fb.Get(x0, y0, z0, x1, y1, z1);
                            os << " bbox=[" << x0 << "," << y0 << "," << z0 << " .. "
                               << x1 << "," << y1 << "," << z1 << "]";
                        }
                        os << " axis=(" << p0.X() << "," << p0.Y() << "," << p0.Z()
                           << ")+(" << (p1.X() - p0.X()) << "," << (p1.Y() - p0.Y())
                           << "," << (p1.Z() - p0.Z()) << ")";
                        if (!perr.empty()) os << " " << perr;
                        return fail(os.str());
                    }
                }
                if (result.IsNull())
                    return fail(std::string("geometry generation failed") +
                                (perr.empty() ? "" : (": " + perr)));

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
                    {
                        std::string report;
                        TopoDS_Shape healed = interop::heal_shape(merged, &report);
                        if (!healed.IsNull() && shape::count(healed).solids >= 1)
                            merged = healed;
                    }
                    doc.replace_body_shape(target, merged);
                }
                return true;
            
}
}
