#include <catch.hpp>

#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

namespace {

// no_hole(60) from the rung-2 PART table: rounded box minus the open cavity.
double no_hole_60() {
    const double pi = 3.14159265358979323846;
    const double w = 60.0;
    const double rounded = 50.0 * (100.0 * w - (4.0 - pi) * 100.0);
    const double inner = 45.0 * (90.0 * (w - 10.0) - (4.0 - pi) * 25.0);
    return rounded - inner;
}

}  // namespace

TEST_CASE("shell a filleted box opens the top", "[shell][rung02]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.name = "sketch 1";
    skf.sketch = std::make_shared<Sketch>("sketch 1");
    auto bottom = skf.sketch->add_line(0, 0, 100, 0);
    auto right = skf.sketch->add_line(100, 0, 100, 60);
    auto top = skf.sketch->add_line(100, 60, 0, 60);
    auto left = skf.sketch->add_line(0, 60, 0, 0);
    skf.sketch->add_constraint(ConstraintType::Coincident,
                               {{bottom, PointRole::End}, {right, PointRole::Start}});
    skf.sketch->add_constraint(ConstraintType::Coincident,
                               {{right, PointRole::End}, {top, PointRole::Start}});
    skf.sketch->add_constraint(ConstraintType::Coincident,
                               {{top, PointRole::End}, {left, PointRole::Start}});
    skf.sketch->add_constraint(ConstraintType::Coincident,
                               {{left, PointRole::End}, {bottom, PointRole::Start}});
    skf.sketch->add_constraint(ConstraintType::Horizontal, {{bottom, PointRole::Self}});
    skf.sketch->add_constraint(ConstraintType::Horizontal, {{top, PointRole::Self}});
    skf.sketch->add_constraint(ConstraintType::Vertical, {{right, PointRole::Self}});
    skf.sketch->add_constraint(ConstraintType::Vertical, {{left, PointRole::Self}});
    skf.sketch->add_constraint(ConstraintType::Fix, {{bottom, PointRole::Self}});
    skf.sketch->add_constraint(ConstraintType::Distance,
                               {{bottom, PointRole::Start}, {bottom, PointRole::End}}, 100.0);
    skf.sketch->add_constraint(ConstraintType::Distance,
                               {{right, PointRole::Start}, {right, PointRole::End}}, 60.0);
    const auto sk_id = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.name = "extrude 1";
    ext.params = {{"sketch", sk_id.str()}, {"distance", 50.0}, {"op", "new"}, {"end", "blind"}};
    const auto ext_id = graph.add(std::move(ext));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* box = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(box != nullptr);

    nlohmann::json edges = nlohmann::json::array();
    for (const auto& eid : box->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape es = doc.resolve(eid);
        if (es.IsNull() || es.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge edge = TopoDS::Edge(es);
        BRepAdaptor_Curve curve(edge);
        if (curve.GetType() != GeomAbs_Line) continue;
        gp_Vec v = curve.Line().Direction();
        if (std::abs(v.Z()) < 0.99) continue;
        edges.push_back(eid.str());
    }
    REQUIRE(edges.size() == 4);

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.name = "fillet";
    fil.params = {{"target", ext_id.str()}, {"radius", 10.0}, {"edges", edges}};
    graph.add(std::move(fil));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);

    const Body* rounded = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(rounded != nullptr);
    std::string top_face;
    for (const auto& fid : rounded->subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape fs = doc.resolve(fid);
        if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(fs);
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (n.Z() < 0.999) continue;
        GProp_GProps props;
        BRepGProp::SurfaceProperties(face, props);
        if (props.CentreOfMass().Z() < 40.0) continue;
        top_face = fid.str();
        break;
    }
    REQUIRE_FALSE(top_face.empty());

    Feature sh;
    sh.type = FeatureType::Shell;
    sh.name = "shell";
    sh.params = {{"target", ext_id.str()},
                 {"faces", nlohmann::json::array({top_face})},
                 {"thickness", 5.0}};
    graph.add(std::move(sh));
    const bool ok = graph.regenerate(doc, &err);
    INFO(err);
    REQUIRE(ok);

    const Body* body = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::is_valid(body->shape));
    int solids = 0;
    for (TopExp_Explorer ex(body->shape, TopAbs_SOLID); ex.More(); ex.Next()) solids += 1;
    REQUIRE(solids == 1);
    REQUIRE(shape::volume(body->shape) == Approx(no_hole_60()).epsilon(0.005));
}
