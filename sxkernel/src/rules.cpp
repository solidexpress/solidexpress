#include "sx/rules.hpp"

#include <cmath>
#include <map>
#include <sstream>

#include "sx/features.hpp"

namespace sx {

void to_json(nlohmann::json& j, const Rule& r) {
    j = nlohmann::json{{"name", r.name}, {"when", r.when}, {"then", r.then}};
}

void from_json(const nlohmann::json& j, Rule& r) {
    r.name = j.value("name", "");
    r.when = j.value("when", "");
    r.then = j.value("then", "");
}

namespace {

bool eval_when(const std::map<std::string, double>& env, const std::string& when) {
    // Tiny parser: "<name> > <number>" or "<name> < <number>".
    std::istringstream in(when);
    std::string name, op;
    double rhs = 0;
    if (!(in >> name >> op >> rhs)) return false;
    auto it = env.find(name);
    if (it == env.end()) return false;
    if (op == ">") return it->second > rhs;
    if (op == "<") return it->second < rhs;
    if (op == ">=") return it->second >= rhs;
    if (op == "<=") return it->second <= rhs;
    if (op == "==") return std::abs(it->second - rhs) < 1e-9;
    return false;
}

}  // namespace

int apply_rules(FeatureGraph& graph, const std::vector<Rule>& rules) {
    std::map<std::string, double> env;
    try {
        env = graph.variables().evaluate();
    } catch (...) {
        return 0;
    }
    int fired = 0;
    for (const auto& r : rules) {
        if (!eval_when(env, r.when)) continue;
        std::istringstream in(r.then);
        std::string verb, target;
        in >> verb >> target;
        if (verb != "suppress" || target.empty()) continue;
        for (const auto& f : graph.timeline()) {
            if (f.name == target || f.id.str() == target ||
                f.name.rfind(target + " ", 0) == 0) {
                graph.set_suppressed(f.id, true);
                ++fired;
                break;
            }
        }
    }
    return fired;
}

}  // namespace sx
