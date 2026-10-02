#include <catch.hpp>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/naming.hpp"
#include "sx/shape_utils.hpp"

#include <BRepFilletAPI_MakeFillet.hxx>
#include <TopExp.hxx>
#include "sx/occt_types.hpp"
#include <TopoDS.hxx>

using namespace sx;
using nlohmann::json;

TEST_CASE("naming: subshape ids survive a resize", "[naming]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    const Body* b = doc.body(body_id);
    auto old_face_ids = b->subshape_ids.at(EntityKind::Face);
    auto old_edge_ids = b->subshape_ids.at(EntityKind::Edge);
    REQUIRE(old_face_ids.size() == 6);

    // Grow the box upward (push/pull style): same topology, moved/stretched.
    doc.replace_body_shape(body_id, shape::make_box(10, 10, 20));
    const auto& new_face_ids = doc.body(body_id)->subshape_ids.at(EntityKind::Face);
    REQUIRE(new_face_ids.size() == 6);

    int preserved = 0;
    for (const auto& id : new_face_ids)
        for (const auto& old : old_face_ids)
            if (id == old) ++preserved;
    REQUIRE(preserved == 6);

    // Edges survive too (12 of a box).
    const auto& new_edge_ids = doc.body(body_id)->subshape_ids.at(EntityKind::Edge);
    int edge_preserved = 0;
    for (const auto& id : new_edge_ids)
        for (const auto& old : old_edge_ids)
            if (id == old) ++edge_preserved;
    REQUIRE(edge_preserved >= 8);  // the 4 verticals stretch, top ring moves
}

TEST_CASE("naming: fillet keeps old faces, new face gets fresh id", "[naming]") {
    Document doc;
    TopoDS_Shape box = shape::make_box(20, 20, 20);
    auto body_id = doc.add_body(box, "Box");
    auto old_face_ids = doc.body(body_id)->subshape_ids.at(EntityKind::Face);

    sx::occt::ShapeIndexedMap edges;
    TopExp::MapShapes(box, TopAbs_EDGE, edges);
    BRepFilletAPI_MakeFillet mk(box);
    mk.Add(2.0, TopoDS::Edge(edges(1)));
    mk.Build();
    REQUIRE(mk.IsDone());
    doc.replace_body_shape(body_id, mk.Shape());

    const auto& new_face_ids = doc.body(body_id)->subshape_ids.at(EntityKind::Face);
    REQUIRE(new_face_ids.size() == 7);
    int preserved = 0;
    for (const auto& id : new_face_ids)
        for (const auto& old : old_face_ids)
            if (id == old) ++preserved;
    // The 6 planar faces survive (barely trimmed); the cylindrical fillet
    // face is genuinely new.
    REQUIRE(preserved == 6);
}

TEST_CASE("naming: moving a body far away releases all ids", "[naming]") {
    shape::Placement far;
    far.origin = {5000, 0, 0};
    auto result = naming::match_subshapes(
        shape::make_box(10, 10, 10),
        {{EntityKind::Face, std::vector<EntityId>(6, EntityId::generate())}},
        shape::make_box(10, 10, 10, far));
    REQUIRE(result.released.size() == 6);
}

TEST_CASE("naming: card aliases survive replace_body_shape", "[naming]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto face_id = doc.subshape_id(body_id, EntityKind::Face, 1);
    doc.cards().set_alias(face_id, "the mounting face");

    doc.replace_body_shape(body_id, shape::make_box(10, 10, 15));
    const Card* card = doc.cards().find(face_id);
    REQUIRE(card != nullptr);
    REQUIRE(card->aliases == "the mounting face");
}

TEST_CASE("naming: face ids and aliases survive parametric regeneration", "[naming]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto fid = doc.graph().add(std::move(box));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    EntityId body_id = doc.graph().feature(fid)->output_body;

    auto face_id = doc.subshape_id(body_id, EntityKind::Face, 3);
    doc.cards().set_alias(face_id, "datum face");

    json p = doc.graph().feature(fid)->params;
    p["c"] = 25.0;
    REQUIRE(doc.graph().set_params(fid, p));
    REQUIRE(doc.graph().regenerate(doc, &err));

    // The id still resolves into the rebuilt body and kept its card text.
    auto ref = doc.find_subshape(face_id);
    REQUIRE(ref.has_value());
    REQUIRE(ref->body == body_id);
    const Card* card = doc.cards().find(face_id);
    REQUIRE(card != nullptr);
    REQUIRE(card->aliases == "datum face");
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(2500.0));
}
