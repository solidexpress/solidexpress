#include <catch.hpp>

#include <cmath>

#include <BRepAdaptor_Surface.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

namespace {

const double kPi = 3.14159265358979323846;

std::shared_ptr<Sketch> centred_rect() {
    auto sk = std::make_shared<Sketch>("base");
    sk->add_line(-60, -60, 60, -60);
    sk->add_line(60, -60, 60, 60);
    sk->add_line(60, 60, -60, 60);
    sk->add_line(-60, 60, -60, -60);
    return sk;
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

// Base 120×120×30, Ø70 boss, Ø60 through cut. The front, back, and boss-top
// faces are annuli: a UV-box centre falls in the hole.
void build_cut_part(Document& doc, FeatureGraph& graph) {
    Feature base_sk;
    base_sk.type = FeatureType::Sketch;
    base_sk.sketch = centred_rect();
    const auto base_sk_id = graph.add(std::move(base_sk));

    Feature base;
    base.type = FeatureType::Extrude;
    base.params = {{"sketch", base_sk_id.str()},
                   {"distance", 30.0},
                   {"op", "new"},
                   {"end", "blind"}};
    const auto base_id = graph.add(std::move(base));

    Feature boss_sk;
    boss_sk.type = FeatureType::Sketch;
    boss_sk.sketch = circle_on(30.0, 35.0);
    const auto boss_sk_id = graph.add(std::move(boss_sk));

    Feature boss;
    boss.type = FeatureType::Extrude;
    boss.params = {{"sketch", boss_sk_id.str()},
                   {"distance", 25.0},
                   {"op", "fuse"},
                   {"end", "blind"},
                   {"target", base_id.str()}};
    graph.add(std::move(boss));

    Feature cut_sk;
    cut_sk.type = FeatureType::Sketch;
    cut_sk.sketch = circle_on(55.0, 30.0);
    const auto cut_sk_id = graph.add(std::move(cut_sk));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", cut_sk_id.str()},
                  {"distance", -1.0},
                  {"op", "cut"},
                  {"end", "through_all"},
                  {"target", base_id.str()}};
    graph.add(std::move(cut));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* body = doc.body(graph.feature(base_id)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::volume(body->shape) == Approx(372702.4).margin(1.0));
}

bool area_near(double got, double want) {
    return std::abs(got - want) <= std::max(1.0, std::abs(want) * 0.01);
}

}  // namespace

TEST_CASE("face_pick_point lies on every planar face of the Ø60-cut part",
          "[measure][rung03]") {
    Document doc;
    FeatureGraph graph;
    build_cut_part(doc, graph);
    const Body* body = nullptr;
    for (const auto& id : doc.body_ids()) {
        body = doc.body(id);
        if (body != nullptr) break;
    }
    REQUIRE(body != nullptr);

    const double front_area = 120.0 * 120.0 - kPi * 35.0 * 35.0;
    const double top_area = kPi * (35.0 * 35.0 - 30.0 * 30.0);
    const double back_area = 120.0 * 120.0 - kPi * 30.0 * 30.0;
    bool saw_front = false;
    bool saw_top = false;
    bool saw_back = false;
    int planar = 0;

    for (const auto& fid : body->subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape shape = doc.resolve(fid);
        if (shape.IsNull() || shape.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(shape);
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        ++planar;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        GProp_GProps props;
        BRepGProp::SurfaceProperties(face, props);
        const double z = surf.Plane().Location().Z();
        const double area = props.Mass();
        INFO("planar z=" << z << " n=(" << n.X() << "," << n.Y() << "," << n.Z()
                         << ") area=" << area);

        const auto pick = measure::face_pick_point(doc, fid);
        REQUIRE(pick.has_value());
        BRepClass_FaceClassifier cls(face, gp_Pnt((*pick)[0], (*pick)[1], (*pick)[2]), 1e-5);
        REQUIRE(cls.State() == TopAbs_IN);

        if (n.Z() > 0.99 && std::abs(z - 30.0) < 0.2 && area_near(area, front_area))
            saw_front = true;
        if (n.Z() > 0.99 && std::abs(z - 55.0) < 0.2 && area_near(area, top_area))
            saw_top = true;
        if (n.Z() < -0.99 && std::abs(z) < 0.2 && area_near(area, back_area))
            saw_back = true;
    }
    REQUIRE(planar >= 3);
    CHECK(saw_front);
    CHECK(saw_top);
    CHECK(saw_back);
}
