#include "sx/curves.hpp"

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepLib.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Curve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include "sx/occt_types.hpp"
#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <stdexcept>

namespace sx::curves {

TopoDS_Wire helix(const gp_Ax2& axis, double radius, double pitch, double turns,
                  bool left_handed) {
    if (radius <= 0.0) throw std::runtime_error("curves::helix: radius must be positive");
    if (turns <= 0.0) throw std::runtime_error("curves::helix: turns must be positive");

    // Helix as a straight line in (U,V) on the cylinder: U = angle, V = height.
    // Slope dV/dU = pitch/(2π) so one full turn advances `pitch` along the axis.
    Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(axis), radius);
    const double u_end = (left_handed ? -1.0 : 1.0) * 2.0 * M_PI * turns;
    const double v_end = pitch * turns;
    Handle(Geom2d_TrimmedCurve) seg =
        GCE2d_MakeSegment(gp_Pnt2d(0.0, 0.0), gp_Pnt2d(u_end, v_end)).Value();

    BRepBuilderAPI_MakeEdge mk_edge(seg, cyl, seg->FirstParameter(), seg->LastParameter());
    if (!mk_edge.IsDone()) throw std::runtime_error("curves::helix: failed to build edge");
    TopoDS_Edge edge = mk_edge.Edge();
    BRepLib::BuildCurves3d(edge);

    BRepBuilderAPI_MakeWire mk_wire(edge);
    if (!mk_wire.IsDone()) throw std::runtime_error("curves::helix: failed to build wire");
    return mk_wire.Wire();
}

TopoDS_Wire spiral(const gp_Ax2& axis, double start_radius, double end_radius, double turns) {
    if (start_radius < 0.0 || end_radius < 0.0)
        throw std::runtime_error("curves::spiral: radii must be non-negative");
    if (turns <= 0.0) throw std::runtime_error("curves::spiral: turns must be positive");

    constexpr int k_samples_per_turn = 32;
    const int n = std::max(2, static_cast<int>(std::ceil(turns * k_samples_per_turn)) + 1);
    sx::occt::Array1OfPnt poles(1, n);

    const gp_Pnt origin = axis.Location();
    const gp_Dir x = axis.XDirection();
    const gp_Dir y = axis.YDirection();
    const double theta_max = 2.0 * M_PI * turns;

    for (int i = 0; i < n; ++i) {
        const double t = static_cast<double>(i) / static_cast<double>(n - 1);
        const double theta = t * theta_max;
        const double r = start_radius + (end_radius - start_radius) * t;
        gp_Pnt p = origin.Translated(gp_Vec(x) * (r * std::cos(theta)) +
                                     gp_Vec(y) * (r * std::sin(theta)));
        poles.SetValue(i + 1, p);
    }

    Handle(Geom_BSplineCurve) bspline = GeomAPI_PointsToBSpline(poles).Curve();
    if (bspline.IsNull()) throw std::runtime_error("curves::spiral: BSpline fit failed");
    Handle(Geom_Curve) curve = bspline;

    BRepBuilderAPI_MakeEdge mk_edge(curve);
    if (!mk_edge.IsDone()) throw std::runtime_error("curves::spiral: failed to build edge");
    BRepBuilderAPI_MakeWire mk_wire(mk_edge.Edge());
    if (!mk_wire.IsDone()) throw std::runtime_error("curves::spiral: failed to build wire");
    return mk_wire.Wire();
}

TopoDS_Wire polyline(const std::vector<gp_Pnt>& pts) {
    if (pts.size() < 2)
        throw std::runtime_error("curves::polyline: need at least two points");

    BRepBuilderAPI_MakeWire mk;
    for (size_t i = 1; i < pts.size(); ++i) {
        if (pts[i - 1].Distance(pts[i]) < 1e-12)
            throw std::runtime_error("curves::polyline: zero-length segment");
        BRepBuilderAPI_MakeEdge edge(pts[i - 1], pts[i]);
        if (!edge.IsDone()) throw std::runtime_error("curves::polyline: failed to build edge");
        mk.Add(edge.Edge());
    }
    if (!mk.IsDone()) throw std::runtime_error("curves::polyline: failed to build wire");
    return mk.Wire();
}

}  // namespace sx::curves
