#include <catch.hpp>

#include <cmath>
#include <memory>
#include <string>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <GeomAbs_CurveType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>

#include "features/ops.hpp"
#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

std::shared_ptr<Sketch> square_xy(double half, const SketchPlane& pl = {}) {
    auto sk = std::make_shared<Sketch>("Square", pl);
    sk->add_line(-half, -half, half, -half);
    sk->add_line(half, -half, half, half);
    sk->add_line(half, half, -half, half);
    sk->add_line(-half, half, -half, -half);
    return sk;
}

EntityId add_sketch(FeatureGraph& g, std::shared_ptr<Sketch> sk) {
    Feature f;
    f.type = FeatureType::Sketch;
    f.sketch = std::move(sk);
    return g.add(std::move(f));
}

double guide_max_dist(const TopoDS_Wire& guide, const TopoDS_Shape& solid) {
    double worst = 0.0;
    for (BRepTools_WireExplorer ex(guide); ex.More(); ex.Next()) {
        BRepAdaptor_Curve c(ex.Current());
        for (int s = 0; s <= 20; ++s) {
            const double t = static_cast<double>(s) / 20.0;
            const double u = c.FirstParameter() + t * (c.LastParameter() - c.FirstParameter());
            TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(c.Value(u)).Vertex();
            BRepExtrema_DistShapeShape dist(v, solid);
            if (!dist.IsDone() || dist.NbSolution() < 1) return 1e9;
            worst = std::max(worst, dist.Value());
        }
    }
    return worst;
}

bool has_circle_edge(const TopoDS_Shape& s) {
    json j = exactness::probe_shape(s);
    for (const auto& e : j["edges"])
        if (e.value("type", "") == "GeomAbs_Circle") return true;
    return false;
}

}  // namespace

TEST_CASE("guided loft: square-to-square follows offset guide", "[exactness][loft]") {
    const double half = 10.0;
    const double height = 40.0;
    const double offset = 5.0;  // 5 mm outside the x=+half face

    Document unguided;
    auto b0 = add_sketch(unguided.graph(), square_xy(half));
    SketchPlane top_pl;
    top_pl.origin = {0, 0, height};
    auto b1 = add_sketch(unguided.graph(), square_xy(half, top_pl));
    Feature loft0;
    loft0.type = FeatureType::Loft;
    loft0.params = {{"sketches", json::array({b0.str(), b1.str()})}, {"ruled", true}};
    auto loft0_id = unguided.graph().add(std::move(loft0));
    std::string err;
    REQUIRE(unguided.graph().regenerate(unguided, &err));
    const double vol0 =
        shape::volume(unguided.body(unguided.graph().feature(loft0_id)->output_body)->shape);
    REQUIRE(vol0 == Approx(2.0 * half * 2.0 * half * height).epsilon(0.02));

    Document guided;
    auto g0 = add_sketch(guided.graph(), square_xy(half));
    auto g1 = add_sketch(guided.graph(), square_xy(half, top_pl));
    SketchPlane xz;
    xz.x_dir = {1, 0, 0};
    xz.y_dir = {0, 0, 1};
    auto guide = std::make_shared<Sketch>("Guide", xz);
    guide->add_line(half + offset, 0.0, half + offset, height);
    auto gid = add_sketch(guided.graph(), guide);
    Feature loft1;
    loft1.type = FeatureType::Loft;
    loft1.params = {{"sketches", json::array({g0.str(), g1.str()})},
                    {"ruled", false},
                    {"guides", json::array({gid.str()})}};
    auto loft1_id = guided.graph().add(std::move(loft1));
    REQUIRE(guided.graph().regenerate(guided, &err));
    const Body* body = guided.body(guided.graph().feature(loft1_id)->output_body);
    REQUIRE(body != nullptr);
    const double vol1 = shape::volume(body->shape);
    REQUIRE(std::abs(vol1 - vol0) > 1.0);
    CHECK_FALSE(has_circle_edge(body->shape));

    TopoDS_Wire gw = feature_ops::sketch_exact_wire(*guide);
    REQUIRE_FALSE(gw.IsNull());
    REQUIRE(guide_max_dist(gw, body->shape) < 1e-6);
}

TEST_CASE("guided loft: refuse when the guide cannot be followed", "[exactness][loft]") {
    Document doc;
    auto b0 = add_sketch(doc.graph(), square_xy(10.0));
    SketchPlane top;
    top.origin = {0, 0, 20};
    auto b1 = add_sketch(doc.graph(), square_xy(10.0, top));
    auto empty = std::make_shared<Sketch>("EmptyGuide");
    auto gid = add_sketch(doc.graph(), empty);
    Feature loft;
    loft.type = FeatureType::Loft;
    loft.params = {{"sketches", json::array({b0.str(), b1.str()})},
                   {"guides", json::array({gid.str()})}};
    doc.graph().add(std::move(loft));
    std::string err;
    REQUIRE_FALSE(doc.graph().regenerate(doc, &err));
    REQUIRE(err.find("guide") != std::string::npos);
}
