#include "sx/cam.hpp"

#include <algorithm>
#include <cmath>
#include <sstream>

namespace sx::cam {

Toolpath pocket_rect(double x0, double y0, double x1, double y1, double depth,
                     double stepover) {
    if (x1 < x0) std::swap(x0, x1);
    if (y1 < y0) std::swap(y0, y1);
    if (stepover <= 0.0) stepover = 2.0;
    Toolpath tp;
    tp.stepover = stepover;
    tp.depth = depth;
    bool flip = false;
    for (double y = y0; y <= y1 + 1e-9; y += stepover) {
        if (!flip) {
            tp.points.push_back({x0, y, -depth});
            tp.points.push_back({x1, y, -depth});
        } else {
            tp.points.push_back({x1, y, -depth});
            tp.points.push_back({x0, y, -depth});
        }
        flip = !flip;
    }
    return tp;
}

std::string post_gcode(const Toolpath& path, double feed) {
    std::ostringstream o;
    o << "G21\nG90\nG0 Z5\nF" << feed << "\n";
    for (size_t i = 0; i < path.points.size(); ++i) {
        const auto& p = path.points[i];
        o << (i == 0 ? "G0" : "G1") << " X" << p[0] << " Y" << p[1] << " Z" << p[2] << "\n";
    }
    o << "G0 Z5\nM2\n";
    return o.str();
}

}  // namespace sx::cam
