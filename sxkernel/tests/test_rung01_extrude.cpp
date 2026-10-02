#include <catch.hpp>

#include "test_temp.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>
#include <tuple>

#ifdef _WIN32
#define popen _popen
#define pclose _pclose
#endif

#include <gp_Vec.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/query.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/solver.hpp"

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

void z_extent(const TopoDS_Shape& shape, double& zmin, double& zmax) {
    Bnd_Box box;
    BRepBndLib::Add(shape, box);
    double xmin, ymin, z0, xmax, ymax, z1;
    box.Get(xmin, ymin, z0, xmax, ymax, z1);
    zmin = z0;
    zmax = z1;
}

std::shared_ptr<Sketch> plate_sketch(double half) {
    auto sk = std::make_shared<Sketch>("Plate");
    sk->add_line(-half, -half, half, -half);
    sk->add_line(half, -half, half, half);
    sk->add_line(half, half, -half, half);
    sk->add_line(-half, half, -half, -half);
    return sk;
}

EntityId lowest_planar_z(const Document& doc, const Body& body) {
    EntityId best;
    double best_z = 1e300;
    auto it = body.subshape_ids.find(EntityKind::Face);
    if (it == body.subshape_ids.end()) return best;
    for (const auto& id : it->second) {
        TopoDS_Shape s = doc.resolve(id);
        if (s.IsNull() || s.ShapeType() != TopAbs_FACE) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(s));
        if (surf.GetType() != GeomAbs_Plane) continue;
        if (std::abs(surf.Plane().Axis().Direction().Z()) < 0.9) continue;
        GProp_GProps props;
        BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
        const double z = props.CentreOfMass().Z();
        if (z < best_z) {
            best_z = z;
            best = id;
        }
    }
    return best;
}

gp_Pnt edge_midpoint(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.CentreOfMass();
}

void add_hex(Sketch& sk, double across_flats) {
    // Vertices on ±X, flats at y = ±across_flats/2.
    const double R = across_flats / std::sqrt(3.0);
    for (int i = 0; i < 6; ++i) {
        const double a0 = i * M_PI / 3.0;
        const double a1 = (i + 1) * M_PI / 3.0;
        sk.add_line(R * std::cos(a0), R * std::sin(a0), R * std::cos(a1), R * std::sin(a1));
    }
}

// Outer boundary of the wrench blank: left semicircle Ø20, shaft lines at
// y = ±10, major arc of the Ø45 head. One closed wire, concave neck corners.
void add_wrench_blank(Sketch& sk, double* x_neck = nullptr) {
    const double r_head = 22.5;
    const double dx = std::sqrt(r_head * r_head - 10.0 * 10.0);
    const double xhit = 200.0 - dx;
    if (x_neck) *x_neck = xhit;
    const double ang = std::atan2(10.0, -dx);
    sk.add_arc(0, 0, 10.0, M_PI / 2.0, 3.0 * M_PI / 2.0);
    sk.add_line(0, -10, xhit, -10);
    sk.add_arc(200.0, 0, r_head, -ang, ang);
    sk.add_line(xhit, 10, 0, 10);
}

double min_z_in_3mf(const std::string& path) {
    std::string cmd = "unzip -p \"" + path + "\" 3D/3dmodel.model";
    FILE* pipe = popen(cmd.c_str(), "r");
    REQUIRE(pipe != nullptr);
    double zmin = 1e300;
    std::string xml;
    char buf[4096];
    while (fgets(buf, sizeof(buf), pipe)) xml += buf;
    pclose(pipe);
    std::size_t pos = 0;
    while ((pos = xml.find("z=\"", pos)) != std::string::npos) {
        pos += 3;
        zmin = std::min(zmin, std::strtod(xml.c_str() + pos, nullptr));
    }
    return zmin;
}

}  // namespace

TEST_CASE("to_face cut follows the bottom face when the plate thickens", "[rung01][extrude]") {
    auto run = [](const char* end, double cut_distance, bool use_bottom_face) {
        Document doc;
        FeatureGraph graph;
        Feature skf;
        skf.type = FeatureType::Sketch;
        skf.sketch = plate_sketch(20.0);
        auto plate_sk = graph.add(std::move(skf));
        Feature ext;
        ext.type = FeatureType::Extrude;
        ext.params = {{"sketch", plate_sk.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
        auto ext_id = graph.add(std::move(ext));
        std::string err;
        REQUIRE(graph.regenerate(doc, &err));
        EntityId body = graph.feature(ext_id)->output_body;
        REQUIRE(doc.body(body) != nullptr);
        EntityId bottom;
        if (use_bottom_face) {
            bottom = lowest_planar_z(doc, *doc.body(body));
            REQUIRE(!bottom.is_null());
        }

        Feature cut_sk;
        cut_sk.type = FeatureType::Sketch;
        SketchPlane pl;
        pl.origin = {0, 0, 10};
        pl.x_dir = {1, 0, 0};
        pl.y_dir = {0, 1, 0};
        cut_sk.sketch = std::make_shared<Sketch>("Cut", pl);
        cut_sk.sketch->add_circle(0, 0, 4.0);
        auto cut_sk_id = graph.add(std::move(cut_sk));

        Feature cut;
        cut.type = FeatureType::Extrude;
        cut.params = {{"sketch", cut_sk_id.str()},
                      {"distance", cut_distance},
                      {"end", end},
                      {"op", "cut"},
                      {"target", ext_id.str()}};
        if (use_bottom_face) cut.params["to_face"] = bottom.str();
        graph.add(std::move(cut));
        REQUIRE(graph.regenerate(doc, &err));

        json p = graph.feature(ext_id)->params;
        p["distance"] = 14.0;
        REQUIRE(graph.set_params(ext_id, p));
        REQUIRE(graph.regenerate(doc, &err));
        const TopoDS_Shape& shape = doc.body(body)->shape;
        double z0, z1;
        z_extent(shape, z0, z1);
        return std::tuple<double, double, bool, bool, bool>{
            z0, z1,
            point_inside(shape, gp_Pnt(0, 0, 0.5)),
            point_inside(shape, gp_Pnt(0, 0, 7.0)),
            point_inside(shape, gp_Pnt(0, 0, 13.5))};
    };

    auto [z0, z1, in_lo, in_mid, in_hi] = run("to_face", -10.0, true);
    CHECK(z0 == Approx(0.0).margin(0.05));
    CHECK(z1 == Approx(14.0).margin(0.05));
    CHECK_FALSE(in_lo);
    CHECK_FALSE(in_mid);
    CHECK_FALSE(in_hi);

    auto blind = run("blind", -10.0, false);
    CHECK(std::get<1>(blind) == Approx(14.0).margin(0.05));
    // Blind 10 from the original top plane leaves the thickened cap solid.
    CHECK(std::get<4>(blind));
}

TEST_CASE("hexagon plus inner circle extrudes a solid with a hole", "[rung01][profile]") {
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Hex");
    add_hex(*skf.sketch, 20.0);
    skf.sketch->add_circle(0, 0, 5.0);
    std::string cerr;
    auto contours = skf.sketch->contour_faces(&cerr);
    INFO(cerr);
    REQUIRE(contours.size() == 1);

    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 7.5}, {"op", "new"}, {"end", "blind"}};
    auto ext_id = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const TopoDS_Shape& shape = doc.body(graph.feature(ext_id)->output_body)->shape;
    double z0, z1;
    z_extent(shape, z0, z1);
    CHECK(z1 - z0 == Approx(7.5).margin(0.05));
    CHECK_FALSE(point_inside(shape, gp_Pnt(0, 0, 3.75)));
    CHECK(point_inside(shape, gp_Pnt(0, 8, 3.75)));
}

TEST_CASE("solved coincident hex still closes", "[rung01][profile]") {
    Sketch sk("SloppyHex");
    const double R = 20.0 / std::sqrt(3.0);
    std::vector<EntityId> lines;
    for (int i = 0; i < 6; ++i) {
        const double a0 = i * M_PI / 3.0;
        const double a1 = (i + 1) * M_PI / 3.0;
        // 0.05 mm gap at each corner — coincident constraints must close it.
        const double gap = 0.05;
        gp_Vec dir(std::cos(a1) - std::cos(a0), std::sin(a1) - std::sin(a0), 0);
        dir.Normalize();
        lines.push_back(sk.add_line(
            R * std::cos(a0) + gap * dir.X(), R * std::sin(a0) + gap * dir.Y(),
            R * std::cos(a1) - gap * dir.X(), R * std::sin(a1) - gap * dir.Y()));
    }
    for (int i = 0; i < 6; ++i) {
        sk.add_constraint(ConstraintType::Coincident,
                          {{lines[i], PointRole::End},
                           {lines[(i + 1) % 6], PointRole::Start}});
    }
    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    sk.add_circle(0, 0, 5.0);
    std::string err;
    auto contours = sk.contour_faces(&err);
    INFO(err);
    REQUIRE(contours.size() == 1);
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>(sk);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 7.5}, {"op", "new"}};
    auto ext_id = graph.add(std::move(ext));
    REQUIRE(graph.regenerate(doc, &err));
    const TopoDS_Shape& shape = doc.body(graph.feature(ext_id)->output_body)->shape;
    CHECK_FALSE(point_inside(shape, gp_Pnt(0, 0, 3.0)));
    CHECK(point_inside(shape, gp_Pnt(0, 8, 3.0)));
}

TEST_CASE("sketch extrude from z=0 exports with min z at 0", "[rung01][export]") {
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = plate_sketch(10.0);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}};
    graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    const std::string path = sx::test::temp_path("sx_rung01_plate.3mf");
    REQUIRE(interop::export_3mf(doc, path, &err));
    const double zmin = min_z_in_3mf(path);
    std::remove(path.c_str());
    CHECK(zmin == Approx(0.0).margin(0.01));
}

TEST_CASE("wrench neck fillet R10, face fillets R1, slot floor limit", "[rung01][fillet]") {
    Document doc;
    FeatureGraph graph;
    double x_neck = 0;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Wrench");
    add_wrench_blank(*skf.sketch, &x_neck);
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
    SketchPlane slot_plane;
    slot_plane.origin = {0, 0, 10};
    slot_plane.x_dir = {1, 0, 0};
    slot_plane.y_dir = {0, 1, 0};
    slot_sk.sketch = std::make_shared<Sketch>("Slot", slot_plane);
    const double x0 = 13.5, x1 = 173.5;
    slot_sk.sketch->add_line(x0, -5, x1, -5);
    slot_sk.sketch->add_line(x1, -5, x1, 5);
    slot_sk.sketch->add_line(x1, 5, x0, 5);
    slot_sk.sketch->add_line(x0, 5, x0, -5);
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

    json neck_edges = json::array();
    const Body* b = doc.body(body);
    for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull()) continue;
        gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
        if (std::abs(m.X() - x_neck) < 1.5 && std::abs(std::abs(m.Y()) - 10.0) < 0.5 &&
            std::abs(m.Z() - 5.0) < 1.0)
            neck_edges.push_back(eid.str());
    }
    REQUIRE(neck_edges.size() == 2);

    Feature neck;
    neck.type = FeatureType::Fillet;
    neck.params = {{"target", ext_id.str()}, {"radius", 10.0}, {"edges", neck_edges}};
    graph.add(std::move(neck));
    REQUIRE(graph.regenerate(doc, &err));
    {
        const TopoDS_Shape& shape = doc.body(body)->shape;
        CHECK(point_inside(shape, gp_Pnt(179.0, 10.5, 5.0)));
        CHECK(point_inside(shape, gp_Pnt(179.0, -10.5, 5.0)));
        CHECK_FALSE(point_inside(shape, gp_Pnt(174.0, 12.5, 5.0)));
    }

    auto face_at = [&](double z_want, double y_abs_max) {
        EntityId best;
        double best_d = 1e300;
        for (const auto& fid : doc.body(body)->subshape_ids.at(EntityKind::Face)) {
            TopoDS_Shape s = doc.resolve(fid);
            if (s.IsNull() || s.ShapeType() != TopAbs_FACE) continue;
            BRepAdaptor_Surface surf(TopoDS::Face(s));
            if (surf.GetType() != GeomAbs_Plane) continue;
            if (std::abs(surf.Plane().Axis().Direction().Z()) < 0.9) continue;
            GProp_GProps props;
            BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
            gp_Pnt c = props.CentreOfMass();
            if (std::abs(c.Y()) > y_abs_max) continue;
            const double d = std::abs(c.Z() - z_want);
            if (d < best_d) {
                best_d = d;
                best = fid;
            }
        }
        return best;
    };

    EntityId floor = face_at(7.5, 2.0);
    REQUIRE(!floor.is_null());
    auto floor_edges = edges_of_face(doc, floor);
    REQUIRE(floor_edges.size() >= 4);
    json floor_json = json::array();
    for (const auto& e : floor_edges) floor_json.push_back(e.str());

    const double vol_before = shape::volume(doc.body(body)->shape);
    Feature too_big;
    too_big.type = FeatureType::Fillet;
    too_big.params = {{"target", ext_id.str()}, {"radius", 1.5}, {"edges", floor_json}};
    auto bad_id = graph.add(std::move(too_big));
    std::string ferr;
    REQUIRE_FALSE(graph.regenerate(doc, &ferr));
    INFO(ferr);
    CHECK(ferr.find("1.25") != std::string::npos);
    CHECK(shape::volume(doc.body(body)->shape) == Approx(vol_before).margin(1e-4));
    REQUIRE(graph.remove(bad_id));
    REQUIRE(graph.regenerate(doc, &err));
    CHECK(shape::volume(doc.body(body)->shape) == Approx(vol_before).margin(1e-3));

    Feature floor_fil;
    floor_fil.type = FeatureType::Fillet;
    floor_fil.params = {{"target", ext_id.str()}, {"radius", 1.0}, {"edges", floor_json}};
    graph.add(std::move(floor_fil));
    REQUIRE(graph.regenerate(doc, &err));
    CHECK(point_inside(doc.body(body)->shape, gp_Pnt(93.5, 4.9, 7.6)));

    auto fillet_face = [&](const EntityId& face, double radius) {
        auto edges = edges_of_face(doc, face);
        REQUIRE(!edges.empty());
        json ej = json::array();
        for (const auto& e : edges) ej.push_back(e.str());
        Feature fil;
        fil.type = FeatureType::Fillet;
        fil.params = {{"target", ext_id.str()}, {"radius", radius}, {"edges", ej}};
        graph.add(std::move(fil));
        REQUIRE(graph.regenerate(doc, &err));
    };

    EntityId top_face = face_at(10.0, 30.0);
    EntityId bottom = face_at(0.0, 30.0);
    REQUIRE(!top_face.is_null());
    REQUIRE(!bottom.is_null());
    fillet_face(top_face, 1.0);
    {
        const TopoDS_Shape& shape = doc.body(body)->shape;
        CHECK_FALSE(point_inside(shape, gp_Pnt(-9.9, 0, 9.9)));
        CHECK(point_inside(shape, gp_Pnt(-9.7, 0, 5.0)));
    }
    fillet_face(bottom, 1.0);
    CHECK_FALSE(point_inside(doc.body(body)->shape, gp_Pnt(-9.9, 0, 0.1)));
}

TEST_CASE("face fillet accepts a circle split into two semicircles", "[rung01][fillet]") {
    Document doc;
    FeatureGraph graph;
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Disk");
    skf.sketch->add_arc(0, 0, 10.0, 0, M_PI);
    skf.sketch->add_arc(0, 0, 10.0, M_PI, 2.0 * M_PI);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"}, {"end", "blind"}};
    auto ext_id = graph.add(std::move(ext));
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body = graph.feature(ext_id)->output_body;
    EntityId top;
    double best = -1e300;
    for (const auto& fid : doc.body(body)->subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape s = doc.resolve(fid);
        if (s.IsNull()) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(s));
        if (surf.GetType() != GeomAbs_Plane) continue;
        GProp_GProps props;
        BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
        if (props.CentreOfMass().Z() > best) {
            best = props.CentreOfMass().Z();
            top = fid;
        }
    }
    auto edges = edges_of_face(doc, top);
    REQUIRE(edges.size() >= 2);
    json ej = json::array();
    for (const auto& e : edges) ej.push_back(e.str());
    Feature fil;
    fil.type = FeatureType::Fillet;
    fil.params = {{"target", ext_id.str()}, {"radius", 1.0}, {"edges", ej}};
    graph.add(std::move(fil));
    REQUIRE(graph.regenerate(doc, &err));
    CHECK_FALSE(point_inside(doc.body(body)->shape, gp_Pnt(-9.9, 0, 9.9)));
    CHECK(point_inside(doc.body(body)->shape, gp_Pnt(0, 0, 5)));
}
