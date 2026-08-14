#pragma once
// In-context references (Wave 1.5). Named snapshots of a neighbor body.
// Downstream features read the snapshot, never the live neighbor, until the
// user clicks Update Context. sx/context.hpp is the AI markdown export — the
// name is taken, so this lives here.

#include <array>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct ContextSnapshot {
    EntityId id;
    std::string name;
    EntityId source_body;
    EntityId consumer_feature;
    std::string source_path;
    double volume = 0.0;
    double height = 0.0;  // bbox Z at capture — the consumer pad reads this
    std::array<double, 3> bbox_min{0, 0, 0};
    std::array<double, 3> bbox_max{0, 0, 0};
    int face_count = 0;
};

void to_json(nlohmann::json& j, const ContextSnapshot& c);
void from_json(const nlohmann::json& j, ContextSnapshot& c);

// Capture the live neighbor into a named snapshot. Returns the context id.
EntityId capture_context(Document& doc, const EntityId& source_body, const std::string& name,
                         std::string* err = nullptr);

// True when the live source no longer matches the snapshot (volume or height).
bool is_context_stale(const Document& doc, const EntityId& context_id);

// Recapture from the live source. Does not regenerate — the caller (or the
// timeline "Update Context" verb) regenerates the consumer afterwards.
bool update_context(Document& doc, const EntityId& context_id, std::string* err = nullptr);

}  // namespace sx
