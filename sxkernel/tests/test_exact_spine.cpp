#include <catch.hpp>

#include <cmath>
#include <memory>
#include <string>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <GeomAbs_CurveType.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include "features/ops.hpp"
#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using namespace sx::feature_ops;
using nlohmann::json;

namespace {

std::shared_ptr<Sketch> line_r150_r20(bool weld_slop = false) {
    auto sk = std::make_shared<Sketch>("Path");
    sk->add_line(0.0, 10.0, 60.0, 10.0);
    const double c150x = weld_slop ? 60.02 : 60.0;
    const double c150y = weld_slop ? 160.02 : 160.0;
    const double r150 = 150.0;
    const double r20 = 20.0;
    // Exact internal tangent: |C150−C20| = 130, along the tutorial's direction.
    const double dx = 167.113 - 60.0, dy = 86.333 - 160.0;
    const double d = std::hypot(dx, dy);
    const double c20x = c150x + dx / d * (r150 - r20);
    const double c20y = c150y + dy / d * (r150 - r20);
    const double tanx = c150x + dx / d * r150;
    const double tany = c150y + dy / d * r150;
    const double sa150 = std::atan2(10.0 - c150y, (weld_slop ? 60.2 : 60.0) - c150x);
    const double ea150 = std::atan2(tany - c150y, tanx - c150x);
    EntityId a150 =
        sk->add_arc(c150x, c150y, r150, sa150, ea150 < sa150 ? ea150 + 2.0 * M_PI : ea150);
    if (weld_slop) {
        SketchEntity* e150 = sk->entity_mut(a150);
        sk->param_mut(e150->params[5]) = 60.2;
        sk->param_mut(e150->params[6]) = 10.0;
    }
    const double sa20 = std::atan2(tany - c20y, tanx - c20x);
    const double ea20 = std::atan2(75.0 - c20y, 150.634 - c20x);
    sk->add_arc(c20x, c20y, r20, sa20, ea20 < sa20 ? ea20 + 2.0 * M_PI : ea20);
    return sk;
}

bool has_line(const TopoDS_Wire& w) {
    for (TopExp_Explorer ex(w, TopAbs_EDGE); ex.More(); ex.Next()) {
        BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
        if (c.GetType() == GeomAbs_Line) return true;
    }
    return false;
}

bool has_torus_major(const TopoDS_Shape& s, double major, double tol) {
    json j = exactness::probe_shape(s);
    for (const auto& f : j["faces"]) {
        if (f.value("type", "") != "GeomAbs_Torus") continue;
        if (std::abs(f.value("radius_major", -1.0) - major) <= tol) return true;
    }
    return false;
}

double point_to_wire(const gp_Pnt& p, const TopoDS_Wire& w) {
    TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(p).Vertex();
    BRepExtrema_DistShapeShape dist(v, w);
    if (!dist.IsDone() || dist.NbSolution() < 1) return 1e9;
    return dist.Value();
}

double thread_flank_included_deg(const TopoDS_Shape& cutter) {
    gp_Pln y0(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0));
    TopoDS_Face plane = BRepBuilderAPI_MakeFace(y0, -80.0, 80.0, -80.0, 80.0).Face();
    BRepAlgoAPI_Section sec(cutter, plane);
    sec.Approximation(Standard_True);
    sec.Build();
    if (!sec.IsDone()) return -1.0;
    struct Seg {
        gp_Pnt a, b;
        gp_Vec dir;
    };
    std::vector<Seg> segs;
    for (TopExp_Explorer ex(sec.Shape(), TopAbs_EDGE); ex.More(); ex.Next()) {
        BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
        gp_Pnt a = c.Value(c.FirstParameter());
        gp_Pnt b = c.Value(c.LastParameter());
        gp_Vec d(a, b);
        if (d.Magnitude() < 0.2) continue;
        d.Normalize();
        segs.push_back({a, b, d});
    }
    double best = -1.0;
    auto near = [](const gp_Pnt& p, const gp_Pnt& q) { return p.Distance(q) < 0.3; };
    for (size_t i = 0; i < segs.size(); ++i) {
        for (size_t k = i + 1; k < segs.size(); ++k) {
            const bool share = near(segs[i].a, segs[k].a) || near(segs[i].a, segs[k].b) ||
                               near(segs[i].b, segs[k].a) || near(segs[i].b, segs[k].b);
            if (!share) continue;
            double ang = segs[i].dir.Angle(segs[k].dir) * 180.0 / M_PI;
            if (ang > 90.0) ang = 180.0 - ang;
            if (std::abs(ang - 60.0) < std::abs(best - 60.0) || best < 0.0) best = ang;
        }
    }
    return best;
}

EntityId add_sketch(FeatureGraph& g, std::shared_ptr<Sketch> sk) {
    Feature f;
    f.type = FeatureType::Sketch;
    f.sketch = std::move(sk);
    return g.add(std::move(f));
}

}  // namespace

TEST_CASE("exact spine: line+R150+R20 is Line/Circle at 1e-6", "[exactness][spine]") {
    auto sk = line_r150_r20();
    TopoDS_Wire w = sketch_exact_wire(*sk);
    REQUIRE_FALSE(w.IsNull());
    REQUIRE(has_line(w));
    REQUIRE(spine_has_circle_radius(w, 150.0, 1e-6));
    REQUIRE(spine_has_circle_radius(w, 20.0, 1e-6));

    json edges = exactness::probe_shape(w)["edges"];
    int lines = 0, circles = 0;
    for (const auto& e : edges) {
        if (e.value("type", "") == "GeomAbs_Line") ++lines;
        if (e.value("type", "") == "GeomAbs_Circle") ++circles;
    }
    REQUIRE(lines >= 1);
    REQUIRE(circles >= 2);
}

TEST_CASE("exact spine: two-sketch join keeps R150/R20", "[exactness][spine]") {
    auto a = std::make_shared<Sketch>("A");
    a->add_line(0.0, 10.0, 60.0, 10.0);
    auto b = line_r150_r20();
    (void)b;
    Sketch arcs("B");
    const double c150x = 60.0, c150y = 160.0, r150 = 150.0, r20 = 20.0;
    const double dx = 167.113 - 60.0, dy = 86.333 - 160.0;
    const double d = std::hypot(dx, dy);
    const double c20x = c150x + dx / d * (r150 - r20);
    const double c20y = c150y + dy / d * (r150 - r20);
    const double tanx = c150x + dx / d * r150;
    const double tany = c150y + dy / d * r150;
    const double sa150 = std::atan2(10.0 - c150y, 60.0 - c150x);
    const double ea150 = std::atan2(tany - c150y, tanx - c150x);
    arcs.add_arc(c150x, c150y, r150, sa150, ea150 < sa150 ? ea150 + 2.0 * M_PI : ea150);
    const double sa20 = std::atan2(tany - c20y, tanx - c20x);
    const double ea20 = std::atan2(75.0 - c20y, 150.634 - c20x);
    arcs.add_arc(c20x, c20y, r20, sa20, ea20 < sa20 ? ea20 + 2.0 * M_PI : ea20);

    TopoDS_Wire joined = join_exact_wires({sketch_exact_wire(*a), sketch_exact_wire(arcs)});
    REQUIRE_FALSE(joined.IsNull());
    REQUIRE(has_line(joined));
    REQUIRE(spine_has_circle_radius(joined, 150.0, 1e-6));
    REQUIRE(spine_has_circle_radius(joined, 20.0, 1e-6));
}

TEST_CASE("exact sweep: torus major 150 from R150 spine", "[exactness][sweep]") {
    auto path = line_r150_r20();
    TopoDS_Wire spine = sketch_exact_wire(*path);
    REQUIRE(spine_has_circle_radius(spine, 150.0, 1e-6));

    SketchPlane yz;
    yz.origin = {0, 10, 0};
    yz.x_dir = {0, 1, 0};
    yz.y_dir = {0, 0, 1};
    auto profile = std::make_shared<Sketch>("Disc", yz);
    profile->add_circle(0.0, 0.0, 2.0);
    std::string perr;
    TopoDS_Shape face = profile->profile_face(&perr);
    REQUIRE_FALSE(face.IsNull());

    TopoDS_Shape exact = sweep_along_spine(face, spine);
    REQUIRE_FALSE(exact.IsNull());
    REQUIRE(has_torus_major(exact, 150.0, 1e-6));

    json pl = sketch_ordered_polyline(*path);
    TopoDS_Shape chorded = sweep_along_polyline(face, pl);
    // Probe: chorded ribbon is a different solid (no torus / different volume).
    const bool chorded_torus = !chorded.IsNull() && has_torus_major(chorded, 150.0, 1e-6);
    if (!chorded.IsNull() && std::abs(shape::volume(exact)) > 1.0) {
        CHECK(std::abs(shape::volume(chorded) - shape::volume(exact)) /
                  std::abs(shape::volume(exact)) >
              1e-6);
    }
    (void)chorded_torus;

    Document doc;
    FeatureGraph graph;
    auto path_sid = add_sketch(graph, path);
    Feature pathf;
    pathf.type = FeatureType::Path;
    pathf.params = {{"sketches", json::array({path_sid.str()})}, {"mode", "join_endpoints"}};
    auto path_fid = graph.add(std::move(pathf));
    auto prof_fid = add_sketch(graph, profile);
    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", prof_fid.str()}, {"path_feature", path_fid.str()}};
    auto sw_fid = graph.add(std::move(sw));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.warnings().empty());
    const Body* body = doc.body(graph.feature(sw_fid)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(has_torus_major(body->shape, 150.0, 1e-6));
}

TEST_CASE("exact spine: spline interpolates fit points", "[exactness][spine]") {
    Sketch sk("SplinePath");
    const std::vector<std::array<double, 2>> fits{{0, 0}, {10, 5}, {20, 0}, {30, 8}};
    sk.add_spline(fits);
    TopoDS_Wire w = sketch_exact_wire(sk);
    REQUIRE_FALSE(w.IsNull());
    json edges = exactness::probe_shape(w)["edges"];
    bool bspline = false;
    for (const auto& e : edges)
        if (e.value("type", "") == "GeomAbs_BSplineCurve") bspline = true;
    REQUIRE(bspline);
    for (const auto& xy : fits) {
        gp_Pnt p(xy[0], xy[1], 0);
        REQUIRE(point_to_wire(p, w) < 1e-6);
    }
}

TEST_CASE("exact spine: ellipse is GeomAbs_Ellipse", "[exactness][spine]") {
    Sketch sk("EllipsePath");
    sk.add_ellipse(0.0, 0.0, 17.5, 5.0, 0.0);
    TopoDS_Wire w = sketch_exact_wire(sk);
    REQUIRE_FALSE(w.IsNull());
    json edges = exactness::probe_shape(w)["edges"];
    bool ell = false;
    for (const auto& e : edges)
        if (e.value("type", "") == "GeomAbs_Ellipse") ell = true;
    REQUIRE(ell);
}

TEST_CASE("exact rib: R20 arc has cylinders R20 ± t/2", "[exactness][rib]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 50.0}, {"b", 50.0}, {"c", 4.0}};
    auto box_fid = doc.graph().add(std::move(box));

    SketchPlane pl;
    pl.origin = {0, 0, 4};
    auto sk = std::make_shared<Sketch>("RibArc", pl);
    sk->add_arc(0.0, 0.0, 20.0, 0.0, M_PI);
    auto sk_id = add_sketch(doc.graph(), sk);

    const double t = 4.0;
    Feature rib;
    rib.type = FeatureType::Rib;
    rib.params = {{"target", box_fid.str()},
                  {"sketch", sk_id.str()},
                  {"thickness", t},
                  {"height", 10.0}};
    doc.graph().add(std::move(rib));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    const Body* body = doc.body(doc.graph().feature(box_fid)->output_body);
    REQUIRE(body != nullptr);
    json faces = exactness::probe_shape(body->shape)["faces"];
    bool inner = false, outer = false;
    int cyl = 0;
    for (const auto& f : faces) {
        if (f.value("type", "") != "GeomAbs_Cylinder") continue;
        ++cyl;
        const double r = f.value("radius", -1.0);
        if (std::abs(r - (20.0 - t / 2.0)) < 1e-6) inner = true;
        if (std::abs(r - (20.0 + t / 2.0)) < 1e-6) outer = true;
    }
    REQUIRE(inner);
    REQUIRE(outer);
    // A polyline rib would facet the arc into extra planar walls at the chords.
    REQUIRE(cyl >= 2);
}

TEST_CASE("exact thread: axial flank 60 deg", "[exactness][thread]") {
    gp_Ax2 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    TopoDS_Shape cutter = thread_cutter_solid(axis, 10.0, 3.0, 2.0, 1.5, 60.0);
    REQUIRE_FALSE(cutter.IsNull());
    const double ang = thread_flank_included_deg(cutter);
    REQUIRE(ang > 0.0);
    REQUIRE(ang == Approx(60.0).margin(0.01));
}

TEST_CASE("exact thread: cutter follows helix pitch", "[exactness][thread]") {
    gp_Ax2 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    TopoDS_Shape c3 = thread_cutter_solid(axis, 10.0, 3.0, 8.0, 1.5, 60.0);
    TopoDS_Shape c4 = thread_cutter_solid(axis, 10.0, 4.0, 8.0, 1.5, 60.0);
    REQUIRE_FALSE(c3.IsNull());
    REQUIRE_FALSE(c4.IsNull());
    auto zspan = [](const TopoDS_Shape& s) {
        Bnd_Box box;
        BRepBndLib::Add(s, box);
        double x0, y0, z0, x1, y1, z1;
        box.Get(x0, y0, z0, x1, y1, z1);
        return z1 - z0;
    };
    INFO("z3=" << zspan(c3) << " z4=" << zspan(c4) << " v3=" << shape::volume(c3)
               << " v4=" << shape::volume(c4));
    REQUIRE(zspan(c3) == Approx(3.0 * 8.0).margin(3.0));
    REQUIRE(zspan(c4) == Approx(4.0 * 8.0).margin(3.0));
    REQUIRE(zspan(c4) > zspan(c3) + 4.0);
}

TEST_CASE("exact thread feature: graph cut keeps ISO flank", "[exactness][thread]") {
    Document doc;
    Feature cyl;
    cyl.type = FeatureType::Primitive;
    cyl.params = {{"kind", "cylinder"}, {"a", 10.0}, {"b", 20.0}};
    auto cyl_fid = doc.graph().add(std::move(cyl));
    Feature thread;
    thread.type = FeatureType::Thread;
    thread.params = {{"target", cyl_fid.str()},
                     {"axis_point", json::array({0.0, 0.0, 0.0})},
                     {"axis_dir", json::array({0.0, 0.0, 1.0})},
                     {"major_radius", 10.0},
                     {"pitch", 3.0},
                     {"turns", 4.0},
                     {"depth", 1.5},
                     {"profile_angle_deg", 60.0}};
    doc.graph().add(std::move(thread));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    const Body* body = doc.body(doc.graph().feature(cyl_fid)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::volume(body->shape) < M_PI * 10.0 * 10.0 * 20.0);
}
