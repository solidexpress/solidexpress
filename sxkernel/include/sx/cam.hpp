#pragma once
// 2.5-axis CAM pocket (Wave 4.3). Own posts — no CalculiX/Gmsh.

#include <array>
#include <string>
#include <vector>

namespace sx::cam {

using Pnt = std::array<double, 3>;

struct Toolpath {
    std::vector<Pnt> points;  // G1 polyline in mm
    double stepover = 2.0;
    double depth = 2.0;
};

// Zig-zag pocket of a rectangle at z = -depth.
Toolpath pocket_rect(double x0, double y0, double x1, double y1, double depth,
                     double stepover);

// Simple LinuxCNC-ish G-code (G21 G90, G0/G1).
std::string post_gcode(const Toolpath& path, double feed = 400.0);

}  // namespace sx::cam
