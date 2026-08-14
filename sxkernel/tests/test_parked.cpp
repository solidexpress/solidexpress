#include <catch.hpp>

#include <cmath>
#include <cstdio>
#include <fstream>

#include "sx/entity.hpp"

#include "sx/autodim.hpp"
#include "sx/diagnose.hpp"
#include "sx/document.hpp"
#include "sx/drawing_doc.hpp"
#include "sx/dxf.hpp"
#include "sx/features.hpp"
#include "sx/pdf.hpp"
#include "sx/query.hpp"
#include "sx/sheet_metal.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch3d.hpp"
#include "sx/specialized.hpp"
#include "sx/sxp.hpp"
#include "sx/user_feature.hpp"
#include "sx/voice.hpp"
#include "sx/xref.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

struct Tmp {
    std::string path;
    Tmp(const char* name) {
        path = std::string("/tmp/") + name;
    }
    ~Tmp() { std::remove(path.c_str()); }
};

TEST_CASE("in-context snapshot does not flow until update", "[parked][xref]") {
    Document doc;
    Feature prim;
    prim.type = FeatureType::Primitive;
    prim.params = {{"kind", "box"}, {"a", 40.0}, {"b", 30.0}, {"c", 20.0}};
    const EntityId pf = doc.graph().add(std::move(prim));
    REQUIRE(doc.graph().regenerate(doc));
    const EntityId src = doc.graph().feature(pf)->output_body;
    const EntityId ctx = capture_context(doc, src, "Neighbor");
    REQUIRE_FALSE(ctx.is_null());
    CHECK_FALSE(is_context_stale(doc, ctx));

    Feature pad;
    pad.type = FeatureType::InContext;
    pad.params = {{"context", ctx.str()}, {"a", 20.0}, {"b", 20.0}};
    const EntityId cf = doc.graph().add(std::move(pad));
    REQUIRE(doc.graph().regenerate(doc));
    doc.context_mut(ctx)->consumer_feature = cf;
    const double v0 = shape::volume(doc.body(doc.graph().feature(cf)->output_body)->shape);
    CHECK(v0 == Approx(20.0 * 20.0 * 20.0).margin(1e-6));

    Feature* p = doc.graph().feature(pf);
    p->params["c"] = 40.0;
    REQUIRE(doc.graph().regenerate(doc));
    CHECK(is_context_stale(doc, ctx));
    const double v_wait = shape::volume(doc.body(doc.graph().feature(cf)->output_body)->shape);
    CHECK(v_wait == Approx(v0).margin(1e-6));

    REQUIRE(update_context(doc, ctx));
    REQUIRE(doc.graph().regenerate(doc));
    CHECK_FALSE(is_context_stale(doc, ctx));
    const double v1 = shape::volume(doc.body(doc.graph().feature(cf)->output_body)->shape);
    CHECK(v1 == Approx(20.0 * 20.0 * 40.0).margin(1e-6));
}

TEST_CASE("drawing dim follows a resized body", "[parked][draw]") {
    Document doc;
    Feature prim;
    prim.type = FeatureType::Primitive;
    prim.params = {{"kind", "box"}, {"a", 50.0}, {"b", 40.0}, {"c", 20.0}};
    const EntityId pf = doc.graph().add(std::move(prim));
    REQUIRE(doc.graph().regenerate(doc));
    const EntityId body = doc.graph().feature(pf)->output_body;
    const EntityId sheet = ensure_drawing_sheet(doc);
    REQUIRE_FALSE(sheet.is_null());
    const EntityId dim = add_drawing_dim(doc, sheet, {}, body, {});
    REQUIRE_FALSE(dim.is_null());
    CHECK(doc.drawing_sheets().front().dims.front().value == Approx(50.0).margin(1e-6));

    doc.graph().feature(pf)->params["a"] = 80.0;
    REQUIRE(doc.graph().regenerate(doc));
    CHECK(refresh_drawing_dims(doc) >= 1);
    CHECK(doc.drawing_sheets().front().dims.front().value == Approx(80.0).margin(1e-6));

    auto proj = project_drawing_view(doc, doc.drawing_sheets().front().views.front());
    CHECK_FALSE(proj.visible.empty());
}

TEST_CASE("BOM counts instances", "[parked][bom]") {
    Document doc;
    const EntityId body = doc.add_body(shape::make_box(10, 10, 10), "Bolt");
    doc.add_instance(body, {0, 0, 0}, {0, 0, 0, 1}, "Bolt");
    doc.add_instance(body, {20, 0, 0}, {0, 0, 0, 1}, "Bolt");
    auto rows = bom_from_instances(doc);
    REQUIRE(rows.size() == 1);
    CHECK(rows[0].qty == 2);
}

TEST_CASE("section view produces hatch", "[parked][section]") {
    Document doc;
    doc.add_body(shape::make_box(40, 40, 20), "Block");
    DrawingView v;
    v.kind = "section";
    v.dir = {0, 1, 0};
    v.up = {0, 0, 1};
    v.section_point = {20, 20, 10};
    v.section_normal = {0, 1, 0};
    auto hatch = section_hatch(doc, v, 5.0);
    CHECK_FALSE(hatch.empty());
}

TEST_CASE("DXF writer round-trips a line", "[parked][dxf]") {
    Tmp f("sx_parked.dxf");
    DxfEntity e;
    e.kind = DxfEntity::Kind::Line;
    e.x1 = 0;
    e.y1 = 0;
    e.x2 = 10;
    e.y2 = 0;
    REQUIRE(write_dxf({e}, f.path));
    std::string err;
    auto back = read_dxf(f.path, &err);
    REQUIRE(back.size() == 1);
    CHECK(back[0].x2 == Approx(10.0));
}

TEST_CASE("vector PDF writes a sheet", "[parked][pdf]") {
    Document doc;
    doc.add_body(shape::make_box(20, 20, 10), "Box");
    DrawingView v;
    v.dir = {0, 1, 0};
    v.up = {0, 0, 1};
    auto proj = project_drawing_view(doc, v);
    drawings::PlacedView pv;
    pv.view = proj;
    pv.label = "Front";
    Tmp f("sx_parked.pdf");
    REQUIRE(write_pdf({pv}, f.path, 1.0, "TEST"));
    std::ifstream in(f.path);
    std::string head(5, '\0');
    in.read(head.data(), 5);
    CHECK(head == "%PDF-");
}

TEST_CASE("thin box converts to sheet", "[parked][sheet]") {
    auto plate = shape::make_box(40, 30, 2);
    double t = 0;
    REQUIRE(sheet::is_thin_solid(plate, &t));
    CHECK(t == Approx(2.0).margin(1e-6));
    CHECK(sheet::flat_area(plate) == Approx(40.0 * 30.0).margin(1e-6));
    auto flat = sheet::unfold_thin_solid(plate);
    REQUIRE_FALSE(flat.IsNull());
}

TEST_CASE("adjacent-to query walks shared edges", "[parked][query]") {
    Document doc;
    const EntityId body = doc.add_body(shape::make_box(10, 10, 10), "Box");
    const EntityId face0 = doc.subshape_id(body, EntityKind::Face, 1);
    auto hits = run_query(doc, "adjacent-to=" + face0.str());
    CHECK_FALSE(hits.empty());
}

TEST_CASE("diagnose names released ids", "[parked][diagnose]") {
    Document doc;
    const EntityId body = doc.add_body(shape::make_box(10, 10, 10), "Box");
    doc.replace_body_shape(body, shape::make_box(12, 10, 10));
    Feature f;
    f.type = FeatureType::Fillet;
    f.name = "fillet 1";
    const EntityId fid = doc.graph().add(std::move(f));
    auto d = diagnose_failed_feature(doc, fid, "fillet failed");
    CHECK(d.feature == fid);
    CHECK_FALSE(d.repairs.empty());
}

TEST_CASE("voice flush is a fasten intent", "[parked][voice]") {
    auto i = voice::interpret("make these flush");
    CHECK(i.kind == voice::IntentKind::Model);
    CHECK(i.verb == "fasten");
}

TEST_CASE("auto-dimension promotes weak dims", "[parked][autodim]") {
    Sketch sk;
    sk.add_line(0, 0, 10, 0);
    sk.add_line(10, 0, 10, 8);
    // A weak distance if we can add one.
    auto id = sk.add_constraint(ConstraintType::Distance,
                                {{sk.entities()[0].id, PointRole::Start},
                                 {sk.entities()[0].id, PointRole::End}},
                                10.0);
    sk.set_constraint_weak(id, true);
    CHECK(auto_dimension(sk) >= 1);
    auto chips = propose_on_select(sk, {});
    CHECK_FALSE(chips.empty());
}

TEST_CASE("user csink recipe cuts a plate", "[parked][user]") {
    Document doc;
    Feature prim;
    prim.type = FeatureType::Primitive;
    prim.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 10.0}};
    const EntityId pf = doc.graph().add(std::move(prim));
    REQUIRE(doc.graph().regenerate(doc));
    const double v0 = shape::volume(doc.body(doc.graph().feature(pf)->output_body)->shape);
    std::string err;
    const EntityId uf =
        instantiate_user_feature(doc, user_csink_recipe(),
                                 {{"target", pf.str()}, {"x", 20.0}, {"y", 20.0}, {"z", 10.0}},
                                 &err);
    REQUIRE_FALSE(uf.is_null());
    const double v1 = shape::volume(doc.body(doc.graph().feature(pf)->output_body)->shape);
    CHECK(v1 < v0);
}

TEST_CASE("3D polyline feeds a path", "[parked][sketch3d]") {
    Sketch3D s;
    s.points = {{0, 0, 0}, {10, 0, 5}, {20, 8, 12}};
    auto path = sketch3d_path(s);
    REQUIRE(path.size() == 3);
    CHECK(path[2][2] == Approx(12.0));
}

TEST_CASE("wave4 spikes have a user-visible benefit", "[parked][wave4]") {
    Document doc;
    const EntityId body = doc.add_body(shape::make_box(20, 20, 20), "Box");
    doc.add_instance(body, {0, 0, 0}, {0, 0, 0, 1}, "Box");
    auto cb = config_bom(doc);
    CHECK(cb.rows.size() == 1);

    CHECK(gear_driven_angle(1.0, 2.0) == Approx(2.0));
    pdm_commit(doc, "first cut");
    CHECK(pdm_log(doc).size() == 1);

    std::string err;
    auto tube = route_tube({{0, 0, 0}, {0, 0, 30}, {10, 0, 40}}, 2.0, &err);
    CHECK_FALSE(tube.IsNull());

    const EntityId other = doc.add_body(shape::make_box(10, 10, 10), "Tool");
    CHECK(mesh_boolean_volume(doc, body, other, "fuse") > 0.0);

    CHECK(import_idf_board(doc, 80, 50) == 4);
    const EntityId pmi = add_pmi_dim(doc, body, {});
    CHECK(pmi_value(doc, pmi) == Approx(20.0).margin(1e-6));
}

TEST_CASE("contexts and drawings survive .sxp", "[parked][sxp]") {
    Document doc;
    Feature prim;
    prim.type = FeatureType::Primitive;
    prim.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    doc.graph().add(std::move(prim));
    REQUIRE(doc.graph().regenerate(doc));
    capture_context(doc, doc.graph().timeline().front().output_body, "Snap");
    ensure_drawing_sheet(doc);
    pdm_commit(doc, "saved");
    Tmp f("sx_parked.sxp");
    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));
    Document loaded;
    REQUIRE(load_sxp(loaded, f.path, &err));
    CHECK_FALSE(loaded.contexts().empty());
    CHECK_FALSE(loaded.drawing_sheets().empty());
    CHECK_FALSE(loaded.pdm_entries().empty());
}
