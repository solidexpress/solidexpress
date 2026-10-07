#include <catch.hpp>
#include <cmath>

#include <BRepClass_FaceClassifier.hxx>
#include <TopAbs_State.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Pnt.hxx>

#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/solver.hpp"

using namespace sx;

TEST_CASE("sketch entities store and expose parameters", "[sketch]") {
    Sketch sk("Test");
    auto line = sk.add_line(0, 0, 10, 0);
    auto circle = sk.add_circle(5, 5, 2);

    const SketchEntity* le = sk.entity(line);
    REQUIRE(le != nullptr);
    REQUIRE(le->type == SketchEntityType::Line);
    auto start = sk.point_pos({line, PointRole::Start});
    auto end = sk.point_pos({line, PointRole::End});
    REQUIRE(start.has_value());
    REQUIRE((*start)[0] == Approx(0.0));
    REQUIRE((*end)[0] == Approx(10.0));

    auto center = sk.point_pos({circle, PointRole::Center});
    REQUIRE((*center)[0] == Approx(5.0));
    REQUIRE((*center)[1] == Approx(5.0));
}

TEST_CASE("planegcs solves a dimensioned rectangle", "[sketch][solver]") {
    // Four lines, roughly rectangular but sloppy; constraints make it an
    // exact 40x30 rectangle anchored via coincident corners.
    Sketch sk("Rect");
    auto bottom = sk.add_line(0, 0, 38, 1);
    auto right = sk.add_line(38, 1, 41, 29);
    auto top = sk.add_line(41, 29, 2, 31);
    auto left = sk.add_line(2, 31, 0, 0);

    sk.add_constraint(ConstraintType::Coincident,
                      {{bottom, PointRole::End}, {right, PointRole::Start}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{right, PointRole::End}, {top, PointRole::Start}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{top, PointRole::End}, {left, PointRole::Start}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{left, PointRole::End}, {bottom, PointRole::Start}});
    sk.add_constraint(ConstraintType::Horizontal, {{bottom, PointRole::Self}});
    sk.add_constraint(ConstraintType::Horizontal, {{top, PointRole::Self}});
    sk.add_constraint(ConstraintType::Vertical, {{right, PointRole::Self}});
    sk.add_constraint(ConstraintType::Vertical, {{left, PointRole::Self}});
    sk.add_constraint(ConstraintType::Distance,
                      {{bottom, PointRole::Start}, {bottom, PointRole::End}}, 40.0);
    sk.add_constraint(ConstraintType::Distance,
                      {{right, PointRole::Start}, {right, PointRole::End}}, 30.0);

    auto solver = make_planegcs_backend();
    SolveResult res = solver->solve(sk);
    REQUIRE(res.ok());

    auto p0 = *sk.point_pos({bottom, PointRole::Start});
    auto p1 = *sk.point_pos({bottom, PointRole::End});
    auto p2 = *sk.point_pos({right, PointRole::End});
    double width = std::hypot(p1[0] - p0[0], p1[1] - p0[1]);
    double height = std::hypot(p2[0] - p1[0], p2[1] - p1[1]);
    REQUIRE(width == Approx(40.0).margin(1e-6));
    REQUIRE(height == Approx(30.0).margin(1e-6));
    // Horizontal means equal y at both ends.
    REQUIRE(p0[1] == Approx(p1[1]).margin(1e-6));
}

TEST_CASE("planegcs solves circle radius constraint", "[sketch][solver]") {
    Sketch sk("Circ");
    auto c = sk.add_circle(10, 10, 7);
    sk.add_constraint(ConstraintType::Radius, {{c, PointRole::Self}}, 12.5);

    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    const SketchEntity* ce = sk.entity(c);
    REQUIRE(sk.param(ce->params[2]) == Approx(12.5).margin(1e-6));
}

TEST_CASE("solver reports failure for conflicting constraints", "[sketch][solver]") {
    Sketch sk("Bad");
    auto l = sk.add_line(0, 0, 10, 0);
    sk.add_constraint(ConstraintType::Distance,
                      {{l, PointRole::Start}, {l, PointRole::End}}, 10.0);
    sk.add_constraint(ConstraintType::Distance,
                      {{l, PointRole::Start}, {l, PointRole::End}}, 20.0);

    auto solver = make_planegcs_backend();
    SolveResult res = solver->solve(sk);
    REQUIRE(res.status == SolveStatus::Failed);
}

TEST_CASE("rectangle profile builds a planar face", "[sketch][profile]") {
    Sketch sk("Rect");
    auto b = sk.add_line(0, 0, 40, 0);
    auto r = sk.add_line(40, 0, 40, 30);
    auto t = sk.add_line(40, 30, 0, 30);
    auto l = sk.add_line(0, 30, 0, 0);
    (void)b; (void)r; (void)t; (void)l;

    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());
    REQUIRE(shape::area(face) == Approx(1200.0).epsilon(1e-6));
}

TEST_CASE("circle profile builds a disk", "[sketch][profile]") {
    Sketch sk("Disk");
    sk.add_circle(0, 0, 10);
    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());
    REQUIRE(shape::area(face) == Approx(3.14159265358979 * 100).epsilon(1e-4));
}

TEST_CASE("open profile fails cleanly", "[sketch][profile]") {
    Sketch sk("Open");
    sk.add_line(0, 0, 10, 0);
    sk.add_line(10, 0, 10, 10);
    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(face.IsNull());
    REQUIRE(!err.empty());
}

TEST_CASE("construction geometry is excluded from profiles", "[sketch][profile]") {
    Sketch sk("Constr");
    sk.add_circle(0, 0, 10);
    auto guide = sk.add_line(-50, 0, 50, 0);
    sk.set_construction(guide, true);
    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());  // circle alone forms the profile
}

TEST_CASE("multi-wire profile: outer rect minus inner hole", "[sketch][profile]") {
    Sketch sk("Frame");
    // Outer 40x30
    sk.add_line(0, 0, 40, 0);
    sk.add_line(40, 0, 40, 30);
    sk.add_line(40, 30, 0, 30);
    sk.add_line(0, 30, 0, 0);
    // Inner 20x10 centered hole
    sk.add_line(10, 10, 30, 10);
    sk.add_line(30, 10, 30, 20);
    sk.add_line(30, 20, 10, 20);
    sk.add_line(10, 20, 10, 10);

    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());
    REQUIRE(err.empty());
    REQUIRE(shape::area(face) == Approx(40.0 * 30.0 - 20.0 * 10.0).epsilon(1e-6));
}

TEST_CASE("point-to-line distance sets hex across-flats", "[sketch][solver]") {
    // Centre to each horizontal flat is 10 → across-flats is 20.
    Sketch sk("HexAF");
    const double af = 20.0;
    const double R = af / std::sqrt(3.0);
    std::vector<EntityId> edges;
    for (int i = 0; i < 6; ++i) {
        double a0 = i * M_PI / 3.0;
        double a1 = (i + 1) * M_PI / 3.0;
        edges.push_back(sk.add_line(R * std::cos(a0), R * std::sin(a0),
                                    R * std::cos(a1), R * std::sin(a1)));
    }
    for (int i = 0; i < 6; ++i) {
        sk.add_constraint(ConstraintType::Coincident,
                          {{edges[static_cast<size_t>(i)], PointRole::End},
                           {edges[static_cast<size_t>((i + 1) % 6)], PointRole::Start}});
    }
    // Top edge is 60°–120° (i = 1), bottom is 240°–300° (i = 4).
    const auto top = edges[1];
    const auto bot = edges[4];
    sk.add_constraint(ConstraintType::Horizontal, {{top, PointRole::Self}});
    sk.add_constraint(ConstraintType::Horizontal, {{bot, PointRole::Self}});
    auto center = sk.add_point(0.2, -0.3);
    sk.add_constraint(ConstraintType::Distance,
                      {{center, PointRole::Self}, {top, PointRole::Self}}, 10.0);
    sk.add_constraint(ConstraintType::Distance,
                      {{center, PointRole::Self}, {bot, PointRole::Self}}, 10.0);

    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    const SketchEntity* te = sk.entity(top);
    const SketchEntity* be = sk.entity(bot);
    const SketchEntity* ce = sk.entity(center);
    double y_top = sk.param(te->params[1]);
    double y_bot = sk.param(be->params[1]);
    double y_c = sk.param(ce->params[1]);
    REQUIRE(sk.param(te->params[1]) == Approx(sk.param(te->params[3])).margin(1e-5));
    REQUIRE(sk.param(be->params[1]) == Approx(sk.param(be->params[3])).margin(1e-5));
    REQUIRE(std::abs(y_top - y_c) == Approx(10.0).margin(1e-4));
    REQUIRE(std::abs(y_bot - y_c) == Approx(10.0).margin(1e-4));
    REQUIRE(std::abs(y_top - y_bot) == Approx(20.0).margin(1e-4));
}

TEST_CASE("multi-wire profile: open leftover fails", "[sketch][profile]") {
    Sketch sk("OpenHole");
    sk.add_line(0, 0, 40, 0);
    sk.add_line(40, 0, 40, 30);
    sk.add_line(40, 30, 0, 30);
    sk.add_line(0, 30, 0, 0);
    // Incomplete inner loop
    sk.add_line(10, 10, 30, 10);
    sk.add_line(30, 10, 30, 20);

    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(face.IsNull());
    REQUIRE(!err.empty());
}

namespace {

bool on_face(const TopoDS_Shape& shape, double x, double y) {
    TopoDS_Face face = TopoDS::Face(shape);
    BRepClass_FaceClassifier cls(face, gp_Pnt(x, y, 0.0), 1e-6);
    return cls.State() == TopAbs_IN || cls.State() == TopAbs_ON;
}

// GUI pre-cut jaw: floor through the head centre, walls out to the Ø45 rim,
// arc endpoints on that rim, but stored angles naming the complementary bulge.
void add_gui_jaw_mouth(Sketch& sk, bool stale_angles) {
    const double cx = 200.0;
    const double cy = 0.0;
    const double r = 22.50000250339508;
    const double sa = -5.037233207302222;
    const double ea = -5.9583410802620556;
    const double sx = 221.32325744628906;
    const double sy = 7.181128025054932;
    const double ex = 207.18112182617188;
    const double ey = 21.32326316833496;
    sk.add_line(207.0710678100586, -7.071067810058594, sx, sy);
    sk.add_line(192.9289321899414, 7.071067810058594, ex, ey);
    sk.add_line(207.0710678100586, -7.071067810058594, 192.9289321899414, 7.071067810058594);
    auto arc = sk.add_arc(cx, cy, r, sa, ea);
    const SketchEntity* e = sk.entity(arc);
    REQUIRE(e != nullptr);
    if (stale_angles) {
        sk.param_mut(e->params[5]) = sx;
        sk.param_mut(e->params[6]) = sy;
        sk.param_mut(e->params[7]) = ex;
        sk.param_mut(e->params[8]) = ey;
    }
}

}  // namespace

TEST_CASE("stale jaw arc angles follow the endpoint mouth", "[sketch][profile][jaw]") {
    Sketch stale("StaleJaw");
    add_gui_jaw_mouth(stale, true);
    std::string err;
    TopoDS_Shape face = stale.profile_face(&err);
    INFO(err);
    REQUIRE_FALSE(face.IsNull());
    // u ≈ 12 along the jaw, inside the 20 mm mouth. The complementary bulge
    // would leave this point outside and swallow the rest of the head.
    CHECK(on_face(face, 200.0 + 12.0 * 0.70710678, 12.0 * 0.70710678));
    CHECK_FALSE(on_face(face, 200.0 - 12.0 * 0.70710678, -12.0 * 0.70710678));
    CHECK(shape::area(face) < 800.0);

    // A consistent major arc (angles name its endpoints) must stay the long bulge.
    Sketch major("MajorArc");
    const double sa = 0.2;
    const double sweep = 300.0 * 3.14159265358979323846 / 180.0;
    auto arc = major.add_arc(0.0, 0.0, 10.0, sa, sa + sweep);
    const SketchEntity* e = major.entity(arc);
    REQUIRE(e != nullptr);
    major.add_line(major.param(e->params[5]), major.param(e->params[6]),
                   major.param(e->params[7]), major.param(e->params[8]));
    TopoDS_Shape wide = major.profile_face(&err);
    INFO(err);
    REQUIRE_FALSE(wide.IsNull());
    const double mid = sa + sweep * 0.5;
    CHECK(on_face(wide, 5.0 * std::cos(mid), 5.0 * std::sin(mid)));
    // The unused cap sits past the chord (r·cos(30°) ≈ 8.7). A consistent
    // major arc must keep that cap outside the face.
    const double gap = mid + 3.14159265358979323846;
    CHECK_FALSE(on_face(wide, 9.5 * std::cos(gap), 9.5 * std::sin(gap)));
    CHECK(shape::area(wide) == Approx(305.1).epsilon(0.02));
}
