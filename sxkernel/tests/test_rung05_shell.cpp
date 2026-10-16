// Rung 5 WP3 — shell both planar ends of Ø150 × 250. Volume is the
// shelled row; both ends open. Feature graph, not the UI chip.

#include <catch.hpp>

#include <cmath>
#include <string>
#include <vector>

#include <BRepAdaptor_Surface.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

namespace {

const double kShelled = 1099557.429;

bool point_inside(const TopoDS_Shape& shape, const gp_Pnt& p) {
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) {
        BRepClass3d_SolidClassifier cl(ex.Current());
        cl.Perform(p, 1e-6);
        if (cl.State() == TopAbs_IN) return true;
    }
    return false;
}

nlohmann::json planar_z_faces(const Document& doc, const Body& body) {
    nlohmann::json out = nlohmann::json::array();
    for (const auto& fid : body.subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape fs = doc.resolve(fid);
        if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(fs);
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (std::abs(n.Z()) < 0.99) continue;
        out.push_back(fid.str());
    }
    return out;
}

}  // namespace

TEST_CASE("shell both ends of a cylinder opens a tube", "[shell][rung05]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.name = "sketch 1";
    skf.sketch = std::make_shared<Sketch>("sketch 1");
    skf.sketch->add_circle(0, 0, 75.0);
    const auto sk_id = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.name = "extrude 1";
    ext.params = {{"sketch", sk_id.str()}, {"distance", 250.0}, {"op", "new"}, {"end", "blind"}};
    const auto ext_id = graph.add(std::move(ext));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* cyl = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(cyl != nullptr);

    const nlohmann::json ends = planar_z_faces(doc, *cyl);
    REQUIRE(ends.size() == 2);

    Feature sh;
    sh.type = FeatureType::Shell;
    sh.name = "shell";
    sh.params = {{"target", ext_id.str()}, {"faces", ends}, {"thickness", 10.0}};
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
    REQUIRE(shape::volume(body->shape) == Approx(kShelled).epsilon(0.005));
    CHECK_FALSE(point_inside(body->shape, gp_Pnt(0, 0, 125)));
    CHECK(point_inside(body->shape, gp_Pnt(70, 0, 125)));
}
