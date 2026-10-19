// A boss-top sketch can convert the Ø70 rim into one external circle.
// Full circles in a plane parallel to the sketch only; arcs stay out.

#include <catch.hpp>

#include <algorithm>
#include <cmath>

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <GeomConvert.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/query.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch3d.hpp"
#include "sx/solver.hpp"

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

// Base 120×120×30 plus Ø70 boss. The rim is the full circle at z = 55, r = 35.
EntityId build_boss(Document& doc, FeatureGraph& graph) {
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

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    REQUIRE(doc.body_ids().size() == 1);
    return doc.body_ids()[0];
}

EntityId circle_edge_at(const Document& doc, const EntityId& body, double z, double radius) {
    const Body* b = doc.body(body);
    if (b == nullptr) return {};
    auto it = b->subshape_ids.find(EntityKind::Edge);
    if (it == b->subshape_ids.end()) return {};
    for (const auto& eid : it->second) {
        const TopoDS_Shape shape = doc.resolve(eid);
        if (shape.IsNull() || shape.ShapeType() != TopAbs_EDGE) continue;
        const BRepAdaptor_Curve curve(TopoDS::Edge(shape));
        if (curve.GetType() != GeomAbs_Circle) continue;
        const gp_Circ circ = curve.Circle();
        const double span = std::abs(curve.LastParameter() - curve.FirstParameter());
        if (span < 2.0 * kPi - 0.05) continue;
        if (std::abs(circ.Location().Z() - z) > 0.05) continue;
        if (std::abs(circ.Radius() - radius) > 0.05) continue;
        return eid;
    }
    return {};
}

EntityId planar_face_z(const Document& doc, const EntityId& body, double z) {
    const Body* b = doc.body(body);
    if (b == nullptr) return {};
    auto it = b->subshape_ids.find(EntityKind::Face);
    if (it == b->subshape_ids.end()) return {};
    for (const auto& fid : it->second) {
        const TopoDS_Shape shape = doc.resolve(fid);
        if (shape.IsNull() || shape.ShapeType() != TopAbs_FACE) continue;
        const BRepAdaptor_Surface surf(TopoDS::Face(shape));
        if (surf.GetType() != GeomAbs_Plane) continue;
        const gp_Pln pl = surf.Plane();
        const gp_Dir n = pl.Axis().Direction();
        if (std::abs(std::abs(n.Z()) - 1.0) > 0.02) continue;
        if (std::abs(pl.Location().Z() - z) > 0.2) continue;
        return fid;
    }
    return {};
}

EntityId sketch_on_z(FeatureGraph& graph, double z) {
    SketchPlane pl;
    pl.origin = {0, 0, z};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    Feature feature;
    feature.type = FeatureType::Sketch;
    feature.sketch = std::make_shared<Sketch>("on face", pl);
    return graph.add(std::move(feature));
}

}  // namespace

TEST_CASE("edges_of_face includes the boss rim on the top face", "[sketch][rung03]") {
    Document doc;
    FeatureGraph& graph = doc.graph();
    const EntityId body = build_boss(doc, graph);
    const EntityId rim = circle_edge_at(doc, body, 55.0, 35.0);
    const EntityId top = planar_face_z(doc, body, 55.0);
    REQUIRE_FALSE(rim.is_null());
    REQUIRE_FALSE(top.is_null());
    const auto edges = edges_of_face(doc, top);
    CHECK(std::find(edges.begin(), edges.end(), rim) != edges.end());
}

TEST_CASE("add_external_edge projects the boss rim as a fixed circle", "[sketch][rung03]") {
    Document doc;
    FeatureGraph& graph = doc.graph();
    const EntityId body = build_boss(doc, graph);
    const EntityId rim = circle_edge_at(doc, body, 55.0, 35.0);
    REQUIRE_FALSE(rim.is_null());

    const EntityId fid = sketch_on_z(graph, 55.0);
    const int dofs_before = make_planegcs_backend()->solve(*graph.feature(fid)->sketch).dofs;
    const EntityId added = add_external_edge(doc, fid, rim);
    REQUIRE_FALSE(added.is_null());

    const Sketch& sketch = *graph.feature(fid)->sketch;
    REQUIRE(sketch.entities().size() == 1);
    const SketchEntity* entity = sketch.entity(added);
    REQUIRE(entity != nullptr);
    CHECK(entity->type == SketchEntityType::Circle);
    CHECK(entity->external);
    CHECK(entity->construction);
    CHECK(entity->projected_from == rim.str());
    CHECK(sketch.param(entity->params[0]) == Approx(0.0).margin(1e-6));
    CHECK(sketch.param(entity->params[1]) == Approx(0.0).margin(1e-6));
    CHECK(sketch.param(entity->params[2]) == Approx(35.0).margin(1e-6));

    const auto solved = make_planegcs_backend()->solve(*graph.feature(fid)->sketch);
    CHECK(solved.ok());
    CHECK(solved.dofs == dofs_before);
    CHECK(solved.dofs == 0);

    CHECK(add_external_edge(doc, fid, rim) == added);
    CHECK(graph.feature(fid)->sketch->entities().size() == 1);

    // A 90° arc in the same plane projects as a trimmed Arc, not a full circle.
    gp_Circ arc_curve(gp_Ax2(gp_Pnt(0, 0, 55), gp_Dir(0, 0, 1)), 35.0);
    const EntityId arc_body =
        doc.add_body(BRepBuilderAPI_MakeEdge(arc_curve, 0.0, kPi / 2.0).Edge(), "arc");
    EntityId arc_id;
    const Body* arc = doc.body(arc_body);
    REQUIRE(arc != nullptr);
    for (const auto& eid : arc->subshape_ids.at(EntityKind::Edge)) arc_id = eid;
    REQUIRE_FALSE(arc_id.is_null());
    const EntityId projected_arc = add_external_edge(doc, fid, arc_id);
    REQUIRE_FALSE(projected_arc.is_null());
    const SketchEntity* arc_e = graph.feature(fid)->sketch->entity(projected_arc);
    REQUIRE(arc_e != nullptr);
    CHECK(arc_e->type == SketchEntityType::Arc);
    CHECK(arc_e->external);
    CHECK(arc_e->construction);
    CHECK(graph.feature(fid)->sketch->param(arc_e->params[2]) == Approx(35.0).margin(1e-6));
    const double sweep =
        graph.feature(fid)->sketch->param(arc_e->params[4]) -
        graph.feature(fid)->sketch->param(arc_e->params[3]);
    CHECK(std::abs(std::abs(sweep) - kPi / 2.0) < 0.05);
    CHECK(graph.feature(fid)->sketch->entities().size() == 2);

    Handle(Geom_Circle) gc = new Geom_Circle(arc_curve);
    Handle(Geom_TrimmedCurve) trim = new Geom_TrimmedCurve(gc, 0.0, kPi / 2.0);
    Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(trim);
    const EntityId bs_body = doc.add_body(BRepBuilderAPI_MakeEdge(bs).Edge(), "bspline-arc");
    EntityId bs_id;
    const Body* bs_body_ptr = doc.body(bs_body);
    REQUIRE(bs_body_ptr != nullptr);
    for (const auto& eid : bs_body_ptr->subshape_ids.at(EntityKind::Edge)) bs_id = eid;
    REQUIRE_FALSE(bs_id.is_null());
    const EntityId projected_bs = add_external_edge(doc, fid, bs_id);
    REQUIRE_FALSE(projected_bs.is_null());
    const SketchEntity* bs_e = graph.feature(fid)->sketch->entity(projected_bs);
    REQUIRE(bs_e != nullptr);
    CHECK(bs_e->type == SketchEntityType::Arc);
    CHECK(bs_e->external);
    CHECK(graph.feature(fid)->sketch->param(bs_e->params[2]) == Approx(35.0).margin(0.2));

    // Origin-plane silhouette: the rim ∩ YZ is a construction diameter.
    const EntityId side = sketch_on_z(graph, 0.0);
    Feature* side_feature = graph.feature(side);
    SketchPlane side_plane = side_feature->sketch->plane();
    side_plane.x_dir = {0, 1, 0};
    side_plane.y_dir = {0, 0, 1};
    side_feature->sketch->set_plane(side_plane);
    const EntityId sil = add_external_edge(doc, side, rim);
    REQUIRE_FALSE(sil.is_null());
    const SketchEntity* sil_e = side_feature->sketch->entity(sil);
    REQUIRE(sil_e != nullptr);
    CHECK(sil_e->type == SketchEntityType::Line);
    CHECK(sil_e->construction);
    CHECK(sil_e->external);

}
