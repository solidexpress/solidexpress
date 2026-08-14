#pragma once
// Connector-based joints (Wave 1). Do not add these as MateType values on
// the face-pair struct — they consume MateConnector frames.

#include <optional>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "sx/ids.hpp"
#include "sx/mates.hpp"

namespace sx {

class Document;

enum class JointType {
    Revolute,     // rotate about connector Z
    Slider,       // translate along Z
    Cylindrical,  // rotate + slide about Z
    Planar,       // slide in XY of A
    Ball,         // spherical at origin
    PinSlot,      // point of B on axis of A
};

const char* to_string(JointType t);
JointType joint_type_from_string(const std::string& s);

struct Joint {
    EntityId id;
    JointType type = JointType::Revolute;
    MateConnector a;
    MateConnector b;
    // Current position of the free degree of freedom: radians for revolute /
    // cylindrical / ball, mm for slider. Dragging a jointed part writes here,
    // so a posed mechanism survives save and reload.
    double value = 0.0;
    double limit_min = 0.0;
    double limit_max = 0.0;
    bool has_limits = false;
    std::string name;
};

// Unit the free DOF is measured in ("deg" or "mm"), for live badges.
const char* joint_unit(JointType t);

void to_json(nlohmann::json& j, const Joint& jnt);
void from_json(const nlohmann::json& j, Joint& jnt);

// Places instance of connector B (via b.instance) so the joint is satisfied
// at parameter `s` (radians for revolute/ball, mm for slider).
bool apply_joint(Document& doc, const Joint& jnt, double s = 0.0);

// Pose every joint in the document at its stored value, in insertion order.
// Returns how many applied.
int solve_joints(Document& doc);

// Analytic crank-slider: crank length a, rod b, angle theta → slider x.
double crank_slider_x(double crank, double rod, double theta);

}  // namespace sx
