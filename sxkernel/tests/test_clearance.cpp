#include <catch.hpp>

#include <cmath>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("wave6_2: new document seeds built-in variables", "[clearance][variables]") {
    Document doc;
    const auto& entries = doc.graph().variables().entries();
    auto has = [&](const char* name, const char* expr) -> bool {
        for (const auto& e : entries) {
            if (e.first == name && e.second == expr) return true;
        }
        return false;
    };
    REQUIRE(has("clearance", "0.3"));
    REQUIRE(has("hole_compensation", "0.2"));
    REQUIRE(has("layer", "0.2"));
    REQUIRE(has("nozzle", "0.4"));
    REQUIRE(has("jaw_af", "10"));
}

TEST_CASE("wave6_2: hole diameter tracks clearance and hole_compensation", "[clearance][feathole]") {
    Document doc;
    FeatureGraph& graph = doc.graph();

    // Box 20×20×10
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    // Through hole: diameter driven by variables = jaw_af + clearance + hole_compensation.
    Feature hole;
    hole.type = FeatureType::Hole;
    hole.params = {{"target", box_fid.str()},
                   {"type", "simple"},
                   {"position", json::array({10.0, 10.0, 10.0})},
                   {"direction", json::array({0.0, 0.0, -1.0})},
                   {"diameter", "=jaw_af + clearance + hole_compensation"},
                   {"depth", 0.0}};
    auto hole_fid = graph.add(std::move(hole));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);

    const double vol0 = 20.0 * 20.0 * 10.0;
    const double d1 = 10.0 + 0.3 + 0.2;  // jaw_af + clearance + hole_compensation
    const double expected_drop1 = M_PI * 0.25 * d1 * d1 * 10.0;
    const double drop1 = vol0 - shape::volume(doc.body(body_id)->shape);
    REQUIRE(drop1 == Approx(expected_drop1).epsilon(0.02));

    // Increase clearance; hole grows accordingly.
    graph.variables().set("clearance", "0.6");
    REQUIRE(graph.regenerate(doc, &err));
    const double d2 = 10.0 + 0.6 + 0.2;
    const double expected_drop2 = M_PI * 0.25 * d2 * d2 * 10.0;
    const double drop2 = vol0 - shape::volume(doc.body(body_id)->shape);
    REQUIRE(drop2 == Approx(expected_drop2).epsilon(0.02));
}

