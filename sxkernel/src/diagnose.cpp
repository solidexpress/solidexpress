#include "sx/diagnose.hpp"

#include "sx/document.hpp"
#include "sx/features.hpp"

namespace sx {

Diagnosis diagnose_failed_feature(const Document& doc, const EntityId& feature,
                                  const std::string& error) {
    Diagnosis d;
    d.feature = feature;
    d.error = error;
    if (const Feature* f = doc.graph().feature(feature)) {
        d.feature_name = f->name.empty() ? to_string(f->type) : f->name;
    }
    d.released = doc.last_released_ids();
    if (!d.released.empty()) {
        d.repairs.push_back("Rematch " + std::to_string(d.released.size()) +
                            " released id(s) by signature");
    }
    if (d.error.find("fillet") != std::string::npos ||
        (d.feature_name.find("fillet") != std::string::npos)) {
        d.repairs.push_back("Pick a surviving edge and rebuild the fillet");
    }
    if (d.repairs.empty()) d.repairs.push_back("Edit the feature params and regenerate");
    return d;
}

}  // namespace sx
