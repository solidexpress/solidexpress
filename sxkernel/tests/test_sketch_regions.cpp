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
