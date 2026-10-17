#include <catch.hpp>

#include <cmath>

#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
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
