#include <catch.hpp>

#include <string>

#include <TopoDS.hxx>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/ids.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("fillet wedge refused on cylindrical hole walls", "[exactness][fillet]") {
    Document doc;
    EntityId box_fid;
    EntityId body = exactness::add_box_hole(doc, 20.0, 20.0, 10.0, 10.0, &box_fid, nullptr);
    const Body* b = doc.body(body);
    REQUIRE(b != nullptr);

    json circles = json::array();
    for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        json e = exactness::probe_edge(TopoDS::Edge(s));
        if (e.value("type", "") == "GeomAbs_Circle") circles.push_back(eid.str());
    }
    REQUIRE_FALSE(circles.empty());

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.name = "fillet 1";
    fil.params = {{"target", box_fid.str()}, {"radius", 20.0}, {"edges", circles}};
    doc.graph().add(std::move(fil));
    std::string err;
    const bool ok = doc.graph().regenerate(doc, &err);
    INFO(err);
    bool refused = false;
    for (const auto& w : doc.graph().warnings())
        if (w.second.find("walls not planar") != std::string::npos) refused = true;
    REQUIRE((!ok || refused));
}
