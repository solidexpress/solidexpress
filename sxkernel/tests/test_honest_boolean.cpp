#include <catch.hpp>

#include <array>
#include <cmath>
#include <string>

#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>

#include "sx/document.hpp"
#include "sx/exactness.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

EntityId add_box(FeatureGraph& g, double a, double b, double c,
                 std::array<double, 3> origin = {0, 0, 0}) {
    Feature f;
    f.type = FeatureType::Primitive;
    f.params = {{"kind", "box"},
                {"a", a},
                {"b", b},
                {"c", c},
                {"origin", json::array({origin[0], origin[1], origin[2]})}};
    return g.add(std::move(f));
}

bool warning_has(const FeatureGraph& g, const char* needle) {
    for (const auto& w : g.warnings())
        if (w.second.find(needle) != std::string::npos) return true;
    return false;
}

}  // namespace

TEST_CASE("honest fuse: touching boxes, zero fuzz, volume = sum", "[exactness][boolean]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    auto a = add_box(g, 10, 10, 10);
    auto b = add_box(g, 10, 10, 10, {10, 0, 0});
    Feature fuse;
    fuse.type = FeatureType::Boolean;
    fuse.params = {{"op", "fuse"}, {"target", a.str()}, {"tool", b.str()}};
    g.add(std::move(fuse));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* body = doc.body(g.feature(a)->output_body);
    REQUIRE(body != nullptr);
    json probe = exactness::probe_shape(body->shape);
    const double vol = probe["volume"].get<double>();
    const double sum = 2000.0;
    REQUIRE(std::abs(vol - sum) / sum < 1e-9);
    CHECK_FALSE(warning_has(g, "boolean fuzz"));
}

TEST_CASE("extrude fuse: 6 mm handle onto 10 mm heads keeps both extents",
          "[exactness][boolean][extrude]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    Feature heads_sk;
    heads_sk.type = FeatureType::Sketch;
    heads_sk.sketch = std::make_shared<Sketch>("Heads");
    heads_sk.sketch->add_line(-25, -27, 25, -27);
    heads_sk.sketch->add_line(25, -27, 25, 27);
    heads_sk.sketch->add_line(25, 27, -25, 27);
    heads_sk.sketch->add_line(-25, 27, -25, -27);
    auto hid = g.add(std::move(heads_sk));
    Feature heads;
    heads.type = FeatureType::Extrude;
    heads.params = {{"sketch", hid.str()},
                    {"distance", 10.0},
                    {"op", "new"},
                    {"end", "symmetric"}};
    auto heads_id = g.add(std::move(heads));
    Feature handle_sk;
    handle_sk.type = FeatureType::Sketch;
    handle_sk.sketch = std::make_shared<Sketch>("Handle");
    handle_sk.sketch->add_line(20, -10, 220, -10);
    handle_sk.sketch->add_line(220, -10, 220, 10);
    handle_sk.sketch->add_line(220, 10, 20, 10);
    handle_sk.sketch->add_line(20, 10, 20, -10);
    auto sid = g.add(std::move(handle_sk));
    Feature handle;
    handle.type = FeatureType::Extrude;
    handle.params = {{"sketch", sid.str()},
                     {"distance", 6.0},
                     {"op", "fuse"},
                     {"end", "symmetric"},
                     {"target", heads_id.str()}};
    g.add(std::move(handle));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* body = doc.body(g.feature(heads_id)->output_body);
    REQUIRE(body != nullptr);
    Bnd_Box box;
    BRepBndLib::Add(body->shape, box);
    REQUIRE_FALSE(box.IsVoid());
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    REQUIRE(x0 == Approx(-25.0).margin(0.2));
    REQUIRE(x1 == Approx(220.0).margin(0.2));
    REQUIRE(y0 == Approx(-27.0).margin(0.2));
    REQUIRE(y1 == Approx(27.0).margin(0.2));
}

TEST_CASE("honest fuse: adjacent 10 mm and 6 mm pads become one solid",
          "[exactness][boolean][extrude]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    auto heads = add_box(g, 40, 20, 10);             // 10 mm thick
    auto handle = add_box(g, 80, 20, 6, {40, 0, 2});  // 6 mm, shares the x=40 face
    Feature fuse;
    fuse.type = FeatureType::Boolean;
    fuse.params = {{"op", "fuse"}, {"target", heads.str()}, {"tool", handle.str()}};
    g.add(std::move(fuse));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* body = doc.body(g.feature(heads)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::is_valid(body->shape));
    REQUIRE(shape::count(body->shape).solids == 1);
    const double vol = shape::volume(body->shape);
    const double sum = 40.0 * 20.0 * 10.0 + 80.0 * 20.0 * 6.0;
    REQUIRE(std::abs(vol - sum) / sum < 1e-6);
}

TEST_CASE("blind cut on the host face removes volume and stays closed",
          "[exactness][boolean][extrude]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    Feature sk;
    sk.type = FeatureType::Sketch;
    sk.sketch = std::make_shared<Sketch>("Plate");
    sk.sketch->add_line(0, 0, 40, 0);
    sk.sketch->add_line(40, 0, 40, 10);
    sk.sketch->add_line(40, 10, 0, 10);
    sk.sketch->add_line(0, 10, 0, 0);
    auto sk_id = g.add(std::move(sk));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    auto ext_id = g.add(std::move(ext));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* plate = doc.body(g.feature(ext_id)->output_body);
    REQUIRE(plate != nullptr);
    const double v0 = shape::volume(plate->shape);

    Feature cut_sk;
    cut_sk.type = FeatureType::Sketch;
    SketchPlane pl;
    pl.origin = {0, 0, 10};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    cut_sk.sketch = std::make_shared<Sketch>("Hole", pl);
    cut_sk.sketch->add_circle(20, 5, 3.0);
    auto cut_sk_id = g.add(std::move(cut_sk));
    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", cut_sk_id.str()},
                  {"distance", -5.0},
                  {"end", "blind"},
                  {"op", "cut"},
                  {"target", ext_id.str()}};
    g.add(std::move(cut));
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    const Body* after = doc.body(g.feature(ext_id)->output_body);
    REQUIRE(after != nullptr);
    REQUIRE(shape::is_valid(after->shape));
    const double v1 = shape::volume(after->shape);
    REQUIRE(v0 - v1 > 100.0);
    REQUIRE(v0 - v1 < 200.0);
}

TEST_CASE("honest fuse: disjoint boxes keep both solids in one body",
          "[exactness][boolean]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    auto a = add_box(g, 10, 10, 10);
    auto b = add_box(g, 10, 10, 10, {50, 0, 0});  // 40 mm gap
    Feature fuse;
    fuse.type = FeatureType::Boolean;
    fuse.params = {{"op", "fuse"}, {"target", a.str()}, {"tool", b.str()}};
    g.add(std::move(fuse));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    REQUIRE(doc.body_ids().size() == 1);
    const Body* body = doc.body(g.feature(a)->output_body);
    REQUIRE(body != nullptr);
    REQUIRE(shape::count(body->shape).solids == 2);
    const double vol = std::abs(shape::volume(body->shape));
    const double sum = 2000.0;
    REQUIRE(std::abs(vol - sum) / sum < 1e-9);
}

TEST_CASE("honest fuse: 0.05 gap writes fuzz warning", "[exactness][boolean]") {
    Document doc;
    FeatureGraph& g = doc.graph();
    auto a = add_box(g, 10, 10, 10);
    auto b = add_box(g, 10, 10, 10, {10.01, 0, 0});
    Feature fuse;
    fuse.type = FeatureType::Boolean;
    fuse.params = {{"op", "fuse"}, {"target", a.str()}, {"tool", b.str()}};
    g.add(std::move(fuse));
    std::string err;
    REQUIRE(g.regenerate(doc, &err));
    INFO(err);
    std::string allw;
    for (const auto& w : g.warnings()) allw += w.second + ";";
    const Body* body = doc.body(g.feature(a)->output_body);
    const double vol = body ? shape::volume(body->shape) : 0.0;
    CAPTURE(allw, vol, g.warnings().size());
    REQUIRE(warning_has(g, "0.05"));
}
