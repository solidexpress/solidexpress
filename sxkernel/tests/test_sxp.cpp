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

TEST_CASE("sxp save/load round trip preserves bodies, ids and cards", "[sxp]") {
    TmpFile f("roundtrip.sxp");

    Document doc;
    auto box_id = doc.add_body(shape::make_box(10, 20, 30), "Box 1");
    auto cyl_id = doc.add_body(shape::make_cylinder(5, 15), "Cyl 1");
    auto face_id = doc.subshape_id(box_id, EntityKind::Face, 3);

    doc.cards().set_alias(face_id, "the shiny side");
    doc.cards().set_notes(box_id, "primary housing block");

    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));

    Document loaded;
    REQUIRE(load_sxp(loaded, f.path, &err));

    // Bodies restored with the same ids and geometry.
    REQUIRE(loaded.body_ids().size() == 2);
    const Body* box = loaded.body(box_id);
    REQUIRE(box != nullptr);
    REQUIRE(box->name == "Box 1");
    REQUIRE(shape::volume(box->shape) == Approx(6000.0).epsilon(1e-6));
    REQUIRE(loaded.body(cyl_id) != nullptr);

    // Subshape ids restored exactly.
    REQUIRE(loaded.subshape_id(box_id, EntityKind::Face, 3) == face_id);
    REQUIRE(!loaded.resolve(face_id).IsNull());

    // Free-text card sections survived the round trip.
    const Card* fc = loaded.cards().find(face_id);
    REQUIRE(fc != nullptr);
    REQUIRE(fc->aliases == "the shiny side");
    const Card* bc = loaded.cards().find(box_id);
    REQUIRE(bc != nullptr);
    REQUIRE(bc->notes == "primary housing block");
}

TEST_CASE("load_sxp fails cleanly on nonsense", "[sxp]") {
    Document doc;
    std::string err;
    REQUIRE(!load_sxp(doc, sx::test::temp_path("does_not_exist_sx.sxp"), &err));
    REQUIRE(!err.empty());

    TmpFile f("garbage.sxp");
    FILE* fp = fopen(f.path.c_str(), "wb");
    fputs("this is not a zip", fp);
    fclose(fp);
    REQUIRE(!load_sxp(doc, f.path, &err));
}

TEST_CASE("save then load twice is stable", "[sxp]") {
    TmpFile f1("stable1.sxp");
    TmpFile f2("stable2.sxp");

    Document doc;
    doc.add_body(shape::make_torus(20, 5), "T");
    std::string err;
    REQUIRE(save_sxp(doc, f1.path, &err));

    Document d2;
    REQUIRE(load_sxp(d2, f1.path, &err));
    REQUIRE(save_sxp(d2, f2.path, &err));

    Document d3;
    REQUIRE(load_sxp(d3, f2.path, &err));
    REQUIRE(d3.body_ids().size() == 1);
    REQUIRE(d3.body_ids()[0] == doc.body_ids()[0]);
}
