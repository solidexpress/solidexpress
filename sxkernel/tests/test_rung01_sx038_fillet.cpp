#include <catch.hpp>

#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/query.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

gp_Pnt face_center(const Document& doc, const EntityId& face) {
    TopoDS_Shape s = doc.resolve(face);
    GProp_GProps props;
    BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
    return props.CentreOfMass();
}

// Planar face nearest z_want whose centre sits inside the slot (|y| small).
EntityId face_at_z(const Document& doc, const EntityId& body, double z_want) {
    EntityId best;
    double best_d = 1e300;
    const Body* b = doc.body(body);
    if (!b) return best;
    for (const auto& fid : b->subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape s = doc.resolve(fid);
        if (s.IsNull() || s.ShapeType() != TopAbs_FACE) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(s));
        if (surf.GetType() != GeomAbs_Plane) continue;
        if (std::abs(surf.Plane().Axis().Direction().Z()) < 0.9) continue;
        const gp_Pnt c = face_center(doc, fid);
        if (std::abs(c.Y()) > 2.0) continue;
        if (c.X() < 18.0 || c.X() > 169.0) continue;
        const double d = std::abs(c.Z() - z_want);
        if (d < best_d) {
            best_d = d;
            best = fid;
        }
    }
    return best;
}

json face_edges(const Document& doc, const EntityId& face) {
    json out = json::array();
    for (const auto& e : edges_of_face(doc, face)) out.push_back(e.str());
    return out;
}

void add_stadium(Sketch& sk) {
    // Centres 18.5 and 168.5, R5: the straight edges are 150 mm.
    const double x0 = 18.5;
    const double x1 = 168.5;
    const double r = 5.0;
    sk.add_line(x0, r, x1, r);
    // Right cap bulges +X (mid angle 0). Left cap bulges −X: end < start, so
    // the profile mid-angle steps by π.
    sk.add_arc(x1, 0.0, r, -M_PI / 2.0, M_PI / 2.0);
    sk.add_line(x1, -r, x0, -r);
    sk.add_arc(x0, 0.0, r, M_PI / 2.0, -M_PI / 2.0);
}

}  // namespace

// The T=14 rebuild used to report limit 0.250: the 0.5 mm wall left between
// the R1 floor fillet and the R1 top fillet was treated as the whole span.
// Slot depth is still 2.5, so the refusal stays the 150 mm line at 1.250.
TEST_CASE("stadium slot floor R1.5 limit stays 1.250 after thickness 14",
          "[rung01][sx038][fillet]") {
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Plate");
    skf.sketch->add_line(0, -20, 200, -20);
    skf.sketch->add_line(200, -20, 200, 20);
    skf.sketch->add_line(200, 20, 0, 20);
    skf.sketch->add_line(0, 20, 0, -20);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    auto ext_id = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body = graph.feature(ext_id)->output_body;

    Feature slot_sk;
    slot_sk.type = FeatureType::Sketch;
    SketchPlane plane;
    plane.origin = {0, 0, 10};
    plane.x_dir = {1, 0, 0};
    plane.y_dir = {0, 1, 0};
    slot_sk.sketch = std::make_shared<Sketch>("Slot", plane);
    add_stadium(*slot_sk.sketch);
    slot_sk.params = {{"support_host", ext_id.str()},
                      {"support_normal", {0.0, 0.0, 1.0}},
                      {"support_side", "max"}};
    auto slot_sk_id = graph.add(std::move(slot_sk));
    Feature slot;
    slot.type = FeatureType::Extrude;
    slot.params = {{"sketch", slot_sk_id.str()},
                   {"distance", -2.5},
                   {"end", "blind"},
                   {"op", "cut"},
                   {"target", ext_id.str()}};
    graph.add(std::move(slot));
    REQUIRE(graph.regenerate(doc, &err));

    auto fillet_face = [&](double z) {
        EntityId face = face_at_z(doc, body, z);
        REQUIRE(!face.is_null());
        json edges = face_edges(doc, face);
        REQUIRE(edges.size() >= 4);
        Feature fil;
        fil.type = FeatureType::Fillet;
        fil.params = {{"target", ext_id.str()}, {"radius", 1.0}, {"edges", edges}};
        graph.add(std::move(fil));
        REQUIRE(graph.regenerate(doc, &err));
    };
    fillet_face(10.0);
    fillet_face(0.0);
    fillet_face(7.5);

    auto refuse = [&](double z, const char* label) {
        EntityId face = face_at_z(doc, body, z);
        REQUIRE(!face.is_null());
        INFO(label << " floor z=" << face_center(doc, face).Z());
        json edges = face_edges(doc, face);
        REQUIRE(edges.size() >= 4);
        Feature too_big;
        too_big.type = FeatureType::Fillet;
        too_big.params = {{"target", ext_id.str()}, {"radius", 1.5}, {"edges", edges}};
        auto bad = graph.add(std::move(too_big));
        std::string ferr;
        REQUIRE_FALSE(graph.regenerate(doc, &ferr));
        INFO(ferr);
        CHECK(ferr.find("limit 1.250") != std::string::npos);
        CHECK(ferr.find("150.000 mm line") != std::string::npos);
        REQUIRE(graph.remove(bad));
        REQUIRE(graph.regenerate(doc, &err));
    };
    refuse(7.5, "T=10");

    json params = graph.feature(ext_id)->params;
    params["distance"] = 14.0;
    REQUIRE(graph.set_params(ext_id, params));
    REQUIRE(graph.regenerate(doc, &err));
    INFO(err);
    EntityId moved = face_at_z(doc, body, 11.5);
    REQUIRE(!moved.is_null());
    CHECK(face_center(doc, moved).Z() == Approx(11.5).margin(0.05));
    refuse(11.5, "T=14");
}
