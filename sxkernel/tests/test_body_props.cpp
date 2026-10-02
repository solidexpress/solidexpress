#include <catch.hpp>

#include "test_temp.hpp"
#include <cstdio>
#include <string>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;
using sx::test::TmpFile;

TEST_CASE("body name and color round-trip through .sxp", "[bodyprops]") {
    TmpFile f("bodyprops.sxp");

    Document doc;
    auto id = doc.add_body(shape::make_box(10, 20, 30), "Box");
    Body* b = doc.body_mut(id);
    REQUIRE(b != nullptr);
    b->name = "Housing";
    b->color = {0.2f, 0.4f, 0.8f};
    doc.bump_revision();

    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));

    Document loaded;
    REQUIRE(load_sxp(loaded, f.path, &err));
    const Body* lb = loaded.body(id);
    REQUIRE(lb != nullptr);
    REQUIRE(lb->name == "Housing");
    REQUIRE(lb->color[0] == Approx(0.2f));
    REQUIRE(lb->color[1] == Approx(0.4f));
    REQUIRE(lb->color[2] == Approx(0.8f));
}

TEST_CASE("rename refreshes body and face cards, preserving free text", "[bodyprops]") {
    Document doc;
    auto id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto face_id = doc.subshape_id(id, EntityKind::Face, 1);
    doc.cards().set_alias(face_id, "the mounting face");

    REQUIRE(doc.rename_body(id, "Housing"));
    REQUIRE(doc.body(id)->name == "Housing");
    const Card* bc = doc.cards().find(id);
    REQUIRE(bc != nullptr);
    REQUIRE(bc->title == "Housing");
    const Card* fc = doc.cards().find(face_id);
    REQUIRE(fc != nullptr);
    REQUIRE(fc->title.find("Housing") != std::string::npos);  // face titles refreshed
    REQUIRE(fc->aliases == "the mounting face");              // free text preserved

    REQUIRE(!doc.rename_body(EntityId::generate(), "nope"));
}

TEST_CASE("fresh body has default display color", "[bodyprops]") {
    Document doc;
    auto id = doc.add_body(shape::make_cylinder(5, 10), "Cyl");
    const Body* b = doc.body(id);
    REQUIRE(b != nullptr);
    REQUIRE(b->color[0] == Approx(0.7f));
    REQUIRE(b->color[1] == Approx(0.7f));
    REQUIRE(b->color[2] == Approx(0.75f));
}
