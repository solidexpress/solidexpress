// Pierce points come from GeomAPI_IntCS / Circle(), not tessellated polylines.

#include <catch.hpp>

#include <cmath>
#include <vector>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch3d.hpp"

using namespace sx;

TEST_CASE("pierce of Ø45 circle on a 30° plane lands on the true circle", "[pierce][kernel]") {
    Document doc;
    gp_Circ circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 22.5);
    doc.add_body(BRepBuilderAPI_MakeEdge(circ).Edge(), "rim");

    const double deg30 = 3.14159265358979323846 / 6.0;
    SketchPlane plane;
    plane.origin = {0, 0, 0};
    plane.x_dir = {1, 0, 0};
    plane.y_dir = {0, std::cos(deg30), std::sin(deg30)};

    auto pts = pierce_uvs(doc, plane);
    REQUIRE(pts.size() >= 2);
    int on_circle = 0;
    for (const auto& uv : pts) {
        // Plane contains +X; UV (u,v) maps to world (u, v cos30, v sin30).
        const double x = uv[0];
        const double y = uv[1] * std::cos(deg30);
        const double z = uv[1] * std::sin(deg30);
        const double r = std::hypot(x, y);
        if (std::abs(z) < 1e-6 && std::abs(r - 22.5) <= 1e-6) ++on_circle;
    }
    CHECK(on_circle >= 2);
}

TEST_CASE("pierce of a Ø45 cylinder matches Circle() rims", "[pierce][kernel]") {
    Document doc;
    BRepPrimAPI_MakeCylinder mk(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 22.5, 40.0);
    doc.add_body(mk.Solid(), "cyl");

    SketchPlane plane;
    plane.origin = {0, 0, 0};
    plane.x_dir = {1, 0, 0};
    plane.y_dir = {0, 1, 0};  // XY: bottom rim lies in the plane — no pierce of that circle
    // A vertical plane through the axis: YZ (x = 0) cuts both rims at y = ±22.5.
    SketchPlane yz;
    yz.origin = {0, 0, 0};
    yz.x_dir = {0, 1, 0};
    yz.y_dir = {0, 0, 1};
    auto pts = pierce_uvs(doc, yz);
    REQUIRE(pts.size() >= 2);
    int on_rims = 0;
    for (const auto& uv : pts) {
        const double y = uv[0];
        const double z = uv[1];
        const double r = std::abs(y);
        const bool at_end = std::abs(z) <= 1e-6 || std::abs(z - 40.0) <= 1e-6;
        if (at_end && std::abs(r - 22.5) <= 1e-6) ++on_rims;
    }
    CHECK(on_rims >= 2);
}
