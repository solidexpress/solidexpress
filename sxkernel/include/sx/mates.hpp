#pragma once
// Assembly mates between component instances (and ground bodies).
//
// v1 is a sequential, closed-form placer (no iterative solver): applying a
// mate computes the rigid transform that moves instance B onto the mated
// geometry of reference A, in insertion order. This matches how simple
// assemblies behave in mainstream CAD for the common cases (plane-on-plane,
// pin-in-hole) and leaves an AI-first/iterative solver as a later backend
// swap, mirroring the sketch SolverBackend seam.
//
// Mate references: `face_*` is a face EntityId of a SOURCE BODY. When the
// paired `instance_*` id is non-null the face is evaluated under that
// instance's placement; when null, the face's own body placement (world) is
// used — that is the "ground" side. `instance_b` must be a real instance:
// it is the side that moves.

#include <optional>
#include <string>
#include <vector>

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <nlohmann/json.hpp>

#include "sx/ids.hpp"

namespace sx {

class Document;

enum class MateType {
    Fixed,            // locks instance_b where it is (no-op on apply)
    PlaneCoincident,  // face planes opposed, signed gap = offset
    Concentric,       // radial pin-in-hole: axes colinear (axial slide free)
};

const char* to_string(MateType t);
MateType mate_type_from_string(const std::string& s);

struct Mate {
    EntityId id;
    MateType type = MateType::PlaneCoincident;
    EntityId instance_a;  // null => face_a is on a grounded body
    EntityId face_a;
    EntityId instance_b;  // the moved side; must be an instance
    EntityId face_b;
    // PlaneCoincident: signed face gap along A's normal.
    // Concentric: required minimum radial clearance (must be > 0); geometry
    // must enclose (hole around pin) with R_hole - R_pin >= offset.
    double offset = 0.0;
    bool flip = false;    // PlaneCoincident: align normals instead of opposing
    std::string name;
};

void to_json(nlohmann::json& j, const Mate& m);
void from_json(const nlohmann::json& j, Mate& m);

struct MatePlane {
    gp_Pnt point;
    gp_Dir normal;
};
struct MateAxis {
    gp_Pnt point;
    gp_Dir dir;
    double radius = 0.0;
    // True when the cylindrical face is a hole wall (material outside the
    // cylinder, OCCT REVERSED) — it can enclose a smaller outer cylinder.
    bool encloses = false;
};

// World-space plane / cylinder axis of a mate reference (face under the
// instance placement, or as-is when instance id is null). nullopt when the
// face is missing or not the right surface type.
std::optional<MatePlane> mate_plane(const Document& doc, const EntityId& instance,
                                    const EntityId& face);
std::optional<MateAxis> mate_axis(const Document& doc, const EntityId& instance,
                                  const EntityId& face);

// Moves instance_b so the mate is satisfied (A stays put). Returns false when
// references are invalid or geometry is of the wrong type.
bool apply_mate(Document& doc, const Mate& m);

// Applies every mate stored on the document in insertion order.
bool solve_mates(Document& doc);

// World-space axis of the first concentric mate that moves `instance` as
// instance_b. When present, the instance has a free rotational DOF about this
// axis (axial slide may also be free). Empty when no concentric mate applies.
std::optional<MateAxis> instance_revolute_axis(const Document& doc,
                                              const EntityId& instance);

}  // namespace sx
