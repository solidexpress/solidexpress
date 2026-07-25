#include <catch2/catch.hpp>

#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/solver.hpp"
#include "sx/variables.hpp"

using namespace sx;

TEST_CASE("sketch: midpoint / diameter / fix / driven", "[sketch][sw]") {
    auto solver = make_planegcs_backend();

    Sketch sk;
    auto ln = sk.add_line(0, 0, 20, 0);
    auto mid = sk.add_point(9, 1);
    sk.add_constraint(ConstraintType::Horizontal, {{ln, PointRole::Self}});
    sk.add_constraint(ConstraintType::Distance,
                      {{ln, PointRole::Start}, {ln, PointRole::End}}, 20.0);
    auto o = sk.add_point(0, 0);
    sk.set_construction(o, true);
    sk.add_constraint(ConstraintType::Fix, {{o, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{o, PointRole::Self}, {ln, PointRole::Start}});
    sk.add_constraint(ConstraintType::Midpoint, {{mid, PointRole::Self}, {ln, PointRole::Self}});
    auto res = solver->solve(sk);
    REQUIRE(res.ok());
    auto mp = *sk.point_pos({mid, PointRole::Self});
    REQUIRE(mp[0] == Approx(10.0).margin(1e-3));
    REQUIRE(mp[1] == Approx(0.0).margin(1e-3));

    Sketch sk2;
    auto c = sk2.add_circle(0, 0, 5);
    sk2.add_constraint(ConstraintType::Fix, {{c, PointRole::Self}});
    // Override radius via diameter after Fix snapshot — update locked then diameter.
    sk2.add_constraint(ConstraintType::Diameter, {{c, PointRole::Self}}, 16.0);
    // Fix already locked r=5; diameter may conflict. Use diameter alone + Fix center.
    Sketch sk2b;
    auto c2 = sk2b.add_circle(1, 2, 5);
    auto ctr = sk2b.add_point(0, 0);
    sk2b.set_construction(ctr, true);
    sk2b.add_constraint(ConstraintType::Fix, {{ctr, PointRole::Self}});
    sk2b.add_constraint(ConstraintType::Coincident,
                        {{ctr, PointRole::Self}, {c2, PointRole::Center}});
    sk2b.add_constraint(ConstraintType::Diameter, {{c2, PointRole::Self}}, 16.0);
    res = solver->solve(sk2b);
    REQUIRE(res.ok());
    REQUIRE(sk2b.param(sk2b.entity(c2)->params[2]) == Approx(8.0).margin(1e-3));

    // Driven distance does not override Fix length.
    Sketch sk3;
    auto l = sk3.add_line(0, 0, 10, 0);
    sk3.add_constraint(ConstraintType::Horizontal, {{l, PointRole::Self}});
    sk3.add_constraint(ConstraintType::Fix, {{l, PointRole::Self}});
    sk3.add_constraint(ConstraintType::Distance,
                       {{l, PointRole::Start}, {l, PointRole::End}}, 99.0, /*driving=*/false);
    res = solver->solve(sk3);
    REQUIRE(res.ok());
    double dx = sk3.param(sk3.entity(l)->params[2]) - sk3.param(sk3.entity(l)->params[0]);
    double dy = sk3.param(sk3.entity(l)->params[3]) - sk3.param(sk3.entity(l)->params[1]);
    REQUIRE(std::sqrt(dx * dx + dy * dy) == Approx(10.0).margin(0.15));
}

TEST_CASE("sketch: mounting plate DOF=0 + extrude volume", "[sketch][sw]") {
    auto solver = make_planegcs_backend();
    auto plate = std::make_shared<Sketch>("Plate");
    auto pb = plate->add_line(0, 0, 80, 0);
    auto pr = plate->add_line(80, 0, 80, 50);
    auto pt = plate->add_line(80, 50, 0, 50);
    auto pln = plate->add_line(0, 50, 0, 0);
    plate->add_constraint(ConstraintType::Coincident,
                          {{pb, PointRole::End}, {pr, PointRole::Start}});
    plate->add_constraint(ConstraintType::Coincident,
                          {{pr, PointRole::End}, {pt, PointRole::Start}});
    plate->add_constraint(ConstraintType::Coincident,
                          {{pt, PointRole::End}, {pln, PointRole::Start}});
    plate->add_constraint(ConstraintType::Coincident,
                          {{pln, PointRole::End}, {pb, PointRole::Start}});
    plate->add_constraint(ConstraintType::Horizontal, {{pb, PointRole::Self}});
    plate->add_constraint(ConstraintType::Horizontal, {{pt, PointRole::Self}});
    plate->add_constraint(ConstraintType::Vertical, {{pr, PointRole::Self}});
    plate->add_constraint(ConstraintType::Vertical, {{pln, PointRole::Self}});
    auto wdim = plate->add_constraint(ConstraintType::Distance,
                                      {{pb, PointRole::Start}, {pb, PointRole::End}}, 80.0);
    plate->add_constraint(ConstraintType::Distance,
                          {{pln, PointRole::Start}, {pln, PointRole::End}}, 50.0);
    auto o = plate->add_point(0, 0);
    plate->set_construction(o, true);
    plate->add_constraint(ConstraintType::Fix, {{o, PointRole::Self}});
    plate->add_constraint(ConstraintType::Coincident,
                          {{o, PointRole::Self}, {pb, PointRole::Start}});

    auto c1 = plate->add_circle(15, 15, 3);
    auto c2 = plate->add_circle(65, 15, 3);
    auto c3 = plate->add_circle(65, 35, 3);
    auto c4 = plate->add_circle(15, 35, 3);
    plate->add_constraint(ConstraintType::Equal, {{c1, PointRole::Self}, {c2, PointRole::Self}});
    plate->add_constraint(ConstraintType::Equal, {{c1, PointRole::Self}, {c3, PointRole::Self}});
    plate->add_constraint(ConstraintType::Equal, {{c1, PointRole::Self}, {c4, PointRole::Self}});
    plate->add_constraint(ConstraintType::Radius, {{c1, PointRole::Self}}, 3.0);
    plate->add_constraint(ConstraintType::Fix, {{c1, PointRole::Self}});
    plate->add_constraint(ConstraintType::Fix, {{c2, PointRole::Self}});
    plate->add_constraint(ConstraintType::Fix, {{c3, PointRole::Self}});
    plate->add_constraint(ConstraintType::Fix, {{c4, PointRole::Self}});

    auto res = solver->solve(*plate);
    REQUIRE(res.ok());
    REQUIRE(res.dofs == 0);

    std::string err;
    REQUIRE_FALSE(plate->profile_face(&err).IsNull());

    Document doc;
    FeatureGraph g;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = plate;
    auto sk_fid = g.add(std::move(skf));
    Feature ex;
    ex.type = FeatureType::Extrude;
    ex.params = {{"sketch", sk_fid.str()}, {"distance", 10.0}, {"op", "new"}};
    g.add(std::move(ex));
    REQUIRE(g.regenerate(doc));
    REQUIRE(doc.body_ids().size() == 1);
    double vol0 = shape::volume(doc.body(doc.body_ids()[0])->shape);
    REQUIRE(vol0 > 1000.0);

    // Widen plate and regenerate.
    plate->set_constraint_value(wdim, 100.0);
    REQUIRE(solver->solve(*plate).ok());
    REQUIRE(g.regenerate(doc));
    double vol1 = shape::volume(doc.body(doc.body_ids()[0])->shape);
    REQUIRE(vol1 > vol0);
}

TEST_CASE("sketch: expression dims", "[sketch][sw]") {
    Sketch sk;
    auto ln = sk.add_line(0, 0, 10, 0);
    sk.add_constraint(ConstraintType::Horizontal, {{ln, PointRole::Self}});
    auto o = sk.add_point(0, 0);
    sk.set_construction(o, true);
    sk.add_constraint(ConstraintType::Fix, {{o, PointRole::Self}});
    sk.add_constraint(ConstraintType::Coincident, {{o, PointRole::Self}, {ln, PointRole::Start}});
    auto cid = sk.add_constraint(ConstraintType::Distance,
                                 {{ln, PointRole::Start}, {ln, PointRole::End}}, 10.0);
    sk.set_constraint_expr(cid, "=w/2");
    VariableTable vars;
    vars.set("w", "40");
    REQUIRE(sk.resolve_expressions(vars.evaluate()));
    REQUIRE(sk.constraint_mut(cid)->value == Approx(20.0));
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    double dx = sk.param(sk.entity(ln)->params[2]) - sk.param(sk.entity(ln)->params[0]);
    REQUIRE(dx == Approx(20.0).margin(1e-3));
}

TEST_CASE("sketch: project line edge + dangling", "[sketch][sw]") {
    Sketch sk;
    auto id = sk.project_line_edge({0, 0, 0}, {30, 0, 0}, "edge-1");
    REQUIRE(sk.is_external(id));
    REQUIRE(sk.entity(id)->projected_from == "edge-1");
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    REQUIRE(sk.update_projected_line(id, {0, 0, 0}, {50, 0, 0}));
    double dx = sk.param(sk.entity(id)->params[2]) - sk.param(sk.entity(id)->params[0]);
    REQUIRE(dx == Approx(50.0).margin(1e-6));
    REQUIRE(sk.mark_dangling_external({}) == 1);
    REQUIRE(sk.is_construction(id));
}

TEST_CASE("sketch: spline + analyze + fully_define", "[sketch][sw]") {
    Sketch sk;
    auto sid = sk.add_spline({{0, 0}, {10, 5}, {20, 0}});
    REQUIRE_FALSE(sid.is_null());
    REQUIRE(sk.spline_fit_points(sid).size() == 3);

    Sketch open;
    open.add_line(0, 0, 10, 0);
    open.add_line(10, 0, 10, 8);
    auto open_issues = open.analyze();
    bool has_open = false;
    for (const auto& i : open_issues)
        if (i.code == "open_loop") has_open = true;
    REQUIRE(has_open);

    Sketch under;
    under.add_line(0, 0, 40, 0.2);
    under.add_line(40, 0.2, 40, 20);
    REQUIRE(under.fully_define() >= 1);
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(under).ok());
}

TEST_CASE("sketch: loft with optional guides path", "[sketch][sw]") {
    Document doc;
    FeatureGraph g;
    Feature bot;
    bot.type = FeatureType::Sketch;
    bot.sketch = std::make_shared<Sketch>("bot");
    bot.sketch->add_circle(0, 0, 10);
    auto bfid = g.add(std::move(bot));
    Feature top;
    top.type = FeatureType::Sketch;
    SketchPlane zp;
    zp.origin = {0, 0, 40};
    top.sketch = std::make_shared<Sketch>("top", zp);
    top.sketch->add_circle(0, 0, 5);
    auto tfid = g.add(std::move(top));
    Feature loft;
    loft.type = FeatureType::Loft;
    loft.params = {{"sketches", {bfid.str(), tfid.str()}}, {"ruled", true}};
    g.add(std::move(loft));
    REQUIRE(g.regenerate(doc));
    double vol_plain = shape::volume(doc.body(doc.body_ids()[0])->shape);
    REQUIRE(vol_plain > 1000.0);

    Document doc2;
    FeatureGraph g2;
    Feature bot2;
    bot2.type = FeatureType::Sketch;
    bot2.sketch = std::make_shared<Sketch>("bot");
    bot2.sketch->add_circle(0, 0, 10);
    auto b2 = g2.add(std::move(bot2));
    Feature top2;
    top2.type = FeatureType::Sketch;
    top2.sketch = std::make_shared<Sketch>("top", zp);
    top2.sketch->add_circle(0, 0, 5);
    auto t2 = g2.add(std::move(top2));
    Feature gu;
    gu.type = FeatureType::Sketch;
    SketchPlane xzp;
    xzp.x_dir = {1, 0, 0};
    xzp.y_dir = {0, 0, 1};
    gu.sketch = std::make_shared<Sketch>("guide", xzp);
    gu.sketch->add_line(10, 0, 14, 20);
    gu.sketch->add_line(14, 20, 5, 40);
    auto gg = g2.add(std::move(gu));
    Feature loft2;
    loft2.type = FeatureType::Loft;
    loft2.params = {{"sketches", {b2.str(), t2.str()}},
                    {"ruled", false},
                    {"guides", {gg.str()}}};
    g2.add(std::move(loft2));
    bool ok = g2.regenerate(doc2);
    REQUIRE(ok);
    REQUIRE_FALSE(doc2.body_ids().empty());
    double vol_g = shape::volume(doc2.body(doc2.body_ids()[0])->shape);
    REQUIRE(std::abs(vol_g - vol_plain) > 0.5);
    REQUIRE(std::abs(vol_g) < 1e7);

    // UI-like: guide coplanar with bottom (ground rail), short loft height.
    Document doc3;
    FeatureGraph g3;
    Feature bot3;
    bot3.type = FeatureType::Sketch;
    bot3.sketch = std::make_shared<Sketch>("bot");
    bot3.sketch->add_circle(0, 0, 10);
    auto b3 = g3.add(std::move(bot3));
    Feature gu3;
    gu3.type = FeatureType::Sketch;
    gu3.sketch = std::make_shared<Sketch>("guide");
    gu3.sketch->add_line(28, -4, 36, 20);
    auto gg3 = g3.add(std::move(gu3));
    Feature top3;
    top3.type = FeatureType::Sketch;
    SketchPlane zp10;
    zp10.origin = {0, 0, 10};
    top3.sketch = std::make_shared<Sketch>("top", zp10);
    top3.sketch->add_circle(0, 0, 4);
    auto t3 = g3.add(std::move(top3));
    Feature loft3;
    loft3.type = FeatureType::Loft;
    loft3.params = {{"sketches", {b3.str(), t3.str()}},
                    {"ruled", false},
                    {"guides", {gg3.str()}}};
    g3.add(std::move(loft3));
    REQUIRE(g3.regenerate(doc3));
    double vol_ui = shape::volume(doc3.body(doc3.body_ids()[0])->shape);
    REQUIRE(std::abs(vol_ui) > 10.0);
    REQUIRE(std::abs(vol_ui) < 1e7);
}
