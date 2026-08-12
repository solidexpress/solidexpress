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

EntityId cylindrical_face(const Document& doc, const EntityId& body_id, bool encloses) {
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    for (const auto& fid : b->subshape_ids.at(EntityKind::Face)) {
        auto ax = mate_axis(doc, {}, fid);
        if (ax && ax->encloses == encloses) return fid;
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

TEST_CASE("concentric mate drops a pin into a hole axis", "[mates]") {
    Document doc;
    CommandStack stack;
    // Hole Ø10 (r=5) at (60,30); pin Ø8 (r=4) → 1 mm radial clearance.
    auto block = bored_block(doc, stack, 5.0, 60, 30);
    auto pin = doc.add_body(shape::make_cylinder(4, 25), "Pin");
    auto inst = doc.add_instance(pin, {-80, 15, 3}, {0, 0.7071068, 0, 0.7071068},
                                 "Pin-1");  // 90 deg about Y: axis now along X
    REQUIRE(!inst.is_null());

    auto hole_face = cylindrical_face(doc, block, /*encloses=*/true);
    auto pin_face = cylindrical_face(doc, pin, /*encloses=*/false);
    REQUIRE(!hole_face.is_null());
    REQUIRE(!pin_face.is_null());

    Mate m;
    m.type = MateType::Concentric;
    m.face_a = hole_face;
    m.instance_b = inst;
    m.face_b = pin_face;
    m.offset = 1.0;  // radial tolerance
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    // Pin axis must be colinear with the hole axis (x=60, y=30, dir Z):
    // bbox is centered on (60, 30) with 4mm radius in x/y.
    double bb[6];
    world_bbox(doc, *doc.instance(inst), bb);
    CHECK((bb[0] + bb[3]) / 2.0 == Approx(60.0).margin(1e-6));
    CHECK((bb[1] + bb[4]) / 2.0 == Approx(30.0).margin(1e-6));
    CHECK(bb[3] - bb[0] == Approx(8.0).margin(1e-4));  // re-aligned to Z
}

TEST_CASE("concentric mate leaves revolute DOF about the axis", "[mates]") {
    Document doc;
    CommandStack stack;
    auto block = bored_block(doc, stack, 5.0, 0, 0);
    auto pin = doc.add_body(shape::make_cylinder(4, 25), "Pin");
    auto inst = doc.add_instance(pin, {80, 0, 0}, {0, 0, 0, 1}, "Pin-1");
    auto hole_face = cylindrical_face(doc, block, /*encloses=*/true);
    auto pin_face = cylindrical_face(doc, pin, /*encloses=*/false);
    REQUIRE(!hole_face.is_null());
    REQUIRE(!pin_face.is_null());

    Mate m;
    m.type = MateType::Concentric;
    m.face_a = hole_face;
    m.instance_b = inst;
    m.face_b = pin_face;
    m.offset = 1.0;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto axis = instance_revolute_axis(doc, inst);
    REQUIRE(axis.has_value());
    CHECK(std::abs(axis->dir.Z()) == Approx(1.0).margin(1e-6));

    // Rotate 30° about the revolute axis; solve must preserve that angle.
    const Instance* before = doc.instance(inst);
    REQUIRE(before);
    gp_Trsf cur = transform_of(*before);
    gp_Trsf spin;
    spin.SetRotation(gp_Ax1(axis->point, axis->dir), M_PI / 6.0);
    gp_Trsf next = spin * cur;
    gp_Quaternion q = next.GetRotation();
    gp_XYZ tr = next.TranslationPart();
    std::array<double, 3> tarr{tr.X(), tr.Y(), tr.Z()};
    std::array<double, 4> qarr{q.X(), q.Y(), q.Z(), q.W()};
    REQUIRE(doc.set_instance_transform(inst, tarr, qarr));
    REQUIRE(solve_mates(doc));

    const Instance* after = doc.instance(inst);
    REQUIRE(after);
    gp_Trsf at = transform_of(*after);
    // A corner of the pin's local +X should have rotated ~30° about Z.
    gp_Pnt local(4, 0, 12.5);
    gp_Pnt world = local.Transformed(at);
    double ang = std::atan2(world.Y() - axis->point.Y(), world.X() - axis->point.X());
    CHECK(ang == Approx(M_PI / 6.0).margin(1e-3));
}

TEST_CASE("concentric requires enclosure and positive radial tolerance", "[mates]") {
    Document doc;
    CommandStack stack;
    auto block = bored_block(doc, stack, 5.0, 0, 0);
    auto pin = doc.add_body(shape::make_cylinder(4, 25), "Pin");
    auto boss = doc.add_body(shape::make_cylinder(10, 40), "Boss");
    auto inst = doc.add_instance(pin, {80, 0, 0}, {0, 0, 0, 1}, "Pin-1");
    auto hole_face = cylindrical_face(doc, block, true);
    auto pin_face = cylindrical_face(doc, pin, false);
    auto boss_face = cylindrical_face(doc, boss, false);
    REQUIRE(!hole_face.is_null());
    REQUIRE(!pin_face.is_null());
    REQUIRE(!boss_face.is_null());

    SECTION("zero tolerance rejected at add") {
        Mate m;
        m.type = MateType::Concentric;
        m.face_a = hole_face;
        m.instance_b = inst;
        m.face_b = pin_face;
        m.offset = 0.0;
        CHECK(doc.add_mate(m).is_null());
    }

    SECTION("outer↔outer rejected (no enclosure)") {
        Mate m;
        m.type = MateType::Concentric;
        m.face_a = boss_face;
        m.instance_b = inst;
        m.face_b = pin_face;
        m.offset = 1.0;
        REQUIRE(!doc.add_mate(m).is_null());
        CHECK_FALSE(solve_mates(doc));
    }

    SECTION("tolerance larger than geometric clearance fails") {
        Mate m;
        m.type = MateType::Concentric;
        m.face_a = hole_face;
        m.instance_b = inst;
        m.face_b = pin_face;
        m.offset = 2.0;  // geometry only has 1.0
        REQUIRE(!doc.add_mate(m).is_null());
        CHECK_FALSE(solve_mates(doc));
    }
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

TEST_CASE("concentric revolute clamps to angle limits", "[mates][limits]") {
    Document doc;
    CommandStack stack;
    auto block = bored_block(doc, stack, 5.0, 0, 0);
    auto pin = doc.add_body(shape::make_cylinder(4, 25), "Pin");
    auto inst = doc.add_instance(pin, {80, 0, 0}, {0, 0, 0, 1}, "Pin-1");
    auto hole_face = cylindrical_face(doc, block, /*encloses=*/true);
    auto pin_face = cylindrical_face(doc, pin, /*encloses=*/false);
    REQUIRE(!hole_face.is_null());
    REQUIRE(!pin_face.is_null());

    Mate m;
    m.type = MateType::Concentric;
    m.face_a = hole_face;
    m.instance_b = inst;
    m.face_b = pin_face;
    m.offset = 1.0;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto ang0 = instance_revolute_angle(doc, inst);
    REQUIRE(ang0.has_value());
    const double a0_deg = *ang0 * 180.0 / M_PI;

    // Re-seat the mate with ±20° limits around the solved rest angle.
    REQUIRE(doc.remove_mate(doc.mates().front().id));
    m.id = {};
    m.angle_min = a0_deg - 20.0;
    m.angle_max = a0_deg + 20.0;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto axis = instance_revolute_axis(doc, inst);
    REQUIRE(axis.has_value());
    const Instance* before = doc.instance(inst);
    REQUIRE(before);
    gp_Trsf cur = transform_of(*before);
    gp_Trsf spin;
    spin.SetRotation(gp_Ax1(axis->point, axis->dir), 60.0 * M_PI / 180.0);
    gp_Trsf next = spin * cur;
    gp_Quaternion q = next.GetRotation();
    gp_XYZ tr = next.TranslationPart();
    REQUIRE(doc.set_instance_transform(inst, {tr.X(), tr.Y(), tr.Z()},
                                       {q.X(), q.Y(), q.Z(), q.W()}));
    REQUIRE(solve_mates(doc));

    auto ang1 = instance_revolute_angle(doc, inst);
    REQUIRE(ang1.has_value());
    CHECK(*ang1 == Approx((a0_deg + 20.0) * M_PI / 180.0).margin(1e-3));
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
