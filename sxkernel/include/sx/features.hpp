#pragma once
// Feature history graph: the parametric timeline. Features are data-driven
// (type + JSON params + optional embedded Sketch) so they serialize cleanly
// and an AI backend can read/write them as plain structured data.
//
// Regeneration (v0): replay the timeline in order, rebuilding all
// graph-owned bodies. Body ids stay stable via Feature::output_body.
// Subshape ids are re-matched positionally when the topology count is
// unchanged (naming v0.5); the topological naming service (plan task 3.2)
// upgrades this matching behind the same interface.

#include <nlohmann/json.hpp>

#include <map>
#include <memory>
#include <string>
#include <vector>

#include "sx/ids.hpp"
#include "sx/sketch.hpp"
#include "sx/variables.hpp"

namespace sx {

class Document;

enum class FeatureType {
    Primitive,  // params: {kind: "box|cylinder|sphere|cone|torus", a, b, c,
                //          origin: [x,y,z], optional z_dir/x_dir: [x,y,z]}
    Sketch,     // embedded sketch; no geometry output
    Extrude,    // params: {sketch: <feature uuid>, distance, symmetric,
                //          op: "new|fuse|cut", target: <feature uuid, for fuse/cut>}
    Revolve,    // params: {sketch, axis_point: [u,v], axis_dir: [u,v], angle, op, target}
    Boolean,    // params: {op: "fuse|cut|common", target: <fid>, tool: <fid>}
    Fillet,     // params: {target: <fid>, radius, edges: [<edge uuid>|legacy 1-based index]}
    Chamfer,    // params: {target: <fid>, distance, edges: [...]}
    Hole,       // params: {target: <fid>, type: "simple|counterbore|countersink",
                //          position: [x,y,z], direction: [x,y,z], diameter, depth
                //          (<=0 = through-all), cb_diameter, cb_depth,
                //          cs_diameter, cs_angle_deg}
    Mirror,     // params: {target: <fid>, plane_point: [x,y,z], plane_normal: [x,y,z]}
    LinearPattern,   // params: {target, direction: [x,y,z], spacing, count}
    CircularPattern, // params: {target, axis_point, axis_dir, count, total_angle}
    Shell,      // params: {target, faces: [<face uuid>|legacy 1-based index], thickness}
    Offset,     // params: {target, offset}
    PushPull,   // params: {target: <fid>, face: <face uuid>, distance}
    Draft,      // params: {target: <fid>, faces: [<face uuid>...], angle_deg,
                //          pull_dir: [x,y,z], neutral_point: [x,y,z],
                //          neutral_normal: [x,y,z]}
    Sweep,      // params: {sketch: <fid>, path: [[x,y,z], ...] OR path_feature: <fid>,
                //          optional guides: [<fid>, ...],
                //          optional op: "new"|"fuse"|"cut", target: <fid>,
                //          optional thin_thickness: >0 hollow wall}
    Loft,       // params: {sketches: [<fid>, ...], ruled: bool,
                //          optional guides: [<fid>, ...]}
    Path,       // params: {sketches: [<fid>, ...] (1+), mode: "join_endpoints|bridge_spline|composite",
                //          path: [[x,y,z], ...] rebuilt on regenerate}
                // No solid output — consumed by Sweep via path_feature.
    HelixSweep, // params: {profile_radius (default 1), axis_point: [x,y,z],
                //          axis_dir: [x,y,z], radius, pitch, turns,
                //          left_handed: bool}
    Thread,     // params: {target: <fid>, axis_point: [x,y,z],
                //          axis_dir: [x,y,z], major_radius, pitch, turns,
                //          depth (default pitch*0.6),
                //          profile_angle_deg (default 60)}
                // Cuts a triangular thread form (external) from target body.
    ImportStep, // params: {path: string, index: int (default 0),
                //          scale: double (default 1.0, uniform via gp_Trsf)}
                // BASE feature: file is re-read on regenerate (document dep).
    ImportStl,  // params: {path: string, scale: double (default 1.0)}
                // BASE feature: mesh import as a single body; re-read on regen.
};

const char* to_string(FeatureType t);
FeatureType feature_type_from_string(const std::string& s);

struct Feature {
    EntityId id;
    std::string name;
    FeatureType type = FeatureType::Primitive;
    bool suppressed = false;
    nlohmann::json params;
    std::shared_ptr<Sketch> sketch;  // only for FeatureType::Sketch
    // Stable id of the body this feature creates (Primitive, ImportStep,
    // ImportStl, new-body Extrude/Revolve, Mirror, Sweep, Loft, HelixSweep). Null for
    // sketches and modifying features.
    EntityId output_body;
    // Stable ids of additional bodies created by pattern features
    // (count-1 copies). Empty for all other types.
    std::vector<EntityId> output_bodies;
};

class FeatureGraph {
public:
    // Appends to the timeline. Assigns feature id (and output_body id where
    // applicable) if unset. Returns the feature id.
    EntityId add(Feature f);
    bool remove(const EntityId& id);  // fails if a later feature references it
    bool set_suppressed(const EntityId& id, bool suppressed);
    // Update params and regenerate later; returns false if feature missing.
    bool set_params(const EntityId& id, nlohmann::json params);
    // Reorder: feature ends at `new_index`. Fails (no mutation) if the move
    // would place it before a dependency or after a dependent, or on bad input.
    bool move(const EntityId& id, int new_index);
    // Sets Feature::name. Returns false if feature missing.
    bool rename(const EntityId& id, const std::string& name);

    Feature* feature(const EntityId& id);
    const Feature* feature(const EntityId& id) const;
    const std::vector<Feature>& timeline() const { return timeline_; }

    VariableTable& variables() { return variables_; }
    const VariableTable& variables() const { return variables_; }

    // True if any later feature references `id` in its params.
    bool has_dependents(const EntityId& id) const;

    // Rollback bar: features at timeline position >= index are skipped during
    // regenerate (like temporary suppression). -1 (default) = end of timeline.
    // Persisted with the graph. Returns false on out-of-range index.
    bool set_rollback(int index);
    int rollback() const { return rollback_index_; }

    // Feature that stopped the last regenerate (null if it succeeded) and its
    // error message. Lets the UI badge the offending timeline row.
    const EntityId& last_failed_feature() const { return last_failed_; }
    const std::string& last_error() const { return last_error_; }

    // Full rebuild: removes all graph-owned bodies from the document and
    // replays the timeline. On failure, err names the offending feature and
    // the document is left with features applied up to that point.
    bool regenerate(Document& doc, std::string* err = nullptr);

    nlohmann::json to_json() const;
    static FeatureGraph from_json(const nlohmann::json& j);

private:
    bool apply(Document& doc, Feature& f, const std::map<std::string, double>& env,
               std::string* err);
    std::vector<Feature> timeline_;
    VariableTable variables_;
    int rollback_index_ = -1;
    EntityId last_failed_;
    std::string last_error_;
    // Body ids created by the last regenerate. Needed so bodies belonging to
    // features that were since removed from the timeline still get cleaned up.
    std::vector<EntityId> generated_;
};

}  // namespace sx
