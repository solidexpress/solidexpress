#include "sx/features.hpp"

#include "features/ops.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <gp_Pln.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <TopTools_ListOfShape.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <Bnd_Box.hxx>
#include <BRepBuilderAPI_FindPlane.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include "sx/occt_types.hpp"
#include <TopExp_Explorer.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Lin.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepTools.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopAbs_Orientation.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <algorithm>
#include <cmath>
#include <sstream>
#include <stdexcept>

#include "sx/curves.hpp"
#include "sx/document.hpp"
#include "sx/interop.hpp"
#include "sx/sketch3d.hpp"
#include "sx/xref.hpp"
#include "sx/log.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sheet_metal.hpp"
#include "sx/sketch_json.hpp"
#include "sx/surface_ops.hpp"
#include "sx/solver.hpp"

using nlohmann::json;

namespace sx {

namespace {

bool always_body(const Feature&) { return true; }
bool never_body(const Feature&) { return false; }
bool op_is_new(const Feature& f) { return f.params.value("op", "new") == "new"; }
bool mirror_body_mode(const Feature& f) {
    // Body-mode Mirror creates a mirrored body; feature-mode Mirror
    // (source_feature_ids) modifies its target in place (cut/fuse).
    return !f.params.contains("source_feature_ids");
}
bool no_target(const Feature& f) { return !f.params.contains("target"); }
bool user_no_target(const Feature& f) {
    return !f.params.contains("target") || f.params.value("target", "").empty();
}

}  // namespace

const FeatureTypeInfo kFeatureTypes[] = {
    {FeatureType::Primitive, "primitive", always_body},
    {FeatureType::Sketch, "sketch", never_body},
    {FeatureType::Extrude, "extrude", op_is_new},
    {FeatureType::Revolve, "revolve", op_is_new},
    {FeatureType::Boolean, "boolean", never_body},
    {FeatureType::Fillet, "fillet", never_body},
    {FeatureType::Chamfer, "chamfer", never_body},
    {FeatureType::Hole, "hole", never_body},
    {FeatureType::Mirror, "mirror", mirror_body_mode},
    {FeatureType::LinearPattern, "linear_pattern", never_body},
    {FeatureType::CircularPattern, "circular_pattern", never_body},
    {FeatureType::Shell, "shell", never_body},
    {FeatureType::Offset, "offset", never_body},
    {FeatureType::Draft, "draft", never_body},
    {FeatureType::Sweep, "sweep", op_is_new},
    {FeatureType::Loft, "loft", always_body},
    {FeatureType::Path, "path", never_body},
    {FeatureType::HelixSweep, "helix_sweep", always_body},
    {FeatureType::Thread, "thread", never_body},
    {FeatureType::ImportStep, "import_step", always_body},
    {FeatureType::ImportStl, "import_stl", always_body},
    {FeatureType::DirectEdit, "direct_edit", never_body},
    {FeatureType::Rib, "rib", never_body},
    {FeatureType::Thicken, "thicken", never_body},
    {FeatureType::Wrap, "wrap", never_body},
    {FeatureType::Flange, "flange", no_target},
    {FeatureType::Knit, "knit", never_body},
    {FeatureType::ReplaceFace, "replace_face", never_body},
    {FeatureType::FrameMember, "frame_member", always_body},
    {FeatureType::InContext, "in_context", always_body},
    {FeatureType::ConvertSheet, "convert_sheet", never_body},
    {FeatureType::UserFeature, "user_feature", user_no_target},
    {FeatureType::Weld, "weld", never_body},
    {FeatureType::Sketch3D, "sketch3d", never_body},
    {FeatureType::Datum, "datum", never_body},
};

static_assert(sizeof(kFeatureTypes) / sizeof(kFeatureTypes[0]) == kFeatureTypeCount);

const char* to_string(FeatureType t) {
    for (const auto& row : kFeatureTypes) {
        if (row.type == t) return row.name;
    }
    return "unknown";
}

FeatureType feature_type_from_string(const std::string& s) {
    for (const auto& row : kFeatureTypes) {
        if (s == row.name) return row.type;
    }
    throw std::invalid_argument("unknown feature type: " + s);
}

static bool creates_body(const Feature& f) {
    for (const auto& row : kFeatureTypes) {
        if (row.type == f.type) return row.creates_body(f);
    }
    return false;
}

EntityId FeatureGraph::add(Feature f) {
    if (f.id.is_null()) f.id = EntityId::generate();
    if (f.name.empty())
        f.name = std::string(to_string(f.type)) + " " + std::to_string(timeline_.size() + 1);
    if (creates_body(f) && f.output_body.is_null()) f.output_body = EntityId::generate();
    EntityId id = f.id;
    timeline_.push_back(std::move(f));
    return id;
}

bool FeatureGraph::remove(const EntityId& id) {
    if (has_dependents(id)) return false;
    for (auto it = timeline_.begin(); it != timeline_.end(); ++it) {
        if (it->id == id) {
            timeline_.erase(it);
            return true;
        }
    }
    return false;
}

bool FeatureGraph::set_suppressed(const EntityId& id, bool suppressed) {
    Feature* f = feature(id);
    if (!f) return false;
    f->suppressed = suppressed;
    return true;
}

bool FeatureGraph::set_params(const EntityId& id, json params) {
    Feature* f = feature(id);
    if (!f) return false;
    f->params = std::move(params);
    return true;
}

namespace {

// Collect feature ids referenced by params keys
// sketch/target/tool/path_feature and arrays sketches/guides/source_feature_ids.
void collect_deps(const Feature& f, std::vector<std::string>& out) {
    for (const char* key : {"sketch", "target", "tool", "path_feature"}) {
        if (f.params.contains(key) && f.params[key].is_string())
            out.push_back(f.params[key].get<std::string>());
    }
    for (const char* arr_key : {"sketches", "guides", "source_feature_ids"}) {
        if (f.params.contains(arr_key) && f.params[arr_key].is_array()) {
            for (const auto& s : f.params[arr_key]) {
                if (s.is_string()) out.push_back(s.get<std::string>());
            }
        }
    }
}

// True when every referenced dependency appears earlier in `order`.
bool deps_ordered(const std::vector<Feature>& order) {
    std::map<std::string, int> index;
    for (int i = 0; i < static_cast<int>(order.size()); ++i) index[order[i].id.str()] = i;
    for (int i = 0; i < static_cast<int>(order.size()); ++i) {
        std::vector<std::string> deps;
        collect_deps(order[i], deps);
        for (const auto& d : deps) {
            auto it = index.find(d);
            if (it == index.end()) continue;  // dangling ref: not a move concern
            if (it->second >= i) return false;
        }
    }
    return true;
}

}  // namespace

bool FeatureGraph::move(const EntityId& id, int new_index) {
    if (new_index < 0 || new_index >= static_cast<int>(timeline_.size())) return false;
    int old_index = -1;
    for (int i = 0; i < static_cast<int>(timeline_.size()); ++i) {
        if (timeline_[i].id == id) {
            old_index = i;
            break;
        }
    }
    if (old_index < 0) return false;
    if (old_index == new_index) return true;

    std::vector<Feature> trial = timeline_;
    Feature moved = std::move(trial[static_cast<size_t>(old_index)]);
    trial.erase(trial.begin() + old_index);
    trial.insert(trial.begin() + new_index, std::move(moved));
    if (!deps_ordered(trial)) return false;
    timeline_ = std::move(trial);
    return true;
}

bool FeatureGraph::rename(const EntityId& id, const std::string& name) {
    Feature* f = feature(id);
    if (!f) return false;
    f->name = name;
    return true;
}

Feature* FeatureGraph::feature(const EntityId& id) {
    for (auto& f : timeline_)
        if (f.id == id) return &f;
    return nullptr;
}

const Feature* FeatureGraph::feature(const EntityId& id) const {
    for (const auto& f : timeline_)
        if (f.id == id) return &f;
    return nullptr;
}

bool FeatureGraph::set_rollback(int index) {
    if (index < -1 || index > static_cast<int>(timeline_.size())) return false;
    // Clamp "roll to end" spellings (size or -1) to the -1 sentinel.
    rollback_index_ = (index >= static_cast<int>(timeline_.size())) ? -1 : index;
    return true;
}

bool FeatureGraph::has_dependents(const EntityId& id) const {
    std::string needle = id.str();
    bool found_self = false;
    for (const auto& f : timeline_) {
        if (f.id == id) {
            found_self = true;
            continue;
        }
        if (!found_self) continue;
        for (const char* key : {"sketch", "target", "tool", "path_feature"}) {
            if (f.params.contains(key) && f.params[key].is_string() &&
                f.params[key].get<std::string>() == needle)
                return true;
        }
        for (const char* arr_key : {"sketches", "guides", "source_feature_ids"}) {
            if (f.params.contains(arr_key) && f.params[arr_key].is_array()) {
                for (const auto& s : f.params[arr_key]) {
                    if (s.is_string() && s.get<std::string>() == needle) return true;
                }
            }
        }
    }
    return false;
}

// --- regeneration ---

namespace feature_ops {
shape::Placement placement_from(const json& p) {
    shape::Placement pl;
    if (p.contains("origin") && p["origin"].is_array() && p["origin"].size() == 3)
        for (int i = 0; i < 3; ++i) pl.origin[i] = p["origin"][i].get<double>();
    // Optional axis frame — used when a primitive has been rotated in-place.
    if (p.contains("z_dir") && p["z_dir"].is_array() && p["z_dir"].size() == 3)
        for (int i = 0; i < 3; ++i) pl.z_dir[i] = p["z_dir"][i].get<double>();
    if (p.contains("x_dir") && p["x_dir"].is_array() && p["x_dir"].size() == 3)
        for (int i = 0; i < 3; ++i) pl.x_dir[i] = p["x_dir"][i].get<double>();
    return pl;
}

TopoDS_Shape build_primitive_feature(const json& p,
                                      const std::map<std::string, double>& env) {
    std::string kind = p.value("kind", "box");
    double a = num_param(p, "a", 10.0, env), b = num_param(p, "b", 10.0, env),
           c = num_param(p, "c", 10.0, env);
    auto pl = placement_from(p);
    if (kind == "box") return shape::make_box(a, b, c, pl);
    if (kind == "cylinder") return shape::make_cylinder(a, b, pl);
    if (kind == "sphere") return shape::make_sphere(a, pl);
    if (kind == "cone") return shape::make_cone(a, b, c, pl);
    if (kind == "torus") return shape::make_torus(a, b, pl);
    throw std::runtime_error("unknown primitive kind: " + kind);
}

// Minimal duplicate of HoleCommand tool construction (see commands_hole.cpp).
// Owned-file constraint prevents extracting a shared helper from commands_hole.
shape::Placement hole_ax_placement(const gp_Pnt& origin, const gp_Dir& z) {
    shape::Placement p;
    p.origin = {origin.X(), origin.Y(), origin.Z()};
    p.z_dir = {z.X(), z.Y(), z.Z()};
    const gp_Dir ref = (std::abs(z.Dot(gp_Dir(0, 0, 1))) < 0.9) ? gp_Dir(0, 0, 1)
                                                                  : gp_Dir(1, 0, 0);
    const gp_Dir x = z.Crossed(ref);
    p.x_dir = {x.X(), x.Y(), x.Z()};
    return p;
}

TopoDS_Shape build_feature_hole_tool(const gp_Pnt& position, const gp_Dir& direction,
                                     double diameter, double depth, const std::string& type,
                                     double cb_diameter, double cb_depth, double cs_diameter,
                                     double cs_angle_deg) {
    const double radius = diameter * 0.5;
    if (radius <= 0.0 || depth <= 0.0) return {};

    const gp_Pnt origin = position.Translated(gp_Vec(direction) * (-k_hole_nudge));
    const double cyl_h = depth + k_hole_nudge;
    const auto place = hole_ax_placement(origin, direction);

    if (type == "hex") {
        // Across-flats = diameter. Circumradius R = AF / √3 so flats sit on AF.
        const double af = diameter;
        const double R = af / std::sqrt(3.0);
        gp_Dir z(place.z_dir[0], place.z_dir[1], place.z_dir[2]);
        gp_Dir x(place.x_dir[0], place.x_dir[1], place.x_dir[2]);
        if (x.XYZ().Modulus() < 1e-12) return {};
        gp_Dir y = z.Crossed(x);
        gp_Pnt o(place.origin[0], place.origin[1], place.origin[2]);
        BRepBuilderAPI_MakePolygon poly;
        for (int i = 0; i < 6; ++i) {
            const double th = (30.0 + 60.0 * i) * M_PI / 180.0;
            gp_Pnt p = o.Translated(gp_Vec(x) * (R * std::cos(th)) +
                                    gp_Vec(y) * (R * std::sin(th)));
            poly.Add(p);
        }
        poly.Close();
        if (!poly.IsDone()) return {};
        BRepBuilderAPI_MakeFace face(poly.Wire());
        if (!face.IsDone()) return {};
        BRepPrimAPI_MakePrism prism(face.Face(), gp_Vec(z) * cyl_h);
        if (!prism.IsDone()) return {};
        return prism.Shape();
    }

    TopoDS_Shape tool = shape::make_cylinder(radius, cyl_h, place);
    if (tool.IsNull()) return {};

    if (type == "simple") return tool;

    if (type == "counterbore") {
        const double cb_r = cb_diameter * 0.5;
        if (cb_r <= radius || cb_depth <= 0.0) return {};
        TopoDS_Shape cb = shape::make_cylinder(cb_r, cb_depth + k_hole_nudge, place);
        BRepAlgoAPI_Fuse fuse(tool, cb);
        if (!fuse.IsDone()) return {};
        return fuse.Shape();
    }

    if (type == "countersink") {
        const double cs_r = cs_diameter * 0.5;
        const double angle = cs_angle_deg * M_PI / 180.0;
        if (cs_r <= radius || angle <= 0.0 || angle >= M_PI) return {};
        const double half = angle * 0.5;
        const double tan_half = std::tan(half);
        if (tan_half <= 1e-12) return {};
        const double cs_h = (cs_r - radius) / tan_half;
        if (cs_h <= 0.0) return {};
        const double cone_h = cs_h + k_hole_nudge;
        const double r2 = std::max(0.0, cs_r - cone_h * tan_half);
        TopoDS_Shape cone = shape::make_cone(cs_r, r2, cone_h, place);
        BRepAlgoAPI_Fuse fuse(tool, cone);
        if (!fuse.IsDone()) return {};
        return fuse.Shape();
    }
    return {};
}

TopoDS_Wire make_polyline_wire(const json& path) {
    if (!path.is_array() || path.size() < 2)
        throw std::runtime_error("path needs at least two points");
    BRepBuilderAPI_MakeWire mk;
    for (size_t i = 1; i < path.size(); ++i) {
        gp_Pnt a = pnt_from(path[i - 1]);
        gp_Pnt b = pnt_from(path[i]);
        if (a.Distance(b) < 1e-12) throw std::runtime_error("zero-length path segment");
        BRepBuilderAPI_MakeEdge edge(a, b);
        if (!edge.IsDone()) throw std::runtime_error("failed to build path edge");
        mk.Add(edge.Edge());
    }
    if (!mk.IsDone()) throw std::runtime_error("failed to build path wire");
    return mk.Wire();
}

// Drop intermediate points that are collinear (safe for dense splines + 3D corner sweeps).
json simplify_path_polyline(const json& path) {
    if (!path.is_array() || path.size() < 3) return path;
    const double dist_eps = 1e-12;
    const double ang_eps = 1e-6;
    json out = json::array();
    out.push_back(path[0]);
    for (size_t i = 1; i + 1 < path.size(); ++i) {
        gp_Pnt a = pnt_from(out.back());
        gp_Pnt b = pnt_from(path[i]);
        gp_Pnt c = pnt_from(path[i + 1]);
        gp_Vec v1(a, b);
        gp_Vec v2(b, c);
        if (v1.SquareMagnitude() < dist_eps * dist_eps) continue;
        if (v2.SquareMagnitude() < dist_eps * dist_eps) continue;
        v1.Normalize();
        v2.Normalize();
        if (v1.IsParallel(v2, ang_eps)) continue;
        out.push_back(path[i]);
    }
    out.push_back(path[path.size() - 1]);
    return out;
}

static double point_seg_dist(const gp_Pnt& p, const gp_Pnt& a, const gp_Pnt& b) {
    gp_Vec ab(a, b);
    double len2 = ab.SquareMagnitude();
    if (len2 < 1e-24) return p.Distance(a);
    double t = gp_Vec(a, p).Dot(ab) / len2;
    t = std::max(0.0, std::min(1.0, t));
    gp_Pnt proj = a.Translated(ab * t);
    return p.Distance(proj);
}

static void rdp_rec(const json& path, size_t i0, size_t i1, double eps, std::vector<bool>& keep) {
    if (i1 <= i0 + 1) return;
    gp_Pnt a = pnt_from(path[i0]);
    gp_Pnt b = pnt_from(path[i1]);
    double max_d = 0.0;
    size_t max_i = i0;
    for (size_t i = i0 + 1; i < i1; ++i) {
        double d = point_seg_dist(pnt_from(path[i]), a, b);
        if (d > max_d) {
            max_d = d;
            max_i = i;
        }
    }
    if (max_d > eps) {
        rdp_rec(path, i0, max_i, eps, keep);
        keep[max_i] = true;
        rdp_rec(path, max_i, i1, eps, keep);
    }
}

json simplify_path_rdp(const json& path, double eps) {
    if (!path.is_array() || path.size() < 3 || eps <= 0.0) return path;
    std::vector<bool> keep(path.size(), false);
    keep[0] = true;
    keep[path.size() - 1] = true;
    rdp_rec(path, 0, path.size() - 1, eps, keep);
    json out = json::array();
    for (size_t i = 0; i < path.size(); ++i)
        if (keep[i]) out.push_back(path[i]);
    return out;
}

json simplify_path_for_sweep(const json& path) {
    json p = simplify_path_polyline(path);
    if (p.is_array() && p.size() > 12) {
        double eps = 0.05;
        json rdp = simplify_path_rdp(p, eps);
        if (rdp.size() >= 2) p = std::move(rdp);
    }
    return p;
}

TopoDS_Wire profile_outer_wire(const TopoDS_Shape& face);
TopoDS_Shape pipe_largest_transition(const TopoDS_Wire& spine, const TopoDS_Wire& profile_wire,
                                     double thin_thickness, bool contact, bool correction,
                                     const TopoDS_Wire* guide, const bool* frenet);

bool polyline_turns_are_smooth(const std::vector<gp_Pnt>& pts) {
    if (pts.size() < 3) return false;
    const double sharp = 25.0 * M_PI / 180.0;
    for (size_t i = 1; i + 1 < pts.size(); ++i) {
        gp_Vec a(pts[i - 1], pts[i]);
        gp_Vec b(pts[i], pts[i + 1]);
        if (a.SquareMagnitude() < 1e-24 || b.SquareMagnitude() < 1e-24) continue;
        if (a.Angle(b) > sharp) return false;
    }
    return true;
}

TopoDS_Shape sweep_along_polyline(const TopoDS_Shape& face, const json& path,
                                  const json* guide_path,
                                  double thin_thickness, bool contact) {
    json simplified = simplify_path_for_sweep(path);
    std::vector<gp_Pnt> pts;
    pts.reserve(simplified.size());
    for (const auto& j : simplified) pts.push_back(pnt_from(j));
    // A densified Catmull/fit-spline is one curve. Mitring its chords on a
    // 3D polyline SIGSEGVs; Transformed on those chords only paints a ribbon.
    // Sharp corners stay a polyline (miter skipped by spine_allows_miter).
    TopoDS_Wire spine;
    if (polyline_turns_are_smooth(pts)) spine = interpolate_wire(pts);
    if (spine.IsNull()) spine = make_polyline_wire(simplified);
    TopoDS_Wire profile_wire = profile_outer_wire(face);
    if (profile_wire.IsNull()) throw std::runtime_error("profile has no outer wire");

    // Discrete trihedron: MakePipe often yields an empty/invalid solid when the
    // profile plane contains the spine tangent (ground sketch along an in-plane
    // rail). Transition pick is shared with sweep_along_spine so a densified
    // 3D corner does not RightCorner-SIGSEGV.
    TopoDS_Wire aux;
    const TopoDS_Wire* guide = nullptr;
    if (guide_path && guide_path->is_array() && guide_path->size() >= 2) {
        json gsimp = simplify_path_for_sweep(*guide_path);
        aux = make_polyline_wire(gsimp);
        guide = &aux;
    }
    return pipe_largest_transition(spine, profile_wire, thin_thickness, contact,
                                   /*correction=*/true, guide, /*frenet=*/nullptr);
}

// Pipe a circular profile along a helix spine (spring / thread groundwork).
// Profile placement is analytic (not sampled from the wire):
//   start = axis.Location + radius · XDir  (cylinder UV=(0,0))
//   tangent at θ=0: s·radius·YDir + (pitch/(2π))·ZDir, s=±1 for handedness
// PipeShell Frenet + withCorrection matches the proven curves test config.
TopoDS_Shape helix_sweep_solid(const gp_Ax2& axis, double helix_r, double pitch,
                               double turns, bool left_handed, double profile_r) {
    if (helix_r <= 0.0) throw std::runtime_error("helix radius must be positive");
    if (turns <= 0.0) throw std::runtime_error("helix turns must be positive");
    if (profile_r <= 0.0) throw std::runtime_error("profile_radius must be positive");

    TopoDS_Wire spine = curves::helix(axis, helix_r, pitch, turns, left_handed);

    const gp_Pnt start = axis.Location().Translated(gp_Vec(axis.XDirection()) * helix_r);
    const double sense = left_handed ? -1.0 : 1.0;
    gp_Vec tangent = gp_Vec(axis.YDirection()) * (sense * helix_r) +
                     gp_Vec(axis.Direction()) * (pitch / (2.0 * M_PI));
    if (tangent.Magnitude() < 1e-15) throw std::runtime_error("degenerate helix tangent");

    gp_Circ circ(gp_Ax2(start, gp_Dir(tangent)), profile_r);
    TopoDS_Wire profile =
        BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(circ).Edge()).Wire();

    BRepOffsetAPI_MakePipeShell shell(spine);
    shell.SetMode();  // Frenet
    shell.Add(profile, /*withContact=*/false,
              /*withCorrection=*/true);
    shell.Build();
    if (!shell.IsDone()) throw std::runtime_error("MakePipeShell failed");
    if (!shell.MakeSolid()) throw std::runtime_error("MakePipeShell could not make solid");
    return shell.Shape();
}

// Triangular thread cutter: isosceles profile in the radial–axial plane
// (apex inward), swept along a helix at major_radius + 0.1·depth clearance.
// One turn at a time — a single multi-turn PipeShell self-intersects and
// BRepGProp/boolean then ignore the extra length.
TopoDS_Shape thread_cutter_solid(const gp_Ax2& axis, double major_radius, double pitch,
                                 double turns, double depth, double profile_angle_deg) {
    if (major_radius <= 0.0) throw std::runtime_error("major_radius must be positive");
    if (pitch <= 0.0) throw std::runtime_error("pitch must be positive");
    if (turns <= 0.0) throw std::runtime_error("turns must be positive");
    if (depth <= 0.0) throw std::runtime_error("depth must be positive");
    if (depth >= major_radius) throw std::runtime_error("depth must be less than major_radius");
    if (profile_angle_deg <= 0.0 || profile_angle_deg >= 180.0)
        throw std::runtime_error("profile_angle_deg must be in (0, 180)");

    const double clearance = 0.1 * depth;
    const double helix_r = major_radius + clearance;
    const double height = depth + clearance;
    const double half_apex = profile_angle_deg * M_PI / 360.0;  // α/2 in radians
    const double half_base = height * std::tan(half_apex);

    const gp_Vec radial(axis.XDirection());
    const gp_Vec axial(axis.Direction());

    auto segment = [&](double z0, double nturns) -> TopoDS_Shape {
        const gp_Pnt o = axis.Location().Translated(axial * z0);
        gp_Ax2 ax(o, axis.Direction(), axis.XDirection());
        const gp_Pnt apex = o.Translated(radial * (major_radius - depth));
        const gp_Pnt base_center = o.Translated(radial * helix_r);
        const gp_Pnt base1 = base_center.Translated(axial * half_base);
        const gp_Pnt base2 = base_center.Translated(axial * (-half_base));
        BRepBuilderAPI_MakeWire profile_mk;
        BRepBuilderAPI_MakeEdge e1(apex, base1);
        BRepBuilderAPI_MakeEdge e2(base1, base2);
        BRepBuilderAPI_MakeEdge e3(base2, apex);
        if (!e1.IsDone() || !e2.IsDone() || !e3.IsDone())
            throw std::runtime_error("thread profile edges failed");
        profile_mk.Add(e1.Edge());
        profile_mk.Add(e2.Edge());
        profile_mk.Add(e3.Edge());
        if (!profile_mk.IsDone()) throw std::runtime_error("thread profile wire failed");
        TopoDS_Wire spine = curves::helix(ax, helix_r, pitch, nturns, /*left_handed=*/false);
        BRepOffsetAPI_MakePipeShell shell(spine);
        shell.SetMode(ax.Direction());  // axial plane: ISO 60° basic profile
        shell.Add(profile_mk.Wire(), /*withContact=*/false, /*withCorrection=*/true);
        shell.Build();
        if (!shell.IsDone()) throw std::runtime_error("thread MakePipeShell failed");
        if (!shell.MakeSolid()) throw std::runtime_error("thread MakePipeShell could not make solid");
        return shell.Shape();
    };

    const int nfull = static_cast<int>(std::floor(turns + 1e-12));
    const double frac = turns - static_cast<double>(nfull);
    TopoDS_Shape acc;
    auto join = [&](const TopoDS_Shape& s) {
        if (s.IsNull()) return;
        if (acc.IsNull()) {
            acc = s;
            return;
        }
        BRepAlgoAPI_Fuse fuse(acc, s);
        if (!fuse.IsDone()) throw std::runtime_error("thread segment fuse failed");
        acc = fuse.Shape();
    };
    for (int i = 0; i < nfull; ++i) join(segment(pitch * static_cast<double>(i), 1.0));
    if (frac > 1e-9) join(segment(pitch * static_cast<double>(nfull), frac));
    if (acc.IsNull()) throw std::runtime_error("thread cutter empty");
    return acc;
}

json pnt_to_json(const gp_Pnt& p) { return json::array({p.X(), p.Y(), p.Z()}); }

// Collect 3D line endpoints from a sketch (legacy / fallback).
std::vector<gp_Pnt> sketch_line_points(const Sketch& sk) {
    std::vector<gp_Pnt> pts;
    const auto& pl = sk.plane();
    for (const auto& e : sk.entities()) {
        if (e.construction) continue;
        if (e.type != SketchEntityType::Line || e.params.size() < 4) continue;
        double x1 = sk.param(e.params[0]);
        double y1 = sk.param(e.params[1]);
        double x2 = sk.param(e.params[2]);
        double y2 = sk.param(e.params[3]);
        pts.push_back(sketch_uv_to_3d(pl, x1, y1));
        pts.push_back(sketch_uv_to_3d(pl, x2, y2));
    }
    return pts;
}

// Join open pieces at both ends so a middle arc still grows into one rail.
json chain_polylines(std::vector<json> segs) {
    json path = json::array();
    std::vector<bool> used(segs.size(), false);
    size_t start = 0;
    for (; start < segs.size(); ++start) {
        if (segs[start].is_array() && segs[start].size() >= 2) break;
    }
    if (start >= segs.size()) return path;
    for (const auto& p : segs[start]) path.push_back(p);
    used[start] = true;
    const double join_eps = 1e-3;
    auto attach = [&]() -> bool {
        gp_Pnt head = pnt_from(path.front());
        gp_Pnt tail = pnt_from(path.back());
        double best = join_eps;
        int pick = -1;
        int how = -1;  // 0 tail+a, 1 tail+b, 2 head+a, 3 head+b
        for (size_t i = 0; i < segs.size(); ++i) {
            if (used[i] || !segs[i].is_array() || segs[i].size() < 2) continue;
            gp_Pnt a = pnt_from(segs[i].front());
            gp_Pnt b = pnt_from(segs[i].back());
            const double d[4] = {tail.Distance(a), tail.Distance(b), head.Distance(a),
                                 head.Distance(b)};
            for (int h = 0; h < 4; ++h) {
                if (d[h] < best) {
                    best = d[h];
                    pick = static_cast<int>(i);
                    how = h;
                }
            }
        }
        if (pick < 0) return false;
        const json& s = segs[static_cast<size_t>(pick)];
        json grown = json::array();
        if (how == 0) {
            for (size_t k = 1; k < s.size(); ++k) path.push_back(s[k]);
        } else if (how == 1) {
            for (int k = static_cast<int>(s.size()) - 2; k >= 0; --k) path.push_back(s[k]);
        } else if (how == 2) {
            for (int k = static_cast<int>(s.size()) - 1; k >= 1; --k) grown.push_back(s[k]);
            for (const auto& p : path) grown.push_back(p);
            path = std::move(grown);
        } else {
            for (size_t k = 0; k + 1 < s.size(); ++k) grown.push_back(s[k]);
            for (const auto& p : path) grown.push_back(p);
            path = std::move(grown);
        }
        used[static_cast<size_t>(pick)] = true;
        return true;
    };
    while (attach()) {
    }
    if (path.size() >= 2) {
        gp_Pnt o(0, 0, 0);
        if (pnt_from(path.front()).Distance(o) > pnt_from(path.back()).Distance(o) + join_eps) {
            json rev = json::array();
            for (int k = static_cast<int>(path.size()) - 1; k >= 0; --k) rev.push_back(path[k]);
            path = std::move(rev);
        }
    }
    return path;
}

// Ordered polyline through line/arc/spline entities. Construction is skipped.
json sketch_ordered_polyline(const Sketch& sk) {
    const double eps = 1e-9;
    const auto& pl = sk.plane();
    std::vector<json> segs;
    auto push_line = [&](gp_Pnt a, gp_Pnt b) {
        if (a.Distance(b) < eps) return;
        json s = json::array();
        s.push_back(pnt_to_json(a));
        s.push_back(pnt_to_json(b));
        segs.push_back(std::move(s));
    };
    for (const auto& e : sk.entities()) {
        if (e.construction) continue;
        json piece = json::array();
        auto add = [&](const gp_Pnt& p) {
            if (!piece.empty()) {
                gp_Pnt prev = pnt_from(piece.back());
                if (prev.Distance(p) < eps) return;
            }
            piece.push_back(pnt_to_json(p));
        };
        if (e.type == SketchEntityType::Line && e.params.size() >= 4) {
            gp_Pnt a = sketch_uv_to_3d(pl, sk.param(e.params[0]), sk.param(e.params[1]));
            gp_Pnt b = sketch_uv_to_3d(pl, sk.param(e.params[2]), sk.param(e.params[3]));
            push_line(a, b);
        } else if (e.type == SketchEntityType::Arc && e.params.size() >= 5) {
            const double cx = sk.param(e.params[0]);
            const double cy = sk.param(e.params[1]);
            const double r = sk.param(e.params[2]);
            double a0 = sk.param(e.params[3]);
            double a1 = sk.param(e.params[4]);
            if (r < eps) continue;
            while (a1 <= a0) a1 += 2.0 * M_PI;
            const double span = a1 - a0;
            const int samples = std::max(8, static_cast<int>(std::ceil(span / (M_PI / 12.0))));
            for (int s = 0; s <= samples; ++s) {
                double t = a0 + span * (static_cast<double>(s) / samples);
                add(sketch_uv_to_3d(pl, cx + r * std::cos(t), cy + r * std::sin(t)));
            }
            if (piece.size() >= 2) segs.push_back(std::move(piece));
        } else if (e.type == SketchEntityType::Circle && e.params.size() >= 3) {
            const double cx = sk.param(e.params[0]);
            const double cy = sk.param(e.params[1]);
            const double r = sk.param(e.params[2]);
            if (r < eps) continue;
            const int samples = 32;
            for (int s = 0; s <= samples; ++s) {
                double t = 2.0 * M_PI * (static_cast<double>(s) / samples);
                add(sketch_uv_to_3d(pl, cx + r * std::cos(t), cy + r * std::sin(t)));
            }
            if (piece.size() >= 2) segs.push_back(std::move(piece));
        } else if (e.type == SketchEntityType::Ellipse ||
                   e.type == SketchEntityType::EllipticalArc) {
            auto axes = sk.ellipse_axes(e.id);
            if (!axes) continue;
            const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3],
                         ang = (*axes)[4];
            if (rx < eps || ry < eps) continue;
            double a0 = 0.0, a1 = 2.0 * M_PI;
            if (e.type == SketchEntityType::EllipticalArc && e.params.size() >= 7) {
                a0 = sk.param(e.params[5]);
                a1 = sk.param(e.params[6]);
                while (a1 <= a0) a1 += 2.0 * M_PI;
            }
            const double span = a1 - a0;
            const int samples = std::max(8, static_cast<int>(std::ceil(span / (M_PI / 12.0))));
            for (int s = 0; s <= samples; ++s) {
                double t = a0 + span * (static_cast<double>(s) / samples);
                double u = cx + rx * std::cos(t) * std::cos(ang) - ry * std::sin(t) * std::sin(ang);
                double v = cy + rx * std::cos(t) * std::sin(ang) + ry * std::sin(t) * std::cos(ang);
                add(sketch_uv_to_3d(pl, u, v));
            }
            if (piece.size() >= 2) segs.push_back(std::move(piece));
        } else if (e.type == SketchEntityType::Spline) {
            auto samples = sk.spline_samples(e.id, std::max(8, static_cast<int>(sk.spline_fit_points(e.id).size()) * 8));
            if (samples.size() < 2) continue;
            for (const auto& uv : samples) add(sketch_uv_to_3d(pl, uv[0], uv[1]));
            if (piece.size() >= 2) segs.push_back(std::move(piece));
        }
    }
    return chain_polylines(std::move(segs));
}

bool spine_has_circle_radius(const TopoDS_Wire& wire, double radius, double tol) {
    if (wire.IsNull()) return false;
    for (TopExp_Explorer ex(wire, TopAbs_EDGE); ex.More(); ex.Next()) {
        BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
        if (c.GetType() != GeomAbs_Circle) continue;
        if (std::abs(c.Circle().Radius() - radius) <= tol) return true;
    }
    return false;
}

bool pipe_solid_ok(const TopoDS_Shape& s) {
    return !s.IsNull() && shape::count(s).solids >= 1 && std::abs(shape::volume(s)) > 1.0e-3;
}

// RightCorner/RoundCorner mitre a handful of analytic pieces (circle+line
// cylinder, spline into a 90° leg). On a non-planar line-chain — densified
// fit-spline plus a 3D corner — OCCT 8.0.1 PipeShell SIGSEGVs inside the
// mitre. Transformed still walks every edge.
bool spine_allows_miter(const TopoDS_Wire& spine) {
    int n = 0;
    for (TopExp_Explorer ex(spine, TopAbs_EDGE); ex.More(); ex.Next()) {
        ++n;
        BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
        if (c.GetType() != GeomAbs_Line) return true;
    }
    if (n <= 2) return true;
    BRepBuilderAPI_FindPlane finder(spine, 1.0e-6);
    return finder.Found();
}

// frenet == nullptr → Discrete trihedron (polyline fallback). Guide wins.
TopoDS_Shape pipe_largest_transition(const TopoDS_Wire& spine, const TopoDS_Wire& profile_wire,
                                     double thin_thickness, bool contact, bool correction,
                                     const TopoDS_Wire* guide, const bool* frenet) {
    auto try_mode = [&](BRepBuilderAPI_TransitionMode mode) -> TopoDS_Shape {
        try {
            BRepOffsetAPI_MakePipeShell shell(spine);
            if (guide && !guide->IsNull())
                shell.SetMode(*guide, /*CurvilinearEquivalence=*/false);
            else if (frenet == nullptr)
                shell.SetMode();
            else
                shell.SetMode(*frenet);
            shell.SetTransitionMode(mode);
            shell.Add(profile_wire, contact, correction);
            shell.Build();
            if (!shell.IsDone() || !shell.MakeSolid()) return {};
            TopoDS_Shape result = shell.Shape();
            if (thin_thickness > 0.0) {
                BRepOffsetAPI_MakeThickSolid mk;
                sx::occt::ShapeList closing;
                mk.MakeThickSolidByJoin(result, closing, -thin_thickness, 1e-3);
                if (!mk.IsDone()) return {};
                result = mk.Shape();
            }
            return pipe_solid_ok(result) ? result : TopoDS_Shape{};
        } catch (const Standard_Failure&) {
            return {};
        }
    };
    // Follow-path must rotate the ellipse at the hook. Transformed on a
    // coplanar circle+line (featsweep path) yields a 0-volume solid; RightCorner
    // fills that cylinder. A spline rail into a 90° leg can "succeed" as
    // Transformed while only sweeping the last edge — pick the largest solid.
    TopoDS_Shape result;
    double best_vol = -1.0;
    auto consider = [&](BRepBuilderAPI_TransitionMode mode) {
        TopoDS_Shape s = try_mode(mode);
        if (!pipe_solid_ok(s)) return;
        const double v = std::abs(shape::volume(s));
        if (v > best_vol) {
            best_vol = v;
            result = std::move(s);
        }
    };
    consider(BRepBuilderAPI_Transformed);
    if (spine_allows_miter(spine)) {
        consider(BRepBuilderAPI_RightCorner);
        consider(BRepBuilderAPI_RoundCorner);
    }
    if (result.IsNull()) throw std::runtime_error("MakePipeShell failed");
    return result;
}

TopoDS_Wire profile_outer_wire(const TopoDS_Shape& face) {
    if (face.ShapeType() == TopAbs_FACE) return BRepTools::OuterWire(TopoDS::Face(face));
    for (TopExp_Explorer ex(face, TopAbs_FACE); ex.More(); ex.Next()) {
        TopoDS_Wire w = BRepTools::OuterWire(TopoDS::Face(ex.Current()));
        if (!w.IsNull()) return w;
    }
    return {};
}

TopoDS_Shape sweep_along_spine(const TopoDS_Shape& face, const TopoDS_Wire& spine,
                               double thin_thickness, bool contact, bool frenet,
                               bool correction, const TopoDS_Wire* guide) {
    if (spine.IsNull()) throw std::runtime_error("empty spine wire");
    TopoDS_Wire profile_wire = profile_outer_wire(face);
    if (profile_wire.IsNull()) throw std::runtime_error("profile has no outer wire");
    return pipe_largest_transition(spine, profile_wire, thin_thickness, contact, correction,
                                   guide, &frenet);
}

// Append polyline b onto a, connecting at the nearest pair of endpoints.
json join_polylines(json a, const json& b) {
    if (!a.is_array() || a.size() < 2) return b;
    if (!b.is_array() || b.size() < 2) return a;
    gp_Pnt tail = pnt_from(a.back());
    gp_Pnt b0 = pnt_from(b[0]);
    gp_Pnt bn = pnt_from(b[b.size() - 1]);
    if (tail.Distance(b0) <= tail.Distance(bn)) {
        for (size_t i = 1; i < b.size(); ++i) a.push_back(b[i]);
    } else {
        for (int i = static_cast<int>(b.size()) - 2; i >= 0; --i) a.push_back(b[i]);
    }
    return a;
}

// Nearest-neighbor chain through a set of points (greedy TSP for path merge).
// Deduplicates coincident endpoints (shared sketch corners) first.
json chain_points(std::vector<gp_Pnt> pts) {
    const double eps = 1e-9;
    std::vector<gp_Pnt> uniq;
    for (const auto& p : pts) {
        bool dup = false;
        for (const auto& u : uniq) {
            if (u.Distance(p) < eps) {
                dup = true;
                break;
            }
        }
        if (!dup) uniq.push_back(p);
    }
    json path = json::array();
    if (uniq.empty()) return path;
    std::vector<bool> used(uniq.size(), false);
    size_t cur = 0;
    used[0] = true;
    path.push_back(pnt_to_json(uniq[0]));
    for (size_t n = 1; n < uniq.size(); ++n) {
        double best = 1e300;
        size_t best_i = cur;
        for (size_t i = 0; i < uniq.size(); ++i) {
            if (used[i]) continue;
            double d = uniq[cur].Distance(uniq[i]);
            if (d < best) {
                best = d;
                best_i = i;
            }
        }
        used[best_i] = true;
        cur = best_i;
        path.push_back(pnt_to_json(uniq[cur]));
    }
    return path;
}

// Catmull-Rom densify for bridge_spline mode (control points → denser polyline).
json densify_catmull(const std::vector<gp_Pnt>& ctrl, int samples_per_seg) {
    json path = json::array();
    if (ctrl.size() < 2) return path;
    if (ctrl.size() == 2) {
        path.push_back(pnt_to_json(ctrl[0]));
        path.push_back(pnt_to_json(ctrl[1]));
        return path;
    }
    auto at = [&](int i) -> gp_Pnt {
        if (i < 0) return ctrl[0];
        if (i >= static_cast<int>(ctrl.size())) return ctrl.back();
        return ctrl[static_cast<size_t>(i)];
    };
    for (int i = 0; i < static_cast<int>(ctrl.size()) - 1; ++i) {
        gp_Pnt p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
        for (int s = 0; s < samples_per_seg; ++s) {
            double t = static_cast<double>(s) / samples_per_seg;
            double t2 = t * t, t3 = t2 * t;
            gp_Pnt p(
                0.5 * ((2 * p1.X()) + (-p0.X() + p2.X()) * t +
                       (2 * p0.X() - 5 * p1.X() + 4 * p2.X() - p3.X()) * t2 +
                       (-p0.X() + 3 * p1.X() - 3 * p2.X() + p3.X()) * t3),
                0.5 * ((2 * p1.Y()) + (-p0.Y() + p2.Y()) * t +
                       (2 * p0.Y() - 5 * p1.Y() + 4 * p2.Y() - p3.Y()) * t2 +
                       (-p0.Y() + 3 * p1.Y() - 3 * p2.Y() + p3.Y()) * t3),
                0.5 * ((2 * p1.Z()) + (-p0.Z() + p2.Z()) * t +
                       (2 * p0.Z() - 5 * p1.Z() + 4 * p2.Z() - p3.Z()) * t2 +
                       (-p0.Z() + 3 * p1.Z() - 3 * p2.Z() + p3.Z()) * t3));
            path.push_back(pnt_to_json(p));
        }
    }
    path.push_back(pnt_to_json(ctrl.back()));
    return path;
}

// Leftover 5: a closed contour (circle, or any profile_face) is a solid.
// Thin wall stays line-based; the kernel says so instead of "open profile".
std::string thin_wall_on_error(double mm) {
    std::ostringstream os;
    os << "Thin wall is on (" << mm << " mm) — set 0 for a solid";
    return os.str();
}

bool sketch_closed_contour(const Sketch& sk) {
    for (const auto& e : sk.entities()) {
        if (!e.construction && (e.type == SketchEntityType::Circle
                                || e.type == SketchEntityType::Ellipse))
            return true;
    }
    std::string ignored;
    return !sk.profile_face(&ignored).IsNull();
}

// Offset of a support face along `want`. Use a point on the face (centre of
// mass, or the UV midpoint for a revolution cap that is not GeomAbs_Plane).
// gp_Pln::Location() of a revolved disc sits at the sketch origin, which
// pulled the Ø30 candlestick cut down to y = 0.
bool face_offset_along(const TopoDS_Face& face, const gp_Vec& want, double* offset) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    if (props.Mass() <= 1e-18) return false;
    const gp_Pnt c = props.CentreOfMass();
    Bnd_Box box;
    BRepBndLib::Add(face, box);
    if (box.IsVoid()) return false;
    double x1 = 0.0, y1 = 0.0, z1 = 0.0, x2 = 0.0, y2 = 0.0, z2 = 0.0;
    box.Get(x1, y1, z1, x2, y2, z2);
    const double span = std::abs(gp_Vec(x2 - x1, y2 - y1, z2 - z1).Dot(want));
    const bool thin = span <= 1.0;

    BRepAdaptor_Surface surf(face);
    gp_Dir n;
    bool have_n = false;
    if (surf.GetType() == GeomAbs_Plane) {
        n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        have_n = true;
    } else {
        double umin = 0.0, umax = 0.0, vmin = 0.0, vmax = 0.0;
        BRepTools::UVBounds(face, umin, umax, vmin, vmax);
        gp_Pnt pu;
        gp_Vec d1u, d1v;
        surf.D1(0.5 * (umin + umax), 0.5 * (vmin + vmax), pu, d1u, d1v);
        gp_Vec nn = d1u.Crossed(d1v);
        if (nn.Magnitude() > 1e-12) {
            n = gp_Dir(nn);
            if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
            have_n = true;
        }
    }
    const double aligned = have_n ? gp_Vec(n).Dot(want) : 0.0;
    // Revolved rims stay SurfaceOfRevolution; 0.999 dropped the y=220 disc.
    if (aligned < 0.95 && !(thin && aligned > 0.5)) return false;
    *offset = gp_Vec(c.XYZ()).Dot(want);
    return true;
}

void rebind_sketch_support(FeatureGraph& graph, Document& doc, Feature& f) {
    if (!f.sketch) return;
    if (!f.params.contains("support_host") || !f.params["support_host"].is_string()) return;
    if (!f.params.contains("support_normal") || !f.params["support_normal"].is_array()
        || f.params["support_normal"].size() < 3) return;
    gp_Vec want(f.params["support_normal"][0].get<double>(),
                f.params["support_normal"][1].get<double>(),
                f.params["support_normal"][2].get<double>());
    if (want.Magnitude() < 1e-12) return;
    want.Normalize();
    const Feature* host = graph.feature(
        EntityId::from_string(f.params["support_host"].get<std::string>()));
    if (host == nullptr || host->output_body.is_null()) return;
    const Body* body = doc.body(host->output_body);
    if (body == nullptr || body->shape.IsNull()) return;
    std::string side = "max";
    if (f.params.contains("support_side") && f.params["support_side"].is_string())
        side = f.params["support_side"].get<std::string>();
    bool have = false;
    double best = 0.0;
    for (TopExp_Explorer ex(body->shape, TopAbs_FACE); ex.More(); ex.Next()) {
        const TopoDS_Face face = TopoDS::Face(ex.Current());
        double off = 0.0;
        if (!face_offset_along(face, want, &off)) continue;
        if (!have || (side == "min" ? off < best : off > best)) {
            best = off;
            have = true;
        }
    }
    if (!have) return;
    SketchPlane pl = f.sketch->plane();
    const double current =
        gp_Vec(pl.origin[0], pl.origin[1], pl.origin[2]).Dot(want);
    // Already on a face along this normal: keep it. Hopping to `best`
    // would move a handle-top sketch (z=3) onto the thicker heads (z=5)
    // and a Blind Cut then misses the body.
    if (std::abs(current - best) > 0.75) {
        bool on_a_face = false;
        for (TopExp_Explorer ex(body->shape, TopAbs_FACE); ex.More(); ex.Next()) {
            double off = 0.0;
            if (!face_offset_along(TopoDS::Face(ex.Current()), want, &off))
                continue;
            if (std::abs(current - off) <= 0.5) {
                on_a_face = true;
                break;
            }
        }
        if (on_a_face) return;
    }
    // Follow the host face, including a shrink (plate 14→10). Refuse a jump
    // onto the opposite end of the body (candlestick y=220 → a false y=0
    // revolution-cap hit).
    Bnd_Box box;
    BRepBndLib::Add(body->shape, box);
    if (!box.IsVoid()) {
        double x1 = 0, y1 = 0, z1 = 0, x2 = 0, y2 = 0, z2 = 0;
        box.Get(x1, y1, z1, x2, y2, z2);
        double emin = 1.0e300;
        double emax = -1.0e300;
        for (double x : {x1, x2}) {
            for (double y : {y1, y2}) {
                for (double z : {z1, z2}) {
                    const double d = gp_Vec(x, y, z).Dot(want);
                    emin = std::min(emin, d);
                    emax = std::max(emax, d);
                }
            }
        }
        const double mid = 0.5 * (emin + emax);
        const bool current_on_side =
            (side == "min") ? (current <= mid + 0.5) : (current >= mid - 0.5);
        const bool best_on_side =
            (side == "min") ? (best <= mid + 0.5) : (best >= mid - 0.5);
        if (current_on_side && !best_on_side) return;
    }
    pl.origin = {want.X() * best, want.Y() * best, want.Z() * best};
    f.sketch->set_plane(std::move(pl));
}

}  // namespace

bool FeatureGraph::apply(Document& doc, Feature& f,
                         const std::map<std::string, double>& env, std::string* err) {
    using namespace feature_ops;
    auto fail = [&](const std::string& msg) {
        if (err) *err = f.name + ": " + msg;
        return false;
    };

    try {
        const json params = resolve_params(f.params, env);
        feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
        using ApplyFn = bool (*)(feature_ops::ApplyCtx&);
        static constexpr ApplyFn kApplyHandlers[] = {
            apply_primitive,
            apply_sketch,
            apply_extrude_revolve,
            apply_extrude_revolve,
            apply_boolean,
            apply_fillet_chamfer,
            apply_fillet_chamfer,
            apply_hole,
            apply_mirror,
            apply_linear_pattern,
            apply_circular_pattern,
            apply_shell,
            apply_offset,
            apply_draft,
            apply_sweep,
            apply_loft,
            apply_path,
            apply_helix_sweep,
            apply_thread,
            apply_import,
            apply_import,
            apply_direct_edit,
            apply_rib,
            apply_thicken,
            apply_wrap,
            apply_flange,
            apply_knit,
            apply_replace_face,
            apply_frame_member,
            apply_in_context,
            apply_convert_sheet,
            apply_user_feature,
            apply_noop,
            apply_noop,
            apply_datum,
        };
        static_assert(sizeof(kApplyHandlers) / sizeof(kApplyHandlers[0]) == kFeatureTypeCount);
        const auto idx = static_cast<size_t>(f.type);
        if (idx >= static_cast<size_t>(kFeatureTypeCount) || kApplyHandlers[idx] == nullptr) {
            return fail("unhandled feature type");
        }
        return kApplyHandlers[idx](ctx);
    } catch (const Standard_Failure& e) {
        return fail(e.GetMessageString());
    } catch (const std::exception& e) {
        return fail(e.what());
    }
}


bool FeatureGraph::regenerate(Document& doc, std::string* err) {
    // Bodies this pass will rebuild stay in the document so apply() can route
    // through replace_body_shape and the naming service keeps subshape ids
    // (and their cards) stable. Bodies whose features are gone or suppressed
    // are removed up front; generated_ covers features removed from the
    // timeline since the last regenerate.
    std::map<std::string, double> env;
    last_failed_ = {};
    last_error_.clear();
    warnings_.clear();
    try {
        env = variables_.evaluate();
    } catch (const std::exception& e) {
        if (err) *err = e.what();
        last_error_ = e.what();
        return false;
    }
    // Rollback treats features past the bar exactly like suppressed ones.
    auto rolled_back = [&](size_t i) {
        return rollback_index_ >= 0 && static_cast<int>(i) >= rollback_index_;
    };
    std::vector<EntityId> rebuilt;
    for (size_t i = 0; i < timeline_.size(); ++i) {
        const auto& f = timeline_[i];
        if (f.suppressed || rolled_back(i)) continue;
        if (!f.output_body.is_null()) rebuilt.push_back(f.output_body);
        for (const auto& id : f.output_bodies) rebuilt.push_back(id);
    }
    auto will_rebuild = [&](const EntityId& id) {
        for (const auto& r : rebuilt)
            if (r == id) return true;
        return false;
    };
    for (const auto& id : generated_) {
        if (!will_rebuild(id) && doc.body(id)) doc.remove_body(id);
    }
    for (const auto& f : timeline_) {
        if (!f.output_body.is_null() && !will_rebuild(f.output_body) && doc.body(f.output_body))
            doc.remove_body(f.output_body);
        for (const auto& id : f.output_bodies) {
            if (!will_rebuild(id) && doc.body(id)) doc.remove_body(id);
        }
    }
    generated_.clear();
    cues_.remember_live_edges(*this, doc);
    for (auto& f : timeline_) {
        if (f.suppressed) continue;
        cues_.refresh_feature_cues(*this, f, doc);
    }
    for (size_t i = 0; i < timeline_.size(); ++i) {
        auto& f = timeline_[i];
        if (f.suppressed || rolled_back(i)) continue;
        if (!apply(doc, f, env, err)) {
            last_failed_ = f.id;
            last_error_ = err ? *err : (f.name + ": regeneration failed");
            log::error("regenerate stopped at feature " + f.name);
            // Stale bodies of features after the failure point would show the
            // previous generation's geometry; drop them.
            bool past_failure = false;
            for (const auto& g : timeline_) {
                if (g.id == f.id) past_failure = true;
                if (!past_failure) continue;
                if (!g.output_body.is_null() && doc.body(g.output_body))
                    doc.remove_body(g.output_body);
                for (const auto& id : g.output_bodies) {
                    if (doc.body(id)) doc.remove_body(id);
                }
            }
            return false;
        }
        if (!f.output_body.is_null()) generated_.push_back(f.output_body);
        for (const auto& id : f.output_bodies) generated_.push_back(id);
    }
    // Selections made after this regen name the ids that exist now. Remember
    // them so a later rollback (a refused fillet) can still resolve that pick.
    cues_.remember_live_edges(*this, doc);
    return true;
}

// --- persistence ---

json FeatureGraph::to_json() const {
    json j;
    j["variables"] = variables_.to_json();
    if (rollback_index_ >= 0) j["rollback"] = rollback_index_;
    j["timeline"] = json::array();
    for (const auto& f : timeline_) {
        json jf;
        jf["id"] = f.id.str();
        jf["name"] = f.name;
        jf["type"] = to_string(f.type);
        jf["suppressed"] = f.suppressed;
        jf["params"] = f.params;
        if (!f.output_body.is_null()) jf["output_body"] = f.output_body.str();
        if (!f.output_bodies.empty()) {
            jf["output_bodies"] = json::array();
            for (const auto& id : f.output_bodies) jf["output_bodies"].push_back(id.str());
        }
        if (f.sketch) jf["sketch_data"] = sketch_to_json(*f.sketch);
        j["timeline"].push_back(jf);
    }
    json mem = cues_.to_json();
    if (!mem.empty()) j["edge_memory"] = std::move(mem);
    return j;
}

FeatureGraph FeatureGraph::from_json(const json& j) {
    FeatureGraph g;
    if (j.contains("variables")) g.variables_ = VariableTable::from_json(j["variables"]);
    g.rollback_index_ = j.value("rollback", -1);
    for (const auto& jf : j.at("timeline")) {
        Feature f;
        f.id = EntityId::from_string(jf.at("id").get<std::string>());
        f.name = jf.value("name", "feature");
        f.type = feature_type_from_string(jf.at("type").get<std::string>());
        f.suppressed = jf.value("suppressed", false);
        f.params = jf.value("params", json::object());
        if (jf.contains("output_body"))
            f.output_body = EntityId::from_string(jf["output_body"].get<std::string>());
        if (jf.contains("output_bodies")) {
            for (const auto& s : jf["output_bodies"])
                f.output_bodies.push_back(EntityId::from_string(s.get<std::string>()));
        }
        if (jf.contains("sketch_data")) f.sketch = sketch_from_json(jf["sketch_data"]);
        g.timeline_.push_back(std::move(f));
    }
    if (j.contains("edge_memory")) g.cues_.from_json(j["edge_memory"]);
    return g;
}

}  // namespace sx
