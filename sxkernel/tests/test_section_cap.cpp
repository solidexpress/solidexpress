#include <catch.hpp>

#include "sx/commands_hollow.hpp"
#include "sx/document.hpp"
#include "sx/section_cap.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

namespace {

EntityId face_with_normal(Document& doc, const Body& b, const char* needle) {
    EntityId found;
    for (const auto& fid : b.subshape_ids.at(EntityKind::Face)) {
        auto desc = shape::describe_face(doc.resolve(fid));
        if (desc.find(needle) != std::string::npos) found = fid;
    }
    return found;
}

SectionCapMesh cap_of(const Document& doc, const EntityId& body) {
    return section_cap(doc.body(body)->shape, 0, 0, 0, 0, 1, 0);
}

}  // namespace

TEST_CASE("section cap of a centred box is the cut rectangle", "[section]") {
    Document doc;
    shape::Placement place;
    place.origin = {-60, -60, 0};
    auto body = doc.add_body(shape::make_box(120, 120, 30, place), "base");

    SectionCapMesh cap = cap_of(doc, body);
    REQUIRE_FALSE(cap.empty());
    // y = 0 through the 120 × 30 cross-section. The wall sample and a
    // point in the removed half (off the plane) are the walk's L7 probes.
    REQUIRE(cap.covers(-59.5, 0, 12));
    REQUIRE(cap.covers(0, 0, 15));
    REQUIRE_FALSE(cap.covers(-61, 0, 12));
    REQUIRE_FALSE(cap.covers(0, 40, 15));
}

TEST_CASE("section cap of a 1 mm shell keeps the wall and drops the cavity", "[section]") {
    Document doc;
    CommandStack stack;
    shape::Placement place;
    place.origin = {-60, -60, 0};
    auto body = doc.add_body(shape::make_box(120, 120, 30, place), "base");
    // describe_face prints a negative zero as "-0", so the back face is not
    // the string "normal (0, 0, -1)".
    EntityId back = face_with_normal(doc, *doc.body(body), "normal (-0, -0, -1)");
    REQUIRE_FALSE(back.is_null());
    stack.push(doc, std::make_unique<ShellCommand>(std::vector<EntityId>{back}, 1.0));

    SectionCapMesh cap = cap_of(doc, body);
    REQUIRE_FALSE(cap.empty());
    // Mid-wall of the 1 mm skin, on the Top plane. The cavity is open.
    REQUIRE(cap.covers(-59.5, 0.0, 12.0));
    REQUIRE(cap.covers(0.0, 0.0, 29.5));
    REQUIRE_FALSE(cap.covers(0.0, 0.0, 12.0));
    REQUIRE_FALSE(cap.covers(0.0, 40.0, 15.0));
}
