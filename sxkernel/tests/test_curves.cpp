#include <catch.hpp>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBndLib.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include "sx/occt_types.hpp"
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <stdexcept>

#include "sx/curves.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

namespace {

double wire_length(const TopoDS_Wire& w) {
    GProp_GProps props;
    BRepGProp::LinearProperties(w, props);
    return props.Mass();
}

Bnd_Box wire_bbox(const TopoDS_Wire& w) {
    Bnd_Box box;
    BRepBndLib::Add(w, box);
    return box;
}

gp_Pnt sample_helix_point(const TopoDS_Wire& w, double t01) {
    TopExp_Explorer ex(w, TopAbs_EDGE);
    REQUIRE(ex.More());
    BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
    const double u = c.FirstParameter() + t01 * (c.LastParameter() - c.FirstParameter());
    return c.Value(u);
}

}  // namespace

TEST_CASE("helix length and height", "[curves]") {
    const double r = 10.0;
    const double pitch = 5.0;
    const double turns = 3.0;
    gp_Ax2 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

    TopoDS_Wire w = curves::helix(axis, r, pitch, turns);
    REQUIRE_FALSE(w.IsNull());
    REQUIRE(shape::is_valid(w));

    const double analytic = turns * std::sqrt(std::pow(2.0 * M_PI * r, 2) + pitch * pitch);
    REQUIRE(wire_length(w) == Approx(analytic).epsilon(0.005));

    Bnd_Box box = wire_bbox(w);
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    REQUIRE(z1 - z0 == Approx(pitch * turns).margin(0.05));
}

TEST_CASE("left-handed helix mirrors right-handed", "[curves]") {
    const double r = 10.0;
    const double pitch = 5.0;
    const double turns = 2.0;
    gp_Ax2 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

    TopoDS_Wire rh = curves::helix(axis, r, pitch, turns, /*left_handed=*/false);
    TopoDS_Wire lh = curves::helix(axis, r, pitch, turns, /*left_handed=*/true);
    REQUIRE(shape::is_valid(rh));
    REQUIRE(shape::is_valid(lh));

    // Mid-turn sample: Y should flip sign between right- and left-handed.
    gp_Pnt pr = sample_helix_point(rh, 0.25);
    gp_Pnt pl = sample_helix_point(lh, 0.25);
    REQUIRE(pr.Y() == Approx(-pl.Y()).margin(1e-3));
    REQUIRE(pr.X() == Approx(pl.X()).margin(1e-3));
    REQUIRE(pr.Z() == Approx(pl.Z()).margin(1e-3));

    // Bounding boxes match (same cylindrical envelope).
    Bnd_Box br = wire_bbox(rh);
    Bnd_Box bl = wire_bbox(lh);
    double rx0, ry0, rz0, rx1, ry1, rz1;
    double lx0, ly0, lz0, lx1, ly1, lz1;
    br.Get(rx0, ry0, rz0, rx1, ry1, rz1);
    bl.Get(lx0, ly0, lz0, lx1, ly1, lz1);
    REQUIRE(rx0 == Approx(lx0).margin(1e-3));
    REQUIRE(ry0 == Approx(ly0).margin(1e-3));
    REQUIRE(rz0 == Approx(lz0).margin(1e-3));
    REQUIRE(rx1 == Approx(lx1).margin(1e-3));
    REQUIRE(ry1 == Approx(ly1).margin(1e-3));
    REQUIRE(rz1 == Approx(lz1).margin(1e-3));
}

TEST_CASE("spiral bounds and outer radius", "[curves]") {
    gp_Ax2 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    const double r0 = 5.0;
    const double r1 = 20.0;
    const double turns = 2.0;

    TopoDS_Wire w = curves::spiral(axis, r0, r1, turns);
    REQUIRE_FALSE(w.IsNull());
    REQUIRE(shape::is_valid(w));

    const double len = wire_length(w);
    const double lo = turns * 2.0 * M_PI * r0;
    const double hi = turns * 2.0 * M_PI * r1;
    REQUIRE(len > lo);
    REQUIRE(len < hi);

    Bnd_Box box = wire_bbox(w);
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    const double rx = std::max(std::abs(x0), std::abs(x1));
    const double ry = std::max(std::abs(y0), std::abs(y1));
    const double outer = std::max(rx, ry);
    REQUIRE(outer == Approx(r1).margin(0.5));
    REQUIRE(std::abs(z1 - z0) < 1e-3);
}

TEST_CASE("polyline edges and validation", "[curves]") {
    TopoDS_Wire w = curves::polyline({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 0)});
    REQUIRE_FALSE(w.IsNull());
    REQUIRE(shape::is_valid(w));

    sx::occt::ShapeIndexedMap edges;
    TopExp::MapShapes(w, TopAbs_EDGE, edges);
    REQUIRE(edges.Extent() == 2);

    // Documented: fewer than two points throws (does not return a null wire).
    REQUIRE_THROWS_AS(curves::polyline({gp_Pnt(0, 0, 0)}), std::runtime_error);
    REQUIRE_THROWS_AS(curves::polyline({}), std::runtime_error);
}

TEST_CASE("pipe shell along helix produces solid", "[curves]") {
    // Frenet trihedron (SetMode default) follows a helix cleanly; matches the
    // single-edge spine path used by SweepCommand when edges.Extent() <= 1
    // would use MakePipe — here we exercise MakePipeShell + MakeSolid explicitly.
    gp_Ax2 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    const double helix_r = 10.0;
    const double pitch = 8.0;
    TopoDS_Wire spine = curves::helix(axis, helix_r, pitch, /*turns=*/1.0);
    REQUIRE(shape::is_valid(spine));

    // Small circle at helix start (r, 0, 0); withCorrection relocates/orients it.
    const double profile_r = 1.0;
    gp_Circ circ(gp_Ax2(gp_Pnt(helix_r, 0, 0), gp_Dir(0, 0, 1)), profile_r);
    TopoDS_Wire profile = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(circ).Edge()).Wire();

    BRepOffsetAPI_MakePipeShell shell(spine);
    shell.SetMode();  // Frenet
    shell.Add(profile, /*withContact=*/Standard_False, /*withCorrection=*/Standard_True);
    shell.Build();
    REQUIRE(shell.IsDone());
    REQUIRE(shell.MakeSolid());

    TopoDS_Shape solid = shell.Shape();
    REQUIRE_FALSE(solid.IsNull());
    REQUIRE(shape::is_valid(solid));
    REQUIRE(shape::count(solid).solids >= 1);
    REQUIRE(shape::volume(solid) > 0.0);
}
