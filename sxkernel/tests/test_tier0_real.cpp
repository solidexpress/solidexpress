// Tier 0: the features below used to be stand-ins (fused boxes, whole-body
// offsets). Each case here asserts something only the real operation can
// satisfy — a cylindrical bend face, material conserved by the developed
// length, six sheets becoming one solid, a trim that touches one face.
#include <catch.hpp>

#include <cmath>
#include <vector>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sheet_metal.hpp"
#include "sx/sketch.hpp"
#include "sx/surface_ops.hpp"

using namespace sx;
using nlohmann::json;

namespace {

constexpr double kRight = 1.5707963267948966;

EntityId add_primitive(Document& doc, const json& params) {
    Feature f;
    f.type = FeatureType::Primitive;
    f.params = params;
    return doc.graph().add(std::move(f));
}

EntityId body_of(Document& doc, const EntityId& fid) {
    const Feature* f = doc.graph().feature(fid);
    return f ? f->output_body : EntityId{};
}

double face_centroid_z(const TopoDS_Shape& face) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    return props.CentreOfMass().Z();
}

// 1-based face index whose centroid is highest / lowest along Z, in the same
// MapShapes order the document uses for subshape ids.
int face_index_by_z(const TopoDS_Shape& s, bool highest) {
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(s, TopAbs_FACE, faces);
    int best = 0;
    double best_z = highest ? -1e300 : 1e300;
    for (int i = 1; i <= faces.Extent(); ++i) {
        const double z = face_centroid_z(faces(i));
        if (highest ? (z > best_z) : (z < best_z)) {
            best_z = z;
            best = i;
        }
    }
    return best;
}

std::array<double, 6> bbox_of(const Document& doc, const EntityId& body) {
    auto bb = measure::bounding_box(doc, body);
    REQUIRE(bb);
    return {bb->min[0], bb->min[1], bb->min[2], bb->max[0], bb->max[1], bb->max[2]};
}

}  // namespace

TEST_CASE("flange folds a real bend that unfolds to the developed length", "[tier0][sheet]") {
    sheet::FlangeParams p;
    p.length = 30.0;
    p.thickness = 1.5;
    p.k_factor = 0.44;
    p.radius = 1.5;
    p.angle_rad = kRight;

    std::string err;
    auto build = sheet::build_flange(30.0, 30.0, 40.0, p, {}, &err);
    REQUIRE_FALSE(build.folded.IsNull());
    REQUIRE_FALSE(build.flat.IsNull());
    CHECK(build.flat_length ==
          Approx(sheet::flat_length(30.0, 30.0, p.thickness, p.k_factor, p.radius, p.angle_rad)));

    // Two fused boxes have only planar faces; a bend has a cylindrical one.
    CHECK(surf::has_curved_face(build.folded));
    CHECK(shape::count(build.folded).solids == 1);
    // Material is conserved: the folded section equals the flat blank to within
    // the K-factor's departure from the mid-plane.
    CHECK(shape::volume(build.folded) == Approx(shape::volume(build.flat)).epsilon(0.01));

    SECTION("an obtuse bend conserves material too") {
        p.angle_rad = 2.0943951023931953;  // 120 degrees
        auto obtuse = sheet::build_flange(30.0, 30.0, 40.0, p, {}, &err);
        REQUIRE_FALSE(obtuse.folded.IsNull());
        CHECK(surf::has_curved_face(obtuse.folded));
        CHECK(shape::volume(obtuse.folded) == Approx(shape::volume(obtuse.flat)).epsilon(0.01));
        CHECK(obtuse.flat_length > build.flat_length);
    }

    SECTION("a leg shorter than the thickness is refused, not silently built") {
        auto bad = sheet::build_flange(1.0, 30.0, 40.0, p, {}, &err);
        CHECK(bad.folded.IsNull());
        CHECK_FALSE(err.empty());
    }
}

TEST_CASE("flange feature records the flat it unfolds to", "[tier0][sheet]") {
    Document doc;
    Feature fl;
    fl.type = FeatureType::Flange;
    fl.params = {{"length", 30.0}, {"base_length", 30.0}, {"thickness", 1.5},
                 {"k_factor", 0.44}, {"radius", 1.5},    {"angle_rad", kRight},
                 {"width", 40.0}};
    auto fid = doc.graph().add(std::move(fl));
    REQUIRE(doc.graph().regenerate(doc));

    const Feature* f = doc.graph().feature(fid);
    REQUIRE(f);
    REQUIRE(doc.body(f->output_body));
    CHECK(surf::has_curved_face(doc.body(f->output_body)->shape));
    const double flat0 = f->params.at("flat_length").get<double>();
    CHECK(flat0 == Approx(sheet::flat_length(30.0, 30.0, 1.5, 0.44, 1.5, kRight)));
    CHECK(f->params.at("flat_width").get<double>() == Approx(40.0));

    // A longer flange leg develops a longer blank and a heavier part.
    const double vol0 = shape::volume(doc.body(f->output_body)->shape);
    doc.graph().feature(fid)->params["length"] = 45.0;
    REQUIRE(doc.graph().regenerate(doc));
    const Feature* f2 = doc.graph().feature(fid);
    CHECK(f2->params.at("flat_length").get<double>() == Approx(flat0 + 15.0));
    CHECK(shape::volume(doc.body(f2->output_body)->shape) > vol0);
}

TEST_CASE("knit sews six sheets into one solid", "[tier0][surf]") {
    Document doc;
    const TopoDS_Shape box = shape::make_box(20.0, 20.0, 20.0);
    std::vector<EntityId> sheets;
    for (TopExp_Explorer it(box, TopAbs_FACE); it.More(); it.Next())
        sheets.push_back(doc.add_body(it.Current(), "Sheet"));
    REQUIRE(sheets.size() == 6);
    for (const auto& id : sheets) CHECK(shape::count(doc.body(id)->shape).solids == 0);

    json bodies = json::array();
    for (const auto& id : sheets) bodies.push_back(id.str());
    Feature k;
    k.type = FeatureType::Knit;
    k.params = {{"bodies", bodies}};
    doc.graph().add(std::move(k));
    REQUIRE(doc.graph().regenerate(doc));

    const Body* knitted = doc.body(sheets.front());
    REQUIRE(knitted);
    CHECK(shape::count(knitted->shape).solids == 1);
    CHECK(shape::volume(knitted->shape) == Approx(8000.0).margin(1e-6));
    // The sewn sheets are consumed, like boolean tool bodies.
    for (size_t i = 1; i < sheets.size(); ++i) CHECK(doc.body(sheets[i]) == nullptr);
}

TEST_CASE("thicken turns a surface into a solid and refuses a solid", "[tier0][surf]") {
    const TopoDS_Shape plate = shape::make_box(20.0, 20.0, 1.0);
    TopoDS_Shape sheet;
    for (TopExp_Explorer it(plate, TopAbs_FACE); it.More(); it.Next()) {
        if (shape::area(it.Current()) > 399.0) {
            sheet = it.Current();
            break;
        }
    }
    REQUIRE_FALSE(sheet.IsNull());

    std::string err;
    TopoDS_Shape solid = surf::thicken(sheet, 2.0, &err);
    REQUIRE_FALSE(solid.IsNull());
    CHECK(shape::count(solid).solids == 1);
    CHECK(shape::volume(solid) == Approx(800.0).epsilon(0.02));

    // The old whole-body offset happily "thickened" a solid; a real one says no.
    CHECK(surf::thicken(plate, 2.0, &err).IsNull());
    CHECK_FALSE(err.empty());
}

TEST_CASE("replace face trims the picked face only", "[tier0][surf]") {
    Document doc;
    auto fid = add_primitive(doc, {{"kind", "box"}, {"a", 40.0}, {"b", 30.0}, {"c", 10.0}});
    REQUIRE(doc.graph().regenerate(doc));
    const EntityId body = body_of(doc, fid);
    REQUIRE(doc.body(body));
    CHECK(shape::volume(doc.body(body)->shape) == Approx(12000.0).margin(1e-6));

    const int top = face_index_by_z(doc.body(body)->shape, true);
    const EntityId top_id = doc.subshape_id(body, EntityKind::Face, top);
    REQUIRE_FALSE(top_id.is_null());
    CHECK(face_centroid_z(doc.resolve(top_id)) == Approx(10.0).margin(1e-6));

    Feature rf;
    rf.type = FeatureType::ReplaceFace;
    rf.params = {{"target", fid.str()},
                 {"face", top_id.str()},
                 {"plane_origin", {0.0, 0.0, 6.0}},
                 {"plane_normal", {0.0, 0.0, 1.0}}};
    auto rf_id = doc.graph().add(std::move(rf));
    REQUIRE(doc.graph().regenerate(doc));
    // Only the top moved: 40 x 30 x 6, still a six-faced box.
    CHECK(shape::volume(doc.body(body)->shape) == Approx(7200.0).margin(1e-3));
    CHECK(shape::count(doc.body(body)->shape).faces == 6);

    SECTION("picking the bottom face trims the other end") {
        doc.graph().remove(rf_id);
        REQUIRE(doc.graph().regenerate(doc));
        const int bottom = face_index_by_z(doc.body(body)->shape, false);
        Feature low;
        low.type = FeatureType::ReplaceFace;
        low.params = {{"target", fid.str()},
                      {"face_index", bottom},
                      {"plane_origin", {0.0, 0.0, 3.0}},
                      {"plane_normal", {0.0, 0.0, 1.0}}};
        doc.graph().add(std::move(low));
        REQUIRE(doc.graph().regenerate(doc));
        CHECK(shape::volume(doc.body(body)->shape) == Approx(8400.0).margin(1e-3));
    }

    SECTION("a plane that misses the body is a named failure, not a silent offset") {
        doc.graph().remove(rf_id);
        REQUIRE(doc.graph().regenerate(doc));
        Feature miss;
        miss.type = FeatureType::ReplaceFace;
        miss.params = {{"target", fid.str()},
                       {"face_index", 1},
                       {"plane_origin", {0.0, 0.0, 99.0}},
                       {"plane_normal", {0.0, 0.0, 1.0}}};
        doc.graph().add(std::move(miss));
        std::string err;
        CHECK_FALSE(doc.graph().regenerate(doc, &err));
        CHECK(err.find("does not trim") != std::string::npos);
    }
}

TEST_CASE("rib follows its sketch profile", "[tier0][rib]") {
    auto rib_gain = [](const std::vector<std::array<double, 4>>& segments) {
        Document doc;
        auto plate = add_primitive(doc, {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 4.0}});
        REQUIRE(doc.graph().regenerate(doc));
        const EntityId body = body_of(doc, plate);
        const double before = shape::volume(doc.body(body)->shape);

        SketchPlane pl;
        pl.origin = {0, 0, 4};
        auto sk = std::make_shared<Sketch>("Rib profile", pl);
        for (const auto& s : segments) sk->add_line(s[0], s[1], s[2], s[3]);
        Feature skf;
        skf.type = FeatureType::Sketch;
        skf.sketch = sk;
        auto sk_id = doc.graph().add(std::move(skf));

        Feature rib;
        rib.type = FeatureType::Rib;
        rib.params = {{"target", plate.str()},
                      {"sketch", sk_id.str()},
                      {"thickness", 2.0},
                      {"height", 8.0}};
        doc.graph().add(std::move(rib));
        REQUIRE(doc.graph().regenerate(doc));
        REQUIRE(doc.body(body));
        CHECK(shape::count(doc.body(body)->shape).solids == 1);
        return shape::volume(doc.body(body)->shape) - before;
    };

    // One 30 mm leg: 30 x 2 x 8.
    const double one_leg = rib_gain({{5.0, 20.0, 35.0, 20.0}});
    CHECK(one_leg == Approx(480.0).epsilon(0.15));

    // Add a 15 mm leg and the rib grows with the profile, not with a box param.
    const double two_legs = rib_gain({{5.0, 20.0, 35.0, 20.0}, {35.0, 20.0, 35.0, 35.0}});
    CHECK(two_legs == Approx(720.0).epsilon(0.15));
    CHECK(two_legs > one_leg * 1.3);
}

TEST_CASE("rib without a profile is refused", "[tier0][rib]") {
    Document doc;
    auto plate = add_primitive(doc, {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 4.0}});
    Feature rib;
    rib.type = FeatureType::Rib;
    rib.params = {{"target", plate.str()}, {"thickness", 2.0}, {"height", 8.0}};
    doc.graph().add(std::move(rib));
    std::string err;
    CHECK_FALSE(doc.graph().regenerate(doc, &err));
    CHECK(err.find("sketch profile") != std::string::npos);
}

TEST_CASE("wrap debosses along the surface instead of slicing the body", "[tier0][wrap]") {
    auto deboss_drop = [](double half) {
        Document doc;
        auto cyl = add_primitive(doc, {{"kind", "cylinder"}, {"a", 20.0}, {"b", 40.0}});
        REQUIRE(doc.graph().regenerate(doc));
        const EntityId body = body_of(doc, cyl);
        const double before = shape::volume(doc.body(body)->shape);
        const auto bb_before = bbox_of(doc, body);

        // Square on a plane facing the barrel, centred half way up.
        SketchPlane pl;
        pl.origin = {0, -40, 20};
        pl.x_dir = {1, 0, 0};
        pl.y_dir = {0, 0, 1};
        auto sk = std::make_shared<Sketch>("Stamp", pl);
        sk->add_line(-half, -half, half, -half);
        sk->add_line(half, -half, half, half);
        sk->add_line(half, half, -half, half);
        sk->add_line(-half, half, -half, -half);
        Feature skf;
        skf.type = FeatureType::Sketch;
        skf.sketch = sk;
        auto sk_id = doc.graph().add(std::move(skf));

        Feature wrap;
        wrap.type = FeatureType::Wrap;
        wrap.params = {{"target", cyl.str()},
                       {"sketch", sk_id.str()},
                       {"depth", 2.0},
                       {"mode", "deboss"}};
        doc.graph().add(std::move(wrap));
        std::string err;
        if (!doc.graph().regenerate(doc, &err)) FAIL("wrap regenerate: " << err);
        REQUIRE(doc.body(body));

        // The barrel is engraved, so the silhouette does not move.
        const auto bb_after = bbox_of(doc, body);
        for (int i = 0; i < 6; ++i) CHECK(bb_after[i] == Approx(bb_before[i]).margin(1e-6));
        const double drop = before - shape::volume(doc.body(body)->shape);
        CHECK(drop > 0.0);
        // A slab cut straight through would remove roughly 2*half*40*2*half.
        CHECK(drop < 2.0 * half * 40.0 * 2.0 * half * 0.5);
        return drop;
    };

    const double small = deboss_drop(5.0);
    const double large = deboss_drop(10.0);
    CHECK(large > small * 1.5);
}
