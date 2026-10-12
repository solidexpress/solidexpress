#include <catch.hpp>
#include <algorithm>
#include <cmath>
#include <utility>
#include <vector>

#include "sx/sketch.hpp"
#include "sx/sketch_tools.hpp"

using namespace sx;
using namespace sx::sketch_tools;

TEST_CASE("fillet_corner rounds a perpendicular L", "[sketchtools]") {
    Sketch sk("FilletL");
    auto la = sk.add_line(0, 0, 10, 0);
    auto lb = sk.add_line(10, 0, 10, 10);
    size_t n_before = sk.entities().size();

    std::string arc_id = fillet_corner(sk, la.str(), lb.str(), 3.0);
    REQUIRE_FALSE(arc_id.empty());
    REQUIRE(sk.entities().size() == n_before + 1);

    EntityId aid = EntityId::from_string(arc_id);
    const SketchEntity* arc = sk.entity(aid);
    REQUIRE(arc != nullptr);
    REQUIRE(arc->type == SketchEntityType::Arc);
    REQUIRE(sk.param(arc->params[2]) == Approx(3.0).margin(1e-9));

    // Trimmed ends are 3 units from the old corner (10, 0).
    auto a_end = *sk.point_pos({la, PointRole::End});
    auto b_start = *sk.point_pos({lb, PointRole::Start});
    REQUIRE(std::hypot(a_end[0] - 10.0, a_end[1] - 0.0) == Approx(3.0).margin(1e-9));
    REQUIRE(std::hypot(b_start[0] - 10.0, b_start[1] - 0.0) == Approx(3.0).margin(1e-9));

    auto arc_s = *sk.point_pos({aid, PointRole::Start});
    auto arc_e = *sk.point_pos({aid, PointRole::End});
    auto dist = [](std::array<double, 2> p, std::array<double, 2> q) {
        return std::hypot(p[0] - q[0], p[1] - q[1]);
    };
    bool match =
        (dist(arc_s, a_end) < 1e-9 && dist(arc_e, b_start) < 1e-9) ||
        (dist(arc_s, b_start) < 1e-9 && dist(arc_e, a_end) < 1e-9);
    REQUIRE(match);
}

TEST_CASE("fillet_corner fails when lines do not touch", "[sketchtools]") {
    Sketch sk("NoTouch");
    auto la = sk.add_line(0, 0, 10, 0);
    auto lb = sk.add_line(10, 1, 10, 10);
    size_t n_before = sk.entities().size();

    std::string arc_id = fillet_corner(sk, la.str(), lb.str(), 2.0);
    REQUIRE(arc_id.empty());
    REQUIRE(sk.entities().size() == n_before);
}

TEST_CASE("fillet_corner fails when radius exceeds segment", "[sketchtools]") {
    Sketch sk("BigR");
    auto la = sk.add_line(0, 0, 10, 0);
    auto lb = sk.add_line(10, 0, 10, 10);
    size_t n_before = sk.entities().size();

    std::string arc_id = fillet_corner(sk, la.str(), lb.str(), 12.0);
    REQUIRE(arc_id.empty());
    REQUIRE(sk.entities().size() == n_before);
}

TEST_CASE("offset_entities offsets a line by +2", "[sketchtools]") {
    Sketch sk("OffLine");
    auto la = sk.add_line(0, 0, 10, 0);
    auto ids = offset_entities(sk, {la.str()}, 2.0);
    REQUIRE(ids.size() == 1);

    EntityId nid = EntityId::from_string(ids[0]);
    const SketchEntity* ne = sk.entity(nid);
    REQUIRE(ne != nullptr);
    REQUIRE(ne->type == SketchEntityType::Line);

    // Original untouched; left of +X is +Y, so offset line at y=2.
    auto o0 = *sk.point_pos({la, PointRole::Start});
    auto o1 = *sk.point_pos({la, PointRole::End});
    REQUIRE(o0[0] == Approx(0.0));
    REQUIRE(o0[1] == Approx(0.0));
    REQUIRE(o1[0] == Approx(10.0));
    REQUIRE(o1[1] == Approx(0.0));

    auto n0 = *sk.point_pos({nid, PointRole::Start});
    auto n1 = *sk.point_pos({nid, PointRole::End});
    REQUIRE(n0[0] == Approx(0.0).margin(1e-9));
    REQUIRE(n0[1] == Approx(2.0).margin(1e-9));
    REQUIRE(n1[0] == Approx(10.0).margin(1e-9));
    REQUIRE(n1[1] == Approx(2.0).margin(1e-9));
    REQUIRE(std::hypot(n0[0] - o0[0], n0[1] - o0[1]) == Approx(2.0).margin(1e-9));
    REQUIRE(std::hypot(n1[0] - o1[0], n1[1] - o1[1]) == Approx(2.0).margin(1e-9));
}

TEST_CASE("offset_entities offsets circles with Concentric and Radius",
          "[sketchtools][rung03]") {
    Sketch sk("OffCirc");
    auto c = sk.add_circle(0, 0, 35);

    auto inward = offset_entities(sk, {c.str()}, -5.0);
    REQUIRE(inward.size() == 1);
    EntityId nid = EntityId::from_string(inward[0]);
    const SketchEntity* ne = sk.entity(nid);
    REQUIRE(ne->type == SketchEntityType::Circle);
    REQUIRE(sk.param(ne->params[0]) == Approx(0.0));
    REQUIRE(sk.param(ne->params[1]) == Approx(0.0));
    REQUIRE(sk.param(ne->params[2]) == Approx(30.0).margin(1e-9));
    REQUIRE(sk.param(sk.entity(c)->params[2]) == Approx(35.0));

    bool has_concentric = false;
    bool has_radius = false;
    for (const auto& con : sk.constraints()) {
        if (con.type == ConstraintType::Concentric && con.refs.size() >= 2) {
            if ((con.refs[0].entity == nid && con.refs[1].entity == c) ||
                (con.refs[1].entity == nid && con.refs[0].entity == c)) {
                has_concentric = true;
            }
        }
        if (con.type == ConstraintType::Radius && !con.refs.empty() &&
            con.refs[0].entity == nid && con.driving) {
            has_radius = std::abs(con.value - 30.0) < 1e-9;
        }
    }
    REQUIRE(has_concentric);
    REQUIRE(has_radius);

    auto outward = offset_entities(sk, {c.str()}, 5.0);
    REQUIRE(outward.size() == 1);
    EntityId oid = EntityId::from_string(outward[0]);
    REQUIRE(sk.param(sk.entity(oid)->params[2]) == Approx(40.0).margin(1e-9));

    size_t n_before = sk.entities().size();
    REQUIRE(offset_entities(sk, {c.str()}, -35.0).empty());
    REQUIRE(offset_entities(sk, {c.str()}, -40.0).empty());
    REQUIRE(offset_entities(sk, {c.str()}, 0.0).empty());
    REQUIRE(sk.entities().size() == n_before);
}

TEST_CASE("trim_entity shortens horizontal at cross near right end",
          "[sketchtools][trim]") {
    Sketch sk("TrimCross");
    auto h = sk.add_line(0, 0, 10, 0);
    auto v = sk.add_line(5, -5, 5, 5);
    size_t n_before = sk.entities().size();

    REQUIRE(trim_entity(sk, h.str(), 8.0, 0.0));
    REQUIRE(sk.entities().size() == n_before);
    REQUIRE(sk.entity(h) != nullptr);

    auto start = *sk.point_pos({h, PointRole::Start});
    auto end = *sk.point_pos({h, PointRole::End});
    REQUIRE(start[0] == Approx(0.0).margin(1e-9));
    REQUIRE(start[1] == Approx(0.0).margin(1e-9));
    REQUIRE(end[0] == Approx(5.0).margin(1e-9));
    REQUIRE(end[1] == Approx(0.0).margin(1e-9));
    // Vertical unchanged.
    auto vs = *sk.point_pos({v, PointRole::Start});
    REQUIRE(vs[0] == Approx(5.0));
}

TEST_CASE("trim_entity splits line crossed by two parallels",
          "[sketchtools][trim]") {
    Sketch sk("TrimMid");
    auto h = sk.add_line(0, 0, 10, 0);
    sk.add_line(3, -2, 3, 2);
    sk.add_line(7, -2, 7, 2);
    size_t n_before = sk.entities().size();

    REQUIRE(trim_entity(sk, h.str(), 5.0, 0.0));
    // Original removed, two remnants added → +1 entity.
    REQUIRE(sk.entities().size() == n_before + 1);
    REQUIRE(sk.entity(h) == nullptr);

    std::vector<const SketchEntity*> remnants;
    for (const auto& e : sk.entities()) {
        if (e.type == SketchEntityType::Line) {
            auto p0 = *sk.point_pos({e.id, PointRole::Start});
            auto p1 = *sk.point_pos({e.id, PointRole::End});
            // Horizontal remnants only (y≈0 both ends, length < 10).
            if (std::abs(p0[1]) < 1e-9 && std::abs(p1[1]) < 1e-9 &&
                std::abs(p1[0] - p0[0]) < 9.5)
                remnants.push_back(&e);
        }
    }
    REQUIRE(remnants.size() == 2);

    auto span_x = [&](const SketchEntity* e) {
        double x0 = sk.param(e->params[0]);
        double x1 = sk.param(e->params[2]);
        return std::make_pair(std::min(x0, x1), std::max(x0, x1));
    };
    auto a = span_x(remnants[0]);
    auto b = span_x(remnants[1]);
    // One segment [0,3], one [7,10]; gap between the parallels.
    bool gap_ok =
        (std::abs(a.first - 0.0) < 1e-9 && std::abs(a.second - 3.0) < 1e-9 &&
         std::abs(b.first - 7.0) < 1e-9 && std::abs(b.second - 10.0) < 1e-9) ||
        (std::abs(b.first - 0.0) < 1e-9 && std::abs(b.second - 3.0) < 1e-9 &&
         std::abs(a.first - 7.0) < 1e-9 && std::abs(a.second - 10.0) < 1e-9);
    REQUIRE(gap_ok);
}

TEST_CASE("trim_entity returns false with no intersections",
          "[sketchtools][trim]") {
    Sketch sk("TrimNone");
    auto h = sk.add_line(0, 0, 10, 0);
    sk.add_line(0, 5, 10, 5);  // parallel, no intersection
    size_t n_before = sk.entities().size();
    uint64_t rev = sk.revision();

    REQUIRE_FALSE(trim_entity(sk, h.str(), 5.0, 0.0));
    REQUIRE(sk.entities().size() == n_before);
    REQUIRE(sk.revision() == rev);
    auto s = *sk.point_pos({h, PointRole::Start});
    auto e = *sk.point_pos({h, PointRole::End});
    REQUIRE(s[0] == Approx(0.0));
    REQUIRE(e[0] == Approx(10.0));
}

TEST_CASE("trim_entity opens gap on line through circle", "[sketchtools][trim]") {
    Sketch sk("TrimLineCirc");
    auto h = sk.add_line(-10, 0, 10, 0);
    sk.add_circle(0, 0, 5);
    size_t n_before = sk.entities().size();

    // Pick inside the circle → remove middle chord between intersections.
    REQUIRE(trim_entity(sk, h.str(), 0.0, 0.0));
    REQUIRE(sk.entities().size() == n_before + 1);
    REQUIRE(sk.entity(h) == nullptr);

    std::vector<std::pair<double, double>> segs;
    for (const auto& e : sk.entities()) {
        if (e.type != SketchEntityType::Line) continue;
        double x0 = sk.param(e.params[0]);
        double y0 = sk.param(e.params[1]);
        double x1 = sk.param(e.params[2]);
        double y1 = sk.param(e.params[3]);
        if (std::abs(y0) > 1e-6 || std::abs(y1) > 1e-6) continue;
        segs.push_back(std::minmax(x0, x1));
    }
    REQUIRE(segs.size() == 2);
    std::sort(segs.begin(), segs.end());
    REQUIRE(segs[0].first == Approx(-10.0).margin(1e-9));
    REQUIRE(segs[0].second == Approx(-5.0).margin(1e-9));
    REQUIRE(segs[1].first == Approx(5.0).margin(1e-9));
    REQUIRE(segs[1].second == Approx(10.0).margin(1e-9));
}

TEST_CASE("trim_entity replaces circle with remaining arc",
          "[sketchtools][trim]") {
    Sketch sk("TrimCirc");
    auto c = sk.add_circle(0, 0, 5);
    // Two vertical chords → four intersections; pick near +X (angle 0).
    sk.add_line(-2, -10, -2, 10);
    sk.add_line(2, -10, 2, 10);
    size_t n_before = sk.entities().size();

    REQUIRE(trim_entity(sk, c.str(), 5.0, 0.0));
    REQUIRE(sk.entities().size() == n_before);  // circle → arc (same count)
    REQUIRE(sk.entity(c) == nullptr);

    const SketchEntity* arc = nullptr;
    for (const auto& e : sk.entities()) {
        if (e.type == SketchEntityType::Arc) {
            arc = &e;
            break;
        }
    }
    REQUIRE(arc != nullptr);
    REQUIRE(sk.param(arc->params[0]) == Approx(0.0).margin(1e-9));
    REQUIRE(sk.param(arc->params[1]) == Approx(0.0).margin(1e-9));
    REQUIRE(sk.param(arc->params[2]) == Approx(5.0).margin(1e-9));

    // Removed the short east arc between the two +X-side hits; remaining is long.
    double sa = sk.param(arc->params[3]);
    double ea = sk.param(arc->params[4]);
    double sweep = ea - sa;
    while (sweep < 0) sweep += 2.0 * 3.14159265358979323846;
    REQUIRE(sweep > 3.14159265358979323846);  // more than half remains
}

TEST_CASE("extend_entity lengthens line to perpendicular ahead",
          "[sketchtools][extend]") {
    Sketch sk("ExtAhead");
    auto h = sk.add_line(0, 0, 5, 0);
    sk.add_line(10, -5, 10, 5);
    size_t n_before = sk.entities().size();

    REQUIRE(extend_entity(sk, h.str(), 4.5, 0.0));
    REQUIRE(sk.entities().size() == n_before);
    REQUIRE(sk.entity(h) != nullptr);

    auto start = *sk.point_pos({h, PointRole::Start});
    auto end = *sk.point_pos({h, PointRole::End});
    REQUIRE(start[0] == Approx(0.0).margin(1e-9));
    REQUIRE(start[1] == Approx(0.0).margin(1e-9));
    REQUIRE(end[0] == Approx(10.0).margin(1e-9));
    REQUIRE(end[1] == Approx(0.0).margin(1e-9));
}

TEST_CASE("extend_entity returns false with nothing ahead",
          "[sketchtools][extend]") {
    Sketch sk("ExtNone");
    auto h = sk.add_line(0, 0, 5, 0);
    sk.add_line(0, 5, 10, 5);  // parallel, no intersection
    size_t n_before = sk.entities().size();
    uint64_t rev = sk.revision();

    REQUIRE_FALSE(extend_entity(sk, h.str(), 4.5, 0.0));
    REQUIRE(sk.entities().size() == n_before);
    REQUIRE(sk.revision() == rev);
    auto s = *sk.point_pos({h, PointRole::Start});
    auto e = *sk.point_pos({h, PointRole::End});
    REQUIRE(s[0] == Approx(0.0));
    REQUIRE(e[0] == Approx(5.0));
}

TEST_CASE("extend_entity picks nearest endpoint (extends start)",
          "[sketchtools][extend]") {
    Sketch sk("ExtStart");
    auto h = sk.add_line(5, 0, 10, 0);
    sk.add_line(0, -5, 0, 5);  // ahead of the start end
    size_t n_before = sk.entities().size();

    // Pick near start → extend start leftward to x=0.
    REQUIRE(extend_entity(sk, h.str(), 5.2, 0.0));
    REQUIRE(sk.entities().size() == n_before);
    REQUIRE(sk.entity(h) != nullptr);

    auto start = *sk.point_pos({h, PointRole::Start});
    auto end = *sk.point_pos({h, PointRole::End});
    REQUIRE(start[0] == Approx(0.0).margin(1e-9));
    REQUIRE(start[1] == Approx(0.0).margin(1e-9));
    REQUIRE(end[0] == Approx(10.0).margin(1e-9));
    REQUIRE(end[1] == Approx(0.0).margin(1e-9));
}

TEST_CASE("pattern_entities copies line with dx=15 count=3",
          "[sketchtools][skpattern]") {
    Sketch sk("PatLine");
    auto la = sk.add_line(0, 0, 10, 0);
    size_t n_before = sk.entities().size();

    auto ids = pattern_entities(sk, {la.str()}, 15.0, 0.0, 3);
    REQUIRE(ids.size() == 2);
    REQUIRE(sk.entities().size() == n_before + 2);

    // Original untouched.
    auto o0 = *sk.point_pos({la, PointRole::Start});
    auto o1 = *sk.point_pos({la, PointRole::End});
    REQUIRE(o0[0] == Approx(0.0));
    REQUIRE(o0[1] == Approx(0.0));
    REQUIRE(o1[0] == Approx(10.0));
    REQUIRE(o1[1] == Approx(0.0));

    EntityId c1 = EntityId::from_string(ids[0]);
    EntityId c2 = EntityId::from_string(ids[1]);
    auto a0 = *sk.point_pos({c1, PointRole::Start});
    auto a1 = *sk.point_pos({c1, PointRole::End});
    REQUIRE(a0[0] == Approx(15.0).margin(1e-9));
    REQUIRE(a0[1] == Approx(0.0).margin(1e-9));
    REQUIRE(a1[0] == Approx(25.0).margin(1e-9));
    REQUIRE(a1[1] == Approx(0.0).margin(1e-9));

    auto b0 = *sk.point_pos({c2, PointRole::Start});
    auto b1 = *sk.point_pos({c2, PointRole::End});
    REQUIRE(b0[0] == Approx(30.0).margin(1e-9));
    REQUIRE(b0[1] == Approx(0.0).margin(1e-9));
    REQUIRE(b1[0] == Approx(40.0).margin(1e-9));
    REQUIRE(b1[1] == Approx(0.0).margin(1e-9));
}

TEST_CASE("pattern_entities copies circle with dy=10 count=2",
          "[sketchtools][skpattern]") {
    Sketch sk("PatCirc");
    auto c = sk.add_circle(1, 2, 5);
    size_t n_before = sk.entities().size();

    auto ids = pattern_entities(sk, {c.str()}, 0.0, 10.0, 2);
    REQUIRE(ids.size() == 1);
    REQUIRE(sk.entities().size() == n_before + 1);

    REQUIRE(sk.param(sk.entity(c)->params[0]) == Approx(1.0));
    REQUIRE(sk.param(sk.entity(c)->params[1]) == Approx(2.0));
    REQUIRE(sk.param(sk.entity(c)->params[2]) == Approx(5.0));

    EntityId nid = EntityId::from_string(ids[0]);
    const SketchEntity* ne = sk.entity(nid);
    REQUIRE(ne != nullptr);
    REQUIRE(ne->type == SketchEntityType::Circle);
    REQUIRE(sk.param(ne->params[0]) == Approx(1.0).margin(1e-9));
    REQUIRE(sk.param(ne->params[1]) == Approx(12.0).margin(1e-9));
    REQUIRE(sk.param(ne->params[2]) == Approx(5.0).margin(1e-9));
}

TEST_CASE("pattern_entities count=1 leaves sketch unchanged",
          "[sketchtools][skpattern]") {
    Sketch sk("PatOne");
    auto la = sk.add_line(0, 0, 10, 0);
    size_t n_before = sk.entities().size();
    uint64_t rev = sk.revision();

    auto ids = pattern_entities(sk, {la.str()}, 15.0, 0.0, 1);
    REQUIRE(ids.empty());
    REQUIRE(sk.entities().size() == n_before);
    REQUIRE(sk.revision() == rev);
}

TEST_CASE("pattern_entities propagates construction flag",
          "[sketchtools][skpattern]") {
    Sketch sk("PatConstr");
    auto la = sk.add_line(0, 0, 5, 0);
    sk.set_construction(la, true);

    auto ids = pattern_entities(sk, {la.str()}, 10.0, 0.0, 2);
    REQUIRE(ids.size() == 1);
    EntityId nid = EntityId::from_string(ids[0]);
    REQUIRE(sk.is_construction(nid));
    REQUIRE(sk.entity(nid)->type == SketchEntityType::Line);
}
