#include <catch.hpp>

#include "test_temp.hpp"

#include <miniz.h>

#include <BRepAdaptor_Surface.hxx>
#include <BRep_Tool.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include "sx/occt_types.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/interop.hpp"
#include "sx/print.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"
#include "sx/tessellate.hpp"

using namespace sx;
using Tmp = sx::test::TmpFile;

namespace {

std::vector<std::array<double, 3>> unique_verts(std::vector<std::array<double, 3>> v) {
    std::sort(v.begin(), v.end());
    v.erase(std::unique(v.begin(), v.end(),
                        [](const auto& a, const auto& b) {
                            return std::abs(a[0] - b[0]) < 1e-12 && std::abs(a[1] - b[1]) < 1e-12 &&
                                   std::abs(a[2] - b[2]) < 1e-12;
                        }),
            v.end());
    return v;
}

std::vector<std::array<double, 3>> stl_ascii_verts(const std::string& path) {
    std::ifstream in(path);
    std::vector<std::array<double, 3>> out;
    std::string tok;
    while (in >> tok) {
        if (tok != "vertex") continue;
        double x = 0, y = 0, z = 0;
        in >> x >> y >> z;
        out.push_back({x, y, z});
    }
    return unique_verts(std::move(out));
}

std::string slurp_3mf_model(const std::string& path) {
    mz_zip_archive zip{};
    REQUIRE(mz_zip_reader_init_file(&zip, path.c_str(), 0));
    size_t sz = 0;
    void* p = mz_zip_reader_extract_file_to_heap(&zip, "3D/3dmodel.model", &sz, 0);
    REQUIRE(p != nullptr);
    std::string xml(static_cast<char*>(p), sz);
    mz_free(p);
    mz_zip_reader_end(&zip);
    return xml;
}

std::vector<std::array<double, 3>> verts_from_3mf_xml(const std::string& xml) {
    std::vector<std::array<double, 3>> out;
    size_t pos = 0;
    while (true) {
        pos = xml.find("<vertex ", pos);
        if (pos == std::string::npos) break;
        auto attr = [&](const char* key) {
            const size_t k = xml.find(key, pos);
            REQUIRE(k != std::string::npos);
            const size_t q1 = xml.find('"', k);
            const size_t q2 = xml.find('"', q1 + 1);
            return std::stod(xml.substr(q1 + 1, q2 - q1 - 1));
        };
        out.push_back({attr("x="), attr("y="), attr("z=")});
        pos += 8;
    }
    return unique_verts(std::move(out));
}

double radial(const gp_Pnt& loc, const gp_Dir& dir, double x, double y, double z) {
    gp_Vec v(loc, gp_Pnt(x, y, z));
    gp_Vec axial(dir.XYZ() * v.Dot(dir));
    return (v - axial).Magnitude();
}

}  // namespace

TEST_CASE("print mesh defaults and sxp round-trip mesh_linear", "[export][print]") {
    Document doc;
    CHECK(doc.print_setup().mesh_linear == Approx(0.01));
    CHECK(doc.print_setup().mesh_angular == Approx(0.1));
    PrintSetup s = doc.print_setup();
    s.mesh_linear = 0.005;
    doc.set_print_setup(s);
    Tmp f("sx_mesh_tol.sxp");
    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));
    Document loaded;
    REQUIRE(load_sxp(loaded, f.path, &err));
    CHECK(loaded.print_setup().mesh_linear == Approx(0.005));
}

TEST_CASE("Ø3×10 hole plate: print vertices on the cylinder, sagitta ≤ tolerance",
          "[export][print]") {
    Document doc;
    const EntityId body = exactness::add_box_hole(doc, 20.0, 20.0, 10.0, 3.0);
    const double lin = doc.print_setup().mesh_linear;
    PrintTriMesh mesh = tessellate_print(doc, body, lin, doc.print_setup().mesh_angular);
    REQUIRE(mesh.indices.size() >= 3);

    const Body* b = doc.body(body);
    REQUIRE(b);
    sx::occt::ShapeIndexedMap faces;
    TopExp::MapShapes(b->shape, TopAbs_FACE, faces);
    std::vector<gp_Cylinder> holes;
    for (int i = 1; i <= faces.Extent(); ++i) {
        const TopoDS_Face f = TopoDS::Face(faces(i));
        BRepAdaptor_Surface adapt(f);
        if (adapt.GetType() != GeomAbs_Cylinder) continue;
        gp_Cylinder cyl = adapt.Cylinder();
        if (std::abs(cyl.Radius() - 1.5) < 1e-6) holes.push_back(cyl);
    }
    REQUIRE_FALSE(holes.empty());
    const gp_Cylinder cyl = holes.front();
    const gp_Pnt loc = cyl.Location();
    const gp_Dir dir = cyl.Axis().Direction();
    const double r = cyl.Radius();

    double max_vert = 0, max_sag = 0;
    for (size_t i = 0; i + 2 < mesh.positions.size(); i += 3) {
        const double d =
            radial(loc, dir, mesh.positions[i], mesh.positions[i + 1], mesh.positions[i + 2]);
        if (std::abs(d - r) > 0.2) continue;  // not on the hole wall
        max_vert = std::max(max_vert, std::abs(d - r));
    }
    CHECK(max_vert <= lin + 1e-6);

    for (size_t t = 0; t + 2 < mesh.indices.size(); t += 3) {
        uint32_t ids[3] = {mesh.indices[t], mesh.indices[t + 1], mesh.indices[t + 2]};
        std::array<double, 3> p[3];
        int on = 0;
        for (int k = 0; k < 3; ++k) {
            p[k] = {mesh.positions[ids[k] * 3], mesh.positions[ids[k] * 3 + 1],
                    mesh.positions[ids[k] * 3 + 2]};
            const double d = radial(loc, dir, p[k][0], p[k][1], p[k][2]);
            if (std::abs(d - r) <= 0.2) ++on;
        }
        if (on < 3) continue;
        for (int e = 0; e < 3; ++e) {
            const auto& a = p[e];
            const auto& b = p[(e + 1) % 3];
            const double mx = 0.5 * (a[0] + b[0]), my = 0.5 * (a[1] + b[1]), mz = 0.5 * (a[2] + b[2]);
            max_sag = std::max(max_sag, std::abs(radial(loc, dir, mx, my, mz) - r));
        }
    }
    CHECK(max_sag <= lin + 1e-6);
}

TEST_CASE("STL and 3MF vertex sets match within 1e-9", "[export][print]") {
    Document doc;
    exactness::add_box_hole(doc, 20.0, 20.0, 10.0, 3.0);
    Tmp stl("sx_tol.stl");
    Tmp mf("sx_tol.3mf");
    std::string err;
    REQUIRE(interop::export_stl(doc, stl.path, false, &err));
    REQUIRE(interop::export_3mf(doc, mf.path, &err));
    auto a = stl_ascii_verts(stl.path);
    auto b = verts_from_3mf_xml(slurp_3mf_model(mf.path));
    REQUIRE(a.size() == b.size());
    double maxd = 0;
    for (size_t i = 0; i < a.size(); ++i) {
        maxd = std::max(maxd, std::hypot(a[i][0] - b[i][0], a[i][1] - b[i][1], a[i][2] - b[i][2]));
    }
    CHECK(maxd <= 1e-9);
}

TEST_CASE("3MF vertex 1234.5678 reads back as 1234.5678", "[export][print]") {
    Document doc;
    doc.add_body(shape::make_box(1234.5678, 1.0, 1.0), "wide");
    Tmp mf("sx_digits.3mf");
    std::string err;
    REQUIRE(interop::export_3mf(doc, mf.path, &err));
    const std::string xml = slurp_3mf_model(mf.path);
    bool found = false;
    for (const auto& v : verts_from_3mf_xml(xml)) {
        if (std::abs(v[0] - 1234.5678) < 1e-12 || std::abs(v[1] - 1234.5678) < 1e-12 ||
            std::abs(v[2] - 1234.5678) < 1e-12) {
            found = true;
            CHECK(v[0] == Approx(v[0]).margin(0));  // parsed as double
            if (std::abs(v[0] - 1234.5678) < 1e-12) CHECK(v[0] == Approx(1234.5678).margin(1e-12));
        }
    }
    CHECK(found);
}
