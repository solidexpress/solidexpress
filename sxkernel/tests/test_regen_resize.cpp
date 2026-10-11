#include <catch.hpp>

#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <BRepIntCurveSurface_Inter.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

namespace {

double no_hole(double w) {
    const double pi = 3.14159265358979323846;
    const double rounded = 50.0 * (100.0 * w - (4.0 - pi) * 100.0);
    const double inner = 45.0 * (90.0 * (w - 10.0) - (4.0 - pi) * 25.0);
    return rounded - inner;
}

std::vector<double> ray_hits(const TopoDS_Shape& shape, const gp_Pnt& origin, const gp_Dir& dir) {
    BRepIntCurveSurface_Inter inter;
    inter.Init(shape, gp_Lin(origin, dir), 1e-6);
    std::vector<double> ts;
    for (; inter.More(); inter.Next()) ts.push_back(inter.W());
    std::sort(ts.begin(), ts.end());
    std::vector<double> unique;
    for (double t : ts) {
        if (unique.empty() || std::abs(t - unique.back()) > 1e-4) unique.push_back(t);
    }
    return unique;
}

double wall_thickness(const TopoDS_Shape& shape, const gp_Pnt& origin, const gp_Dir& dir) {
    const auto ts = ray_hits(shape, origin, dir);
    REQUIRE(ts.size() >= 2);
    return ts[1] - ts[0];
}

}  // namespace

TEST_CASE("fillet and shell survive a rectangle resize", "[regen][rung02]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.name = "sketch 1";
    skf.sketch = std::make_shared<Sketch>("sketch 1");
    auto bottom = skf.sketch->add_line(0, 0, 100, 0);
    auto right = skf.sketch->add_line(100, 0, 100, 65);
    auto top = skf.sketch->add_line(100, 65, 0, 65);
    auto left = skf.sketch->add_line(0, 65, 0, 0);
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
    const auto height_dim = skf.sketch->add_constraint(
        ConstraintType::Distance, {{right, PointRole::Start}, {right, PointRole::End}}, 65.0);
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
    const auto fil_id = graph.add(std::move(fil));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    REQUIRE(graph.warnings().empty());

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
    const bool shelled = graph.regenerate(doc, &err);
    if (!shelled) {
        // G4: shell on the filleted body cannot be built. WP4 owns that.
        // This case then only proves the fillet survives 65 → 60 → 65.
        INFO(err);
        REQUIRE(graph.remove(graph.timeline().back().id));
        REQUIRE(graph.regenerate(doc, &err));
    }

    auto set_width = [&](double w) {
        REQUIRE(graph.feature(sk_id)->sketch->set_constraint_value(height_dim, w));
        const bool ok = graph.regenerate(doc, &err);
        INFO(err);
        REQUIRE(ok);
        REQUIRE(graph.warnings().empty());
    };

    auto expect_part = [&](double w) {
        const Body* body = doc.body(graph.feature(ext_id)->output_body);
        REQUIRE(body != nullptr);
        const double vol = shape::volume(body->shape);
        if (shelled) {
            REQUIRE(vol == Approx(no_hole(w)).epsilon(0.005));
            const TopoDS_Shape& s = body->shape;
            CHECK(wall_thickness(s, gp_Pnt(-10, 20, 25), gp_Dir(1, 0, 0)) == Approx(5.0).margin(0.1));
            CHECK(wall_thickness(s, gp_Pnt(110, 20, 25), gp_Dir(-1, 0, 0)) == Approx(5.0).margin(0.1));
            CHECK(wall_thickness(s, gp_Pnt(50, -10, 25), gp_Dir(0, 1, 0)) == Approx(5.0).margin(0.1));
            CHECK(wall_thickness(s, gp_Pnt(50, w + 10, 25), gp_Dir(0, -1, 0)) == Approx(5.0).margin(0.1));
            CHECK(wall_thickness(s, gp_Pnt(50, w / 2.0, -10), gp_Dir(0, 0, 1)) == Approx(5.0).margin(0.1));
        } else {
            const double pi = 3.14159265358979323846;
            const double rounded = 50.0 * (100.0 * w - (4.0 - pi) * 100.0);
            REQUIRE(vol == Approx(rounded).epsilon(0.005));
        }
        (void)fil_id;
    };

    set_width(60);
    expect_part(60);
    set_width(65);
    expect_part(65);
}
