#include "sx/surface_ops.hpp"

#include <algorithm>
#include <cmath>

#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBndLib.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <Bnd_Box.hxx>
#include <ShapeFix_Solid.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shell.hxx>
#include <gp_Pln.hxx>
#include <gp_Vec.hxx>

#include "sx/shape_utils.hpp"

namespace sx::surf {
namespace {

double bbox_diagonal(const TopoDS_Shape& s) {
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    if (box.IsVoid()) return 0.0;
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    return gp_Vec(xmax - xmin, ymax - ymin, zmax - zmin).Magnitude();
}

// shape::center_of_mass integrates volume, which is zero for a face; a face
// probe has to come from its surface properties.
gp_Pnt surface_centroid(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(s, props);
    return props.CentreOfMass();
}

double distance_to_point(const TopoDS_Shape& s, const gp_Pnt& p) {
    BRepExtrema_DistShapeShape d(s, BRepBuilderAPI_MakeVertex(p).Vertex());
    if (!d.IsDone() || d.NbSolution() < 1) return -1.0;
    return d.Value();
}

}  // namespace

bool has_curved_face(const TopoDS_Shape& s) {
    for (TopExp_Explorer it(s, TopAbs_FACE); it.More(); it.Next()) {
        BRepAdaptor_Surface surf(TopoDS::Face(it.Current()), false);
        if (surf.GetType() != GeomAbs_Plane) return true;
    }
    return false;
}

TopoDS_Shape knit(const std::vector<TopoDS_Shape>& parts, double tolerance, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return TopoDS_Shape();
    };
    if (parts.size() < 2) return bail("knit needs at least two surfaces");

    BRepBuilderAPI_Sewing sew(tolerance);
    int added = 0;
    for (const auto& p : parts) {
        if (p.IsNull()) continue;
        sew.Add(p);
        ++added;
    }
    if (added < 2) return bail("knit needs at least two surfaces");
    sew.Perform();
    TopoDS_Shape sewed = sew.SewedShape();
    if (sewed.IsNull()) return bail("sewing failed");

    // A closed shell is a solid waiting to be named as one.
    if (sewed.ShapeType() == TopAbs_SHELL) {
        ShapeFix_Solid fixer;
        TopoDS_Shape solid = fixer.SolidFromShell(TopoDS::Shell(sewed));
        if (!solid.IsNull() && shape::volume(solid) > tolerance) return solid;
    }
    return sewed;
}

TopoDS_Shape thicken(const TopoDS_Shape& sheet, double offset, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return TopoDS_Shape();
    };
    if (sheet.IsNull()) return bail("nothing to thicken");
    if (std::abs(offset) < 1e-9) return bail("thicken needs a non-zero offset");
    if (shape::count(sheet).solids > 0)
        return bail("thicken needs a surface or shell (use offset for a solid)");

    BRepOffsetAPI_MakeThickSolid mk;
    mk.MakeThickSolidBySimple(sheet, offset);
    if (!mk.IsDone()) return bail("thicken failed");
    TopoDS_Shape out = mk.Shape();
    if (out.IsNull() || shape::count(out).solids < 1) return bail("thicken produced no solid");
    // Offsetting a face inherits its orientation, which can leave the solid
    // inside-out; booleans downstream need it the right way round.
    if (shape::volume(out) < 0.0) out = out.Reversed();
    return out;
}

TopoDS_Shape plane_tool(const TopoDS_Shape& solid, const gp_Pnt& origin, const gp_Dir& normal) {
    const double d = std::max(1.0, bbox_diagonal(solid));
    BRepBuilderAPI_MakeFace mk(gp_Pln(origin, normal), -d, d, -d, d);
    if (!mk.IsDone()) return {};
    return mk.Face();
}

TopoDS_Shape replace_face(const TopoDS_Shape& solid, const TopoDS_Shape& face,
                          const TopoDS_Shape& tool, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return TopoDS_Shape();
    };
    if (solid.IsNull() || face.IsNull() || tool.IsNull()) return bail("missing solid, face or tool");

    BRepAlgoAPI_Splitter split;
    TopTools_ListOfShape args, tools;
    args.Append(solid);
    tools.Append(tool);
    split.SetArguments(args);
    split.SetTools(tools);
    split.Build();
    if (!split.IsDone() || split.Shape().IsNull()) return bail("replace face: split failed");

    const gp_Pnt probe = surface_centroid(face);
    const double tol = 1e-6;

    std::vector<TopoDS_Shape> keep;
    int pieces = 0;
    for (TopExp_Explorer it(split.Shape(), TopAbs_SOLID); it.More(); it.Next()) {
        ++pieces;
        const double d = distance_to_point(it.Current(), probe);
        if (d > tol) keep.push_back(it.Current());
    }
    if (pieces < 2) return bail("replace face: the tool surface does not trim the target");
    if (keep.empty()) return bail("replace face: every piece still carries the old face");

    TopoDS_Shape out = keep.front();
    for (size_t i = 1; i < keep.size(); ++i) {
        BRepAlgoAPI_Fuse fuse(out, keep[i]);
        if (!fuse.IsDone()) return bail("replace face: rejoining the trimmed pieces failed");
        out = fuse.Shape();
    }
    if (shape::volume(out) <= tol) return bail("replace face: nothing left of the target");
    return out;
}

TopoDS_Shape rib_solid(const std::vector<gp_Pnt>& profile, double thickness, double height,
                       const gp_Dir& dir, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return TopoDS_Shape();
    };
    if (profile.size() < 2) return bail("rib needs an open profile of two or more points");
    if (thickness <= 1e-9 || std::abs(height) <= 1e-9)
        return bail("rib needs a positive thickness and a non-zero height");

    const double half = thickness * 0.5;
    const gp_Vec up = gp_Vec(dir) * height;
    TopoDS_Shape out;
    for (size_t i = 1; i < profile.size(); ++i) {
        gp_Pnt a = profile[i - 1];
        gp_Pnt b = profile[i];
        gp_Vec along(a, b);
        if (along.Magnitude() < 1e-9) continue;
        along.Normalize();
        // Overlap the joints so consecutive segments fuse into one rib.
        if (i > 1) a.Translate(along * -half);
        if (i + 1 < profile.size()) b.Translate(along * half);
        gp_Vec side = gp_Vec(dir).Crossed(along);
        if (side.Magnitude() < 1e-9) return bail("rib profile is parallel to its own height");
        side.Normalize();
        side *= half;

        BRepBuilderAPI_MakePolygon poly(a.Translated(side), b.Translated(side),
                                        b.Translated(-side), a.Translated(-side), true);
        if (!poly.IsDone()) return bail("rib segment outline failed");
        BRepBuilderAPI_MakeFace face(poly.Wire(), true);
        if (!face.IsDone()) return bail("rib segment is not planar");
        TopoDS_Shape seg = BRepPrimAPI_MakePrism(face.Face(), up).Shape();
        if (seg.IsNull()) return bail("rib segment sweep failed");
        if (out.IsNull()) {
            out = seg;
            continue;
        }
        BRepAlgoAPI_Fuse fuse(out, seg);
        if (!fuse.IsDone()) return bail("rib corner fuse failed");
        out = fuse.Shape();
    }
    if (out.IsNull()) return bail("rib profile had no usable segments");
    return out;
}

TopoDS_Shape offset_solid(const TopoDS_Shape& solid, double delta, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return TopoDS_Shape();
    };
    if (solid.IsNull()) return bail("nothing to offset");
    if (std::abs(delta) < 1e-9) return bail("offset must be non-zero");
    const double budget = shape::volume(solid);
    // Grown or shrunk, but never unchanged: an offset that leaves the volume
    // alone means OCCT quietly handed back the input.
    auto usable = [&](const TopoDS_Shape& s) {
        if (s.IsNull()) return TopoDS_Shape();
        TopoDS_Shape out = s;
        if (shape::volume(out) < 0.0) out = out.Reversed();
        const double v = shape::volume(out);
        if (v <= 1e-9) return TopoDS_Shape();
        const bool moved = delta > 0.0 ? (v > budget * 1.0001) : (v < budget * 0.9999);
        return moved ? out : TopoDS_Shape();
    };

    BRepOffsetAPI_MakeOffsetShape by_join;
    by_join.PerformByJoin(solid, delta, 1e-3);
    if (by_join.IsDone()) {
        TopoDS_Shape out = usable(by_join.Shape());
        if (!out.IsNull()) return out;
    }
    BRepOffsetAPI_MakeOffsetShape simple;
    simple.PerformBySimple(solid, delta);
    if (simple.IsDone()) {
        TopoDS_Shape out = usable(simple.Shape());
        if (!out.IsNull()) return out;
    }
    return bail("surface offset failed");
}

TopoDS_Shape surface_stamp(const TopoDS_Shape& solid, const TopoDS_Shape& column, double depth,
                           bool outward, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return TopoDS_Shape();
    };
    if (solid.IsNull() || column.IsNull()) return bail("missing body or profile column");
    if (depth <= 1e-9) return bail("stamp depth must be positive");

    TopoDS_Shape offset = offset_solid(solid, outward ? depth : -depth, err);
    if (offset.IsNull()) return {};

    // Two ordinary solid booleans: take the slice of the column inside the
    // near shape, then discard whatever reaches past `depth`.
    BRepAlgoAPI_Common chunk(column, outward ? offset : solid);
    if (!chunk.IsDone() || chunk.Shape().IsNull()) return bail("profile misses the body");
    BRepAlgoAPI_Cut stamp(chunk.Shape(), outward ? solid : offset);
    if (!stamp.IsDone() || stamp.Shape().IsNull()) return bail("stamp trim failed");
    if (shape::volume(stamp.Shape()) <= 1e-9) return bail("stamp is empty");
    return stamp.Shape();
}

}  // namespace sx::surf
