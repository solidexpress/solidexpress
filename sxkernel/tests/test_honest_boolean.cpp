#include <catch.hpp>

#include <array>
#include <cmath>
#include <string>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

namespace {

EntityId add_box(FeatureGraph& g, double a, double b, double c,
                 std::array<double, 3> origin = {0, 0, 0}) {
    Feature f;
    f.type = FeatureType::Primitive;
    f.params = {{"kind", "box"},
                {"a", a},
                {"b", b},
                {"c", c},
                {"origin", json::array({origin[0], origin[1], origin[2]})}};
    return g.add(std::move(f));
}

bool warning_has(const FeatureGraph& g, const char* needle) {
    for (const auto& w : g.warnings())
        if (w.second.find(needle) != std::string::npos) return true;
    return false;
}

}  // namespace

TEST_CASE("honest fuse: touching boxes, zero fuzz, volume = sum", "[exactness][boolean]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    auto a = add_box(g, 10, 10, 10);
    auto b = add_box(g, 10, 10, 10, {10, 0, 0});
    Feature fuse;
    fuse.type = FeatureType::Boolean;
    fuse.params = {{"op", "fuse"}, {"target", a.str()}, {"tool", b.str()}};
    g.add(std::move(fuse));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* body = doc.body(g.feature(a)->output_body);
    REQUIRE(body != nullptr);
    json probe = exactness::probe_shape(body->shape);
    const double vol = probe["volume"].get<double>();
    const double sum = 2000.0;
    REQUIRE(std::abs(vol - sum) / sum < 1e-9);
    CHECK_FALSE(warning_has(g, "boolean fuzz"));
}

TEST_CASE("honest fuse: 0.05 gap writes fuzz warning", "[exactness][boolean]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    auto a = add_box(g, 10, 10, 10);
    auto b = add_box(g, 10, 10, 10, {10.01, 0, 0});
    Feature fuse;
    fuse.type = FeatureType::Boolean;
    fuse.params = {{"op", "fuse"}, {"target", a.str()}, {"tool", b.str()}};
    g.add(std::move(fuse));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    std::string allw;
    for (const auto& w : g.warnings()) allw += w.second + ";";
    const Body* body = doc.body(g.feature(a)->output_body);
    const double vol = body ? shape::volume(body->shape) : 0.0;
    CAPTURE(allw, vol, g.warnings().size());
    REQUIRE(warning_has(g, "0.05"));
}
