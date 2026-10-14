// Rung 3 WP6 — whole Lesson-1 part through the feature pipeline.
// Volumes match docs/loop/rung-03-plan.md (0.05 % solids, 0.2 % final).

#include <catch.hpp>

#include <cmath>
#include <string>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_CurveType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
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

gp_Pnt edge_mid(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.CentreOfMass();
}

double edge_len(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.Mass();
}

bool vol_ok(double got, double want, double frac) {
    return std::abs(got - want) <= std::abs(want) * frac;
}

nlohmann::json r5_edges(const Document& doc, const Body& body) {
    nlohmann::json out = nlohmann::json::array();
    int vertical = 0;
    int front_outer = 0;
    int root = 0;
    for (const auto& eid : body.subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape sh = doc.resolve(eid);
        if (sh.IsNull() || sh.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge edge = TopoDS::Edge(sh);
        BRepAdaptor_Curve curve(edge);
        const gp_Pnt mid = edge_mid(edge);
        if (curve.GetType() == GeomAbs_Line) {
            gp_Vec v = curve.Line().Direction();
            if (std::abs(v.Z()) > 0.99 && std::abs(edge_len(edge) - 30.0) < 0.5) {
                if (std::abs(std::abs(mid.X()) - 60.0) < 0.5
                    && std::abs(std::abs(mid.Y()) - 60.0) < 0.5) {
                    out.push_back(eid.str());
                    ++vertical;
                }
            } else if (std::abs(mid.Z() - 30.0) < 0.4 && std::abs(v.Z()) < 0.1) {
                // Outer front edges of the z=30 square (not the root).
                const bool on_x = std::abs(std::abs(mid.X()) - 60.0) < 0.5
                                  && std::abs(mid.Y()) < 55.0;
                const bool on_y = std::abs(std::abs(mid.Y()) - 60.0) < 0.5
                                  && std::abs(mid.X()) < 55.0;
                if (on_x || on_y) {
                    out.push_back(eid.str());
                    ++front_outer;
                }
            }
        } else if (curve.GetType() == GeomAbs_Circle) {
            const gp_Circ circ = curve.Circle();
            if (std::abs(circ.Radius() - 35.0) < 0.3 && std::abs(mid.Z() - 30.0) < 0.5) {
                out.push_back(eid.str());
                ++root;
            }
        }
    }
    REQUIRE(vertical == 4);
    REQUIRE(front_outer == 4);
    REQUIRE(root == 1);
    REQUIRE(out.size() == 9);
    return out;
}

nlohmann::json annulus_rims(const Document& doc, const Body& body) {
    nlohmann::json out = nlohmann::json::array();
    for (const auto& eid : body.subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape sh = doc.resolve(eid);
        if (sh.IsNull() || sh.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge edge = TopoDS::Edge(sh);
        BRepAdaptor_Curve curve(edge);
        if (curve.GetType() != GeomAbs_Circle) continue;
        const gp_Pnt mid = edge_mid(edge);
        if (std::abs(mid.Z() - 55.0) > 0.5) continue;
        const double r = curve.Circle().Radius();
        if (std::abs(r - 35.0) < 0.3 || std::abs(r - 30.0) < 0.3)
            out.push_back(eid.str());
    }
    REQUIRE(out.size() == 2);
    return out;
}

std::string back_face_id(const Document& doc, const Body& body) {
    for (const auto& fid : body.subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape fs = doc.resolve(fid);
        if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(fs);
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (n.Z() > -0.99) continue;
        GProp_GProps props;
        BRepGProp::SurfaceProperties(face, props);
        if (std::abs(props.CentreOfMass().Z()) < 0.5) return fid.str();
    }
    return "";
}

}  // namespace

TEST_CASE("rung03 part volumes through the feature pipeline", "[rung03][features]") {
    Document doc;
    FeatureGraph graph;

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

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b0 = doc.body(graph.feature(base_id)->output_body);
    REQUIRE(b0 != nullptr);
    REQUIRE(vol_ok(shape::volume(b0->shape), 432000.0, 0.0005));

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
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b1 = doc.body(graph.feature(base_id)->output_body);
    REQUIRE(vol_ok(shape::volume(b1->shape), 528211.3, 0.0005));

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
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b2 = doc.body(graph.feature(base_id)->output_body);
    REQUIRE(vol_ok(shape::volume(b2->shape), 372702.4, 0.0005));

    Feature r5;
    r5.type = FeatureType::Fillet;
    r5.params = {{"target", base_id.str()},
                 {"radius", 5.0},
                 {"edges", r5_edges(doc, *b2)}};
    graph.add(std::move(r5));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b3 = doc.body(graph.feature(base_id)->output_body);
    REQUIRE(shape::is_valid(b3->shape));
    REQUIRE(vol_ok(shape::volume(b3->shape), 370784.6, 0.0005));

    Feature r15;
    r15.type = FeatureType::Fillet;
    r15.params = {{"target", base_id.str()},
                  {"radius", 1.5},
                  {"edges", annulus_rims(doc, *b3)}};
    graph.add(std::move(r15));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b4 = doc.body(graph.feature(base_id)->output_body);
    REQUIRE(shape::is_valid(b4->shape));
    REQUIRE(vol_ok(shape::volume(b4->shape), 370587.4, 0.0005));

    const std::string back = back_face_id(doc, *b4);
    REQUIRE_FALSE(back.empty());
    Feature sh;
    sh.type = FeatureType::Shell;
    sh.params = {{"target", base_id.str()},
                 {"faces", nlohmann::json::array({back})},
                 {"thickness", 1.0}};
    graph.add(std::move(sh));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b5 = doc.body(graph.feature(base_id)->output_body);
    REQUIRE(shape::is_valid(b5->shape));
    int solids = 0;
    for (TopExp_Explorer ex(b5->shape, TopAbs_SOLID); ex.More(); ex.Next()) ++solids;
    REQUIRE(solids == 1);
    REQUIRE(vol_ok(shape::volume(b5->shape), 39311.0, 0.002));
}
