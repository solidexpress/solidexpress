#include <catch.hpp>
#include <cmath>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>

#include "sx/sketch.hpp"
#include "sx/solver.hpp"

using namespace sx;

TEST_CASE("ellipse 35x10 profile area", "[sketch][rung06]") {
    Sketch sk("Ellipse");
    auto id = sk.add_ellipse(0.0, 0.0, 17.5, 5.0, 0.0);
    REQUIRE_FALSE(id.is_null());
    const SketchEntity* e = sk.entity(id);
    REQUIRE(e != nullptr);
    REQUIRE(e->type == SketchEntityType::Ellipse);
    auto ax = sk.ellipse_axes(id);
    REQUIRE(ax.has_value());
    REQUIRE((*ax)[2] == Approx(17.5).margin(1e-6));
    REQUIRE((*ax)[3] == Approx(5.0).margin(1e-6));

    auto solver = make_planegcs_backend();
    auto result = solver->solve(sk);
    REQUIRE((result.status == SolveStatus::Success || result.status == SolveStatus::Converged));

    std::string err;
    auto face = sk.profile_face(&err);
    REQUIRE_FALSE(face.IsNull());
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    const double area = props.Mass();
    const double want = 3.14159265358979323846 * 17.5 * 5.0;
    REQUIRE(area == Approx(want).epsilon(0.005));
}

TEST_CASE("ellipse stays an ellipse after solve", "[sketch][rung06]") {
    Sketch sk("Handle");
    auto id = sk.add_ellipse(0.0, 0.0, 17.5, 5.0, 0.0);
    auto solver = make_planegcs_backend();
    auto result = solver->solve(sk);
    REQUIRE((result.status == SolveStatus::Success || result.status == SolveStatus::Converged));
    auto ax = sk.ellipse_axes(id);
    REQUIRE(ax.has_value());
    REQUIRE((*ax)[2] * 2.0 == Approx(35.0).margin(0.2));
    REQUIRE((*ax)[3] * 2.0 == Approx(10.0).margin(0.2));
}

TEST_CASE("ellipse axes plus centre pin fully define", "[sketch][rung06]") {
    Sketch sk("Handle");
    auto id = sk.add_ellipse(1.0, 2.0, 17.5, 5.0, 0.1);
    auto pin = sk.add_point(0.0, 0.0);
    sk.add_constraint(ConstraintType::Fix, {{pin, PointRole::Self}}, 0.0);
    sk.add_constraint(ConstraintType::Horizontal,
                      {{id, PointRole::Start}, {id, PointRole::End}}, 0.0);
    sk.add_constraint(ConstraintType::Distance,
                      {{id, PointRole::Start}, {id, PointRole::End}}, 35.0);
    sk.add_constraint(ConstraintType::Distance,
                      {{id, PointRole::MinorStart}, {id, PointRole::MinorEnd}}, 10.0);
    sk.add_constraint(ConstraintType::Coincident,
                      {{id, PointRole::Center}, {pin, PointRole::Self}}, 0.0);
    auto solver = make_planegcs_backend();
    auto result = solver->solve(sk);
    REQUIRE((result.status == SolveStatus::Success || result.status == SolveStatus::Converged));
    REQUIRE(result.dofs == 0);
    auto ax = sk.ellipse_axes(id);
    REQUIRE(ax.has_value());
    REQUIRE((*ax)[0] == Approx(0.0).margin(0.2));
    REQUIRE((*ax)[1] == Approx(0.0).margin(0.2));
    REQUIRE((*ax)[2] * 2.0 == Approx(35.0).margin(0.2));
    REQUIRE((*ax)[3] * 2.0 == Approx(10.0).margin(0.2));
}
