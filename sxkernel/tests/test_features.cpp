#include <catch.hpp>
#include <cmath>

#include <cstdio>

#include "sx/command.hpp"
#include "sx/commands_graph.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch_json.hpp"
#include "sx/sxp.hpp"

using namespace sx;
using nlohmann::json;

static std::shared_ptr<Sketch> rect_sketch(double w, double h) {
    auto sk = std::make_shared<Sketch>("Rect");
    sk->add_line(0, 0, w, 0);
    sk->add_line(w, 0, w, h);
    sk->add_line(w, h, 0, h);
    sk->add_line(0, h, 0, 0);
    return sk;
}

TEST_CASE("sketch json round trip", "[features][sketchjson]") {
    auto sk = std::make_shared<Sketch>("S");
    auto l = sk->add_line(0, 0, 10, 5);
    auto c = sk->add_circle(3, 3, 2);
    sk->set_construction(c, true);
    sk->add_constraint(ConstraintType::Horizontal, {{l, PointRole::Self}});
    sk->add_constraint(ConstraintType::Distance, {{l, PointRole::Start}, {l, PointRole::End}}, 12.0);

    auto restored = sketch_from_json(sketch_to_json(*sk));
    REQUIRE(restored->id() == sk->id());
    REQUIRE(restored->entities().size() == 2);
    REQUIRE(restored->constraints().size() == 2);
    REQUIRE(restored->entity(l) != nullptr);
    REQUIRE(restored->entity(c)->construction);
    REQUIRE(restored->constraints()[1].value == Approx(12.0));
    auto pos = restored->point_pos({l, PointRole::End});
    REQUIRE((*pos)[0] == Approx(10.0));
    REQUIRE((*pos)[1] == Approx(5.0));
}

TEST_CASE("feature graph: primitive + parametric edit + regenerate", "[features]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto fid = graph.add(std::move(box));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0));

    // Parametric edit: change a dimension, regenerate; body id is stable.
    json p = graph.feature(fid)->params;
    p["c"] = 25.0;
    REQUIRE(graph.set_params(fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(2500.0));
    REQUIRE(doc.body_ids().size() == 1);  // no duplicate bodies
}

TEST_CASE("feature graph: cylinder respects z_dir placement", "[features]") {
    Document doc;
    FeatureGraph graph;

    Feature cyl;
    cyl.type = FeatureType::Primitive;
    // Radius 4, height 20, axis along +X from origin.
    cyl.params = {{"kind", "cylinder"},
                  {"a", 4.0},
                  {"b", 20.0},
                  {"origin", json::array({0.0, 0.0, 0.0})},
                  {"z_dir", json::array({1.0, 0.0, 0.0})},
                  {"x_dir", json::array({0.0, 0.0, -1.0})}};
    auto fid = graph.add(std::move(cyl));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(fid)->output_body;
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(shape::volume(b->shape) == Approx(M_PI * 16.0 * 20.0).epsilon(1e-6));
    auto com = shape::center_of_mass(b->shape);
    REQUIRE(com[0] == Approx(10.0).margin(1e-3));
    REQUIRE(com[1] == Approx(0.0).margin(1e-3));
    REQUIRE(com[2] == Approx(0.0).margin(1e-3));
}

TEST_CASE("feature graph: sketch -> extrude -> fillet chain", "[features]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = rect_sketch(40, 30);
    auto sketch_fid = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sketch_fid.str()}, {"distance", 20.0}, {"op", "new"}};
    auto ext_fid = graph.add(std::move(ext));

    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.params = {{"target", ext_fid.str()}, {"radius", 2.0}, {"edges", json::array({1})}};
    auto fil_fid = graph.add(std::move(fil));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(ext_fid)->output_body;
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    double vol = shape::volume(b->shape);
    REQUIRE(vol < 24000.0);
    REQUIRE(vol > 23900.0);  // one 2mm fillet on a 24000 solid
    REQUIRE(shape::count(b->shape).faces == 7);

    // Suppress the fillet: sharp box returns.
    REQUIRE(graph.set_suppressed(fil_fid, true));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(24000.0).epsilon(1e-9));

    // Edit the sketch dimension via the embedded sketch (parametric rebuild).
    graph.feature(fil_fid)->suppressed = false;
    Feature* skf_ptr = graph.feature(sketch_fid);
    // Widen the rectangle: move the two right-side x params from 40 to 50.
    auto lines = skf_ptr->sketch->entities();
    // rebuild sketch simpler: replace with a new one, same feature
    skf_ptr->sketch = rect_sketch(50, 30);
    REQUIRE(graph.regenerate(doc, &err));
    double vol2 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol2 > 29900.0);
    REQUIRE(vol2 < 30000.0);  // 50*30*20 minus fillet
}

TEST_CASE("feature graph: extrude cut into target", "[features]") {
    Document doc;
    FeatureGraph graph;

    Feature base;
    base.type = FeatureType::Primitive;
    base.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    auto base_fid = graph.add(std::move(base));

    // Hole sketch: circle r=5 at (20,20) on the ground plane.
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Hole");
    skf.sketch->add_circle(20, 20, 5);
    auto sketch_fid = graph.add(std::move(skf));

    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", sketch_fid.str()}, {"distance", 10.0},
                  {"op", "cut"}, {"target", base_fid.str()}};
    graph.add(std::move(cut));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(base_fid)->output_body;
    double expected = 40.0 * 40.0 * 10.0 - M_PI * 25.0 * 10.0;
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(expected).epsilon(1e-4));
    REQUIRE(doc.body_ids().size() == 1);
}

TEST_CASE("feature graph: dependency protection and json round trip", "[features]") {
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = rect_sketch(10, 10);
    auto sketch_fid = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sketch_fid.str()}, {"distance", 5.0}, {"op", "new"}};
    auto ext_fid = graph.add(std::move(ext));

    REQUIRE(graph.has_dependents(sketch_fid));
    REQUIRE(!graph.remove(sketch_fid));  // protected
    REQUIRE(graph.remove(ext_fid));      // leaf is removable
    REQUIRE(!graph.has_dependents(sketch_fid));

    // Round trip through JSON.
    Feature ext2;
    ext2.type = FeatureType::Extrude;
    ext2.params = {{"sketch", sketch_fid.str()}, {"distance", 7.0}, {"op", "new"}};
    auto ext2_fid = graph.add(std::move(ext2));

    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.timeline().size() == 2);
    REQUIRE(restored.feature(sketch_fid) != nullptr);
    REQUIRE(restored.feature(ext2_fid) != nullptr);
    REQUIRE(restored.feature(ext2_fid)->output_body ==
            graph.feature(ext2_fid)->output_body);

    Document doc;
    std::string err;
    REQUIRE(restored.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(restored.feature(ext2_fid)->output_body)->shape) ==
            Approx(700.0).epsilon(1e-9));
}

TEST_CASE("feature graph persists through .sxp save/load", "[features][sxp]") {
    const std::string path = "/tmp/sx_features_roundtrip.sxp";

    Document doc;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = rect_sketch(20, 10);
    auto sketch_fid = doc.graph().add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sketch_fid.str()}, {"distance", 5.0}, {"op", "new"}};
    auto ext_fid = doc.graph().add(std::move(ext));

    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    EntityId body_id = doc.graph().feature(ext_fid)->output_body;
    REQUIRE(save_sxp(doc, path, &err));

    Document loaded;
    REQUIRE(load_sxp(loaded, path, &err));
    REQUIRE(loaded.graph().timeline().size() == 2);
    REQUIRE(loaded.body(body_id) != nullptr);  // body restored from brep

    // Parametric edit after load: change distance and regenerate.
    json p = loaded.graph().feature(ext_fid)->params;
    p["distance"] = 12.0;
    REQUIRE(loaded.graph().set_params(ext_fid, p));
    REQUIRE(loaded.graph().regenerate(loaded, &err));
    REQUIRE(shape::volume(loaded.body(body_id)->shape) == Approx(20.0 * 10.0 * 12.0).epsilon(1e-9));
    std::remove(path.c_str());
}

TEST_CASE("feature graph: failure reports offending feature", "[features]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Open");
    skf.sketch->add_line(0, 0, 10, 0);  // open profile
    auto sketch_fid = graph.add(std::move(skf));

    Feature ext;
    ext.name = "BadPad";
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sketch_fid.str()}, {"distance", 5.0}, {"op", "new"}};
    graph.add(std::move(ext));

    std::string err;
    REQUIRE(!graph.regenerate(doc, &err));
    REQUIRE(err.find("BadPad") != std::string::npos);
}

TEST_CASE("graph snapshot command: undo/redo restores timeline and bodies", "[features][undo]") {
    Document doc;
    CommandStack stack;

    // Edit 1: add a box through a snapshot command.
    json empty = doc.graph().to_json();
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto fid = doc.graph().add(std::move(box));
    EntityId body_id = doc.graph().feature(fid)->output_body;
    json with_box = doc.graph().to_json();
    stack.push(doc, std::make_unique<GraphSnapshotCommand>("add box", empty, with_box));
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0));

    // Edit 2: resize the box.
    json p = doc.graph().feature(fid)->params;
    p["a"] = 20.0;
    REQUIRE(doc.graph().set_params(fid, p));
    stack.push(doc, std::make_unique<GraphSnapshotCommand>("resize", with_box,
                                                           doc.graph().to_json()));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(2000.0));

    // Undo resize: original size, stable body id.
    REQUIRE(stack.undo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0));

    // Undo add: body gone, timeline empty.
    REQUIRE(stack.undo(doc));
    REQUIRE(doc.body(body_id) == nullptr);
    REQUIRE(doc.graph().timeline().empty());

    // Redo both: back to the resized box under the same id.
    REQUIRE(stack.redo(doc));
    REQUIRE(stack.redo(doc));
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(2000.0));
}


TEST_CASE("feature graph: thin extrude open line", "[features][thin]") {
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("OpenLine");
    skf.sketch->add_line(0, 0, 40, 0);
    auto sketch_fid = graph.add(std::move(skf));

    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sketch_fid.str()},
                  {"distance", 10.0},
                  {"thin_thickness", 5.0},
                  {"op", "new"}};
    auto ext_fid = graph.add(std::move(ext));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(ext_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(2000.0).epsilon(1e-6));
}

TEST_CASE("feature graph: thin extrude flip_side changes COM", "[features][thin]") {
    auto run = [](bool flip) {
        Document doc;
        FeatureGraph graph;

        Feature skf;
        skf.type = FeatureType::Sketch;
        skf.sketch = std::make_shared<Sketch>("OpenLine");
        skf.sketch->add_line(0, 0, 40, 0);
        auto sketch_fid = graph.add(std::move(skf));

        Feature ext;
        ext.type = FeatureType::Extrude;
        ext.params = {{"sketch", sketch_fid.str()},
                      {"distance", 10.0},
                      {"thin_thickness", 5.0},
                      {"flip_side", flip},
                      {"op", "new"}};
        auto ext_fid = graph.add(std::move(ext));

        std::string err;
        REQUIRE(graph.regenerate(doc, &err));
        EntityId body_id = graph.feature(ext_fid)->output_body;
        REQUIRE(doc.body(body_id) != nullptr);
        return shape::center_of_mass(doc.body(body_id)->shape);
    };

    auto com_a = run(false);
    auto com_b = run(true);
    REQUIRE(com_a[1] == Approx(-com_b[1]).margin(1e-3));
    REQUIRE(std::abs(com_a[1] - com_b[1]) > 1e-3);
}

TEST_CASE("feature graph: open-profile cut Flip Side to Cut", "[features][opencut]") {
    // SW Cut Extrude video richness: open line divides the part; Flip Side
    // chooses which half-space is removed (not a thin wall).
    auto run = [](bool flip) {
        Document doc;
        FeatureGraph graph;

        Feature box;
        box.type = FeatureType::Primitive;
        box.params = {{"kind", "box"}, {"a", 100.0}, {"b", 60.0}, {"c", 30.0}};
        auto box_fid = graph.add(std::move(box));

        Feature skf;
        skf.type = FeatureType::Sketch;
        SketchPlane pl;
        pl.origin = {0, 0, 30};
        pl.x_dir = {1, 0, 0};
        pl.y_dir = {0, 1, 0};
        skf.sketch = std::make_shared<Sketch>("OpenCut", pl);
        // Vertical divider at x=20 across the 60 mm width.
        skf.sketch->add_line(20, 0, 20, 60);
        auto sketch_fid = graph.add(std::move(skf));

        Feature ext;
        ext.type = FeatureType::Extrude;
        ext.params = {{"sketch", sketch_fid.str()},
                      {"distance", -30.0},
                      {"end", "through_all"},
                      {"op", "cut"},
                      {"target", box_fid.str()},
                      {"flip_side", flip}};
        graph.add(std::move(ext));

        std::string err;
        REQUIRE(graph.regenerate(doc, &err));
        EntityId body_id = graph.feature(box_fid)->output_body;
        REQUIRE(doc.body(body_id) != nullptr);
        return shape::volume(doc.body(body_id)->shape);
    };

    double v0 = run(false);
    double v1 = run(true);
    // Full brick = 180000. One side ~20*60*30=36000, other ~80*60*30=144000.
    REQUIRE(std::abs(v0 - v1) > 50'000.0);
    REQUIRE((v0 + v1) == Approx(180'000.0).margin(1.0));
}

TEST_CASE("feature graph: selected contours fuse disjoint regions", "[features][contours]") {
    // Two side-by-side squares must extrude as solid union — not outer+hole
    // (that was the unacceptable shortcut vs SW Selected Contours).
    Document doc;
    FeatureGraph graph;

    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("TwoPads");
    // Square A: (0,0)-(10,10)
    skf.sketch->add_line(0, 0, 10, 0);
    skf.sketch->add_line(10, 0, 10, 10);
    skf.sketch->add_line(10, 10, 0, 10);
    skf.sketch->add_line(0, 10, 0, 0);
    // Square B: (20,0)-(30,10)
    skf.sketch->add_line(20, 0, 30, 0);
    skf.sketch->add_line(30, 0, 30, 10);
    skf.sketch->add_line(30, 10, 20, 10);
    skf.sketch->add_line(20, 10, 20, 0);
    auto sketch_fid = graph.add(std::move(skf));

    std::string cerr;
    auto contours = graph.feature(sketch_fid)->sketch->contour_faces(&cerr);
    REQUIRE(contours.size() == 2);

    Feature ext_all;
    ext_all.type = FeatureType::Extrude;
    ext_all.params = {{"sketch", sketch_fid.str()}, {"distance", 5.0}, {"op", "new"}};
    auto ext_all_id = graph.add(std::move(ext_all));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    double vol_all =
        shape::volume(doc.body(graph.feature(ext_all_id)->output_body)->shape);
    REQUIRE(vol_all == Approx(2.0 * 10.0 * 10.0 * 5.0).epsilon(1e-6));

    // Select only contour 0 → half the volume.
    Document doc2;
    FeatureGraph graph2;
    Feature sk2;
    sk2.type = FeatureType::Sketch;
    sk2.sketch = std::make_shared<Sketch>("OnePad");
    sk2.sketch->add_line(0, 0, 10, 0);
    sk2.sketch->add_line(10, 0, 10, 10);
    sk2.sketch->add_line(10, 10, 0, 10);
    sk2.sketch->add_line(0, 10, 0, 0);
    sk2.sketch->add_line(20, 0, 30, 0);
    sk2.sketch->add_line(30, 0, 30, 10);
    sk2.sketch->add_line(30, 10, 20, 10);
    sk2.sketch->add_line(20, 10, 20, 0);
    auto sk2_id = graph2.add(std::move(sk2));
    Feature ext1;
    ext1.type = FeatureType::Extrude;
    ext1.params = {{"sketch", sk2_id.str()},
                   {"distance", 5.0},
                   {"op", "new"},
                   {"selected_contours", {0}}};
    auto ext1_id = graph2.add(std::move(ext1));
    REQUIRE(graph2.regenerate(doc2, &err));
    double vol1 = shape::volume(doc2.body(graph2.feature(ext1_id)->output_body)->shape);
    REQUIRE(vol1 == Approx(10.0 * 10.0 * 5.0).epsilon(1e-6));
}

TEST_CASE("contour_faces splits a circle by a shared chord", "[sketch][contours]") {
    // Video 2 topology: a closed circle plus a line that shares the arc.
    // Two D-regions, not the full disk and not an open-loop failure.
    Sketch sk("ChordedCircle");
    sk.add_circle(0, 0, 10);
    sk.add_line(-10, 0, 10, 0);
    std::string err;
    auto contours = sk.contour_faces(&err);
    REQUIRE(contours.size() == 2);
    const double half = 0.5 * 3.141592653589793 * 100.0;
    CHECK(shape::area(contours[0]) == Approx(half).epsilon(1e-3));
    CHECK(shape::area(contours[1]) == Approx(half).epsilon(1e-3));
}

TEST_CASE("contour_faces pliers head: circle plus exterior nose", "[sketch][contours]") {
    // Video 2 Boss-Extrude1: disk + tapered nose that shares the circle's arc.
    Sketch sk("PliersHead");
    sk.add_circle(0, 0, 10);
    // Points (-6,8) and (6,8) lie on the circle (36+64=100).
    sk.add_line(-6, 8, -3, 22);
    sk.add_line(-3, 22, 3, 22);
    sk.add_line(3, 22, 6, 8);
    std::string err;
    auto contours = sk.contour_faces(&err);
    REQUIRE(contours.size() == 2);
    const double disk = 3.141592653589793 * 100.0;
    // Exterior nose = trapezoid minus the circular cap (arc bows into the
    // trapezoid). Segment height 2 on r=10: (r²/2)(θ − sin θ), θ = 2 acos(0.8).
    const double theta = 2.0 * std::acos(0.8);
    const double segment = 50.0 * (theta - std::sin(theta));
    const double nose = 0.5 * (12.0 + 6.0) * 14.0 - segment;
    CHECK(shape::area(contours[0]) == Approx(disk).epsilon(1e-3));
    CHECK(shape::area(contours[1]) == Approx(nose).epsilon(1e-2));

    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("PliersHead");
    skf.sketch->add_circle(0, 0, 10);
    skf.sketch->add_line(-6, 8, -3, 22);
    skf.sketch->add_line(-3, 22, 3, 22);
    skf.sketch->add_line(3, 22, 6, 8);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 8.0}, {"op", "new"}};
    auto ext_id = graph.add(std::move(ext));
    REQUIRE(graph.regenerate(doc, &err));
    double vol = shape::volume(doc.body(graph.feature(ext_id)->output_body)->shape);
    CHECK(vol == Approx((disk + nose) * 8.0).epsilon(1e-3));
}

TEST_CASE("contour_faces keeps nested wire as a hole", "[sketch][contours]") {
    Sketch sk("PlateHole");
    sk.add_line(0, 0, 40, 0);
    sk.add_line(40, 0, 40, 30);
    sk.add_line(40, 30, 0, 30);
    sk.add_line(0, 30, 0, 0);
    sk.add_circle(20, 15, 5);
    std::string err;
    auto contours = sk.contour_faces(&err);
    REQUIRE(contours.size() == 1);
    // Solid area ≈ 40*30 - π*25.
    REQUIRE(shape::area(contours[0]) == Approx(1200.0 - 3.141592653589793 * 25.0).epsilon(1e-3));
}
