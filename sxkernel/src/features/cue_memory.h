#pragma once
// Live-edge memory: midpoint and direction of every edge id seen before a rebuild.
// Persists as the edge_memory object, six numbers per id, unchanged from the graph JSON.

#include <map>
#include <string>

#include <nlohmann/json.hpp>

#include "features/topo_cue.h"

namespace sx {

class Document;
class FeatureGraph;
struct Feature;

class CueMemory {
public:
    void remember_live_edges(const FeatureGraph& graph, Document& doc);
    void refresh_feature_cues(FeatureGraph& graph, Feature& feature, Document& doc);
    const TopoCue* find(const std::string& id) const;
    nlohmann::json to_json() const;
    void from_json(const nlohmann::json& j);

private:
    std::map<std::string, TopoCue> edges_;
};

}  // namespace sx
