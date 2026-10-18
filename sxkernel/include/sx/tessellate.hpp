#pragma once
// Tessellation service: OCCT shape -> raw triangle buffers, Godot-free so the
// kernel stays headless-testable. sxcore converts these to ArrayMesh.

#include <cstdint>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct FaceMesh {
    EntityId face;                    // stable face id
    std::vector<float> positions;     // xyz triplets
    std::vector<float> normals;       // xyz triplets, same count
    std::vector<uint32_t> indices;    // triangle list into this face's vertices
};

struct BodyMesh {
    EntityId body;
    std::vector<FaceMesh> faces;
    // Edge polylines for wireframe/selection display.
    struct EdgeLine {
        EntityId edge;
        std::vector<float> points;  // xyz polyline
    };
    std::vector<EdgeLine> edges;
};

// linear_deflection in model units (mm); angular_deflection in radians.
// isolate=true meshes a geometric copy so export deflection does not stick
// on the live body (OCCT IncrementalMesh keeps a finer cache).
BodyMesh tessellate_body(const Document& doc, const EntityId& body,
                         double linear_deflection = 0.2,
                         double angular_deflection = 0.35,
                         bool isolate = false);

}  // namespace sx
