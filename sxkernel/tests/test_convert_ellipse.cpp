// Convert of ellipse / tilted circle copies the kernel curve. Associative
// regen updates the projected entity. Probe: tessellated circle seam/centroid.

#include <catch.hpp>

#include <cmath>
#include <memory>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <GeomAbs_CurveType.hxx>
#include <Geom_Ellipse.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Elips.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch3d.hpp"
#include "sx/tessellate.hpp"

using namespace sx;
using nlohmann::json;

namespace {

const double kPi = 3.14159265358979323846;

EntityId only_edge(const Document& doc, const EntityId& body) {
    const Body* b = doc.body(body);
    REQUIRE(b != nullptr);
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

EntityId ellipse_edge_at(const Document& doc, const EntityId& body, double z, double rx,
                         double ry) {
    const Body* b = doc.body(body);
    if (b == nullptr) return {};
    auto it = b->subshape_ids.find(EntityKind::Edge);
    if (it == b->subshape_ids.end()) return {};
    for (const auto& eid : it->second) {
        const TopoDS_Shape shape = doc.resolve(eid);
        if (shape.IsNull() || shape.ShapeType() != TopAbs_EDGE) continue;
        const BRepAdaptor_Curve curve(TopoDS::Edge(shape));
        if (curve.GetType() != GeomAbs_Ellipse) continue;
        const gp_Elips el = curve.Ellipse();
        if (std::abs(el.Location().Z() - z) > 0.05) continue;
        if (std::abs(el.MajorRadius() - rx) > 0.05) continue;
        if (std::abs(el.MinorRadius() - ry) > 0.05) continue;
        return eid;
    }
    return {};
}

}  // namespace

TEST_CASE("probe: get_edge_lines circle seam and centroid", "[convert][ellipse][probe]") {
    Document doc;
    gp_Circ circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 22.5);
    const EntityId body = doc.add_body(BRepBuilderAPI_MakeEdge(circ).Edge(), "circle");
    BodyMesh mesh = tessellate_body(doc, body, 0.2, 0.35);
    REQUIRE_FALSE(mesh.edges.empty());
    const auto& pts = mesh.edges.front().points;
    REQUIRE(pts.size() >= 6);
    const size_t n = pts.size() / 3;
    gp_Pnt first(pts[0], pts[1], pts[2]);
    gp_Pnt last(pts[(n - 1) * 3], pts[(n - 1) * 3 + 1], pts[(n - 1) * 3 + 2]);
    const bool seam_repeat = first.Distance(last) <= 0.2;
    double cx = 0, cy = 0, cz = 0;
    for (size_t i = 0; i < n; ++i) {
        cx += pts[3 * i];
        cy += pts[3 * i + 1];
        cz += pts[3 * i + 2];
    }
    cx /= static_cast<double>(n);
    cy /= static_cast<double>(n);
    cz /= static_cast<double>(n);
    const double centroid_err = std::hypot(cx, cy, cz);
    INFO("seam_repeat=" << seam_repeat << " n=" << n << " centroid_err=" << centroid_err);
    // Recorded for the plan: even when the seam repeats, stop using polylines
    // for pierce/anchors. The ~r/N Ø45 claim is dropped if centroid_err is small.
    CHECK(n >= 8);
    if (centroid_err > 0.2)
        WARN("tessellation centroid off by " << centroid_err << " mm (r/N would be "
                                             << (22.5 / static_cast<double>(n)) << ")");
}

TEST_CASE("convert in-plane ellipse keeps radii", "[convert][ellipse]") {
    Document doc;
    FeatureGraph& graph = doc.graph();
    auto sk = std::make_shared<Sketch>("ell");
    sk->add_ellipse(0.0, 0.0, 20.0, 10.0, 0.0);
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = sk;
    const EntityId sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 15.0}, {"op", "new"}, {"end", "blind"}};
    graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    REQUIRE(doc.body_ids().size() == 1);
    const EntityId body = doc.body_ids()[0];
    const EntityId rim = ellipse_edge_at(doc, body, 15.0, 20.0, 10.0);
    REQUIRE_FALSE(rim.is_null());

    const EntityId fid = sketch_xy(graph, 15.0);
    const EntityId added = add_external_edge(doc, fid, rim);
    REQUIRE_FALSE(added.is_null());
    Sketch& sketch = *graph.feature(fid)->sketch;
    const SketchEntity* entity = sketch.entity(added);
    REQUIRE(entity != nullptr);
    CHECK(entity->type == SketchEntityType::Ellipse);
    CHECK(entity->external);
    auto axes = sketch.ellipse_axes(added);
    REQUIRE(axes.has_value());
    CHECK((*axes)[2] == Approx(20.0).margin(1e-6));
    CHECK((*axes)[3] == Approx(10.0).margin(1e-6));

    json report = exactness::report_sketch(sketch);
    REQUIRE(report["entities"].size() == 1);
    CHECK(report["entities"][0]["type"] == "ellipse");
}

TEST_CASE("convert ellipse follows regen", "[convert][ellipse]") {
    Document doc;
    gp_Elips el(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 20.0, 10.0);
    const EntityId body = doc.add_body(BRepBuilderAPI_MakeEdge(el).Edge(), "ell");
    const EntityId edge = only_edge(doc, body);
    const EntityId fid = sketch_xy(doc.graph());
    const EntityId added = add_external_edge(doc, fid, edge);
    REQUIRE_FALSE(added.is_null());
    auto axes0 = doc.graph().feature(fid)->sketch->ellipse_axes(added);
    REQUIRE(axes0.has_value());
    CHECK((*axes0)[2] == Approx(20.0).margin(1e-6));

    gp_Elips el2(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 25.0, 10.0);
    doc.replace_body_shape(body, BRepBuilderAPI_MakeEdge(el2).Edge());
    CHECK(rebuild_projected_externals(doc, fid) >= 1);
    auto axes1 = doc.graph().feature(fid)->sketch->ellipse_axes(added);
    REQUIRE(axes1.has_value());
    CHECK((*axes1)[2] == Approx(25.0).margin(1e-6));
    CHECK((*axes1)[3] == Approx(10.0).margin(1e-6));
}

TEST_CASE("tilted circle converts to ellipse", "[convert][ellipse]") {
    Document doc;
    const double deg30 = kPi / 6.0;
    gp_Ax2 ax(gp_Pnt(0, 0, 0), gp_Dir(0, std::sin(deg30), std::cos(deg30)));
    gp_Circ circ(ax, 20.0);
    const EntityId body = doc.add_body(BRepBuilderAPI_MakeEdge(circ).Edge(), "tilt");
    const EntityId edge = only_edge(doc, body);
    REQUIRE(BRepAdaptor_Curve(TopoDS::Edge(doc.resolve(edge))).GetType() == GeomAbs_Circle);

    const EntityId fid = sketch_xy(doc.graph());
    const EntityId added = add_external_edge(doc, fid, edge);
    REQUIRE_FALSE(added.is_null());
    Sketch& sketch = *doc.graph().feature(fid)->sketch;
    const SketchEntity* entity = sketch.entity(added);
    REQUIRE(entity != nullptr);
    CHECK(entity->type == SketchEntityType::Ellipse);
    auto axes = sketch.ellipse_axes(added);
    REQUIRE(axes.has_value());
    CHECK((*axes)[2] == Approx(20.0).margin(1e-6));
    CHECK((*axes)[3] == Approx(20.0 * std::cos(deg30)).margin(1e-6));
}
