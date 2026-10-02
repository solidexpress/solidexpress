#include <catch.hpp>

#include "test_temp.hpp"

#include <cstdio>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;

namespace {

// Expression-driven box (a = b = "=w", c = 10) with w preset to 20.
EntityId add_var_box(Document& doc) {
    doc.graph().variables().set("w", "20");
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", "=w"}, {"b", "=w"}, {"c", 10.0}};
    auto fid = doc.graph().add(std::move(box));
    REQUIRE(doc.graph().regenerate(doc));
    return fid;
}

}  // namespace

TEST_CASE("configurations snapshot and swap the variable table", "[configurations]") {
    Document doc;
    auto fid = add_var_box(doc);
    EntityId body_id = doc.graph().feature(fid)->output_body;
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(20.0 * 20.0 * 10.0));

    REQUIRE(doc.save_configuration("Small"));
    REQUIRE(doc.active_configuration() == "Small");

    doc.graph().variables().set("w", "40");
    REQUIRE(doc.save_configuration("Large"));
    REQUIRE(doc.configurations().size() == 2);

    // Switching back regenerates the small box (same stable body id).
    REQUIRE(doc.activate_configuration("Small"));
    REQUIRE(doc.graph().regenerate(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(20.0 * 20.0 * 10.0));

    REQUIRE(doc.activate_configuration("Large"));
    REQUIRE(doc.graph().regenerate(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(40.0 * 40.0 * 10.0));

    REQUIRE(!doc.activate_configuration("Missing"));
    REQUIRE(!doc.save_configuration(""));
}

TEST_CASE("saving over an existing configuration updates it", "[configurations]") {
    Document doc;
    add_var_box(doc);
    REQUIRE(doc.save_configuration("A"));
    doc.graph().variables().set("w", "33");
    REQUIRE(doc.save_configuration("A"));
    REQUIRE(doc.configurations().size() == 1);

    doc.graph().variables().set("w", "1");
    REQUIRE(doc.activate_configuration("A"));
    auto env = doc.graph().variables().evaluate();
    REQUIRE(env["w"] == Approx(33.0));
}

TEST_CASE("removing a configuration clears the active marker", "[configurations]") {
    Document doc;
    add_var_box(doc);
    REQUIRE(doc.save_configuration("Only"));
    REQUIRE(doc.remove_configuration("Only"));
    REQUIRE(doc.active_configuration().empty());
    REQUIRE(doc.configurations().empty());
    REQUIRE(!doc.remove_configuration("Only"));
}

TEST_CASE("configurations survive sxp round-trip", "[configurations][sxp]") {
    Document doc;
    add_var_box(doc);
    REQUIRE(doc.save_configuration("Small"));
    doc.graph().variables().set("w", "40");
    REQUIRE(doc.save_configuration("Large"));

    std::string path = sx::test::temp_path("sx_config_roundtrip.sxp");
    std::string err;
    REQUIRE(save_sxp(doc, path, &err));

    Document loaded;
    REQUIRE(load_sxp(loaded, path, &err));
    REQUIRE(loaded.configurations().size() == 2);
    REQUIRE(loaded.active_configuration() == "Large");

    REQUIRE(loaded.activate_configuration("Small"));
    auto env = loaded.graph().variables().evaluate();
    REQUIRE(env["w"] == Approx(20.0));
    std::remove(path.c_str());
}
