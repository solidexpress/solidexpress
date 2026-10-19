#include "sx/sketch_regions.hpp"
#include "sx/shape_utils.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBndLib.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <BRep_Builder.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GProp_GProps.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Elips.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include "sx/occt_types.hpp"

#include <algorithm>
#include <cmath>

namespace sx {
namespace {

constexpr double kPi = 3.14159265358979323846;

gp_Pnt to3d(const SketchPlane& pl, double u, double v) {
    gp_Pnt o(pl.origin[0], pl.origin[1], pl.origin[2]);
    gp_Vec x(pl.x_dir[0], pl.x_dir[1], pl.x_dir[2]);
    gp_Vec y(pl.y_dir[0], pl.y_dir[1], pl.y_dir[2]);
    return gp_Pnt(o.XYZ() + x.XYZ() * u + y.XYZ() * v);
}

gp_Pnt face_com(const TopoDS_Shape& face) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    return props.CentreOfMass();
}

std::array<double, 2> uv_of(const SketchPlane& pl, const gp_Pnt& p) {
    gp_Pnt o(pl.origin[0], pl.origin[1], pl.origin[2]);
    gp_Vec x(pl.x_dir[0], pl.x_dir[1], pl.x_dir[2]);
    gp_Vec y(pl.y_dir[0], pl.y_dir[1], pl.y_dir[2]);
    gp_Vec d(o, p);
    return {d.Dot(x), d.Dot(y)};
}

double param(const Sketch& sk, const SketchEntity& e, size_t i) {
    return sk.param(e.params[i]);
}

std::vector<TopoDS_Edge> sketch_edges(const Sketch& sk) {
    const auto n = sk.plane().normal();
    gp_Dir nd(n[0], n[1], n[2]);
    gp_Dir xd(sk.plane().x_dir[0], sk.plane().x_dir[1], sk.plane().x_dir[2]);
    std::vector<TopoDS_Edge> edges;
    auto at = [&](double u, double v) { return to3d(sk.plane(), u, v); };
    for (const auto& e : sk.entities()) {
        if (e.construction || e.type == SketchEntityType::Point) continue;
        if (e.type == SketchEntityType::Line) {
            gp_Pnt a = at(param(sk, e, 0), param(sk, e, 1));
            gp_Pnt b = at(param(sk, e, 2), param(sk, e, 3));
            if (a.Distance(b) < 1e-9) continue;
            edges.push_back(BRepBuilderAPI_MakeEdge(a, b).Edge());
        } else if (e.type == SketchEntityType::Circle) {
            gp_Circ circ(gp_Ax2(at(param(sk, e, 0), param(sk, e, 1)), nd, xd), param(sk, e, 2));
            edges.push_back(BRepBuilderAPI_MakeEdge(circ).Edge());
        } else if (e.type == SketchEntityType::Arc) {
            gp_Pnt a = at(param(sk, e, 5), param(sk, e, 6));
            gp_Pnt b = at(param(sk, e, 7), param(sk, e, 8));
            double sa = param(sk, e, 3), ea = param(sk, e, 4);
            double mid = (sa + ea) / 2.0;
            if (ea < sa) mid += kPi;
            gp_Pnt m = at(param(sk, e, 0) + param(sk, e, 2) * std::cos(mid),
                          param(sk, e, 1) + param(sk, e, 2) * std::sin(mid));
            GC_MakeArcOfCircle mk(a, m, b);
            if (mk.IsDone()) {
                Handle(Geom_TrimmedCurve) arc = mk.Value();
                edges.push_back(BRepBuilderAPI_MakeEdge(arc).Edge());
            }
        } else if (e.type == SketchEntityType::Spline) {
            TopoDS_Edge edge = sk.spline_edge(e.id);
            if (!edge.IsNull()) edges.push_back(edge);
        } else if (e.type == SketchEntityType::Ellipse) {
            auto axes = sk.ellipse_axes(e.id);
            if (!axes) continue;
            const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3],
                         ang = (*axes)[4];
            gp_Dir yd(sk.plane().y_dir[0], sk.plane().y_dir[1], sk.plane().y_dir[2]);
            gp_XYZ xell = xd.XYZ() * std::cos(ang) + yd.XYZ() * std::sin(ang);
            gp_Elips el(gp_Ax2(at(cx, cy), nd, gp_Dir(xell)), rx, ry);
            edges.push_back(BRepBuilderAPI_MakeEdge(el).Edge());
        } else if (e.type == SketchEntityType::EllipticalArc && e.params.size() >= 11) {
            auto axes = sk.ellipse_axes(e.id);
            if (!axes) continue;
            const double cx = (*axes)[0], cy = (*axes)[1], rx = (*axes)[2], ry = (*axes)[3],
                         ang = (*axes)[4];
            gp_Dir yd(sk.plane().y_dir[0], sk.plane().y_dir[1], sk.plane().y_dir[2]);
            gp_XYZ xell = xd.XYZ() * std::cos(ang) + yd.XYZ() * std::sin(ang);
            gp_Elips el(gp_Ax2(at(cx, cy), nd, gp_Dir(xell)), rx, ry);
            Handle(Geom_Ellipse) ge = new Geom_Ellipse(el);
            gp_Pnt a = at(param(sk, e, 7), param(sk, e, 8));
            gp_Pnt b = at(param(sk, e, 9), param(sk, e, 10));
            BRepBuilderAPI_MakeEdge mk(ge, a, b);
            if (mk.IsDone()) {
                edges.push_back(mk.Edge());
            } else {
                double sa = param(sk, e, 5), ea = param(sk, e, 6);
                if (ea < sa) ea += 2.0 * kPi;
                Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(ge, sa, ea);
                BRepBuilderAPI_MakeEdge mk2(tr);
                if (mk2.IsDone()) edges.push_back(mk2.Edge());
            }
        }
    }
    return edges;
}

void sort_faces(std::vector<TopoDS_Shape>& faces) {
    std::sort(faces.begin(), faces.end(), [](const TopoDS_Shape& a, const TopoDS_Shape& b) {
        double aa = shape::area(a), ba = shape::area(b);
        if (std::abs(aa - ba) > 1e-9) return aa > ba;
        gp_Pnt ca = face_com(a), cb = face_com(b);
        if (std::abs(ca.X() - cb.X()) > 1e-9) return ca.X() < cb.X();
        return ca.Y() < cb.Y();
    });
}

std::vector<TopoDS_Shape> split_host(const TopoDS_Shape& host, const std::vector<TopoDS_Edge>& edges,
                                     std::string* err) {
    if (host.IsNull() || host.ShapeType() != TopAbs_FACE) {
        if (err) *err = "host is not a face";
        return {};
    }
    if (edges.empty()) return {host};
    BRepAlgoAPI_Splitter splitter;
    sx::occt::ShapeList args, tools;
    args.Append(host);
    splitter.SetArguments(args);
    for (const auto& e : edges) tools.Append(e);
    splitter.SetTools(tools);
    splitter.SetFuzzyValue(1e-6);
    splitter.Build();
    if (!splitter.IsDone()) {
        if (err) *err = "host region split failed";
        return {};
    }
    std::vector<TopoDS_Shape> faces;
    for (TopExp_Explorer ex(splitter.Shape(), TopAbs_FACE); ex.More(); ex.Next()) {
        TopoDS_Face f = TopoDS::Face(ex.Current());
        if (shape::area(f) < 1e-8) continue;
        faces.push_back(f);
    }
    if (faces.empty()) {
        if (err) *err = "no host regions";
        return {};
    }
    sort_faces(faces);
    return faces;
}

bool uv_near(const std::array<double, 2>& a, const std::array<double, 2>& b) {
    return std::hypot(a[0] - b[0], a[1] - b[1]) <= 1e-9;
}

void append_uv(std::vector<std::array<double, 2>>& loop, const std::array<double, 2>& p) {
    if (!loop.empty() && uv_near(loop.back(), p)) return;
    loop.push_back(p);
}

void sample_wire(const TopoDS_Wire& wire, const TopoDS_Face& face, double deflection,
                 const SketchPlane& pl, std::vector<std::array<double, 2>>& loop) {
    auto take_edge = [&](const TopoDS_Edge& edge) {
        BRepAdaptor_Curve curve(edge);
        std::vector<gp_Pnt> pts;
        if (curve.GetType() == GeomAbs_Line) {
            pts.push_back(curve.Value(curve.FirstParameter()));
            pts.push_back(curve.Value(curve.LastParameter()));
        } else {
            try {
                GCPnts_QuasiUniformDeflection samp(curve, deflection);
                if (samp.IsDone()) {
                    for (int i = 1; i <= samp.NbPoints(); ++i) pts.push_back(samp.Value(i));
                }
            } catch (...) {
            }
            if (pts.size() < 2) {
                pts.clear();
                pts.push_back(curve.Value(curve.FirstParameter()));
                pts.push_back(curve.Value(curve.LastParameter()));
            }
        }
        if (edge.Orientation() == TopAbs_REVERSED) std::reverse(pts.begin(), pts.end());
        for (const auto& p : pts) append_uv(loop, uv_of(pl, p));
    };
    bool any = false;
    for (BRepTools_WireExplorer exp(wire, face); exp.More(); exp.Next()) {
        any = true;
        take_edge(TopoDS::Edge(exp.Current()));
    }
    if (!any) {
        for (TopExp_Explorer ex(wire, TopAbs_EDGE); ex.More(); ex.Next())
            take_edge(TopoDS::Edge(ex.Current()));
    }
    if (loop.size() >= 2 && uv_near(loop.front(), loop.back())) loop.pop_back();
}

}  // namespace

SketchRegions SketchRegions::arrange(const Sketch& sketch, const TopoDS_Shape& host_face) {
    SketchRegions out;
    if (!host_face.IsNull() && host_face.ShapeType() == TopAbs_FACE) {
        auto edges = sketch_edges(sketch);
        out.faces = split_host(host_face, edges, &out.error);
        return out;
    }
    out.faces = sketch.contour_faces(&out.error);
    return out;
}

int SketchRegions::containing_uv(const Sketch& sketch, double u, double v) const {
    gp_Pnt p = to3d(sketch.plane(), u, v);
    int best = -1;
    double best_area = 1e300;
    for (int i = 0; i < size(); ++i) {
        if (faces[static_cast<size_t>(i)].ShapeType() != TopAbs_FACE) continue;
        TopoDS_Face face = TopoDS::Face(faces[static_cast<size_t>(i)]);
        BRepClass_FaceClassifier cls(face, p, 1e-6);
        if (cls.State() != TopAbs_IN && cls.State() != TopAbs_ON) continue;
        double a = shape::area(face);
        if (a < best_area) {
            best_area = a;
            best = i;
        }
    }
    return best;
}

std::vector<Sketch::ContourOutline> SketchRegions::outlines(const Sketch& sketch,
                                                            double deflection) const {
    if (!(deflection > 0.0)) deflection = 0.05;
    std::vector<Sketch::ContourOutline> out;
    out.reserve(faces.size());
    for (const auto& shape : faces) {
        if (shape.ShapeType() != TopAbs_FACE) continue;
        const TopoDS_Face face = TopoDS::Face(shape);
        const TopoDS_Wire outer_wire = BRepTools::OuterWire(face);
        Sketch::ContourOutline region;
        region.area = shape::area(face);
        for (TopExp_Explorer wx(face, TopAbs_WIRE); wx.More(); wx.Next()) {
            const TopoDS_Wire wire = TopoDS::Wire(wx.Current());
            std::vector<std::array<double, 2>> loop;
            sample_wire(wire, face, deflection, sketch.plane(), loop);
            if (wire.IsSame(outer_wire)) region.outer = std::move(loop);
            else region.holes.push_back(std::move(loop));
        }
        if (!region.outer.empty()) {
            double minx = region.outer[0][0], miny = region.outer[0][1];
            double maxx = minx, maxy = miny;
            for (const auto& p : region.outer) {
                minx = std::min(minx, p[0]);
                miny = std::min(miny, p[1]);
                maxx = std::max(maxx, p[0]);
                maxy = std::max(maxy, p[1]);
            }
            region.min = {minx, miny};
            region.size = {maxx - minx, maxy - miny};
            region.center = {(minx + maxx) * 0.5, (miny + maxy) * 0.5};
        }
        out.push_back(std::move(region));
    }
    return out;
}

}  // namespace sx
