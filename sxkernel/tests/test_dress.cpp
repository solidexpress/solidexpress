#include <catch.hpp>

#include <cstdio>
#include <fstream>
#include <string>

#include "sx/commands_dress.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/log.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

TEST_CASE("fillet one edge of a box", "[dress]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    const Body* b0 = doc.body(body_id);
    REQUIRE(shape::volume(b0->shape) == Approx(1000.0));
    REQUIRE(shape::count(b0->shape).faces == 6);

    const auto edge_ids_before = b0->subshape_ids.at(EntityKind::Edge);
    REQUIRE(edge_ids_before.size() == 12);
    EntityId edge = edge_ids_before.front();

    stack.push(doc, std::make_unique<FilletCommand>(std::vector<EntityId>{edge}, 2.0));

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    const double vol = shape::volume(b->shape);
    // Removed material ≈ (4-pi)/4 * r^2 * length ≈ 8.58 for r=2, L=10
    REQUIRE(vol < 1000.0);
    REQUIRE(vol > 990.0);
    REQUIRE(shape::count(b->shape).faces == 7);

    REQUIRE(stack.undo(doc));
    b = doc.body(body_id);
    REQUIRE(shape::volume(b->shape) == Approx(1000.0).epsilon(1e-6));
    REQUIRE(b->subshape_ids.at(EntityKind::Edge) == edge_ids_before);

    REQUIRE(stack.redo(doc));
    b = doc.body(body_id);
    REQUIRE(shape::volume(b->shape) == Approx(vol).epsilon(1e-6));
    REQUIRE(shape::count(b->shape).faces == 7);
}

TEST_CASE("fillet all 12 edges of a box", "[dress]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    const auto& edge_ids = doc.body(body_id)->subshape_ids.at(EntityKind::Edge);
    REQUIRE(edge_ids.size() == 12);

    stack.push(doc, std::make_unique<FilletCommand>(edge_ids, 1.0));

    const Body* b = doc.body(body_id);
    REQUIRE(shape::is_valid(b->shape));
    const double vol = shape::volume(b->shape);
    REQUIRE(vol < 1000.0);
    REQUIRE(vol > 950.0);
}

TEST_CASE("chamfer one edge of a box", "[dress]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    EntityId edge = doc.body(body_id)->subshape_ids.at(EntityKind::Edge).front();

    stack.push(doc, std::make_unique<ChamferCommand>(std::vector<EntityId>{edge}, 2.0));

    const Body* b = doc.body(body_id);
    const double vol = shape::volume(b->shape);
    // Symmetric chamfer d=2 on a 90° edge removes 0.5*d^2*L = 20 → vol ≈ 980
    REQUIRE(vol > 970.0);
    REQUIRE(vol < 990.0);
    REQUIRE(shape::count(b->shape).faces == 7);

    REQUIRE(stack.undo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));

    REQUIRE(stack.redo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol).epsilon(1e-6));
    REQUIRE(shape::count(doc.body(body_id)->shape).faces == 7);
}

TEST_CASE("fillet rejects non-edge and oversized radius", "[dress]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");
    EntityId face = doc.body(body_id)->subshape_ids.at(EntityKind::Face).front();
    EntityId edge = doc.body(body_id)->subshape_ids.at(EntityKind::Edge).front();

    FilletCommand bad_kind({face}, 1.0);
    REQUIRE_THROWS_AS(bad_kind.execute(doc), std::invalid_argument);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));

    FilletCommand too_big({edge}, 20.0);
    REQUIRE_THROWS(too_big.execute(doc));
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));
}

namespace {

int count_log_level(const std::string& path, const std::string& level) {
    std::ifstream in(path);
    int n = 0;
    std::string line;
    const std::string tag = "[" + level + "]";
    while (std::getline(in, line)) {
        if (line.find(tag) != std::string::npos) ++n;
    }
    return n;
}

}  // namespace

TEST_CASE("stale fillet edges log one error only when face cues cannot recover them", "[dress]") {
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Box");
    skf.sketch->add_line(-5, -5, 5, -5);
    skf.sketch->add_line(5, -5, 5, 5);
    skf.sketch->add_line(5, 5, -5, 5);
    skf.sketch->add_line(-5, 5, -5, -5);
    const auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    const auto ext_id = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const auto body = graph.feature(ext_id)->output_body;
    const auto& edge_ids = doc.body(body)->subshape_ids.at(EntityKind::Edge);
    REQUIRE(edge_ids.size() == 12);
    // A cue is stored only for a face whose every edge is in the fillet.
    nlohmann::json edges = nlohmann::json::array();
    for (const auto& edge : edge_ids) edges.push_back(edge.str());

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.params = {{"target", ext_id.str()}, {"radius", 1.0}, {"edges", edges}};
    const auto fid = graph.add(std::move(fil));
    REQUIRE(graph.regenerate(doc, &err));
    Feature* feat = graph.feature(fid);
    REQUIRE(feat != nullptr);
    REQUIRE(feat->params.contains("face_cues"));
    REQUIRE(feat->params["face_cues"].is_array());
    REQUIRE_FALSE(feat->params["face_cues"].empty());

    const std::string path = "/tmp/sx-dress-stale-cues.log";
    feat->params["edges"] = nlohmann::json::array({"00000000-0000-4000-8000-000000000001"});
    std::remove(path.c_str());
    sx::log::set_file_sink(path);
    REQUIRE(graph.regenerate(doc, &err));
    sx::log::set_file_sink("");
    CHECK(count_log_level(path, "ERROR") == 0);

    feat = graph.feature(fid);
    REQUIRE(feat != nullptr);
    feat->params["edges"] = nlohmann::json::array({"00000000-0000-4000-8000-000000000002"});
    feat->params["face_cues"] = nlohmann::json::array();
    std::remove(path.c_str());
    sx::log::set_file_sink(path);
    REQUIRE(graph.regenerate(doc, &err));
    sx::log::set_file_sink("");
    CHECK(count_log_level(path, "ERROR") == 1);
}
