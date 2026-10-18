#include "sx/sketch3d.hpp"

#include <cmath>
#include <unordered_map>

#include <BRepAdaptor_Curve.hxx>
#include <GeomAPI_IntCS.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAbs_CurveType.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Plane.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/sketch.hpp"

namespace sx {

void to_json(nlohmann::json& j, const Sketch3D& s) {
    j = nlohmann::json{{"id", s.id.str()},
                       {"name", s.name},
                       {"points", s.points},
                       {"segments", nlohmann::json::array()}};
    for (const auto& seg : s.segments) j["segments"].push_back({seg.first, seg.second});
}

void from_json(const nlohmann::json& j, Sketch3D& s) {
    if (j.contains("id")) s.id = EntityId::from_string(j.at("id").get<std::string>());
    s.name = j.value("name", "3D Sketch");
    if (j.contains("points")) s.points = j.at("points").get<std::vector<std::array<double, 3>>>();
    s.segments.clear();
    if (j.contains("segments")) {
        for (const auto& seg : j.at("segments")) {
            if (seg.is_array() && seg.size() >= 2)
                s.segments.emplace_back(seg[0].get<int>(), seg[1].get<int>());
        }
    }
}

std::vector<std::array<double, 3>> sketch3d_path(const Sketch3D& s) {
    if (!s.segments.empty()) {
        std::vector<std::array<double, 3>> out;
        for (const auto& seg : s.segments) {
            if (seg.first >= 0 && static_cast<size_t>(seg.first) < s.points.size())
                out.push_back(s.points[static_cast<size_t>(seg.first)]);
            if (seg.second >= 0 && static_cast<size_t>(seg.second) < s.points.size())
                out.push_back(s.points[static_cast<size_t>(seg.second)]);
        }
        return out;
    }
    return s.points;
}

namespace {

bool pierce_edge(const Document& doc, const EntityId& edge_id, const SketchPlane& plane,
                 double* u, double* v) {
    TopoDS_Shape sh = doc.resolve(edge_id);
    if (sh.IsNull() || sh.ShapeType() != TopAbs_EDGE) return false;
    try {
        BRepAdaptor_Curve c(TopoDS::Edge(sh));
        const gp_Pnt a = c.Value(c.FirstParameter());
        const gp_Pnt b = c.Value(c.LastParameter());
        const gp_Pnt mid = c.Value(0.5 * (c.FirstParameter() + c.LastParameter()));
        gp_Pnt pick = mid;
        const gp_Pnt o(plane.origin[0], plane.origin[1], plane.origin[2]);
        const gp_Dir n(plane.normal()[0], plane.normal()[1], plane.normal()[2]);
        Handle(Geom_Plane) pl = new Geom_Plane(o, n);
        double best = 1e9;
        for (const gp_Pnt& p : {a, b, mid}) {
            GeomAPI_ProjectPointOnSurf proj(p, pl);
            if (!proj.IsDone() || proj.NbPoints() < 1) continue;
            const double d = proj.LowerDistance();
            if (d < best) {
                best = d;
                pick = proj.NearestPoint();
            }
        }
        const auto nrm = plane.normal();
        const auto x = plane.x_dir;
        std::array<double, 3> y{nrm[1] * x[2] - nrm[2] * x[1], nrm[2] * x[0] - nrm[0] * x[2],
                                nrm[0] * x[1] - nrm[1] * x[0]};
        const double dx = pick.X() - plane.origin[0];
        const double dy = pick.Y() - plane.origin[1];
        const double dz = pick.Z() - plane.origin[2];
        *u = dx * x[0] + dy * x[1] + dz * x[2];
        *v = dx * y[0] + dy * y[1] + dz * y[2];
        return true;
    } catch (...) {
        return false;
    }
}

}  // namespace

namespace {

constexpr double kTwoPi = 6.283185307179586;

// A full circle projects when the curve itself lies in the sketch plane.
// The circle axis is not that test: a rim whose 3D points sit on the face
// can still report an axis that is not the plane normal.
double plane_gap(const SketchPlane& plane, const gp_Pnt& p) {
    const auto n = plane.normal();
    const double nlen = std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    if (nlen < 1e-12) return 1e9;
    const double dx = p.X() - plane.origin[0];
    const double dy = p.Y() - plane.origin[1];
    const double dz = p.Z() - plane.origin[2];
    return std::abs((dx * n[0] + dy * n[1] + dz * n[2]) / nlen);
}

bool circle_lies_in_plane(const BRepAdaptor_Curve& curve, const SketchPlane& plane) {
    if (plane_gap(plane, curve.Circle().Location()) > 0.05) return false;
    const double t0 = curve.FirstParameter();
    const double t1 = curve.LastParameter();
    for (int i = 0; i < 3; ++i) {
        const double t = t0 + (t1 - t0) * ((i + 0.5) / 3.0);
        if (plane_gap(plane, curve.Value(t)) > 0.05) return false;
    }
    return true;
}

EntityId project_line(Sketch* sketch, const BRepAdaptor_Curve& curve, const std::string& edge) {
    const gp_Pnt a = curve.Value(curve.FirstParameter());
    const gp_Pnt b = curve.Value(curve.LastParameter());
    if (a.Distance(b) < 1e-9) return {};
    const EntityId added =
        sketch->project_line_edge({a.X(), a.Y(), a.Z()}, {b.X(), b.Y(), b.Z()}, edge);
    if (added.is_null()) return {};
    sketch->set_construction(added, true);
    return added;
}

EntityId project_circle(Sketch* sketch, const BRepAdaptor_Curve& curve, const SketchPlane& plane,
                        const std::string& edge) {
    if (curve.GetType() != GeomAbs_Circle) return {};
    const double span = std::abs(curve.LastParameter() - curve.FirstParameter());
    if (span < kTwoPi - 0.05) return {};
    const gp_Circ circ = curve.Circle();
    if (circle_lies_in_plane(curve, plane)) {
        const gp_Pnt c = circ.Location();
        const EntityId added =
            sketch->project_circle_edge({c.X(), c.Y(), c.Z()}, circ.Radius(), edge);
        if (added.is_null()) return {};
        sketch->set_construction(added, true);
        return added;
    }
    // Origin-plane silhouette: circle ∩ sketch plane → a diameter line.
    const auto nrm = plane.normal();
    gp_Pnt o(plane.origin[0], plane.origin[1], plane.origin[2]);
    gp_Dir n(nrm[0], nrm[1], nrm[2]);
    Handle(Geom_Circle) gc = new Geom_Circle(circ);
    Handle(Geom_Plane) gpl = new Geom_Plane(o, n);
    GeomAPI_IntCS inter(gc, gpl);
    if (!inter.IsDone() || inter.NbPoints() < 2) return {};
    const gp_Pnt a = inter.Point(1);
    const gp_Pnt b = inter.Point(2);
    if (a.Distance(b) < 1e-6) return {};
    const EntityId added =
        sketch->project_line_edge({a.X(), a.Y(), a.Z()}, {b.X(), b.Y(), b.Z()}, edge);
    if (added.is_null()) return {};
    sketch->set_construction(added, true);
    return added;
}

using ExternalProjector = EntityId (*)(Sketch*, const BRepAdaptor_Curve&, const SketchPlane&,
                                       const std::string&);

EntityId dispatch_line(Sketch* sketch, const BRepAdaptor_Curve& curve, const SketchPlane& plane,
                       const std::string& edge) {
    return project_line(sketch, curve, edge);
}

EntityId dispatch_circle(Sketch* sketch, const BRepAdaptor_Curve& curve, const SketchPlane& plane,
                         const std::string& edge) {
    return project_circle(sketch, curve, plane, edge);
}

const std::unordered_map<GeomAbs_CurveType, ExternalProjector> kProjectors = {
    {GeomAbs_Line, dispatch_line},
    {GeomAbs_Circle, dispatch_circle},
};

}  // namespace

EntityId add_external_edge(Document& doc, const EntityId& sketch_fid, const EntityId& edge_id) {
    Feature* f = doc.graph().feature(sketch_fid);
    if (f == nullptr || !f->sketch) return {};
    const std::string edge = edge_id.str();
    for (const auto& e : f->sketch->entities()) {
        if (e.external && e.projected_from == edge) return e.id;
    }
    const TopoDS_Shape sh = doc.resolve(edge_id);
    if (sh.IsNull() || sh.ShapeType() != TopAbs_EDGE) return {};
    const BRepAdaptor_Curve curve(TopoDS::Edge(sh));
    const auto it = kProjectors.find(curve.GetType());
    if (it == kProjectors.end()) return {};
    return it->second(f->sketch.get(), curve, f->sketch->plane(), edge);
}

int convert_edges_to_sketch(Document& doc, const EntityId& sketch_fid,
                            const std::vector<EntityId>& edge_ids, std::string* err) {
    Feature* f = doc.graph().feature(sketch_fid);
    if (!f || !f->sketch) {
        if (err) *err = "convert needs a sketch feature";
        return 0;
    }
    nlohmann::json ids = nlohmann::json::array();
    int n = 0;
    for (const auto& e : edge_ids) {
        double u = 0, v = 0;
        if (!pierce_edge(doc, e, f->sketch->plane(), &u, &v)) continue;
        f->sketch->add_point(u, v);
        ids.push_back(e.str());
        ++n;
    }
    f->params["converted_edges"] = ids;
    doc.bump_revision();
    return n;
}

int rebuild_converted_points(Document& doc, const EntityId& sketch_fid) {
    Feature* f = doc.graph().feature(sketch_fid);
    if (!f || !f->sketch || !f->params.contains("converted_edges")) return 0;
    int n = 0;
    for (const auto& s : f->params["converted_edges"]) {
        EntityId e;
        try {
            e = EntityId::from_string(s.get<std::string>());
        } catch (...) {
            continue;
        }
        double u = 0, v = 0;
        if (!pierce_edge(doc, e, f->sketch->plane(), &u, &v)) continue;
        f->sketch->add_point(u, v);
        ++n;
    }
    return n;
}

}  // namespace sx
