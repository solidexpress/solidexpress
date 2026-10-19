// Spline editing: fit-point drag and spline-end Tangent to a line.

#include <catch.hpp>

#include <array>
#include <cmath>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <gp_Pnt.hxx>

#include "sx/sketch.hpp"
#include "sx/solver.hpp"

using namespace sx;

namespace {

const std::vector<std::array<double, 2>> kZigzag = {
    {0, 0}, {10, 8}, {20, -4}, {30, 6}, {40, 0},
};

double dist_edge(const gp_Pnt& p, const TopoDS_Edge& edge) {
    BRepExtrema_DistShapeShape d(BRepBuilderAPI_MakeVertex(p).Vertex(), edge);
    if (!d.IsDone() || d.NbSolution() < 1) return 1e9;
    return d.Value();
}

double parallel_err(std::array<double, 2> a, std::array<double, 2> b) {
    const double na = std::hypot(a[0], a[1]);
    const double nb = std::hypot(b[0], b[1]);
    if (na < 1e-12 || nb < 1e-12) return 1e9;
    return std::abs(a[0] * b[1] - a[1] * b[0]) / (na * nb);
}

}  // namespace

TEST_CASE("spline edit: fit-point drag keeps interpolant through the point",
          "[spline][edit]") {
    Sketch sk;
    const EntityId id = sk.add_spline(kZigzag);
    REQUIRE(sk.set_spline_fit_point(id, 2, 20, 12));
    const TopoDS_Edge edge = sk.spline_edge(id);
    CHECK(dist_edge(gp_Pnt(20, 12, 0), edge) <= 1e-6);
    CHECK(dist_edge(gp_Pnt(0, 0, 0), edge) <= 1e-6);
    CHECK(dist_edge(gp_Pnt(40, 0, 0), edge) <= 1e-6);
}

TEST_CASE("spline edit: tangent to a line matches end derivative", "[spline][edit]") {
    Sketch sk;
    const EntityId sid = sk.add_spline(kZigzag);
    const EntityId lid = sk.add_line(40, 0, 50, 10);
    sk.add_constraint(ConstraintType::Coincident,
                      {{sid, PointRole::End}, {lid, PointRole::Start}}, 0.0);
    sk.add_constraint(ConstraintType::Tangent,
                      {{sid, PointRole::End}, {lid, PointRole::Self}}, 0.0);
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    const auto der = sk.spline_end_derivative(sid, false);
    CHECK(parallel_err(der, {10, 10}) <= 1e-6);
}
