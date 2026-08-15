#pragma once
// .sxp container: zip with manifest.json, breps/<uuid>.brep, cards/<uuid>.md.

#include <array>
#include <string>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Document;

// Returns true on success. On failure, err (if non-null) receives a message.
bool save_sxp(const Document& doc, const std::string& path, std::string* err = nullptr);
bool load_sxp(Document& doc, const std::string& path, std::string* err = nullptr);

// Multi-doc Insert Components (SolidWorks Video 5): load an external .sxp into
// a temp document, deep-copy every body into `dest` under fresh EntityIds, and
// place an instance of each at `base_translation` (+ per-body X stagger).
// The first instance into an empty assembly is Fixed (restraint). Source bodies
// are returned so the UI can hide them and show only the placed components.
struct InsertSxpResult {
    std::vector<EntityId> body_ids;
    std::vector<EntityId> instance_ids;
};
bool insert_sxp(Document& dest, const std::string& path,
                const std::array<double, 3>& base_translation = {0, 0, 0},
                InsertSxpResult* out = nullptr, std::string* err = nullptr);

// Peek an .sxp without mutating the destination document — body names + volumes
// for the Insert Components chooser.
struct SxpComponentInfo {
    bool ok = false;
    std::string error;
    std::vector<std::string> body_ids;
    std::vector<std::string> body_names;
    std::vector<double> volumes;
};
SxpComponentInfo sxp_component_info(const std::string& path);

}  // namespace sx
