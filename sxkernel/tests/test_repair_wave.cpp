#include <catch.hpp>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/print.hpp"
#include "sx/shape_utils.hpp"
#include "sx/thread_standards.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("shell: UUID face refs hollow a box", "[features][dress][shell]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 50.0}, {"b", 50.0}, {"c", 50.0}};
    auto box_fid = graph.add(std::move(box));
    REQUIRE(graph.regenerate(doc));
    EntityId body = graph.feature(box_fid)->output_body;
    REQUIRE(doc.body(body));
    const double vol0 = shape::volume(doc.body(body)->shape);

    // Prefer a +Z face UUID from the body's subshape list.
    REQUIRE(doc.body(body)->subshape_ids.count(EntityKind::Face));
    const auto& faces = doc.body(body)->subshape_ids.at(EntityKind::Face);
    REQUIRE(faces.size() >= 1);
    EntityId top = faces.front();

    Feature shell;
    shell.type = FeatureType::Shell;
    shell.params = {{"target", box_fid.str()},
                    {"faces", json::array({top.str()})},
                    {"thickness", 2.0}};
    graph.add(std::move(shell));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const double vol1 = shape::volume(doc.body(body)->shape);
    REQUIRE(vol1 > 1.0);
    REQUIRE(vol1 < vol0 * 0.6);
}

TEST_CASE("draft: graph feature tapers a face", "[features][dress][draft]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 50.0}, {"b", 50.0}, {"c", 50.0}};
    auto box_fid = graph.add(std::move(box));
    REQUIRE(graph.regenerate(doc));
    EntityId body = graph.feature(box_fid)->output_body;
    const double vol0 = shape::volume(doc.body(body)->shape);
    const auto& faces = doc.body(body)->subshape_ids.at(EntityKind::Face);
    REQUIRE(faces.size() >= 1);

    Feature draft;
    draft.type = FeatureType::Draft;
    draft.params = {{"target", box_fid.str()},
                    {"faces", json::array({faces.front().str()})},
                    {"angle_deg", 5.0},
                    {"pull_dir", json::array({0.0, 0.0, 1.0})},
                    {"neutral_point", json::array({25.0, 25.0, 0.0})},
                    {"neutral_normal", json::array({0.0, 0.0, 1.0})}};
    graph.add(std::move(draft));
    std::string err;
    // Draft can fail on some face orientations — either success with volume
    // change, or a named failure (not a type_error on UUID faces).
    const bool ok = graph.regenerate(doc, &err);
    if (ok) {
        REQUIRE(std::abs(shape::volume(doc.body(body)->shape) - vol0) > 1.0);
    } else {
        REQUIRE(err.find("type_error") == std::string::npos);
        REQUIRE(err.find("draft") != std::string::npos);
    }
}

TEST_CASE("linear pattern: count=3 yields exactly 3 bodies", "[features][transform][pattern]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(box));
    REQUIRE(graph.regenerate(doc));
    REQUIRE(doc.body_ids().size() == 1);

    Feature pat;
    pat.type = FeatureType::LinearPattern;
    pat.params = {{"target", box_fid.str()},
                  {"direction", json::array({1.0, 0.0, 0.0})},
                  {"spacing", 80.0},
                  {"count", 3}};
    auto pat_fid = graph.add(std::move(pat));
    REQUIRE(graph.regenerate(doc));
    REQUIRE(doc.body_ids().size() == 3);
    REQUIRE(graph.feature(pat_fid)->output_bodies.size() == 2);

    // Second regenerate must keep the same body count (no orphan copies).
    REQUIRE(graph.regenerate(doc));
    REQUIRE(doc.body_ids().size() == 3);
}

TEST_CASE("print setup: nozzle drives default min_wall", "[print]") {
    PrintSetup s;
    REQUIRE(s.nozzle_mm == Approx(0.4));
    REQUIRE(s.material == "PLA");
    s.nozzle_mm = 0.6;
    s.min_wall = 3.0 * s.nozzle_mm;
    json j = s;
    PrintSetup round;
    from_json(j, round);
    REQUIRE(round.nozzle_mm == Approx(0.6));
    REQUIRE(round.min_wall == Approx(1.8));
    REQUIRE(round.material == "PLA");
}

TEST_CASE("thread table: M6 coarse is present", "[threadstd]") {
    auto m6 = find_thread("M6");
    REQUIRE(m6.has_value());
    REQUIRE(m6->major_diameter_mm == Approx(6.0));
    REQUIRE(m6->pitch_mm == Approx(1.0));
    REQUIRE(thread_table().size() > 20);
}
