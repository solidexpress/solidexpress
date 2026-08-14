#include <catch.hpp>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/variables.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("variable expressions: precedence, parens, unary minus", "[variables]") {
    VariableTable t;
    t.set("a", "2");
    t.set("b", "3");
    auto m = t.evaluate();
    REQUIRE(m["a"] == Approx(2.0));
    REQUIRE(m["b"] == Approx(3.0));

    REQUIRE(eval_expression("2+3*4", {}) == Approx(14.0));
    REQUIRE(eval_expression("(2+3)*4", {}) == Approx(20.0));
    REQUIRE(eval_expression("-3+5", {}) == Approx(2.0));
    REQUIRE(eval_expression("-(2+3)", {}) == Approx(-5.0));
    REQUIRE(eval_expression("10/2-1", {}) == Approx(4.0));
    REQUIRE(eval_expression("2*-3", {}) == Approx(-6.0));

    std::map<std::string, double> env{{"w", 10.0}, {"h", 4.0}};
    REQUIRE(eval_expression("w*h/2", env) == Approx(20.0));
    REQUIRE(eval_expression("w + -h", env) == Approx(6.0));
}

TEST_CASE("variable expressions: chained refs and cycles", "[variables]") {
    VariableTable t;
    t.set("w", "20");
    t.set("h", "w/2");
    t.set("d", "h+1");
    auto m = t.evaluate();
    REQUIRE(m["w"] == Approx(20.0));
    REQUIRE(m["h"] == Approx(10.0));
    REQUIRE(m["d"] == Approx(11.0));

    VariableTable cycle;
    cycle.set("x", "y+1");
    cycle.set("y", "x+1");
    REQUIRE_THROWS_WITH(cycle.evaluate(), Catch::Matchers::Contains("cyclic"));

    VariableTable self;
    self.set("z", "z");
    REQUIRE_THROWS_WITH(self.evaluate(), Catch::Matchers::Contains("cyclic"));
}

TEST_CASE("variable table json round trip", "[variables]") {
    VariableTable t;
    t.set("w", "20");
    t.set("h", "w*2");
    auto restored = VariableTable::from_json(t.to_json());
    auto m = restored.evaluate();
    REQUIRE(m["w"] == Approx(20.0));
    REQUIRE(m["h"] == Approx(40.0));
    REQUIRE(VariableTable::from_json(json::object()).entries().empty());
}

TEST_CASE("num_param resolves =expressions", "[variables]") {
    std::map<std::string, double> env{{"w", 15.0}};
    json p = {{"distance", 10.0}, {"radius", "=w*2"}, {"depth", "=w"}};
    REQUIRE(num_param(p, "distance", 0.0, env) == Approx(10.0));
    REQUIRE(num_param(p, "radius", 0.0, env) == Approx(30.0));
    REQUIRE(num_param(p, "missing", 7.0, env) == Approx(7.0));
    REQUIRE(num_param(p, "depth", 0.0, env) == Approx(15.0));
}

TEST_CASE("num_param accepts plain numeric strings", "[variables]") {
    std::map<std::string, double> env{};
    json p = {{"a", "10"}, {"b", "  20.5  "}, {"c", "-3.25"}};
    REQUIRE(num_param(p, "a", 0.0, env) == Approx(10.0));
    REQUIRE(num_param(p, "b", 0.0, env) == Approx(20.5));
    REQUIRE(num_param(p, "c", 0.0, env) == Approx(-3.25));
}

TEST_CASE("feature graph: expression-driven box tracks variable", "[variables]") {
    Document doc;
    FeatureGraph graph;
    graph.variables().set("w", "20");

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", "=w"}, {"b", "=w"}, {"c", "10"}};
    // c as plain number string would fail — use number or =expr
    box.params["c"] = 10.0;
    auto fid = graph.add(std::move(box));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(fid)->output_body;
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(20.0 * 20.0 * 10.0));

    graph.variables().set("w", "30");
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(30.0 * 30.0 * 10.0));
}

TEST_CASE("feature graph: variables + expression params json round trip", "[variables]") {
    FeatureGraph graph;
    graph.variables().set("w", "20");
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", "=w"}, {"b", "=w"}, {"c", 10.0}};
    auto fid = graph.add(std::move(box));

    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.variables().contains("w"));
    REQUIRE(*restored.variables().get("w") == "20");
    REQUIRE(restored.feature(fid)->params["a"] == "=w");

    Document doc;
    std::string err;
    REQUIRE(restored.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(restored.feature(fid)->output_body)->shape) ==
            Approx(4000.0));

    // Absent variables key stays empty (backward compatible).
    json bare = {{"timeline", graph.to_json()["timeline"]}};
    FeatureGraph empty_vars = FeatureGraph::from_json(bare);
    REQUIRE(empty_vars.variables().entries().empty());
}

TEST_CASE("feature graph: missing variable fails regenerate with feature name",
          "[variables]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.name = "SizedBox";
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", "=missing_w"}, {"b", 10.0}, {"c", 10.0}};
    graph.add(std::move(box));

    std::string err;
    REQUIRE(!graph.regenerate(doc, &err));
    REQUIRE(err.find("SizedBox") != std::string::npos);
    REQUIRE(err.find("missing_w") != std::string::npos);
}
