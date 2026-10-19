// CueMemory keeps the edge_memory JSON; add_external_edge projects lines and
// circles (full or arc) on a parallel sketch plane.

#include <catch.hpp>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <GeomAbs_CurveType.hxx>
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

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

TEST_CASE("add_external_edge projects a box line and a partial circle as Arc", "[cue_memory]") {
    sx::Document doc;
    const sx::EntityId box = doc.add_body(sx::shape::make_box(20, 30, 10), "Box");
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
    REQUIRE(!line_id.is_null());

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

    gp_Circ arc_curve(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 12.0);
    const sx::EntityId arc_body =
        doc.add_body(BRepBuilderAPI_MakeEdge(arc_curve, 0.0, 1.2).Edge(), "arc");
    sx::EntityId arc_id;
    const sx::Body* arc = doc.body(arc_body);
    REQUIRE(arc != nullptr);
    for (const auto& eid : arc->subshape_ids.at(sx::EntityKind::Edge)) arc_id = eid;
    REQUIRE(!arc_id.is_null());
    const sx::EntityId projected = sx::add_external_edge(doc, fid, arc_id);
    CHECK(!projected.is_null());
    const sx::Sketch& after = *doc.graph().feature(fid)->sketch;
    bool saw_arc = false;
    for (const auto& entity : after.entities()) {
        if (entity.id == projected && entity.type == sx::SketchEntityType::Arc) saw_arc = true;
    }
    CHECK(saw_arc);
}
