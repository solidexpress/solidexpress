#include <catch.hpp>

#include "test_temp.hpp"

#include <miniz.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/interop.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;
using sx::test::TmpFile;

namespace {

bool mesh_bbox(const std::string& path, double out_min[3], double out_max[3]) {
    mz_zip_archive zip{};
    if (!mz_zip_reader_init_file(&zip, path.c_str(), 0)) return false;
    size_t sz = 0;
    void* p = mz_zip_reader_extract_file_to_heap(&zip, "3D/3dmodel.model", &sz, 0);
    mz_zip_reader_end(&zip);
    if (p == nullptr) return false;
    const std::string xml(static_cast<char*>(p), sz);
    mz_free(p);
    bool any = false;
    size_t pos = 0;
    while ((pos = xml.find("vertex x=\"", pos)) != std::string::npos) {
        double x = 0, y = 0, z = 0;
        if (std::sscanf(xml.c_str() + pos, "vertex x=\"%lf\" y=\"%lf\" z=\"%lf\"", &x, &y, &z) ==
            3) {
            if (!any) {
                out_min[0] = out_max[0] = x;
                out_min[1] = out_max[1] = y;
                out_min[2] = out_max[2] = z;
                any = true;
            } else {
                out_min[0] = std::min(out_min[0], x);
                out_min[1] = std::min(out_min[1], y);
                out_min[2] = std::min(out_min[2], z);
                out_max[0] = std::max(out_max[0], x);
                out_max[1] = std::max(out_max[1], y);
                out_max[2] = std::max(out_max[2], z);
            }
        }
        pos += 10;
    }
    return any;
}

}  // namespace

TEST_CASE("3MF of two instances 100 mm apart spans the gap", "[assembly][export]") {
    Document doc;
    doc.set_kind(Document::Kind::Assembly);
    const auto src = doc.add_body(shape::make_box(10, 10, 10), "Box");
    REQUIRE(!src.is_null());
    REQUIRE(!doc.add_instance(src, {0, 0, 0}, {0, 0, 0, 1}, "A").is_null());
    REQUIRE(!doc.add_instance(src, {100, 0, 0}, {0, 0, 0, 1}, "B").is_null());

    TmpFile mf("sx_assembly_span.3mf");
    std::string err;
    REQUIRE(interop::export_3mf(doc, mf.path, &err));
    CHECK(err.empty());

    double mn[3]{}, mx[3]{};
    REQUIRE(mesh_bbox(mf.path, mn, mx));
    const double dx = mx[0] - mn[0];
    // Stacked sources at identity span ~10. Placed instances span ~110.
    REQUIRE(dx >= 90.0);
    CHECK(mn[0] == Approx(0.0).margin(0.5));
    CHECK(mx[0] == Approx(110.0).margin(0.5));
}

TEST_CASE("part 3MF without instances stays body-at-identity", "[assembly][export]") {
    Document doc;
    doc.add_body(shape::make_box(10, 20, 30), "Box");
    TmpFile mf("sx_part_identity.3mf");
    std::string err;
    REQUIRE(interop::export_3mf(doc, mf.path, &err));
    double mn[3]{}, mx[3]{};
    REQUIRE(mesh_bbox(mf.path, mn, mx));
    CHECK(mn[0] == Approx(0.0).margin(0.5));
    CHECK(mx[0] == Approx(10.0).margin(0.5));
    CHECK(mx[1] - mn[1] == Approx(20.0).margin(0.5));
    CHECK(mx[2] - mn[2] == Approx(30.0).margin(0.5));
}
