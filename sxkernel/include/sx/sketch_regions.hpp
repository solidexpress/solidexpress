#pragma once
// Arrangement of sketch curves plus an optional host-face boundary.
// One region is a closed area a click can name. Extrude takes a set of ids.

#include <array>
#include <string>
#include <vector>

#include <TopoDS_Shape.hxx>

#include "sx/sketch.hpp"

namespace sx {

struct SketchRegions {
    std::vector<TopoDS_Shape> faces;  // area descending, then centroid x, y
    std::string error;

    bool empty() const { return faces.empty(); }
    int size() const { return static_cast<int>(faces.size()); }

    // Host face empty → sketch-only closed contours (Selected Contours).
    static SketchRegions arrange(const Sketch& sketch, const TopoDS_Shape& host_face);

    int containing_uv(const Sketch& sketch, double u, double v) const;

    std::vector<Sketch::ContourOutline> outlines(const Sketch& sketch,
                                                 double deflection = 0.05) const;
};

}  // namespace sx
