#include "sx/user_feature.hpp"

#include "sx/document.hpp"
#include "sx/features.hpp"

namespace sx {

nlohmann::json user_csink_recipe() {
    return nlohmann::json{
        {"name", "csink"},
        {"params",
         {{"target", ""},
          {"x", 0.0},
          {"y", 0.0},
          {"z", 0.0},
          {"diameter", 6.0},
          {"depth", 10.0},
          {"cs_diameter", 12.0},
          {"cs_angle_deg", 90.0}}},
        {"steps",
         nlohmann::json::array(
             {nlohmann::json{{"type", "hole"},
                             {"hole_type", "countersink"},
                             {"target", "$target"},
                             {"diameter", "$diameter"},
                             {"depth", "$depth"},
                             {"cs_diameter", "$cs_diameter"},
                             {"cs_angle_deg", "$cs_angle_deg"},
                             {"position", nlohmann::json::array({"$x", "$y", "$z"})}}})}};
}

namespace {

nlohmann::json subst(const nlohmann::json& node, const nlohmann::json& args) {
    if (node.is_string()) {
        const auto s = node.get<std::string>();
        if (!s.empty() && s[0] == '$') {
            const auto key = s.substr(1);
            if (args.contains(key)) return args.at(key);
        }
        return node;
    }
    if (node.is_array()) {
        nlohmann::json out = nlohmann::json::array();
        for (const auto& x : node) out.push_back(subst(x, args));
        return out;
    }
    if (node.is_object()) {
        nlohmann::json out = nlohmann::json::object();
        for (auto it = node.begin(); it != node.end(); ++it) out[it.key()] = subst(it.value(), args);
        return out;
    }
    return node;
}

}  // namespace

EntityId instantiate_user_feature(Document& doc, const nlohmann::json& recipe,
                                  const nlohmann::json& args, std::string* err) {
    nlohmann::json params = recipe.value("params", nlohmann::json::object());
    for (auto it = args.begin(); it != args.end(); ++it) params[it.key()] = it.value();
    Feature f;
    f.type = FeatureType::UserFeature;
    f.name = recipe.value("name", "user");
    f.params = params;
    f.params["recipe"] = recipe.value("name", "user");
    f.params["steps"] = subst(recipe.value("steps", nlohmann::json::array()), params);
    const EntityId id = doc.graph().add(std::move(f));
    std::string regen_err;
    if (!doc.graph().regenerate(doc, &regen_err)) {
        if (err) *err = regen_err;
        return {};
    }
    return id;
}

}  // namespace sx
