#include <catch.hpp>
#include <array>
#include <cmath>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>

#include "sx/sketch.hpp"
#include "sx/sketch_tools.hpp"
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

TEST_CASE("trimmed 55x50 ellipse C contour area", "[sketch][rung07]") {
    constexpr double kPi = 3.14159265358979323846;
    constexpr double kDeg = 17.0 * kPi / 180.0;
    auto world = [&](double xp, double yp) {
        return std::array<double, 2>{
            xp * std::cos(kDeg) - yp * std::sin(kDeg),
            xp * std::sin(kDeg) + yp * std::cos(kDeg)};
    };
    const double xj = -25.0 * std::sqrt(1.0 - (12.5 / 27.5) * (12.5 / 27.5));
    Sketch sk("SpannerC");
    auto ell = sk.add_ellipse(0.0, 0.0, 27.5, 25.0, kDeg + kPi * 0.5);
    auto o_hi = world(xj, 12.5);
    auto o_lo = world(xj, -12.5);
    auto i_hi = world(xj + 20.0, 12.5);
    auto i_lo = world(xj + 20.0, -12.5);
    sk.add_line(o_hi[0], o_hi[1], i_hi[0], i_hi[1]);
    sk.add_line(o_lo[0], o_lo[1], i_lo[0], i_lo[1]);
    const double cx_local = (xj + 20.0) - std::sqrt(15.0 * 15.0 - 12.5 * 12.5);
    auto c15 = world(cx_local, 0.0);
    auto throat = world(cx_local + 15.0, 0.0);
    double sa = std::atan2(i_lo[1] - c15[1], i_lo[0] - c15[0]);
    double ea = std::atan2(i_hi[1] - c15[1], i_hi[0] - c15[0]);
    if (ea < sa) ea += 2.0 * kPi;
    double mid = std::atan2(throat[1] - c15[1], throat[0] - c15[0]);
    double from = mid - sa;
    while (from < 0) from += 2.0 * kPi;
    if (from > ea - sa + 1e-9) {
        std::swap(sa, ea);
        if (ea < sa) ea += 2.0 * kPi;
    }
    sk.add_arc(c15[0], c15[1], 15.0, sa, ea);
    auto pick = world(-25.0, 0.0);
    REQUIRE(sketch_tools::trim_entity(sk, ell.str(), pick[0], pick[1]));
    bool full = false;
    bool arc = false;
    for (const auto& e : sk.entities()) {
        if (e.type == SketchEntityType::Ellipse) full = true;
        if (e.type == SketchEntityType::EllipticalArc) arc = true;
    }
    REQUIRE_FALSE(full);
    REQUIRE(arc);

    std::string err;
    auto face = sk.profile_face(&err);
    INFO(err);
    REQUIRE_FALSE(face.IsNull());
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    REQUIRE(props.Mass() == Approx(1495.80).epsilon(0.01));
    auto contours = sk.contour_faces(&err);
    INFO(err);
    REQUIRE(contours.size() == 1);
}
