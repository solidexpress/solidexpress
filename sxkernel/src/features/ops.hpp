#pragma once
// Per-type FeatureGraph::apply handlers. Implementation detail of features.cpp —
// not part of the public sxkernel API.

#include <nlohmann/json.hpp>

#include <map>
#include <string>
#include <vector>

#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

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
// Exact sketch wire: lines, trimmed-circle arcs, interpolating splines, and
// (when the sole path entity, or closed=true) full circle/ellipse. Empty when
// the sketch has no usable path geometry. Polyline is the documented fallback.
TopoDS_Wire sketch_exact_wire(const Sketch& sk, bool closed = false);
TopoDS_Wire sketch_spine_wire(const Sketch& sk);
TopoDS_Wire join_exact_wires(const std::vector<TopoDS_Wire>& wires);
TopoDS_Wire interpolate_wire(const std::vector<gp_Pnt>& pts);
nlohmann::json sample_wire_polyline(const TopoDS_Wire& wire, int samples_per_edge = 16);
bool spine_has_circle_radius(const TopoDS_Wire& wire, double radius, double tol = 0.2);
TopoDS_Shape sweep_along_spine(const TopoDS_Shape& face, const TopoDS_Wire& spine,
                               double thin_thickness = 0.0, bool contact = false,
                               bool frenet = true, bool correction = true,
                               const TopoDS_Wire* guide = nullptr);
TopoDS_Shape rib_along_wire(const TopoDS_Wire& spine, double thickness, double height,
                            const gp_Dir& dir, std::string* err = nullptr);
inline constexpr const char* kApproxPathWarning = "approximated path";
inline constexpr const char* kBooleanFuzzWarning = "boolean fuzz ";
inline constexpr double kHonestKeepRatio = 0.999999;  // 99.9999 % of expected

// Fuse/cut with silent fuzz ≤ 1e-6×bbox; larger fuzz/heal is reported.
struct HonestBoolean {
    double fuzz_used = 0.0;
    bool healed = false;
    std::string warning;
    TopoDS_Shape shape;

    static double bbox_diag(const TopoDS_Shape& s);
    static double silent_limit(const TopoDS_Shape& a, const TopoDS_Shape& b);

    static HonestBoolean fuse(const TopoDS_Shape& a, const TopoDS_Shape& b);
    static HonestBoolean cut(const TopoDS_Shape& a, const TopoDS_Shape& b);
};
inline gp_Pnt sketch_uv_to_3d(const SketchPlane& pl, double u, double v) {
    return gp_Pnt(pl.origin[0] + pl.x_dir[0] * u + pl.y_dir[0] * v,
                  pl.origin[1] + pl.x_dir[1] * u + pl.y_dir[1] * v,
                  pl.origin[2] + pl.x_dir[2] * u + pl.y_dir[2] * v);
}
nlohmann::json join_polylines(nlohmann::json a, const nlohmann::json& b);
nlohmann::json chain_points(std::vector<gp_Pnt> pts);
nlohmann::json densify_catmull(const std::vector<gp_Pnt>& ctrl, int samples_per_seg = 8);
nlohmann::json pnt_to_json(const gp_Pnt& p);
TopoDS_Wire make_polyline_wire(const nlohmann::json& path);
TopoDS_Shape sweep_along_polyline(const TopoDS_Shape& face, const nlohmann::json& path,
                                  const nlohmann::json* guide_path = nullptr,
                                  double thin_thickness = 0.0, bool contact = false);
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

// Godot JSON.stringify turns ints into floats (0 → 0.0). Accept both.
std::vector<int> selected_contour_indices(const nlohmann::json& params);

gp_Pnt pnt_from(const nlohmann::json& a);
gp_Dir dir_from(const nlohmann::json& a);
void put_body(Document& doc, const EntityId& id, const TopoDS_Shape& shape,
              const std::string& name);
void ensure_pattern_slots(Feature& f, int count, Document& doc);

bool planar_face_normal(const TopoDS_Face& face, gp_Dir& n);
bool edge_midpoint_sample(const TopoDS_Edge& edge, gp_Pnt& point, gp_Vec& unit_tangent);
std::string format_fixed(double v, int decimals);

}  // namespace sx::feature_ops
