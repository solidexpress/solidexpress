#include <catch.hpp>

#include "test_temp.hpp"

#include <cmath>
#include <string>

#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopTools_ListOfShape.hxx>

#include "features/ops.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

void weld_arc(Sketch& sk, const EntityId& id, double sx, double sy, double ex, double ey) {
    SketchEntity* e = sk.entity_mut(id);
    REQUIRE(e != nullptr);
    REQUIRE(e->params.size() >= 9);
    sk.param_mut(e->params[5]) = sx;
    sk.param_mut(e->params[6]) = sy;
    sk.param_mut(e->params[7]) = ex;
    sk.param_mut(e->params[8]) = ey;
}

EntityId arc_through(Sketch& sk, double cx, double cy, double r, double sx, double sy,
                     double ex, double ey, double tx, double ty) {
    auto ang = [&](double x, double y) { return std::atan2(y - cy, x - cx); };
    double sa = ang(sx, sy), ea = ang(ex, ey), ta = ang(tx, ty);
    double ea1 = ea;
    while (ea1 <= sa + 1.0e-9) ea1 += 2.0 * M_PI;
    double t = ta;
    while (t < sa - 1.0e-9) t += 2.0 * M_PI;
    EntityId id;
    if (t <= ea1 + 1.0e-9) {
        id = sk.add_arc(cx, cy, r, sa, ea1);
    } else {
        double sa2 = ea, ea2 = sa;
        while (ea2 <= sa2 + 1.0e-9) ea2 += 2.0 * M_PI;
        id = sk.add_arc(cx, cy, r, sa2, ea2);
    }
    SketchEntity* e = sk.entity_mut(id);
    REQUIRE(e != nullptr);
    const double astx = sk.param(e->params[5]);
    const double asty = sk.param(e->params[6]);
    const double dstart = std::hypot(astx - sx, asty - sy);
    const double dend = std::hypot(astx - ex, asty - ey);
    if (dstart <= dend)
        weld_arc(sk, id, sx, sy, ex, ey);
    else
        weld_arc(sk, id, ex, ey, sx, sy);
    return id;
}

std::shared_ptr<Sketch> revolve_profile() {
    auto sk = std::make_shared<Sketch>("Candle");
    sk->add_line(0, 0, 0, 220);
    sk->add_line(0, 220, 20, 220);
    arc_through(*sk, 20, 210, 10, 30, 210, 20, 220, 27, 217);
    sk->add_line(30, 210, 30, 170);
    arc_through(*sk, 30, 150, 20, 30, 130, 30, 170, 50, 150);
    sk->add_line(30, 130, 30, 80);
    const double c60x = 90.0, c60y = 80.0, r60 = 60.0;
    const double c12x = 99.499, c12y = 8.125;
    const double d = std::hypot(c12x - c60x, c12y - c60y);
    const double tanx = c60x + (c12x - c60x) * (r60 / d);
    const double tany = c60y + (c12y - c60y) * (r60 / d);
    const double r12 = std::hypot(c12x - tanx, c12y - tany);
    const double clipx = c12x + std::sqrt(std::max(0.0, r12 * r12 - c12y * c12y));
    arc_through(*sk, c60x, c60y, r60, 30, 80, tanx, tany, 90, 20);
    arc_through(*sk, c12x, c12y, r12, tanx, tany, clipx, 0, c12x + r12, c12y);
    sk->add_line(clipx, 0, 0, 0);
    return sk;
}

std::shared_ptr<Sketch> path_profile() {
    auto sk = std::make_shared<Sketch>("Path");
    sk->add_line(0.0, 10.0, 60.0, 10.0);
    const double c150x = 60.0, c150y = 160.0, r150 = 150.0;
    const double c20x = 167.113, c20y = 86.333, r20 = 20.0;
    const double dx = c20x - c150x, dy = c20y - c150y;
    const double d = std::hypot(dx, dy);
    const double tanx = c150x + dx / d * r150;
    const double tany = c150y + dy / d * r150;
    const double sa150 = std::atan2(10.0 - c150y, 60.0 - c150x);
    const double ea150 = std::atan2(tany - c150y, tanx - c150x);
    sk->add_arc(c150x, c150y, r150, sa150, ea150 < sa150 ? ea150 + 2.0 * M_PI : ea150);
    const double sa20 = std::atan2(tany - c20y, tanx - c20x);
    const double ea20 = std::atan2(75.0 - c20y, 150.634 - c20x);
    sk->add_arc(c20x, c20y, r20, sa20, ea20 < sa20 ? ea20 + 2.0 * M_PI : ea20);
    return sk;
}

std::shared_ptr<Sketch> ellipse_profile() {
    SketchPlane right;
    right.x_dir = {0, 0, 1};
    right.y_dir = {0, 1, 0};
    auto sk = std::make_shared<Sketch>("Ellipse", right);
    sk->add_ellipse(0.0, 10.0, 17.5, 5.0, 0.0);
    return sk;
}

void bbox_xyz(const TopoDS_Shape& s, double out[6]) {
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    box.Get(out[0], out[1], out[2], out[3], out[4], out[5]);
}

bool usable(const TopoDS_Shape& s) { return !s.IsNull() && shape::count(s).solids >= 1; }

TopoDS_Shape try_fuse(const TopoDS_Shape& a, const TopoDS_Shape& b, double fuzzy) {
    BRepAlgoAPI_Fuse opf;
    TopTools_ListOfShape args, tools;
    args.Append(a);
    tools.Append(b);
    opf.SetArguments(args);
    opf.SetTools(tools);
    opf.SetFuzzyValue(fuzzy);
    opf.Build();
    if (opf.IsDone() && usable(opf.Shape())) return opf.Shape();
    return {};
}

}  // namespace

TEST_CASE("rung06 sweep ribbon pipes and fuses", "[rung06][sweep][fuse]") {
    std::string ferr;
    auto ell = ellipse_profile();
    TopoDS_Shape face = ell->profile_face(&ferr);
    REQUIRE_FALSE(face.IsNull());
    auto path = path_profile();
    TopoDS_Wire spine = feature_ops::sketch_spine_wire(*path);
    REQUIRE_FALSE(spine.IsNull());
    REQUIRE(feature_ops::spine_has_circle_radius(spine, 150.0, 0.2));
    REQUIRE(feature_ops::spine_has_circle_radius(spine, 20.0, 0.2));

    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = revolve_profile();
    const auto sk_id = graph.add(std::move(skf));
    Feature rv;
    rv.type = FeatureType::Revolve;
    rv.params = {{"sketch", sk_id.str()},
                 {"axis_point", {0.0, 0.0}},
                 {"axis_dir", {0.0, 1.0}},
                 {"angle", 6.283185307179586},
                 {"op", "new"}};
    const auto rv_id = graph.add(std::move(rv));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* body = doc.body(graph.feature(rv_id)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::count(body->shape).solids >= 1);

    TopoDS_Shape frenet = feature_ops::sweep_along_spine(face, spine, 0.0, false, true);
    REQUIRE(usable(frenet));
    double rb[6] = {};
    bbox_xyz(frenet, rb);
    CHECK(rb[3] == Approx(192.1).margin(0.2));
    TopoDS_Shape merged = try_fuse(body->shape, frenet, 1.0e-4);
    REQUIRE(usable(merged));
    double bb[6] = {};
    bbox_xyz(merged, bb);
    CHECK(bb[3] == Approx(192.1).margin(0.2));
    CHECK(shape::volume(merged) == Approx(1741298.0).epsilon(0.005));
}

TEST_CASE("rung06 sweep fuses via FeatureGraph", "[rung06][sweep][graph]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = revolve_profile();
    const auto sk_id = graph.add(std::move(skf));

    Feature rv;
    rv.type = FeatureType::Revolve;
    rv.params = {{"sketch", sk_id.str()},
                 {"axis_point", {0.0, 0.0}},
                 {"axis_dir", {0.0, 1.0}},
                 {"angle", 6.283185307179586},
                 {"op", "new"}};
    const auto rv_id = graph.add(std::move(rv));

    Feature path_sk;
    path_sk.type = FeatureType::Sketch;
    path_sk.sketch = path_profile();
    const auto path_sk_id = graph.add(std::move(path_sk));

    Feature pathf;
    pathf.type = FeatureType::Path;
    pathf.params = {{"sketches", json::array({path_sk_id.str()})}, {"mode", "join_endpoints"}};
    const auto path_fid = graph.add(std::move(pathf));

    Feature ell_sk;
    ell_sk.type = FeatureType::Sketch;
    ell_sk.sketch = ellipse_profile();
    const auto ell_id = graph.add(std::move(ell_sk));

    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", ell_id.str()},
                 {"path_feature", path_fid.str()},
                 {"op", "fuse"},
                 {"target", rv_id.str()}};
    graph.add(std::move(sw));

    std::string err;
    const bool ok = graph.regenerate(doc, &err);
    INFO("err=" << err << " last=" << graph.last_error());
    REQUIRE(ok);
    const Body* body = doc.body(graph.feature(rv_id)->output_body);
    REQUIRE(body != nullptr);
    double bb[6] = {};
    bbox_xyz(body->shape, bb);
    INFO("xmax=" << bb[3] << " vol=" << shape::volume(body->shape));
    CHECK(bb[3] == Approx(192.1).margin(0.2));
    CHECK(shape::volume(body->shape) == Approx(1741298.0).epsilon(0.005));
    sx::test::TmpFile tmp("rung06_sweep.3mf");
    REQUIRE(interop::export_3mf(doc, tmp.path, &err));
}
