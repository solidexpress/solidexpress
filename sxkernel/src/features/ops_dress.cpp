#include "ops.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <ElSLib.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include "sx/occt_types.hpp"
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec.hxx>

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <limits>
#include <sstream>

#include "sx/shape_utils.hpp"
#include "sx/variables.hpp"
#include "sx/measure.hpp"
#include "sx/log.hpp"

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
    return len + std::max(blend_radius_at(body, other, len), corner_radius_at(body, other, chosen));
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
            span += blend_radius_at(body, TopoDS::Vertex(verts(1)), len);
            if (verts.Extent() > 1)
                span += blend_radius_at(body, TopoDS::Vertex(verts(verts.Extent())), len);
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

std::string format_mm(double v) {
    const double shown = std::round(v * 1000.0) / 1000.0;
    std::ostringstream os;
    os.setf(std::ios::fixed);
    os << std::setprecision(3) << shown;
    return os.str();
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
    return format_mm(props.Mass()) + " mm " + kind + " at (" + format_mm(mid.X()) + ", "
           + format_mm(mid.Y()) + ", " + format_mm(mid.Z()) + ")";
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

// Rebuilds mint new ids for edges that an upstream feature recreates. Match
// the cue captured before regen (midpoint + direction) back onto the body.
bool match_edge_cue(const Body& body, const nlohmann::json& cue, TopoDS_Shape& out) {
    if (!cue.is_object() || !cue.contains("point") || !cue.contains("dir")) return false;
    const auto& pj = cue["point"];
    const auto& dj = cue["dir"];
    if (!pj.is_array() || pj.size() < 3 || !dj.is_array() || dj.size() < 3) return false;
    const gp_Pnt want(pj[0].get<double>(), pj[1].get<double>(), pj[2].get<double>());
    gp_Vec want_dir(dj[0].get<double>(), dj[1].get<double>(), dj[2].get<double>());
    if (want_dir.Magnitude() < 1e-12) return false;
    want_dir.Normalize();
    sx::occt::ShapeIndexedMap map;
    TopExp::MapShapes(body.shape, TopAbs_EDGE, map);
    double best = 1e300;
    bool found = false;
    for (int i = 1; i <= map.Extent(); ++i) {
        const TopoDS_Edge edge = TopoDS::Edge(map(i));
        BRepAdaptor_Curve curve(edge);
        gp_Pnt p;
        gp_Vec v;
        curve.D1(0.5 * (curve.FirstParameter() + curve.LastParameter()), p, v);
        if (v.Magnitude() < 1e-12) continue;
        v.Normalize();
        const double dist = p.Distance(want);
        const double align = std::abs(v.Dot(want_dir));
        if (dist < 0.5 && align > 0.95 && dist < best) {
            best = dist;
            out = edge;
            found = true;
        }
    }
    return found;
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

bool planar_face_normal(const TopoDS_Face& face, gp_Dir& n) {
    BRepAdaptor_Surface surf(face);
    if (surf.GetType() != GeomAbs_Plane) return false;
    n = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
    return true;
}

// The grid sample inside the face that sits nearest the middle of its UV box.
bool face_interior_point(const TopoDS_Face& face, gp_Pnt& out) {
    double u0, u1, v0, v1;
    BRepTools::UVBounds(face, u0, u1, v0, v1);
    BRepAdaptor_Surface surf(face);
    const int n = 16;
    double best = 1e300;
    bool found = false;
    for (int i = 1; i < n; ++i) {
        for (int j = 1; j < n; ++j) {
            const double fu = static_cast<double>(i) / n;
            const double fv = static_cast<double>(j) / n;
            const double u = u0 + (u1 - u0) * fu;
            const double v = v0 + (v1 - v0) * fv;
            BRepClass_FaceClassifier cl(face, gp_Pnt2d(u, v), 1e-7);
            if (cl.State() != TopAbs_IN) continue;
            const double d = (fu - 0.5) * (fu - 0.5) + (fv - 0.5) * (fv - 0.5);
            if (d < best) {
                best = d;
                out = surf.Value(u, v);
                found = true;
            }
        }
    }
    return found;
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
        if (!face_interior_point(face, p)) continue;
        cues.push_back({{"point", {p.X(), p.Y(), p.Z()}}, {"normal", {n.X(), n.Y(), n.Z()}}});
    }
    return cues;
}

// The planar face with the cue's normal that still contains the cue point once
// the point slides along the normal onto the face's plane. When several faces
// qualify (a pocket floor under the top face), the one whose plane moved
// least wins.
bool match_face_cue(const TopoDS_Shape& shape, const nlohmann::json& cue, TopoDS_Face& out) {
    if (!cue.is_object() || !cue.contains("point") || !cue.contains("normal")) return false;
    const auto& pj = cue["point"];
    const auto& nj = cue["normal"];
    if (!pj.is_array() || pj.size() < 3 || !nj.is_array() || nj.size() < 3) return false;
    const gp_Pnt want(pj[0].get<double>(), pj[1].get<double>(), pj[2].get<double>());
    gp_Vec want_n(nj[0].get<double>(), nj[1].get<double>(), nj[2].get<double>());
    if (want_n.Magnitude() < 1e-12) return false;
    want_n.Normalize();
    sx::occt::ShapeIndexedMap faces;
    TopExp::MapShapes(shape, TopAbs_FACE, faces);
    double best = 1e300;
    bool found = false;
    for (int i = 1; i <= faces.Extent(); ++i) {
        const TopoDS_Face face = TopoDS::Face(faces(i));
        gp_Dir n;
        if (!planar_face_normal(face, n)) continue;
        if (gp_Vec(n).Dot(want_n) < 0.999) continue;
        BRepAdaptor_Surface surf(face);
        const gp_Pln pln = surf.Plane();
        const double shift = gp_Vec(want, pln.Location()).Dot(want_n);
        const gp_Pnt on_plane = want.Translated(want_n * shift);
        double u, v;
        ElSLib::PlaneParameters(pln.Position(), on_plane, u, v);
        BRepClass_FaceClassifier cl(face, gp_Pnt2d(u, v), 1e-4);
        if (cl.State() != TopAbs_IN && cl.State() != TopAbs_ON) continue;
        if (std::abs(shift) < best) {
            best = std::abs(shift);
            out = face;
            found = true;
        }
    }
    return found;
}

bool resolve_dressup_edge(ApplyCtx& ctx, const Body& body, const nlohmann::json& je,
                          TopoDS_Shape& es, std::string* why) {
    if (resolve_topo_shape(ctx.doc, body, EntityKind::Edge, je, es, why)) return true;
    if (!je.is_string() || !ctx.params.contains("edge_cues")) return false;
    const auto& cues = ctx.params["edge_cues"];
    const std::string key = je.get<std::string>();
    if (!cues.is_object() || !cues.contains(key)) return false;
    if (!match_edge_cue(body, cues[key], es)) return false;
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
            sx::log::error(std::string(soft_skip_tag) + why);
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
        // "fillet failed (limit …)" is only for a radius that does not fit.
        if (limit < 1e290 && asked > limit + 1e-4) {
            std::string extra;
            if (!limit_edge.IsNull()) extra = "; " + edge_phrase(limit_edge);
            return ctx.fail("fillet failed (limit " + format_mm(limit) + extra + ")");
        }
        std::string fault;
        if (!build_fillet(tb->shape, resolved, v, r2, result, &fault)) {
            TopoDS_Shape recovered;
            std::string fault2;
            if (fillet_unified(tb->shape, resolved, v, r2, recovered, &fault2))
                result = recovered;
            else {
                if (fault.empty()) fault = fault2;
                if (!fault.empty()) return ctx.fail("fillet failed (" + fault + ")");
                return ctx.fail("fillet failed");
            }
        }
        remember_face_cues(ctx, *tb, resolved);
    } else {
        BRepFilletAPI_MakeChamfer mk(tb->shape);
        const DressupEdges found = resolve_dressup_edges(ctx, *tb, "chamfer soft-skip: ");
        if (!report_lost_edges(ctx, found)) return false;
        if (found.edges.empty()) return true;
        for (const auto& edge : found.edges) mk.Add(v, edge);
        mk.Build();
        if (!mk.IsDone()) return ctx.fail("chamfer failed");
        result = mk.Shape();
        remember_face_cues(ctx, *tb, found.edges);
    }
    if (!shape::is_valid(result)) return ctx.fail("result invalid");
    ctx.doc.replace_body_shape(target, result);
    return true;
}

bool apply_shell(ApplyCtx& ctx) {
    if (ctx.target_inactive("target")) return true;
    EntityId target = ctx.find_feature_body("target");
    const Body* tb = ctx.doc.body(target);
    if (!tb) return ctx.fail("missing target body");
    sx::occt::ShapeList remove_faces;
    for (const auto& jf : ctx.params.at("faces")) {
        TopoDS_Shape fs;
        std::string why;
        if (!resolve_topo_shape(ctx.doc, *tb, EntityKind::Face, jf, fs, &why))
            return ctx.fail(why);
        remove_faces.Append(fs);
    }
    if (remove_faces.IsEmpty()) return ctx.fail("no faces to remove");
    double thickness = num_param(ctx.params, "thickness", 1.0, ctx.env);
    BRepOffsetAPI_MakeThickSolid mk;
    mk.MakeThickSolidByJoin(tb->shape, remove_faces, -thickness, 1e-3);
    if (!mk.IsDone()) return ctx.fail("shell failed");
    TopoDS_Shape result = mk.Shape();
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
