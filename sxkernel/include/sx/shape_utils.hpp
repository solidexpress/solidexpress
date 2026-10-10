#pragma once
// OCCT convenience layer: primitive construction, measurement, topology counts.

#include <TopoDS_Shape.hxx>
#include <array>
#include <string>

namespace sx::shape {

struct Placement {
    // Position + Z-axis direction + X-axis reference; identity by default.
    std::array<double, 3> origin{0, 0, 0};
    std::array<double, 3> z_dir{0, 0, 1};
    std::array<double, 3> x_dir{1, 0, 0};
};

TopoDS_Shape make_box(double dx, double dy, double dz, const Placement& p = {});
TopoDS_Shape make_cylinder(double radius, double height, const Placement& p = {});
TopoDS_Shape make_sphere(double radius, const Placement& p = {});
TopoDS_Shape make_cone(double r1, double r2, double height, const Placement& p = {});
TopoDS_Shape make_torus(double major_r, double minor_r, const Placement& p = {});

double volume(const TopoDS_Shape& s);
double area(const TopoDS_Shape& s);
std::array<double, 3> center_of_mass(const TopoDS_Shape& s);

struct TopoCounts {
    int solids = 0, shells = 0, faces = 0, edges = 0, vertices = 0;
};
TopoCounts count(const TopoDS_Shape& s);

bool is_valid(const TopoDS_Shape& s);

// Serialize/deserialize a shape as OCCT BREP text.
std::string to_brep_string(const TopoDS_Shape& s);
TopoDS_Shape from_brep_string(const std::string& data);

// One-line geometric description of a subshape ("planar face, area 100 mm^2,
// normal +Z") used in semantic card digests.
std::string describe_face(const TopoDS_Shape& face);

}  // namespace sx::shape
