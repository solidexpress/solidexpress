// WP-L11: constraint weak round-trip; unknown types are load errors.

#include <catch.hpp>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <sstream>

#include "sx/sketch.hpp"
#include "sx/sketch_json.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("BRepTools::Write digit count probe", "[json][l11]") {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(1.0 / 3.0, 2.0, 3.0).Shape();
    std::ostringstream os;
    BRepTools::Write(box, os);
    const std::string s = os.str();
    // Record for WP-L12: OCCT 8.0.1 BRepTools::Write emits 17 digits
    // (0.33333333333333331), not 15.
    INFO(s.substr(0, 400));
    CHECK(s.find("0.33333333333333331") != std::string::npos);
}

TEST_CASE("sketch json round-trips weak, expr, fix, every entity", "[json][l11]") {
    Sketch sk("RoundTrip");
    sk.add_point(1, 2);
    sk.add_line(0, 0, 10, 0);
    auto c = sk.add_circle(0, 0, 5);
    sk.add_arc(20, 0, 3, 0.0, 1.2);
    sk.add_ellipse(40, 0, 8, 4, 0.1);
    sk.add_elliptical_arc(60, 0, 6, 3, 0.0, 0.2, 1.1);
    sk.add_spline({{0, 10}, {5, 12}, {10, 10}});
    auto dist = sk.add_constraint(ConstraintType::Distance,
                                  {{c, PointRole::Center}, {c, PointRole::Center}}, 0.0, false);
    sk.set_constraint_weak(dist, true);
    sk.set_constraint_expr(dist, "w/2");
    sk.add_constraint(ConstraintType::Fix, {{c, PointRole::Center}});

    json a = sketch_to_json(sk);
    bool saw_weak = false;
    for (const auto& jc : a.at("constraints")) {
        if (jc.value("weak", false)) saw_weak = true;
    }
    REQUIRE(saw_weak);
    auto loaded = sketch_from_json(a);
    json b = sketch_to_json(*loaded);
    CHECK(a == b);

    auto again = sketch_from_json(b);
    CHECK(sketch_to_json(*again) == a);
}

TEST_CASE("unknown entity type is a named load error", "[json][l11]") {
    Sketch sk;
    sk.add_line(0, 0, 1, 0);
    json j = sketch_to_json(sk);
    j["entities"][0]["type"] = "nurbs_patch";
    CHECK_THROWS_WITH(sketch_from_json(j), Catch::Matchers::Contains("nurbs_patch"));
}

TEST_CASE("unknown constraint type is a named load error", "[json][l11]") {
    Sketch sk;
    auto ln = sk.add_line(0, 0, 1, 0);
    sk.add_constraint(ConstraintType::Horizontal, {{ln, PointRole::Self}});
    json j = sketch_to_json(sk);
    j["constraints"][0]["type"] = "wormhole";
    CHECK_THROWS_WITH(sketch_from_json(j), Catch::Matchers::Contains("wormhole"));
}
