#pragma once
// iLogic-style rules over the variable table (Wave 3).

#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace sx {

class FeatureGraph;

struct Rule {
    std::string name;
    // "if width > 100 then suppress rib"
    std::string when;   // expression on variables, e.g. "width > 100"
    std::string then;   // "suppress <feature name or uuid>"
};

void to_json(nlohmann::json& j, const Rule& r);
void from_json(const nlohmann::json& j, Rule& r);

// Evaluates rules against the graph variable table. Returns how many fired.
int apply_rules(FeatureGraph& graph, const std::vector<Rule>& rules);

}  // namespace sx
