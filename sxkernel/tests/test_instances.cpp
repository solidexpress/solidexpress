#include <catch.hpp>

#include <cmath>
#include <cstdio>
#include <string>

#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <miniz.h>
#include <nlohmann/json.hpp>

#include "sx/commands_assembly.hpp"
#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;

namespace {

struct TmpFile {
    std::string path;
    explicit TmpFile(const char* name) : path(std::string("/tmp/sx_test_") + name) {}
    ~TmpFile() { std::remove(path.c_str()); }
};

void bbox_extents(const TopoDS_Shape& s, double& dx, double& dy, double& dz,
                  double& xmin, double& ymin, double& zmin) {
    Bnd_Box box;
    BRepBndLib::Add(s, box);
    double xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    dx = xmax - xmin;
    dy = ymax - ymin;
    dz = zmax - zmin;
}

bool approx3(const std::array<double, 3>& a, const std::array<double, 3>& b,
             double eps = 1e-9) {
    return std::abs(a[0] - b[0]) < eps && std::abs(a[1] - b[1]) < eps &&
           std::abs(a[2] - b[2]) < eps;
}

bool approx4(const std::array<double, 4>& a, const std::array<double, 4>& b,
             double eps = 1e-9) {
    return std::abs(a[0] - b[0]) < eps && std::abs(a[1] - b[1]) < eps &&
           std::abs(a[2] - b[2]) < eps && std::abs(a[3] - b[3]) < eps;
}

}  // namespace

TEST_CASE("translated instance preserves volume and shifts bbox", "[instances]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 20, 30), "Box");
    const double vol = shape::volume(doc.body(body_id)->shape);

    auto inst_id =
        doc.add_instance(body_id, {5, 0, 0}, {0, 0, 0, 1}, "Inst A");
    REQUIRE(!inst_id.is_null());
    REQUIRE(doc.instances().size() == 1);

    const Instance* inst = doc.instance(inst_id);
    REQUIRE(inst != nullptr);
    REQUIRE(inst->source_body == body_id);
    REQUIRE(approx3(inst->translation, {5, 0, 0}));

    TopoDS_Shape placed = resolved_shape(doc, *inst);
    REQUIRE(shape::volume(placed) == Approx(vol).epsilon(1e-6));

    double dx, dy, dz, xmin, ymin, zmin;
    bbox_extents(placed, dx, dy, dz, xmin, ymin, zmin);
    REQUIRE(xmin == Approx(5.0).epsilon(1e-6));
    // margin, not epsilon: relative tolerance is zero at 0.0 and Bnd_Box pads ~1e-7
    REQUIRE(ymin == Approx(0.0).margin(1e-5));
    REQUIRE(zmin == Approx(0.0).margin(1e-5));
    REQUIRE(dx == Approx(10.0).epsilon(1e-6));
    REQUIRE(dy == Approx(20.0).epsilon(1e-6));
    REQUIRE(dz == Approx(30.0).epsilon(1e-6));
}

TEST_CASE("rotated instance swaps XY bbox extents", "[instances]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 20, 30), "Box");

    // 90° about Z: quaternion (0, 0, sin(π/4), cos(π/4)).
    const double s = std::sin(M_PI / 4.0);
    const double c = std::cos(M_PI / 4.0);
    auto inst_id =
        doc.add_instance(body_id, {0, 0, 0}, {0, 0, s, c}, "Rotated");
    REQUIRE(!inst_id.is_null());

    TopoDS_Shape placed = resolved_shape(doc, *doc.instance(inst_id));
    REQUIRE(shape::volume(placed) == Approx(10 * 20 * 30).epsilon(1e-6));

    double dx, dy, dz, xmin, ymin, zmin;
    bbox_extents(placed, dx, dy, dz, xmin, ymin, zmin);
    REQUIRE(dx == Approx(20.0).epsilon(1e-6));
    REQUIRE(dy == Approx(10.0).epsilon(1e-6));
    REQUIRE(dz == Approx(30.0).epsilon(1e-6));
}

TEST_CASE("set_instance_transform updates placement", "[instances]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto inst_id =
        doc.add_instance(body_id, {0, 0, 0}, {0, 0, 0, 1}, "Inst");
    const uint64_t rev = doc.revision();

    REQUIRE(doc.set_instance_transform(inst_id, {3, 4, 5}, {0, 0, 0, 1}));
    REQUIRE(doc.revision() > rev);

    const Instance* inst = doc.instance(inst_id);
    REQUIRE(approx3(inst->translation, {3, 4, 5}));

    double dx, dy, dz, xmin, ymin, zmin;
    bbox_extents(resolved_shape(doc, *inst), dx, dy, dz, xmin, ymin, zmin);
    REQUIRE(xmin == Approx(3.0).epsilon(1e-6));
    REQUIRE(ymin == Approx(4.0).epsilon(1e-6));
    REQUIRE(zmin == Approx(5.0).epsilon(1e-6));
}

TEST_CASE("removing source body cascades to instances", "[instances]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(5, 5, 5), "Box");
    auto other_id = doc.add_body(shape::make_box(1, 1, 1), "Other");
    auto a = doc.add_instance(body_id, {1, 0, 0}, {0, 0, 0, 1}, "A");
    auto b = doc.add_instance(body_id, {2, 0, 0}, {0, 0, 0, 1}, "B");
    auto c = doc.add_instance(other_id, {0, 0, 0}, {0, 0, 0, 1}, "C");
    REQUIRE(doc.instances().size() == 3);

    REQUIRE(doc.remove_body(body_id));
    REQUIRE(doc.instance(a) == nullptr);
    REQUIRE(doc.instance(b) == nullptr);
    REQUIRE(doc.instance(c) != nullptr);
    REQUIRE(doc.instances().size() == 1);
    REQUIRE(doc.instances()[0].id == c);
}

TEST_CASE("add_instance rejects missing source", "[instances]") {
    Document doc;
    EntityId missing = EntityId::generate();
    auto id = doc.add_instance(missing, {0, 0, 0}, {0, 0, 0, 1}, "Nope");
    REQUIRE(id.is_null());
    REQUIRE(doc.instances().empty());
}

TEST_CASE("assembly undo restores place and remove instance", "[instances][undo]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");

    auto push_edit = [&](const char* label, const auto& mutate) {
        nlohmann::json before = assembly_to_json(doc);
        mutate();
        nlohmann::json after = assembly_to_json(doc);
        REQUIRE(before != after);
        stack.push_executed(
            std::make_unique<AssemblySnapshotCommand>(label, std::move(before), std::move(after)));
    };

    EntityId inst_id;
    push_edit("place instance", [&] {
        inst_id = doc.add_instance(body_id, {5, 0, 0}, {0, 0, 0, 1}, "Inst A");
        REQUIRE(!inst_id.is_null());
    });
    REQUIRE(doc.instances().size() == 1);

    push_edit("move instance", [&] {
        REQUIRE(doc.set_instance_transform(inst_id, {9, 2, 1}, {0, 0, 0, 1}));
    });
    REQUIRE(approx3(doc.instance(inst_id)->translation, {9, 2, 1}));

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.instance(inst_id) != nullptr);
    REQUIRE(approx3(doc.instance(inst_id)->translation, {5, 0, 0}));

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.instances().empty());

    REQUIRE(stack.redo(doc));
    REQUIRE(doc.instances().size() == 1);
    REQUIRE(doc.instance(inst_id) != nullptr);
    REQUIRE(approx3(doc.instance(inst_id)->translation, {5, 0, 0}));

    REQUIRE(stack.redo(doc));
    REQUIRE(approx3(doc.instance(inst_id)->translation, {9, 2, 1}));
}

TEST_CASE("sxp round-trips instances", "[instances][sxp]") {
    TmpFile f("instances_roundtrip.sxp");

    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 20, 30), "Box");
    const double s = std::sin(M_PI / 4.0);
    const double c = std::cos(M_PI / 4.0);
    auto inst_id =
        doc.add_instance(body_id, {1, 2, 3}, {0, 0, s, c}, "Placed");

    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));

    Document loaded;
    REQUIRE(load_sxp(loaded, f.path, &err));
    REQUIRE(loaded.instances().size() == 1);
    const Instance* inst = loaded.instance(inst_id);
    REQUIRE(inst != nullptr);
    REQUIRE(inst->source_body == body_id);
    REQUIRE(inst->name == "Placed");
    REQUIRE(approx3(inst->translation, {1, 2, 3}));
    REQUIRE(approx4(inst->rotation_quat, {0, 0, s, c}));
}

TEST_CASE("sxp load with zero instances leaves empty list", "[instances][sxp]") {
    TmpFile f("instances_empty.sxp");
    Document doc;
    doc.add_body(shape::make_box(1, 1, 1), "Box");
    std::string err;
    REQUIRE(save_sxp(doc, f.path, &err));

    Document loaded;
    auto bid = loaded.add_body(shape::make_box(2, 2, 2), "Temp");
    loaded.add_instance(bid, {0, 0, 0}, {0, 0, 0, 1}, "TempInst");
    REQUIRE(loaded.instances().size() == 1);

    REQUIRE(load_sxp(loaded, f.path, &err));
    REQUIRE(loaded.instances().empty());
    REQUIRE(loaded.body_ids().size() == 1);
}

TEST_CASE("sxp load drops instances with missing source", "[instances][sxp]") {
    TmpFile base("instances_orphan_base.sxp");
    TmpFile f("instances_orphan.sxp");

    Document doc;
    doc.add_body(shape::make_box(10, 10, 10), "Box");
    std::string err;
    REQUIRE(save_sxp(doc, base.path, &err));

    // Copy the saved archive and inject an instances.json whose source is missing.
    mz_zip_archive in{};
    REQUIRE(mz_zip_reader_init_file(&in, base.path.c_str(), 0));
    mz_zip_archive out{};
    REQUIRE(mz_zip_writer_init_file(&out, f.path.c_str(), 0));
    const mz_uint n = mz_zip_reader_get_num_files(&in);
    for (mz_uint i = 0; i < n; ++i) {
        char name[512];
        mz_zip_reader_get_filename(&in, i, name, sizeof(name));
        if (std::string(name) == "instances.json") continue;
        size_t size = 0;
        void* p = mz_zip_reader_extract_to_heap(&in, i, &size, 0);
        REQUIRE(p != nullptr);
        REQUIRE(mz_zip_writer_add_mem(&out, name, p, size, MZ_DEFAULT_COMPRESSION));
        mz_free(p);
    }
    nlohmann::json orphan = nlohmann::json::array();
    orphan.push_back(nlohmann::json{{"id", EntityId::generate().str()},
                                    {"source_body", EntityId::generate().str()},
                                    {"translation", {1, 0, 0}},
                                    {"rotation_quat", {0, 0, 0, 1}},
                                    {"name", "Ghost"}});
    const std::string orphan_text = orphan.dump(2);
    REQUIRE(mz_zip_writer_add_mem(&out, "instances.json", orphan_text.data(),
                                  orphan_text.size(), MZ_DEFAULT_COMPRESSION));
    REQUIRE(mz_zip_writer_finalize_archive(&out));
    mz_zip_writer_end(&out);
    mz_zip_reader_end(&in);

    Document loaded;
    REQUIRE(load_sxp(loaded, f.path, &err));
    REQUIRE(loaded.body_ids().size() == 1);
    REQUIRE(loaded.instances().empty());
}
