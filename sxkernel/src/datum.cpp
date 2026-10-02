#include "sx/datum.hpp"

#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_Surface.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <stdexcept>

namespace sx {
namespace {

constexpr double kEps = 1e-12;

EntityId resolve_id(const EntityId& keep_id) {
    return keep_id.is_null() ? EntityId::generate() : keep_id;
}

std::array<double, 3> to_arr(const gp_Pnt& p) { return {p.X(), p.Y(), p.Z()}; }
std::array<double, 3> to_arr(const gp_Dir& d) { return {d.X(), d.Y(), d.Z()}; }
std::array<double, 3> to_arr(const gp_Vec& v) { return {v.X(), v.Y(), v.Z()}; }

gp_Pnt to_pnt(const std::array<double, 3>& a) { return gp_Pnt(a[0], a[1], a[2]); }
gp_Vec to_vec(const std::array<double, 3>& a) { return gp_Vec(a[0], a[1], a[2]); }

std::array<double, 3> normalized(const std::array<double, 3>& v) {
    const double len = std::sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (len < kEps) return {0, 0, 0};
    return {v[0] / len, v[1] / len, v[2] / len};
}

Handle(Geom_Surface) basis_surface(const Handle(Geom_Surface)& surf) {
    Handle(Geom_RectangularTrimmedSurface) trimmed =
        Handle(Geom_RectangularTrimmedSurface)::DownCast(surf);
    if (!trimmed.IsNull()) return trimmed->BasisSurface();
    return surf;
}

nlohmann::json vec_to_json(const std::array<double, 3>& v) {
    return nlohmann::json::array({v[0], v[1], v[2]});
}

std::array<double, 3> vec_from_json(const nlohmann::json& j) {
    return {j.at(0).get<double>(), j.at(1).get<double>(), j.at(2).get<double>()};
}

}  // namespace

std::array<double, 3> DatumPlane::y_dir() const {
    return normalized({normal[1] * x_dir[2] - normal[2] * x_dir[1],
                       normal[2] * x_dir[0] - normal[0] * x_dir[2],
                       normal[0] * x_dir[1] - normal[1] * x_dir[0]});
}

void to_json(nlohmann::json& j, const DatumPlane& p) {
    j = nlohmann::json{{"id", p.id.str()},
                       {"name", p.name},
                       {"origin", vec_to_json(p.origin)},
                       {"normal", vec_to_json(p.normal)},
                       {"x_dir", vec_to_json(p.x_dir)}};
}

void from_json(const nlohmann::json& j, DatumPlane& p) {
    p.id = EntityId::from_string(j.at("id").get<std::string>());
    p.name = j.at("name").get<std::string>();
    p.origin = vec_from_json(j.at("origin"));
    p.normal = vec_from_json(j.at("normal"));
    p.x_dir = vec_from_json(j.at("x_dir"));
}

void to_json(nlohmann::json& j, const DatumAxis& a) {
    j = nlohmann::json{{"id", a.id.str()},
                       {"name", a.name},
                       {"point", vec_to_json(a.point)},
                       {"direction", vec_to_json(a.direction)}};
}

void from_json(const nlohmann::json& j, DatumAxis& a) {
    a.id = EntityId::from_string(j.at("id").get<std::string>());
    a.name = j.at("name").get<std::string>();
    a.point = vec_from_json(j.at("point"));
    a.direction = vec_from_json(j.at("direction"));
}

void to_json(nlohmann::json& j, const DatumPoint& p) {
    j = nlohmann::json{{"id", p.id.str()},
                       {"name", p.name},
                       {"position", vec_to_json(p.position)}};
}

void from_json(const nlohmann::json& j, DatumPoint& p) {
    p.id = EntityId::from_string(j.at("id").get<std::string>());
    p.name = j.at("name").get<std::string>();
    p.position = vec_from_json(j.at("position"));
}

namespace datum {

DatumPlane plane_xy(const EntityId& keep_id) {
    DatumPlane p;
    p.id = resolve_id(keep_id);
    p.name = "XY";
    p.origin = {0, 0, 0};
    p.normal = {0, 0, 1};
    p.x_dir = {1, 0, 0};
    return p;
}

DatumPlane plane_xz(const EntityId& keep_id) {
    DatumPlane p;
    p.id = resolve_id(keep_id);
    p.name = "XZ";
    p.origin = {0, 0, 0};
    p.normal = {0, 1, 0};
    p.x_dir = {1, 0, 0};
    return p;
}

DatumPlane plane_yz(const EntityId& keep_id) {
    DatumPlane p;
    p.id = resolve_id(keep_id);
    p.name = "YZ";
    p.origin = {0, 0, 0};
    p.normal = {1, 0, 0};
    p.x_dir = {0, 1, 0};
    return p;
}

DatumPlane plane_offset(const DatumPlane& src, double distance, const EntityId& keep_id) {
    DatumPlane p = src;
    p.id = resolve_id(keep_id);
    const auto n = normalized(src.normal);
    p.normal = n;
    p.x_dir = normalized(src.x_dir);
    p.origin = {src.origin[0] + n[0] * distance, src.origin[1] + n[1] * distance,
                src.origin[2] + n[2] * distance};
    return p;
}

DatumPlane plane_from_face(const TopoDS_Shape& face, const EntityId& keep_id) {
    if (face.IsNull() || face.ShapeType() != TopAbs_FACE)
        throw std::runtime_error("plane_from_face: shape is not a face");

    const TopoDS_Face f = TopoDS::Face(face);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
    if (surf.IsNull()) throw std::runtime_error("plane_from_face: null surface");

    Handle(Geom_Surface) basis = basis_surface(surf);
    gp_Pln pln;
    Handle(Geom_Plane) gplane = Handle(Geom_Plane)::DownCast(basis);
    if (!gplane.IsNull()) {
        pln = gplane->Pln();
    } else {
        GeomLib_IsPlanarSurface checker(basis);
        if (!checker.IsPlanar())
            throw std::runtime_error("plane_from_face: face is not planar");
        pln = checker.Plan();
    }

    double umin = 0, umax = 0, vmin = 0, vmax = 0;
    BRepTools::UVBounds(f, umin, umax, vmin, vmax);
    const gp_Pnt origin = surf->Value(0.5 * (umin + umax), 0.5 * (vmin + vmax));

    gp_Dir normal = pln.Axis().Direction();
    if (f.Orientation() == TopAbs_REVERSED) normal.Reverse();
    const gp_Dir x_dir = pln.XAxis().Direction();

    DatumPlane p;
    p.id = resolve_id(keep_id);
    p.name = "FacePlane";
    p.origin = to_arr(origin);
    p.normal = to_arr(normal);
    p.x_dir = to_arr(x_dir);
    return p;
}

DatumPlane plane_from_points(const std::array<double, 3>& p1,
                             const std::array<double, 3>& p2,
                             const std::array<double, 3>& p3,
                             const EntityId& keep_id) {
    const gp_Vec v12(to_pnt(p1), to_pnt(p2));
    const gp_Vec v13(to_pnt(p1), to_pnt(p3));
    gp_Vec n = v12.Crossed(v13);
    if (n.Magnitude() < kEps)
        throw std::runtime_error("plane_from_points: points are collinear");
    n.Normalize();

    gp_Vec x = v12;
    if (x.Magnitude() < kEps)
        throw std::runtime_error("plane_from_points: points are collinear");
    x.Normalize();

    DatumPlane p;
    p.id = resolve_id(keep_id);
    p.name = "ThreePointPlane";
    p.origin = p1;
    p.normal = to_arr(n);
    p.x_dir = to_arr(x);
    return p;
}

DatumAxis axis_from_points(const std::array<double, 3>& p1,
                           const std::array<double, 3>& p2,
                           const EntityId& keep_id) {
    gp_Vec d = to_vec({p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2]});
    if (d.Magnitude() < kEps)
        throw std::runtime_error("axis_from_points: points are coincident");
    d.Normalize();

    DatumAxis a;
    a.id = resolve_id(keep_id);
    a.name = "Axis";
    a.point = p1;
    a.direction = to_arr(d);
    return a;
}

DatumAxis axis_of_cylinder(const TopoDS_Shape& face, const EntityId& keep_id) {
    if (face.IsNull() || face.ShapeType() != TopAbs_FACE)
        throw std::runtime_error("axis_of_cylinder: shape is not a face");

    Handle(Geom_Surface) surf = basis_surface(BRep_Tool::Surface(TopoDS::Face(face)));
    Handle(Geom_CylindricalSurface) cyl = Handle(Geom_CylindricalSurface)::DownCast(surf);
    if (cyl.IsNull())
        throw std::runtime_error("axis_of_cylinder: face is not cylindrical");

    const gp_Ax1 ax = cyl->Axis();
    DatumAxis a;
    a.id = resolve_id(keep_id);
    a.name = "CylinderAxis";
    a.point = to_arr(ax.Location());
    a.direction = to_arr(ax.Direction());
    return a;
}

double angle_between(const DatumPlane& a, const DatumPlane& b) {
    const gp_Dir na(a.normal[0], a.normal[1], a.normal[2]);
    const gp_Dir nb(b.normal[0], b.normal[1], b.normal[2]);
    return na.Angle(nb);
}

}  // namespace datum
}  // namespace sx
