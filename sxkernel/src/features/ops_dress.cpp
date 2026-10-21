#include "ops.hpp"
#include "shell_open_half.hpp"
#include "topo_cue.h"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <Geom_Surface.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomLProp_SLProps.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include "sx/occt_types.hpp"
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <Bnd_Box.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <algorithm>
#include <cmath>
#include <limits>

#include "sx/shape_utils.hpp"
#include "sx/interop.hpp"
#include "sx/variables.hpp"
#include "sx/measure.hpp"
#include "sx/log.hpp"
#include "face_interior.hpp"

namespace sx::feature_ops {

namespace {

// A blend already sitting on this vertex ate part of the original wall.
// Add its radius back when it is smaller than the remaining edge, so a
// 2.5 mm slot with an R1 floor fillet still reports a 2.5 mm span (the
// straight remnant is 1.5). Profile cylinders larger than the edge, such
// as a slot end, are not blends of that edge.
double blend_radius_at(const TopoDS_Shape& body, const TopoDS_Vertex& vertex, double edge_len) {
    sx::occt::ShapeIndexedDataMapOfList ancestors;
    TopExp::MapShapesAndAncestors(body, TopAbs_VERTEX, TopAbs_FACE, ancestors);
    const int idx = ancestors.FindIndex(vertex);
    if (idx < 1) return 0.0;
    double extra = 0.0;
    const sx::occt::ShapeList& faces = ancestors.FindFromIndex(idx);
    for (const TopoDS_Shape& face_shape : faces) {
        if (face_shape.ShapeType() != TopAbs_FACE) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(face_shape));
        double r = 0.0;
        if (surf.GetType() == GeomAbs_Cylinder)
            r = surf.Cylinder().Radius();
        else if (surf.GetType() == GeomAbs_Torus)
            r = surf.Torus().MinorRadius();
        else if (surf.GetType() == GeomAbs_Sphere)
            r = surf.Sphere().Radius();
        if (r > 1e-6 && r <= edge_len + 1e-4) extra = std::max(extra, r);
    }
    return extra;
}

double linear_length(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.Mass();
}

// A corner blend is a circular arc of about a quarter turn. A slot-end
// semicircle (angle ~π) is the floor boundary, not a blend of the wall.
bool corner_blend_arc(const TopoDS_Edge& edge, double& radius) {
    BRepAdaptor_Curve curve(edge);
    const double angle = std::abs(curve.LastParameter() - curve.FirstParameter());
    // Quarter-turn only. A slot-end semicircle (parameter ~π) is the floor
    // boundary, not the wall the radius has to fit in.
    if (!(angle > 0.5 && angle < 2.2)) return false;
    if (curve.GetType() == GeomAbs_Circle) {
        radius = curve.Circle().Radius();
    } else if (curve.GetType() == GeomAbs_Ellipse) {
        // Rectangular-slot corners come back as a quarter ellipse whose minor
        // radius is the fillet that already ate the wall (major is the
        // corner diagonal, √2 r).
        radius = curve.Ellipse().MinorRadius();
    } else {
        return false;
    }
    return radius > 1e-6;
}

gp_Vec tangent_at_vertex(const TopoDS_Edge& edge, const TopoDS_Vertex& vertex) {
    BRepAdaptor_Curve curve(edge);
    const gp_Pnt vp = BRep_Tool::Pnt(vertex);
    double t = curve.FirstParameter();
    gp_Pnt p0;
    curve.D0(t, p0);
    if (p0.Distance(vp) > 1e-4) t = curve.LastParameter();
    gp_Pnt p;
    gp_Vec v;
    curve.D1(t, p, v);
    if (v.Magnitude() < 1e-12) return gp_Vec(0, 0, 0);
    v.Normalize();
    return v;
}

// Radius of a corner-blend arc leaving `vertex`, other than `skip`.
// Used when the straight remnant is shorter than the blend (R1 on both
// ends of a 2.5 mm wall leaves 0.5 mm), so blend_radius_at would drop it.
double corner_radius_at(const TopoDS_Shape& body, const TopoDS_Vertex& vertex,
                        const TopoDS_Edge& skip) {
    sx::occt::ShapeIndexedDataMapOfList ancestors;
    TopExp::MapShapesAndAncestors(body, TopAbs_VERTEX, TopAbs_EDGE, ancestors);
    const int idx = ancestors.FindIndex(vertex);
    if (idx < 1) return 0.0;
    double best = 0.0;
    const sx::occt::ShapeList& edges = ancestors.FindFromIndex(idx);
    for (const TopoDS_Shape& es : edges) {
        if (es.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge edge = TopoDS::Edge(es);
        if (edge.IsSame(skip) || BRep_Tool::Degenerated(edge)) continue;
        double radius = 0.0;
        if (!corner_blend_arc(edge, radius)) continue;
        best = std::max(best, radius);
    }
    return best;
}

double restored_blend_at(const TopoDS_Shape& body, const TopoDS_Vertex& vertex,
                         const TopoDS_Edge& edge, double edge_len);

// After a floor fillet the sharp wall edge is gone. The departure from the
// new floor boundary is the blend's quarter-circle; the original wall is
// that radius plus the straight remnant plus a blend on the far end.
double continuation_past_blend(const TopoDS_Shape& body, const TopoDS_Vertex& far,
                               const TopoDS_Edge& blend_arc, const gp_Vec& wall_dir) {
    if (wall_dir.SquareMagnitude() < 1e-12) return 0.0;
    sx::occt::ShapeIndexedDataMapOfList ancestors;
    TopExp::MapShapesAndAncestors(body, TopAbs_VERTEX, TopAbs_EDGE, ancestors);
    const int idx = ancestors.FindIndex(far);
    if (idx < 1) return 0.0;
    double best_align = 0.7;
    TopoDS_Edge chosen;
    bool found = false;
    const sx::occt::ShapeList& edges = ancestors.FindFromIndex(idx);
    for (const TopoDS_Shape& es : edges) {
        if (es.ShapeType() != TopAbs_EDGE) continue;
        const TopoDS_Edge edge = TopoDS::Edge(es);
        if (edge.IsSame(blend_arc) || BRep_Tool::Degenerated(edge)) continue;
        const gp_Vec t = tangent_at_vertex(edge, far);
        if (t.SquareMagnitude() < 1e-12) continue;
        const double align = std::abs(t.Dot(wall_dir));
        if (align > best_align) {
            best_align = align;
            chosen = edge;
            found = true;
        }
    }
    if (!found) return 0.0;
    double radius = 0.0;
    if (corner_blend_arc(chosen, radius)) return radius;
    const double len = linear_length(chosen);
    if (len <= 1e-6) return 0.0;
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(chosen, v1, v2);
    const gp_Pnt farp = BRep_Tool::Pnt(far);
    const TopoDS_Vertex other =
        BRep_Tool::Pnt(v1).Distance(farp) >= BRep_Tool::Pnt(v2).Distance(farp) ? v1 : v2;
    return len + restored_blend_at(body, other, chosen, len);
}

// Radius of a fillet face meeting `edge` at `vertex` when the straight
// remnant is shorter than the blend (R1 on both ends of a 2.5 mm wall
// leaves 0.5 mm). blend_radius_at drops that face because r > edge length,
// and the quarter-circle may not be the departure edge after a rebuild.
// A profile cylinder (slot end, axis along this edge) is not that blend.
double transverse_fillet_radius(const TopoDS_Shape& body, const TopoDS_Vertex& vertex,
                                const TopoDS_Edge& edge, double edge_len) {
    const gp_Vec along = tangent_at_vertex(edge, vertex);
    if (along.SquareMagnitude() < 1e-12) return 0.0;
    sx::occt::ShapeIndexedDataMapOfList ancestors;
    TopExp::MapShapesAndAncestors(body, TopAbs_VERTEX, TopAbs_FACE, ancestors);
    const int idx = ancestors.FindIndex(vertex);
    if (idx < 1) return 0.0;
    double best = 0.0;
    bool found = false;
    const sx::occt::ShapeList& faces = ancestors.FindFromIndex(idx);
    for (const TopoDS_Shape& face_shape : faces) {
        if (face_shape.ShapeType() != TopAbs_FACE) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(face_shape));
        double r = 0.0;
        gp_Vec axis(0, 0, 0);
        if (surf.GetType() == GeomAbs_Cylinder) {
            r = surf.Cylinder().Radius();
            axis = gp_Vec(surf.Cylinder().Axis().Direction());
        } else if (surf.GetType() == GeomAbs_Torus) {
            r = surf.Torus().MinorRadius();
            axis = gp_Vec(surf.Torus().Axis().Direction());
        } else if (surf.GetType() == GeomAbs_Sphere) {
            r = surf.Sphere().Radius();
        } else {
            continue;
        }
        if (r <= edge_len + 1e-4) continue;
        // Larger than a corner that could have left this remnant (an R5
        // slot end against a 0.5 mm wall). The R1 blend is about twice
        // the remnant; a profile radius is many times larger.
        if (r > edge_len * 4.0 + 1e-6) continue;
        if (axis.SquareMagnitude() > 1e-12 && std::abs(axis.Normalized().Dot(along)) > 0.95)
            continue;
        if (!found || r < best) {
            best = r;
            found = true;
        }
    }
    return found ? best : 0.0;
}

// Put back the blend that already ate this end of `edge`. The straight
// remnant between an R1 floor fillet and an R1 top fillet is 0.5 mm, so
// the radius lives on the fillet face rather than on a longer edge.
double restored_blend_at(const TopoDS_Shape& body, const TopoDS_Vertex& vertex,
                         const TopoDS_Edge& edge, double edge_len) {
    const double blended = blend_radius_at(body, vertex, edge_len);
    const double corner = corner_radius_at(body, vertex, edge);
    double transverse = 0.0;
    if (blended <= 1e-6 && corner <= 1e-6)
        transverse = transverse_fillet_radius(body, vertex, edge, edge_len);
    return std::max(blended, std::max(corner, transverse));
}

// Shortest edge that leaves `fillet_edge` across either adjacent face.
// Half of that span is the largest radius that still fits when the same
// wall is filleted from both ends (slot depth 2.5 → limit 1.25). A floor
// that already carries a fillet still reports the original wall: the
// blend arc counts as its radius, not its arc length.
double min_departure_length(const TopoDS_Shape& body, const TopoDS_Edge& fillet_edge) {
    sx::occt::ShapeIndexedDataMapOfList ancestors;
    TopExp::MapShapesAndAncestors(body, TopAbs_EDGE, TopAbs_FACE, ancestors);
    const int idx = ancestors.FindIndex(fillet_edge);
    if (idx < 1) return std::numeric_limits<double>::infinity();
    sx::occt::ShapeIndexedMap fillet_verts;
    TopExp::MapShapes(fillet_edge, TopAbs_VERTEX, fillet_verts);
    double best = std::numeric_limits<double>::infinity();
    const sx::occt::ShapeList& faces = ancestors.FindFromIndex(idx);
    for (const TopoDS_Shape& face_shape : faces) {
        for (TopExp_Explorer ex(face_shape, TopAbs_EDGE); ex.More(); ex.Next()) {
            const TopoDS_Edge edge = TopoDS::Edge(ex.Current());
            if (edge.IsSame(fillet_edge)) continue;
            sx::occt::ShapeIndexedMap verts;
            TopExp::MapShapes(edge, TopAbs_VERTEX, verts);
            bool shares = false;
            for (int i = 1; i <= verts.Extent(); ++i) {
                if (fillet_verts.Contains(verts(i))) {
                    shares = true;
                    break;
                }
            }
            if (!shares) continue;
            const double len = linear_length(edge);
            if (len <= 1e-6) continue;
            double span = len;
            // A 0.5 mm remnant between an R1 floor fillet and an R1 top fillet
            // is still the original 2.5 mm wall. blend_radius_at ignores a
            // blend larger than that remnant; restored_blend_at reads it off
            // the fillet face. After a thickness rebuild that remnant is the
            // departure, so the slot floor's 150 mm line must not report
            // limit 0.250.
            span += restored_blend_at(body, TopoDS::Vertex(verts(1)), edge, len);
            if (verts.Extent() > 1)
                span += restored_blend_at(body, TopoDS::Vertex(verts(verts.Extent())), edge, len);
            double blend_r = 0.0;
            if (corner_blend_arc(edge, blend_r)) {
                TopoDS_Vertex ev1, ev2;
                TopExp::Vertices(edge, ev1, ev2);
                const bool v1_on = fillet_verts.Contains(ev1);
                const TopoDS_Vertex far_v = v1_on && !fillet_verts.Contains(ev2) ? ev2 : ev1;
                const gp_Vec wall = tangent_at_vertex(edge, far_v);
                const double walked = blend_r + continuation_past_blend(body, far_v, edge, wall);
                // The arc-length sum double-counts a blend that already ate
                // the wall (quarter-circle ~1.57 plus its own radius). The
                // walked span is the original wall. Keep the shorter one
                // only when the walk actually left the blend.
                if (walked > blend_r + 1e-6) span = std::min(span, walked);
            }
            best = std::min(best, span);
        }
    }
    return best;
}

std::string edge_phrase(const TopoDS_Edge& edge) {
    BRepAdaptor_Curve curve(edge);
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    const char* kind = "curve";
    if (curve.GetType() == GeomAbs_Line) {
        kind = std::abs(curve.Line().Direction().Z()) >= 0.95 ? "vertical" : "line";
    } else if (curve.GetType() == GeomAbs_Circle) {
        kind = "arc";
    } else if (curve.GetType() == GeomAbs_Ellipse) {
        kind = "ellipse";
    } else if (curve.GetType() == GeomAbs_BSplineCurve || curve.GetType() == GeomAbs_BezierCurve) {
        kind = "spline";
    }
    gp_Pnt mid;
    curve.D0(0.5 * (curve.FirstParameter() + curve.LastParameter()), mid);
    return format_fixed(props.Mass(), 3) + " mm " + kind + " at (" + format_fixed(mid.X(), 3) +
           ", " + format_fixed(mid.Y(), 3) + ", " + format_fixed(mid.Z(), 3) + ")";
}

void note_faulty_contour(BRepFilletAPI_MakeFillet& mk, std::string* fault) {
    if (!fault) return;
    fault->clear();
    if (mk.NbFaultyContours() < 1) return;
    const int ic = mk.FaultyContour(1);
    if (ic < 1 || ic > mk.NbContours() || mk.NbEdges(ic) < 1) return;
    const TopoDS_Edge fe = mk.Edge(ic, 1);
    if (!fe.IsNull()) *fault = edge_phrase(fe);
}

// Cue-only resolve (no stable id). Absolute then relative live in resolve().
bool match_edge_cue(const Body& body, const nlohmann::json& cue, TopoDS_Shape& out) {
    if (!cue.is_object()) return false;
    ShapeIndex index;
    index.shape = body.shape;
    index.kind = EntityKind::Edge;
    index.body = &body;
    const Resolution found = resolve(cue_from_json(cue), index);
    if (!found.found) return false;
    out = found.shape;
    return true;
}

bool same_smooth_curve(const TopoDS_Edge& a, const TopoDS_Edge& b) {
    if (a.IsSame(b)) return true;
    BRepAdaptor_Curve ca(a);
    BRepAdaptor_Curve cb(b);
    if (ca.GetType() != cb.GetType()) return false;
    if (ca.GetType() == GeomAbs_Line) {
        const gp_Lin la = ca.Line();
        const gp_Lin lb = cb.Line();
        if (!la.Direction().IsParallel(lb.Direction(), 1e-4)) return false;
        return la.Distance(lb.Location()) < 1e-4;
    }
    if (ca.GetType() == GeomAbs_Circle) {
        const gp_Circ cia = ca.Circle();
        const gp_Circ cib = cb.Circle();
        if (std::abs(cia.Radius() - cib.Radius()) > 1e-4) return false;
        if (cia.Location().Distance(cib.Location()) > 1e-4) return false;
        return cia.Axis().Direction().IsParallel(cib.Axis().Direction(), 1e-4);
    }
    return false;
}

// Forward/reverse of a seam, or two halves of one circle, are one curve.
std::vector<TopoDS_Edge> drop_seam_duplicates(const std::vector<TopoDS_Edge>& edges) {
    std::vector<TopoDS_Edge> out;
    for (const auto& edge : edges) {
        if (BRep_Tool::Degenerated(edge)) continue;
        bool dup = false;
        for (const auto& kept : out) {
            if (same_smooth_curve(edge, kept)) {
                dup = true;
                break;
            }
        }
        if (!dup) out.push_back(edge);
    }
    return out;
}

std::vector<TopoDS_Edge> map_edges_onto(const TopoDS_Shape& shape,
                                        const std::vector<TopoDS_Edge>& picked) {
    sx::occt::ShapeIndexedMap edges;
    TopExp::MapShapes(shape, TopAbs_EDGE, edges);
    std::vector<TopoDS_Edge> chosen;
    std::vector<int> seen;
    for (const auto& src : picked) {
        BRepAdaptor_Curve curve(src);
        gp_Pnt mid;
        curve.D0(0.5 * (curve.FirstParameter() + curve.LastParameter()), mid);
        for (int i = 1; i <= edges.Extent(); ++i) {
            if (std::find(seen.begin(), seen.end(), i) != seen.end()) continue;
            const TopoDS_Edge edge = TopoDS::Edge(edges(i));
            if (BRep_Tool::Degenerated(edge)) continue;
            BRepExtrema_DistShapeShape dist(BRepBuilderAPI_MakeVertex(mid), edge);
            dist.Perform();
            if (!dist.IsDone() || dist.Value() > 0.05) continue;
            seen.push_back(i);
            chosen.push_back(edge);
            break;
        }
    }
    return drop_seam_duplicates(chosen);
}

// Add() already grows a G1 contour. A second Add of a tangent (or seam-split)
// partner duplicates that contour and MakeFillet fails even when the radius
// fits. Skip edges already claimed; drop IsSame / same-curve duplicates first.
bool build_fillet(const TopoDS_Shape& shape, const std::vector<TopoDS_Edge>& picked, double v,
                  double r2, TopoDS_Shape& out, std::string* fault) {
    const std::vector<TopoDS_Edge> edges = drop_seam_duplicates(picked);
    if (edges.empty()) return false;
    try {
        BRepFilletAPI_MakeFillet mk(shape);
        for (const auto& edge : edges) {
            if (mk.Contour(edge) != 0) continue;
            if (std::abs(r2 - v) > 1e-12)
                mk.Add(v, r2, edge);
            else
                mk.Add(v, edge);
        }
        mk.Build();
        if (!mk.IsDone()) {
            note_faulty_contour(mk, fault);
            return false;
        }
        const TopoDS_Shape result = mk.Shape();
        if (result.IsNull() || !shape::is_valid(result)) return false;
        out = result;
        return true;
    } catch (const Standard_Failure&) {
        return false;
    }
}

// A circle seam splits one smooth boundary into two edges. MakeFillet then
// rejects the whole face even though each piece is under the radius limit.
// Merge those same-domain edges and fillet one Add per unique curve.
gp_Vec face_xy_normal(const TopoDS_Face& face, const gp_Pnt& at) {
    Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
    if (surf.IsNull()) return {};
    GeomAPI_ProjectPointOnSurf proj(at, surf);
    if (!proj.IsDone() || proj.NbPoints() < 1) return {};
    double u = 0.0, vv = 0.0;
    proj.LowerDistanceParameters(u, vv);
    GeomLProp_SLProps props(surf, u, vv, 1, 1e-6);
    if (!props.IsNormalDefined()) return {};
    gp_Dir n = props.Normal();
    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
    gp_Vec xy(n.X(), n.Y(), 0.0);
    if (xy.SquareMagnitude() < 1e-12) return {};
    xy.Normalize();
    return xy;
}

// Intersection of two XY offset lines (X − q_i) · n_i = r.
bool offset_meet(const gp_Pnt& q1, const gp_Vec& n1, const gp_Pnt& q2, const gp_Vec& n2, double r,
                 double z, gp_Pnt& c) {
    const double det = n1.X() * n2.Y() - n1.Y() * n2.X();
    if (std::abs(det) < 1e-10) return false;
    const double b1 = r + q1.X() * n1.X() + q1.Y() * n1.Y();
    const double b2 = r + q2.X() * n2.X() + q2.Y() * n2.Y();
    c = gp_Pnt((b1 * n2.Y() - b2 * n1.Y()) / det, (n1.X() * b2 - n2.X() * b1) / det, z);
    return true;
}

TopoDS_Shape wedge_prism(const gp_Pnt& p, const gp_Pnt& t1, const gp_Pnt& mid, const gp_Pnt& t2,
                         double z0, double z1) {
    GC_MakeArcOfCircle mkarc(t1, mid, t2);
    if (!mkarc.IsDone()) return {};
    BRepBuilderAPI_MakeWire wire;
    wire.Add(BRepBuilderAPI_MakeEdge(p, t1).Edge());
    wire.Add(BRepBuilderAPI_MakeEdge(mkarc.Value()).Edge());
    wire.Add(BRepBuilderAPI_MakeEdge(t2, p).Edge());
    if (!wire.IsDone()) return {};
    BRepBuilderAPI_MakeFace face(wire.Wire(), true);
    if (!face.IsDone()) return {};
    gp_Trsf down;
    down.SetTranslation(gp_Vec(0, 0, z0 - p.Z()));
    TopoDS_Shape profile = BRepBuilderAPI_Transform(face.Face(), down, true).Shape();
    return BRepPrimAPI_MakePrism(profile, gp_Vec(0, 0, z1 - z0)).Shape();
}

// UnifySameDomain / Common can hand back a self-intersecting shell. Keep the
// last valid body so a neck R20 is not reported as a bare "result invalid".
TopoDS_Shape keep_valid(const TopoDS_Shape& candidate, const TopoDS_Shape& fallback) {
    if (candidate.IsNull()) return fallback;
    if (shape::is_valid(candidate)) return candidate;
    std::string report;
    TopoDS_Shape healed = interop::heal_shape(candidate, &report);
    if (!healed.IsNull() && shape::is_valid(healed)) return healed;
    return fallback;
}

// Neck R30/R20 on a 6 mm handle: MakeFillet first (Convert needs circular
// arcs), then void-wedge fuse, always clipped to the start AABB.
struct NeckFillet {
    static constexpr double XY_ALIGN_MM = 0.2;
    static constexpr double MIN_Z_LEN = 0.2;
    static constexpr double RADIUS_VS_THICK = 2.0;
    static constexpr double AABB_XZ_SLACK = 1.0;
    static constexpr double MIN_VOLUME = 0.5;
    static constexpr double VOID_ANGLE_MIN_RAD = 100.0 * M_PI / 180.0;
    static constexpr double UNIFY_LIN = 1e-6;
    static constexpr double UNIFY_ANG = 1e-4;

    static TopoDS_Shape aabb_of(const TopoDS_Shape& body, bool slack_y) {
        Bnd_Box box;
        BRepBndLib::Add(body, box);
        box.SetGap(0.0);
        double xmin = 0, ymin = 0, zmin = 0, xmax = 0, ymax = 0, zmax = 0;
        box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        if (xmax - xmin < 1e-6 || ymax - ymin < 1e-6 || zmax - zmin < 1e-6) return {};
        xmin -= AABB_XZ_SLACK;
        xmax += AABB_XZ_SLACK;
        zmin -= AABB_XZ_SLACK;
        zmax += AABB_XZ_SLACK;
        if (slack_y) {
            ymin -= AABB_XZ_SLACK;
            ymax += AABB_XZ_SLACK;
        }
        return BRepPrimAPI_MakeBox(gp_Pnt(xmin, ymin, zmin), gp_Pnt(xmax, ymax, zmax)).Shape();
    }

    static TopoDS_Shape common_with(const TopoDS_Shape& shape, const TopoDS_Shape& box) {
        if (shape.IsNull() || box.IsNull()) return {};
        BRepAlgoAPI_Common common(shape, box);
        common.Build();
        if (!common.IsDone()) return {};
        TopoDS_Shape clipped = common.Shape();
        if (clipped.IsNull() || shape::volume(clipped) < MIN_VOLUME) return {};
        return clipped;
    }

    static TopoDS_Shape clip_add(const TopoDS_Shape& body, const TopoDS_Shape& add) {
        // Empty (not the unclipped add) if Common fails — fusing the raw wedge
        // grows Y past the ellipse and blows the pass-bar box.
        return common_with(add, aabb_of(body, false));
    }

    static bool is_neck(const TopoDS_Edge& edge, double radius, gp_Pnt& a, gp_Pnt& b, double& z0,
                        double& z1) {
        if (radius <= 1e-6) return false;
        BRepAdaptor_Curve curve(edge);
        a = curve.Value(curve.FirstParameter());
        b = curve.Value(curve.LastParameter());
        if (std::abs(a.X() - b.X()) > XY_ALIGN_MM || std::abs(a.Y() - b.Y()) > XY_ALIGN_MM)
            return false;
        z0 = std::min(a.Z(), b.Z());
        z1 = std::max(a.Z(), b.Z());
        if (z1 - z0 < MIN_Z_LEN) return false;
        return radius > RADIUS_VS_THICK * (z1 - z0) + 1e-6;
    }

    static bool any(const std::vector<TopoDS_Edge>& edges, double radius) {
        gp_Pnt a, b;
        double z0 = 0, z1 = 0;
        for (const auto& edge : edges) {
            if (is_neck(edge, radius, a, b, z0, z1)) return true;
        }
        return false;
    }

    // Planar-vertical walls are one wedge path. Neck edges (R30 on 6 mm)
    // may have an elliptical extrusion as the other wall and still fuse.
    static bool walls_planar_vertical(const TopoDS_Shape& shape, const TopoDS_Edge& edge) {
        BRepAdaptor_Curve curve(edge);
        gp_Pnt a = curve.Value(curve.FirstParameter());
        gp_Pnt b = curve.Value(curve.LastParameter());
        gp_Vec along(a, b);
        if (along.SquareMagnitude() < 1e-12) return false;
        along.Normalize();
        sx::occt::ShapeIndexedDataMapOfList ancestors;
        TopExp::MapShapesAndAncestors(shape, TopAbs_EDGE, TopAbs_FACE, ancestors);
        const int idx = ancestors.FindIndex(edge);
        if (idx < 1) return false;
        int planar = 0;
        for (const TopoDS_Shape& fs : ancestors.FindFromIndex(idx)) {
            if (fs.ShapeType() != TopAbs_FACE) continue;
            BRepAdaptor_Surface surf(TopoDS::Face(fs));
            if (surf.GetType() != GeomAbs_Plane) return false;
            gp_Dir n = surf.Plane().Axis().Direction();
            if (std::abs(n.Dot(gp_Dir(along))) > 0.05) return false;
            ++planar;
        }
        return planar >= 2;
    }

    static bool any_planar_vertical(const TopoDS_Shape& shape,
                                    const std::vector<TopoDS_Edge>& edges) {
        for (const auto& e : edges) {
            if (walls_planar_vertical(shape, e)) return true;
        }
        return false;
    }

    static bool fuse_wedge(const TopoDS_Shape& shape, const TopoDS_Edge& edge, double radius,
                           TopoDS_Shape& out) {
        gp_Pnt a, b;
        double z0 = 0, z1 = 0;
        if (!is_neck(edge, radius, a, b, z0, z1)) return false;
        const gp_Pnt p((a.X() + b.X()) * 0.5, (a.Y() + b.Y()) * 0.5, (z0 + z1) * 0.5);

        sx::occt::ShapeIndexedDataMapOfList ancestors;
        TopExp::MapShapesAndAncestors(shape, TopAbs_EDGE, TopAbs_FACE, ancestors);
        const int idx = ancestors.FindIndex(edge);
        if (idx < 1) return false;
        const sx::occt::ShapeList& faces = ancestors.FindFromIndex(idx);
        std::vector<gp_Vec> normals;
        for (const TopoDS_Shape& fs : faces) {
            if (fs.ShapeType() != TopAbs_FACE) continue;
            gp_Vec n = face_xy_normal(TopoDS::Face(fs), p);
            if (n.SquareMagnitude() <= 0.5) continue;
            gp_Pnt probe(p.X() + n.X() * 0.3, p.Y() + n.Y() * 0.3, p.Z());
            BRepClass3d_SolidClassifier cl(shape, probe, 1e-4);
            if (cl.State() != TopAbs_OUT) n.Reverse();
            normals.push_back(n);
        }
        if (normals.size() < 2) return false;
        gp_Vec n1 = normals[0];
        gp_Vec n2 = normals[1];
        if (n1.Crossed(n2).SquareMagnitude() < 1e-8) return false;
        if (n1.X() * n2.Y() - n1.Y() * n2.X() < 0.0) std::swap(n1, n2);

        gp_Pnt c;
        if (!offset_meet(p, n1, p, n2, radius, p.Z(), c)) return false;
        gp_Vec bis = n1 + n2;
        if (bis.SquareMagnitude() < 1e-12) return false;
        bis.Normalize();
        const gp_Pnt t1(c.X() - n1.X() * radius, c.Y() - n1.Y() * radius, p.Z());
        const gp_Pnt t2(c.X() - n2.X() * radius, c.Y() - n2.Y() * radius, p.Z());
        const gp_Pnt mid(c.X() - bis.X() * radius, c.Y() - bis.Y() * radius, p.Z());
        BRepClass3d_SolidClassifier cl(shape, mid, 1e-4);
        if (cl.State() != TopAbs_OUT) return false;
        // Neck voids are 112° / 127°. A 90° box or slot corner must still refuse
        // (R50 applied, R1.5 slot floor).
        gp_Vec u1(t1.X() - p.X(), t1.Y() - p.Y(), 0.0);
        gp_Vec u2(t2.X() - p.X(), t2.Y() - p.Y(), 0.0);
        if (u1.SquareMagnitude() < 1e-12 || u2.SquareMagnitude() < 1e-12) return false;
        if (u1.Angle(u2) < VOID_ANGLE_MIN_RAD) return false;

        TopoDS_Shape add = wedge_prism(p, t1, mid, t2, z0, z1);
        if (add.IsNull()) return false;
        if (shape::volume(add) < 0.0) add.Reverse();
        add = clip_add(shape, add);
        if (add.IsNull() || shape::volume(add) < MIN_VOLUME) return false;
        BRepAlgoAPI_Fuse fuse(shape, add);
        fuse.Build();
        if (!fuse.IsDone()) return false;
        TopoDS_Shape fused = fuse.Shape();
        if (fused.IsNull()) return false;
        if (!shape::is_valid(fused)) {
            std::string report;
            TopoDS_Shape healed = interop::heal_shape(fused, &report);
            if (!healed.IsNull() && (shape::is_valid(healed) ||
                                    (shape::count(healed).solids >= 1 &&
                                     shape::volume(healed) > shape::volume(shape) + MIN_VOLUME)))
                fused = healed;
            else
                return false;
        }
        // Merge the wedge cap with the handle top so Convert sees R30/R20 arcs
        // as edges of that face (A28), not as a foreign coplanar cap.
        try {
            ShapeUpgrade_UnifySameDomain unif(fused, true, true, true);
            unif.SetLinearTolerance(UNIFY_LIN);
            unif.SetAngularTolerance(UNIFY_ANG);
            unif.Build();
            if (!unif.Shape().IsNull()) fused = keep_valid(unif.Shape(), fused);
        } catch (...) {
        }
        if (!shape::is_valid(fused)) return false;
        out = fused;
        return true;
    }

    static bool fuse_wedges(const TopoDS_Shape& shape, const std::vector<TopoDS_Edge>& edges,
                            double radius, TopoDS_Shape& out) {
        TopoDS_Shape acc = shape;
        bool any = false;
        for (const auto& edge : drop_seam_duplicates(edges)) {
            TopoDS_Shape next;
            if (!fuse_wedge(acc, edge, radius, next)) continue;
            acc = next;
            any = true;
        }
        if (!any) return false;
        out = acc;
        return true;
    }

    static TopoDS_Shape clip_result(const TopoDS_Shape& start, const TopoDS_Shape& result) {
        TopoDS_Shape clipped = common_with(result, aabb_of(start, false));
        if (clipped.IsNull()) return result;
        if (!shape::is_valid(clipped)) {
            std::string report;
            TopoDS_Shape healed = interop::heal_shape(clipped, &report);
            if (!healed.IsNull() && shape::volume(healed) > 1.0) clipped = healed;
            else
                return result;
        }
        try {
            ShapeUpgrade_UnifySameDomain unif(clipped, true, true, true);
            unif.SetLinearTolerance(UNIFY_LIN);
            unif.SetAngularTolerance(UNIFY_ANG);
            unif.Build();
            if (!unif.Shape().IsNull()) clipped = keep_valid(unif.Shape(), clipped);
        } catch (...) {
        }
        return keep_valid(clipped, result);
    }
};

bool fillet_unified(const TopoDS_Shape& shape, const std::vector<TopoDS_Edge>& picked, double v,
                    double r2, TopoDS_Shape& out, std::string* fault) {
    ShapeUpgrade_UnifySameDomain unif(shape, true, true, true);
    unif.SetLinearTolerance(1e-6);
    unif.SetAngularTolerance(1e-4);
    unif.Build();
    const TopoDS_Shape unified = unif.Shape();
    if (unified.IsNull()) return false;
    const std::vector<TopoDS_Edge> chosen = map_edges_onto(unified, picked);
    if (chosen.empty()) return false;
    return build_fillet(unified, chosen, v, r2, out, fault);
}

// A face pick fillets every edge of that face. Edge ids and cues move when an
// upstream edit (a thicker base extrude) moves the face, so the feature also
// remembers the face itself: its plane normal and one point inside it.
std::vector<TopoDS_Edge> face_edges(const TopoDS_Face& face) {
    sx::occt::ShapeIndexedMap map;
    TopExp::MapShapes(face, TopAbs_EDGE, map);
    std::vector<TopoDS_Edge> out;
    for (int i = 1; i <= map.Extent(); ++i) {
        const TopoDS_Edge edge = TopoDS::Edge(map(i));
        if (!BRep_Tool::Degenerated(edge)) out.push_back(edge);
    }
    return out;
}

bool contains_edge(const std::vector<TopoDS_Edge>& edges, const TopoDS_Edge& edge) {
    for (const auto& e : edges)
        if (e.IsSame(edge)) return true;
    return false;
}

nlohmann::json face_cues_for(const TopoDS_Shape& shape, const std::vector<TopoDS_Edge>& edges) {
    nlohmann::json cues = nlohmann::json::array();
    sx::occt::ShapeIndexedMap faces;
    TopExp::MapShapes(shape, TopAbs_FACE, faces);
    for (int i = 1; i <= faces.Extent(); ++i) {
        const TopoDS_Face face = TopoDS::Face(faces(i));
        gp_Dir n;
        if (!planar_face_normal(face, n)) continue;
        const std::vector<TopoDS_Edge> fe = face_edges(face);
        if (fe.size() < 3) continue;
        bool covered = true;
        for (const auto& e : fe) {
            if (!contains_edge(edges, e)) {
                covered = false;
                break;
            }
        }
        if (!covered) continue;
        gp_Pnt p;
        if (!sx::measure::face_interior_point(face, p)) continue;
        cues.push_back({{"point", {p.X(), p.Y(), p.Z()}}, {"normal", {n.X(), n.Y(), n.Z()}}});
    }
    return cues;
}

// The planar face with the cue's normal that still contains the cue point once
// the point slides along the normal onto the face's plane. When several faces
// qualify (a pocket floor under the top face), the one whose plane moved
// least wins.
bool match_face_cue(const TopoDS_Shape& shape, const nlohmann::json& cue, TopoDS_Face& out) {
    if (!cue.is_object()) return false;
    ShapeIndex index;
    index.shape = shape;
    index.kind = EntityKind::Face;
    const Resolution found = resolve(cue_from_json(cue), index);
    if (!found.found || found.shape.IsNull() || found.shape.ShapeType() != TopAbs_FACE) return false;
    out = TopoDS::Face(found.shape);
    return true;
}

bool resolve_dressup_edge(ApplyCtx& ctx, const Body& body, const nlohmann::json& je,
                          TopoDS_Shape& es, std::string* why) {
    TopoCue cue;
    if (je.is_string() && ctx.params.contains("edge_cues") && ctx.params["edge_cues"].is_object()) {
        const auto& cues = ctx.params["edge_cues"];
        const std::string key = je.get<std::string>();
        if (cues.contains(key)) cue = cue_from_json(cues[key]);
    }
    ShapeIndex index;
    index.shape = body.shape;
    index.kind = EntityKind::Edge;
    index.ref = je;
    index.doc = &ctx.doc;
    index.body = &body;
    const Resolution found = resolve(cue, index);
    if (!found.found) {
        if (why) *why = found.lost;
        return false;
    }
    es = found.shape;
    if (why) why->clear();
    return true;
}

struct DressupEdges {
    std::vector<TopoDS_Edge> edges;
    int total = 0;
    int lost = 0;
};

// Every edge the feature names that still resolves. Edges that do not are
// re-found through the face the feature was built from (face_cues). What
// stays unresolved after that is counted in `lost`.
DressupEdges resolve_dressup_edges(ApplyCtx& ctx, const Body& body, const char* soft_skip_tag) {
    DressupEdges out;
    for (const auto& je : ctx.params.at("edges")) {
        ++out.total;
        TopoDS_Shape es;
        std::string why;
        if (!resolve_dressup_edge(ctx, body, je, es, &why)) {
            sx::log::debug(std::string(soft_skip_tag) + why);
            continue;
        }
        const TopoDS_Edge edge = TopoDS::Edge(es);
        if (!contains_edge(out.edges, edge)) out.edges.push_back(edge);
    }
    if (static_cast<int>(out.edges.size()) < out.total) {
        const auto& cues = ctx.feature.params.value("face_cues", nlohmann::json::array());
        if (cues.is_array()) {
            for (const auto& cue : cues) {
                TopoDS_Face face;
                if (!match_face_cue(body.shape, cue, face)) continue;
                for (const auto& e : face_edges(face))
                    if (!contains_edge(out.edges, e)) out.edges.push_back(e);
            }
        }
    }
    out.lost = std::max(0, out.total - static_cast<int>(out.edges.size()));
    if (out.lost > 0) {
        // A lost edge is a documented, non-fatal degrade (the user-facing
        // warning is report_lost_edges). Log it as a warning, named.
        const std::string who = ctx.feature.name.empty() ? std::string("feature") : ctx.feature.name;
        sx::log::warn(who + ": " + std::string(soft_skip_tag) + std::to_string(out.lost) +
                      " edges lost on rebuild");
    }
    return out;
}

// Lost edges never fail the rebuild: unrelated edits (a later sketch, a hole)
// must not be rolled back. They are reported as a warning the status line and
// the timeline row show.
bool report_lost_edges(ApplyCtx& ctx, const DressupEdges& found) {
    if (found.total == 0 || found.lost == 0) return true;
    const std::string what =
        found.edges.empty()
            ? "all " + std::to_string(found.total) + " edges lost on rebuild — it changes nothing now"
            : std::to_string(found.lost) + " of " + std::to_string(found.total)
                  + " edges lost on rebuild";
    ctx.graph.add_warning(ctx.feature.id, ctx.feature.name + ": " + what);
    return true;
}

void remember_face_cues(ApplyCtx& ctx, const Body& body, const std::vector<TopoDS_Edge>& edges) {
    nlohmann::json cues = face_cues_for(body.shape, edges);
    if (cues.empty())
        ctx.feature.params.erase("face_cues");
    else
        ctx.feature.params["face_cues"] = std::move(cues);
}

}  // namespace

bool apply_fillet_chamfer(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    double v = num_param(ctx.params,
                         ctx.feature.type == FeatureType::Fillet ? "radius" : "distance", 1.0,
                         ctx.env);

    TopoDS_Shape result;
    if (ctx.feature.type == FeatureType::Fillet) {
        const double r2 = ctx.params.contains("radius2")
                              ? num_param(ctx.params, "radius2", v, ctx.env)
                              : v;
        double limit = std::numeric_limits<double>::infinity();
        TopoDS_Edge limit_edge;
        const DressupEdges found = resolve_dressup_edges(ctx, *tb, "fillet soft-skip: ");
        if (!report_lost_edges(ctx, found)) return false;
        std::vector<TopoDS_Edge> resolved = found.edges;
        for (const auto& edge : resolved) {
            const double this_limit = 0.5 * min_departure_length(tb->shape, edge);
            if (this_limit < limit) {
                limit = this_limit;
                limit_edge = edge;
            }
        }
        if (resolved.empty()) return true;
        const double asked = std::max(v, r2);
        auto limit_msg = [&]() {
            std::string extra;
            if (!limit_edge.IsNull()) extra = "; " + edge_phrase(limit_edge);
            return "fillet failed (limit " + format_fixed(limit, 3) + extra + ")";
        };
        // Keep the 0.5×departure refuse for slots / boxes. Neck R30 on a 6 mm
        // Z-edge is allowed to try MakeFillet and the void-angle fuse.
        if (limit < 1e290 && asked > limit + 1e-4 &&
            !NeckFillet::any(resolved, asked))
            return ctx.fail(limit_msg());
        std::string fault;
        const bool neck = NeckFillet::any(resolved, asked);
        // MakeFillet leaves circular arcs on the handle-top face, which A28
        // Convert needs (two lines + R30 + R20). The void-angle fuse is the
        // fallback when OCCT refuses R30 on 6 mm. Either path is clipped to
        // the start AABB so a T-point spike cannot grow Y past the ellipse.
        if (!build_fillet(tb->shape, resolved, v, r2, result, &fault)) {
            TopoDS_Shape recovered;
            std::string fault2;
            const bool planar_vert = NeckFillet::any_planar_vertical(tb->shape, resolved);
            // Neck R30/R20 sits on a 6 mm Z-edge whose other wall is the C
            // ellipse extrusion — not a plane. Void-angle fuse already
            // refuses 90° boxes and cylindrical hole rims (those edges are
            // not necks). Planar-vertical is sufficient, not required.
            if ((neck || planar_vert) &&
                NeckFillet::fuse_wedges(tb->shape, resolved, asked, recovered)) {
                result = recovered;
                ctx.graph.add_warning(ctx.feature.id, ctx.feature.name + ": fillet wedge");
            } else if (fillet_unified(tb->shape, resolved, v, r2, recovered, &fault2))
                result = recovered;
            else {
                if (!planar_vert && !neck)
                    ctx.graph.add_warning(ctx.feature.id,
                                          ctx.feature.name +
                                              ": fillet wedge refused: walls not planar and vertical");
                if (limit < 1e290 && asked > limit + 1e-4)
                    return ctx.fail(limit_msg());
                if (fault.empty()) fault = fault2;
                if (!fault.empty()) return ctx.fail("fillet failed (" + fault + ")");
                return ctx.fail("fillet failed");
            }
        }
        remember_face_cues(ctx, *tb, resolved);
        if (neck)
            result = NeckFillet::clip_result(tb->shape, result);
    } else {
        BRepFilletAPI_MakeChamfer mk(tb->shape);
        const DressupEdges found = resolve_dressup_edges(ctx, *tb, "chamfer soft-skip: ");
        if (!report_lost_edges(ctx, found)) return false;
        if (found.edges.empty()) return true;
        for (const auto& edge : found.edges) mk.Add(v, edge);
        mk.Build();
        if (!mk.IsDone()) {
            // OCCT refuses without a limit phrase (fillets have one). Name the
            // distance and the edge count so a refused chamfer is not a bare
            // "chamfer failed" at the end of a green suite log.
            return ctx.fail("chamfer failed (" + format_fixed(v, 3) + " on " +
                            std::to_string(found.edges.size()) + " edge(s))");
        }
        result = mk.Shape();
        remember_face_cues(ctx, *tb, found.edges);
    }
    if (!shape::is_valid(result)) {
        std::string report;
        TopoDS_Shape healed = interop::heal_shape(result, &report);
        if (!healed.IsNull() && shape::is_valid(healed))
            result = healed;
        else
            return ctx.fail("result invalid");
    }
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_shell(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    sx::occt::ShapeList remove_faces;
    nlohmann::json stored_cues = ctx.feature.params.value("face_cues", nlohmann::json::object());
    if (!stored_cues.is_object()) stored_cues = nlohmann::json::object();
    bool cues_changed = false;
    for (const auto& jf : ctx.params.at("faces")) {
        TopoCue cue;
        if (jf.is_string() && stored_cues.contains(jf.get<std::string>()))
            cue = cue_from_json(stored_cues[jf.get<std::string>()]);
        ShapeIndex index;
        index.shape = tb->shape;
        index.kind = EntityKind::Face;
        index.ref = jf;
        index.doc = &ctx.doc;
        index.body = tb;
        const Resolution found = resolve(cue, index);
        if (!found.found) return ctx.fail(found.lost);
        remove_faces.Append(found.shape);
        if (!jf.is_string() || found.shape.ShapeType() != TopAbs_FACE) continue;
        const TopoCue fresh = cue_from_face(TopoDS::Face(found.shape), tb->shape);
        const std::string key = jf.get<std::string>();
        if (refresh_cue(stored_cues, key, fresh, EntityKind::Face)) cues_changed = true;
    }
    if (cues_changed) ctx.feature.params["face_cues"] = std::move(stored_cues);
    if (remove_faces.IsEmpty()) return ctx.fail("no faces to remove");
    double thickness = num_param(ctx.params, "thickness", 1.0, ctx.env);
    TopoDS_Shape result;
    std::string why;
    if (!shell_keeping_open_walls(tb->shape, remove_faces, thickness, result, &why))
        return ctx.fail(why.empty() ? "shell failed" : why);
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("shell result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_offset(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    double offset = num_param(ctx.params, "offset", 0.0, ctx.env);
    BRepOffsetAPI_MakeOffsetShape mk;
    mk.PerformByJoin(tb->shape, offset, 1e-3);
    if (!mk.IsDone()) return ctx.fail("offset failed");
    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("offset result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_push_pull(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    if (!ctx.params.contains("face")) return ctx.fail("missing face");
    TopoDS_Shape face_shape;
    std::string why;
    if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Face, ctx.params.at("face"), face_shape,
                            &why)) {
        // UUID may not survive a move+regen; fall back to stored plane cue.
        if (!ctx.params.contains("face_point") || !ctx.params.contains("face_normal"))
            return ctx.fail(why);
        gp_Pnt want = pnt_from(ctx.params.at("face_point"));
        gp_Dir want_n = dir_from(ctx.params.at("face_normal"));
        double best = 1e300;
        TopoDS_Shape best_face;
        for (const auto& fid : tb->subshape_ids.at(EntityKind::Face)) {
            TopoDS_Shape fs = ctx.doc.resolve(fid);
            if (fs.IsNull() || fs.ShapeType() != TopAbs_FACE) continue;
            TopoDS_Face f = TopoDS::Face(fs);
            BRepAdaptor_Surface surf(f);
            if (surf.GetType() != GeomAbs_Plane) continue;
            gp_Dir n = surf.Plane().Axis().Direction();
            if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
            if (n.Dot(want_n) < 0.95) continue;
            gp_Pnt c = surf.Plane().Location();
            // Prefer the face whose plane is closest to the stored pick point.
            double dist = std::abs(gp_Vec(c, want).Dot(n));
            // Also prefer proximity of the UV midpoint when available.
            auto mid = measure::face_midpoint(ctx.doc, fid);
            if (mid) {
                gp_Pnt m((*mid)[0], (*mid)[1], (*mid)[2]);
                dist += want.Distance(m) * 0.01;
            }
            if (dist < best) {
                best = dist;
                best_face = fs;
            }
        }
        if (best_face.IsNull()) return ctx.fail(why);
        face_shape = best_face;
    }
    TopoDS_Face face = TopoDS::Face(face_shape);
    BRepAdaptor_Surface surf(face);
    if (surf.GetType() != GeomAbs_Plane)
        return ctx.fail("only planar faces supported");
    gp_Dir normal = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) normal.Reverse();
    double distance = num_param(ctx.params, "distance", 0.0, ctx.env);
    const double dist = std::abs(distance);
    TopoDS_Shape tool;
    TopoDS_Shape result;
    if (distance >= 0) {
        gp_Vec sweep(normal.XYZ() * dist);
        tool = BRepPrimAPI_MakePrism(face, sweep).Shape();
        result = BRepAlgoAPI_Fuse(tb->shape, tool).Shape();
    } else {
        gp_Vec inward(normal.Reversed().XYZ() * dist);
        tool = BRepPrimAPI_MakePrism(face, inward).Shape();
        result = BRepAlgoAPI_Cut(tb->shape, tool).Shape();
    }
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("push/pull boolean failed");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_draft(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    if (!ctx.params.contains("faces") || !ctx.params["faces"].is_array() ||
        ctx.params["faces"].empty())
        return ctx.fail("no faces to draft");
    double angle_deg = num_param(ctx.params, "angle_deg", 0.0, ctx.env);
    double angle = angle_deg * M_PI / 180.0;
    gp_Dir pull = dir_from(ctx.params.at("pull_dir"));
    gp_Pln neutral(pnt_from(ctx.params.at("neutral_point")),
                   dir_from(ctx.params.at("neutral_normal")));
    BRepOffsetAPI_DraftAngle mk(tb->shape);
    for (const auto& jf : ctx.params.at("faces")) {
        TopoDS_Shape fs;
        std::string why;
        if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Face, jf, fs, &why))
            return ctx.fail(why);
        mk.Add(TopoDS::Face(fs), pull, angle, neutral);
        if (!mk.AddDone()) return ctx.fail("draft add failed");
    }
    mk.Build();
    if (!mk.IsDone()) return ctx.fail("draft failed");
    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        return ctx.fail("draft result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

}  // namespace sx::feature_ops
