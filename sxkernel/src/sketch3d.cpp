#include "sx/sketch3d.hpp"

#include <cmath>

#include <BRepAdaptor_Curve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
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
