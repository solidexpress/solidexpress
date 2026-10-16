// Rung 5 WP4 — feature-mirror the four PDF features about z = 0.
// One body, −Z half solid; Shell in the list is a skip, not a fail.
// WP6 continues: re-shell the −Z half; +Z walls stay 10.

#include <catch.hpp>

#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

#include <BRepAdaptor_Surface.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepIntCurveSurface_Inter.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

const double kPi = 3.14159265358979323846;
const double kMirrorVol = 6034606.788;
const double kShelled = 1099557.429;
const double kReshell = 2716299.548;

bool point_inside(const TopoDS_Shape& shape, const gp_Pnt& p) {
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) {
        BRepClass3d_SolidClassifier cl(ex.Current());
        cl.Perform(p, 1e-6);
        if (cl.State() == TopAbs_IN) return true;
    }
    return false;
}

int solid_count(const TopoDS_Shape& shape) {
    int n = 0;
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) ++n;
    return n;
}

std::shared_ptr<Sketch> circle_on(double z, double r) {
    SketchPlane pl;
    pl.origin = {0, 0, z};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    auto sk = std::make_shared<Sketch>("circle", pl);
    sk->add_circle(0, 0, r);
    return sk;
}

std::shared_ptr<Sketch> flange_cut_sketch() {
    SketchPlane pl;
    pl.origin = {0, 0, 260.0};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    auto sk = std::make_shared<Sketch>("cut", pl);
    sk->add_circle(0, 0, 65.0);
    for (int k = 0; k < 8; ++k) {
        const double ang = static_cast<double>(k) * kPi / 4.0;
        sk->add_circle(94.0 * std::sin(ang), 94.0 * std::cos(ang), 5.0);
    }
    return sk;
}

std::vector<double> ray_hits(const TopoDS_Shape& shape, const gp_Pnt& origin, const gp_Dir& dir) {
    BRepIntCurveSurface_Inter inter;
    inter.Init(shape, gp_Lin(origin, dir), 1e-6);
    std::vector<double> ts;
    for (; inter.More(); inter.Next()) ts.push_back(inter.W());
    std::sort(ts.begin(), ts.end());
    std::vector<double> unique;
    for (double t : ts) {
        if (unique.empty() || std::abs(t - unique.back()) > 1e-4) unique.push_back(t);
    }
    return unique;
}

json planar_faces_at_z(const Document& doc, const Body& body, double z, double nz) {
    json out = json::array();
    for (const auto& fid : body.subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape fs = doc.resolve(fid);
        if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(fs);
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (nz != 0.0 && n.Z() * nz < 0.99) continue;
        auto pick = measure::face_pick_point(doc, fid);
        if (!pick) continue;
        const double fz = (*pick)[2];
        if (std::abs(fz - z) > 0.5) continue;
        out.push_back(fid.str());
    }
    return out;
}

std::string dump_planar_z(const Document& doc, const Body& body) {
    std::string s;
    for (const auto& fid : body.subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape fs = doc.resolve(fid);
        if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(fs);
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (std::abs(n.Z()) < 0.99) continue;
        auto pick = measure::face_pick_point(doc, fid);
        const double fz = pick ? (*pick)[2] : 1e9;
        s += " nZ=" + std::to_string(n.Z()) + " z=" + std::to_string(fz);
        if (pick)
            s += " r=" + std::to_string(std::hypot((*pick)[0], (*pick)[1]));
        s += ";";
    }
    return s;
}

json planar_z_faces(const Document& doc, const Body& body) {
    json out = json::array();
    for (const auto& fid : body.subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape fs = doc.resolve(fid);
        if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(fs);
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (std::abs(n.Z()) < 0.99) continue;
        out.push_back(fid.str());
    }
    return out;
}

bool bolt_ring_empty(const TopoDS_Shape& shape, double z) {
    for (int k = 0; k < 8; ++k) {
        const double ang = static_cast<double>(k) * kPi / 4.0;
        if (point_inside(shape, gp_Pnt(94.0 * std::sin(ang), 94.0 * std::cos(ang), z)))
            return false;
    }
    return true;
}

struct PipeCut {
    EntityId ext;
    EntityId shell;
    EntityId flange;
    EntityId cut;
};

// Cylinder → shell both ends → fuse Ø225 × 10 → cut Blind 10 (Ø130 + 8×Ø10).
PipeCut add_cut_pipe(FeatureGraph& graph, Document& doc) {
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.name = "sketch 1";
    skf.sketch = std::make_shared<Sketch>("sketch 1");
    skf.sketch->add_circle(0, 0, 75.0);
    const auto sk_id = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.name = "extrude 1";
    ext.params = {{"sketch", sk_id.str()}, {"distance", 250.0}, {"op", "new"}, {"end", "blind"}};
    PipeCut ids;
    ids.ext = graph.add(std::move(ext));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* cyl = doc.body(graph.feature(ids.ext)->output_body);
    REQUIRE(cyl != nullptr);
    const json ends = planar_z_faces(doc, *cyl);
    REQUIRE(ends.size() == 2);

    Feature sh;
    sh.type = FeatureType::Shell;
    sh.name = "shell";
    sh.params = {{"target", ids.ext.str()}, {"faces", ends}, {"thickness", 10.0}};
    ids.shell = graph.add(std::move(sh));

    Feature fl_sk;
    fl_sk.type = FeatureType::Sketch;
    fl_sk.name = "flange sketch";
    fl_sk.sketch = circle_on(250.0, 112.5);
    const auto fl_sk_id = graph.add(std::move(fl_sk));

    Feature flange;
    flange.type = FeatureType::Extrude;
    flange.name = "flange";
    flange.params = {{"sketch", fl_sk_id.str()},
                     {"distance", 10.0},
                     {"op", "fuse"},
                     {"end", "blind"},
                     {"target", ids.ext.str()}};
    ids.flange = graph.add(std::move(flange));

    Feature cut_sk;
    cut_sk.type = FeatureType::Sketch;
    cut_sk.name = "cut sketch";
    cut_sk.sketch = flange_cut_sketch();
    const auto cut_sk_id = graph.add(std::move(cut_sk));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.name = "cut";
    cut.params = {{"sketch", cut_sk_id.str()},
                  {"distance", -10.0},
                  {"op", "cut"},
                  {"end", "blind"},
                  {"target", ids.ext.str()}};
    ids.cut = graph.add(std::move(cut));

    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    return ids;
}

EntityId add_mirrored_pipe(FeatureGraph& graph, Document& doc) {
    const PipeCut ids = add_cut_pipe(graph, doc);
    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.name = "mirror";
    mir.params = {{"source_feature_ids", json::array({ids.ext.str(), ids.shell.str(), ids.flange.str(),
                                                      ids.cut.str()})},
                  {"plane_point", json::array({0.0, 0.0, 0.0})},
                  {"plane_normal", json::array({0.0, 0.0, 1.0})},
                  {"target", ids.ext.str()}};
    graph.add(std::move(mir));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    return ids.ext;
}

}  // namespace

TEST_CASE("rung05 feature-mirror of four PDF features is one solid half", "[rung05][mirror]") {
    Document doc;
    FeatureGraph graph;
    const PipeCut ids = add_cut_pipe(graph, doc);

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.name = "mirror";
    mir.params = {{"source_feature_ids", json::array({ids.ext.str(), ids.shell.str(), ids.flange.str(),
                                                      ids.cut.str()})},
                  {"plane_point", json::array({0.0, 0.0, 0.0})},
                  {"plane_normal", json::array({0.0, 0.0, 1.0})},
                  {"target", ids.ext.str()}};
    graph.add(std::move(mir));

    std::string err;
    const bool ok = graph.regenerate(doc, &err);
    INFO(err);
    REQUIRE(ok);

    REQUIRE(doc.body_ids().size() == 1);
    const Body* body = doc.body(graph.feature(ids.ext)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::is_valid(body->shape));
    REQUIRE(solid_count(body->shape) == 1);

    auto bb = measure::bounding_box(doc, body->id);
    REQUIRE(bb.has_value());
    CHECK(bb->min[0] == Approx(-112.5).margin(0.2));
    CHECK(bb->min[1] == Approx(-112.5).margin(0.2));
    CHECK(bb->min[2] == Approx(-260.0).margin(0.2));
    CHECK(bb->max[0] == Approx(112.5).margin(0.2));
    CHECK(bb->max[1] == Approx(112.5).margin(0.2));
    CHECK(bb->max[2] == Approx(260.0).margin(0.2));
    CHECK((bb->max[0] - bb->min[0]) == Approx(225.0).margin(0.2));
    CHECK((bb->max[1] - bb->min[1]) == Approx(225.0).margin(0.2));
    CHECK((bb->max[2] - bb->min[2]) == Approx(520.0).margin(0.2));

    REQUIRE(shape::volume(body->shape) == Approx(kMirrorVol).epsilon(0.005));
    CHECK(point_inside(body->shape, gp_Pnt(0, 0, -125)));
    CHECK_FALSE(point_inside(body->shape, gp_Pnt(0, 0, 125)));
    CHECK(bolt_ring_empty(body->shape, 255.0));
    CHECK(bolt_ring_empty(body->shape, -255.0));
}

TEST_CASE("rung05 feature-mirror skips Shell-only as a no-op", "[rung05][mirror]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("sketch 1");
    skf.sketch->add_circle(0, 0, 75.0);
    const auto sk_id = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 250.0}, {"op", "new"}, {"end", "blind"}};
    const auto ext_id = graph.add(std::move(ext));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* cyl = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(cyl != nullptr);
    const json ends = planar_z_faces(doc, *cyl);
    REQUIRE(ends.size() == 2);

    Feature sh;
    sh.type = FeatureType::Shell;
    sh.params = {{"target", ext_id.str()}, {"faces", ends}, {"thickness", 10.0}};
    const auto sh_id = graph.add(std::move(sh));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* shelled = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(shelled != nullptr);
    const double vol0 = shape::volume(shelled->shape);
    REQUIRE(vol0 == Approx(kShelled).epsilon(0.005));

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.params = {{"source_feature_ids", json::array({sh_id.str()})},
                  {"plane_point", json::array({0.0, 0.0, 0.0})},
                  {"plane_normal", json::array({0.0, 0.0, 1.0})},
                  {"target", ext_id.str()}};
    graph.add(std::move(mir));
    const bool ok = graph.regenerate(doc, &err);
    INFO(err);
    REQUIRE(ok);

    REQUIRE(doc.body_ids().size() == 1);
    const Body* after = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(after != nullptr);
    REQUIRE(shape::volume(after->shape) == Approx(vol0).epsilon(1e-6));
    CHECK_FALSE(point_inside(after->shape, gp_Pnt(0, 0, 125)));
    REQUIRE_FALSE(graph.warnings().empty());
    CHECK(graph.warnings().front().second.find("skipped shell") != std::string::npos);
}

TEST_CASE("rung05 re-shell of mirrored half keeps +Z walls 10", "[rung05][reshell]") {
    Document doc;
    FeatureGraph graph;
    const EntityId ext_id = add_mirrored_pipe(graph, doc);
    const Body* mirrored = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(mirrored != nullptr);
    REQUIRE(point_inside(mirrored->shape, gp_Pnt(0, 0, -125)));

    INFO(dump_planar_z(doc, *mirrored));
    json remove = planar_faces_at_z(doc, *mirrored, -260.0, 0.0);
    REQUIRE_FALSE(remove.empty());
    const json plug_neg = planar_faces_at_z(doc, *mirrored, 0.0, -1.0);
    const json plug_pos = planar_faces_at_z(doc, *mirrored, 0.0, 1.0);
    for (const auto& id : plug_neg) remove.push_back(id);
    for (const auto& id : plug_pos) remove.push_back(id);

    Feature sh;
    sh.type = FeatureType::Shell;
    sh.name = "reshell";
    sh.params = {{"target", ext_id.str()}, {"faces", remove}, {"thickness", 10.0}};
    graph.add(std::move(sh));
    std::string err;
    const bool ok = graph.regenerate(doc, &err);
    INFO(err);
    REQUIRE(ok);

    REQUIRE(doc.body_ids().size() == 1);
    const Body* body = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::is_valid(body->shape));
    REQUIRE(solid_count(body->shape) == 1);
    REQUIRE(shape::volume(body->shape) == Approx(kReshell).epsilon(0.005));
    CHECK_FALSE(point_inside(body->shape, gp_Pnt(0, 0, -125)));
    CHECK_FALSE(point_inside(body->shape, gp_Pnt(0, 0, 125)));
    CHECK(point_inside(body->shape, gp_Pnt(70, 0, 125)));
    CHECK(point_inside(body->shape, gp_Pnt(70, 0, -125)));

    auto hits_at = [&](double z) {
        const auto ts = ray_hits(body->shape, gp_Pnt(-150.0, 0.0, z), gp_Dir(1.0, 0.0, 0.0));
        std::vector<double> xs;
        for (double t : ts) xs.push_back(-150.0 + t);
        return xs;
    };
    const auto pos = hits_at(125.0);
    const auto neg = hits_at(-125.0);
    REQUIRE(pos.size() == 4);
    REQUIRE(neg.size() == 4);
    CHECK(pos[0] == Approx(-75.0).margin(0.2));
    CHECK(pos[1] == Approx(-65.0).margin(0.2));
    CHECK(pos[2] == Approx(65.0).margin(0.2));
    CHECK(pos[3] == Approx(75.0).margin(0.2));
    CHECK(neg[0] == Approx(-75.0).margin(0.2));
    CHECK(neg[1] == Approx(-65.0).margin(0.2));
    CHECK(neg[2] == Approx(65.0).margin(0.2));
    CHECK(neg[3] == Approx(75.0).margin(0.2));
}
