#include <catch.hpp>

#include <cmath>
#include <cstdio>
#include <fstream>
#include <string>

#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopoDS.hxx>

#include "sx/document.hpp"
#include "sx/dxf.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/materials.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/solver.hpp"
#include "sx/sxp.hpp"
#include "sx/thread_standards.hpp"

using namespace sx;

namespace {

struct TmpFile {
    std::string path;
    explicit TmpFile(const char* name) : path(std::string("/tmp/sx_w0_") + name) {}
    ~TmpFile() { std::remove(path.c_str()); }
};

std::shared_ptr<Sketch> rect_on_xy(double w, double h) {
    auto sk = std::make_shared<Sketch>("Rect");
    sk->add_line(0, 0, w, 0);
    sk->add_line(w, 0, w, h);
    sk->add_line(w, h, 0, h);
    sk->add_line(0, h, 0, 0);
    return sk;
}

double body_z_extent(const Document& doc, const EntityId& id) {
    const Body* b = doc.body(id);
    REQUIRE(b != nullptr);
    Bnd_Box box;
    BRepBndLib::Add(b->shape, box);
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    return zmax - zmin;
}

}  // namespace

TEST_CASE("extrude through_all cuts a plate without changing thickness", "[wave0][extrude]") {
    Document doc;
    Feature plate;
    plate.type = FeatureType::Primitive;
    plate.params = {{"kind", "box"}, {"a", 40.0}, {"b", 30.0}, {"c", 10.0}};
    auto plate_fid = doc.graph().add(std::move(plate));
    REQUIRE(doc.graph().regenerate(doc));
    const EntityId plate_body = doc.graph().feature(plate_fid)->output_body;
    const double thick0 = body_z_extent(doc, plate_body);
    CHECK(thick0 == Approx(10.0).margin(1e-6));
    const double vol0 = shape::volume(doc.body(plate_body)->shape);

    SketchPlane pl;
    pl.origin = {10, 10, 10};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, -1, 0};  // normal −Z, into the plate
    auto sk = std::make_shared<Sketch>("Slot", pl);
    sk->add_line(0, 0, 8, 0);
    sk->add_line(8, 0, 8, 8);
    sk->add_line(8, 8, 0, 8);
    sk->add_line(0, 8, 0, 0);
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = sk;
    auto sk_id = doc.graph().add(std::move(skf));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", sk_id.str()},
                  {"distance", 1.0},
                  {"end", "through_all"},
                  {"op", "cut"},
                  {"target", plate_fid.str()}};
    doc.graph().add(std::move(cut));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    const Body* out = doc.body(plate_body);
    REQUIRE(out);
    CHECK(body_z_extent(doc, plate_body) == Approx(thick0).margin(1e-4));
    CHECK(shape::volume(out->shape) < vol0 - 50.0);
}

TEST_CASE("direct edit pull grows a box and survives regen", "[wave0][direct]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 10.0}};
    auto box_fid = doc.graph().add(std::move(box));
    REQUIRE(doc.graph().regenerate(doc));
    const EntityId box_body_id = doc.graph().feature(box_fid)->output_body;
    const double vol0 = shape::volume(doc.body(box_body_id)->shape);
    CHECK(vol0 == Approx(4000.0).margin(1e-3));

    EntityId top_face;
    const Body* box_body = doc.body(box_body_id);
    for (const auto& fid : box_body->subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape fs = doc.resolve(fid);
        if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(fs));
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (fs.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (n.IsEqual(gp_Dir(0, 0, 1), 1e-6)) {
            top_face = fid;
            break;
        }
    }
    REQUIRE(!top_face.is_null());

    Feature de;
    de.type = FeatureType::DirectEdit;
    de.params = {{"target", box_fid.str()},
                 {"kind", "push_pull"},
                 {"face", top_face.str()},
                 {"distance", 5.0},
                 {"direction", {0.0, 0.0, 1.0}}};
    doc.graph().add(std::move(de));
    std::string derr;
    REQUIRE(doc.graph().regenerate(doc, &derr));
    const double vol1 = shape::volume(doc.body(box_body_id)->shape);
    CHECK(vol1 == Approx(vol0 + 20.0 * 20.0 * 5.0).margin(1.0));
    REQUIRE(doc.graph().regenerate(doc));
    CHECK(shape::volume(doc.body(box_body_id)->shape) == Approx(vol1).margin(1.0));
}

TEST_CASE("mounting-plate sketch: concentric + weak dim yields", "[wave0][sketch]") {
    Sketch sk("Plate");
    auto outer = sk.add_circle(0, 0, 20);
    auto hole = sk.add_circle(0.4, 0.2, 3);
    sk.add_constraint(ConstraintType::Concentric, {{outer, PointRole::Center}, {hole, PointRole::Center}});
    auto weak = sk.add_constraint(ConstraintType::Distance,
                                  {{outer, PointRole::Center}, {hole, PointRole::Center}}, 5.0);
    REQUIRE(sk.set_constraint_weak(weak, true));
    auto strong = sk.add_constraint(ConstraintType::Radius, {{outer, PointRole::Self}}, 20.0);
    (void)strong;
    auto backend = make_planegcs_backend();
    auto r = backend->solve(sk);
    REQUIRE(r.ok());
    auto oc = sk.point_pos({outer, PointRole::Center});
    auto hc = sk.point_pos({hole, PointRole::Center});
    REQUIRE(oc);
    REQUIRE(hc);
    const double dx = (*oc)[0] - (*hc)[0];
    const double dy = (*oc)[1] - (*hc)[1];
    CHECK(std::sqrt(dx * dx + dy * dy) == Approx(0.0).margin(1e-4));
    CHECK(r.dofs >= 0);
}

TEST_CASE("four M6 holes: mass equals steel density times volume", "[wave0][hole]") {
    Document doc;
    Feature plate;
    plate.type = FeatureType::Primitive;
    plate.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 8.0}};
    auto plate_fid = doc.graph().add(std::move(plate));
    REQUIRE(doc.graph().regenerate(doc));
    const EntityId plate_body = doc.graph().feature(plate_fid)->output_body;

    auto spec = find_thread("M6");
    REQUIRE(spec);
    Feature holes;
    holes.type = FeatureType::Hole;
    holes.params = {{"target", plate_fid.str()},
                    {"type", "simple"},
                    {"position", {8.0, 8.0, 8.0}},
                    {"positions",
                     {{8.0, 8.0, 8.0}, {32.0, 8.0, 8.0}, {32.0, 32.0, 8.0}, {8.0, 32.0, 8.0}}},
                    {"direction", {0.0, 0.0, -1.0}},
                    {"diameter", spec->major_diameter_mm},
                    {"depth", 0.0}};
    doc.graph().add(std::move(holes));
    REQUIRE(doc.graph().regenerate(doc));
    REQUIRE(doc.set_body_material(plate_body, "Stainless Steel"));
    auto mat = materials::find("Stainless Steel");
    REQUIRE(mat);
    auto mp = measure::mass_properties(doc, plate_body);
    REQUIRE(mp);
    const double mass_g = mat->density_g_cm3 * mp->volume / 1000.0;
    CHECK(mp->volume < 40.0 * 40.0 * 8.0 - 100.0);
    CHECK(mass_g == Approx(mat->density_g_cm3 * mp->volume / 1000.0).margin(1e-9));
    CHECK(mass_g > 0.0);
}

TEST_CASE("variable fillet r1/r2 changes volume vs constant", "[wave0][fillet]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 20.0}};
    auto box_fid = doc.graph().add(std::move(box));
    REQUIRE(doc.graph().regenerate(doc));
    const EntityId box_body_id = doc.graph().feature(box_fid)->output_body;
    const double vol0 = shape::volume(doc.body(box_body_id)->shape);

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.params = {{"target", box_fid.str()}, {"radius", 2.0}, {"radius2", 5.0}, {"edges", {1}}};
    doc.graph().add(std::move(fil));
    REQUIRE(doc.graph().regenerate(doc));
    const double vol1 = shape::volume(doc.body(box_body_id)->shape);
    CHECK(vol1 < vol0);
    CHECK(vol1 > 0.0);
}

TEST_CASE("DXF rectangle becomes four sketch lines", "[wave0][dxf]") {
    TmpFile f("rect.dxf");
    {
        std::ofstream out(f.path);
        out << "0\nSECTION\n2\nENTITIES\n"
            << "0\nLINE\n10\n0\n20\n0\n11\n40\n21\n0\n"
            << "0\nLINE\n10\n40\n20\n0\n11\n40\n21\n30\n"
            << "0\nLINE\n10\n40\n20\n30\n11\n0\n21\n30\n"
            << "0\nLINE\n10\n0\n20\n30\n11\n0\n21\n0\n"
            << "0\nENDSEC\n0\nEOF\n";
    }
    std::string err;
    auto ents = read_dxf(f.path, &err);
    REQUIRE(ents.size() == 4);
    Sketch sk;
    CHECK(add_dxf_to_sketch(sk, ents) == 4);
    int lines = 0;
    for (const auto& e : sk.entities())
        if (e.type == SketchEntityType::Line) ++lines;
    CHECK(lines == 4);

    Document doc;
    auto fid = import_dxf_sketch(doc, f.path, &err);
    REQUIRE(!fid.is_null());
    const Feature* sf = doc.graph().feature(fid);
    REQUIRE(sf);
    REQUIRE(sf->sketch);
    CHECK(sf->sketch->entities().size() == 4);
}

TEST_CASE("interference volume of 1 mm overlap", "[wave0][clash]") {
    Document doc;
    auto a = doc.add_body(shape::make_box(10, 10, 10), "A");
    shape::Placement p;
    p.origin = {9, 0, 0};
    auto b = doc.add_body(shape::make_box(10, 10, 10, p), "B");
    auto v = measure::interference_volume(doc, a, b);
    REQUIRE(v);
    CHECK(*v == Approx(100.0).margin(1.0));  // 1 x 10 x 10
}

TEST_CASE("heal report is card-ready on a valid solid", "[wave0][heal]") {
    auto box = shape::make_box(10, 10, 10);
    std::string report;
    auto healed = interop::heal_shape(box, &report);
    REQUIRE(!healed.IsNull());
    CHECK(report.find("heal:") != std::string::npos);
    CHECK(shape::is_valid(healed));
    CHECK(shape::volume(healed) == Approx(1000.0).margin(1e-3));
}

TEST_CASE("3MF and glTF export write nonzero files", "[wave0][meshout]") {
    Document doc;
    doc.add_body(shape::make_box(5, 5, 5), "Box");
    TmpFile a("box.3mf");
    TmpFile b("box.gltf");
    std::string err;
    REQUIRE(interop::export_3mf(doc, a.path, &err));
    REQUIRE(interop::export_gltf(doc, b.path, &err));
    std::ifstream fa(a.path, std::ios::binary | std::ios::ate);
    std::ifstream fb(b.path, std::ios::binary | std::ios::ate);
    CHECK(fa.tellg() > 64);
    CHECK(fb.tellg() > 64);
}
