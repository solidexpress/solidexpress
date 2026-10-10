#include "sx/features.hpp"

#include "features/ops.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
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

TopoDS_Shape sweep_along_polyline(const TopoDS_Shape& face, const json& path,
                                  const json* guide_path,
                                  double thin_thickness) {
    json simplified = simplify_path_for_sweep(path);
    TopoDS_Wire spine = make_polyline_wire(simplified);
    TopoDS_Wire profile_wire = BRepTools::OuterWire(TopoDS::Face(face));
    if (profile_wire.IsNull()) throw std::runtime_error("profile has no outer wire");

    // Prefer MakePipeShell for all cases: MakePipe often yields an empty/invalid
    // solid when the profile plane contains the spine tangent (common for ground
    // sketches swept along an in-plane rail).
    BRepOffsetAPI_MakePipeShell shell(spine);
    if (guide_path && guide_path->is_array() && guide_path->size() >= 2) {
        json gsimp = simplify_path_for_sweep(*guide_path);
        TopoDS_Wire aux = make_polyline_wire(gsimp);
        // Auxiliary spine steers profile orientation / scale along the path.
        shell.SetMode(aux, /*CurvilinearEquivalence=*/false);
    } else {
        shell.SetMode();
    }
    shell.SetTransitionMode(BRepBuilderAPI_RightCorner);
    shell.Add(profile_wire, /*withContact=*/false,
              /*withCorrection=*/true);
    shell.Build();
    if (!shell.IsDone()) throw std::runtime_error("MakePipeShell failed");
    if (!shell.MakeSolid()) throw std::runtime_error("MakePipeShell could not make solid");
    TopoDS_Shape result = shell.Shape();
    if (thin_thickness > 0.0) {
        // Closed hollow: offset the swept solid inward (no open faces removed).
        BRepOffsetAPI_MakeThickSolid mk;
        sx::occt::ShapeList closing;
        mk.MakeThickSolidByJoin(result, closing, -thin_thickness, 1e-3);
        if (!mk.IsDone()) throw std::runtime_error("thin wall shell failed");
        result = mk.Shape();
    }
    return result;
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

    const gp_Pnt origin = axis.Location();
    const gp_Vec radial(axis.XDirection());
    const gp_Vec axial(axis.Direction());

    const gp_Pnt apex = origin.Translated(radial * (major_radius - depth));
    const gp_Pnt base_center = origin.Translated(radial * helix_r);
    const gp_Pnt base1 = base_center.Translated(axial * half_base);
    const gp_Pnt base2 = base_center.Translated(axial * (-half_base));

    BRepBuilderAPI_MakeWire profile_mk;
    {
        BRepBuilderAPI_MakeEdge e1(apex, base1);
        BRepBuilderAPI_MakeEdge e2(base1, base2);
        BRepBuilderAPI_MakeEdge e3(base2, apex);
        if (!e1.IsDone() || !e2.IsDone() || !e3.IsDone())
            throw std::runtime_error("thread profile edges failed");
        profile_mk.Add(e1.Edge());
        profile_mk.Add(e2.Edge());
        profile_mk.Add(e3.Edge());
    }
    if (!profile_mk.IsDone()) throw std::runtime_error("thread profile wire failed");
    TopoDS_Wire profile = profile_mk.Wire();

    TopoDS_Wire spine = curves::helix(axis, helix_r, pitch, turns, /*left_handed=*/false);

    BRepOffsetAPI_MakePipeShell shell(spine);
    shell.SetMode();  // Frenet
    shell.Add(profile, /*withContact=*/false,
              /*withCorrection=*/true);
    shell.Build();
    if (!shell.IsDone()) throw std::runtime_error("thread MakePipeShell failed");
    if (!shell.MakeSolid()) throw std::runtime_error("thread MakePipeShell could not make solid");
    return shell.Shape();
}

gp_Pnt sketch_uv_to_3d(const SketchPlane& pl, double u, double v) {
    return gp_Pnt(pl.origin[0] + pl.x_dir[0] * u + pl.y_dir[0] * v,
                  pl.origin[1] + pl.x_dir[1] * u + pl.y_dir[1] * v,
                  pl.origin[2] + pl.x_dir[2] * u + pl.y_dir[2] * v);
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

// Ordered polyline through line entities (preserves spline densification order).
json sketch_ordered_polyline(const Sketch& sk) {
    const double eps = 1e-9;
    json path = json::array();
    const auto& pl = sk.plane();
    gp_Pnt last;
    bool have_last = false;
    auto append_seg = [&](gp_Pnt a, gp_Pnt b) {
        if (!have_last) {
            path.push_back(pnt_to_json(a));
            if (a.Distance(b) >= eps) path.push_back(pnt_to_json(b));
            last = b;
            have_last = true;
            return;
        }
        if (last.Distance(a) < eps) {
            if (last.Distance(b) >= eps) path.push_back(pnt_to_json(b));
            last = b;
        } else if (last.Distance(b) < eps) {
            if (last.Distance(a) >= eps) path.push_back(pnt_to_json(a));
            last = a;
        } else {
            path.push_back(pnt_to_json(a));
            if (a.Distance(b) >= eps) path.push_back(pnt_to_json(b));
            last = b;
        }
    };
    for (const auto& e : sk.entities()) {
        if (e.construction) continue;
        if (e.type == SketchEntityType::Line && e.params.size() >= 4) {
            gp_Pnt a = sketch_uv_to_3d(pl, sk.param(e.params[0]), sk.param(e.params[1]));
            gp_Pnt b = sketch_uv_to_3d(pl, sk.param(e.params[2]), sk.param(e.params[3]));
            append_seg(a, b);
        } else if (e.type == SketchEntityType::Arc && e.params.size() >= 5) {
            const double cx = sk.param(e.params[0]);
            const double cy = sk.param(e.params[1]);
            const double r = sk.param(e.params[2]);
            double a0 = sk.param(e.params[3]);
            double a1 = sk.param(e.params[4]);
            if (r < eps) continue;
            // Sweep CCW from start to end (same convention as Sketch::add_arc).
            while (a1 <= a0) a1 += 2.0 * M_PI;
            const double span = a1 - a0;
            const int samples = std::max(8, static_cast<int>(std::ceil(span / (M_PI / 12.0))));
            gp_Pnt prev = sketch_uv_to_3d(pl, cx + r * std::cos(a0), cy + r * std::sin(a0));
            for (int s = 1; s <= samples; ++s) {
                double t = a0 + span * (static_cast<double>(s) / samples);
                gp_Pnt cur = sketch_uv_to_3d(pl, cx + r * std::cos(t), cy + r * std::sin(t));
                append_seg(prev, cur);
                prev = cur;
            }
        } else if (e.type == SketchEntityType::Circle && e.params.size() >= 3) {
            const double cx = sk.param(e.params[0]);
            const double cy = sk.param(e.params[1]);
            const double r = sk.param(e.params[2]);
            if (r < eps) continue;
            const int samples = 32;
            gp_Pnt prev = sketch_uv_to_3d(pl, cx + r, cy);
            for (int s = 1; s <= samples; ++s) {
                double t = 2.0 * M_PI * (static_cast<double>(s) / samples);
                gp_Pnt cur = sketch_uv_to_3d(pl, cx + r * std::cos(t), cy + r * std::sin(t));
                append_seg(prev, cur);
                prev = cur;
            }
        } else if (e.type == SketchEntityType::Spline) {
            // Sample the interpolating B-spline (not just fit-point chords).
            auto fits = sk.spline_fit_points(e.id);
            if (fits.size() < 2) continue;
            sx::occt::Array1OfPnt poles(1, static_cast<int>(fits.size()));
            for (int i = 0; i < static_cast<int>(fits.size()); ++i)
                poles.SetValue(i + 1, sketch_uv_to_3d(pl, fits[static_cast<size_t>(i)][0],
                                                      fits[static_cast<size_t>(i)][1]));
            GeomAPI_PointsToBSpline mk(poles);
            if (!mk.IsDone()) {
                for (size_t i = 1; i < fits.size(); ++i) {
                    gp_Pnt a = sketch_uv_to_3d(pl, fits[i - 1][0], fits[i - 1][1]);
                    gp_Pnt b = sketch_uv_to_3d(pl, fits[i][0], fits[i][1]);
                    append_seg(a, b);
                }
                continue;
            }
            Handle(Geom_BSplineCurve) curve = mk.Curve();
            const int samples = std::max(8, static_cast<int>(fits.size()) * 8);
            double u0 = curve->FirstParameter();
            double u1 = curve->LastParameter();
            gp_Pnt prev = curve->Value(u0);
            for (int s = 1; s <= samples; ++s) {
                double u = u0 + (u1 - u0) * (static_cast<double>(s) / samples);
                gp_Pnt cur = curve->Value(u);
                append_seg(prev, cur);
                prev = cur;
            }
        }
    }
    return path;
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
        if (!e.construction && e.type == SketchEntityType::Circle) return true;
    }
    std::string ignored;
    return !sk.profile_face(&ignored).IsNull();
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
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (gp_Vec(n).Dot(want) < 0.999) continue;
        const double offset = gp_Vec(surf.Plane().Location().XYZ()).Dot(want);
        if (!have || (side == "min" ? offset < best : offset > best)) {
            best = offset;
            have = true;
        }
    }
    if (!have) return;
    SketchPlane pl = f.sketch->plane();
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
        return fail(e.what());
    } catch (const std::exception& e) {
        return fail(e.what());
    }
}


// Record every currently resolvable edge so a later rebuild can find it
// after topological naming mints a new id for the same geometry.
static void remember_live_edges(FeatureGraph& graph, Document& doc) {
    for (const auto& body_id : doc.body_ids()) {
        const Body* body = doc.body(body_id);
        if (!body) continue;
        auto it = body->subshape_ids.find(EntityKind::Edge);
        if (it == body->subshape_ids.end()) continue;
        for (const auto& eid : it->second) {
            TopoDS_Shape shape = doc.resolve(eid);
            if (shape.IsNull() || shape.ShapeType() != TopAbs_EDGE) continue;
            const TopoDS_Edge edge = TopoDS::Edge(shape);
            BRepAdaptor_Curve curve(edge);
            gp_Pnt p;
            gp_Vec v;
            curve.D1(0.5 * (curve.FirstParameter() + curve.LastParameter()), p, v);
            if (v.Magnitude() < 1e-12) continue;
            v.Normalize();
            graph.remember_edge(eid.str(), p.X(), p.Y(), p.Z(), v.X(), v.Y(), v.Z());
        }
    }
}

// True when `point`/`dir` is the same line the stored cue already names.
// Topological naming can hand a fillet's old edge id to a different curve
// after the blend consumes it. That must not replace the pre-fillet cue.
static bool cue_still_names(const json& cue, const gp_Pnt& point, const gp_Vec& dir) {
    if (!cue.is_object() || !cue.contains("point") || !cue.contains("dir")) return true;
    const auto& pj = cue["point"];
    const auto& dj = cue["dir"];
    if (!pj.is_array() || pj.size() < 3 || !dj.is_array() || dj.size() < 3) return true;
    gp_Vec want_dir(dj[0].get<double>(), dj[1].get<double>(), dj[2].get<double>());
    if (want_dir.Magnitude() < 1e-12 || dir.Magnitude() < 1e-12) return false;
    want_dir.Normalize();
    gp_Vec got = dir;
    got.Normalize();
    if (std::abs(got.Dot(want_dir)) <= 0.95) return false;
    const gp_Pnt want(pj[0].get<double>(), pj[1].get<double>(), pj[2].get<double>());
    const gp_Vec delta(want, point);
    const gp_Vec along = want_dir * delta.Dot(want_dir);
    const double perp = (delta - along).Magnitude();
    return perp <= 0.5;
}

// A fillet/chamfer edge created by an earlier feature is released when the
// base body is rebuilt, then minted again by that feature. Copy a cue onto
// the feature while the id still resolves, or from an edge seen on a
// previous regen. Cues are not overwritten when the id is already gone, or
// when the id now resolves to a different curve, so a later regen keeps the
// pre-fillet location.
static void remember_dressup_edge_cues(FeatureGraph& graph, Feature& f, Document& doc) {
    if (f.type != FeatureType::Fillet && f.type != FeatureType::Chamfer) return;
    if (!f.params.contains("edges") || !f.params["edges"].is_array()) return;
    if (!f.params.contains("target") || !f.params["target"].is_string()) return;
    const Feature* ref =
        graph.feature(EntityId::from_string(f.params["target"].get<std::string>()));
    if (!ref || ref->output_body.is_null()) return;
    const Body* tb = doc.body(ref->output_body);
    if (!tb) return;
    json cues = f.params.value("edge_cues", json::object());
    bool changed = false;
    for (const auto& je : f.params["edges"]) {
        if (!je.is_string()) continue;
        const std::string key = je.get<std::string>();
        const bool have = cues.contains(key);
        TopoDS_Shape es;
        std::string why;
        if (feature_ops::resolve_topo_shape(doc, *tb, EntityKind::Edge, je, es, &why)) {
            const TopoDS_Edge edge = TopoDS::Edge(es);
            BRepAdaptor_Curve curve(edge);
            gp_Pnt p;
            gp_Vec v;
            curve.D1(0.5 * (curve.FirstParameter() + curve.LastParameter()), p, v);
            if (v.Magnitude() < 1e-12) continue;
            v.Normalize();
            if (have && !cue_still_names(cues[key], p, v)) continue;
            cues[key] = {{"point", {p.X(), p.Y(), p.Z()}}, {"dir", {v.X(), v.Y(), v.Z()}}};
            changed = true;
            continue;
        }
        double px, py, pz, dx, dy, dz;
        if (!graph.recall_edge(key, px, py, pz, dx, dy, dz)) continue;
        gp_Pnt mem_p(px, py, pz);
        gp_Vec mem_d(dx, dy, dz);
        if (have && !cue_still_names(cues[key], mem_p, mem_d)) continue;
        cues[key] = {{"point", {px, py, pz}}, {"dir", {dx, dy, dz}}};
        changed = true;
    }
    if (changed) f.params["edge_cues"] = std::move(cues);
}

void FeatureGraph::remember_edge(const std::string& id, double px, double py, double pz,
                                 double dx, double dy, double dz) {
    edge_memory_[id] = EdgeMemory{px, py, pz, dx, dy, dz};
}

bool FeatureGraph::recall_edge(const std::string& id, double& px, double& py, double& pz,
                               double& dx, double& dy, double& dz) const {
    auto it = edge_memory_.find(id);
    if (it == edge_memory_.end()) return false;
    px = it->second.px;
    py = it->second.py;
    pz = it->second.pz;
    dx = it->second.dx;
    dy = it->second.dy;
    dz = it->second.dz;
    return true;
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
    remember_live_edges(*this, doc);
    for (auto& f : timeline_) {
        if (f.suppressed) continue;
        remember_dressup_edge_cues(*this, f, doc);
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
    remember_live_edges(*this, doc);
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
    if (!edge_memory_.empty()) {
        json mem = json::object();
        for (const auto& [id, e] : edge_memory_)
            mem[id] = {e.px, e.py, e.pz, e.dx, e.dy, e.dz};
        j["edge_memory"] = std::move(mem);
    }
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
    if (j.contains("edge_memory") && j["edge_memory"].is_object()) {
        for (auto it = j["edge_memory"].begin(); it != j["edge_memory"].end(); ++it) {
            const auto& a = it.value();
            if (!a.is_array() || a.size() < 6) continue;
            g.remember_edge(it.key(), a[0].get<double>(), a[1].get<double>(), a[2].get<double>(),
                            a[3].get<double>(), a[4].get<double>(), a[5].get<double>());
        }
    }
    return g;
}

}  // namespace sx
