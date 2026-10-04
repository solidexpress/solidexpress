#include <catch.hpp>

#include "test_temp.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shell.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/query.hpp"
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

EntityId face_at_z(const Document& doc, const EntityId& body, double z_want, double y_abs_max) {
    EntityId best;
    double best_d = 1e300;
    const Body* b = doc.body(body);
    if (!b) return best;
    for (const auto& fid : b->subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape s = doc.resolve(fid);
        if (s.IsNull() || s.ShapeType() != TopAbs_FACE) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(s));
        if (surf.GetType() != GeomAbs_Plane) continue;
        if (std::abs(surf.Plane().Axis().Direction().Z()) < 0.9) continue;
        GProp_GProps props;
        BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
        gp_Pnt c = props.CentreOfMass();
        if (std::abs(c.Y()) > y_abs_max) continue;
        const double d = std::abs(c.Z() - z_want);
        if (d < best_d) {
            best_d = d;
            best = fid;
        }
    }
    return best;
}

void add_rect(Sketch& sk, double x0, double y0, double x1, double y1) {
    sk.add_line(x0, y0, x1, y0);
    sk.add_line(x1, y0, x1, y1);
    sk.add_line(x1, y1, x0, y1);
    sk.add_line(x0, y1, x0, y0);
}

void add_wrench_blank(Sketch& sk, double* x_neck) {
    const double r_head = 22.5;
    const double dx = std::sqrt(r_head * r_head - 10.0 * 10.0);
    const double xhit = 200.0 - dx;
    if (x_neck) *x_neck = xhit;
    const double ang = std::atan2(10.0, -dx);
    sk.add_arc(0, 0, 10.0, M_PI / 2.0, 3.0 * M_PI / 2.0);
    sk.add_line(0, -10, xhit, -10);
    sk.add_arc(200.0, 0, r_head, -ang, ang);
    sk.add_line(xhit, 10, 0, 10);
}

TopoDS_Shape box_missing_one_face() {
    TopoDS_Shape box = shape::make_box(10, 10, 10);
    BRep_Builder builder;
    TopoDS_Shell shell;
    builder.MakeShell(shell);
    bool skipped = false;
    for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next()) {
        if (!skipped) {
            skipped = true;
            continue;
        }
        builder.Add(shell, ex.Current());
    }
    return shell;
}

json outer_top_edges(const Document& doc, const EntityId& body, const EntityId& top) {
    json out = json::array();
    for (const auto& eid : edges_of_face(doc, top)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
        if (std::abs(m.Z() - 10.0) > 0.4) continue;
        if (std::abs(std::abs(m.X()) - 20.0) < 0.6 || std::abs(std::abs(m.Y()) - 15.0) < 0.6)
            out.push_back(eid.str());
    }
    return out;
}

}  // namespace

TEST_CASE("plate slot R1 fillets; R1.5 refuses with 1.25; 3MF closed", "[rung01][replan3][fillet]") {
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Plate");
    add_rect(*skf.sketch, -20, -15, 20, 15);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    auto ext_id = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body = graph.feature(ext_id)->output_body;

    Feature slot_sk;
    slot_sk.type = FeatureType::Sketch;
    SketchPlane slot_plane;
    slot_plane.origin = {0, 0, 10};
    slot_plane.x_dir = {1, 0, 0};
    slot_plane.y_dir = {0, 1, 0};
    slot_sk.sketch = std::make_shared<Sketch>("Slot", slot_plane);
    add_rect(*slot_sk.sketch, -10, -5, 10, 5);
    auto slot_sk_id = graph.add(std::move(slot_sk));
    Feature slot;
    slot.type = FeatureType::Extrude;
    slot.params = {{"sketch", slot_sk_id.str()},
                   {"distance", -2.5},
                   {"end", "blind"},
                   {"op", "cut"},
                   {"target", ext_id.str()}};
    graph.add(std::move(slot));
    REQUIRE(graph.regenerate(doc, &err));

    EntityId floor = face_at_z(doc, body, 7.5, 2.0);
    REQUIRE(!floor.is_null());
    auto floor_edges = edges_of_face(doc, floor);
    REQUIRE(floor_edges.size() >= 4);
    json floor_json = json::array();
    for (const auto& e : floor_edges) floor_json.push_back(e.str());

    const double vol_before = shape::volume(doc.body(body)->shape);
    Feature too_big;
    too_big.type = FeatureType::Fillet;
    too_big.params = {{"target", ext_id.str()}, {"radius", 1.5}, {"edges", floor_json}};
    auto bad_id = graph.add(std::move(too_big));
    std::string ferr;
    REQUIRE_FALSE(graph.regenerate(doc, &ferr));
    INFO(ferr);
    CHECK(ferr.find("1.25") != std::string::npos);
    CHECK(ferr.find("limit") != std::string::npos);
    CHECK(shape::volume(doc.body(body)->shape) == Approx(vol_before).margin(1e-4));
    REQUIRE(graph.remove(bad_id));
    REQUIRE(graph.regenerate(doc, &err));
    CHECK(shape::volume(doc.body(body)->shape) == Approx(vol_before).margin(1e-3));

    Feature floor_fil;
    floor_fil.type = FeatureType::Fillet;
    floor_fil.params = {{"target", ext_id.str()}, {"radius", 1.0}, {"edges", floor_json}};
    graph.add(std::move(floor_fil));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    CHECK(err.find("limit 1.250") == std::string::npos);
    CHECK(point_inside(doc.body(body)->shape, gp_Pnt(0.0, 4.9, 7.6)));

    EntityId top = face_at_z(doc, body, 10.0, 20.0);
    REQUIRE(!top.is_null());
    json top_json = outer_top_edges(doc, body, top);
    REQUIRE(top_json.size() >= 4);
    Feature top_fil;
    top_fil.type = FeatureType::Fillet;
    top_fil.params = {{"target", ext_id.str()}, {"radius", 1.0}, {"edges", top_json}};
    graph.add(std::move(top_fil));
    err.clear();
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    CHECK(err.find("limit 1.250") == std::string::npos);
    CHECK_FALSE(point_inside(doc.body(body)->shape, gp_Pnt(-19.9, 0, 9.9)));
    CHECK(point_inside(doc.body(body)->shape, gp_Pnt(-19.7, 0, 5.0)));

    sx::test::TmpFile solid("rung01_replan3_fillet.3mf");
    std::string last_export_error = "stale";
    REQUIRE(interop::export_3mf(doc, solid.path, &last_export_error));
    CHECK(last_export_error.empty());
    CHECK(std::filesystem::exists(solid.path));

    Document open;
    open.add_body(box_missing_one_face(), "Open");
    const std::string bad_path =
        (std::filesystem::temp_directory_path() / "rung01_replan3_open.3mf").string();
    {
        std::ofstream preexisting(bad_path, std::ios::binary);
        preexisting << "stale zip";
    }
    REQUIRE(std::filesystem::exists(bad_path));
    last_export_error = "stale";
    REQUIRE_FALSE(interop::export_3mf(open, bad_path, &last_export_error));
    CHECK(last_export_error.find("open") != std::string::npos);
    int bad = 0, total = 0;
    REQUIRE(std::sscanf(last_export_error.c_str(),
                        "3MF mesh is open (%d/%d edges not shared twice)", &bad, &total) == 2);
    CHECK(bad > 0);
    CHECK_FALSE(std::filesystem::exists(bad_path));
    std::remove(bad_path.c_str());
}

TEST_CASE("wrench neck R10 on concave edges still succeeds", "[rung01][replan3][fillet]") {
    Document doc;
    FeatureGraph graph;
    double x_neck = 0;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Wrench");
    add_wrench_blank(*skf.sketch, &x_neck);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    auto ext_id = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body = graph.feature(ext_id)->output_body;

    json neck_edges = json::array();
    const Body* b = doc.body(body);
    for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull()) continue;
        gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
        if (std::abs(m.X() - x_neck) < 1.5 && std::abs(std::abs(m.Y()) - 10.0) < 0.5 &&
            std::abs(m.Z() - 5.0) < 1.0)
            neck_edges.push_back(eid.str());
    }
    REQUIRE(neck_edges.size() == 2);

    Feature neck;
    neck.type = FeatureType::Fillet;
    neck.params = {{"target", ext_id.str()}, {"radius", 10.0}, {"edges", neck_edges}};
    graph.add(std::move(neck));
    REQUIRE(graph.regenerate(doc, &err));
    CHECK(point_inside(doc.body(body)->shape, gp_Pnt(179.0, 10.5, 5.0)));
    CHECK(point_inside(doc.body(body)->shape, gp_Pnt(179.0, -10.5, 5.0)));
    CHECK_FALSE(point_inside(doc.body(body)->shape, gp_Pnt(174.0, 12.5, 5.0)));
}
