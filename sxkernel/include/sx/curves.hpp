#pragma once
// Curve / path wire builders (helix, spiral, polyline) for sweeps and features.

#include <TopoDS_Wire.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>

#include <vector>

namespace sx::curves {

// True helix on a cylinder: 2D line on Geom_CylindricalSurface with V/U slope
// = pitch/(2π), edge over ΔU = 2π·turns, then BRepLib::BuildCurves3d.
// `left_handed` reverses the angular sense (negative U).
// Throws std::runtime_error if radius <= 0 or turns <= 0.
TopoDS_Wire helix(const gp_Ax2& axis, double radius, double pitch, double turns,
                  bool left_handed = false);

// Planar Archimedean spiral in the plane of `axis` (Location + XDir/YDir),
// radius lerping start_radius → end_radius over `turns`. Interpolating
// BSpline through samples with analytic tangents (chord within 1e-7).
// Throws std::runtime_error if turns <= 0 or either radius is negative.
TopoDS_Wire spiral(const gp_Ax2& axis, double start_radius, double end_radius, double turns);

// Multi-edge wire through consecutive points. Throws std::runtime_error if
// pts.size() < 2 (null wire is not returned).
TopoDS_Wire polyline(const std::vector<gp_Pnt>& pts);

}  // namespace sx::curves
