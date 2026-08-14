#include "sx/joints.hpp"

#include <algorithm>
#include <cmath>

#include <gp_Dir.hxx>
#include <stdexcept>

#include <gp_Ax1.hxx>
#include <gp_Ax3.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include "sx/document.hpp"
#include "sx/instances.hpp"

namespace sx {

const char* to_string(JointType t) {
    switch (t) {
        case JointType::Revolute: return "revolute";
        case JointType::Slider: return "slider";
        case JointType::Cylindrical: return "cylindrical";
        case JointType::Planar: return "planar";
        case JointType::Ball: return "ball";
        case JointType::PinSlot: return "pin_slot";
    }
    return "unknown";
}

JointType joint_type_from_string(const std::string& s) {
    if (s == "revolute") return JointType::Revolute;
    if (s == "slider") return JointType::Slider;
    if (s == "cylindrical") return JointType::Cylindrical;
    if (s == "planar") return JointType::Planar;
    if (s == "ball") return JointType::Ball;
    if (s == "pin_slot") return JointType::PinSlot;
    throw std::invalid_argument("unknown joint type: " + s);
}

const char* joint_unit(JointType t) {
    switch (t) {
        case JointType::Slider:
        case JointType::PinSlot:
        case JointType::Planar: return "mm";
        case JointType::Revolute:
        case JointType::Cylindrical:
        case JointType::Ball: return "deg";
    }
    return "";
}

void to_json(nlohmann::json& j, const Joint& jnt) {
    j = nlohmann::json{
        {"uuid", jnt.id.str()},
        {"type", to_string(jnt.type)},
        {"a", jnt.a},
        {"b", jnt.b},
        {"value", jnt.value},
        {"limit_min", jnt.limit_min},
        {"limit_max", jnt.limit_max},
        {"has_limits", jnt.has_limits},
        {"name", jnt.name},
    };
}

void from_json(const nlohmann::json& j, Joint& jnt) {
    if (j.contains("uuid")) jnt.id = EntityId::from_string(j["uuid"].get<std::string>());
    jnt.type = joint_type_from_string(j.at("type").get<std::string>());
    if (j.contains("a")) jnt.a = j["a"].get<MateConnector>();
    if (j.contains("b")) jnt.b = j["b"].get<MateConnector>();
    jnt.value = j.value("value", 0.0);
    jnt.limit_min = j.value("limit_min", 0.0);
    jnt.limit_max = j.value("limit_max", 0.0);
    jnt.has_limits = j.value("has_limits", false);
    jnt.name = j.value("name", "");
}

namespace {

bool set_pose(Document& doc, const EntityId& instance_id, const gp_Trsf& pose) {
    if (!doc.instance(instance_id)) return false;
    gp_Quaternion q = pose.GetRotation();
    gp_XYZ tr = pose.TranslationPart();
    return doc.set_instance_transform(instance_id, {tr.X(), tr.Y(), tr.Z()},
                                      {q.X(), q.Y(), q.Z(), q.W()});
}

// Transform taking connector-local coordinates into the frame's own space.
gp_Trsf frame_of(const MateConnector& c) {
    const gp_Pnt origin(c.origin[0], c.origin[1], c.origin[2]);
    const gp_Dir z(c.z_dir[0], c.z_dir[1], c.z_dir[2]);
    gp_Dir x(c.x_dir[0], c.x_dir[1], c.x_dir[2]);
    // Keep X perpendicular to Z; a face-derived X can drift onto the axis.
    if (std::abs(x.Dot(z)) > 1.0 - 1e-9) {
        const gp_Dir ref = std::abs(z.Dot(gp_Dir(0, 0, 1))) < 0.9 ? gp_Dir(0, 0, 1)
                                                                  : gp_Dir(1, 0, 0);
        x = z.Crossed(ref);
    }
    gp_Trsf to_local;
    to_local.SetTransformation(gp_Ax3(origin, z, x));
    return to_local.Inverted();
}

}  // namespace

bool apply_joint(Document& doc, const Joint& jnt, double s) {
    if (jnt.b.instance.is_null() || !doc.instance(jnt.b.instance)) return false;
    double param = s;
    if (jnt.has_limits) param = std::clamp(s, jnt.limit_min, jnt.limit_max);

    // Absolute pose: take the part's own connector frame onto the ground frame,
    // with the joint's one free degree of freedom applied in between. Driving
    // the same value twice lands in the same place, and returning to zero
    // returns the part home.
    gp_Trsf drive;
    switch (jnt.type) {
        case JointType::Revolute:
        case JointType::Cylindrical:
        case JointType::Ball:
            drive.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), param);
            break;
        case JointType::Slider:
            drive.SetTranslation(gp_Vec(0, 0, param));
            break;
        case JointType::Planar:
        case JointType::PinSlot:
            drive.SetTranslation(gp_Vec(param, 0, 0));
            break;
    }
    const gp_Trsf pose = frame_of(jnt.a) * drive * frame_of(jnt.b).Inverted();
    return set_pose(doc, jnt.b.instance, pose);
}

int solve_joints(Document& doc) {
    int applied = 0;
    for (const auto& j : doc.joints()) {
        if (apply_joint(doc, j, j.value)) ++applied;
    }
    return applied;
}

double crank_slider_x(double crank, double rod, double theta) {
    // x = a cos θ + sqrt(b² − a² sin² θ)
    const double s = std::sin(theta);
    const double inner = rod * rod - crank * crank * s * s;
    if (inner < 0.0) return crank * std::cos(theta);
    return crank * std::cos(theta) + std::sqrt(inner);
}

}  // namespace sx
