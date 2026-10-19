#pragma once
// Own DXF reader/writer (LINE / CIRCLE / ARC / ELLIPSE / SPLINE / LWPOLYLINE).
// No libdxfrw.

#include <array>
#include <string>
#include <vector>

#include "sx/ids.hpp"
#include "sx/sketch.hpp"

namespace sx {

struct DxfEntity {
    enum class Kind { Line, Circle, Arc, Ellipse, Spline } kind = Kind::Line;
    double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
    double cx = 0, cy = 0, radius = 0;
    double start_angle = 0, end_angle = 0;  // degrees, ARC only
    // ELLIPSE: major-axis endpoint relative to center (DXF 11/21), ratio = minor/major.
    double major_x = 0, major_y = 0, ratio = 1;
    double param_start = 0, param_end = 6.283185307179586;
    // SPLINE fit/control points in XY.
    int degree = 3;
    std::vector<std::array<double, 2>> points;
};

// Parse a text DXF. Returns empty + *err on I/O or empty ENTITIES.
// Unsupported entity types are listed in *refused (HATCH, DIMENSION, …).
std::vector<DxfEntity> read_dxf(const std::string& path, std::string* err = nullptr,
                                std::vector<std::string>* refused = nullptr);

// Append parsed entities onto a sketch (model-space XY).
int add_dxf_to_sketch(Sketch& sketch, const std::vector<DxfEntity>& entities);

// Create a Sketch feature on the document graph from a DXF file.
EntityId import_dxf_sketch(class Document& doc, const std::string& path, std::string* err = nullptr);

// Write ENTITIES (LINE / CIRCLE / ARC / ELLIPSE / SPLINE).
bool write_dxf(const std::vector<DxfEntity>& entities, const std::string& path,
               std::string* err = nullptr);

// Export the drawing document (or a front-view fallback) as typed DXF curves
// plus HLR polylines.
bool export_drawing_dxf(const Document& doc, const std::string& path, std::string* err = nullptr);

}  // namespace sx
