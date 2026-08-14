#include <catch.hpp>

#include <BRepAdaptor_Curve.hxx>
#include <TopoDS.hxx>
#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

namespace {

EntityId bottom_edge_id(Document& doc, const Body& b) {
    for (const auto& eid : b.subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        BRepAdaptor_Curve curve(TopoDS::Edge(s));
        gp_Pnt a = curve.Value(curve.FirstParameter());
        gp_Pnt c = curve.Value(curve.LastParameter());
        gp_Pnt mid(0.5 * (a.X() + c.X()), 0.5 * (a.Y() + c.Y()), 0.5 * (a.Z() + c.Z()));
        if (std::abs(mid.Z()) < 1e-6 && curve.GetType() == GeomAbs_Line) return eid;
    }
    return {};
}

}  // namespace

TEST_CASE("featops: fillet stores edge uuid and survives source edit", "[featops][uuidrefs]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 30.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(box));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);

    // Bottom horizontal edge: height-only edits keep its geometry, so naming
    // preserves the UUID stored in the fillet feature.
    EntityId edge_id = bottom_edge_id(doc, *b);
    REQUIRE(!edge_id.is_null());

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.params = {{"target", box_fid.str()},
                  {"radius", 2.0},
                  {"edges", json::array({edge_id.str()})}};
    auto fil_fid = graph.add(std::move(fil));

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) != nullptr);
    double vol_filleted = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol_filleted < 24000.0);
    REQUIRE(vol_filleted > 23000.0);

    REQUIRE(graph.feature(fil_fid)->params.at("edges")[0].is_string());
    REQUIRE(graph.feature(fil_fid)->params.at("edges")[0].get<std::string>() == edge_id.str());

    json p = graph.feature(box_fid)->params;
    p["c"] = 25.0;
    REQUIRE(graph.set_params(box_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) != nullptr);
    double vol2 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol2 > vol_filleted);
    REQUIRE(vol2 < 40.0 * 30.0 * 25.0);
}

TEST_CASE("featops: legacy integer edge index still loads", "[featops][uuidrefs]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 30.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(box));

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.params = {{"target", box_fid.str()}, {"radius", 2.0}, {"edges", json::array({1})}};
    graph.add(std::move(fil));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    REQUIRE(shape::volume(doc.body(body_id)->shape) < 24000.0);
}

TEST_CASE("featops: push_pull feature grows a box face", "[featops][pushpull]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);

    EntityId top_face;
    for (const auto& fid : b->subshape_ids.at(EntityKind::Face)) {
        if (shape::describe_face(doc.resolve(fid)).find("normal (0, 0, 1)") != std::string::npos) {
            top_face = fid;
            break;
        }
    }
    REQUIRE(!top_face.is_null());

    Feature pp;
    pp.type = FeatureType::DirectEdit;
    pp.params = {{"target", box_fid.str()},
                 {"kind", "push_pull"},
                 {"face", top_face.str()},
                 {"distance", 5.0}};
    graph.add(std::move(pp));

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1500.0).epsilon(1e-3));
}
