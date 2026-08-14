#include <catch.hpp>

#include <cstdio>
#include <string>

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

}  // namespace

TEST_CASE("insert_sxp copies bodies and places instances", "[insert_sxp]") {
    TmpFile part("jaw_part.sxp");
    {
        Document src;
        src.add_body(shape::make_box(40, 20, 10), "Jaw");
        src.add_body(shape::make_cylinder(5, 30, {{0, 0, 0}}), "Pin");
        REQUIRE(save_sxp(src, part.path));
    }

    Document asm_doc;
    // Seed a ground body so the assembly is not empty of bodies, but still
    // has no instances — first insert must still Fix the first component.
    asm_doc.add_body(shape::make_box(100, 100, 5), "Base");
    REQUIRE(asm_doc.instances().empty());

    InsertSxpResult out;
    std::string err;
    REQUIRE(insert_sxp(asm_doc, part.path, {10, 0, 5}, &out, &err));
    CHECK(err.empty());
    REQUIRE(out.body_ids.size() == 2);
    REQUIRE(out.instance_ids.size() == 2);
    REQUIRE(asm_doc.instances().size() == 2);

    // Fresh EntityIds (not the source archive's).
    for (const auto& id : out.body_ids) REQUIRE(asm_doc.body(id) != nullptr);
    CHECK(asm_doc.body(out.body_ids[0])->name == "Jaw");
    CHECK(asm_doc.body(out.body_ids[1])->name == "Pin");

    const Instance* first = asm_doc.instance(out.instance_ids[0]);
    const Instance* second = asm_doc.instance(out.instance_ids[1]);
    REQUIRE(first != nullptr);
    REQUIRE(second != nullptr);
    CHECK(first->fixed);
    CHECK_FALSE(second->fixed);
    CHECK(first->source_path == part.path);
    CHECK(first->translation[0] == Approx(10.0));
    CHECK(second->translation[0] == Approx(50.0));  // staggered +40

    // Fixed mate auto-added for the first component.
    bool has_fixed = false;
    for (const auto& m : asm_doc.mates()) {
        if (m.type == MateType::Fixed && m.instance_b == out.instance_ids[0]) has_fixed = true;
    }
    CHECK(has_fixed);

    // Fixed restraint refuses transform edits.
    CHECK_FALSE(asm_doc.set_instance_transform(out.instance_ids[0], {99, 0, 0}, {0, 0, 0, 1}));
    CHECK(asm_doc.instance(out.instance_ids[0])->translation[0] == Approx(10.0));

    // Float unlocks transform.
    REQUIRE(asm_doc.set_instance_fixed(out.instance_ids[0], false));
    CHECK_FALSE(asm_doc.instance(out.instance_ids[0])->fixed);
    REQUIRE(asm_doc.set_instance_transform(out.instance_ids[0], {12, 0, 5}, {0, 0, 0, 1}));
    CHECK(asm_doc.instance(out.instance_ids[0])->translation[0] == Approx(12.0));
}

TEST_CASE("insert_sxp round-trips through host .sxp", "[insert_sxp]") {
    TmpFile part("part_a.sxp");
    TmpFile assembly("assy.sxp");
    {
        Document src;
        src.add_body(shape::make_box(10, 10, 10), "Block");
        REQUIRE(save_sxp(src, part.path));
    }
    EntityId inst_id;
    {
        Document asm_doc;
        InsertSxpResult out;
        REQUIRE(insert_sxp(asm_doc, part.path, {0, 0, 0}, &out));
        REQUIRE(out.instance_ids.size() == 1);
        inst_id = out.instance_ids[0];
        REQUIRE(save_sxp(asm_doc, assembly.path));
    }
    Document loaded;
    REQUIRE(load_sxp(loaded, assembly.path));
    REQUIRE(loaded.instances().size() == 1);
    const Instance* inst = loaded.instance(inst_id);
    REQUIRE(inst != nullptr);
    CHECK(inst->fixed);
    CHECK(inst->source_path == part.path);
    CHECK(inst->name == "Block");
}

TEST_CASE("insert_sxp fails on missing file", "[insert_sxp]") {
    Document doc;
    std::string err;
    CHECK_FALSE(insert_sxp(doc, "/tmp/sx_no_such_file.sxp", {0, 0, 0}, nullptr, &err));
    CHECK_FALSE(err.empty());
}
