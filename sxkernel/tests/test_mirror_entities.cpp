// WP-L8: Mirror Entities keep type, reflected arc angles, Symmetric.

#include <catch.hpp>

#include <cmath>

#include "sx/sketch.hpp"
#include "sx/sketch_tools.hpp"
#include "sx/solver.hpp"

using namespace sx;
using namespace sx::sketch_tools;

namespace {

void reflect_axis(double x, double y, double ax0, double ay0, double ax1, double ay1,
                  double& ox, double& oy) {
    const double dx = ax1 - ax0, dy = ay1 - ay0;
    const double len = std::hypot(dx, dy);
    const double adx = dx / len, ady = dy / len;
    const double anx = -ady, any = adx;
    const double px = x - ax0, py = y - ay0;
    const double along = px * adx + py * ady;
    const double across = px * anx + py * any;
    ox = ax0 + along * adx - across * anx;
    oy = ay0 + along * ady - across * any;
}

bool has_symmetric(const Sketch& sk, EntityId a, EntityId b) {
    for (const auto& c : sk.constraints()) {
        if (c.type != ConstraintType::Symmetric || c.refs.size() < 3) continue;
        if ((c.refs[0].entity == a && c.refs[1].entity == b) ||
            (c.refs[0].entity == b && c.refs[1].entity == a))
            return true;
    }
    return false;
}

}  // namespace

TEST_CASE("mirror arc about a vertical axis reflects endpoints", "[mirror][l8]") {
    Sketch sk;
    auto axis = sk.add_line(0, -20, 0, 20);
    auto arc = sk.add_arc(10, 0, 5, 0.0, 1.5707963267948966);
    auto ids = mirror_entities(sk, {arc.str()}, axis.str());
    REQUIRE(ids.size() == 1);
    EntityId copy = EntityId::from_string(ids[0]);
    const SketchEntity* e = sk.entity(copy);
    REQUIRE(e->type == SketchEntityType::Arc);
    CHECK(sk.param(e->params[0]) == Approx(-10.0).margin(1e-9));
    CHECK(sk.param(e->params[2]) == Approx(5.0).margin(1e-9));
    double sx, sy, ex, ey;
    reflect_axis(15, 0, 0, -20, 0, 20, sx, sy);
    reflect_axis(10, 5, 0, -20, 0, 20, ex, ey);
    CHECK(std::hypot(sk.param(e->params[5]) - ex, sk.param(e->params[6]) - ey) <= 1e-9);
    CHECK(std::hypot(sk.param(e->params[7]) - sx, sk.param(e->params[8]) - sy) <= 1e-9);
    CHECK(has_symmetric(sk, arc, copy));
}

TEST_CASE("mirror arc about a 30 degree axis", "[mirror][l8]") {
    Sketch sk;
    const double a = 30.0 * 3.14159265358979323846 / 180.0;
    auto axis = sk.add_line(0, 0, std::cos(a) * 40, std::sin(a) * 40);
    auto arc = sk.add_arc(20, 0, 4, 0.2, 1.1);
    auto ids = mirror_entities(sk, {arc.str()}, axis.str());
    REQUIRE(ids.size() == 1);
    EntityId copy = EntityId::from_string(ids[0]);
    const SketchEntity* e = sk.entity(copy);
    REQUIRE(e->type == SketchEntityType::Arc);
    double cx, cy;
    reflect_axis(20, 0, 0, 0, std::cos(a) * 40, std::sin(a) * 40, cx, cy);
    CHECK(sk.param(e->params[0]) == Approx(cx).margin(1e-9));
    CHECK(sk.param(e->params[1]) == Approx(cy).margin(1e-9));
    CHECK(sk.param(e->params[2]) == Approx(4.0).margin(1e-9));
    CHECK(has_symmetric(sk, arc, copy));
}

TEST_CASE("mirror copy follows the source under solve", "[mirror][l8]") {
    Sketch sk;
    auto axis = sk.add_line(-30, 0, 30, 0);
    auto ln = sk.add_line(-10, 8, 10, 8);
    auto ids = mirror_entities(sk, {ln.str()}, axis.str());
    REQUIRE(ids.size() == 1);
    sk.add_constraint(ConstraintType::Fix, {{axis, PointRole::Self}});
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    sk.param_mut(sk.entity(ln)->params[1]) = 12.0;
    sk.param_mut(sk.entity(ln)->params[3]) = 12.0;
    sk.add_constraint(ConstraintType::Fix, {{ln, PointRole::Self}});
    REQUIRE(solver->solve(sk).ok());
    EntityId copy = EntityId::from_string(ids[0]);
    CHECK(sk.param(sk.entity(copy)->params[1]) == Approx(-12.0).margin(1e-6));
    CHECK(sk.param(sk.entity(copy)->params[3]) == Approx(-12.0).margin(1e-6));
}
