#include <catch.hpp>

#include <cmath>
#include <vector>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

std::shared_ptr<Sketch> circle_sketch(double r, SketchPlane plane = {}) {
    auto sk = std::make_shared<Sketch>("Disk", plane);
    sk->add_circle(0, 0, r);
    return sk;
}

std::shared_ptr<Sketch> rect_sketch(double w, double h, SketchPlane plane = {}) {
    auto sk = std::make_shared<Sketch>("Rect", plane);
    sk->add_line(0, 0, w, 0);
    sk->add_line(w, 0, w, h);
    sk->add_line(w, h, 0, h);
    sk->add_line(0, h, 0, 0);
    return sk;
}

double polyline_length(const json& path) {
    double len = 0;
    for (size_t i = 1; i < path.size(); ++i) {
        double dx = path[i][0].get<double>() - path[i - 1][0].get<double>();
        double dy = path[i][1].get<double>() - path[i - 1][1].get<double>();
        double dz = path[i][2].get<double>() - path[i - 1][2].get<double>();
        len += std::sqrt(dx * dx + dy * dy + dz * dz);
    }
    return len;
}

}  // namespace

TEST_CASE("featsweep: sweep circle matches extrude volume and stable body id", "[featsweep]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = circle_sketch(5.0);
    auto sketch_fid = graph.add(std::move(skf));

    const double height = 25.0;
    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", sketch_fid.str()},
                 {"path", json::array({json::array({0.0, 0.0, 0.0}),
                                       json::array({0.0, 0.0, height})})}};
    auto sw_fid = graph.add(std::move(sw));

    // Reference extrude with the same profile and height.
    FeatureGraph extrude_graph;
    Feature skf2;
    skf2.type = FeatureType::Sketch;
    skf2.sketch = circle_sketch(5.0);
    auto sk2 = extrude_graph.add(std::move(skf2));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk2.str()}, {"distance", height}, {"op", "new"}};
    auto ext_fid = extrude_graph.add(std::move(ext));

    Document extrude_doc;
    std::string err;
    REQUIRE(extrude_graph.regenerate(extrude_doc, &err));
    const double extrude_vol =
        shape::volume(extrude_doc.body(extrude_graph.feature(ext_fid)->output_body)->shape);

    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(sw_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::is_valid(doc.body(body_id)->shape));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(extrude_vol).epsilon(0.01));

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(sw_fid)->output_body == body_id);
    REQUIRE(doc.body(body_id) != nullptr);

    // Edit path length: body id stable, volume scales.
    json p = graph.feature(sw_fid)->params;
    p["path"] = json::array({json::array({0.0, 0.0, 0.0}), json::array({0.0, 0.0, 50.0})});
    REQUIRE(graph.set_params(sw_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(sw_fid)->output_body == body_id);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(extrude_vol * 2.0).epsilon(0.01));
}

TEST_CASE("featsweep: sweep L-path produces valid solid", "[featsweep]") {
    Document doc;
    FeatureGraph graph;

    const double r = 2.0;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = circle_sketch(r);
    auto sketch_fid = graph.add(std::move(skf));

    json path = json::array({json::array({0.0, 0.0, 0.0}), json::array({0.0, 0.0, 40.0}),
                             json::array({30.0, 0.0, 40.0})});
    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", sketch_fid.str()}, {"path", path}};
    auto sw_fid = graph.add(std::move(sw));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* b = doc.body(graph.feature(sw_fid)->output_body);
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::count(b->shape).solids >= 1);

    const double expected = M_PI * r * r * polyline_length(path);
    REQUIRE(shape::volume(b->shape) == Approx(expected).epsilon(0.15));
}

TEST_CASE("featsweep: loft frustum volume and suppress restores body id", "[featsweep]") {
    Document doc;
    FeatureGraph graph;

    Feature bottom;
    bottom.type = FeatureType::Sketch;
    bottom.sketch = rect_sketch(20, 20);
    auto bottom_fid = graph.add(std::move(bottom));

    SketchPlane top_plane;
    top_plane.origin = {0, 0, 30};
    Feature top;
    top.type = FeatureType::Sketch;
    top.sketch = rect_sketch(10, 10, top_plane);
    auto top_fid = graph.add(std::move(top));

    Feature loft;
    loft.type = FeatureType::Loft;
    loft.params = {{"sketches", json::array({bottom_fid.str(), top_fid.str()})},
                   {"ruled", true}};
    auto loft_fid = graph.add(std::move(loft));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(loft_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::is_valid(doc.body(body_id)->shape));

    const double A1 = 400.0, A2 = 100.0, h = 30.0;
    const double frustum = h / 3.0 * (A1 + A2 + std::sqrt(A1 * A2));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(frustum).epsilon(0.05));

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(loft_fid)->output_body == body_id);
    REQUIRE(doc.body(body_id) != nullptr);

    REQUIRE(graph.set_suppressed(loft_fid, true));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) == nullptr);

    REQUIRE(graph.set_suppressed(loft_fid, false));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(loft_fid)->output_body == body_id);
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(frustum).epsilon(0.05));
}

TEST_CASE("featsweep: loft dependency protects referenced sketches", "[featsweep]") {
    FeatureGraph graph;

    Feature sk1;
    sk1.type = FeatureType::Sketch;
    sk1.sketch = rect_sketch(20, 20);
    auto sk1_fid = graph.add(std::move(sk1));

    SketchPlane top_plane;
    top_plane.origin = {0, 0, 10};
    Feature sk2;
    sk2.type = FeatureType::Sketch;
    sk2.sketch = rect_sketch(10, 10, top_plane);
    auto sk2_fid = graph.add(std::move(sk2));

    Feature loft;
    loft.type = FeatureType::Loft;
    loft.params = {{"sketches", json::array({sk1_fid.str(), sk2_fid.str()})}, {"ruled", false}};
    auto loft_fid = graph.add(std::move(loft));

    REQUIRE(graph.has_dependents(sk1_fid));
    REQUIRE(graph.has_dependents(sk2_fid));
    REQUIRE(!graph.remove(sk1_fid));
    REQUIRE(!graph.remove(sk2_fid));

    REQUIRE(graph.remove(loft_fid));
    REQUIRE(!graph.has_dependents(sk1_fid));
    REQUIRE(graph.remove(sk1_fid));
    REQUIRE(graph.remove(sk2_fid));
}

TEST_CASE("featsweep: json round trip preserves sweep and loft", "[featsweep]") {
    FeatureGraph graph;

    Feature sk_circle;
    sk_circle.type = FeatureType::Sketch;
    sk_circle.sketch = circle_sketch(3.0);
    auto circle_fid = graph.add(std::move(sk_circle));

    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", circle_fid.str()},
                 {"path", json::array({json::array({0.0, 0.0, 0.0}),
                                       json::array({0.0, 0.0, 12.0})})}};
    auto sw_fid = graph.add(std::move(sw));

    Feature sk_a;
    sk_a.type = FeatureType::Sketch;
    sk_a.sketch = rect_sketch(20, 20);
    auto sk_a_fid = graph.add(std::move(sk_a));

    SketchPlane top_plane;
    top_plane.origin = {0, 0, 30};
    Feature sk_b;
    sk_b.type = FeatureType::Sketch;
    sk_b.sketch = rect_sketch(10, 10, top_plane);
    auto sk_b_fid = graph.add(std::move(sk_b));

    Feature loft;
    loft.type = FeatureType::Loft;
    loft.params = {{"sketches", json::array({sk_a_fid.str(), sk_b_fid.str()})},
                   {"ruled", true}};
    auto loft_fid = graph.add(std::move(loft));

    Document doc;
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId sw_body = graph.feature(sw_fid)->output_body;
    EntityId loft_body = graph.feature(loft_fid)->output_body;
    const double sw_vol = shape::volume(doc.body(sw_body)->shape);
    const double loft_vol = shape::volume(doc.body(loft_body)->shape);

    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.timeline().size() == graph.timeline().size());
    REQUIRE(restored.feature(sw_fid)->type == FeatureType::Sweep);
    REQUIRE(restored.feature(loft_fid)->type == FeatureType::Loft);
    REQUIRE(restored.feature(sw_fid)->params == graph.feature(sw_fid)->params);
    REQUIRE(restored.feature(loft_fid)->params == graph.feature(loft_fid)->params);
    REQUIRE(restored.feature(sw_fid)->output_body == sw_body);
    REQUIRE(restored.feature(loft_fid)->output_body == loft_body);

    Document doc2;
    REQUIRE(restored.regenerate(doc2, &err));
    REQUIRE(doc2.body(sw_body) != nullptr);
    REQUIRE(doc2.body(loft_body) != nullptr);
    REQUIRE(shape::volume(doc2.body(sw_body)->shape) == Approx(sw_vol).epsilon(1e-6));
    REQUIRE(shape::volume(doc2.body(loft_body)->shape) == Approx(loft_vol).epsilon(1e-6));
}

TEST_CASE("featsweep: Path joins two planar sketches and Sweep consumes path_feature",
          "[featsweep][path]") {
    Document doc;
    FeatureGraph graph;

    // Path sketch A on XY: line from origin toward +X
    Feature ska;
    ska.type = FeatureType::Sketch;
    ska.sketch = std::make_shared<Sketch>("PathA");
    ska.sketch->add_line(0, 0, 20, 0);
    auto ska_fid = graph.add(std::move(ska));

    // Path sketch B on XZ-ish plane (Y-up kernel: rotate to YZ for vertical)
    SketchPlane yz;
    yz.origin = {20, 0, 0};
    yz.x_dir = {0, 1, 0};
    yz.y_dir = {0, 0, 1};
    Feature skb;
    skb.type = FeatureType::Sketch;
    skb.sketch = std::make_shared<Sketch>("PathB", yz);
    skb.sketch->add_line(0, 0, 0, 30);
    auto skb_fid = graph.add(std::move(skb));

    Feature pathf;
    pathf.type = FeatureType::Path;
    pathf.params = {{"sketches", json::array({ska_fid.str(), skb_fid.str()})},
                    {"mode", "join_endpoints"}};
    auto path_fid = graph.add(std::move(pathf));

    Feature profile;
    profile.type = FeatureType::Sketch;
    profile.sketch = circle_sketch(2.0);
    auto profile_fid = graph.add(std::move(profile));

    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", profile_fid.str()}, {"path_feature", path_fid.str()}};
    auto sw_fid = graph.add(std::move(sw));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(path_fid)->params.contains("path"));
    REQUIRE(graph.feature(path_fid)->params["path"].size() >= 2);
    EntityId body = graph.feature(sw_fid)->output_body;
    REQUIRE(doc.body(body) != nullptr);
    REQUIRE(shape::volume(doc.body(body)->shape) > 0.0);

    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.feature(path_fid)->type == FeatureType::Path);
    Document doc2;
    REQUIRE(restored.regenerate(doc2, &err));
    REQUIRE(doc2.body(body) != nullptr);
}

TEST_CASE("featsweep: Path merge preserves sketch order for dense spline + 3D corner sweep",
          "[featsweep][path]") {
    Document doc;
    FeatureGraph graph;

    Feature ska;
    ska.type = FeatureType::Sketch;
    ska.sketch = std::make_shared<Sketch>("SplineRail");
    // Densified fit-spline as line chain (matches UI spline tool).
    for (int i = 0; i < 16; ++i) {
        double t0 = static_cast<double>(i) / 16.0;
        double t1 = static_cast<double>(i + 1) / 16.0;
        double x0 = 20.0 * t0;
        double y0 = 4.0 * std::sin(t0 * 3.14159);
        double x1 = 20.0 * t1;
        double y1 = 4.0 * std::sin(t1 * 3.14159);
        ska.sketch->add_line(x0, y0, x1, y1);
    }
    auto ska_fid = graph.add(std::move(ska));

    SketchPlane yz;
    yz.origin = {20, 0, 0};
    yz.x_dir = {0, 1, 0};
    yz.y_dir = {0, 0, 1};
    Feature skb;
    skb.type = FeatureType::Sketch;
    skb.sketch = std::make_shared<Sketch>("Leg", yz);
    skb.sketch->add_line(0, 0, 0, 30);
    auto skb_fid = graph.add(std::move(skb));

    Feature pathf;
    pathf.type = FeatureType::Path;
    pathf.params = {{"sketches", json::array({ska_fid.str(), skb_fid.str()})},
                    {"mode", "join_endpoints"}};
    auto path_fid = graph.add(std::move(pathf));

    Feature profile;
    profile.type = FeatureType::Sketch;
    profile.sketch = circle_sketch(2.0);
    auto profile_fid = graph.add(std::move(profile));

    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", profile_fid.str()}, {"path_feature", path_fid.str()}};
    auto sw_fid = graph.add(std::move(sw));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body = graph.feature(sw_fid)->output_body;
    REQUIRE(doc.body(body) != nullptr);
    REQUIRE(shape::volume(doc.body(body)->shape) > 0.0);
}

TEST_CASE("featsweep: Path from a single sketch and Sweep path_feature deps",
          "[featsweep][path]") {
    Document doc;
    FeatureGraph graph;

    Feature rail;
    rail.type = FeatureType::Sketch;
    rail.sketch = std::make_shared<Sketch>("Rail");
    rail.sketch->add_line(0, 0, 40, 0);
    auto rail_fid = graph.add(std::move(rail));

    Feature pathf;
    pathf.type = FeatureType::Path;
    pathf.params = {{"sketches", json::array({rail_fid.str()})}, {"mode", "join_endpoints"}};
    auto path_fid = graph.add(std::move(pathf));

    Feature profile;
    profile.type = FeatureType::Sketch;
    profile.sketch = circle_sketch(2.0);
    auto profile_fid = graph.add(std::move(profile));

    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", profile_fid.str()}, {"path_feature", path_fid.str()}};
    auto sw_fid = graph.add(std::move(sw));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(path_fid)->params["path"].size() >= 2);
    EntityId body = graph.feature(sw_fid)->output_body;
    REQUIRE(doc.body(body) != nullptr);
    REQUIRE(shape::volume(doc.body(body)->shape) ==
            Approx(M_PI * 4.0 * 40.0).epsilon(0.05));

    REQUIRE(graph.has_dependents(path_fid));
    REQUIRE(!graph.remove(path_fid));
    REQUIRE(graph.remove(sw_fid));
    REQUIRE(!graph.has_dependents(path_fid));
    REQUIRE(graph.remove(path_fid));
}

TEST_CASE("featsweep: Path densifies arc rails", "[featsweep][path]") {
    Document doc;
    FeatureGraph graph;

    Feature rail;
    rail.type = FeatureType::Sketch;
    rail.sketch = std::make_shared<Sketch>("ArcRail");
    rail.sketch->add_arc(0, 0, 20, 0, M_PI / 2.0);
    auto rail_fid = graph.add(std::move(rail));

    Feature pathf;
    pathf.type = FeatureType::Path;
    pathf.params = {{"sketches", json::array({rail_fid.str()})}, {"mode", "join_endpoints"}};
    auto path_fid = graph.add(std::move(pathf));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const json& path = graph.feature(path_fid)->params["path"];
    REQUIRE(path.is_array());
    REQUIRE(path.size() >= 8);
}

TEST_CASE("featsweep: sweep cut/fuse ops and thin_thickness", "[featsweep]") {
    Document doc;
    FeatureGraph graph;

    Feature boxf;
    boxf.type = FeatureType::Primitive;
    boxf.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(boxf));

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = circle_sketch(5.0);
    auto sketch_fid = graph.add(std::move(skf));

    Feature sw;
    sw.type = FeatureType::Sweep;
    sw.params = {{"sketch", sketch_fid.str()},
                 {"path", json::array({json::array({0.0, 0.0, 0.0}),
                                       json::array({0.0, 0.0, 30.0})})},
                 {"op", "cut"},
                 {"target", box_fid.str()}};
    graph.add(std::move(sw));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId box_body = graph.feature(box_fid)->output_body;
    REQUIRE(doc.body(box_body) != nullptr);
    const double box_vol = 40.0 * 40.0 * 20.0;
    REQUIRE(shape::volume(doc.body(box_body)->shape) < box_vol - 1.0);

    // Thin sweep as a new body.
    FeatureGraph g2;
    Feature sk2;
    sk2.type = FeatureType::Sketch;
    sk2.sketch = circle_sketch(5.0);
    auto sk2_fid = g2.add(std::move(sk2));
    Feature thin;
    thin.type = FeatureType::Sweep;
    thin.params = {{"sketch", sk2_fid.str()},
                   {"path", json::array({json::array({0.0, 0.0, 0.0}),
                                         json::array({0.0, 0.0, 20.0})})},
                   {"thin_thickness", 1.0}};
    auto thin_fid = g2.add(std::move(thin));
    Document doc2;
    REQUIRE(g2.regenerate(doc2, &err));
    const Body* tb = doc2.body(g2.feature(thin_fid)->output_body);
    REQUIRE(tb != nullptr);
    REQUIRE(shape::is_valid(tb->shape));
    const double solid_vol = M_PI * 25.0 * 20.0;
    REQUIRE(shape::volume(tb->shape) < solid_vol - 1.0);
}
