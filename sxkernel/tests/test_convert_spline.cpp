// Convert of an in-plane BSpline/Bezier copies the curve as a sketch Spline
// (interpolating fit, 1e-6). Line and Circle/Arc Convert stay typed.

#include <catch.hpp>

#include <cmath>
#include <memory>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRep_Tool.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAbs_CurveType.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "features/ops.hpp"
#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch3d.hpp"

using namespace sx;
using nlohmann::json;

namespace {

const double kPi = 3.14159265358979323846;

EntityId only_edge(const Document& doc, const EntityId& body) {
    const Body* b = doc.body(body);
    REQUIRE(b != nullptr);
    REQUIRE(b->subshape_ids.count(EntityKind::Edge) == 1);
    REQUIRE_FALSE(b->subshape_ids.at(EntityKind::Edge).empty());
    return b->subshape_ids.at(EntityKind::Edge).front();
}

EntityId sketch_xy(FeatureGraph& graph, double z = 0.0) {
    SketchPlane pl;
    pl.origin = {0, 0, z};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    Feature feature;
    feature.type = FeatureType::Sketch;
    feature.sketch = std::make_shared<Sketch>("convert", pl);
    return graph.add(std::move(feature));
}

Handle(Geom_BSplineCurve) zigzag_bspline() {
    const std::vector<gp_Pnt> pts = {
        gp_Pnt(0, 0, 0), gp_Pnt(10, 8, 0), gp_Pnt(20, -4, 0), gp_Pnt(30, 6, 0), gp_Pnt(40, 0, 0)};
    Handle(TColgp_HArray1OfPnt) arr = new TColgp_HArray1OfPnt(1, static_cast<int>(pts.size()));
    for (int i = 0; i < static_cast<int>(pts.size()); ++i) arr->SetValue(i + 1, pts[static_cast<size_t>(i)]);
    GeomAPI_Interpolate interp(arr, Standard_False, 1.0e-7);
    interp.Perform();
    REQUIRE(interp.IsDone());
    return interp.Curve();
}

double point_to_edge(const gp_Pnt& p, const TopoDS_Edge& edge) {
    BRepExtrema_DistShapeShape dist(BRepBuilderAPI_MakeVertex(p).Vertex(), edge);
    if (!dist.IsDone() || dist.NbSolution() < 1) return 1e9;
    return dist.Value();
}

}  // namespace

TEST_CASE("convert in-plane BSpline is a sketch Spline on the edge", "[convert][spline]") {
    Document doc;
    Handle(Geom_BSplineCurve) curve = zigzag_bspline();
    REQUIRE_FALSE(curve.IsNull());
    const EntityId body = doc.add_body(BRepBuilderAPI_MakeEdge(curve).Edge(), "zigzag");
    const EntityId edge = only_edge(doc, body);
    BRepAdaptor_Curve adaptor(TopoDS::Edge(doc.resolve(edge)));
    REQUIRE(adaptor.GetType() == GeomAbs_BSplineCurve);

    const EntityId fid = sketch_xy(doc.graph());
    const EntityId added = add_external_edge(doc, fid, edge);
    REQUIRE_FALSE(added.is_null());

    Sketch& sketch = *doc.graph().feature(fid)->sketch;
    const SketchEntity* entity = sketch.entity(added);
    REQUIRE(entity != nullptr);
    CHECK(entity->type == SketchEntityType::Spline);
    CHECK(entity->external);
    CHECK(entity->construction);
    CHECK(entity->projected_from == edge.str());

    json report = exactness::report_sketch(sketch);
    REQUIRE(report["entities"].size() == 1);
    CHECK(report["entities"][0]["type"] == "spline");
    REQUIRE(report["entities"][0].contains("fit_points"));
    CHECK(report["entities"][0]["fit_points"].size() >= 2);

    const auto fits = sketch.spline_fit_points(added);
    REQUIRE(fits.size() >= 2);
    const TopoDS_Edge shape = TopoDS::Edge(doc.resolve(edge));
    for (const auto& uv : fits) {
        const gp_Pnt p = feature_ops::sketch_uv_to_3d(sketch.plane(), uv[0], uv[1]);
        CHECK(point_to_edge(p, shape) <= 1e-6);
    }
}

TEST_CASE("convert in-plane Bezier is a sketch Spline", "[convert][spline]") {
    Document doc;
    TColgp_Array1OfPnt poles(1, 4);
    poles.SetValue(1, gp_Pnt(0, 0, 0));
    poles.SetValue(2, gp_Pnt(8, 12, 0));
    poles.SetValue(3, gp_Pnt(22, -6, 0));
    poles.SetValue(4, gp_Pnt(30, 2, 0));
    Handle(Geom_BezierCurve) bezier = new Geom_BezierCurve(poles);
    const EntityId body = doc.add_body(BRepBuilderAPI_MakeEdge(bezier).Edge(), "bezier");
    const EntityId edge = only_edge(doc, body);
    REQUIRE(BRepAdaptor_Curve(TopoDS::Edge(doc.resolve(edge))).GetType() == GeomAbs_BezierCurve);

    const EntityId fid = sketch_xy(doc.graph());
    const EntityId added = add_external_edge(doc, fid, edge);
    REQUIRE_FALSE(added.is_null());
    const SketchEntity* entity = doc.graph().feature(fid)->sketch->entity(added);
    REQUIRE(entity != nullptr);
    CHECK(entity->type == SketchEntityType::Spline);
    CHECK(entity->external);

    const auto fits = doc.graph().feature(fid)->sketch->spline_fit_points(added);
    const TopoDS_Edge shape = TopoDS::Edge(doc.resolve(edge));
    for (const auto& uv : fits) {
        const gp_Pnt p =
            feature_ops::sketch_uv_to_3d(doc.graph().feature(fid)->sketch->plane(), uv[0], uv[1]);
        CHECK(point_to_edge(p, shape) <= 1e-6);
    }
}

TEST_CASE("convert Line and Arc stay Line and Arc", "[convert][spline]") {
    Document doc;
    const EntityId line_body =
        doc.add_body(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(25, 0, 0)).Edge(), "line");
    const EntityId line_edge = only_edge(doc, line_body);

    gp_Circ circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 12.0);
    const EntityId arc_body =
        doc.add_body(BRepBuilderAPI_MakeEdge(circ, 0.0, kPi / 2.0).Edge(), "arc");
    const EntityId arc_edge = only_edge(doc, arc_body);

    const EntityId fid = sketch_xy(doc.graph());
    const EntityId line_id = add_external_edge(doc, fid, line_edge);
    const EntityId arc_id = add_external_edge(doc, fid, arc_edge);
    REQUIRE_FALSE(line_id.is_null());
    REQUIRE_FALSE(arc_id.is_null());

    Sketch& sketch = *doc.graph().feature(fid)->sketch;
    REQUIRE(sketch.entity(line_id)->type == SketchEntityType::Line);
    REQUIRE(sketch.entity(arc_id)->type == SketchEntityType::Arc);
    CHECK(sketch.param(sketch.entity(arc_id)->params[2]) == Approx(12.0).margin(1e-6));
}
