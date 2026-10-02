#include "sx/shape_utils.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include "sx/occt_types.hpp"
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <sstream>

namespace sx::shape {

static gp_Ax2 to_ax2(const Placement& p) {
    return gp_Ax2(gp_Pnt(p.origin[0], p.origin[1], p.origin[2]),
                  gp_Dir(p.z_dir[0], p.z_dir[1], p.z_dir[2]),
                  gp_Dir(p.x_dir[0], p.x_dir[1], p.x_dir[2]));
}

TopoDS_Shape make_box(double dx, double dy, double dz, const Placement& p) {
    return BRepPrimAPI_MakeBox(to_ax2(p), dx, dy, dz).Shape();
}

TopoDS_Shape make_cylinder(double radius, double height, const Placement& p) {
    return BRepPrimAPI_MakeCylinder(to_ax2(p), radius, height).Shape();
}

TopoDS_Shape make_sphere(double radius, const Placement& p) {
    return BRepPrimAPI_MakeSphere(to_ax2(p), radius).Shape();
}

TopoDS_Shape make_cone(double r1, double r2, double height, const Placement& p) {
    return BRepPrimAPI_MakeCone(to_ax2(p), r1, r2, height).Shape();
}

TopoDS_Shape make_torus(double major_r, double minor_r, const Placement& p) {
    return BRepPrimAPI_MakeTorus(to_ax2(p), major_r, minor_r).Shape();
}

double volume(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::VolumeProperties(s, props);
    return props.Mass();
}

double area(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(s, props);
    return props.Mass();
}

std::array<double, 3> center_of_mass(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::VolumeProperties(s, props);
    gp_Pnt c = props.CentreOfMass();
    return {c.X(), c.Y(), c.Z()};
}

TopoCounts count(const TopoDS_Shape& s) {
    // TopExp::MapShapes deduplicates shared subshapes (an edge belongs to two
    // faces but counts once), unlike TopExp_Explorer.
    auto unique_count = [&s](TopAbs_ShapeEnum kind) {
        sx::occt::ShapeIndexedMap map;
        TopExp::MapShapes(s, kind, map);
        return map.Extent();
    };
    TopoCounts tc;
    tc.solids = unique_count(TopAbs_SOLID);
    tc.shells = unique_count(TopAbs_SHELL);
    tc.faces = unique_count(TopAbs_FACE);
    tc.edges = unique_count(TopAbs_EDGE);
    tc.vertices = unique_count(TopAbs_VERTEX);
    return tc;
}

bool is_valid(const TopoDS_Shape& s) {
    if (s.IsNull()) return false;
    BRepCheck_Analyzer analyzer(s);
    return analyzer.IsValid() == Standard_True;
}

std::string to_brep_string(const TopoDS_Shape& s) {
    std::ostringstream oss;
    BRepTools::Write(s, oss);
    return oss.str();
}

TopoDS_Shape from_brep_string(const std::string& data) {
    std::istringstream iss(data);
    TopoDS_Shape shape;
    BRep_Builder builder;
    BRepTools::Read(shape, iss, builder);
    return shape;
}

static std::string fmt(double v) {
    char buf[32];
    std::snprintf(buf, sizeof(buf), "%.4g", v);
    return buf;
}

std::string describe_face(const TopoDS_Shape& face) {
    if (face.IsNull() || face.ShapeType() != TopAbs_FACE) return "invalid face";
    BRepAdaptor_Surface surf(TopoDS::Face(face));
    std::string type;
    std::string extra;
    switch (surf.GetType()) {
        case GeomAbs_Plane: {
            type = "planar face";
            gp_Dir n = surf.Plane().Axis().Direction();
            if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
            extra = ", normal (" + fmt(n.X()) + ", " + fmt(n.Y()) + ", " + fmt(n.Z()) + ")";
            break;
        }
        case GeomAbs_Cylinder:
            type = "cylindrical face";
            extra = ", radius " + fmt(surf.Cylinder().Radius()) + " mm";
            break;
        case GeomAbs_Cone:
            type = "conical face";
            extra = ", half-angle " + fmt(surf.Cone().SemiAngle() * 180.0 / M_PI) + " deg";
            break;
        case GeomAbs_Sphere:
            type = "spherical face";
            extra = ", radius " + fmt(surf.Sphere().Radius()) + " mm";
            break;
        case GeomAbs_Torus:
            type = "toroidal face";
            extra = ", major radius " + fmt(surf.Torus().MajorRadius()) + " mm";
            break;
        default:
            type = "freeform face";
    }
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    return type + ", area " + fmt(props.Mass()) + " mm^2" + extra;
}

std::string describe_edge(const TopoDS_Shape& edge) {
    if (edge.IsNull() || edge.ShapeType() != TopAbs_EDGE) return "invalid edge";
    BRepAdaptor_Curve curve(TopoDS::Edge(edge));
    std::string type;
    switch (curve.GetType()) {
        case GeomAbs_Line: type = "linear edge"; break;
        case GeomAbs_Circle: type = "circular edge, radius " + fmt(curve.Circle().Radius()) + " mm"; break;
        case GeomAbs_Ellipse: type = "elliptical edge"; break;
        case GeomAbs_BSplineCurve: type = "spline edge"; break;
        default: type = "curved edge";
    }
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return type + ", length " + fmt(props.Mass()) + " mm";
}

}  // namespace sx::shape
