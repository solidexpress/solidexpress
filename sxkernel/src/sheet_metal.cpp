#include "sx/sheet_metal.hpp"

#include <algorithm>
#include <cmath>
#include <vector>

#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <Bnd_Box.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

namespace sx::sheet {

double bend_allowance(double angle_rad, double thickness, double k_factor, double radius) {
    return std::abs(angle_rad) * (radius + k_factor * thickness);
}

double flat_length(double leg1, double leg2, double thickness, double k_factor, double radius,
                   double angle_rad) {
    const double ba = bend_allowance(angle_rad, thickness, k_factor, radius);
    // Outside legs include the bend region once each; subtract thickness so
    // the flat is the developed inside + allowance.
    return std::max(0.0, leg1 + leg2 + ba - 2.0 * thickness);
}

void to_json(nlohmann::json& j, const FlangeParams& p) {
    j = nlohmann::json{{"length", p.length},
                       {"thickness", p.thickness},
                       {"k_factor", p.k_factor},
                       {"radius", p.radius},
                       {"angle_rad", p.angle_rad}};
}

void from_json(const nlohmann::json& j, FlangeParams& p) {
    p.length = j.value("length", 20.0);
    p.thickness = j.value("thickness", 1.5);
    p.k_factor = j.value("k_factor", 0.44);
    p.radius = j.value("radius", 1.5);
    p.angle_rad = j.value("angle_rad", 1.5707963267948966);
}

namespace {

// Section point: the bend cross-section is drawn in XZ and swept along +Y.
gp_Pnt sec(double x, double z) { return gp_Pnt(x, 0.0, z); }

void add_line(BRepBuilderAPI_MakeWire& wire, const gp_Pnt& a, const gp_Pnt& b) {
    if (a.Distance(b) < 1e-9) return;
    BRepBuilderAPI_MakeEdge edge(a, b);
    if (edge.IsDone()) wire.Add(edge.Edge());
}

// Arc of `radius` about `center` from angle a0 to a1, measured in the section
// plane from the -Z direction (the bend starts tangent to the flat leg).
void add_bend_arc(BRepBuilderAPI_MakeWire& wire, double cx, double cz, double radius, double a0,
                  double a1) {
    auto at = [&](double a) { return sec(cx + radius * std::sin(a), cz - radius * std::cos(a)); };
    Handle(Geom_TrimmedCurve) arc =
        GC_MakeArcOfCircle(at(a0), at(0.5 * (a0 + a1)), at(a1)).Value();
    BRepBuilderAPI_MakeEdge edge(arc);
    if (edge.IsDone()) wire.Add(edge.Edge());
}

}  // namespace

FlangeBuild build_flange(double base_leg, double flange_leg, double width, const FlangeParams& p,
                         const shape::Placement& at, std::string* err) {
    FlangeBuild out;
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return out;
    };
    const double t = p.thickness;
    const double r = p.radius;
    const double a = p.angle_rad;
    if (t <= 1e-9 || width <= 1e-9) return bail("thickness and width must be positive");
    if (r <= 1e-9) return bail("bend radius must be positive");
    if (a <= 1e-9 || a >= M_PI) return bail("bend angle must be between 0 and pi");
    // Straight (unbent) run of each leg; the remainder is the bend region.
    const double s1 = base_leg - t;
    const double s2 = flange_leg - t;
    if (s1 <= 1e-9 || s2 <= 1e-9) return bail("each leg must be longer than the thickness");

    out.bend_allowance = bend_allowance(a, t, p.k_factor, r);
    out.flat_length = flat_length(base_leg, flange_leg, t, p.k_factor, r, a);

    // Bend center sits above the inner surface where the base leg ends.
    const double cx = s1, cz = t + r;
    const gp_Vec tangent(std::cos(a), 0.0, std::sin(a));  // flange run direction
    const gp_Pnt inner_arc_end = sec(cx + r * std::sin(a), cz - r * std::cos(a));
    const gp_Pnt outer_arc_end = sec(cx + (r + t) * std::sin(a), cz - (r + t) * std::cos(a));
    const gp_Pnt inner_tip = inner_arc_end.Translated(tangent * s2);
    const gp_Pnt outer_tip = outer_arc_end.Translated(tangent * s2);

    BRepBuilderAPI_MakeWire wire;
    add_line(wire, sec(0.0, 0.0), sec(s1, 0.0));            // base leg, outer face
    add_bend_arc(wire, cx, cz, r + t, 0.0, a);              // bend, outer face
    add_line(wire, outer_arc_end, outer_tip);               // flange leg, outer face
    add_line(wire, outer_tip, inner_tip);                   // flange tip
    add_line(wire, inner_tip, inner_arc_end);               // flange leg, inner face
    add_bend_arc(wire, cx, cz, r, a, 0.0);                  // bend, inner face
    add_line(wire, sec(s1, t), sec(0.0, t));                // base leg, inner face
    add_line(wire, sec(0.0, t), sec(0.0, 0.0));             // base leg end
    if (!wire.IsDone()) return bail("bend section did not close");

    BRepBuilderAPI_MakeFace face(wire.Wire(), true);
    if (!face.IsDone()) return bail("bend section is not planar");
    TopoDS_Shape folded = BRepPrimAPI_MakePrism(face.Face(), gp_Vec(0.0, width, 0.0)).Shape();
    if (folded.IsNull()) return bail("sweep failed");

    gp_Trsf place;
    place.SetTransformation(
        gp_Ax3(gp_Pnt(at.origin[0], at.origin[1], at.origin[2]),
               gp_Dir(at.z_dir[0], at.z_dir[1], at.z_dir[2]),
               gp_Dir(at.x_dir[0], at.x_dir[1], at.x_dir[2])),
        gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    out.folded = BRepBuilderAPI_Transform(folded, place, true).Shape();
    out.flat = shape::make_box(out.flat_length, width, t, at);
    return out;
}

bool is_thin_solid(const TopoDS_Shape& s, double* thickness) {
    if (s.IsNull()) return false;
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    if (box.IsVoid()) return false;
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    const double dx = xmax - xmin, dy = ymax - ymin, dz = zmax - zmin;
    const double t = std::min({dx, dy, dz});
    const double m = std::max({dx, dy, dz});
    if (t < 1e-6 || t > m * 0.25) return false;
    if (thickness) *thickness = t;
    return true;
}

double flat_area(const TopoDS_Shape& s) {
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    if (box.IsVoid()) return 0.0;
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    double d[3] = {xmax - xmin, ymax - ymin, zmax - zmin};
    std::sort(d, d + 3);
    return d[1] * d[2];
}

TopoDS_Shape unfold_thin_solid(const TopoDS_Shape& s, std::string* err) {
    double t = 0.0;
    if (!is_thin_solid(s, &t)) {
        if (err) *err = "solid is not a thin sheet";
        return {};
    }
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    double d[3] = {xmax - xmin, ymax - ymin, zmax - zmin};
    std::sort(d, d + 3);
    return shape::make_box(d[2], d[1], t);
}

}  // namespace sx::sheet
