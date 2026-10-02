#include <catch.hpp>

#include "test_temp.hpp"
#include <cmath>
#include <cstdio>
#include <string>

#include <miniz.h>

#include "sx/document.hpp"
#include "sx/sxp.hpp"

using namespace sx;
using sx::test::TmpFile;

namespace {
bool approx3(const std::array<double, 3>& a, const std::array<double, 3>& b,
             double eps = 1e-9) {
    return std::abs(a[0] - b[0]) < eps && std::abs(a[1] - b[1]) < eps &&
           std::abs(a[2] - b[2]) < eps;
}
}  // namespace

TEST_CASE("document stores and removes datums", "[datumdoc]") {
    Document doc;
    REQUIRE(doc.datums().empty());

    auto plane_id = doc.add_datum_plane({0, 0, 0}, {0, 0, 1});
    auto axis_id = doc.add_datum_axis({1, 2, 3}, {0, 1, 0});
    auto point_id = doc.add_datum_point({4, 5, 6});

    REQUIRE(!plane_id.is_null());
    REQUIRE(!axis_id.is_null());
    REQUIRE(!point_id.is_null());
    REQUIRE(doc.datums().size() == 3);

    REQUIRE(std::holds_alternative<DatumPlane>(doc.datums()[0]));
    REQUIRE(std::holds_alternative<DatumAxis>(doc.datums()[1]));
    REQUIRE(std::holds_alternative<DatumPoint>(doc.datums()[2]));

    const auto& plane = std::get<DatumPlane>(doc.datums()[0]);
    REQUIRE(plane.id == plane_id);
    REQUIRE(plane.name == "Datum Plane 1");
    REQUIRE(approx3(plane.origin, {0, 0, 0}));
    REQUIRE(approx3(plane.normal, {0, 0, 1}));

    const auto& axis = std::get<DatumAxis>(doc.datums()[1]);
    REQUIRE(axis.id == axis_id);
    REQUIRE(approx3(axis.point, {1, 2, 3}));
    REQUIRE(approx3(axis.direction, {0, 1, 0}));

    const auto& point = std::get<DatumPoint>(doc.datums()[2]);
    REQUIRE(point.id == point_id);
    REQUIRE(approx3(point.position, {4, 5, 6}));

    REQUIRE(doc.remove_datum(axis_id));
    REQUIRE(doc.datums().size() == 2);
    REQUIRE(!doc.remove_datum(axis_id));
    REQUIRE(doc.remove_datum(plane_id));
    REQUIRE(doc.remove_datum(point_id));
    REQUIRE(doc.datums().empty());
}

TEST_CASE("sxp round-trips datums", "[datumdoc][sxp]") {
    TmpFile f("datums_roundtrip.sxp");

    Document doc;
    auto plane_id = doc.add_datum_plane({10, 0, 0}, {1, 0, 0});
    auto axis_id = doc.add_datum_axis({0, 0, 0}, {0, 0, 1});
    auto point_id = doc.add_datum_point({7, 8, 9});
    const auto plane_name = std::get<DatumPlane>(doc.datums()[0]).name;
    const auto plane_x = std::get<DatumPlane>(doc.datums()[0]).x_dir;

    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));

    Document loaded;
    REQUIRE(load_sxp(loaded, f.path, &err));
    REQUIRE(loaded.datums().size() == 3);

    REQUIRE(std::holds_alternative<DatumPlane>(loaded.datums()[0]));
    const auto& p = std::get<DatumPlane>(loaded.datums()[0]);
    REQUIRE(p.id == plane_id);
    REQUIRE(p.name == plane_name);
    REQUIRE(approx3(p.origin, {10, 0, 0}));
    REQUIRE(approx3(p.normal, {1, 0, 0}));
    REQUIRE(approx3(p.x_dir, plane_x));

    REQUIRE(std::holds_alternative<DatumAxis>(loaded.datums()[1]));
    REQUIRE(std::get<DatumAxis>(loaded.datums()[1]).id == axis_id);

    REQUIRE(std::holds_alternative<DatumPoint>(loaded.datums()[2]));
    REQUIRE(std::get<DatumPoint>(loaded.datums()[2]).id == point_id);
    REQUIRE(approx3(std::get<DatumPoint>(loaded.datums()[2]).position, {7, 8, 9}));
}

TEST_CASE("sxp load tolerates missing datums.json", "[datumdoc][sxp]") {
    TmpFile f("datums_legacy.sxp");

    // Minimal pre-datum .sxp: manifest only, no datums.json.
    mz_zip_archive zip{};
    REQUIRE(mz_zip_writer_init_file(&zip, f.path.c_str(), 0));
    const std::string manifest =
        R"({"format":"sxp","version":1,"bodies":[]})";
    REQUIRE(mz_zip_writer_add_mem(&zip, "manifest.json", manifest.data(),
                                  manifest.size(), MZ_DEFAULT_COMPRESSION));
    REQUIRE(mz_zip_writer_finalize_archive(&zip));
    mz_zip_writer_end(&zip);

    Document doc;
    doc.add_datum_point({1, 2, 3});  // should be cleared on load
    REQUIRE(doc.datums().size() == 1);

    std::string err;
    REQUIRE(load_sxp(doc, f.path, &err));
    REQUIRE(doc.datums().empty());
    REQUIRE(doc.body_ids().empty());
}

TEST_CASE("sxp load with zero datums leaves empty list", "[datumdoc][sxp]") {
    TmpFile f("datums_empty.sxp");
    Document doc;
    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));

    Document loaded;
    loaded.add_datum_axis({0, 0, 0}, {1, 0, 0});
    REQUIRE(load_sxp(loaded, f.path, &err));
    REQUIRE(loaded.datums().empty());
}
