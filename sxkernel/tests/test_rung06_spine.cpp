#include <catch.hpp>

#include <cmath>

#include "features/ops.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using namespace sx::feature_ops;

TEST_CASE("path spine wire keeps R150 and R20 circular edges", "[rung06][spine]") {
    Sketch sk("Path");
    sk.add_line(0.0, 10.0, 60.0, 10.0);
    const double c150x = 60.0, c150y = 160.0, r150 = 150.0;
    const double c20x = 167.113, c20y = 86.333, r20 = 20.0;
    const double dx = c20x - c150x, dy = c20y - c150y;
    const double d = std::hypot(dx, dy);
    const double tanx = c150x + dx / d * r150;
    const double tany = c150y + dy / d * r150;
    const double sa150 = std::atan2(10.0 - c150y, 60.0 - c150x);
    const double ea150 = std::atan2(tany - c150y, tanx - c150x);
    sk.add_arc(c150x, c150y, r150, sa150, ea150 < sa150 ? ea150 + 2.0 * M_PI : ea150);
    const double sa20 = std::atan2(tany - c20y, tanx - c20x);
    const double ea20 = std::atan2(75.0 - c20y, 150.634 - c20x);
    sk.add_arc(c20x, c20y, r20, sa20, ea20 < sa20 ? ea20 + 2.0 * M_PI : ea20);

    TopoDS_Wire wire = sketch_spine_wire(sk);
    REQUIRE_FALSE(wire.IsNull());
    REQUIRE(spine_has_circle_radius(wire, 150.0, 0.2));
    REQUIRE(spine_has_circle_radius(wire, 20.0, 0.2));
}

TEST_CASE("path spine wire joins 0.2 mm click slop", "[rung06][spine]") {
    Sketch sk("Path");
    sk.add_line(0.0, 10.0, 60.0, 10.0);
    const double c150x = 60.02, c150y = 160.02, r150 = 150.0;
    const double c20x = 167.113, c20y = 86.333, r20 = 20.0;
    const double dx = c20x - c150x, dy = c20y - c150y;
    const double d = std::hypot(dx, dy);
    const double tanx = c150x + dx / d * r150;
    const double tany = c150y + dy / d * r150;
    const double sa150 = std::atan2(10.0 - c150y, 60.2 - c150x);
    const double ea150 = std::atan2(tany - c150y, tanx - c150x);
    EntityId a150 = sk.add_arc(c150x, c150y, r150, sa150, ea150 < sa150 ? ea150 + 2.0 * M_PI : ea150);
    SketchEntity* e150 = sk.entity_mut(a150);
    REQUIRE(e150 != nullptr);
    REQUIRE(e150->params.size() >= 9);
    sk.param_mut(e150->params[5]) = 60.2;
    sk.param_mut(e150->params[6]) = 10.0;
    const double sa20 = std::atan2(tany - c20y, tanx - c20x);
    const double ea20 = std::atan2(75.0 - c20y, 150.634 - c20x);
    sk.add_arc(c20x, c20y, r20, sa20, ea20 < sa20 ? ea20 + 2.0 * M_PI : ea20);

    TopoDS_Wire wire = sketch_spine_wire(sk);
    REQUIRE_FALSE(wire.IsNull());
    REQUIRE(spine_has_circle_radius(wire, 150.0, 0.2));
    REQUIRE(spine_has_circle_radius(wire, 20.0, 0.2));
}
