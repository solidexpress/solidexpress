#include <catch.hpp>

#include <cmath>

#include <BRepAdaptor_Surface.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

namespace {

const double kPi = 3.14159265358979323846;

bool point_inside(const TopoDS_Shape& shape, const gp_Pnt& p) {
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) {
        BRepClass3d_SolidClassifier cl(ex.Current());
        cl.Perform(p, 1e-6);
        if (cl.State() == TopAbs_IN) return true;
    }
    return false;
}

std::shared_ptr<Sketch> cylinder_profile() {
    SketchPlane pl;
    pl.origin = {0, 180, 0};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 0, -1};
    auto sk = std::make_shared<Sketch>("Cyl", pl);
    sk->add_circle(0.0, 0.0, 30.0);
    return sk;
}

std::shared_ptr<Sketch> hole_profile() {
    SketchPlane pl;
    pl.origin = {0, 220, 0};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 0, -1};
    auto sk = std::make_shared<Sketch>("Hole", pl);
    sk->add_circle(0.0, 0.0, 15.0);
    return sk;
}

EntityId face_near_y(const Document& doc, const EntityId& body, double y_want) {
    EntityId best;
    double best_d = 1e300;
    const Body* b = doc.body(body);
    if (!b) return best;
    auto it = b->subshape_ids.find(EntityKind::Face);
    if (it == b->subshape_ids.end()) return best;
    for (const auto& fid : it->second) {
        TopoDS_Shape s = doc.resolve(fid);
        if (s.IsNull() || s.ShapeType() != TopAbs_FACE) continue;
        GProp_GProps props;
        BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
        if (props.Mass() <= 1e-18) continue;
        const double d = std::abs(props.CentreOfMass().Y() - y_want);
        if (d < best_d) {
            best_d = d;
            best = fid;
        }
    }
    return best;
}

}  // namespace

TEST_CASE("rung06 drafted cut frustum", "[features][rung06][draft]") {
    Document doc;
    FeatureGraph graph;

    Feature cyl_sk;
    cyl_sk.type = FeatureType::Sketch;
    cyl_sk.sketch = cylinder_profile();
    const auto cyl_sk_id = graph.add(std::move(cyl_sk));

    Feature cyl;
    cyl.type = FeatureType::Extrude;
    cyl.params = {{"sketch", cyl_sk_id.str()},
                  {"distance", 40.0},
                  {"op", "new"},
                  {"end", "blind"}};
    const auto cyl_id = graph.add(std::move(cyl));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b0 = doc.body(graph.feature(cyl_id)->output_body);
    REQUIRE(b0 != nullptr);
    const double vol0 = shape::volume(b0->shape);
    REQUIRE(vol0 == Approx(kPi * 30.0 * 30.0 * 40.0).epsilon(0.02));

    Feature hole_sk;
    hole_sk.type = FeatureType::Sketch;
    hole_sk.sketch = hole_profile();
    const auto hole_sk_id = graph.add(std::move(hole_sk));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", hole_sk_id.str()},
                  {"distance", -25.0},
                  {"op", "cut"},
                  {"target", cyl_id.str()},
                  {"end", "blind"},
                  {"draft_deg", 15.0},
                  {"draft_inward", true}};
    graph.add(std::move(cut));
    err.clear();
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b1 = doc.body(graph.feature(cyl_id)->output_body);
    REQUIRE(b1 != nullptr);
    const double drop = vol0 - shape::volume(b1->shape);
    REQUIRE(drop == Approx(10954.475).epsilon(0.02));
    REQUIRE(point_inside(b1->shape, gp_Pnt(13.0, 195.0, 0.0)));
}

TEST_CASE("rung06 face sketch stays on the revolve top", "[features][rung06][draft]") {
    Document doc;
    FeatureGraph graph;

    Feature profile;
    profile.type = FeatureType::Sketch;
    auto sk = std::make_shared<Sketch>("Stem");
    sk->add_line(0, 0, 20, 0);
    sk->add_line(20, 0, 20, 220);
    sk->add_line(20, 220, 0, 220);
    sk->add_line(0, 220, 0, 0);
    profile.sketch = sk;
    const auto profile_id = graph.add(std::move(profile));

    Feature rev;
    rev.type = FeatureType::Revolve;
    rev.params = {{"sketch", profile_id.str()},
                  {"axis_point", {0.0, 0.0}},
                  {"axis_dir", {0.0, 1.0}},
                  {"angle", 6.283185307179586},
                  {"op", "new"}};
    const auto rev_id = graph.add(std::move(rev));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);

    Feature hole_sk;
    hole_sk.type = FeatureType::Sketch;
    hole_sk.sketch = hole_profile();
    hole_sk.params = {{"support_host", rev_id.str()},
                      {"support_normal", {0.0, 1.0, 0.0}},
                      {"support_side", "max"}};
    const auto hole_id = graph.add(std::move(hole_sk));
    err.clear();
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Feature* hf = graph.feature(hole_id);
    REQUIRE(hf != nullptr);
    REQUIRE(hf->sketch != nullptr);
    REQUIRE(hf->sketch->plane().origin[1] == Approx(220.0).margin(0.2));

    const Body* b0 = doc.body(graph.feature(rev_id)->output_body);
    REQUIRE(b0 != nullptr);
    const double vol0 = shape::volume(b0->shape);

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", hole_id.str()},
                  {"distance", -25.0},
                  {"op", "cut"},
                  {"target", rev_id.str()},
                  {"end", "blind"},
                  {"draft_deg", 15.0},
                  {"draft_inward", true}};
    graph.add(std::move(cut));
    err.clear();
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Feature* hf2 = graph.feature(hole_id);
    REQUIRE(hf2 != nullptr);
    REQUIRE(hf2->sketch->plane().origin[1] == Approx(220.0).margin(0.2));
    const Body* b1 = doc.body(graph.feature(rev_id)->output_body);
    REQUIRE(b1 != nullptr);
    REQUIRE(vol0 - shape::volume(b1->shape) == Approx(10954.475).epsilon(0.05));
    REQUIRE(point_inside(b1->shape, gp_Pnt(13.0, 195.0, 0.0)));
}

TEST_CASE("rung06 support side wins over a stale host_face", "[features][rung06][draft]") {
    Document doc;
    FeatureGraph graph;

    Feature profile;
    profile.type = FeatureType::Sketch;
    auto sk = std::make_shared<Sketch>("Stem");
    sk->add_line(0, 0, 20, 0);
    sk->add_line(20, 0, 20, 220);
    sk->add_line(20, 220, 0, 220);
    sk->add_line(0, 220, 0, 0);
    profile.sketch = sk;
    const auto profile_id = graph.add(std::move(profile));

    Feature rev;
    rev.type = FeatureType::Revolve;
    rev.params = {{"sketch", profile_id.str()},
                  {"axis_point", {0.0, 0.0}},
                  {"axis_dir", {0.0, 1.0}},
                  {"angle", 6.283185307179586},
                  {"op", "new"}};
    const auto rev_id = graph.add(std::move(rev));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);

    const EntityId body = graph.feature(rev_id)->output_body;
    const EntityId bottom = face_near_y(doc, body, 0.0);
    REQUIRE_FALSE(bottom.is_null());

    Feature hole_sk;
    hole_sk.type = FeatureType::Sketch;
    hole_sk.sketch = hole_profile();
    hole_sk.params = {{"support_host", rev_id.str()},
                      {"support_normal", {0.0, 1.0, 0.0}},
                      {"support_side", "max"},
                      {"host_face", bottom.str()}};
    const auto hole_id = graph.add(std::move(hole_sk));
    err.clear();
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Feature* hf = graph.feature(hole_id);
    REQUIRE(hf != nullptr);
    REQUIRE(hf->sketch != nullptr);
    REQUIRE(hf->sketch->plane().origin[1] == Approx(220.0).margin(0.2));
}

TEST_CASE("rung06 rebind does not pull a top sketch down to y=0", "[features][rung06][draft]") {
    Document doc;
    FeatureGraph graph;

    Feature profile;
    profile.type = FeatureType::Sketch;
    auto sk = std::make_shared<Sketch>("Stem");
    sk->add_line(0, 0, 20, 0);
    sk->add_line(20, 0, 20, 220);
    sk->add_line(20, 220, 0, 220);
    sk->add_line(0, 220, 0, 0);
    profile.sketch = sk;
    const auto profile_id = graph.add(std::move(profile));

    Feature rev;
    rev.type = FeatureType::Revolve;
    rev.params = {{"sketch", profile_id.str()},
                  {"axis_point", {0.0, 0.0}},
                  {"axis_dir", {0.0, 1.0}},
                  {"angle", 6.283185307179586},
                  {"op", "new"}};
    const auto rev_id = graph.add(std::move(rev));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));

    SketchPlane pl;
    pl.origin = {0, 220, 0};
    pl.x_dir = {-1, 0, 0};
    pl.y_dir = {0, 0, 1};
    Feature hole_sk;
    hole_sk.type = FeatureType::Sketch;
    hole_sk.sketch = std::make_shared<Sketch>("Hole", pl);
    hole_sk.sketch->add_circle(0.0, 0.0, 15.0);
    hole_sk.params = {{"support_host", rev_id.str()},
                      {"support_normal", {0.0, 1.0, 0.0}},
                      {"support_side", "max"}};
    const auto hole_id = graph.add(std::move(hole_sk));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(hole_id)->sketch->plane().origin[1] == Approx(220.0).margin(0.2));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", hole_id.str()},
                  {"distance", -25.0},
                  {"op", "cut"},
                  {"target", rev_id.str()},
                  {"end", "blind"},
                  {"draft_deg", 15.0},
                  {"draft_inward", true}};
    graph.add(std::move(cut));
    err.clear();
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    REQUIRE(graph.feature(hole_id)->sketch->plane().origin[1] == Approx(220.0).margin(0.2));
}

TEST_CASE("rung06 draft 75 refused", "[features][rung06][draft]") {
    Document doc;
    FeatureGraph graph;
    Feature cyl_sk;
    cyl_sk.type = FeatureType::Sketch;
    cyl_sk.sketch = cylinder_profile();
    const auto cyl_sk_id = graph.add(std::move(cyl_sk));
    Feature cyl;
    cyl.type = FeatureType::Extrude;
    cyl.params = {{"sketch", cyl_sk_id.str()},
                  {"distance", 40.0},
                  {"op", "new"},
                  {"end", "blind"}};
    const auto cyl_id = graph.add(std::move(cyl));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));

    Feature hole_sk;
    hole_sk.type = FeatureType::Sketch;
    hole_sk.sketch = hole_profile();
    const auto hole_sk_id = graph.add(std::move(hole_sk));
    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", hole_sk_id.str()},
                  {"distance", -25.0},
                  {"op", "cut"},
                  {"target", cyl_id.str()},
                  {"end", "blind"},
                  {"draft_deg", 75.0},
                  {"draft_inward", true}};
    graph.add(std::move(cut));
    err.clear();
    REQUIRE_FALSE(graph.regenerate(doc, &err));
    REQUIRE(err.find("draft") != std::string::npos);
}
