#include <catch.hpp>

#include <cmath>
#include <memory>
#include <string>
#include <utility>

#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <Bnd_Box.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <LocOpe_DPrism.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Cone.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

const double kPi = 3.14159265358979323846;
const double kDeg = kPi / 180.0;

EntityId add_sketch(FeatureGraph& g, std::shared_ptr<Sketch> sk) {
    Feature f;
    f.type = FeatureType::Sketch;
    f.sketch = std::move(sk);
    return g.add(std::move(f));
}

std::shared_ptr<Sketch> rect_xy(double w, double h) {
    auto sk = std::make_shared<Sketch>("Rect");
    sk->add_line(0, 0, w, 0);
    sk->add_line(w, 0, w, h);
    sk->add_line(w, h, 0, h);
    sk->add_line(0, h, 0, 0);
    return sk;
}

int count_type(const json& arr, const char* type) {
    int n = 0;
    for (const auto& e : arr)
        if (e.value("type", "") == type) ++n;
    return n;
}

double plane_to_dir_deg(const gp_Dir& n, const gp_Dir& d) {
    const double c = std::abs(n.Dot(d));
    const double s = std::sqrt(std::max(0.0, 1.0 - c * c));
    return std::atan2(c, s) / kDeg;  // 0 = wall contains d
}

}  // namespace

TEST_CASE("draft dprism: signed Height direction", "[exactness][draft]") {
    gp_Circ c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 15.0);
    TopoDS_Face f =
        BRepBuilderAPI_MakeFace(BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c).Edge()).Wire(),
                                true)
            .Face();
    const double ang = 15.0 * kDeg;
    const double h = 25.0 / std::cos(ang);
    auto zspan = [](const TopoDS_Shape& s) {
        Bnd_Box b;
        BRepBndLib::Add(s, b);
        double x0, y0, z0, x1, y1, z1;
        b.Get(x0, y0, z0, x1, y1, z1);
        return std::make_pair(z0, z1);
    };
    {
        LocOpe_DPrism mk(f, h, ang);
        REQUIRE(mk.IsDone());
        auto z = zspan(mk.Shape());
        CAPTURE(z.first, z.second, shape::volume(mk.Shape()));
        REQUIRE(z.second > 20.0);  // +Z
    }
    {
        LocOpe_DPrism mk(f, -h, -ang);
        REQUIRE(mk.IsDone());
        auto z = zspan(mk.Shape());
        const double vol = shape::volume(mk.Shape());
        CAPTURE(z.first, z.second, vol);
        REQUIRE(z.first < -20.0);  // -Z
        REQUIRE(std::abs(vol - 10954.475) / 10954.475 < 1e-6);
    }
}

TEST_CASE("draft dprism: 40x10 rect 5 deg inward sides", "[exactness][draft]") {
    Document doc;
    auto sid = add_sketch(doc.graph(), rect_xy(40.0, 10.0));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sid.str()},
                  {"distance", 10.0},
                  {"op", "new"},
                  {"end", "blind"},
                  {"draft_deg", 5.0},
                  {"draft_inward", true}};
    const auto eid = doc.graph().add(std::move(ext));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    INFO(err);
    const Body* b = doc.body(doc.graph().feature(eid)->output_body);
    REQUIRE(b != nullptr);

    const gp_Dir z(0, 0, 1);
    int side_count = 0;
    for (TopExp_Explorer fx(b->shape, TopAbs_FACE); fx.More(); fx.Next()) {
        const TopoDS_Face f = TopoDS::Face(fx.Current());
        BRepAdaptor_Surface surf(f);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (std::abs(n.Dot(z)) > 0.9) continue;  // top / bottom
        const double ang = plane_to_dir_deg(n, z);
        INFO("side angle " << ang);
        REQUIRE(ang == Approx(5.0).margin(1e-6));
        ++side_count;
    }
    REQUIRE(side_count == 4);

    json probe = exactness::probe_shape(b->shape);
    REQUIRE(probe["volume"].get<double>() < 40.0 * 10.0 * 10.0);
}

TEST_CASE("draft dprism: Ø6 hole stays a cone", "[exactness][draft]") {
    Document doc;
    auto sk = rect_xy(40.0, 10.0);
    sk->add_circle(20.0, 5.0, 3.0);
    auto sid = add_sketch(doc.graph(), sk);
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sid.str()},
                  {"distance", 10.0},
                  {"op", "new"},
                  {"end", "blind"},
                  {"draft_deg", 5.0},
                  {"draft_inward", true}};
    const auto eid = doc.graph().add(std::move(ext));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    INFO(err);
    const Body* b = doc.body(doc.graph().feature(eid)->output_body);
    REQUIRE(b != nullptr);

    json probe = exactness::probe_shape(b->shape);
    REQUIRE(count_type(probe["faces"], "GeomAbs_Cone") >= 1);
    bool cone_ok = false;
    for (const auto& f : probe["faces"]) {
        if (f.value("type", "") != "GeomAbs_Cone") continue;
        const double semi = std::abs(f["semi_angle"].get<double>()) / kDeg;
        INFO("cone semi_angle deg " << semi);
        if (std::abs(semi - 5.0) < 1e-6) cone_ok = true;
    }
    REQUIRE(cone_ok);
}

TEST_CASE("draft dprism: rung6 Ø30 15 deg cut volume and host diameter",
          "[exactness][draft][rung06]") {
    Document doc;
    FeatureGraph& graph = doc.graph();

    SketchPlane cyl_pl;
    cyl_pl.origin = {0, 180, 0};
    cyl_pl.x_dir = {1, 0, 0};
    cyl_pl.y_dir = {0, 0, -1};
    auto cyl_sk = std::make_shared<Sketch>("Cyl", cyl_pl);
    cyl_sk->add_circle(0.0, 0.0, 30.0);
    auto cyl_sid = add_sketch(graph, cyl_sk);

    Feature cyl;
    cyl.type = FeatureType::Extrude;
    cyl.params = {{"sketch", cyl_sid.str()},
                  {"distance", 40.0},
                  {"op", "new"},
                  {"end", "blind"}};
    const auto cyl_id = graph.add(std::move(cyl));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b0 = doc.body(graph.feature(cyl_id)->output_body);
    REQUIRE(b0 != nullptr);
    const double vol0 = shape::volume(b0->shape);

    SketchPlane hole_pl;
    hole_pl.origin = {0, 220, 0};
    hole_pl.x_dir = {1, 0, 0};
    hole_pl.y_dir = {0, 0, -1};
    auto hole_sk = std::make_shared<Sketch>("Hole", hole_pl);
    hole_sk->add_circle(0.0, 0.0, 15.0);
    auto hole_sid = add_sketch(graph, hole_sk);

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", hole_sid.str()},
                  {"distance", -25.0},
                  {"op", "cut"},
                  {"target", cyl_id.str()},
                  {"end", "blind"},
                  {"draft_deg", 15.0},
                  {"draft_inward", true}};
    graph.add(std::move(cut));
    err.clear();
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    const Body* b1 = doc.body(graph.feature(cyl_id)->output_body);
    REQUIRE(b1 != nullptr);

    const double r1 = 15.0;
    const double h = 25.0;
    const double r2 = r1 - h * std::tan(15.0 * kDeg);
    const double analytic = kPi * h / 3.0 * (r1 * r1 + r1 * r2 + r2 * r2);
    const double vol1 = shape::volume(b1->shape);
    const double drop = vol0 - vol1;
    CAPTURE(vol0, vol1, drop, analytic, drop / analytic);
    REQUIRE(std::abs(drop - analytic) / analytic < 1e-6);

    json probe = exactness::probe_shape(b1->shape);
    bool host_dia = false;
    for (const auto& e : probe["edges"]) {
        if (e.value("type", "") != "GeomAbs_Circle") continue;
        const double rad = e.value("radius", 0.0);
        const auto& loc = e["centre"];
        if (!loc.is_array() || loc.size() < 2) continue;
        if (std::abs(loc[1].get<double>() - 220.0) > 0.05) continue;
        INFO("host circle r=" << rad << " y=" << loc[1].get<double>());
        if (std::abs(rad - 15.0) < 1e-6) host_dia = true;
    }
    if (!host_dia) {
        // Fallback: sample the cone at the host plane.
        for (TopExp_Explorer fx(b1->shape, TopAbs_FACE); fx.More(); fx.Next()) {
            const TopoDS_Face f = TopoDS::Face(fx.Current());
            BRepAdaptor_Surface surf(f);
            if (surf.GetType() != GeomAbs_Cone) continue;
            const gp_Cone c = surf.Cone();
            const gp_Ax1 ax = c.Axis();
            const gp_Pnt apexish = c.Location();
            const gp_Vec along(ax.Direction());
            const double t = gp_Vec(apexish, gp_Pnt(0, 220, 0)).Dot(along);
            const double sa = c.SemiAngle();
            const double r = c.RefRadius() + t * std::tan(sa);
            INFO("cone r at y=220 " << std::abs(r) << " semi=" << sa);
            if (std::abs(std::abs(r) - 15.0) < 1e-6) host_dia = true;
        }
    }
    REQUIRE(host_dia);
}
