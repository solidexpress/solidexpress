#include "ops.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRep_Tool.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp.hxx>
#include "sx/occt_types.hpp"

#include <cmath>
#include <sstream>
#include <stdexcept>

namespace sx::feature_ops {

std::vector<int> selected_contour_indices(const nlohmann::json& params) {
    std::vector<int> out;
    if (!params.contains("selected_contours") || !params["selected_contours"].is_array())
        return out;
    for (const auto& v : params["selected_contours"]) {
        if (v.is_number_integer()) {
            out.push_back(v.get<int>());
        } else if (v.is_number_float()) {
            const double d = v.get<double>();
            const int idx = static_cast<int>(std::lround(d));
            if (std::abs(d - static_cast<double>(idx)) <= 1e-9) out.push_back(idx);
        }
    }
    return out;
}

gp_Pnt pnt_from(const nlohmann::json& a) {
    return gp_Pnt(a[0].get<double>(), a[1].get<double>(), a[2].get<double>());
}

gp_Dir dir_from(const nlohmann::json& a) {
    double x = a[0].get<double>(), y = a[1].get<double>(), z = a[2].get<double>();
    double len = std::sqrt(x * x + y * y + z * z);
    if (len < 1e-15) throw std::runtime_error("zero-length direction");
    return gp_Dir(x / len, y / len, z / len);
}

void put_body(Document& doc, const EntityId& id, const TopoDS_Shape& shape,
              const std::string& name) {
    if (doc.body(id)) doc.replace_body_shape(id, shape);
    else doc.add_body(shape, name, id);
}

void ensure_pattern_slots(Feature& f, int count, Document& doc) {
    if (count < 2) throw std::runtime_error("pattern count must be >= 2");
    const size_t needed = static_cast<size_t>(count - 1);
    if (f.output_bodies.size() > needed) {
        for (size_t i = needed; i < f.output_bodies.size(); ++i) {
            if (doc.body(f.output_bodies[i])) doc.remove_body(f.output_bodies[i]);
        }
        f.output_bodies.resize(needed);
    } else {
        while (f.output_bodies.size() < needed) f.output_bodies.push_back(EntityId::generate());
    }
}

// Resolve a topology ref that may be a durable EntityId string or a legacy
// 1-based TopExp map index. UUID refs survive regen when naming remaps ids.
bool resolve_topo_shape(Document& doc, const Body& body, EntityKind kind,
                        const nlohmann::json& ref, TopoDS_Shape& out, std::string* why) {
    if (ref.is_string()) {
        EntityId id = EntityId::from_string(ref.get<std::string>());
        auto sr = doc.find_subshape(id);
        if (!sr || sr->kind != kind || sr->body != body.id) {
            if (why) *why = "missing " + std::string(kind == EntityKind::Edge ? "edge" : "face") +
                             " uuid " + ref.get<std::string>();
            return false;
        }
        out = doc.resolve(id);
        return !out.IsNull();
    }
    if (ref.is_number_integer() || ref.is_number_float()) {
        sx::occt::ShapeIndexedMap map;
        TopAbs_ShapeEnum occt_kind = kind == EntityKind::Edge ? TopAbs_EDGE : TopAbs_FACE;
        TopExp::MapShapes(body.shape, occt_kind, map);
        int idx = ref.is_number_integer() ? ref.get<int>()
                                          : static_cast<int>(std::lround(ref.get<double>()));
        if (idx < 1 || idx > map.Extent()) {
            if (why) *why = "topology index out of range";
            return false;
        }
        out = map(idx);
        return true;
    }
    // Godot JSON.stringify turns ints into floats (3 → 3.0). Accept whole floats.
    if (ref.is_number_float()) {
        const double v = ref.get<double>();
        const int idx = static_cast<int>(std::lround(v));
        if (std::abs(v - static_cast<double>(idx)) > 1e-9) {
            if (why) *why = "topology ref must be uuid string or integer index";
            return false;
        }
        sx::occt::ShapeIndexedMap map;
        TopAbs_ShapeEnum occt_kind = kind == EntityKind::Edge ? TopAbs_EDGE : TopAbs_FACE;
        TopExp::MapShapes(body.shape, occt_kind, map);
        if (idx < 1 || idx > map.Extent()) {
            if (why) *why = "topology index out of range";
            return false;
        }
        out = map(idx);
        return true;
    }
    if (why) *why = "topology ref must be uuid string or integer index";
    return false;
}

bool planar_face_normal(const TopoDS_Face& face, gp_Dir& n) {
    BRepAdaptor_Surface surf(face);
    if (surf.GetType() != GeomAbs_Plane) return false;
    n = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
    return true;
}

bool edge_midpoint_sample(const TopoDS_Edge& edge, gp_Pnt& point, gp_Vec& unit_tangent) {
    if (BRep_Tool::Degenerated(edge)) return false;
    BRepAdaptor_Curve curve(edge);
    gp_Pnt p;
    gp_Vec v;
    curve.D1(0.5 * (curve.FirstParameter() + curve.LastParameter()), p, v);
    if (v.Magnitude() < 1e-12) return false;
    v.Normalize();
    point = p;
    unit_tangent = v;
    return true;
}

std::string format_fixed(double v, int decimals) {
    double scale = 1.0;
    for (int i = 0; i < decimals; ++i) scale *= 10.0;
    const double shown = std::round(v * scale) / scale;
    std::ostringstream os;
    os.setf(std::ios::fixed);
    os.precision(decimals);
    os << shown;
    return os.str();
}

}  // namespace sx::feature_ops
