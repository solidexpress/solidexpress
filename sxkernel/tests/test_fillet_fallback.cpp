#include <catch.hpp>

#include <array>
#include <cmath>
#include <string>
#include <vector>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/ids.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch_tools.hpp"

using namespace sx;
using nlohmann::json;

namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr double kDeg = 17.0 * kPi / 180.0;

std::array<double, 2> world(double xp, double yp) {
    return {xp * std::cos(kDeg) - yp * std::sin(kDeg),
            xp * std::sin(kDeg) + yp * std::cos(kDeg)};
}

void add_c_profile(Sketch& sk) {
    const double xj = -25.0 * std::sqrt(1.0 - (12.5 / 27.5) * (12.5 / 27.5));
    auto ell = sk.add_ellipse(0.0, 0.0, 27.5, 25.0, kDeg + kPi * 0.5);
    auto o_hi = world(xj, 12.5);
    auto o_lo = world(xj, -12.5);
    auto i_hi = world(xj + 20.0, 12.5);
    auto i_lo = world(xj + 20.0, -12.5);
    sk.add_line(o_hi[0], o_hi[1], i_hi[0], i_hi[1]);
    sk.add_line(o_lo[0], o_lo[1], i_lo[0], i_lo[1]);
    const double cx_local = (xj + 20.0) - std::sqrt(15.0 * 15.0 - 12.5 * 12.5);
    auto c15 = world(cx_local, 0.0);
    auto throat = world(cx_local + 15.0, 0.0);
    double sa = std::atan2(i_lo[1] - c15[1], i_lo[0] - c15[0]);
    double ea = std::atan2(i_hi[1] - c15[1], i_hi[0] - c15[0]);
    if (ea < sa) ea += 2.0 * kPi;
    double mid = std::atan2(throat[1] - c15[1], throat[0] - c15[0]);
    double from = mid - sa;
    while (from < 0) from += 2.0 * kPi;
    if (from > ea - sa + 1e-9) {
        std::swap(sa, ea);
        if (ea < sa) ea += 2.0 * kPi;
    }
    sk.add_arc(c15[0], c15[1], 15.0, sa, ea);
    auto pick = world(-25.0, 0.0);
    REQUIRE(sketch_tools::trim_entity(sk, ell.str(), pick[0], pick[1]));
}

gp_Pnt edge_mid(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.CentreOfMass();
}

double edge_len(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.Mass();
}

}  // namespace

TEST_CASE("fillet wedge refused on cylindrical hole walls", "[exactness][fillet]") {
    Document doc;
    EntityId box_fid;
    EntityId body = exactness::add_box_hole(doc, 20.0, 20.0, 10.0, 10.0, &box_fid, nullptr);
    const Body* b = doc.body(body);
    REQUIRE(b != nullptr);

    json circles = json::array();
    for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        json e = exactness::probe_edge(TopoDS::Edge(s));
        if (e.value("type", "") == "GeomAbs_Circle") circles.push_back(eid.str());
    }
    REQUIRE_FALSE(circles.empty());

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.name = "fillet 1";
    fil.params = {{"target", box_fid.str()}, {"radius", 20.0}, {"edges", circles}};
    doc.graph().add(std::move(fil));
    std::string err;
    const bool ok = doc.graph().regenerate(doc, &err);
    INFO(err);
    bool refused = false;
    for (const auto& w : doc.graph().warnings())
        if (w.second.find("walls not planar") != std::string::npos) refused = true;
    REQUIRE((!ok || refused));
}

TEST_CASE("fillet wedge recovers R30 on elliptical C neck", "[exactness][fillet][rung07]") {
    Document doc;
    FeatureGraph& g = doc.graph();

    Feature csk;
    csk.type = FeatureType::Sketch;
    csk.sketch = std::make_shared<Sketch>("C");
    add_c_profile(*csk.sketch);
    auto csk_id = g.add(std::move(csk));
    Feature cext;
    cext.type = FeatureType::Extrude;
    cext.params = {{"sketch", csk_id.str()},
                   {"distance", 10.0},
                   {"op", "new"},
                   {"end", "midplane"}};
    auto cext_id = g.add(std::move(cext));

    Feature hsk;
    hsk.type = FeatureType::Sketch;
    hsk.sketch = std::make_shared<Sketch>("Handle");
    hsk.sketch->add_line(22.0, 10.0, 80.0, 10.0);
    hsk.sketch->add_line(80.0, 10.0, 80.0, -10.0);
    hsk.sketch->add_line(80.0, -10.0, 22.0, -10.0);
    hsk.sketch->add_line(22.0, -10.0, 22.0, 10.0);
    auto hsk_id = g.add(std::move(hsk));
    Feature hext;
    hext.type = FeatureType::Extrude;
    hext.params = {{"sketch", hsk_id.str()},
                   {"distance", 6.0},
                   {"op", "fuse"},
                   {"end", "midplane"},
                   {"target", cext_id.str()}};
    g.add(std::move(hext));

    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* body = doc.body(g.feature(cext_id)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::is_valid(body->shape));
    const double v0 = shape::volume(body->shape);

    json necks = json::array();
    for (const auto& eid : body->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge e = TopoDS::Edge(s);
        if (std::abs(edge_len(e) - 6.0) > 0.6) continue;
        const gp_Pnt m = edge_mid(e);
        if (std::abs(m.Y() - 10.0) <= 0.6 || std::abs(m.Y() + 10.0) <= 0.6) {
            if (m.X() > 15.0 && m.X() < 35.0) necks.push_back(eid.str());
        }
    }
    REQUIRE(necks.size() >= 2);

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.name = "fillet R30";
    fil.params = {{"target", cext_id.str()}, {"radius", 30.0}, {"edges", necks}};
    g.add(std::move(fil));
    err.clear();
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* after = doc.body(g.feature(cext_id)->output_body);
    REQUIRE(after != nullptr);
    REQUIRE(shape::is_valid(after->shape));
    REQUIRE(shape::count(after->shape).solids == 1);
    CHECK(std::abs(shape::volume(after->shape) - v0) > 1.0);
}

void add_twelve_point(Sketch& sk, double cx, double cy, double af) {
    const double outer = af / std::sqrt(3.0);
    const double inner = (af * 0.5) / std::cos(15.0 * kPi / 180.0);
    std::array<std::array<double, 2>, 24> pts{};
    for (int k = 0; k < 24; ++k) {
        const double ang = static_cast<double>(k) * 15.0 * kPi / 180.0;
        const double radius = (k % 2) == 0 ? outer : inner;
        pts[static_cast<size_t>(k)] = {cx + std::cos(ang) * radius, cy + std::sin(ang) * radius};
    }
    for (int i = 0; i < 24; ++i) {
        const auto& a = pts[static_cast<size_t>(i)];
        const auto& b = pts[static_cast<size_t>((i + 23) % 24)];
        sk.add_line(a[0], a[1], b[0], b[1]);
    }
}

TEST_CASE("fillet R20 on 12-point ring neck stays valid", "[exactness][fillet][rung07]") {
    Document doc;
    FeatureGraph& g = doc.graph();

    Feature rsk;
    rsk.type = FeatureType::Sketch;
    rsk.sketch = std::make_shared<Sketch>("Ring");
    rsk.sketch->add_circle(240.0, 0.0, 16.5);
    add_twelve_point(*rsk.sketch, 240.0, 0.0, 25.0);
    auto rsk_id = g.add(std::move(rsk));
    Feature rext;
    rext.type = FeatureType::Extrude;
    rext.params = {{"sketch", rsk_id.str()},
                   {"distance", 10.0},
                   {"op", "new"},
                   {"end", "midplane"}};
    auto rext_id = g.add(std::move(rext));

    Feature hsk;
    hsk.type = FeatureType::Sketch;
    hsk.sketch = std::make_shared<Sketch>("Handle");
    hsk.sketch->add_line(80.0, 10.0, 226.876, 10.0);
    hsk.sketch->add_line(226.876, 10.0, 226.876, -10.0);
    hsk.sketch->add_line(226.876, -10.0, 80.0, -10.0);
    hsk.sketch->add_line(80.0, -10.0, 80.0, 10.0);
    auto hsk_id = g.add(std::move(hsk));
    Feature hext;
    hext.type = FeatureType::Extrude;
    hext.params = {{"sketch", hsk_id.str()},
                   {"distance", 6.0},
                   {"op", "fuse"},
                   {"end", "midplane"},
                   {"target", rext_id.str()}};
    g.add(std::move(hext));

    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* body = doc.body(g.feature(rext_id)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::is_valid(body->shape));

    json necks = json::array();
    for (const auto& eid : body->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge e = TopoDS::Edge(s);
        if (std::abs(edge_len(e) - 6.0) > 0.6) continue;
        const gp_Pnt m = edge_mid(e);
        if (std::abs(std::abs(m.Y()) - 10.0) > 0.6) continue;
        if (m.X() > 220.0 && m.X() < 232.0) necks.push_back(eid.str());
    }
    REQUIRE(necks.size() >= 2);

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.name = "fillet R20";
    fil.params = {{"target", rext_id.str()}, {"radius", 20.0}, {"edges", necks}};
    g.add(std::move(fil));
    err.clear();
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* after = doc.body(g.feature(rext_id)->output_body);
    REQUIRE(after != nullptr);
    REQUIRE(shape::is_valid(after->shape));
    REQUIRE(shape::count(after->shape).solids == 1);
}
