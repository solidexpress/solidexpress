#pragma once
// 3D sketch v1 (Wave 1.11): a separate 3D curve set that feeds Path / Sweep.
// Not a mutation of the 2D PlaneGCS sketch — one immutable plane stays 2D.

#include <array>
#include <string>
#include <utility>
#include <vector>

#include <nlohmann/json.hpp>

#include "sx/ids.hpp"
#include "sx/sketch.hpp"

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

// One external construction entity for a model edge (line, circle/arc, or
// in-plane BSpline/Bezier spline). Null when the type is unsupported. A
// second call for the same edge returns the existing entity.
EntityId add_external_edge(Document& doc, const EntityId& sketch_fid,
                           const EntityId& edge_id);

// Rebuild converted pierce points from stored edge UUIDs. Returns points written.
int rebuild_converted_points(Document& doc, const EntityId& sketch_fid);

// Re-project every external entity from its live edge. Marks dangling when the
// edge is gone. Returns entities updated.
int rebuild_projected_externals(Document& doc, const EntityId& sketch_fid);

// Analytic circles whose 3D curve lies on `plane` (BRepAdaptor_Curve::Circle).
struct PlaneCircle {
    EntityId edge;
    std::array<double, 3> center{0, 0, 0};
    double radius = 0;
};
std::vector<PlaneCircle> circles_on_plane(const Document& doc, const SketchPlane& plane);

// True curve ∩ plane (GeomAPI_IntCS), plus open-curve endpoints on the plane.
std::vector<std::array<double, 2>> pierce_uvs(const Document& doc, const SketchPlane& plane);

}  // namespace sx
