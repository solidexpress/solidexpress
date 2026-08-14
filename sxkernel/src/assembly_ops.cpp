#include "sx/assembly_ops.hpp"

#include <cmath>

#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <gp_Ax1.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include "sx/document.hpp"
#include "sx/joints.hpp"

namespace sx {
namespace {

std::array<double, 3> assembly_centre(const Document& doc) {
    double x = 0, y = 0, z = 0;
    int n = 0;
    for (const auto& inst : doc.instances()) {
        const auto& t = inst.exploded ? inst.assembled_translation : inst.translation;
        x += t[0];
        y += t[1];
        z += t[2];
        ++n;
    }
    if (n == 0) return {0, 0, 0};
    return {x / n, y / n, z / n};
}

double part_size(const Document& doc, const EntityId& body) {
    const Body* b = doc.body(body);
    if (!b || b->shape.IsNull()) return 10.0;
    Bnd_Box box;
    BRepBndLib::Add(b->shape, box);
    if (box.IsVoid()) return 10.0;
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    return std::max(1.0, gp_Vec(xmax - xmin, ymax - ymin, zmax - zmin).Magnitude());
}

// Direction a part travels when the view explodes: along its joint axis when it
// has one, otherwise away from the middle of the assembly.
gp_Vec explode_dir(const Document& doc, const Instance& inst) {
    for (const auto& j : doc.joints()) {
        if (j.b.instance != inst.id) continue;
        gp_Vec axis(j.a.z_dir[0], j.a.z_dir[1], j.a.z_dir[2]);
        if (axis.Magnitude() > 1e-9) return axis.Normalized();
    }
    const auto c = assembly_centre(doc);
    const auto& t = inst.exploded ? inst.assembled_translation : inst.translation;
    gp_Vec out(t[0] - c[0], t[1] - c[1], t[2] - c[2]);
    if (out.Magnitude() < 1e-6) return gp_Vec(0, 0, 1);
    return out.Normalized();
}

}  // namespace

int explode(Document& doc, double factor) {
    int moved = 0;
    // Snapshot ids first: set_instance_transform mutates the vector in place.
    std::vector<EntityId> ids;
    for (const auto& inst : doc.instances()) ids.push_back(inst.id);

    for (const auto& id : ids) {
        Instance* inst = doc.instance_mut(id);
        if (!inst || inst->fixed) continue;
        if (!inst->exploded) inst->assembled_translation = inst->translation;
        const auto home = inst->assembled_translation;
        if (std::abs(factor) < 1e-9) {
            inst->translation = home;
            inst->exploded = false;
            ++moved;
            continue;
        }
        const gp_Vec step = explode_dir(doc, *inst) * (factor * part_size(doc, inst->source_body));
        inst->translation = {home[0] + step.X(), home[1] + step.Y(), home[2] + step.Z()};
        inst->exploded = true;
        ++moved;
    }
    if (moved > 0) doc.bump_revision();
    return moved;
}

bool is_exploded(const Document& doc) {
    for (const auto& inst : doc.instances()) {
        if (inst.exploded) return true;
    }
    return false;
}

std::vector<EntityId> pattern_instance(Document& doc, const EntityId& instance, int count,
                                       double total_angle, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return std::vector<EntityId>{};
    };
    const Instance* seed = doc.instance(instance);
    if (!seed) return bail("pattern needs a component instance");
    if (count < 2) return bail("pattern count must be at least two");

    // Axis: the seed's joint if it has one, else world Z through the assembly.
    gp_Pnt axis_point(0, 0, 0);
    gp_Dir axis_dir(0, 0, 1);
    const Joint* driver = nullptr;
    for (const auto& j : doc.joints()) {
        if (j.b.instance == instance) {
            driver = &j;
            break;
        }
    }
    if (driver != nullptr) {
        axis_point = gp_Pnt(driver->a.origin[0], driver->a.origin[1], driver->a.origin[2]);
        gp_Vec z(driver->a.z_dir[0], driver->a.z_dir[1], driver->a.z_dir[2]);
        if (z.Magnitude() > 1e-9) axis_dir = gp_Dir(z);
    } else {
        const auto c = assembly_centre(doc);
        axis_point = gp_Pnt(c[0], c[1], c[2]);
    }

    const std::string base = seed->name.empty() ? std::string("Instance") : seed->name;
    const auto seed_translation = seed->translation;
    const auto seed_rotation = seed->rotation_quat;
    const EntityId source = seed->source_body;

    std::vector<EntityId> made;
    for (int i = 1; i < count; ++i) {
        const double angle = total_angle * static_cast<double>(i) / static_cast<double>(count);
        gp_Trsf spin;
        spin.SetRotation(gp_Ax1(axis_point, axis_dir), angle);
        gp_Pnt where(seed_translation[0], seed_translation[1], seed_translation[2]);
        where.Transform(spin);
        gp_Quaternion seed_q(seed_rotation[0], seed_rotation[1], seed_rotation[2],
                             seed_rotation[3]);
        if (seed_q.Norm() < 1e-12) seed_q.Set(0, 0, 0, 1);
        const gp_Quaternion q = spin.GetRotation() * seed_q;
        const EntityId made_id =
            doc.add_instance(source, {where.X(), where.Y(), where.Z()},
                             {q.X(), q.Y(), q.Z(), q.W()}, base + " " + std::to_string(i + 1));
        if (made_id.is_null()) continue;
        made.push_back(made_id);
        // Each copy inherits the seed's joint, so one definition drives them all.
        if (driver != nullptr) {
            Joint copy = *driver;
            copy.id = {};
            copy.name.clear();
            copy.b.instance = made_id;
            gp_Pnt frame(copy.a.origin[0], copy.a.origin[1], copy.a.origin[2]);
            frame.Transform(spin);
            copy.a.origin = {frame.X(), frame.Y(), frame.Z()};
            doc.add_joint(std::move(copy));
        }
    }
    if (made.empty()) return bail("pattern produced no copies");
    return made;
}

}  // namespace sx
