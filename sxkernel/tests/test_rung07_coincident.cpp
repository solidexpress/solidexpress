#include <catch.hpp>
#include <array>
#include <cmath>

#include "sx/sketch.hpp"
#include "sx/solver.hpp"

using namespace sx;

namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr double kDeg = 17.0 * kPi / 180.0;

std::array<double, 2> world(double xp, double yp) {
    return {xp * std::cos(kDeg) - yp * std::sin(kDeg),
            xp * std::sin(kDeg) + yp * std::cos(kDeg)};
}

double ellipse_implicit(const std::array<double, 5>& ax, double x, double y) {
    const double cx = ax[0], cy = ax[1], rx = ax[2], ry = ax[3], ang = ax[4];
    const double ca = std::cos(ang), sa = std::sin(ang);
    const double dx = x - cx, dy = y - cy;
    const double u = dx * ca + dy * sa;
    const double v = -dx * sa + dy * ca;
    return (u / rx) * (u / rx) + (v / ry) * (v / ry);
}

}  // namespace

TEST_CASE("coincident line end to ellipse stays on the curve", "[sketch][rung07]") {
    Sketch sk("JawOnEllipse");
    auto ell = sk.add_ellipse(0.0, 0.0, 27.5, 25.0, kDeg + kPi * 0.5);
    auto pin = sk.add_point(0.0, 0.0);
    sk.add_constraint(ConstraintType::Fix, {{pin, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{ell, PointRole::Center}, {pin, PointRole::Self}});
    const double xj = -25.0 * std::sqrt(1.0 - (12.5 / 27.5) * (12.5 / 27.5));
    auto o_hi = world(xj, 12.5);
    auto i_hi = world(xj + 20.0, 12.5);
    auto ln = sk.add_line(o_hi[0], o_hi[1], i_hi[0], i_hi[1]);
    sk.add_constraint(ConstraintType::Coincident,
                      {{ln, PointRole::Start}, {ell, PointRole::Self}});
    auto solver = make_planegcs_backend();
    auto result = solver->solve(sk);
    REQUIRE(result.ok());
    auto ax = sk.ellipse_axes(ell);
    REQUIRE(ax.has_value());
    REQUIRE((*ax)[0] == Approx(0.0).margin(0.05));
    REQUIRE((*ax)[1] == Approx(0.0).margin(0.05));
    const SketchEntity* e = sk.entity(ln);
    REQUIRE(e != nullptr);
    const double x = sk.param(e->params[0]);
    const double y = sk.param(e->params[1]);
    REQUIRE(std::hypot(x, y) > 10.0);
    REQUIRE(ellipse_implicit(*ax, x, y) == Approx(1.0).margin(0.02));
}

TEST_CASE("coincident handle end to ellipse stays at the y=10 hit",
          "[sketch][rung07]") {
    Sketch sk("HandleOnC");
    auto ell = sk.add_ellipse(0.0, 0.0, 27.5, 25.0, kDeg + kPi * 0.5);
    auto pin = sk.add_point(0.0, 0.0);
    sk.add_constraint(ConstraintType::Fix, {{pin, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{ell, PointRole::Center}, {pin, PointRole::Self}});
    auto ln = sk.add_line(22.944, 10.0, 120.0, 10.0);
    auto far = sk.add_point(120.0, 10.0);
    sk.add_constraint(ConstraintType::Fix, {{far, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{ln, PointRole::End}, {far, PointRole::Self}});
    sk.add_constraint(ConstraintType::Horizontal, {{ln, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{ln, PointRole::Start}, {ell, PointRole::Self}});
    auto solver = make_planegcs_backend();
    auto result = solver->solve(sk);
    REQUIRE(result.ok());
    const SketchEntity* e = sk.entity(ln);
    REQUIRE(e != nullptr);
    const double x = sk.param(e->params[0]);
    const double y = sk.param(e->params[1]);
    REQUIRE(y == Approx(10.0).margin(0.05));
    REQUIRE(x == Approx(22.944).margin(0.4));
    auto major = world(0.0, 27.5);
    REQUIRE(std::hypot(x - major[0], y - major[1]) > 15.0);
    auto ax = sk.ellipse_axes(ell);
    REQUIRE(ax.has_value());
    REQUIRE(ellipse_implicit(*ax, x, y) == Approx(1.0).margin(0.02));
}

TEST_CASE("coincident line end to circle sits on the radius", "[sketch][rung07]") {
    Sketch sk("HandleOnRing");
    auto circ = sk.add_circle(240.0, 0.0, 16.5);
    auto pin = sk.add_point(240.0, 0.0);
    sk.add_constraint(ConstraintType::Fix, {{pin, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{circ, PointRole::Center}, {pin, PointRole::Self}});
    sk.add_constraint(ConstraintType::Radius, {{circ, PointRole::Self}}, 16.5);
    auto ln = sk.add_line(200.0, 10.0, 230.0, 10.0);
    auto start = sk.add_point(200.0, 10.0);
    sk.add_constraint(ConstraintType::Fix, {{start, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{ln, PointRole::Start}, {start, PointRole::Self}});
    sk.add_constraint(ConstraintType::Horizontal, {{ln, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{ln, PointRole::End}, {circ, PointRole::Self}});
    auto solver = make_planegcs_backend();
    auto result = solver->solve(sk);
    REQUIRE(result.ok());
    const SketchEntity* e = sk.entity(ln);
    REQUIRE(e != nullptr);
    const double x = sk.param(e->params[2]);
    const double y = sk.param(e->params[3]);
    REQUIRE(std::hypot(x - 240.0, y) == Approx(16.5).margin(0.05));
    REQUIRE(x == Approx(226.876).margin(0.2));
    REQUIRE(std::hypot(x - 240.0, y - 0.0) > 1.0);
}
