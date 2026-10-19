// Rung 7 WP8 — Feature Mirror replays Fillet (not Skip) onto mirrored edges.

#include <catch.hpp>

#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <string>
#include <vector>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

bool point_inside(const TopoDS_Shape& shape, const gp_Pnt& p) {
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) {
        BRepClass3d_SolidClassifier cl(ex.Current());
        cl.Perform(p, 1e-6);
        if (cl.State() == TopAbs_IN) return true;
    }
    return false;
}

gp_Pnt edge_midpoint(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.CentreOfMass();
}

double edge_length(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.Mass();
}

json z_edges_near(const Document& doc, const Body& body, const std::vector<gp_Pnt>& at,
                  double want_len, double tol = 1.5) {
    json out = json::array();
    for (const auto& eid : body.subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge e = TopoDS::Edge(s);
        if (std::abs(edge_length(e) - want_len) > 0.6) continue;
        const gp_Pnt m = edge_midpoint(e);
        for (const auto& p : at) {
            if (std::hypot(m.X() - p.X(), m.Y() - p.Y()) <= tol &&
                std::abs(m.Z() - p.Z()) <= tol) {
                out.push_back(eid.str());
                break;
            }
        }
    }
    return out;
}

bool warning_mentions(const FeatureGraph& graph, const char* needle) {
    for (const auto& w : graph.warnings()) {
        if (w.second.find(needle) != std::string::npos) return true;
    }
    return false;
}

}  // namespace

TEST_CASE("rung07 feature-mirror replays a box fillet", "[rung07][mirror]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("box");
    skf.sketch->add_line(0, 0, 40, 0);
    skf.sketch->add_line(40, 0, 40, 40);
    skf.sketch->add_line(40, 40, 0, 40);
    skf.sketch->add_line(0, 40, 0, 0);
    const auto sk_id = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    const auto ext_id = graph.add(std::move(ext));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* box = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(box != nullptr);
    const double vol0 = shape::volume(box->shape);
    REQUIRE(vol0 == Approx(16000.0).margin(1.0));

    json one = json::array();
    for (const auto& eid : box->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        const gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
        if (std::abs(m.X()) < 0.6 && std::abs(m.Z() - 10.0) < 0.6 &&
            std::abs(m.Y() - 20.0) < 1.0) {
            one.push_back(eid.str());
        }
    }
    REQUIRE(one.size() == 1);

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.name = "fillet 1";
    fil.params = {{"target", ext_id.str()}, {"radius", 2.0}, {"edges", one}};
    const auto fil_id = graph.add(std::move(fil));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    INFO(graph.feature(fil_id)->params.dump());
    REQUIRE(graph.feature(fil_id)->params.contains("edge_cues"));
    const double vol1 = shape::volume(doc.body(graph.feature(ext_id)->output_body)->shape);
    REQUIRE(vol1 < vol0 - 1.0);

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.name = "mirror";
    mir.params = {{"source_feature_ids", json::array({fil_id.str()})},
                  {"plane_point", json::array({20.0, 0.0, 0.0})},
                  {"plane_normal", json::array({1.0, 0.0, 0.0})},
                  {"target", ext_id.str()}};
    graph.add(std::move(mir));
    const bool ok = graph.regenerate(doc, &err);
    INFO(err);
    INFO(graph.last_error());
    REQUIRE(ok);

    REQUIRE(doc.body_ids().size() == 1);
    const Body* after = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(after != nullptr);
    const double drop = vol0 - vol1;
    REQUIRE(shape::volume(after->shape) == Approx(vol0 - 2.0 * drop).margin(2.0));
    CHECK_FALSE(warning_mentions(graph, "skipped fillet"));
}

TEST_CASE("rung07 feature-mirror Cut+Fillet about Z=0 rounds both pockets",
          "[rung07][mirror]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("plate");
    skf.sketch->add_line(0, -20, 80, -20);
    skf.sketch->add_line(80, -20, 80, 20);
    skf.sketch->add_line(80, 20, 0, 20);
    skf.sketch->add_line(0, 20, 0, -20);
    const auto sk_id = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 20.0}, {"op", "new"}, {"end", "blind"}};
    const auto ext_id = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);

    Feature psk;
    psk.type = FeatureType::Sketch;
    psk.sketch = std::make_shared<Sketch>("pocket");
    SketchPlane pl;
    pl.origin = {0, 0, 20};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    psk.sketch->set_plane(pl);
    psk.sketch->add_line(20, -8, 60, -8);
    psk.sketch->add_line(60, -8, 60, 8);
    psk.sketch->add_line(60, 8, 20, 8);
    psk.sketch->add_line(20, 8, 20, -8);
    const auto psk_id = graph.add(std::move(psk));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.name = "cut";
    cut.params = {{"sketch", psk_id.str()},
                  {"distance", -8.0},
                  {"op", "cut"},
                  {"end", "blind"},
                  {"target", ext_id.str()}};
    const auto cut_id = graph.add(std::move(cut));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    INFO(graph.last_error());

    const Body* plate = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(plate != nullptr);
    CHECK_FALSE(point_inside(plate->shape, gp_Pnt(40, 0, 16)));
    CHECK(point_inside(plate->shape, gp_Pnt(40, 0, 4)));

    const json corners = z_edges_near(doc, *plate,
            {gp_Pnt(20, 8, 16), gp_Pnt(60, 8, 16), gp_Pnt(20, -8, 16), gp_Pnt(60, -8, 16)},
            8.0);
    INFO(corners.dump());
    REQUIRE(corners.size() >= 4);

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.name = "fillet 3";
    fil.params = {{"target", ext_id.str()}, {"radius", 3.0}, {"edges", corners}};
    const auto fil_id = graph.add(std::move(fil));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    INFO(graph.feature(fil_id)->params.dump());
    const double vol_one = shape::volume(doc.body(graph.feature(ext_id)->output_body)->shape);
    CHECK(point_inside(doc.body(graph.feature(ext_id)->output_body)->shape,
                       gp_Pnt(20.5, 7.5, 16)));

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.name = "mirror";
    mir.params = {{"source_feature_ids", json::array({cut_id.str(), fil_id.str()})},
                  {"plane_point", json::array({0.0, 0.0, 10.0})},
                  {"plane_normal", json::array({0.0, 0.0, 1.0})},
                  {"target", ext_id.str()}};
    graph.add(std::move(mir));
    const bool ok = graph.regenerate(doc, &err);
    INFO(err);
    INFO(graph.last_error());
    REQUIRE(ok);

    REQUIRE(doc.body_ids().size() == 1);
    const Body* both = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(both != nullptr);
    CHECK_FALSE(point_inside(both->shape, gp_Pnt(40, 0, 16)));
    CHECK_FALSE(point_inside(both->shape, gp_Pnt(40, 0, 4)));
    CHECK(point_inside(both->shape, gp_Pnt(20.5, 7.5, 16)));
    CHECK(point_inside(both->shape, gp_Pnt(20.5, 7.5, 4)));
    const double vol_both = shape::volume(both->shape);
    const double plate_vol = 80.0 * 40.0 * 20.0;
    const double pocket = 40.0 * 16.0 * 8.0;
    REQUIRE(vol_both < vol_one - 0.5 * pocket);
    REQUIRE(vol_both == Approx(plate_vol - 2.0 * pocket + 2.0 * (vol_one - (plate_vol - pocket)))
                            .margin(20.0));
    CHECK_FALSE(warning_mentions(graph, "skipped fillet"));
}

TEST_CASE("rung07 feature-mirror replays a box chamfer", "[rung07][mirror][chamfer]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("box");
    skf.sketch->add_line(0, 0, 40, 0);
    skf.sketch->add_line(40, 0, 40, 40);
    skf.sketch->add_line(40, 40, 0, 40);
    skf.sketch->add_line(0, 40, 0, 0);
    const auto sk_id = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    const auto ext_id = graph.add(std::move(ext));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* box = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(box != nullptr);
    const double vol0 = shape::volume(box->shape);

    json one = json::array();
    for (const auto& eid : box->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        const gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
        if (std::abs(m.X()) < 0.6 && std::abs(m.Z() - 10.0) < 0.6 &&
            std::abs(m.Y() - 20.0) < 1.0) {
            one.push_back(eid.str());
        }
    }
    REQUIRE(one.size() == 1);

    Feature ch;
    ch.type = FeatureType::Chamfer;
    ch.name = "chamfer 1";
    ch.params = {{"target", ext_id.str()}, {"distance", 2.0}, {"edges", one}};
    const auto ch_id = graph.add(std::move(ch));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    REQUIRE((graph.feature(ch_id)->params.contains("edge_cues") ||
             graph.feature(ch_id)->params.contains("face_cues")));
    const double vol1 = shape::volume(doc.body(graph.feature(ext_id)->output_body)->shape);
    REQUIRE(vol1 < vol0 - 0.5);

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.name = "mirror";
    mir.params = {{"source_feature_ids", json::array({ch_id.str()})},
                  {"plane_point", json::array({20.0, 0.0, 0.0})},
                  {"plane_normal", json::array({1.0, 0.0, 0.0})},
                  {"target", ext_id.str()}};
    graph.add(std::move(mir));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* after = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(after != nullptr);
    const double drop = vol0 - vol1;
    REQUIRE(shape::volume(after->shape) == Approx(vol0 - 2.0 * drop).margin(2.0));
    CHECK_FALSE(warning_mentions(graph, "skipped chamfer"));
}
