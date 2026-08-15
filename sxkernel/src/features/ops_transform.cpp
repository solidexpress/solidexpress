#include "ops.hpp"

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <Bnd_Box.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <algorithm>
#include <cmath>
#include <map>
#include <string>
#include <vector>

#include "sx/shape_utils.hpp"
#include "sx/variables.hpp"

namespace sx::feature_ops {
namespace {

// Rebuild Extrude/Revolve solid tool from a source feature's resolved params.
bool build_pad_tool(ApplyCtx& ctx, const Feature& src, const nlohmann::json& params,
                    const Body* extent_hint, TopoDS_Shape& out) {
    if (src.type != FeatureType::Extrude && src.type != FeatureType::Revolve)
        return false;
    if (!params.contains("sketch") || !params["sketch"].is_string())
        return ctx.fail("source feature missing sketch");
    EntityId sketch_fid = EntityId::from_string(params.at("sketch").get<std::string>());
    const Feature* skf = ctx.graph.feature(sketch_fid);
    if (!skf || !skf->sketch) return ctx.fail("missing sketch feature");

    std::string perr;
    TopoDS_Shape face;
    double thin_thickness = num_param(params, "thin_thickness", 0.0, ctx.env);
    bool flip_side = params.value("flip_side", false);
    if (thin_thickness > 0.0) {
        std::string thin_type = params.value("thin_type", "one_side");
        bool thin_midplane = (thin_type == "midplane");
        face = skf->sketch->thin_profile_face(thin_thickness, thin_midplane, flip_side, &perr);
    } else {
        std::vector<int> contour_idxs;
        if (params.contains("selected_contours") && params["selected_contours"].is_array()) {
            for (const auto& v : params["selected_contours"]) {
                if (v.is_number_integer()) contour_idxs.push_back(v.get<int>());
            }
        }
        if (!contour_idxs.empty()) {
            face = skf->sketch->profile_face_selected(contour_idxs, &perr);
        } else {
            face = skf->sketch->profile_face(&perr);
        }
        std::string op_early = params.value("op", "new");
        if (face.IsNull() && (op_early == "cut" || op_early == "fuse")) {
            double pad = 1.0e5;
            if (extent_hint && !extent_hint->shape.IsNull()) {
                Bnd_Box box;
                BRepBndLib::Add(extent_hint->shape, box);
                if (!box.IsVoid()) {
                    double xmin, ymin, zmin, xmax, ymax, zmax;
                    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                    double diag =
                        std::hypot(xmax - xmin, std::hypot(ymax - ymin, zmax - zmin));
                    pad = std::max(diag * 4.0, 100.0);
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
    if (face.IsNull()) return ctx.fail("profile: " + perr);

    if (src.type == FeatureType::Extrude) {
        auto n = skf->sketch->plane().normal();
        gp_Vec dir(n[0], n[1], n[2]);
        dir.Normalize();
        double dist = num_param(params, "distance", 10.0, ctx.env);
        std::string end = params.value("end", "blind");
        bool midplane = params.value("symmetric", false) || end == "midplane";
        std::string op = params.value("op", "new");
        if (end == "through_all") {
            double sign = dist < 0.0 ? -1.0 : 1.0;
            double extent = 1.0e6;
            if (op != "new" && extent_hint && !extent_hint->shape.IsNull()) {
                Bnd_Box box;
                BRepBndLib::Add(extent_hint->shape, box);
                if (!box.IsVoid()) {
                    double xmin, ymin, zmin, xmax, ymax, zmax;
                    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                    gp_Pnt c((xmin + xmax) * 0.5, (ymin + ymax) * 0.5, (zmin + zmax) * 0.5);
                    gp_Pnt corners[8] = {
                        {xmin, ymin, zmin}, {xmax, ymin, zmin}, {xmin, ymax, zmin},
                        {xmax, ymax, zmin}, {xmin, ymin, zmax}, {xmax, ymin, zmax},
                        {xmin, ymax, zmax}, {xmax, ymax, zmax},
                    };
                    double max_along = 0.0;
                    for (const auto& p : corners)
                        max_along = std::max(max_along, std::abs(gp_Vec(c, p).Dot(dir)));
                    extent = std::max(max_along * 2.0 + 10.0, std::abs(dist));
                }
            }
            dist = sign * extent;
        }
        TopoDS_Shape profile = face;
        if (midplane) {
            gp_Trsf t;
            t.SetTranslation(dir * (-dist / 2.0));
            profile = BRepBuilderAPI_Transform(face, t, true).Shape();
        }
        out = BRepPrimAPI_MakePrism(profile, dir * dist).Shape();
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
        out = BRepPrimAPI_MakeRevol(face, gp_Ax1(p0, gp_Dir(gp_Vec(p0, p1))),
                                    num_param(params, "angle", 6.283185307179586, ctx.env))
                  .Shape();
    }
    if (out.IsNull()) return ctx.fail("geometry generation failed");
    return true;
}

EntityId resolve_feature_body(ApplyCtx& ctx, const Feature& ref) {
    if (!ref.output_body.is_null()) return ref.output_body;
    // Modifying features (cut Extrude, Fillet, …) operate on their target body.
    if (ref.params.contains("target") && ref.params["target"].is_string()) {
        const Feature* t =
            ctx.graph.feature(EntityId::from_string(ref.params["target"].get<std::string>()));
        return t ? t->output_body : EntityId{};
    }
    return {};
}

bool apply_feature_mirror(ApplyCtx& ctx) {
    const auto& ids = ctx.params.at("source_feature_ids");
    if (!ids.is_array() || ids.empty()) return ctx.fail("source_feature_ids empty");

    // Timeline order (not the raw array order).
    std::map<std::string, int> timeline_index;
    for (int i = 0; i < static_cast<int>(ctx.graph.timeline().size()); ++i)
        timeline_index[ctx.graph.timeline()[static_cast<size_t>(i)].id.str()] = i;

    struct SrcRef {
        int index;
        EntityId id;
    };
    std::vector<SrcRef> ordered;
    for (const auto& jid : ids) {
        if (!jid.is_string()) return ctx.fail("source_feature_ids entries must be strings");
        EntityId id = EntityId::from_string(jid.get<std::string>());
        auto it = timeline_index.find(id.str());
        if (it == timeline_index.end()) return ctx.fail("unknown source feature " + id.str());
        ordered.push_back({it->second, id});
    }
    std::sort(ordered.begin(), ordered.end(),
              [](const SrcRef& a, const SrcRef& b) { return a.index < b.index; });

    gp_Trsf mirror_trsf;
    mirror_trsf.SetMirror(gp_Ax2(pnt_from(ctx.params.at("plane_point")),
                                 dir_from(ctx.params.at("plane_normal"))));

    // Optional explicit target for cut/fuse; otherwise inherit from each source.
    EntityId explicit_target;
    if (ctx.params.contains("target") && ctx.params["target"].is_string()) {
        const Feature* tf =
            ctx.graph.feature(EntityId::from_string(ctx.params["target"].get<std::string>()));
        if (!tf || tf->suppressed) return true;  // inactive target → no-op
        explicit_target = tf->output_body.is_null() ? resolve_feature_body(ctx, *tf) : tf->output_body;
        if (explicit_target.is_null()) return ctx.fail("missing target body");
    }

    size_t new_body_count = 0;
    auto next_new_body_id = [&]() -> EntityId {
        if (new_body_count == 0) {
            if (ctx.feature.output_body.is_null())
                ctx.feature.output_body = EntityId::generate();
            ++new_body_count;
            return ctx.feature.output_body;
        }
        const size_t idx = new_body_count - 1;
        while (ctx.feature.output_bodies.size() <= idx)
            ctx.feature.output_bodies.push_back(EntityId::generate());
        EntityId id = ctx.feature.output_bodies[idx];
        ++new_body_count;
        return id;
    };

    for (const auto& src_ref : ordered) {
        const Feature* src = ctx.graph.feature(src_ref.id);
        if (!src) return ctx.fail("missing source feature");
        if (src->suppressed) continue;

        if (src->type == FeatureType::Fillet || src->type == FeatureType::Chamfer) {
            return ctx.fail("feature mirror of Fillet/Chamfer not supported yet");
        }
        if (src->type != FeatureType::Extrude && src->type != FeatureType::Revolve) {
            return ctx.fail(std::string("feature mirror unsupported type: ") + to_string(src->type));
        }

        nlohmann::json src_params = resolve_params(src->params, ctx.env);
        std::string op = src_params.value("op", "new");

        const Body* extent_hint = nullptr;
        EntityId target_body;
        if (op == "cut" || op == "fuse") {
            target_body = explicit_target;
            if (target_body.is_null()) {
                if (!src_params.contains("target") || !src_params["target"].is_string())
                    return ctx.fail("cut/fuse source missing target");
                const Feature* tf = ctx.graph.feature(
                    EntityId::from_string(src_params["target"].get<std::string>()));
                if (!tf || tf->suppressed) continue;
                target_body =
                    tf->output_body.is_null() ? resolve_feature_body(ctx, *tf) : tf->output_body;
            }
            if (target_body.is_null()) return ctx.fail("missing target body");
            extent_hint = ctx.doc.body(target_body);
            if (!extent_hint) return ctx.fail("missing target body");
        }

        TopoDS_Shape tool;
        if (!build_pad_tool(ctx, *src, src_params, extent_hint, tool)) return false;
        TopoDS_Shape mirrored =
            BRepBuilderAPI_Transform(tool, mirror_trsf, /*copy=*/true).Shape();
        if (mirrored.IsNull() || !shape::is_valid(mirrored))
            return ctx.fail("mirror of tool failed");

        if (op == "new") {
            EntityId bid = next_new_body_id();
            put_body(ctx.doc, bid, mirrored, "Mirror of " + src->name);
        } else if (op == "cut" || op == "fuse") {
            const Body* tb = ctx.doc.body(target_body);
            if (!tb) return ctx.fail("missing target body");
            TopoDS_Shape merged =
                (op == "cut")
                    ? TopoDS_Shape(BRepAlgoAPI_Cut(tb->shape, mirrored).Shape())
                    : TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, mirrored).Shape());
            if (merged.IsNull() || !shape::is_valid(merged))
                return ctx.fail("mirrored boolean failed");
            ctx.doc.replace_body_shape(target_body, merged);
        } else {
            return ctx.fail("unsupported extrude op: " + op);
        }
    }
    return true;
}

}  // namespace

bool apply_mirror(ApplyCtx& ctx) {
    if (ctx.params.contains("source_feature_ids") &&
        ctx.params["source_feature_ids"].is_array() &&
        !ctx.params["source_feature_ids"].empty()) {
        return apply_feature_mirror(ctx);
    }

    // Body mode: mirror entire target body into feature.output_body.
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
    // Count may arrive as int (C++ binding) or float (PropertyPanel JSON).
    int count = static_cast<int>(std::lround(num_param(ctx.params, "count", 0.0, ctx.env)));
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
    int count = static_cast<int>(std::lround(num_param(ctx.params, "count", 0.0, ctx.env)));
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
