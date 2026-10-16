#include "shell_open_half.hpp"

#include "ops.hpp"

#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBndLib.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include "face_interior.hpp"
#include "sx/occt_types.hpp"
#include "sx/shape_utils.hpp"
#include "sx/surface_ops.hpp"

namespace sx::feature_ops {
namespace {

// ShellOpenHalf.POLICY
//   plug: planar face, solid|void, void probe inside the AABB (a cavity, not
//         the exterior), interior XY in the core (not a rim annulus).
//   then split on those planes. Shell a piece iff its centre of mass is inside
//         material (the solid core) and it carries faces on a plug plane.
//         Closing faces = those plug-plane faces. Keep already-open pieces.
//   no plugs → MakeThickSolidByJoin on the whole body (rungs 2–3).
struct ShellOpenHalf {
    static constexpr double kCoreFrac = 0.4;
    static constexpr double kProbe = 0.5;
    static constexpr double kFaceTol = 0.2;
    static constexpr double kPlaneTol = 1e-3;
    struct Plug {
        gp_Pln plane;
    };
};

bool point_in_solid(const TopoDS_Shape& shape, const gp_Pnt& p) {
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) {
        BRepClass3d_SolidClassifier cl(ex.Current());
        cl.Perform(p, 1e-6);
        if (cl.State() == TopAbs_IN) return true;
    }
    return false;
}

bool inside_bbox(const Bnd_Box& box, const gp_Pnt& p) {
    double xmin = 0, ymin = 0, zmin = 0, xmax = 0, ymax = 0, zmax = 0;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    const double m = 1e-3;
    return p.X() > xmin + m && p.X() < xmax - m && p.Y() > ymin + m && p.Y() < ymax - m &&
           p.Z() > zmin + m && p.Z() < zmax - m;
}

bool same_plane(const gp_Pln& a, const gp_Pln& b) {
    return std::abs(a.Axis().Direction().Dot(b.Axis().Direction())) > 0.99 &&
           std::abs(a.Distance(b.Location())) < ShellOpenHalf::kPlaneTol;
}

bool on_plane(const TopoDS_Face& face, const gp_Pln& pln) {
    gp_Dir n;
    if (!planar_face_normal(face, n)) return false;
    if (std::abs(n.Dot(pln.Axis().Direction())) < 0.99) return false;
    gp_Pnt p;
    if (!sx::measure::face_interior_point(face, p)) return false;
    return std::abs(pln.Distance(p)) < ShellOpenHalf::kFaceTol;
}

bool join_shell(const TopoDS_Shape& solid, const sx::occt::ShapeList& remove, double thickness,
                TopoDS_Shape& result, std::string* err) {
    if (remove.IsEmpty()) {
        result = solid;
        return true;
    }
    BRepOffsetAPI_MakeThickSolid mk;
    mk.MakeThickSolidByJoin(solid, remove, -thickness, 1e-3);
    if (!mk.IsDone()) {
        if (err) *err = "shell failed";
        return false;
    }
    result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result)) {
        if (err) *err = "shell result invalid";
        return false;
    }
    return true;
}

std::vector<ShellOpenHalf::Plug> find_plugs(const TopoDS_Shape& body, double thickness) {
    Bnd_Box box;
    BRepBndLib::Add(body, box);
    double xmin = 0, ymin = 0, zmin = 0, xmax = 0, ymax = 0, zmax = 0;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    const double core_r =
        ShellOpenHalf::kCoreFrac * 0.5 * std::min(xmax - xmin, ymax - ymin);
    const double probe = std::min(ShellOpenHalf::kProbe, std::max(0.1, thickness * 0.25));
    std::vector<ShellOpenHalf::Plug> plugs;
    for (TopExp_Explorer ex(body, TopAbs_FACE); ex.More(); ex.Next()) {
        const TopoDS_Face face = TopoDS::Face(ex.Current());
        gp_Dir n;
        if (!planar_face_normal(face, n)) continue;
        gp_Pnt p;
        if (!sx::measure::face_interior_point(face, p)) continue;
        if (std::hypot(p.X(), p.Y()) > core_r) continue;
        const gp_Pnt plus = p.Translated(gp_Vec(n) * probe);
        const gp_Pnt minus = p.Translated(gp_Vec(n) * -probe);
        const bool in_plus = point_in_solid(body, plus);
        const bool in_minus = point_in_solid(body, minus);
        if (in_plus == in_minus) continue;
        const gp_Pnt& cavity = in_plus ? minus : plus;
        if (!inside_bbox(box, cavity)) continue;
        const gp_Pln pln(p, n);
        bool dup = false;
        for (const auto& got : plugs) {
            if (same_plane(got.plane, pln)) {
                dup = true;
                break;
            }
        }
        if (!dup) plugs.push_back({pln});
    }
    return plugs;
}

bool split_by_planes(const TopoDS_Shape& body, const std::vector<gp_Pln>& planes,
                     std::vector<TopoDS_Shape>& solids, std::string* err) {
    TopoDS_Shape current = body;
    for (const auto& pln : planes) {
        const TopoDS_Shape tool =
            surf::plane_tool(current, pln.Location(), pln.Axis().Direction());
        if (tool.IsNull()) {
            if (err) *err = "shell split plane failed";
            return false;
        }
        BRepAlgoAPI_Splitter split;
        sx::occt::ShapeList args, tools;
        args.Append(current);
        tools.Append(tool);
        split.SetArguments(args);
        split.SetTools(tools);
        split.Build();
        if (!split.IsDone() || split.Shape().IsNull()) {
            if (err) *err = "shell split failed";
            return false;
        }
        current = split.Shape();
    }
    for (TopExp_Explorer ex(current, TopAbs_SOLID); ex.More(); ex.Next())
        solids.push_back(ex.Current());
    return !solids.empty();
}

void append_on_planes(const TopoDS_Shape& solid, const std::vector<gp_Pln>& planes,
                      sx::occt::ShapeList& out) {
    for (TopExp_Explorer ex(solid, TopAbs_FACE); ex.More(); ex.Next()) {
        const TopoDS_Face face = TopoDS::Face(ex.Current());
        for (const auto& pln : planes) {
            if (!on_plane(face, pln)) continue;
            out.Append(face);
            break;
        }
    }
}

gp_Pnt centre_of_mass(const TopoDS_Shape& solid) {
    GProp_GProps props;
    BRepGProp::VolumeProperties(solid, props);
    return props.CentreOfMass();
}

TopoDS_Shape unify_piece(const TopoDS_Shape& solid) {
    ShapeUpgrade_UnifySameDomain unify(solid, true, true, true);
    unify.Build();
    return unify.Shape().IsNull() ? solid : unify.Shape();
}

bool fuse_all(const std::vector<TopoDS_Shape>& parts, TopoDS_Shape& result, std::string* err) {
    if (parts.empty()) {
        if (err) *err = "shell has no pieces";
        return false;
    }
    result = parts.front();
    for (size_t i = 1; i < parts.size(); ++i) {
        BRepAlgoAPI_Fuse fuse(result, parts[i]);
        if (!fuse.IsDone() || fuse.Shape().IsNull()) {
            if (err) *err = "shell fuse failed";
            return false;
        }
        result = fuse.Shape();
    }
    ShapeUpgrade_UnifySameDomain unify(result, true, true, true);
    unify.Build();
    if (!unify.Shape().IsNull()) result = unify.Shape();
    if (result.IsNull() || !shape::is_valid(result)) {
        if (err) *err = "shell result invalid";
        return false;
    }
    return true;
}

}  // namespace

bool shell_keeping_open_walls(const TopoDS_Shape& body, const sx::occt::ShapeList& remove_faces,
                              double thickness, TopoDS_Shape& result, std::string* err) {
    const auto plugs = find_plugs(body, thickness);
    if (plugs.empty()) return join_shell(body, remove_faces, thickness, result, err);

    std::vector<gp_Pln> planes;
    planes.reserve(plugs.size());
    for (const auto& p : plugs) planes.push_back(p.plane);

    std::vector<TopoDS_Shape> solids;
    if (!split_by_planes(body, planes, solids, err)) return false;
    if (solids.size() < 2) return join_shell(body, remove_faces, thickness, result, err);

    std::vector<TopoDS_Shape> parts;
    bool any_shelled = false;
    for (const TopoDS_Shape& solid : solids) {
        sx::occt::ShapeList local;
        append_on_planes(solid, planes, local);
        if (local.IsEmpty() || !point_in_solid(solid, centre_of_mass(solid))) {
            parts.push_back(solid);
            continue;
        }
        const TopoDS_Shape clean = unify_piece(solid);
        sx::occt::ShapeList closing;
        append_on_planes(clean, planes, closing);
        TopoDS_Shape shelled;
        if (!join_shell(clean, closing, thickness, shelled, err)) return false;
        parts.push_back(shelled);
        any_shelled = true;
    }
    if (!any_shelled) return join_shell(body, remove_faces, thickness, result, err);
    return fuse_all(parts, result, err);
}

}  // namespace sx::feature_ops
