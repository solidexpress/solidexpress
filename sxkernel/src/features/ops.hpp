#pragma once
// Per-type FeatureGraph::apply handlers. Implementation detail of features.cpp —
// not part of the public sxkernel API.

#include <nlohmann/json.hpp>

#include <map>
#include <string>
#include <vector>

#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/entity.hpp"
#include "sx/features.hpp"
#include "sx/ids.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

namespace sx::feature_ops {

struct ApplyCtx {
    FeatureGraph& graph;
    Document& doc;
    Feature& feature;
    const nlohmann::json& params;  // already resolve_params'd
    const std::map<std::string, double>& env;
    std::string* err;

    EntityId find_feature_body(const std::string& key) const {
        if (!params.contains(key)) return {};
        const Feature* ref =
            graph.feature(EntityId::from_string(params[key].get<std::string>()));
        return ref ? ref->output_body : EntityId{};
    }

    // True when the referenced feature is missing or suppressed — modifying
    // features should no-op rather than fail the whole regenerate.
    bool target_inactive(const std::string& key) const {
        if (!params.contains(key)) return true;
        const Feature* ref =
            graph.feature(EntityId::from_string(params[key].get<std::string>()));
        return ref == nullptr || ref->suppressed;
    }

    bool fail(const std::string& msg) const {
        if (err) *err = feature.name + ": " + msg;
        return false;
    }
};

bool apply_fillet_chamfer(ApplyCtx& ctx);
bool apply_shell(ApplyCtx& ctx);
bool apply_offset(ApplyCtx& ctx);
bool apply_push_pull(ApplyCtx& ctx);
bool apply_draft(ApplyCtx& ctx);
bool apply_mirror(ApplyCtx& ctx);
bool apply_linear_pattern(ApplyCtx& ctx);
bool apply_circular_pattern(ApplyCtx& ctx);
bool apply_boolean(ApplyCtx& ctx);
bool apply_primitive(ApplyCtx& ctx);
bool apply_sketch(ApplyCtx& ctx);
bool apply_extrude_revolve(ApplyCtx& ctx);
bool apply_hole(ApplyCtx& ctx);
bool apply_path(ApplyCtx& ctx);
bool apply_sweep(ApplyCtx& ctx);
bool apply_loft(ApplyCtx& ctx);
bool apply_helix_sweep(ApplyCtx& ctx);
bool apply_thread(ApplyCtx& ctx);
bool apply_import(ApplyCtx& ctx);
bool apply_direct_edit(ApplyCtx& ctx);
bool apply_replace_face(ApplyCtx& ctx);
bool apply_rib(ApplyCtx& ctx);
bool apply_thicken(ApplyCtx& ctx);
bool apply_wrap(ApplyCtx& ctx);
bool apply_flange(ApplyCtx& ctx);
bool apply_knit(ApplyCtx& ctx);
bool apply_frame_member(ApplyCtx& ctx);
bool apply_in_context(ApplyCtx& ctx);
bool apply_convert_sheet(ApplyCtx& ctx);
bool apply_user_feature(ApplyCtx& ctx);
bool apply_datum(ApplyCtx& ctx);
bool apply_noop(ApplyCtx& ctx);

inline constexpr double k_hole_nudge = 1.0;
inline constexpr double k_hole_through = 1e6;

shape::Placement placement_from(const nlohmann::json& p);

TopoDS_Shape build_primitive_feature(const nlohmann::json& p,
                                     const std::map<std::string, double>& env);
TopoDS_Shape build_feature_hole_tool(const gp_Pnt& position, const gp_Dir& direction,
                                     double diameter, double depth, const std::string& type,
                                     double cb_diameter, double cb_depth, double cs_diameter,
                                     double cs_angle_deg);
nlohmann::json simplify_path_polyline(const nlohmann::json& path);
nlohmann::json simplify_path_rdp(const nlohmann::json& path, double eps);
nlohmann::json simplify_path_for_sweep(const nlohmann::json& path);
nlohmann::json sketch_ordered_polyline(const Sketch& sk);
nlohmann::json join_polylines(nlohmann::json a, const nlohmann::json& b);
nlohmann::json chain_points(std::vector<gp_Pnt> pts);
nlohmann::json densify_catmull(const std::vector<gp_Pnt>& ctrl, int samples_per_seg = 8);
nlohmann::json pnt_to_json(const gp_Pnt& p);
TopoDS_Wire make_polyline_wire(const nlohmann::json& path);
TopoDS_Shape sweep_along_polyline(const TopoDS_Shape& face, const nlohmann::json& path,
                                  const nlohmann::json* guide_path = nullptr,
                                  double thin_thickness = 0.0);
TopoDS_Shape helix_sweep_solid(const gp_Ax2& axis, double helix_r, double pitch,
                               double turns, bool left_handed, double profile_r);
TopoDS_Shape thread_cutter_solid(const gp_Ax2& axis, double major_radius, double pitch,
                                 double turns, double depth, double angle_deg);
std::vector<gp_Pnt> sketch_line_points(const Sketch& sk);
std::string thin_wall_on_error(double mm);
bool sketch_closed_contour(const Sketch& sk);
void rebind_sketch_support(FeatureGraph& graph, Document& doc, Feature& f);

bool resolve_topo_shape(Document& doc, const Body& body, EntityKind kind,
                        const nlohmann::json& ref, TopoDS_Shape& out, std::string* why);

gp_Pnt pnt_from(const nlohmann::json& a);
gp_Dir dir_from(const nlohmann::json& a);
void put_body(Document& doc, const EntityId& id, const TopoDS_Shape& shape,
              const std::string& name);
void ensure_pattern_slots(Feature& f, int count, Document& doc);

}  // namespace sx::feature_ops
