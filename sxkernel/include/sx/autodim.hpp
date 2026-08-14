#pragma once
// Auto-dimension and propose-on-select (Wave 3.6 / 3.9).

#include <string>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Sketch;

struct ProposeChip {
    std::string verb;  // "parallel", "perpendicular", "equal"
    EntityId a;
    EntityId b;
    double score = 0.0;
};

// Promote every weak dimension to strong. Returns how many promoted.
int auto_dimension(Sketch& sketch);

// Near-parallel / near-perpendicular / near-equal line pairs as chips.
std::vector<ProposeChip> propose_on_select(const Sketch& sketch,
                                           const std::vector<EntityId>& selected);

}  // namespace sx
