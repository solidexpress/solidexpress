#pragma once
// Assembly-level operations on instances: exploded views and patterns of a
// component. Both work off connectors and joints, not the face-pair mate.

#include <string>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Document;

// Separate every movable instance along its joint axis (or radially away from
// the assembly centre when it has no joint), by `factor` times the part's own
// size. Factor 0 collapses back to the remembered assembled placement, so an
// exploded view is reversible without re-solving. Returns instances moved.
int explode(Document& doc, double factor);

// True while any instance is displaced by explode().
bool is_exploded(const Document& doc);

// Copy `instance` around the axis of the joint that drives it (or about world Z
// through the assembly centre when it has none), `count` placements in total
// including the seed. Each copy inherits the seed's joint, so a bolt circle is
// one joint definition. Returns the new instance ids.
std::vector<EntityId> pattern_instance(Document& doc, const EntityId& instance, int count,
                                       double total_angle, std::string* err = nullptr);

}  // namespace sx
