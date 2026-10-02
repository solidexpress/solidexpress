#include <catch.hpp>

#include "test_temp.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>
#include <sys/stat.h>
#include <vector>

#include "sx/document.hpp"
#include "sx/interop.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

namespace {

bool file_exists_nonzero(const std::string& path, size_t min_bytes) {
    struct stat st {};
    if (stat(path.c_str(), &st) != 0) return false;
    return static_cast<size_t>(st.st_size) > min_bytes;
}

}  // namespace

TEST_CASE("STEP round trip preserves body count and volumes", "[interop]") {
    const std::string path = sx::test::temp_path("sx_interop_test.step");
    std::remove(path.c_str());

    Document src;
    auto box_id = src.add_body(shape::make_box(10, 20, 30), "Box");
    auto cyl_id = src.add_body(shape::make_cylinder(5, 15), "Cyl");
    const double box_vol = shape::volume(src.body(box_id)->shape);
    const double cyl_vol = shape::volume(src.body(cyl_id)->shape);

    std::string err;
    REQUIRE(interop::export_step(src, path, &err));
    REQUIRE(err.empty());

    Document dst;
    auto ids = interop::import_step(dst, path, &err);
    REQUIRE(ids.size() == 2);
    REQUIRE(dst.body_ids().size() == 2);

    std::vector<double> vols;
    for (const auto& id : ids) {
        const Body* b = dst.body(id);
        REQUIRE(b != nullptr);
        REQUIRE(shape::is_valid(b->shape));
        vols.push_back(shape::volume(b->shape));
    }

    auto near = [](double a, double b) {
        const double denom = std::max(std::abs(b), 1e-12);
        return std::abs(a - b) / denom < 1e-4;
    };
    // Order is not guaranteed; match volumes.
    const bool matched =
        (near(vols[0], box_vol) && near(vols[1], cyl_vol)) ||
        (near(vols[0], cyl_vol) && near(vols[1], box_vol));
    REQUIRE(matched);

    std::remove(path.c_str());
}

TEST_CASE("IGES round trip imports geometry", "[interop]") {
    const std::string path = sx::test::temp_path("sx_interop_test.iges");
    std::remove(path.c_str());

    Document src;
    src.add_body(shape::make_box(10, 20, 30), "Box");

    std::string err;
    REQUIRE(interop::export_iges(src, path, &err));

    Document dst;
    auto ids = interop::import_iges(dst, path, &err);
    REQUIRE(ids.size() >= 1);

    const Body* b = dst.body(ids[0]);
    REQUIRE(b != nullptr);
    REQUIRE(!b->shape.IsNull());

    const double vol = shape::volume(b->shape);
    if (vol > 1e-6) {
        REQUIRE(vol == Approx(6000.0).epsilon(1e-3));
    } else {
        // Surface-oriented IGES may not sew into a solid; faces are enough.
        REQUIRE(shape::count(b->shape).faces > 0);
    }

    std::remove(path.c_str());
}

TEST_CASE("STL export and import", "[interop]") {
    const std::string path = sx::test::temp_path("sx_interop_test.stl");
    std::remove(path.c_str());

    Document src;
    src.add_body(shape::make_box(10, 20, 30), "Box");

    std::string err;
    REQUIRE(interop::export_stl(src, path, true, &err));
    REQUIRE(file_exists_nonzero(path, 100));

    Document dst;
    auto ids = interop::import_stl(dst, path, &err);
    REQUIRE(ids.size() == 1);
    const Body* b = dst.body(ids[0]);
    REQUIRE(b != nullptr);
    REQUIRE(b->name == "Mesh 1");
    REQUIRE(shape::count(b->shape).faces > 0);

    std::remove(path.c_str());
}

TEST_CASE("interop failure paths set err", "[interop]") {
    Document doc;
    doc.add_body(shape::make_box(1, 1, 1), "Box");

    std::string err;
    auto ids = interop::import_step(doc, sx::test::temp_path("sx_interop_missing_nope.step"), &err);
    REQUIRE(ids.empty());
    REQUIRE(!err.empty());

    err.clear();
    REQUIRE_FALSE(interop::export_step(doc, "/nonexistent_dir/x.step", &err));
    REQUIRE(!err.empty());
}
