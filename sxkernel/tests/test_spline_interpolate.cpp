// One spline definition: GeomAPI_Interpolate through fit points.

#include <catch.hpp>

#include <cmath>
#include <memory>
#include <string>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <Geom_BSplineCurve.hxx>
#include <NCollection_Array1.hxx>
#include <gp_Pnt.hxx>

#include "sx/sketch.hpp"
#include "sx/sketch_json.hpp"
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

Handle(Geom_BSplineCurve) curve_from_geom(const Sketch::SplineGeom& g) {
    if (!g.ok || g.poles.size() < 2 || g.knots.empty() ||
        g.knots.size() != g.multiplicities.size())
        return {};
    NCollection_Array1<gp_Pnt> poles(1, static_cast<int>(g.poles.size()));
    for (int i = 0; i < static_cast<int>(g.poles.size()); ++i)
        poles.SetValue(i + 1, gp_Pnt(g.poles[static_cast<size_t>(i)][0],
                                     g.poles[static_cast<size_t>(i)][1], 0));
    NCollection_Array1<double> knots(1, static_cast<int>(g.knots.size()));
    NCollection_Array1<int> mults(1, static_cast<int>(g.knots.size()));
    for (int i = 0; i < static_cast<int>(g.knots.size()); ++i) {
        knots.SetValue(i + 1, g.knots[static_cast<size_t>(i)]);
        mults.SetValue(i + 1, g.multiplicities[static_cast<size_t>(i)]);
    }
    return new Geom_BSplineCurve(poles, knots, mults, g.degree, false);
}

}  // namespace

TEST_CASE("spline interpolate: kernel edge through fit points", "[spline][interpolate]") {
    Sketch sk;
    const EntityId id = sk.add_spline(kZigzag);
    REQUIRE_FALSE(id.is_null());
    const TopoDS_Edge edge = sk.spline_edge(id);
    REQUIRE_FALSE(edge.IsNull());
    BRepAdaptor_Curve curve(edge);
    CHECK(curve.GetType() == GeomAbs_BSplineCurve);
    for (const auto& uv : kZigzag) {
        const gp_Pnt p(uv[0], uv[1], 0);
        CHECK(dist_edge(p, edge) <= 1e-9);
    }
}

TEST_CASE("spline interpolate: samples lie on the kernel curve", "[spline][interpolate]") {
    Sketch sk;
    const EntityId id = sk.add_spline(kZigzag);
    const TopoDS_Edge edge = sk.spline_edge(id);
    auto samples = sk.spline_samples(id, 100);
    REQUIRE(samples.size() == 100);
    for (const auto& uv : samples) {
        CHECK(dist_edge(gp_Pnt(uv[0], uv[1], 0), edge) <= 1e-6);
    }
}

TEST_CASE("spline interpolate: solver geom matches kernel at 100 parameters",
          "[spline][interpolate]") {
    Sketch sk;
    const EntityId id = sk.add_spline(kZigzag);
    const TopoDS_Edge edge = sk.spline_edge(id);
    auto geom = sk.spline_geom(id);
    REQUIRE(geom.ok);
    Handle(Geom_BSplineCurve) solver_c = curve_from_geom(geom);
    REQUIRE_FALSE(solver_c.IsNull());
    const double u0 = solver_c->FirstParameter();
    const double u1 = solver_c->LastParameter();
    for (int i = 0; i < 100; ++i) {
        const double t = u0 + (u1 - u0) * (static_cast<double>(i) / 99.0);
        const gp_Pnt p = solver_c->Value(t);
        CHECK(dist_edge(p, edge) <= 1e-6);
    }
    auto preview = Sketch::interpolate_samples(kZigzag, 100);
    REQUIRE(preview.size() == 100);
    for (const auto& uv : preview) {
        CHECK(dist_edge(gp_Pnt(uv[0], uv[1], 0), edge) <= 1e-6);
    }
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    const TopoDS_Edge after = sk.spline_edge(id);
    for (const auto& uv : kZigzag) {
        CHECK(dist_edge(gp_Pnt(uv[0], uv[1], 0), after) <= 1e-9);
    }
}

TEST_CASE("spline interpolate: save/load fit points bit-identical", "[spline][interpolate]") {
    Sketch sk;
    const EntityId id = sk.add_spline(kZigzag);
    const auto before = sk.spline_fit_points(id);
    REQUIRE(before.size() == 5);
    auto loaded = sketch_from_json(sketch_to_json(sk));
    REQUIRE(loaded);
    EntityId lid;
    for (const auto& e : loaded->entities()) {
        if (e.type == SketchEntityType::Spline) lid = e.id;
    }
    REQUIRE_FALSE(lid.is_null());
    const auto after = loaded->spline_fit_points(lid);
    REQUIRE(after.size() == before.size());
    for (size_t i = 0; i < before.size(); ++i) {
        CHECK(after[i][0] == before[i][0]);
        CHECK(after[i][1] == before[i][1]);
    }
}
