#pragma once
// FeatureScript-shaped user features (Wave 3.3): a JSON recipe whose compiled
// form *is* a graph feature. Natives rewritten here prove the loop.

#include <string>

#include <nlohmann/json.hpp>

#include "sx/ids.hpp"

namespace sx {

class Document;

// Built-in recipe: countersunk hole on a face. Params: target, x, y, z,
// diameter, depth, cs_diameter, cs_angle_deg.
nlohmann::json user_csink_recipe();

// Instantiate a recipe as a UserFeature on the graph. `args` override the
// recipe's default params. Returns the new feature id.
EntityId instantiate_user_feature(Document& doc, const nlohmann::json& recipe,
                                  const nlohmann::json& args, std::string* err = nullptr);

}  // namespace sx
