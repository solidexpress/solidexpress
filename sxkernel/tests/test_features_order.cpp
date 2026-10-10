#include <catch.hpp>

#include "sx/features.hpp"

#include <stdexcept>
#include <string>

using namespace sx;

TEST_CASE("featorder: every FeatureType round-trips to_string / from_string", "[featorder]") {
    REQUIRE(kFeatureTypeCount == 35);
    int n = 0;
    for (int i = 0; i < kFeatureTypeCount; ++i) {
        const FeatureTypeInfo& row = kFeatureTypes[i];
        REQUIRE(row.name != nullptr);
        REQUIRE(std::string(to_string(row.type)) == row.name);
        REQUIRE(feature_type_from_string(row.name) == row.type);
        ++n;
    }
    REQUIRE(n == kFeatureTypeCount);
    REQUIRE_THROWS_AS(feature_type_from_string("not_a_feature"), std::invalid_argument);
    try {
        feature_type_from_string("not_a_feature");
        FAIL("expected throw");
    } catch (const std::invalid_argument& e) {
        REQUIRE(std::string(e.what()) == "unknown feature type: not_a_feature");
    }
}
