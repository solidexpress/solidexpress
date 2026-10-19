// One-shot OCCT replica of the locked spanner profiles. Pins check_rung07 volumes.
#include <catch.hpp>

#include <array>
#include <cmath>
#include <string>
#include <vector>

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Elips.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch_tools.hpp"

using namespace sx;

namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr double kDeg = 17.0 * kPi / 180.0;

std::array<double, 2> world(double xp, double yp) {
    return {xp * std::cos(kDeg) - yp * std::sin(kDeg),
            xp * std::sin(kDeg) + yp * std::cos(kDeg)};
}

double area_of(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(s, props);
    return props.Mass();
}

double volume_of(const TopoDS_Shape& s) { return sx::shape::volume(s); }

TopoDS_Shape midplane_prism(const TopoDS_Shape& face, double thickness) {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(0, 0, -thickness * 0.5));
    TopoDS_Shape profile = BRepBuilderAPI_Transform(face, t, true).Shape();
    return BRepPrimAPI_MakePrism(profile, gp_Vec(0, 0, thickness)).Shape();
}

TopoDS_Face hex_face(double cx, double cy, double af, double rot) {
    const double R = af / std::sqrt(3.0);
    BRepBuilderAPI_MakePolygon poly;
    for (int i = 0; i < 6; ++i) {
        const double a = rot + static_cast<double>(i) * kPi / 3.0;
        poly.Add(gp_Pnt(cx + R * std::cos(a), cy + R * std::sin(a), 0.0));
    }
    poly.Close();
    return BRepBuilderAPI_MakeFace(poly.Wire()).Face();
}

TopoDS_Face c_face() {
    const double xj = -25.0 * std::sqrt(1.0 - (12.5 / 27.5) * (12.5 / 27.5));
    Sketch sk("SpannerC");
    auto ell = sk.add_ellipse(0.0, 0.0, 27.5, 25.0, kDeg + kPi * 0.5);
    auto o_hi = world(xj, 12.5);
    auto o_lo = world(xj, -12.5);
    auto i_hi = world(xj + 20.0, 12.5);
    auto i_lo = world(xj + 20.0, -12.5);
    sk.add_line(o_hi[0], o_hi[1], i_hi[0], i_hi[1]);
    sk.add_line(o_lo[0], o_lo[1], i_lo[0], i_lo[1]);
    const double cx_local = (xj + 20.0) - std::sqrt(15.0 * 15.0 - 12.5 * 12.5);
    auto c15 = world(cx_local, 0.0);
    auto throat = world(cx_local + 15.0, 0.0);
    double sa = std::atan2(i_lo[1] - c15[1], i_lo[0] - c15[0]);
    double ea = std::atan2(i_hi[1] - c15[1], i_hi[0] - c15[0]);
    if (ea < sa) ea += 2.0 * kPi;
    double mid = std::atan2(throat[1] - c15[1], throat[0] - c15[0]);
    double from = mid - sa;
    while (from < 0) from += 2.0 * kPi;
    if (from > ea - sa + 1e-9) {
        std::swap(sa, ea);
        if (ea < sa) ea += 2.0 * kPi;
    }
    sk.add_arc(c15[0], c15[1], 15.0, sa, ea);
    auto pick = world(-25.0, 0.0);
    REQUIRE(sketch_tools::trim_entity(sk, ell.str(), pick[0], pick[1]));
    std::string err;
    auto face = sk.profile_face(&err);
    INFO(err);
    REQUIRE_FALSE(face.IsNull());
    REQUIRE(face.ShapeType() == TopAbs_FACE);
    return TopoDS::Face(face);
}

TopoDS_Face ring_face() {
    gp_Circ circ(gp_Ax2(gp_Pnt(240.0, 0.0, 0.0), gp_Dir(0, 0, 1)), 16.5);
    TopoDS_Edge ce = BRepBuilderAPI_MakeEdge(circ);
    TopoDS_Wire cw = BRepBuilderAPI_MakeWire(ce);
    TopoDS_Face outer = BRepBuilderAPI_MakeFace(cw).Face();
    // Point-up hex: vertex at 90°. Second hex rotated 30°.
    TopoDS_Face h1 = hex_face(240.0, 0.0, 25.0, kPi * 0.5);
    TopoDS_Face h2 = hex_face(240.0, 0.0, 25.0, kPi * 0.5 + kPi / 6.0);
    TopoDS_Shape fused = BRepAlgoAPI_Fuse(h1, h2).Shape();
    TopoDS_Shape cut = BRepAlgoAPI_Cut(outer, fused).Shape();
    for (TopExp_Explorer ex(cut, TopAbs_FACE); ex.More(); ex.Next()) {
        TopoDS_Face f = TopoDS::Face(ex.Current());
        if (area_of(f) > 200.0) return f;
    }
    FAIL("ring face missing");
    return {};
}

TopoDS_Face handle_face() {
    // Hits: y = ±10 on the ellipse (+X) and on Ø33.
    auto at_local = [&](double t) {
        return world(25.0 * std::cos(t), 27.5 * std::sin(t));
    };
    auto find_y = [&](double ywant) {
        double best_t = 0.0;
        double best = 1e9;
        for (int i = 0; i <= 4000; ++i) {
            const double t = -kPi + 2.0 * kPi * i / 4000.0;
            auto p = at_local(t);
            if (p[0] <= 0.0) continue;
            const double d = std::abs(p[1] - ywant);
            if (d < best) {
                best = d;
                best_t = t;
            }
        }
        return best_t;
    };
    const double t_hi = find_y(10.0);
    const double t_lo = find_y(-10.0);
    auto p_hi = at_local(t_hi);
    auto p_lo = at_local(t_lo);
    const double circ_x = 240.0 - std::sqrt(16.5 * 16.5 - 10.0 * 10.0);
    gp_Pnt a(p_hi[0], p_hi[1], 0.0);
    gp_Pnt b(circ_x, 10.0, 0.0);
    gp_Pnt c(circ_x, -10.0, 0.0);
    gp_Pnt d(p_lo[0], p_lo[1], 0.0);

    gp_Elips el(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1),
                       gp_Dir(std::cos(kDeg + kPi * 0.5), std::sin(kDeg + kPi * 0.5), 0)),
                27.5, 25.0);
    Handle(Geom_Ellipse) ge = new Geom_Ellipse(el);
    Handle(Geom_TrimmedCurve) te = new Geom_TrimmedCurve(ge, t_lo, t_hi, true);
    // Local t is from the 17° minor axis; Geom_Ellipse param is from major.
    // Build the cap through t=0 (handle side) with a sampled wire instead.
    BRepBuilderAPI_MakeWire mk;
    mk.Add(BRepBuilderAPI_MakeEdge(a, b));
    const double sa = std::atan2(10.0, circ_x - 240.0);
    const double ea = std::atan2(-10.0, circ_x - 240.0);
    gp_Circ circ(gp_Ax2(gp_Pnt(240.0, 0.0, 0.0), gp_Dir(0, 0, 1)), 16.5);
    mk.Add(BRepBuilderAPI_MakeEdge(circ, sa, ea));
    mk.Add(BRepBuilderAPI_MakeEdge(c, d));
    const int N = 64;
    gp_Pnt prev = d;
    // Walk the ellipse from t_lo toward t_hi the long way through t=0.
    auto wrap = [](double t) {
        while (t < -kPi) t += 2.0 * kPi;
        while (t > kPi) t -= 2.0 * kPi;
        return t;
    };
    double t0 = wrap(t_lo);
    double t1 = wrap(t_hi);
    // CCW in local t through 0: t_lo is negative, t_hi positive, short path
    // through 0 is t_lo → 0 → t_hi.
    for (int i = 1; i <= N; ++i) {
        const double t = t0 + (t1 - t0) * i / static_cast<double>(N);
        auto p = at_local(t);
        gp_Pnt q(p[0], p[1], 0.0);
        mk.Add(BRepBuilderAPI_MakeEdge(prev, q));
        prev = q;
    }
    REQUIRE(mk.IsDone());
    BRepBuilderAPI_MakeFace face(mk.Wire());
    REQUIRE(face.IsDone());
    return face.Face();
}

}  // namespace

TEST_CASE("rung07 OCCT replica pins boss volume", "[rung07][replica]") {
    TopoDS_Face c = c_face();
    const double a_c = area_of(c);
    CHECK(a_c == Approx(1495.80).epsilon(0.01));

    TopoDS_Face ring = ring_face();
    const double a_ring = area_of(ring);
    CHECK(a_ring == Approx(275.172).epsilon(0.02));

    TopoDS_Face handle = handle_face();
    const double a_h = area_of(handle);
    CHECK(a_h == Approx(3999.25).epsilon(0.02));

    TopoDS_Shape heads = BRepAlgoAPI_Fuse(midplane_prism(c, 10.0), midplane_prism(ring, 10.0)).Shape();
    TopoDS_Shape boss = BRepAlgoAPI_Fuse(heads, midplane_prism(handle, 6.0)).Shape();
    const double v_boss = volume_of(boss);
    WARN("OCCT replica A_C=" << a_c << " A_ring=" << a_ring << " A_h=" << a_h
                             << " V_boss=" << v_boss);
    CHECK(v_boss == Approx(41705.0).epsilon(0.002));
}
