#include <catch.hpp>

#include <array>
#include <cmath>
#include <cstdio>
#include <string>

#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax1.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Trsf.hxx>
#include <nlohmann/json.hpp>

#include "sx/commands_assembly.hpp"
#include "sx/commands_boolean.hpp"
#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/mates.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;

namespace {

struct TmpFile {
    std::string path;
    explicit TmpFile(const char* name) : path(std::string("/tmp/sx_test_") + name) {}
    ~TmpFile() { std::remove(path.c_str()); }
};

// First planar face of `body` whose outward normal matches `want` (world
// space, body at rest). Null id when none.
EntityId planar_face_with_normal(const Document& doc, const EntityId& body_id,
                                 const gp_Dir& want) {
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    auto it = b->subshape_ids.find(EntityKind::Face);
    REQUIRE(it != b->subshape_ids.end());
    for (const auto& fid : it->second) {
        auto pl = mate_plane(doc, {}, fid);
        if (pl && pl->normal.IsEqual(want, 1e-6)) return fid;
    }
    return {};
}

EntityId cylindrical_face(const Document& doc, const EntityId& body_id) {
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    for (const auto& fid : b->subshape_ids.at(EntityKind::Face)) {
        auto ax = mate_axis(doc, {}, fid);
        if (ax) return fid;
    }
    return {};
}

// Block with a through-hole of radius `hole_r` centered at (cx, cy).
EntityId bored_block(Document& doc, CommandStack& stack, double hole_r, double cx,
                     double cy) {
    auto block = doc.add_body(shape::make_box(60, 60, 40, {{cx - 30, cy - 30, 0}}), "Block");
    auto drill = doc.add_body(shape::make_cylinder(hole_r, 40, {{cx, cy, 0}}), "Drill");
    stack.push(doc, std::make_unique<BooleanCommand>(block, drill, BooleanOp::Cut));
    return block;
}

void world_bbox(const Document& doc, const Instance& inst, double out[6]) {
    Bnd_Box box;
    BRepBndLib::Add(resolved_shape(doc, inst), box);
    box.Get(out[0], out[1], out[2], out[3], out[4], out[5]);
}

}  // namespace

TEST_CASE("plane coincident mate stacks a block onto a base", "[mates]") {
    Document doc;
    // Base 100x100x20 at origin; block 30x30x30 instanced far away, rotated.
    auto base = doc.add_body(shape::make_box(100, 100, 20), "Base");
    auto block = doc.add_body(shape::make_box(30, 30, 30, {{200, 0, 0}}), "Block");
    auto inst = doc.add_instance(block, {50, 50, 90}, {0, 0, 0.3826834, 0.9238795},
                                 "Block-1");  // 45 deg about Z
    REQUIRE(!inst.is_null());

    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_bottom = planar_face_with_normal(doc, block, gp_Dir(0, 0, -1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_bottom.is_null());

    Mate m;
    m.type = MateType::PlaneCoincident;
    m.face_a = base_top;      // grounded body reference (instance_a null)
    m.instance_b = inst;
    m.face_b = block_bottom;
    auto mid = doc.add_mate(m);
    REQUIRE(!mid.is_null());
    REQUIRE(solve_mates(doc));

    // Block bottom now sits on z = 20 (base top).
    double bb[6];
    world_bbox(doc, *doc.instance(inst), bb);
    CHECK(bb[2] == Approx(20.0).margin(1e-6));

    SECTION("offset opens a gap along the mate normal") {
        Mate g = doc.mates().front();
        doc.remove_mate(g.id);
        g.offset = 5.0;
        REQUIRE(!doc.add_mate(g).is_null());
        REQUIRE(solve_mates(doc));
        world_bbox(doc, *doc.instance(inst), bb);
        CHECK(bb[2] == Approx(25.0).margin(1e-6));
    }
}

TEST_CASE("plane coincident flip alignment opposes vs coincides normals", "[mates][flip]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(100, 100, 20), "Base");
    auto block = doc.add_body(shape::make_box(30, 30, 30, {{200, 0, 0}}), "Block");
    auto inst = doc.add_instance(block, {50, 50, 90}, {0, 0, 0, 1}, "Block-1");

    // Top-of-base (+Z) to top-of-block (+Z). Default oppose vs Flip Alignment
    // produce mirrored poses (SW Flip Mate Alignment richness).
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_top = planar_face_with_normal(doc, block, gp_Dir(0, 0, 1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_top.is_null());

    Mate m;
    m.type = MateType::PlaneCoincident;
    m.face_a = base_top;
    m.instance_b = inst;
    m.face_b = block_top;
    m.flip = false;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));
    double bb_opp[6];
    world_bbox(doc, *doc.instance(inst), bb_opp);

    Mate flipped = doc.mates().front();
    doc.remove_mate(flipped.id);
    flipped.flip = true;
    REQUIRE(doc.set_instance_transform(inst, {50, 50, 90}, {0, 0, 0, 1}));
    REQUIRE(!doc.add_mate(flipped).is_null());
    REQUIRE(solve_mates(doc));
    double bb_flip[6];
    world_bbox(doc, *doc.instance(inst), bb_flip);

    // Flip must invert which side of the mate plane the block occupies.
    CHECK(std::abs(bb_opp[2] - bb_flip[2]) > 1.0);
    CHECK(std::abs(bb_opp[5] - bb_flip[5]) > 1.0);
    // Both poses still contact the mate plane near z=20.
    CHECK(std::min(std::abs(bb_opp[2] - 20.0), std::abs(bb_opp[5] - 20.0)) < 1e-4);
    CHECK(std::min(std::abs(bb_flip[2] - 20.0), std::abs(bb_flip[5] - 20.0)) < 1e-4);
}

TEST_CASE("mate validation and cascade", "[mates]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(10, 10, 10), "B");
    auto inst = doc.add_instance(body, {30, 0, 0}, {0, 0, 0, 1}, "B-1");

    SECTION("instance_b must be an instance") {
        Mate m;
        m.type = MateType::PlaneCoincident;
        m.instance_b = body;  // a body id, not an instance
        CHECK(doc.add_mate(m).is_null());
    }

    SECTION("wrong surface type fails to apply") {
        Mate m;
        m.type = MateType::Concentric;  // box has no cylindrical face
        m.face_a = doc.body(body)->subshape_ids.at(EntityKind::Face).front();
        m.instance_b = inst;
        m.face_b = m.face_a;
        m.offset = 0.1;
        REQUIRE(!doc.add_mate(m).is_null());
        CHECK_FALSE(solve_mates(doc));
    }

    SECTION("removing an instance cascades its mates") {
        Mate m;
        m.type = MateType::Fixed;
        m.instance_b = inst;
        REQUIRE(!doc.add_mate(m).is_null());
        REQUIRE(doc.mates().size() == 1);
        REQUIRE(doc.remove_instance(inst));
        CHECK(doc.mates().empty());
    }
}

TEST_CASE("assembly undo restores mate flip and instance pose", "[mates][undo]") {
    Document doc;
    CommandStack stack;
    auto base = doc.add_body(shape::make_box(100, 100, 20), "Base");
    auto block = doc.add_body(shape::make_box(30, 30, 30, {{200, 0, 0}}), "Block");
    auto inst = doc.add_instance(block, {50, 50, 90}, {0, 0, 0, 1}, "Block-1");
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_top = planar_face_with_normal(doc, block, gp_Dir(0, 0, 1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_top.is_null());

    // Snapshot → mutate → push (same path as SxDocument::apply_assembly_edit).
    auto push_edit = [&](const char* label, const auto& mutate) {
        nlohmann::json before = assembly_to_json(doc);
        mutate();
        nlohmann::json after = assembly_to_json(doc);
        REQUIRE(before != after);
        stack.push_executed(
            std::make_unique<AssemblySnapshotCommand>(label, std::move(before), std::move(after)));
    };

    push_edit("add flipped mate", [&] {
        Mate m;
        m.type = MateType::PlaneCoincident;
        m.face_a = base_top;
        m.instance_b = inst;
        m.face_b = block_top;
        m.flip = true;
        m.name = "tops";
        REQUIRE(!doc.add_mate(m).is_null());
        REQUIRE(solve_mates(doc));
    });
    REQUIRE(doc.mates().size() == 1);
    REQUIRE(doc.mates().front().flip);
    const auto t_after_mate = doc.instance(inst)->translation;

    push_edit("nudge instance + solve", [&] {
        REQUIRE(doc.set_instance_transform(inst, {70, 50, 40}, {0, 0, 0, 1}));
        REQUIRE(solve_mates(doc));
    });
    const auto t_after_nudge = doc.instance(inst)->translation;
    REQUIRE(t_after_nudge != t_after_mate);

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.mates().size() == 1);
    REQUIRE(doc.mates().front().flip);
    REQUIRE(doc.instance(inst)->translation == t_after_mate);

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.mates().empty());
    CHECK(doc.instance(inst)->translation[0] == Approx(50.0));
    CHECK(doc.instance(inst)->translation[1] == Approx(50.0));
    CHECK(doc.instance(inst)->translation[2] == Approx(90.0));

    REQUIRE(stack.redo(doc));
    REQUIRE(doc.mates().size() == 1);
    REQUIRE(doc.mates().front().flip);
    REQUIRE(doc.instance(inst)->translation == t_after_mate);

    REQUIRE(stack.redo(doc));
    REQUIRE(doc.instance(inst)->translation == t_after_nudge);
}

TEST_CASE("mates persist through .sxp round trip", "[mates]") {
    TmpFile f("mates.sxp");
    EntityId mate_id, inst_id;
    {
        Document doc;
        auto base = doc.add_body(shape::make_box(50, 50, 10), "Base");
        auto top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
        auto block = doc.add_body(shape::make_box(10, 10, 10, {{100, 0, 0}}), "Blk");
        auto bottom = planar_face_with_normal(doc, block, gp_Dir(0, 0, -1));
        inst_id = doc.add_instance(block, {0, 0, 50}, {0, 0, 0, 1}, "Blk-1");
        Mate m;
        m.type = MateType::PlaneCoincident;
        m.face_a = top;
        m.instance_b = inst_id;
        m.face_b = bottom;
        m.offset = 2.5;
        m.flip = false;
        mate_id = doc.add_mate(m);
        REQUIRE(save_sxp(doc, f.path));
    }
    Document loaded;
    REQUIRE(load_sxp(loaded, f.path));
    REQUIRE(loaded.mates().size() == 1);
    const Mate& m = loaded.mates().front();
    CHECK(m.id == mate_id);
    CHECK(m.type == MateType::PlaneCoincident);
    CHECK(m.instance_b == inst_id);
    CHECK(m.offset == Approx(2.5));
    // And it still solves on the loaded document.
    REQUIRE(solve_mates(loaded));
    double bb[6];
    world_bbox(loaded, *loaded.instance(inst_id), bb);
    CHECK(bb[2] == Approx(12.5).margin(1e-6));
}

TEST_CASE("fastened mate seats a bolt in a hole (all 6 DOF)", "[mates]") {
    Document doc;
    auto hole_cyl = doc.add_body(shape::make_cylinder(10, 40, {{60, 30, 0}}), "Boss");
    auto pin = doc.add_body(shape::make_cylinder(4, 25), "Bolt");
    auto inst = doc.add_instance(pin, {-80, 15, 3}, {0, 0.7071068, 0, 0.7071068}, "Bolt-1");
    auto boss_face = cylindrical_face(doc, hole_cyl);
    auto pin_face = cylindrical_face(doc, pin);
    REQUIRE(!boss_face.is_null());
    REQUIRE(!pin_face.is_null());

    auto ca = implicit_connector(doc, {}, boss_face);
    auto cb = implicit_connector(doc, inst, pin_face);
    REQUIRE(ca);
    REQUIRE(cb);

    Mate m;
    m.type = MateType::Fastened;
    m.face_a = boss_face;
    m.instance_b = inst;
    m.face_b = pin_face;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto seated = implicit_connector(doc, inst, pin_face);
    REQUIRE(seated);
    CHECK(seated->origin[0] == Approx(ca->origin[0]).margin(1e-4));
    CHECK(seated->origin[1] == Approx(ca->origin[1]).margin(1e-4));
    CHECK(seated->origin[2] == Approx(ca->origin[2]).margin(1e-4));
    gp_Dir za(ca->z_dir[0], ca->z_dir[1], ca->z_dir[2]);
    gp_Dir zb(seated->z_dir[0], seated->z_dir[1], seated->z_dir[2]);
    CHECK(std::abs(za.Dot(zb)) == Approx(1.0).margin(1e-5));

    TmpFile f("fastened.sxp");
    REQUIRE(save_sxp(doc, f.path));
    Document loaded;
    REQUIRE(load_sxp(loaded, f.path));
    REQUIRE(loaded.mates().size() == 1);
    CHECK(loaded.mates().front().type == MateType::Fastened);
    REQUIRE(solve_mates(loaded));
}

TEST_CASE("old coincident mates still load after connector migration", "[mates]") {
    TmpFile f("legacy_coincident.sxp");
    EntityId inst_id;
    {
        Document doc;
        auto base = doc.add_body(shape::make_box(50, 50, 10), "Base");
        auto top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
        auto block = doc.add_body(shape::make_box(10, 10, 10, {{100, 0, 0}}), "Blk");
        auto bottom = planar_face_with_normal(doc, block, gp_Dir(0, 0, -1));
        inst_id = doc.add_instance(block, {0, 0, 50}, {0, 0, 0, 1}, "Blk-1");
        Mate m;
        m.type = MateType::PlaneCoincident;
        m.face_a = top;
        m.instance_b = inst_id;
        m.face_b = bottom;
        REQUIRE(!doc.add_mate(m).is_null());
        REQUIRE(save_sxp(doc, f.path));
    }
    Document loaded;
    REQUIRE(load_sxp(loaded, f.path));
    REQUIRE(loaded.mates().size() == 1);
    CHECK(loaded.mates().front().type == MateType::PlaneCoincident);
    REQUIRE(solve_mates(loaded));
    double bb[6];
    world_bbox(loaded, *loaded.instance(inst_id), bb);
    CHECK(bb[2] == Approx(10.0).margin(1e-6));
}

TEST_CASE("plane parallel mate aligns normals without closing the gap", "[mates]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(50, 50, 10), "Base");
    auto block = doc.add_body(shape::make_box(20, 20, 20, {{100, 0, 0}}), "Blk");
    // Tip the block 45° about Y so its +Z face is tilted; parallel should flatten it.
    auto inst = doc.add_instance(block, {0, 0, 40}, {0, 0.3826834, 0, 0.9238795}, "Blk-1");
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_top = planar_face_with_normal(doc, block, gp_Dir(0, 0, 1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_top.is_null());

    Mate m;
    m.type = MateType::PlaneParallel;
    m.face_a = base_top;
    m.instance_b = inst;
    m.face_b = block_top;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto pl = mate_plane(doc, inst, block_top);
    REQUIRE(pl);
    CHECK(std::abs(pl->normal.Dot(gp_Dir(0, 0, 1))) == Approx(1.0).margin(1e-6));
    // Translation remains free after Parallel: we can still drag Z without
    // the mate snapping us back (unlike PlaneCoincident).
    REQUIRE(doc.set_instance_transform(inst, {0, 0, 80}, {0, 0, 0, 1}));
    REQUIRE(solve_mates(doc));
    CHECK(doc.instance(inst)->translation[2] == Approx(80.0).margin(1e-6));
    auto pl2 = mate_plane(doc, inst, block_top);
    REQUIRE(pl2);
    CHECK(std::abs(pl2->normal.Dot(gp_Dir(0, 0, 1))) == Approx(1.0).margin(1e-6));
}
