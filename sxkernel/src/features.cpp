#include "sx/features.hpp"
#include "sx/solver.hpp"

#include "features/ops.hpp"

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepTools.hxx>
#include <Bnd_Box.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Wire.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <GProp_GProps.hxx>

#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>

#include "sx/curves.hpp"
#include "sx/document.hpp"
#include "sx/interop.hpp"
#include "sx/log.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch_json.hpp"

using nlohmann::json;

namespace sx {

using feature_ops::dir_from;
using feature_ops::pnt_from;
using feature_ops::put_body;

const char* to_string(FeatureType t) {
    switch (t) {
        case FeatureType::Primitive: return "primitive";
        case FeatureType::Sketch: return "sketch";
        case FeatureType::Extrude: return "extrude";
        case FeatureType::Revolve: return "revolve";
        case FeatureType::Boolean: return "boolean";
        case FeatureType::Fillet: return "fillet";
        case FeatureType::Chamfer: return "chamfer";
        case FeatureType::Hole: return "hole";
        case FeatureType::Mirror: return "mirror";
        case FeatureType::LinearPattern: return "linear_pattern";
        case FeatureType::CircularPattern: return "circular_pattern";
        case FeatureType::Shell: return "shell";
        case FeatureType::Offset: return "offset";
        case FeatureType::PushPull: return "push_pull";
        case FeatureType::Draft: return "draft";
        case FeatureType::Sweep: return "sweep";
        case FeatureType::Loft: return "loft";
        case FeatureType::Path: return "path";
        case FeatureType::HelixSweep: return "helix_sweep";
        case FeatureType::Thread: return "thread";
        case FeatureType::ImportStep: return "import_step";
        case FeatureType::ImportStl: return "import_stl";
    }
    return "unknown";
}

FeatureType feature_type_from_string(const std::string& s) {
    if (s == "primitive") return FeatureType::Primitive;
    if (s == "sketch") return FeatureType::Sketch;
    if (s == "extrude") return FeatureType::Extrude;
    if (s == "revolve") return FeatureType::Revolve;
    if (s == "boolean") return FeatureType::Boolean;
    if (s == "fillet") return FeatureType::Fillet;
    if (s == "chamfer") return FeatureType::Chamfer;
    if (s == "hole") return FeatureType::Hole;
    if (s == "mirror") return FeatureType::Mirror;
    if (s == "linear_pattern") return FeatureType::LinearPattern;
    if (s == "circular_pattern") return FeatureType::CircularPattern;
    if (s == "shell") return FeatureType::Shell;
    if (s == "offset") return FeatureType::Offset;
    if (s == "push_pull") return FeatureType::PushPull;
    if (s == "draft") return FeatureType::Draft;
    if (s == "sweep") return FeatureType::Sweep;
    if (s == "loft") return FeatureType::Loft;
    if (s == "path") return FeatureType::Path;
    if (s == "helix_sweep") return FeatureType::HelixSweep;
    if (s == "thread") return FeatureType::Thread;
    if (s == "import_step") return FeatureType::ImportStep;
    if (s == "import_stl") return FeatureType::ImportStl;
    throw std::invalid_argument("unknown feature type: " + s);
}

static bool creates_body(const Feature& f) {
    if (f.type == FeatureType::Primitive || f.type == FeatureType::ImportStep ||
        f.type == FeatureType::ImportStl || f.type == FeatureType::Mirror ||
        f.type == FeatureType::Loft || f.type == FeatureType::HelixSweep)
        return true;
    if (f.type == FeatureType::Extrude || f.type == FeatureType::Revolve ||
        f.type == FeatureType::Sweep)
        return f.params.value("op", "new") == "new";
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

// Collect feature ids referenced by params keys sketch/target/tool/sketches/guides.
void collect_deps(const Feature& f, std::vector<std::string>& out) {
    for (const char* key : {"sketch", "target", "tool", "path_feature"}) {
        if (f.params.contains(key) && f.params[key].is_string())
            out.push_back(f.params[key].get<std::string>());
    }
    for (const char* arr_key : {"sketches", "guides"}) {
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
        std::vector<std::string> deps;
        collect_deps(f, deps);
        for (const auto& d : deps) {
            if (d == needle) return true;
        }
    }
    return false;
}

// --- regeneration ---

namespace {
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
constexpr double k_hole_nudge = 1.0;
constexpr double k_hole_through = 1e6;

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
                                  const json* guide_path = nullptr,
                                  double thin_thickness = 0.0) {
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
        shell.SetMode(aux, /*CurvilinearEquivalence=*/Standard_False);
    } else {
        shell.SetMode();
    }
    shell.SetTransitionMode(BRepBuilderAPI_RightCorner);
    shell.Add(profile_wire, /*withContact=*/Standard_False,
              /*withCorrection=*/Standard_True);
    shell.Build();
    if (!shell.IsDone()) throw std::runtime_error("MakePipeShell failed");
    if (!shell.MakeSolid()) throw std::runtime_error("MakePipeShell could not make solid");
    TopoDS_Shape result = shell.Shape();
    if (thin_thickness > 0.0) {
        // Closed hollow: offset the swept solid inward (no open faces removed).
        BRepOffsetAPI_MakeThickSolid mk;
        TopTools_ListOfShape closing;
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
    shell.Add(profile, /*withContact=*/Standard_False,
              /*withCorrection=*/Standard_True);
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
    shell.Add(profile, /*withContact=*/Standard_False,
              /*withCorrection=*/Standard_True);
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

// Ordered polyline through line + spline entities (preserves drawing order).
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
            TColgp_Array1OfPnt poles(1, static_cast<int>(fits.size()));
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
json densify_catmull(const std::vector<gp_Pnt>& ctrl, int samples_per_seg = 8) {
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

}  // namespace

bool FeatureGraph::apply(Document& doc, Feature& f,
                         const std::map<std::string, double>& env, std::string* err) {
    auto fail = [&](const std::string& msg) {
        if (err) *err = f.name + ": " + msg;
        return false;
    };

    try {
        // Resolve "=expr" string params to numbers so every double read below
        // (including nested origin/position arrays) sees concrete values.
        const json params = resolve_params(f.params, env);
        auto find_feature_body = [&](const std::string& key) -> EntityId {
            if (!params.contains(key)) return {};
            const Feature* ref =
                feature(EntityId::from_string(params[key].get<std::string>()));
            return ref ? ref->output_body : EntityId{};
        };

        switch (f.type) {
            case FeatureType::Sketch:
                if (f.sketch) {
                    std::string serr;
                    if (!f.sketch->resolve_expressions(env, &serr))
                        return fail(serr.empty() ? "sketch expression failed" : serr);
                    // Associative Convert Entities: refresh projected edges from live
                    // body topology; mark dangling when the source edge is gone.
                    {
                        std::vector<std::string> live;
                        for (const auto& bid : doc.body_ids()) {
                            const Body* b = doc.body(bid);
                            if (!b) continue;
                            const auto it = b->subshape_ids.find(EntityKind::Edge);
                            if (it == b->subshape_ids.end()) continue;
                            for (const auto& eid : it->second) live.push_back(eid.str());
                        }
                        for (const auto& e : f.sketch->entities()) {
                            if (!e.external || e.projected_from.empty()) continue;
                            EntityId edge_id;
                            try {
                                edge_id = EntityId::from_string(e.projected_from);
                            } catch (...) {
                                continue;  // non-UUID tags (tests / legacy) skip update
                            }
                            TopoDS_Shape sh = doc.resolve(edge_id);
                            if (sh.IsNull() || sh.ShapeType() != TopAbs_EDGE) continue;
                            TopoDS_Edge edge = TopoDS::Edge(sh);
                            BRepAdaptor_Curve curv(edge);
                            if (curv.GetType() == GeomAbs_Line) {
                                gp_Pnt a = curv.Value(curv.FirstParameter());
                                gp_Pnt b = curv.Value(curv.LastParameter());
                                f.sketch->update_projected_line(
                                    e.id,
                                    {a.X(), a.Y(), a.Z()},
                                    {b.X(), b.Y(), b.Z()});
                            } else if (curv.GetType() == GeomAbs_Circle) {
                                gp_Circ c = curv.Circle();
                                gp_Pnt ctr = c.Location();
                                f.sketch->update_projected_circle(
                                    e.id, {ctr.X(), ctr.Y(), ctr.Z()}, c.Radius());
                            }
                        }
                        int dangling = f.sketch->mark_dangling_external(live);
                        if (dangling > 0)
                            log::warn(f.name + ": " + std::to_string(dangling) +
                                      " converted entities dangling");
                    }
                    // Re-solve after expression resolution so dims drive geometry.
                    auto solver = make_planegcs_backend();
                    auto res = solver->solve(*f.sketch);
                    if (!res.ok()) return fail("sketch solve failed after expressions");
                }
                return true;  // no geometry output

            case FeatureType::Primitive: {
                TopoDS_Shape shape = build_primitive_feature(params, env);
                // Rebuilding into a live body routes through replace_body_shape,
                // which runs the naming service so subshape ids survive edits.
                put_body(doc, f.output_body, shape, f.name);
                return true;
            }

            case FeatureType::Extrude:
            case FeatureType::Revolve: {
                EntityId sketch_fid = EntityId::from_string(params.at("sketch").get<std::string>());
                const Feature* skf = feature(sketch_fid);
                if (!skf || !skf->sketch) return fail("missing sketch feature");
                std::string perr;
                TopoDS_Shape face = skf->sketch->profile_face(&perr);
                if (face.IsNull()) return fail("profile: " + perr);

                TopoDS_Shape result;
                if (f.type == FeatureType::Extrude) {
                    auto n = skf->sketch->plane().normal();
                    gp_Vec dir(n[0], n[1], n[2]);
                    dir.Normalize();
                    double dist = num_param(params, "distance", 10.0, env);
                    std::string end = params.value("end", "blind");
                    bool midplane = params.value("symmetric", false) || end == "midplane";
                    std::string op = params.value("op", "new");
                    if (end == "through_all") {
                        // Peer Through All: long enough to exit all target
                        // geometry (cut/fuse) or a generous blind for new.
                        double sign = dist < 0.0 ? -1.0 : 1.0;
                        double extent = 1.0e6;
                        if (op != "new") {
                            EntityId tid = find_feature_body("target");
                            const Body* tb = doc.body(tid);
                            if (tb && !tb->shape.IsNull()) {
                                Bnd_Box box;
                                BRepBndLib::Add(tb->shape, box);
                                if (!box.IsVoid()) {
                                    double xmin, ymin, zmin, xmax, ymax, zmax;
                                    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                                    gp_Pnt c((xmin + xmax) * 0.5, (ymin + ymax) * 0.5,
                                             (zmin + zmax) * 0.5);
                                    gp_Pnt corners[8] = {
                                        {xmin, ymin, zmin}, {xmax, ymin, zmin},
                                        {xmin, ymax, zmin}, {xmax, ymax, zmin},
                                        {xmin, ymin, zmax}, {xmax, ymin, zmax},
                                        {xmin, ymax, zmax}, {xmax, ymax, zmax},
                                    };
                                    double max_along = 0.0;
                                    for (const auto& p : corners) {
                                        max_along = std::max(max_along,
                                            std::abs(gp_Vec(c, p).Dot(dir)));
                                    }
                                    extent = std::max(max_along * 2.0 + 10.0, std::abs(dist));
                                }
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
                    TopoDS_Shape merged = (op == "cut")
                                              ? TopoDS_Shape(BRepAlgoAPI_Cut(tb->shape, result).Shape())
                                              : TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, result).Shape());
                    if (merged.IsNull()) return fail("boolean failed");
                    doc.replace_body_shape(target, merged);
                }
                return true;
            }

            case FeatureType::Boolean: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_boolean(ctx);
            }

            case FeatureType::Fillet:
            case FeatureType::Chamfer: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_fillet_chamfer(ctx);
            }

            case FeatureType::Hole: {
                if (params.contains("target")) {
                    const Feature* tf =
                        feature(EntityId::from_string(params["target"].get<std::string>()));
                    if (!tf || tf->suppressed) return true;
                }
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                double diameter = num_param(params, "diameter", 0.0, env);
                if (diameter <= 0.0) return fail("invalid diameter");
                double depth_param = num_param(params, "depth", 0.0, env);
                double depth = depth_param > 0.0 ? depth_param : k_hole_through;
                std::string htype = params.value("type", "simple");
                TopoDS_Shape tool = build_feature_hole_tool(
                    pnt_from(params.at("position")), dir_from(params.at("direction")),
                    diameter, depth, htype, num_param(params, "cb_diameter", 0.0, env),
                    num_param(params, "cb_depth", 0.0, env),
                    num_param(params, "cs_diameter", 0.0, env),
                    num_param(params, "cs_angle_deg", 90.0, env));
                if (tool.IsNull() || !shape::is_valid(tool)) return fail("hole tool failed");
                BRepAlgoAPI_Cut cut(tb->shape, tool);
                if (!cut.IsDone()) return fail("hole cut failed");
                TopoDS_Shape result = cut.Shape();
                if (result.IsNull() || !shape::is_valid(result)) return fail("hole result invalid");
                if (shape::count(result).solids < 1 || shape::volume(result) <= 0.0)
                    return fail("hole destroyed the solid");
                doc.replace_body_shape(target, result);
                return true;
            }

            case FeatureType::Mirror: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_mirror(ctx);
            }

            case FeatureType::LinearPattern: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_linear_pattern(ctx);
            }

            case FeatureType::CircularPattern: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_circular_pattern(ctx);
            }

            case FeatureType::Shell: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_shell(ctx);
            }

            case FeatureType::Offset: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_offset(ctx);
            }

            case FeatureType::PushPull: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_push_pull(ctx);
            }

            case FeatureType::Draft: {
                feature_ops::ApplyCtx ctx{*this, doc, f, params, env, err};
                return feature_ops::apply_draft(ctx);
            }

            case FeatureType::Path: {
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

            case FeatureType::Sweep: {
                EntityId sketch_fid =
                    EntityId::from_string(params.at("sketch").get<std::string>());
                const Feature* skf = feature(sketch_fid);
                if (!skf || !skf->sketch) return fail("missing sketch feature");
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
                    EntityId gid =
                        EntityId::from_string(params["guides"][0].get<std::string>());
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
                    return fail(std::string("sweep failed: ") + e.GetMessageString());
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
                    TopoDS_Shape merged = (op == "cut")
                                              ? TopoDS_Shape(BRepAlgoAPI_Cut(tb->shape, result).Shape())
                                              : TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, result).Shape());
                    if (merged.IsNull()) return fail("boolean failed");
                    doc.replace_body_shape(target, merged);
                }
                return true;
            }

            case FeatureType::Loft: {
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
                        BRepBuilderAPI_MakeFace mkf(w, /*OnlyPlane=*/Standard_True);
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
                                return pts[k - 1].Translated(
                                    gp_Vec(pts[k - 1], pts[k]) * u);
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
                            // Station along loft axis; radius blends profile sizes and
                            // guide offset (clamped so a far rail cannot explode volume).
                            gp_Lin axis_line(c0, axis_dir);
                            double along = gp_Vec(axis_line.Location(), gp).Dot(axis_dir);
                            along = std::clamp(along, 0.0, axis_vec.Magnitude());
                            gp_Pnt foot =
                                axis_line.Location().Translated(gp_Vec(axis_dir) * along);
                            double r_blend = r0 + (r1 - r0) * (along / std::max(axis_vec.Magnitude(), 1e-9));
                            double r_off = foot.Distance(gp);
                            double r = std::clamp(0.5 * (r_blend + r_off), r_lo, r_hi);
                            if (r < 1e-6) r = 1e-3;
                            // Nudge section center toward the guide in the loft plane.
                            gp_Vec lateral(foot, gp);
                            lateral -= gp_Vec(axis_dir) * lateral.Dot(axis_dir);
                            gp_Pnt center = foot;
                            if (lateral.Magnitude() > 1e-9) {
                                double nudge = std::min(lateral.Magnitude(), r * 0.35);
                                center = foot.Translated(lateral.Normalized() * nudge);
                            }
                            gp_Circ circ(gp_Ax2(center, axis_dir), r);
                            TopoDS_Wire mw =
                                BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(circ).Edge())
                                    .Wire();
                            mids.push_back(mw);
                        }
                    }
                    std::vector<TopoDS_Wire> ordered;
                    ordered.push_back(sections.front());
                    for (auto& m : mids) ordered.push_back(m);
                    ordered.push_back(sections.back());
                    // Keep any middle profile sketches between first and last.
                    for (size_t si = 1; si + 1 < sections.size(); ++si)
                        ordered.insert(ordered.end() - 1, sections[si]);
                    sections = std::move(ordered);
                    ruled = false;  // smoothed loft through guide sections
                }
                BRepOffsetAPI_ThruSections loft(/*isSolid=*/Standard_True, ruled);
                for (const auto& w : sections) loft.AddWire(w);
                TopoDS_Shape result;
                try {
                    loft.Build();
                    if (!loft.IsDone()) return fail("ThruSections failed");
                    result = loft.Shape();
                } catch (const Standard_Failure& e) {
                    return fail(std::string("ThruSections failed: ") + e.GetMessageString());
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("loft result invalid");
                if (shape::count(result).solids < 1) return fail("loft result is not a solid");
                put_body(doc, f.output_body, result, f.name);
                return true;
            }

            case FeatureType::HelixSweep: {
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

            case FeatureType::Thread: {
                if (!params.contains("axis_point") || !params.contains("axis_dir"))
                    return fail("missing axis_point/axis_dir");
                if (params.contains("target")) {
                    const Feature* tf =
                        feature(EntityId::from_string(params["target"].get<std::string>()));
                    if (!tf || tf->suppressed) return true;
                }
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

            case FeatureType::ImportStep:
            case FeatureType::ImportStl: {
                // File is re-read on every regenerate; path is an external
                // document dependency (acceptable for this BASE feature).
                if (!params.contains("path") || !params["path"].is_string())
                    return fail("missing path");
                const std::string path = params["path"].get<std::string>();
                const double scale = num_param(params, "scale", 1.0, env);
                const bool is_stl = f.type == FeatureType::ImportStl;

                Document tmp;
                std::string ierr;
                auto ids = is_stl ? interop::import_stl(tmp, path, &ierr)
                                  : interop::import_step(tmp, path, &ierr);
                if (ids.empty())
                    return fail(ierr.empty()
                                    ? (is_stl ? "STL import failed" : "STEP import failed")
                                    : ierr);
                const int index = is_stl ? 0 : params.value("index", 0);
                if (index < 0 || static_cast<size_t>(index) >= ids.size())
                    return fail("shape index out of range");
                const Body* src = tmp.body(ids[static_cast<size_t>(index)]);
                if (!src || src->shape.IsNull()) return fail("imported shape is null");

                TopoDS_Shape result = src->shape;
                if (std::abs(scale - 1.0) > 1e-15) {
                    if (scale <= 0.0) return fail("scale must be positive");
                    gp_Trsf t;
                    t.SetScale(gp_Pnt(0, 0, 0), scale);
                    result = BRepBuilderAPI_Transform(result, t, /*copy=*/true).Shape();
                    if (result.IsNull() || !shape::is_valid(result))
                        return fail("scale transform failed");
                }
                put_body(doc, f.output_body, result, f.name);
                return true;
            }
        }
    } catch (const std::exception& e) {
        return fail(e.what());
    }
    return fail("unhandled feature type");
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
    return g;
}

}  // namespace sx
