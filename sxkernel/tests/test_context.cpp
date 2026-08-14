#include <catch.hpp>

#include "sx/cards.hpp"
#include "sx/context.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("context export covers timeline, bodies, and free text", "[context]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.name = "Base";
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 10.0}};
    auto fid = doc.graph().add(std::move(box));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    EntityId body_id = doc.graph().feature(fid)->output_body;

    auto face_id = doc.subshape_id(body_id, EntityKind::Face, 1);
    doc.cards().set_alias(face_id, "the mounting face");
    doc.cards().set_notes(body_id, "keep walls above 2mm");

    std::string md = export_context_markdown(doc);
    REQUIRE(md.find("# Model context") != std::string::npos);
    REQUIRE(md.find(fid.str()) != std::string::npos);          // timeline JSON
    REQUIRE(md.find(body_id.str()) != std::string::npos);      // body section
    REQUIRE(md.find(face_id.str()) != std::string::npos);      // face card line
    REQUIRE(md.find("the mounting face") != std::string::npos);
    REQUIRE(md.find("keep walls above 2mm") != std::string::npos);
    REQUIRE(md.find("volume: 4000") != std::string::npos);
    REQUIRE(md.find("\"kind\": \"box\"") != std::string::npos);
}

TEST_CASE("context export of empty document", "[context]") {
    Document doc;
    std::string md = export_context_markdown(doc);
    REQUIRE(md.find("_empty_") != std::string::npos);
    // Wave 6.2: new documents seed built-in variables; section should be present.
    REQUIRE(md.find("## Variables") != std::string::npos);
    REQUIRE(md.find("`clearance` = `0.3`") != std::string::npos);
    REQUIRE(md.find("## Datums") == std::string::npos);
    REQUIRE(md.find("## Instances") == std::string::npos);
}

TEST_CASE("context export covers variables, datums, and instances", "[context]") {
    Document doc;
    doc.graph().variables().set("w", "20");
    doc.graph().variables().set("h", "w/2");

    auto plane_id = doc.add_datum_plane({0, 0, 5}, {0, 0, 1});
    doc.cards().set_alias(plane_id, "mid plane");
    auto axis_id = doc.add_datum_axis({0, 0, 0}, {1, 0, 0});

    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto inst_id = doc.add_instance(body_id, {30, 0, 0}, {0, 0, 0, 1}, "Box (inst)");

    std::string md = export_context_markdown(doc);
    REQUIRE(md.find("## Variables") != std::string::npos);
    REQUIRE(md.find("`w` = `20`") != std::string::npos);
    REQUIRE(md.find("`h` = `w/2`") != std::string::npos);
    REQUIRE(md.find("→ 10") != std::string::npos);  // h evaluated
    REQUIRE(md.find("## Datums") != std::string::npos);
    REQUIRE(md.find(plane_id.str()) != std::string::npos);
    REQUIRE(md.find("mid plane") != std::string::npos);
    REQUIRE(md.find(axis_id.str()) != std::string::npos);
    REQUIRE(md.find("## Instances") != std::string::npos);
    REQUIRE(md.find(inst_id.str()) != std::string::npos);
    REQUIRE(md.find("Box (inst)") != std::string::npos);
}
