#include "ops.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <BRep_Tool.hxx>
#include <Standard_Failure.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Elips.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <TColStd_HArray1OfBoolean.hxx>
#include <TColgp_Array1OfVec.hxx>
#include <TColgp_HArray1OfPnt.hxx>

#include <algorithm>
#include <cmath>
#include <vector>

namespace sx::feature_ops {
namespace {

Handle(Geom_BSplineCurve) interpolate_curve(const std::vector<gp_Pnt>& pts) {
    if (pts.size() < 2) return {};
    Handle(TColgp_HArray1OfPnt) arr =
        new TColgp_HArray1OfPnt(1, static_cast<int>(pts.size()));
    for (int i = 0; i < static_cast<int>(pts.size()); ++i) arr->SetValue(i + 1, pts[static_cast<size_t>(i)]);
    GeomAPI_Interpolate interp(arr, Standard_False, 1.0e-7);
    interp.Perform();
    if (!interp.IsDone()) return {};
    return interp.Curve();
}

gp_Dir plane_normal(const SketchPlane& pl) {
    const auto n = pl.normal();
    return gp_Dir(n[0], n[1], n[2]);
}

gp_Pnt plane_origin(const SketchPlane& pl) { return sketch_uv_to_3d(pl, 0.0, 0.0); }

gp_Dir uv_dir(const SketchPlane& pl, double du, double dv) {
    gp_Pnt a = plane_origin(pl);
    gp_Pnt b = sketch_uv_to_3d(pl, du, dv);
    gp_Vec v(a, b);
    if (v.Magnitude() < 1e-15) return gp_Dir(pl.x_dir[0], pl.x_dir[1], pl.x_dir[2]);
    return gp_Dir(v);
}

struct PathSeg {
    gp_Pnt a, b;
    gp_Pnt mid;
    enum Kind { Line, Circle, Other } kind = Line;
    TopoDS_Edge edge;
    bool used = false;
};

TopoDS_Edge make_line_edge(const gp_Pnt& from, const gp_Pnt& to) {
    if (from.Distance(to) < 1e-12) return {};
    BRepBuilderAPI_MakeEdge mk(from, to);
    return mk.IsDone() ? mk.Edge() : TopoDS_Edge{};
}

TopoDS_Edge make_arc_edge(const gp_Pnt& from, const gp_Pnt& mid, const gp_Pnt& to) {
    GC_MakeArcOfCircle mk(from, mid, to);
    if (!mk.IsDone()) return {};
    BRepBuilderAPI_MakeEdge e(mk.Value());
    return e.IsDone() ? e.Edge() : TopoDS_Edge{};
}

TopoDS_Edge rebuild_seg(const PathSeg& s, const gp_Pnt& from, const gp_Pnt& to) {
    if (s.kind == PathSeg::Circle) return make_arc_edge(from, s.mid, to);
    if (s.kind == PathSeg::Line) return make_line_edge(from, to);
    return s.edge;  // spline / ellipse: keep the exact edge
}

bool wire_ends(const TopoDS_Wire& w, gp_Pnt& start, gp_Pnt& end) {
    if (w.IsNull()) return false;
    BRepTools_WireExplorer ex(w);
    if (!ex.More()) return false;
    start = BRep_Tool::Pnt(TopExp::FirstVertex(ex.Current(), Standard_True));
    TopoDS_Edge last = ex.Current();
    for (; ex.More(); ex.Next()) last = ex.Current();
    end = BRep_Tool::Pnt(TopExp::LastVertex(last, Standard_True));
    return true;
}

std::vector<TopoDS_Edge> wire_edges(const TopoDS_Wire& w, bool reverse) {
    std::vector<TopoDS_Edge> edges;
    for (BRepTools_WireExplorer ex(w); ex.More(); ex.Next())
        edges.push_back(TopoDS::Edge(ex.Current()));
    if (reverse) {
        std::reverse(edges.begin(), edges.end());
        for (auto& e : edges) e.Reverse();
    }
    return edges;
}

TopoDS_Wire edges_to_wire(const std::vector<TopoDS_Edge>& edges) {
    if (edges.empty()) return {};
    BRepBuilderAPI_MakeWire mk;
    for (const auto& e : edges) {
        if (e.IsNull()) return {};
        mk.Add(e);
    }
    if (!mk.IsDone()) return {};
    return mk.Wire();
}

TopoDS_Wire closed_conic_wire(const Sketch& sk) {
    const auto& pl = sk.plane();
    const SketchEntity* sole = nullptr;
    for (const auto& e : sk.entities()) {
        if (e.construction || e.external) continue;
        if (e.type == SketchEntityType::Point) continue;
        if (sole) return {};
        sole = &e;
    }
    if (!sole) return {};
    const gp_Dir n = plane_normal(pl);
    if (sole->type == SketchEntityType::Circle && sole->params.size() >= 3) {
        const double cx = sk.param(sole->params[0]);
        const double cy = sk.param(sole->params[1]);
        const double r = sk.param(sole->params[2]);
        if (r < 1e-9) return {};
        gp_Circ circ(gp_Ax2(sketch_uv_to_3d(pl, cx, cy), n), r);
        BRepBuilderAPI_MakeEdge e(circ);
        if (!e.IsDone()) return {};
        BRepBuilderAPI_MakeWire mk(e.Edge());
        return mk.IsDone() ? mk.Wire() : TopoDS_Wire{};
    }
    if ((sole->type == SketchEntityType::Ellipse || sole->type == SketchEntityType::EllipticalArc) &&
        sole->type == SketchEntityType::Ellipse) {
        auto axes = sk.ellipse_axes(sole->id);
        if (!axes) return {};
        const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3],
                     ang = (*axes)[4];
        if (rx < 1e-9 || ry < 1e-9) return {};
        gp_Ax2 ax(sketch_uv_to_3d(pl, cx, cy), n, uv_dir(pl, std::cos(ang), std::sin(ang)));
        gp_Elips el(ax, rx, ry);
        BRepBuilderAPI_MakeEdge e(el);
        if (!e.IsDone()) return {};
        BRepBuilderAPI_MakeWire mk(e.Edge());
        return mk.IsDone() ? mk.Wire() : TopoDS_Wire{};
    }
    return {};
}

TopoDS_Edge spline_edge(const Sketch& sk, const SketchEntity& e) {
    auto fits = sk.spline_fit_points(e.id);
    if (fits.size() < 2) return {};
    const auto& pl = sk.plane();
    std::vector<gp_Pnt> pts;
    pts.reserve(fits.size());
    for (const auto& xy : fits) pts.push_back(sketch_uv_to_3d(pl, xy[0], xy[1]));
    Handle(Geom_BSplineCurve) c = interpolate_curve(pts);
    if (c.IsNull()) return {};
    BRepBuilderAPI_MakeEdge mk(c);
    return mk.IsDone() ? mk.Edge() : TopoDS_Edge{};
}

TopoDS_Edge ellipse_arc_edge(const Sketch& sk, const SketchEntity& e) {
    auto axes = sk.ellipse_axes(e.id);
    if (!axes) return {};
    const auto& pl = sk.plane();
    const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3], ang = (*axes)[4];
    if (rx < 1e-9 || ry < 1e-9) return {};
    gp_Ax2 ax(sketch_uv_to_3d(pl, cx, cy), plane_normal(pl),
              uv_dir(pl, std::cos(ang), std::sin(ang)));
    Handle(Geom_Ellipse) ge = new Geom_Ellipse(gp_Elips(ax, rx, ry));
    double a0 = 0.0, a1 = 2.0 * M_PI;
    if (e.type == SketchEntityType::EllipticalArc && e.params.size() >= 7) {
        a0 = sk.param(e.params[5]);
        a1 = sk.param(e.params[6]);
        while (a1 <= a0) a1 += 2.0 * M_PI;
    }
    Handle(Geom_TrimmedCurve) trim = new Geom_TrimmedCurve(ge, a0, a1);
    BRepBuilderAPI_MakeEdge mk(trim);
    return mk.IsDone() ? mk.Edge() : TopoDS_Edge{};
}

}  // namespace

TopoDS_Wire interpolate_wire(const std::vector<gp_Pnt>& pts) {
    Handle(Geom_BSplineCurve) c = interpolate_curve(pts);
    if (c.IsNull()) return {};
    BRepBuilderAPI_MakeEdge e(c);
    if (!e.IsDone()) return {};
    BRepBuilderAPI_MakeWire mk(e.Edge());
    return mk.IsDone() ? mk.Wire() : TopoDS_Wire{};
}

nlohmann::json sample_wire_polyline(const TopoDS_Wire& wire, int samples_per_edge) {
    nlohmann::json path = nlohmann::json::array();
    if (wire.IsNull()) return path;
    const int n = std::max(2, samples_per_edge);
    auto push = [&](const gp_Pnt& p) {
        if (!path.empty()) {
            gp_Pnt prev = pnt_from(path.back());
            if (prev.Distance(p) < 1e-12) return;
        }
        path.push_back(pnt_to_json(p));
    };
    for (BRepTools_WireExplorer ex(wire); ex.More(); ex.Next()) {
        BRepAdaptor_Curve c(ex.Current());
        for (int s = 0; s <= n; ++s) {
            const double t = static_cast<double>(s) / n;
            const double u = c.FirstParameter() + t * (c.LastParameter() - c.FirstParameter());
            push(c.Value(u));
        }
    }
    return path;
}

TopoDS_Wire join_exact_wires(const std::vector<TopoDS_Wire>& wires) {
    std::vector<TopoDS_Wire> live;
    for (const auto& w : wires)
        if (!w.IsNull()) live.push_back(w);
    if (live.empty()) return {};
    if (live.size() == 1) return live.front();
    std::vector<TopoDS_Edge> acc = wire_edges(live.front(), false);
    gp_Pnt head, tail;
    if (!wire_ends(live.front(), head, tail)) return {};
    const double join = 0.5;
    for (size_t i = 1; i < live.size(); ++i) {
        gp_Pnt b0, b1;
        if (!wire_ends(live[i], b0, b1)) return {};
        const double d0 = tail.Distance(b0);
        const double d1 = tail.Distance(b1);
        const bool reverse = d1 < d0;
        const double gap = reverse ? d1 : d0;
        const gp_Pnt attach = reverse ? b1 : b0;
        const gp_Pnt new_tail = reverse ? b0 : b1;
        if (gap > join) return {};
        if (gap > 1e-9) {
            TopoDS_Edge bridge = make_line_edge(tail, attach);
            if (bridge.IsNull()) return {};
            acc.push_back(bridge);
        }
        auto more = wire_edges(live[i], reverse);
        acc.insert(acc.end(), more.begin(), more.end());
        tail = new_tail;
    }
    return edges_to_wire(acc);
}

TopoDS_Wire sketch_exact_wire(const Sketch& sk, bool closed) {
    if (TopoDS_Wire sole = closed_conic_wire(sk); !sole.IsNull()) return sole;

    const double eps = 1e-9;
    const double join = 0.5;
    const auto& pl = sk.plane();
    std::vector<PathSeg> segs;

    auto add_line = [&](gp_Pnt a, gp_Pnt b) {
        if (a.Distance(b) < eps) return;
        PathSeg s;
        s.a = a;
        s.b = b;
        s.mid = gp_Pnt(0.5 * (a.X() + b.X()), 0.5 * (a.Y() + b.Y()), 0.5 * (a.Z() + b.Z()));
        s.kind = PathSeg::Line;
        s.edge = make_line_edge(a, b);
        if (!s.edge.IsNull()) segs.push_back(std::move(s));
    };

    for (const auto& e : sk.entities()) {
        if (e.construction || e.external) continue;
        if (e.type == SketchEntityType::Point) continue;
        if (e.type == SketchEntityType::Line && e.params.size() >= 4) {
            add_line(sketch_uv_to_3d(pl, sk.param(e.params[0]), sk.param(e.params[1])),
                     sketch_uv_to_3d(pl, sk.param(e.params[2]), sk.param(e.params[3])));
        } else if (e.type == SketchEntityType::Arc && e.params.size() >= 5) {
            const double cx = sk.param(e.params[0]);
            const double cy = sk.param(e.params[1]);
            const double r = sk.param(e.params[2]);
            double sa = sk.param(e.params[3]), ea = sk.param(e.params[4]);
            if (r < eps) continue;
            if (ea < sa) ea += 2.0 * M_PI;
            gp_Pnt center = sketch_uv_to_3d(pl, cx, cy);
            gp_Circ circ(gp_Ax2(center, plane_normal(pl), uv_dir(pl, 1.0, 0.0)), r);
            Handle(Geom_Circle) gc = new Geom_Circle(circ);
            Handle(Geom_TrimmedCurve) trim = new Geom_TrimmedCurve(gc, sa, ea);
            BRepBuilderAPI_MakeEdge mk(trim);
            if (!mk.IsDone()) continue;
            const double mid_a = 0.5 * (sa + ea);
            gp_Pnt a = sketch_uv_to_3d(pl, cx + r * std::cos(sa), cy + r * std::sin(sa));
            gp_Pnt b = sketch_uv_to_3d(pl, cx + r * std::cos(ea), cy + r * std::sin(ea));
            if (e.params.size() >= 9) {
                a = sketch_uv_to_3d(pl, sk.param(e.params[5]), sk.param(e.params[6]));
                b = sketch_uv_to_3d(pl, sk.param(e.params[7]), sk.param(e.params[8]));
            }
            PathSeg s;
            s.a = a;
            s.b = b;
            s.mid = sketch_uv_to_3d(pl, cx + r * std::cos(mid_a), cy + r * std::sin(mid_a));
            s.kind = PathSeg::Circle;
            s.edge = mk.Edge();
            segs.push_back(std::move(s));
        } else if (e.type == SketchEntityType::Spline) {
            TopoDS_Edge edge = spline_edge(sk, e);
            if (edge.IsNull()) continue;
            auto fits = sk.spline_fit_points(e.id);
            PathSeg s;
            s.a = sketch_uv_to_3d(pl, fits.front()[0], fits.front()[1]);
            s.b = sketch_uv_to_3d(pl, fits.back()[0], fits.back()[1]);
            s.mid = s.a;
            s.kind = PathSeg::Other;
            s.edge = edge;
            segs.push_back(std::move(s));
        } else if (e.type == SketchEntityType::EllipticalArc) {
            TopoDS_Edge edge = ellipse_arc_edge(sk, e);
            if (edge.IsNull()) continue;
            auto fits_end = [&](bool start) -> gp_Pnt {
                if (e.params.size() >= 11) {
                    const size_t i = start ? 7 : 9;
                    return sketch_uv_to_3d(pl, sk.param(e.params[i]), sk.param(e.params[i + 1]));
                }
                BRepAdaptor_Curve c(edge);
                return start ? c.Value(c.FirstParameter()) : c.Value(c.LastParameter());
            };
            PathSeg s;
            s.a = fits_end(true);
            s.b = fits_end(false);
            s.mid = s.a;
            s.kind = PathSeg::Other;
            s.edge = edge;
            segs.push_back(std::move(s));
        }
    }
    if (segs.empty()) return {};

    std::vector<PathSeg*> chain;
    PathSeg* seed = &segs[0];
    seed->used = true;
    chain.push_back(seed);
    gp_Pnt head = seed->a;
    gp_Pnt tail = seed->b;
    auto grow = [&]() -> bool {
        double best = join;
        PathSeg* pick = nullptr;
        int how = -1;
        for (auto& s : segs) {
            if (s.used) continue;
            const double d[4] = {tail.Distance(s.a), tail.Distance(s.b), head.Distance(s.a),
                                 head.Distance(s.b)};
            for (int h = 0; h < 4; ++h) {
                if (d[h] < best) {
                    best = d[h];
                    pick = &s;
                    how = h;
                }
            }
        }
        if (pick == nullptr) return false;
        pick->used = true;
        if (how == 0) {
            if (best > eps) pick->edge = rebuild_seg(*pick, tail, pick->b);
            tail = pick->b;
            chain.push_back(pick);
        } else if (how == 1) {
            if (best > eps) pick->edge = rebuild_seg(*pick, tail, pick->a);
            tail = pick->a;
            chain.push_back(pick);
        } else if (how == 2) {
            if (best > eps) pick->edge = rebuild_seg(*pick, pick->b, head);
            head = pick->b;
            chain.insert(chain.begin(), pick);
        } else {
            if (best > eps) pick->edge = rebuild_seg(*pick, pick->a, head);
            head = pick->a;
            chain.insert(chain.begin(), pick);
        }
        return true;
    };
    while (grow()) {
    }
    std::vector<TopoDS_Edge> edges;
    for (auto* s : chain) {
        if (s->edge.IsNull()) return {};
        edges.push_back(s->edge);
    }
    if (closed && head.Distance(tail) > eps && head.Distance(tail) <= join)
        edges.push_back(make_line_edge(tail, head));
    return edges_to_wire(edges);
}

TopoDS_Wire sketch_spine_wire(const Sketch& sk) { return sketch_exact_wire(sk, false); }

TopoDS_Shape rib_along_wire(const TopoDS_Wire& spine, double thickness, double height,
                            const gp_Dir& dir, std::string* err) {
    auto bail = [&](const char* msg) {
        if (err) *err = msg;
        return TopoDS_Shape();
    };
    if (spine.IsNull()) return bail("rib needs an open profile");
    if (thickness <= 1e-9 || std::abs(height) <= 1e-9)
        return bail("rib needs a positive thickness and a non-zero height");

    BRepTools_WireExplorer ex(spine);
    if (!ex.More()) return bail("rib profile is empty");
    const TopoDS_Edge first = ex.Current();
    BRepAdaptor_Curve c(first);
    const bool rev = first.Orientation() == TopAbs_REVERSED;
    const double u = rev ? c.LastParameter() : c.FirstParameter();
    gp_Pnt p;
    gp_Vec tan;
    c.D1(u, p, tan);
    if (rev) tan.Reverse();
    if (tan.Magnitude() < 1e-12) return bail("rib profile has a degenerate start");
    tan.Normalize();
    gp_Vec side = gp_Vec(dir).Crossed(tan);
    if (side.Magnitude() < 1e-9) return bail("rib profile is parallel to its own height");
    side.Normalize();
    side *= thickness * 0.5;
    const gp_Vec up = gp_Vec(dir) * height;
    BRepBuilderAPI_MakePolygon poly(p.Translated(side), p.Translated(-side),
                                    p.Translated(-side).Translated(up),
                                    p.Translated(side).Translated(up), true);
    if (!poly.IsDone()) return bail("rib section outline failed");
    try {
        BRepOffsetAPI_MakePipeShell shell(spine);
        shell.SetMode(dir);
        shell.SetTransitionMode(BRepBuilderAPI_RightCorner);
        shell.Add(poly.Wire(), /*withContact=*/false, /*withCorrection=*/true);
        shell.Build();
        if (!shell.IsDone() || !shell.MakeSolid()) return bail("rib pipe failed");
        TopoDS_Shape s = shell.Shape();
        if (s.IsNull()) return bail("rib pipe failed");
        return s;
    } catch (const Standard_Failure&) {
        return bail("rib pipe failed");
    }
}

}  // namespace sx::feature_ops
