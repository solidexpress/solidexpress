#include <catch.hpp>

#include <cmath>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"

using namespace sx;
using nlohmann::json;

namespace {

int count_type(const json& arr, const char* type) {
    int n = 0;
    for (const auto& e : arr)
        if (e.value("type", "") == type) ++n;
    return n;
}

const json* first_type(const json& arr, const char* type) {
    for (const auto& e : arr)
        if (e.value("type", "") == type) return &e;
    return nullptr;
}

}  // namespace

TEST_CASE("exactness: box + Ø10 hole is a Circle of radius 5", "[exactness]") {
    Document doc;
    EntityId hole_fid;
    EntityId body = exactness::add_box_hole(doc, 20.0, 20.0, 10.0, 10.0, nullptr, &hole_fid);
    json report = exactness::report_body(doc, body);
    REQUIRE(report.contains("edges"));
    REQUIRE(report.contains("volume"));

    const json* circle = first_type(report["edges"], "GeomAbs_Circle");
    REQUIRE(circle != nullptr);
    REQUIRE((*circle)["radius"].get<double>() == Approx(5.0).margin(1e-6));
    REQUIRE(count_type(report["edges"], "GeomAbs_Circle") >= 1);

    const double analytic = 20.0 * 20.0 * 10.0 - M_PI * 5.0 * 5.0 * 10.0;
    const double vol = report["volume"].get<double>();
    REQUIRE(std::abs(vol - analytic) / analytic < 1e-9);

    json features = exactness::report_features(doc);
    REQUIRE(features.size() == 2);
    const json* hole = nullptr;
    for (const auto& f : features)
        if (f.value("type", "") == "hole") hole = &f;
    REQUIRE(hole != nullptr);
    REQUIRE((*hole)["params"]["diameter"].get<double>() == Approx(10.0).margin(0.0));
    REQUIRE((*hole)["params"]["type"].get<std::string>() == "simple");
}

TEST_CASE("exactness: feature params round-trip as written", "[exactness]") {
    Document doc;
    EntityId hole_fid;
    EntityId body = exactness::add_box_hole(doc, 20.0, 20.0, 10.0, 10.0, nullptr, &hole_fid);
    const Feature* hole = doc.graph().feature(hole_fid);
    REQUIRE(hole != nullptr);
    REQUIRE(hole->params.at("diameter").get<double>() == 10.0);
    REQUIRE(hole->params.at("depth").get<double>() == 0.0);

    json dump = exactness::report(doc);
    REQUIRE(dump["features"].size() == 2);
    REQUIRE(dump["bodies"].size() == 1);
    REQUIRE(dump["bodies"][0]["id"].get<std::string>() == body.str());
}

TEST_CASE("exactness: sketch circle reports radius", "[exactness]") {
    Sketch sk;
    sk.add_circle(0.0, 0.0, 5.0);
    json j = exactness::report_sketch(sk);
    REQUIRE(j["entities"].size() == 1);
    REQUIRE(j["entities"][0]["type"] == "circle");
    REQUIRE(j["entities"][0]["radius"].get<double>() == Approx(5.0).margin(1e-12));
}
