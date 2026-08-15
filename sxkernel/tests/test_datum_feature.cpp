#include <catch.hpp>

#include "sx/document.hpp"
#include "sx/features.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("datum feature: offset plane regenerates on the timeline", "[features][datum]") {
    Document doc;
    FeatureGraph graph;

    Feature d;
    d.type = FeatureType::Datum;
    d.params = {{"kind", "plane"},
                {"origin", json::array({0.0, 0.0, 15.0})},
                {"normal", json::array({0.0, 0.0, 1.0})}};
    auto fid = graph.add(std::move(d));
    REQUIRE(graph.regenerate(doc));
    REQUIRE(doc.datums().size() == 1);
    REQUIRE(graph.feature(fid)->params.contains("datum_id"));

    // Edit offset via params — same datum_id, new origin.
    auto* f = graph.feature(fid);
    f->params["origin"] = json::array({0.0, 0.0, 40.0});
    REQUIRE(graph.regenerate(doc));
    REQUIRE(doc.datums().size() == 1);
    const auto& stored = doc.datums().front();
    REQUIRE(std::holds_alternative<DatumPlane>(stored));
    const auto& plane = std::get<DatumPlane>(stored);
    REQUIRE(plane.origin[2] == Approx(40.0));
}
