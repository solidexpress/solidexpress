#include <catch.hpp>
#
#include "sx/command.hpp"
#include "sx/commands_boolean.hpp"
#include "sx/document.hpp"
#include "sx/print.hpp"
#include "sx/shape_utils.hpp"
#
using namespace sx;
#
TEST_CASE("paint: 1.2mm plate can be flagged thin", "[print][paint]") {
    Document doc;
    const EntityId plate = doc.add_body(shape::make_box(40, 40, 1.2), "plate");
    PrintSetup s = doc.print_setup();
    // Raise threshold so 1.2mm is considered thin for this test.
    s.min_wall = 1.25;
    doc.set_print_setup(s);
    const PrintReport r = print_analyze(doc, plate);
    REQUIRE(r.min_wall == Approx(1.2).margin(0.2));
    // Paint data should include at least one thin face.
    CHECK_FALSE(r.thin_faces.empty());
}
#
TEST_CASE("paint: 60°+ overhang reports face area > 0", "[print][paint]") {
    Document doc;
    CommandStack stack;
    // Classic L-shelf: horizontal shelf fused to a vertical wall.
    const EntityId base = doc.add_body(shape::make_box(40, 10, 10), "base");
    shape::Placement p;
    p.origin = {30, 0, 10};
    const EntityId shelf = doc.add_body(shape::make_box(20, 10, 10, p), "shelf");
    stack.push(doc, std::make_unique<BooleanCommand>(base, shelf, BooleanOp::Fuse));
    const PrintReport r = print_analyze(doc, base);
    // Total overhang area already tracked:
    REQUIRE(r.overhang_area > 0.0);
    // Paint data should attribute some area to one or more faces.
    double sum = 0.0;
    for (const auto& fa : r.overhang_face_areas) sum += fa.second;
    CHECK(sum > 0.0);
}
