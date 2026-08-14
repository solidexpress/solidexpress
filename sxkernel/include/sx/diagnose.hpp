#pragma once
// What's Wrong (Wave 3.5): a failed feature plus the naming ids that were
// released on the last replace_body_shape. Opened from the timeline FailBadge.

#include <string>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct Diagnosis {
    EntityId feature;
    std::string feature_name;
    std::string error;
    std::vector<EntityId> released;
    std::vector<std::string> repairs;
};

// Names the failed feature, lists released subshape ids, and offers rematch
// candidates. Empty feature id when nothing has failed.
Diagnosis diagnose_failed_feature(const Document& doc, const EntityId& feature,
                                  const std::string& error);

}  // namespace sx
