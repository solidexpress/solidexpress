#pragma once
// 3D sketch v1 (Wave 1.11): a separate 3D curve set that feeds Path / Sweep.
// Not a mutation of the 2D PlaneGCS sketch — one immutable plane stays 2D.

#include <array>
#include <string>
#include <utility>
#include <vector>

#include <nlohmann/json.hpp>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct Sketch3D {
    EntityId id;
    std::string name = "3D Sketch";
    std::vector<std::array<double, 3>> points;
    std::vector<std::pair<int, int>> segments;
};

void to_json(nlohmann::json& j, const Sketch3D& s);
void from_json(const nlohmann::json& j, Sketch3D& s);

// Polyline through the points in order (or along segments when present).
std::vector<std::array<double, 3>> sketch3d_path(const Sketch3D& s);

// Associative convert: store edge UUIDs on a 2D sketch feature and drop pierce
// points onto its plane. Rebuilds those points from the live edges on regen.
int convert_edges_to_sketch(Document& doc, const EntityId& sketch_fid,
                            const std::vector<EntityId>& edge_ids, std::string* err = nullptr);

// Rebuild converted pierce points from stored edge UUIDs. Returns points written.
int rebuild_converted_points(Document& doc, const EntityId& sketch_fid);

}  // namespace sx
