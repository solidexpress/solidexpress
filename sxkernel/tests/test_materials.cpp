#include <catch.hpp>

#include "test_temp.hpp"

#include <cstdio>

#include "sx/document.hpp"
#include "sx/materials.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;

TEST_CASE("standard material table has sane entries", "[materials]") {
    const auto& table = materials::standard();
    REQUIRE(table.size() == 13);
    REQUIRE(table.front().name == "Unspecified");
    REQUIRE(table.front().density_g_cm3 == Approx(1.0));
    for (const auto& m : table) {
        CHECK(!m.name.empty());
        CHECK(m.density_g_cm3 > 0.0);
        CHECK(m.density_g_cm3 < 25.0);
    }
    auto pla = materials::find("PLA");
    REQUIRE(pla.has_value());
    CHECK(pla->density_g_cm3 == Approx(1.24));
    CHECK(!materials::find("Unobtainium").has_value());
    CHECK(!materials::find("Oak").has_value());
}

TEST_CASE("body material assignment validates against the table", "[materials]") {
    Document doc;
    auto id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    CHECK(doc.body(id)->material == "Unspecified");

    REQUIRE(doc.set_body_material(id, "PC"));
    CHECK(doc.body(id)->material == "PC");

    CHECK(!doc.set_body_material(id, "Unobtainium"));
    CHECK(doc.body(id)->material == "PC");
    CHECK(!doc.set_body_material(EntityId::generate(), "PLA"));
}

TEST_CASE("material survives sxp round-trip", "[materials][sxp]") {
    Document doc;
    auto id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    REQUIRE(doc.set_body_material(id, "TPU"));

    std::string path = sx::test::temp_path("sx_material_roundtrip.sxp");
    std::string err;
    REQUIRE(save_sxp(doc, path, &err));

    Document loaded;
    REQUIRE(load_sxp(loaded, path, &err));
    const Body* b = loaded.body(id);
    REQUIRE(b != nullptr);
    CHECK(b->material == "TPU");
    std::remove(path.c_str());
}
