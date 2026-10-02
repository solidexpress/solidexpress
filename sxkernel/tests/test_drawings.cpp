#include <catch.hpp>

#include "test_temp.hpp"

#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>

#include "sx/command.hpp"
#include "sx/commands_boolean.hpp"
#include "sx/document.hpp"
#include "sx/drawings.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using sx::test::TmpFile;
using namespace sx::drawings;

namespace {

std::string slurp(const std::string& path) {
    std::ifstream f(path);
    std::ostringstream ss;
    ss << f.rdbuf();
    return ss.str();
}

}  // namespace

TEST_CASE("HLR projection of a box gives its silhouette bounds", "[drawings]") {
    auto box = shape::make_box(40, 30, 20);

    // Top view (looking down -Z): footprint 40 x 30.
    auto top = project(box, gp_Dir(0, 0, -1), gp_Dir(0, 1, 0));
    REQUIRE(!top.visible.empty());
    CHECK(top.max_x - top.min_x == Approx(40.0).margin(1e-3));
    CHECK(top.max_y - top.min_y == Approx(30.0).margin(1e-3));
    // (The bottom face's edges sit directly under the top's, so HLR reports
    // hidden edges even for a plain box — no assertion on hidden here.)

    // Front view (looking along +Y): 40 wide x 20 tall.
    auto front = project(box, gp_Dir(0, 1, 0), gp_Dir(0, 0, 1));
    CHECK(front.max_x - front.min_x == Approx(40.0).margin(1e-3));
    CHECK(front.max_y - front.min_y == Approx(20.0).margin(1e-3));
}

TEST_CASE("occluded geometry lands in the hidden edge set", "[drawings]") {
    // Box with a through-hole along Y; viewed along +X the hole is inside
    // the outline, so its edges must be hidden.
    Document doc;
    auto body = doc.add_body(shape::make_box(40, 30, 20), "Plate");
    auto tool = doc.add_body(
        shape::make_cylinder(5, 60, {{20, -10, 10}, {0, 1, 0}, {1, 0, 0}}), "Drill");
    CommandStack stack;
    stack.push(doc, std::make_unique<BooleanCommand>(body, tool, BooleanOp::Cut));
    REQUIRE(doc.body(tool) == nullptr);

    auto side = project(doc.body(body)->shape, gp_Dir(-1, 0, 0), gp_Dir(0, 0, 1));
    REQUIRE(!side.visible.empty());
    CHECK(!side.hidden.empty());
}

TEST_CASE("three-view SVG export writes a valid sheet", "[drawings]") {
    Document doc;
    doc.add_body(shape::make_box(40, 30, 20), "Plate");
    TmpFile f("three_view.svg");
    REQUIRE(export_three_view_svg(doc, f.path));

    std::string svg = slurp(f.path);
    CHECK(svg.find("<svg") != std::string::npos);
    CHECK(svg.find("polyline") != std::string::npos);
    CHECK(svg.find("FRONT") != std::string::npos);
    CHECK(svg.find("TOP") != std::string::npos);
    CHECK(svg.find("RIGHT") != std::string::npos);

    SECTION("empty document refuses to export") {
        Document empty;
        TmpFile g("empty.svg");
        CHECK_FALSE(export_three_view_svg(empty, g.path));
    }
}

TEST_CASE("hidden edges render dashed in the SVG", "[drawings]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(40, 30, 20), "Plate");
    auto tool = doc.add_body(
        shape::make_cylinder(5, 60, {{20, -10, 10}, {0, 1, 0}, {1, 0, 0}}), "Drill");
    CommandStack stack;
    stack.push(doc, std::make_unique<BooleanCommand>(body, tool, BooleanOp::Cut));

    TmpFile f("dashed.svg");
    REQUIRE(export_three_view_svg(doc, f.path));
    CHECK(slurp(f.path).find("stroke-dasharray") != std::string::npos);
}
