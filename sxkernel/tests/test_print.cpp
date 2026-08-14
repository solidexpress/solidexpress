#include <catch.hpp>

#include <miniz.h>

#include <cstdio>
#include <fstream>
#include <sstream>

#include "sx/command.hpp"
#include "sx/commands_boolean.hpp"
#include "sx/document.hpp"
#include "sx/interop.hpp"
#include "sx/print.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;

namespace {

struct Tmp {
    std::string path;
    explicit Tmp(const char* name) { path = std::string("/tmp/") + name; }
    ~Tmp() { std::remove(path.c_str()); }
};

std::string slurp(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::ostringstream ss;
    ss << in.rdbuf();
    return ss.str();
}

}  // namespace

TEST_CASE("print analyze: cube min wall is the thickness", "[print]") {
    Document doc;
    const EntityId body = doc.add_body(shape::make_box(20, 20, 20), "cube");
    const PrintReport r = print_analyze(doc, body);
    CHECK(r.min_wall == Approx(20.0).margin(0.3));
    CHECK(r.wall_ok);
    CHECK(r.fits_bed);
    CHECK(r.digest.find("min wall") != std::string::npos);
}

TEST_CASE("print analyze: thin plate fails the wall threshold", "[print]") {
    Document doc;
    const EntityId body = doc.add_body(shape::make_box(20, 20, 1.2), "plate");
    PrintSetup s = doc.print_setup();
    s.min_wall = 2.0;
    doc.set_print_setup(s);
    const PrintReport r = print_analyze(doc, body);
    CHECK(r.min_wall == Approx(1.2).margin(0.15));
    CHECK_FALSE(r.wall_ok);
    CHECK(r.digest.find("thin") != std::string::npos);
}

TEST_CASE("print analyze: L-shelf has overhang area", "[print]") {
    Document doc;
    CommandStack stack;
    const EntityId base = doc.add_body(shape::make_box(40, 10, 10), "base");
    shape::Placement p;
    p.origin = {30, 0, 10};
    const EntityId shelf = doc.add_body(shape::make_box(20, 10, 10, p), "shelf");
    stack.push(doc, std::make_unique<BooleanCommand>(base, shelf, BooleanOp::Fuse));
    const PrintReport r = print_analyze(doc, base);
    CHECK(r.overhang_area > 50.0);
    CHECK_FALSE(r.overhang_ok);
}

TEST_CASE("print orient lays a tall box down", "[print]") {
    Document doc;
    const EntityId body = doc.add_body(shape::make_box(10, 10, 80), "tower");
    const PrintReport before = print_analyze(doc, body);
    CHECK(before.height == Approx(80.0).margin(0.2));
    const PrintReport after = print_orient(doc, body);
    CHECK(after.height == Approx(10.0).margin(0.3));
    CHECK(after.height < before.height);
}

TEST_CASE("print 3MF carries bed metadata and sxp round-trips setup", "[print]") {
    Document doc;
    doc.add_body(shape::make_box(10, 10, 10), "cube");
    PrintSetup s = doc.print_setup();
    s.bed_x = 180;
    s.bed_y = 180;
    s.min_wall = 1.6;
    doc.set_print_setup(s);

    Tmp mf("sx_print.3mf");
    std::string err;
    REQUIRE(interop::export_3mf(doc, mf.path, &err));
    mz_zip_archive zip{};
    REQUIRE(mz_zip_reader_init_file(&zip, mf.path.c_str(), 0));
    size_t sz = 0;
    void* p = mz_zip_reader_extract_file_to_heap(&zip, "3D/3dmodel.model", &sz, 0);
    REQUIRE(p != nullptr);
    const std::string xml(static_cast<char*>(p), sz);
    mz_free(p);
    mz_zip_reader_end(&zip);
    CHECK(xml.find("sx:bed") != std::string::npos);
    CHECK(xml.find("180x180") != std::string::npos);
    CHECK(xml.find("unit=\"millimeter\"") != std::string::npos);

    Tmp sxp("sx_print.sxp");
    REQUIRE(save_sxp(doc, sxp.path, &err));
    Document loaded;
    REQUIRE(load_sxp(loaded, sxp.path, &err));
    CHECK(loaded.print_setup().bed_x == Approx(180.0));
    CHECK(loaded.print_setup().min_wall == Approx(1.6));
}
