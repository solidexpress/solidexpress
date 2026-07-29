#include <catch.hpp>

#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("mirror: body mode still creates mirrored body", "[features][mirror]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.params = {{"target", box_fid.str()},
                  {"plane_point", json::array({15.0, 0.0, 0.0})},
                  {"plane_normal", json::array({1.0, 0.0, 0.0})}};
    auto mir_fid = graph.add(std::move(mir));

    REQUIRE(graph.has_dependents(box_fid));
    REQUIRE(graph.feature(mir_fid)->output_body.is_null() == false);

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId mirrored = graph.feature(mir_fid)->output_body;
    REQUIRE(doc.body(mirrored) != nullptr);
    REQUIRE(shape::volume(doc.body(mirrored)->shape) == Approx(1000.0).epsilon(1e-6));
    REQUIRE(shape::center_of_mass(doc.body(mirrored)->shape)[0] == Approx(25.0).epsilon(1e-6));
    REQUIRE(doc.body_ids().size() == 2);
}

TEST_CASE("mirror: feature mode mirrors extrude cut into same body", "[features][mirror]") {
    Document doc;
    FeatureGraph graph;

    // 40×40×10 box; mid-plane at x=20.
    Feature base;
    base.type = FeatureType::Primitive;
    base.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    auto base_fid = graph.add(std::move(base));

    // Off-center hole (circle r=5 at x=10, y=20) — mirror should place twin at x=30.
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Hole");
    skf.sketch->add_circle(10, 20, 5);
    auto sketch_fid = graph.add(std::move(skf));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", sketch_fid.str()},
                  {"distance", 10.0},
                  {"op", "cut"},
                  {"target", base_fid.str()}};
    auto cut_fid = graph.add(std::move(cut));

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.params = {{"source_feature_ids", json::array({cut_fid.str()})},
                  {"plane_point", json::array({20.0, 0.0, 0.0})},
                  {"plane_normal", json::array({1.0, 0.0, 0.0})},
                  {"target", base_fid.str()}};
    auto mir_fid = graph.add(std::move(mir));

    REQUIRE(graph.has_dependents(cut_fid));
    REQUIRE(graph.feature(mir_fid)->output_body.is_null());

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));

    EntityId body_id = graph.feature(base_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(doc.body_ids().size() == 1);

    const double hole = M_PI * 25.0 * 10.0;
    const double expected = 40.0 * 40.0 * 10.0 - 2.0 * hole;
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(expected).epsilon(1e-4));

    // Symmetric about the mid-plane → COM x ≈ 20.
    auto com = shape::center_of_mass(doc.body(body_id)->shape);
    REQUIRE(com[0] == Approx(20.0).epsilon(1e-3));
}

TEST_CASE("mirror: feature mode stays parametric when source cut edits", "[features][mirror]") {
    Document doc;
    FeatureGraph graph;

    Feature base;
    base.type = FeatureType::Primitive;
    base.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    auto base_fid = graph.add(std::move(base));

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Hole");
    skf.sketch->add_circle(10, 20, 5);
    auto sketch_fid = graph.add(std::move(skf));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", sketch_fid.str()},
                  {"distance", 10.0},
                  {"op", "cut"},
                  {"target", base_fid.str()}};
    auto cut_fid = graph.add(std::move(cut));

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.params = {{"source_feature_ids", json::array({cut_fid.str()})},
                  {"plane_point", json::array({20.0, 0.0, 0.0})},
                  {"plane_normal", json::array({1.0, 0.0, 0.0})},
                  {"target", base_fid.str()}};
    graph.add(std::move(mir));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(base_fid)->output_body;
    const double hole_full = M_PI * 25.0 * 10.0;
    REQUIRE(shape::volume(doc.body(body_id)->shape) ==
            Approx(16000.0 - 2.0 * hole_full).epsilon(1e-4));

    // Halve cut depth via set_params; mirrored tool rebuilds with new distance.
    json p = graph.feature(cut_fid)->params;
    p["distance"] = 5.0;
    REQUIRE(graph.set_params(cut_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    const double hole_half = M_PI * 25.0 * 5.0;
    REQUIRE(shape::volume(doc.body(body_id)->shape) ==
            Approx(16000.0 - 2.0 * hole_half).epsilon(1e-4));
}
