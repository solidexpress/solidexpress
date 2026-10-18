#include <catch.hpp>

#include "sx/commands_graph.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/query.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch_regions.hpp"

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

using namespace sx;

namespace {

gp_Pnt face_com(const TopoDS_Shape& face) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    return props.CentreOfMass();
}

EntityId top_face_id(const Document& doc, const Body& body) {
    EntityId best;
    double z = -1e300;
    for (const auto& fid : body.subshape_ids.at(EntityKind::Face)) {
        auto sh = doc.resolve(fid);
        if (sh.IsNull()) continue;
        double fz = face_com(sh).Z();
        if (fz > z) {
            z = fz;
            best = fid;
        }
    }
    return best;
}

}  // namespace

TEST_CASE("SketchRegions: closed rectangle is one clickable area", "[sketch][regions]") {
    Sketch sk("Pad");
    sk.add_line(0, 0, 40, 0);
    sk.add_line(40, 0, 40, 20);
    sk.add_line(40, 20, 0, 20);
    sk.add_line(0, 20, 0, 0);
    auto arranged = SketchRegions::arrange(sk, {});
    REQUIRE(arranged.size() == 1);
    CHECK(arranged.containing_uv(sk, 20, 10) == 0);
    CHECK(arranged.containing_uv(sk, 80, 10) == -1);
}

TEST_CASE("SketchRegions: host face plus chord yields two halves", "[sketch][regions]") {
    Document doc;
    FeatureGraph graph;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    auto box_id = graph.add(std::move(box));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* body = doc.body(graph.feature(box_id)->output_body);
    REQUIRE(body != nullptr);
    EntityId top = top_face_id(doc, *body);
    REQUIRE_FALSE(top.is_null());
    TopoDS_Shape host = doc.resolve(top);
    Sketch sk("Chord");
    sk.set_plane({{0, 0, 10}, {1, 0, 0}, {0, 1, 0}});
    sk.add_line(0, 20, 40, 20);
    auto arranged = SketchRegions::arrange(sk, host);
    REQUIRE(arranged.size() == 2);
    int a = arranged.containing_uv(sk, 20, 30);
    int b = arranged.containing_uv(sk, 20, 10);
    REQUIRE(a >= 0);
    REQUIRE(b >= 0);
    CHECK(a != b);
}

TEST_CASE("feature graph: region pick cuts only that area", "[features][regions]") {
    Document doc;
    FeatureGraph graph;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    auto box_id = graph.add(std::move(box));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* body = doc.body(graph.feature(box_id)->output_body);
    REQUIRE(body != nullptr);
    EntityId top = top_face_id(doc, *body);
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Jaw");
    skf.sketch->set_plane({{0, 0, 10}, {1, 0, 0}, {0, 1, 0}});
    skf.sketch->add_line(10, 10, 30, 10);
    skf.sketch->add_line(30, 10, 30, 30);
    skf.sketch->add_line(30, 30, 10, 30);
    skf.sketch->add_line(10, 30, 10, 10);
    skf.params = {{"host_face", top.str()}, {"support_host", box_id.str()}};
    auto sk_id = graph.add(std::move(skf));
    auto arranged = SketchRegions::arrange(*graph.feature(sk_id)->sketch, doc.resolve(top));
    REQUIRE(arranged.size() >= 2);
    int pocket = arranged.containing_uv(*graph.feature(sk_id)->sketch, 20, 20);
    REQUIRE(pocket >= 0);
    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", sk_id.str()},
                  {"distance", -20.0},
                  {"op", "cut"},
                  {"end", "through_all"},
                  {"target", box_id.str()},
                  {"selected_contours", {pocket}}};
    graph.add(std::move(cut));
    REQUIRE(graph.regenerate(doc, &err));
    double vol = shape::volume(doc.body(graph.feature(box_id)->output_body)->shape);
    CHECK(vol == Approx(40.0 * 40.0 * 10.0 - 20.0 * 20.0 * 10.0).epsilon(1e-3));
}

TEST_CASE("feature graph: face-sketch Blind 1 cut subtracts a pocket", "[features][cut]") {
    Document doc;
    FeatureGraph graph;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    auto box_id = graph.add(std::move(box));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const Body* body = doc.body(graph.feature(box_id)->output_body);
    REQUIRE(body != nullptr);
    const double v0 = shape::volume(body->shape);
    EntityId top = top_face_id(doc, *body);
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Pocket");
    skf.sketch->set_plane({{0, 0, 10}, {1, 0, 0}, {0, 1, 0}});
    skf.sketch->add_line(10, 10, 30, 10);
    skf.sketch->add_line(30, 10, 30, 30);
    skf.sketch->add_line(30, 30, 10, 30);
    skf.sketch->add_line(10, 30, 10, 10);
    skf.params = {{"host_face", top.str()}, {"support_host", box_id.str()}};
    auto sk_id = graph.add(std::move(skf));
    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", sk_id.str()},
                  {"distance", -1.0},
                  {"op", "cut"},
                  {"end", "blind"},
                  {"target", box_id.str()}};
    graph.add(std::move(cut));
    REQUIRE(graph.regenerate(doc, &err));
    double vol = shape::volume(doc.body(graph.feature(box_id)->output_body)->shape);
    CHECK(vol == Approx(v0 - 20.0 * 20.0 * 1.0).epsilon(1e-3));
}

TEST_CASE("face sketch stays on the thinner pad, not the thicker head", "[features][cut]") {
    Document doc;
    FeatureGraph graph;
    Feature handle_sk;
    handle_sk.type = FeatureType::Sketch;
    handle_sk.sketch = std::make_shared<Sketch>("Handle");
    handle_sk.sketch->add_line(0, 0, 80, 0);
    handle_sk.sketch->add_line(80, 0, 80, 20);
    handle_sk.sketch->add_line(80, 20, 0, 20);
    handle_sk.sketch->add_line(0, 20, 0, 0);
    auto hs = graph.add(std::move(handle_sk));
    Feature handle_ex;
    handle_ex.type = FeatureType::Extrude;
    handle_ex.params = {{"sketch", hs.str()}, {"distance", 6.0}, {"op", "new"}, {"end", "blind"}};
    auto he = graph.add(std::move(handle_ex));
    Feature head_sk;
    head_sk.type = FeatureType::Sketch;
    head_sk.sketch = std::make_shared<Sketch>("Head");
    head_sk.sketch->add_line(80, 0, 100, 0);
    head_sk.sketch->add_line(100, 0, 100, 20);
    head_sk.sketch->add_line(100, 20, 80, 20);
    head_sk.sketch->add_line(80, 20, 80, 0);
    auto ds = graph.add(std::move(head_sk));
    Feature head_ex;
    head_ex.type = FeatureType::Extrude;
    head_ex.params = {{"sketch", ds.str()},
                      {"distance", 10.0},
                      {"op", "fuse"},
                      {"end", "blind"},
                      {"target", he.str()}};
    graph.add(std::move(head_ex));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(graph.feature(he)->output_body) != nullptr);
    const double v0 = shape::volume(doc.body(graph.feature(he)->output_body)->shape);
    REQUIRE(v0 > 100.0);
    Feature pocket;
    pocket.type = FeatureType::Sketch;
    pocket.sketch = std::make_shared<Sketch>("Recess");
    pocket.sketch->set_plane({{0, 0, 6}, {1, 0, 0}, {0, 1, 0}});
    pocket.sketch->add_line(10, 5, 70, 5);
    pocket.sketch->add_line(70, 5, 70, 15);
    pocket.sketch->add_line(70, 15, 10, 15);
    pocket.sketch->add_line(10, 15, 10, 5);
    pocket.params = {{"support_host", he.str()},
                     {"support_normal", {0.0, 0.0, 1.0}},
                     {"support_side", "max"}};
    auto ps = graph.add(std::move(pocket));
    Feature cut;
    cut.type = FeatureType::Extrude;
    cut.params = {{"sketch", ps.str()},
                  {"distance", -1.0},
                  {"op", "cut"},
                  {"end", "blind"},
                  {"target", he.str()}};
    graph.add(std::move(cut));
    REQUIRE(graph.regenerate(doc, &err));
    const double vol = shape::volume(doc.body(graph.feature(he)->output_body)->shape);
    CHECK(v0 - vol == Approx(60.0 * 10.0 * 1.0).epsilon(1e-2));
}
