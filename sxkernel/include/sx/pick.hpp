#pragma once
// Exact ray picking against B-rep geometry (not the tessellation), so pick
// results are precise and return stable face ids.

#include <array>
#include <optional>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct PickHit {
    EntityId body;
    EntityId face;
    std::array<double, 3> point{};
    double distance = 0.0;  // along the ray from origin
};

// Casts a ray through all bodies; returns the nearest hit.
std::optional<PickHit> pick_ray(const Document& doc,
                                const std::array<double, 3>& origin,
                                const std::array<double, 3>& direction);

// Same as pick_ray, but only the named body (instance face picks: transform
// the ray into source space so stacked insert-sources at identity are ignored).
std::optional<PickHit> pick_ray_body(const Document& doc, const EntityId& body,
                                     const std::array<double, 3>& origin,
                                     const std::array<double, 3>& direction);

}  // namespace sx
