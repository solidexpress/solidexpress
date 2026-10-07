#include <catch.hpp>

#include <BRepAdaptor_Surface.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/query.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

bool point_inside(const TopoDS_Shape& shape, const gp_Pnt& p) {
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) {
        BRepClass3d_SolidClassifier cl(ex.Current());
        cl.Perform(p, 1e-6);
        if (cl.State() == TopAbs_IN) return true;
    }
    return false;
}

gp_Pnt edge_midpoint(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.CentreOfMass();
}

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
        GProp_GProps props;
        BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
        const double d = std::abs(props.CentreOfMass().Z() - z_want);
        if (d < best_d) {
            best_d = d;
            best = fid;
        }
    }
    return best;
}

void add_rect(Sketch& sk, double x0, double y0, double x1, double y1) {
    sk.add_line(x0, y0, x1, y0);
    sk.add_line(x1, y0, x1, y1);
    sk.add_line(x1, y1, x0, y1);
    sk.add_line(x0, y1, x0, y0);
}

json ids_json(const std::vector<EntityId>& ids) {
    json out = json::array();
    for (const auto& e : ids) out.push_back(e.str());
    return out;
}

struct Plate {
    Document doc;
    FeatureGraph graph;
    EntityId ext_id;
    EntityId body;
    std::string err;

    // 40 x 30 x 10 plate with a 20 x 10 x 2.5 slot cut from the top. The slot
    // sketch carries support keys, so a thickness edit moves it with the top.
    Plate() {
        Feature skf;
        skf.type = FeatureType::Sketch;
        skf.sketch = std::make_shared<Sketch>("Plate");
        add_rect(*skf.sketch, -20, -15, 20, 15);
        auto sk_id = graph.add(std::move(skf));
        Feature ext;
        ext.type = FeatureType::Extrude;
        ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"},
                      {"end", "blind"}};
        ext_id = graph.add(std::move(ext));
        REQUIRE(graph.regenerate(doc, &err));
        body = graph.feature(ext_id)->output_body;

        Feature slot_sk;
        slot_sk.type = FeatureType::Sketch;
        SketchPlane plane;
        plane.origin = {0, 0, 10};
        plane.x_dir = {1, 0, 0};
        plane.y_dir = {0, 1, 0};
        slot_sk.sketch = std::make_shared<Sketch>("Slot", plane);
        add_rect(*slot_sk.sketch, -10, -5, 10, 5);
        slot_sk.params = {{"support_host", ext_id.str()},
                          {"support_normal", {0.0, 0.0, 1.0}},
                          {"support_side", "max"}};
        auto slot_sk_id = graph.add(std::move(slot_sk));
        Feature slot;
        slot.type = FeatureType::Extrude;
        slot.params = {{"sketch", slot_sk_id.str()}, {"distance", -2.5}, {"end", "blind"},
                       {"op", "cut"}, {"target", ext_id.str()}};
        graph.add(std::move(slot));
        REQUIRE(graph.regenerate(doc, &err));
    }

    EntityId add_fillet(const json& edges, double radius) {
        Feature fil;
        fil.type = FeatureType::Fillet;
        fil.params = {{"target", ext_id.str()}, {"radius", radius}, {"edges", edges}};
        auto id = graph.add(std::move(fil));
        REQUIRE(graph.regenerate(doc, &err));
        return id;
    }

    bool set_thickness(double t) {
        json p = graph.feature(ext_id)->params;
        p["distance"] = t;
        REQUIRE(graph.set_params(ext_id, p));
        err.clear();
        return graph.regenerate(doc, &err);
    }

    const TopoDS_Shape& shape() const { return doc.body(body)->shape; }

    json edges_where(double z, double tol, bool want_outer_x) const {
        json out = json::array();
        const Body* b = doc.body(body);
        for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
            TopoDS_Shape s = doc.resolve(eid);
            if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
            const gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
            if (std::abs(m.Z() - z) > tol) continue;
            if (want_outer_x && std::abs(std::abs(m.X()) - 20.0) > 0.6) continue;
            out.push_back(eid.str());
        }
        return out;
    }
};

}  // namespace

TEST_CASE("face-derived top and slot-floor R1 survive a thickness edit",
          "[rung01][replan12][fillet]") {
    Plate plate;
    const EntityId top = face_at_z(plate.doc, plate.body, 10.0);
    REQUIRE(!top.is_null());
    const auto top_edges = edges_of_face(plate.doc, top);
    REQUIRE(top_edges.size() >= 8);
    plate.add_fillet(ids_json(top_edges), 1.0);
    REQUIRE_FALSE(point_inside(plate.shape(), gp_Pnt(-19.9, 0, 9.9)));

    const EntityId floor = face_at_z(plate.doc, plate.body, 7.5);
    REQUIRE(!floor.is_null());
    const auto floor_edges = edges_of_face(plate.doc, floor);
    REQUIRE(floor_edges.size() >= 4);
    plate.add_fillet(ids_json(floor_edges), 1.0);
    REQUIRE(point_inside(plate.shape(), gp_Pnt(0.0, 4.9, 7.6)));

    REQUIRE(plate.set_thickness(14.0));
    INFO(plate.err);
    CHECK(plate.graph.warnings().empty());
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(-19.9, 0, 13.9)));
    CHECK(point_inside(plate.shape(), gp_Pnt(-19.7, 0, 9.0)));
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(9.9, 0, 13.9)));
    CHECK(point_inside(plate.shape(), gp_Pnt(0.0, 4.9, 11.6)));
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(0.0, 0.0, 12.0)));

    // Back to 10: the same fillets still resolve (cues and faces re-anchored).
    REQUIRE(plate.set_thickness(10.0));
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(-19.9, 0, 9.9)));
    CHECK(point_inside(plate.shape(), gp_Pnt(0.0, 4.9, 7.6)));
}

TEST_CASE("a fillet whose edges are all lost warns by name and the edit stands",
          "[rung01][replan12][fillet]") {
    Plate plate;
    json two = json::array();
    json floor = plate.edges_where(7.5, 0.1, false);
    REQUIRE(floor.size() >= 2);
    two.push_back(floor[0]);
    two.push_back(floor[1]);
    plate.add_fillet(two, 1.0);

    REQUIRE(plate.set_thickness(14.0));
    INFO(plate.err);
    REQUIRE(plate.graph.warnings().size() == 1);
    const std::string msg = plate.graph.warnings()[0].second;
    CHECK(msg.find("fillet") != std::string::npos);
    CHECK(msg.find("all 2 edges lost on rebuild") != std::string::npos);
    CHECK(plate.graph.last_failed_feature().is_null());
}

TEST_CASE("vertical edges of a two-edge fillet scale with thickness",
          "[rung01][replan12][fillet][thick]") {
    Plate plate;
    json corner;
    json other;
    const Body* b = plate.doc.body(plate.body);
    for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = plate.doc.resolve(eid);
        if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
        const gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
        // Outer vertical corners of the 40×30 plate. Slot walls sit at |x|=10.
        if (std::abs(m.Z() - 5.0) > 0.2) continue;
        if (std::abs(std::abs(m.X()) - 20.0) > 0.6) continue;
        if (std::abs(std::abs(m.Y()) - 15.0) > 0.6) continue;
        if (m.X() > 0.0 && m.Y() > 0.0) corner = eid.str();
        else if (other.is_null()) other = eid.str();
    }
    REQUIRE(corner.is_string());
    REQUIRE(other.is_string());
    json two = json::array({corner, other});
    plate.add_fillet(two, 1.0);
    REQUIRE(plate.graph.warnings().empty());

    // Midpoints move 2 mm in Z. The axes stay put, so both edges re-resolve.
    REQUIRE(plate.set_thickness(14.0));
    INFO(plate.err);
    CHECK(plate.graph.warnings().empty());
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(19.95, 14.95, 7.0)));
    CHECK(point_inside(plate.shape(), gp_Pnt(18.5, 13.5, 7.0)));

    // Shorter than the original midpoint (z=5): the cue sits just past the
    // new top and still names the same corner.
    REQUIRE(plate.set_thickness(4.0));
    CHECK(plate.graph.warnings().empty());
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(19.95, 14.95, 2.0)));
}

TEST_CASE("a fillet that loses some edges still builds and warns",
          "[rung01][replan12][fillet]") {
    Plate plate;
    json floor = plate.edges_where(7.5, 0.1, false);
    json bottom = plate.edges_where(0.0, 0.1, false);
    REQUIRE(floor.size() >= 1);
    REQUIRE(bottom.size() >= 1);
    json mixed = json::array();
    mixed.push_back(floor[0]);
    mixed.push_back(bottom[0]);
    plate.add_fillet(mixed, 1.0);
    REQUIRE(plate.graph.warnings().empty());

    REQUIRE(plate.set_thickness(14.0));
    INFO(plate.err);
    REQUIRE(plate.graph.warnings().size() == 1);
    const std::string msg = plate.graph.warnings()[0].second;
    CHECK(msg.find("1 of 2 edges lost on rebuild") != std::string::npos);
    CHECK(msg.find("fillet") != std::string::npos);
}
