// CueMemory keeps the edge_memory JSON, and add_external_edge only accepts lines.
// These cases load a pre-change literal and a box with one circular edge.

#include <catch.hpp>

#include <BRepAdaptor_Curve.hxx>
#include <GeomAbs_CurveType.hxx>
#include <TopoDS.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch3d.hpp"

using nlohmann::json;

TEST_CASE("CueMemory loads an edge_memory array and writes it back", "[cue_memory]") {
    const json literal = json::parse(R"({
        "timeline": [],
        "edge_memory": {
            "a-edge": [1.0, 2.0, 3.0, 0.0, 1.0, 0.0],
            "b-edge": [4.5, 0.0, -1.0, 1.0, 0.0, 0.0]
        }
    })");
    const sx::FeatureGraph graph = sx::FeatureGraph::from_json(literal);
    const sx::TopoCue* a = graph.cues().find("a-edge");
    const sx::TopoCue* b = graph.cues().find("b-edge");
    REQUIRE(a != nullptr);
    REQUIRE(b != nullptr);
    CHECK(a->point.X() == 1.0);
    CHECK(a->point.Y() == 2.0);
    CHECK(a->point.Z() == 3.0);
    CHECK(a->dir.X() == 0.0);
    CHECK(a->dir.Y() == 1.0);
    CHECK(a->dir.Z() == 0.0);
    CHECK(b->point.X() == 4.5);
    CHECK(b->point.Y() == 0.0);
    CHECK(b->point.Z() == -1.0);
    CHECK(b->dir.X() == 1.0);
    CHECK(b->dir.Y() == 0.0);
    CHECK(b->dir.Z() == 0.0);
    CHECK(graph.cues().find("missing") == nullptr);
    CHECK(graph.cues().to_json() == literal["edge_memory"]);
}

TEST_CASE("add_external_edge projects a box line and rejects a circle", "[cue_memory]") {
    sx::Document doc;
    const sx::EntityId box = doc.add_body(sx::shape::make_box(20, 30, 10), "Box");
    const sx::EntityId cyl = doc.add_body(sx::shape::make_cylinder(5, 12), "Cyl");
    sx::Feature sketch_feature;
    sketch_feature.type = sx::FeatureType::Sketch;
    sketch_feature.sketch = std::make_shared<sx::Sketch>("on box");
    const sx::EntityId fid = doc.graph().add(std::move(sketch_feature));

    sx::EntityId line_id;
    for (const auto& eid : doc.body(box)->subshape_ids.at(sx::EntityKind::Edge)) {
        const TopoDS_Shape shape = doc.resolve(eid);
        if (shape.IsNull() || shape.ShapeType() != TopAbs_EDGE) continue;
        if (BRepAdaptor_Curve(TopoDS::Edge(shape)).GetType() == GeomAbs_Line) {
            line_id = eid;
            break;
        }
    }
    sx::EntityId arc_id;
    for (const auto& eid : doc.body(cyl)->subshape_ids.at(sx::EntityKind::Edge)) {
        const TopoDS_Shape shape = doc.resolve(eid);
        if (shape.IsNull() || shape.ShapeType() != TopAbs_EDGE) continue;
        if (BRepAdaptor_Curve(TopoDS::Edge(shape)).GetType() == GeomAbs_Circle) {
            arc_id = eid;
            break;
        }
    }
    REQUIRE(!line_id.is_null());
    REQUIRE(!arc_id.is_null());

    const sx::EntityId first = sx::add_external_edge(doc, fid, line_id);
    REQUIRE(!first.is_null());
    const sx::Sketch& sketch = *doc.graph().feature(fid)->sketch;
    int external_construction = 0;
    for (const auto& entity : sketch.entities()) {
        if (entity.external && entity.construction && entity.id == first) ++external_construction;
    }
    CHECK(external_construction == 1);
    CHECK(sketch.entities().size() == 1);
    const sx::EntityId second = sx::add_external_edge(doc, fid, line_id);
    CHECK(second == first);
    CHECK(doc.graph().feature(fid)->sketch->entities().size() == 1);
    CHECK(sx::add_external_edge(doc, fid, arc_id).is_null());
}
