#include <catch.hpp>

#include "sx/catalog.hpp"

using namespace sx;

TEST_CASE("mechanic-tool catalog exposes hex socket + open-end", "[wave6_5][catalog]") {
    // Hex socket sizes present
    auto sockets = catalog::mechanic_tools_of_kind("hex_socket");
    REQUIRE(!sockets.empty());
    bool has_af10 = false;
    for (const auto& t : sockets) {
        if (t.designation == "AF10" && t.af_mm == Approx(10.0)) {
            has_af10 = true;
            break;
        }
    }
    CHECK(has_af10);

    // Open-end wrench AF table present
    auto opens = catalog::mechanic_tools_of_kind("open_end");
    REQUIRE(!opens.empty());
    bool has_open_af10 = false;
    for (const auto& t : opens) {
        if (t.designation == "AF10" && t.af_mm == Approx(10.0)) {
            has_open_af10 = true;
            break;
        }
    }
    CHECK(has_open_af10);
}

