#pragma once
// The filled cross-section of one solid. The viewport clips with a plane;
// this is the cap that actually sits on the cut, including a 1 mm shell wall.
// Screen drawing lives in SectionCap — this file is only the triangles.

#include <cstdint>
#include <vector>

#include <TopoDS_Shape.hxx>

namespace sx {

struct SectionCapMesh {
    std::vector<float> positions;  // xyz triplets, model space
    std::vector<uint32_t> indices;

    bool empty() const { return indices.size() < 3; }

    // True when `p` lies on the cap (within `tol` of a triangle, inside it).
    bool covers(double x, double y, double z, double tol = 0.2) const;
};

// Triangles of `solid` ∩ the plane through `point` with `normal`.
// Empty when the plane misses the solid.
SectionCapMesh section_cap(const TopoDS_Shape& solid, double px, double py, double pz,
                           double nx, double ny, double nz);

}  // namespace sx
