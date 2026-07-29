#include <catch.hpp>

#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("feathole: simple hole volume drop, edit, suppress, json", "[feathole]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature hole;
    hole.type = FeatureType::Hole;
    hole.params = {{"target", box_fid.str()},
                   {"type", "simple"},
                   {"position", json::array({10.0, 10.0, 10.0})},
                   {"direction", json::array({0.0, 0.0, -1.0})},
                   {"diameter", 6.0},
                   {"depth", 0.0},
                   {"cb_diameter", 0.0},
                   {"cb_depth", 0.0},
                   {"cs_diameter", 0.0},
                   {"cs_angle_deg", 90.0}};
    auto hole_fid = graph.add(std::move(hole));

    REQUIRE(graph.has_dependents(box_fid));
    REQUIRE(graph.feature(hole_fid)->output_body.is_null());

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);

    const double vol0 = 20.0 * 20.0 * 10.0;
    const double expected_drop = M_PI * 9.0 * 10.0;  // r=3 through 10 mm
    const double vol1 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol0 - vol1 == Approx(expected_drop).epsilon(0.01));

    // Edit diameter via set_params + regenerate → volume tracks.
    json p = graph.feature(hole_fid)->params;
    p["diameter"] = 8.0;
    REQUIRE(graph.set_params(hole_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    const double expected_drop2 = M_PI * 16.0 * 10.0;  // r=4
    const double vol2 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol0 - vol2 == Approx(expected_drop2).epsilon(0.01));

    // Suppress → volume restored to solid box.
    REQUIRE(graph.set_suppressed(hole_fid, true));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol0).epsilon(1e-6));

    REQUIRE(graph.set_suppressed(hole_fid, false));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol2).epsilon(1e-6));

    // JSON round-trip preserves the hole feature.
    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.timeline().size() == 2);
    const Feature* rh = restored.feature(hole_fid);
    REQUIRE(rh != nullptr);
    REQUIRE(rh->type == FeatureType::Hole);
    REQUIRE(rh->params.at("target").get<std::string>() == box_fid.str());
    REQUIRE(rh->params.at("type").get<std::string>() == "simple");
    REQUIRE(rh->params.at("diameter").get<double>() == Approx(8.0));
    REQUIRE(rh->params.at("depth").get<double>() == Approx(0.0));

    Document doc2;
    REQUIRE(restored.regenerate(doc2, &err));
    EntityId body2 = restored.feature(box_fid)->output_body;
    REQUIRE(shape::volume(doc2.body(body2)->shape) == Approx(vol2).epsilon(1e-6));
}

TEST_CASE("holewizard: multi-point simple holes volume drop + parametric edit",
          "[feathole][holewizard]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature hole;
    hole.type = FeatureType::Hole;
    hole.params = {{"target", box_fid.str()},
                   {"type", "simple"},
                   {"positions", json::array({json::array({10.0, 10.0, 10.0}),
                                              json::array({30.0, 30.0, 10.0})})},
                   {"direction", json::array({0.0, 0.0, -1.0})},
                   {"diameter", 6.0},
                   {"depth", 0.0},
                   {"cb_diameter", 0.0},
                   {"cb_depth", 0.0},
                   {"cs_diameter", 0.0},
                   {"cs_angle_deg", 90.0}};
    auto hole_fid = graph.add(std::move(hole));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);

    const double vol0 = 40.0 * 40.0 * 10.0;
    const double expected_drop = 2.0 * M_PI * 9.0 * 10.0;  // two Ø6 through 10 mm
    const double vol1 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol0 - vol1 == Approx(expected_drop).epsilon(0.01));

    // Parametric: change diameter → both holes update.
    json p = graph.feature(hole_fid)->params;
    p["diameter"] = 8.0;
    REQUIRE(graph.set_params(hole_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    const double expected_drop2 = 2.0 * M_PI * 16.0 * 10.0;  // r=4 × 2
    const double vol2 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol0 - vol2 == Approx(expected_drop2).epsilon(0.01));

    // positions wins over position when both are present.
    p["position"] = json::array({20.0, 20.0, 10.0});
    p["diameter"] = 6.0;
    REQUIRE(graph.set_params(hole_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    const double vol3 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol0 - vol3 == Approx(expected_drop).epsilon(0.01));
}

TEST_CASE("holewizard: single position still works (regression)", "[feathole][holewizard]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature hole;
    hole.type = FeatureType::Hole;
    hole.params = {{"target", box_fid.str()},
                   {"type", "simple"},
                   {"position", json::array({10.0, 10.0, 10.0})},
                   {"direction", json::array({0.0, 0.0, -1.0})},
                   {"diameter", 6.0},
                   {"depth", 0.0}};
    graph.add(std::move(hole));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    const double vol0 = 20.0 * 20.0 * 10.0;
    const double expected_drop = M_PI * 9.0 * 10.0;
    REQUIRE(vol0 - shape::volume(doc.body(body_id)->shape) == Approx(expected_drop).epsilon(0.01));
}
