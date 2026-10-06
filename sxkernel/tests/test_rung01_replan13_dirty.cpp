#include <catch.hpp>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>

#include <algorithm>
#include <cmath>
#include <functional>
#include <stdexcept>
#include <string>

#include "sx/commands_dress.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

namespace {

gp_Pnt edge_midpoint(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.CentreOfMass();
}

json top_edge_ids(const Document& doc, const EntityId& body) {
    json out = json::array();
    const Body* b = doc.body(body);
    REQUIRE(b != nullptr);
    double zmax = -1e300;
    for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        zmax = std::max(zmax, edge_midpoint(TopoDS::Edge(s)).Z());
    }
    for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        if (std::abs(edge_midpoint(TopoDS::Edge(s)).Z() - zmax) < 0.1)
            out.push_back(eid.str());
    }
    REQUIRE(out.size() >= 4);
    return out;
}

std::vector<EntityId> top_edge_vec(const Document& doc, const EntityId& body) {
    std::vector<EntityId> out;
    for (const auto& j : top_edge_ids(doc, body))
        out.push_back(EntityId::from_string(j.get<std::string>()));
    return out;
}

EntityId add_box(Document& doc, double a, double b, double c) {
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", a}, {"b", b}, {"c", c}};
    auto fid = doc.graph().add(std::move(box));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    return fid;
}

// Mirrors SxDocument::apply_graph_edit (not linked into sxkernel_tests):
// mutate, regenerate, and on failure restore the graph via set_graph + regen.
// Reproduce-first: no restore_revision here, so a refused edit leaves
// revision moved (the first case is red on baseline). The product commit
// adds restore_revision to this helper and to apply_graph_edit.
bool apply_graph_edit_like(Document& doc, const std::function<bool()>& mutate) {
    json before = doc.graph().to_json();
    const uint64_t rev0 = doc.revision();
    if (!mutate()) return false;
    std::string err;
    if (!doc.graph().regenerate(doc, &err)) {
        doc.set_graph(FeatureGraph::from_json(before));
        doc.graph().regenerate(doc, nullptr);
        (void)rev0;
        return false;
    }
    return true;
}

bool add_fillet(Document& doc, const EntityId& target, const json& edges, double radius) {
    return apply_graph_edit_like(doc, [&] {
        Feature fil;
        fil.type = FeatureType::Fillet;
        fil.params = {{"target", target.str()}, {"radius", radius}, {"edges", edges}};
        doc.graph().add(std::move(fil));
        return true;
    });
}

}  // namespace

TEST_CASE("a refused fillet leaves revision and the timeline unchanged", "[replan13]") {
    Document doc;
    auto box_fid = add_box(doc, 20.0, 10.0, 10.0);
    EntityId body = doc.graph().feature(box_fid)->output_body;
    json edges = top_edge_ids(doc, body);
    const uint64_t rev0 = doc.revision();
    const size_t nfeat = doc.graph().timeline().size();

    REQUIRE_FALSE(add_fillet(doc, box_fid, edges, 50.0));
    CHECK(doc.revision() == rev0);
    CHECK(doc.graph().timeline().size() == nfeat);
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));

    // Direct FilletCommand (SxDocument::fillet_edges) must not bump on throw.
    const uint64_t rev1 = doc.revision();
    bool threw = false;
    try {
        FilletCommand cmd(top_edge_vec(doc, body), 50.0);
        cmd.execute(doc);
    } catch (const std::exception&) {
        threw = true;
    }
    REQUIRE(threw);
    CHECK(doc.revision() == rev1);
}

TEST_CASE("an accepted fillet increases revision", "[replan13]") {
    Document doc;
    auto box_fid = add_box(doc, 20.0, 10.0, 10.0);
    EntityId body = doc.graph().feature(box_fid)->output_body;
    json edges = top_edge_ids(doc, body);
    const uint64_t rev0 = doc.revision();
    REQUIRE(add_fillet(doc, box_fid, edges, 1.0));
    CHECK(doc.revision() > rev0);
}

TEST_CASE("a refused fillet then an accepted one still increases revision", "[replan13]") {
    Document doc;
    auto box_fid = add_box(doc, 20.0, 10.0, 10.0);
    EntityId body = doc.graph().feature(box_fid)->output_body;
    json edges = top_edge_ids(doc, body);
    const uint64_t rev0 = doc.revision();
    REQUIRE_FALSE(add_fillet(doc, box_fid, edges, 50.0));
    CHECK(doc.revision() == rev0);
    REQUIRE(add_fillet(doc, box_fid, edges, 1.0));
    CHECK(doc.revision() > rev0);
}
