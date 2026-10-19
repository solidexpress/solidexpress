// WP-L8: offset Δr is a relation; circular pattern keeps 60°.

#include <catch.hpp>

#include <algorithm>
#include <cmath>

#include <BRepAdaptor_Surface.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch_tools.hpp"
#include "sx/solver.hpp"

using namespace sx;
using namespace sx::sketch_tools;

TEST_CASE("offset circle radius tracks the source", "[offset][l8]") {
    Sketch sk;
    auto c = sk.add_circle(0, 0, 10);
    auto src_r = sk.add_constraint(ConstraintType::Radius, {{c, PointRole::Self}}, 10.0, true);
    auto ids = offset_entities(sk, {c.str()}, 2.0);
    REQUIRE(ids.size() == 1);
    EntityId copy = EntityId::from_string(ids[0]);
    CHECK(sk.param(sk.entity(copy)->params[2]) == Approx(12.0).margin(1e-9));
    REQUIRE(sk.set_constraint_value(src_r, 11.0));
    sk.param_mut(sk.entity(c)->params[2]) = 11.0;
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    CHECK(sk.param(sk.entity(copy)->params[2]) == Approx(13.0).margin(1e-6));
}

TEST_CASE("circular pattern six copies stay at 60 deg after seed move", "[pattern][l8]") {
    Sketch sk;
    auto seed = sk.add_circle(10, 0, 2);
    auto ids = circular_pattern_entities(sk, {seed.str()}, 0, 0, 6, 2 * 3.14159265358979323846);
    REQUIRE(ids.size() == 5);
    sk.param_mut(sk.entity(seed)->params[0]) = 0.0;
    sk.param_mut(sk.entity(seed)->params[1]) = 12.0;
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    const double two_pi = 2 * 3.14159265358979323846;
    std::vector<double> angs;
    angs.push_back(std::atan2(sk.param(sk.entity(seed)->params[1]),
                              sk.param(sk.entity(seed)->params[0])));
    for (const auto& sid : ids) {
        EntityId id = EntityId::from_string(sid);
        angs.push_back(std::atan2(sk.param(sk.entity(id)->params[1]),
                                  sk.param(sk.entity(id)->params[0])));
    }
    std::sort(angs.begin(), angs.end());
    for (size_t i = 1; i < angs.size(); ++i) {
        double d = angs[i] - angs[i - 1];
        while (d < 0) d += two_pi;
        CHECK(d == Approx(two_pi / 6.0).margin(1e-9));
    }
}

TEST_CASE("thin line-arc-line has a cylindrical face", "[thin][l8]") {
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Channel");
    skf.sketch->add_line(0, 0, 10, 0);
    skf.sketch->add_arc(10, 5, 5, -1.5707963267948966, 1.5707963267948966);
    skf.sketch->add_line(10, 10, 0, 10);
    auto sid = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sid.str()},
                  {"distance", 8.0},
                  {"thin_thickness", 2.0},
                  {"op", "new"}};
    auto eid = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* b = doc.body(graph.feature(eid)->output_body);
    REQUIRE(b != nullptr);
    bool cyl = false;
    for (TopExp_Explorer ex(b->shape, TopAbs_FACE); ex.More(); ex.Next()) {
        BRepAdaptor_Surface s(TopoDS::Face(ex.Current()));
        if (s.GetType() == GeomAbs_Cylinder) cyl = true;
    }
    CHECK(cyl);
}
