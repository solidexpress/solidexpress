#include <catch.hpp>

#include "test_temp.hpp"

#include <cmath>
#include <fstream>
#include <string>

#include "sx/document.hpp"
#include "sx/dxf.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using Tmp = sx::test::TmpFile;

TEST_CASE("drawing DXF of a Ø20 disc has one CIRCLE of radius 10", "[dxf][export]") {
    Document doc;
    // Axis along +Y so the default front view (look +Y, up +Z) sees the disc.
    doc.add_body(shape::make_cylinder(10.0, 1.0, {{0, -0.5, 0}, {0, 1, 0}, {1, 0, 0}}), "disc");
    Tmp f("sx_disc.dxf");
    std::string err;
    REQUIRE(export_drawing_dxf(doc, f.path, &err));
    auto ents = read_dxf(f.path, &err);
    int circles = 0;
    for (const auto& e : ents) {
        if (e.kind == DxfEntity::Kind::Circle && std::abs(e.radius - 10.0) < 1e-9) ++circles;
    }
    REQUIRE(circles == 1);
}

TEST_CASE("bulged LWPOLYLINE imports as lines+arcs with radii within 1e-9", "[dxf][import]") {
    Tmp f("sx_bulge.dxf");
    {
        std::ofstream out(f.path);
        // Closed: line (0,0)-(20,0), semicircle bulge=1 back via (10,10), verticals omitted.
        // Rectangle with one semicircular side: (0,0)->(20,0) line, (20,0)->(0,0) bulge=1
        // (upper semicircle r=10).
        out << "0\nSECTION\n2\nENTITIES\n"
            << "0\nLWPOLYLINE\n90\n2\n70\n1\n"
            << "10\n0\n20\n0\n42\n0\n"
            << "10\n20\n20\n0\n42\n1\n"
            << "0\nENDSEC\n0\nEOF\n";
    }
    std::string err;
    auto ents = read_dxf(f.path, &err);
    REQUIRE(ents.size() == 2);
    int lines = 0, arcs = 0;
    double arc_r = 0;
    for (const auto& e : ents) {
        if (e.kind == DxfEntity::Kind::Line) ++lines;
        if (e.kind == DxfEntity::Kind::Arc) {
            ++arcs;
            arc_r = e.radius;
        }
    }
    CHECK(lines == 1);
    CHECK(arcs == 1);
    CHECK(arc_r == Approx(10.0).margin(1e-9));

    Sketch sk;
    REQUIRE(add_dxf_to_sketch(sk, ents) == 2);
    int sketch_arcs = 0;
    for (const auto& e : sk.entities()) {
        if (e.type == SketchEntityType::Arc) {
            ++sketch_arcs;
            CHECK(sk.param(e.params[2]) == Approx(10.0).margin(1e-9));
        }
    }
    CHECK(sketch_arcs == 1);
}

TEST_CASE("DXF ELLIPSE and SPLINE import, HATCH is refused", "[dxf][import]") {
    Tmp ok("sx_ell_spl.dxf");
    {
        std::ofstream out(ok.path);
        out << "0\nSECTION\n2\nENTITIES\n"
            << "0\nELLIPSE\n10\n0\n20\n0\n11\n8\n21\n0\n40\n0.5\n41\n0\n42\n6.283185307179586\n"
            << "0\nSPLINE\n70\n8\n71\n3\n73\n3\n10\n0\n20\n0\n10\n5\n20\n4\n10\n10\n20\n0\n"
            << "0\nENDSEC\n0\nEOF\n";
    }
    std::string err;
    auto ents = read_dxf(ok.path, &err);
    int ell = 0, spl = 0;
    for (const auto& e : ents) {
        if (e.kind == DxfEntity::Kind::Ellipse) ++ell;
        if (e.kind == DxfEntity::Kind::Spline) ++spl;
    }
    CHECK(ell == 1);
    CHECK(spl == 1);
    Sketch sk;
    CHECK(add_dxf_to_sketch(sk, ents) == 2);

    Tmp bad("sx_hatch.dxf");
    {
        std::ofstream out(bad.path);
        out << "0\nSECTION\n2\nENTITIES\n0\nHATCH\n0\nENDSEC\n0\nEOF\n";
    }
    err.clear();
    auto none = read_dxf(bad.path, &err);
    CHECK(none.empty());
    CHECK(err.find("refused:") != std::string::npos);
    CHECK(err.find("HATCH") != std::string::npos);
}
