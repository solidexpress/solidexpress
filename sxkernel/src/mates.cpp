#include "sx/mates.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepTools.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <stdexcept>

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/log.hpp"

namespace sx {

const char* to_string(MateType t) {
    switch (t) {
        case MateType::Fixed: return "fixed";
        case MateType::PlaneCoincident: return "plane_coincident";
        case MateType::PlaneParallel: return "plane_parallel";
        case MateType::Concentric: return "concentric";
        case MateType::Fastened: return "fastened";
    }
    return "unknown";
}

MateType mate_type_from_string(const std::string& s) {
    if (s == "fixed") return MateType::Fixed;
    if (s == "plane_coincident") return MateType::PlaneCoincident;
    if (s == "plane_parallel") return MateType::PlaneParallel;
    if (s == "concentric") return MateType::Concentric;
    if (s == "fastened") return MateType::Fastened;
    throw std::invalid_argument("unknown mate type: " + s);
}

void to_json(nlohmann::json& j, const Mate& m) {
    j = nlohmann::json{
        {"uuid", m.id.str()},
        {"type", to_string(m.type)},
        {"instance_a", m.instance_a.is_null() ? "" : m.instance_a.str()},
        {"face_a", m.face_a.is_null() ? "" : m.face_a.str()},
        {"instance_b", m.instance_b.is_null() ? "" : m.instance_b.str()},
        {"face_b", m.face_b.is_null() ? "" : m.face_b.str()},
        {"offset", m.offset},
        {"flip", m.flip},
        {"name", m.name},
    };
}

static EntityId id_or_null(const std::string& s) {
    return s.empty() ? EntityId{} : EntityId::from_string(s);
}

void from_json(const nlohmann::json& j, Mate& m) {
    m.id = EntityId::from_string(j.at("uuid").get<std::string>());
    m.type = mate_type_from_string(j.at("type").get<std::string>());
    m.instance_a = id_or_null(j.value("instance_a", ""));
    m.face_a = id_or_null(j.value("face_a", ""));
    m.instance_b = id_or_null(j.value("instance_b", ""));
    m.face_b = id_or_null(j.value("face_b", ""));
    m.offset = j.value("offset", 0.0);
    m.flip = j.value("flip", false);
    m.name = j.value("name", "");
}

void to_json(nlohmann::json& j, const MateConnector& c) {
    j = nlohmann::json{
        {"uuid", c.id.str()},
        {"instance", c.instance.is_null() ? "" : c.instance.str()},
        {"face", c.face.is_null() ? "" : c.face.str()},
        {"origin", c.origin},
        {"z_dir", c.z_dir},
        {"x_dir", c.x_dir},
        {"name", c.name},
    };
}

void from_json(const nlohmann::json& j, MateConnector& c) {
    c.id = id_or_null(j.value("uuid", j.value("id", "")));
    c.instance = id_or_null(j.value("instance", ""));
    c.face = id_or_null(j.value("face", ""));
    if (j.contains("origin") && j["origin"].is_array() && j["origin"].size() == 3)
        for (int i = 0; i < 3; ++i) c.origin[i] = j["origin"][i].get<double>();
    if (j.contains("z_dir") && j["z_dir"].is_array() && j["z_dir"].size() == 3)
        for (int i = 0; i < 3; ++i) c.z_dir[i] = j["z_dir"][i].get<double>();
    if (j.contains("x_dir") && j["x_dir"].is_array() && j["x_dir"].size() == 3)
        for (int i = 0; i < 3; ++i) c.x_dir[i] = j["x_dir"][i].get<double>();
    c.name = j.value("name", "");
}

namespace {

// Face shape under the reference's placement. Null shape on failure.
TopoDS_Shape reference_face(const Document& doc, const EntityId& instance,
                            const EntityId& face) {
    TopoDS_Shape f = doc.resolve(face);
    if (f.IsNull() || f.ShapeType() != TopAbs_FACE) return {};
    if (instance.is_null()) return f;
    const Instance* inst = doc.instance(instance);
    if (!inst) return {};
    return f.Moved(TopLoc_Location(transform_of(*inst)));
}

}  // namespace

std::optional<MatePlane> mate_plane(const Document& doc, const EntityId& instance,
                                    const EntityId& face) {
    TopoDS_Shape f = reference_face(doc, instance, face);
    if (f.IsNull()) return std::nullopt;
    BRepAdaptor_Surface surf(TopoDS::Face(f));
    if (surf.GetType() != GeomAbs_Plane) return std::nullopt;
    gp_Pln pln = surf.Plane();
    gp_Dir n = pln.Axis().Direction();
    if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
    return MatePlane{pln.Location(), n};
}

std::optional<MateAxis> mate_axis(const Document& doc, const EntityId& instance,
                                  const EntityId& face) {
    TopoDS_Shape f = reference_face(doc, instance, face);
    if (f.IsNull()) return std::nullopt;
    BRepAdaptor_Surface surf(TopoDS::Face(f));
    if (surf.GetType() != GeomAbs_Cylinder) return std::nullopt;
    gp_Ax1 ax = surf.Cylinder().Axis();
    return MateAxis{ax.Location(), ax.Direction()};
}

std::optional<MateConnector> implicit_connector(const Document& doc,
                                                const EntityId& instance,
                                                const EntityId& face) {
    TopoDS_Shape f = reference_face(doc, instance, face);
    if (f.IsNull() || f.ShapeType() != TopAbs_FACE) return std::nullopt;
    TopoDS_Face tf = TopoDS::Face(f);
    BRepAdaptor_Surface surf(tf);
    Standard_Real umin = 0, umax = 0, vmin = 0, vmax = 0;
    BRepTools::UVBounds(tf, umin, umax, vmin, vmax);
    gp_Pnt mid = surf.Value(0.5 * (umin + umax), 0.5 * (vmin + vmax));

    MateConnector c;
    c.instance = instance;
    c.face = face;
    if (surf.GetType() == GeomAbs_Plane) {
        auto pl = mate_plane(doc, instance, face);
        if (!pl) return std::nullopt;
        gp_Dir z = pl->normal;
        gp_Dir xref = surf.Plane().XAxis().Direction();
        if (std::abs(xref.Dot(z)) > 0.95) xref = surf.Plane().YAxis().Direction();
        gp_Dir x = z.Crossed(xref.Crossed(z));
        c.origin = {mid.X(), mid.Y(), mid.Z()};
        c.z_dir = {z.X(), z.Y(), z.Z()};
        c.x_dir = {x.X(), x.Y(), x.Z()};
        c.name = "implicit plane";
        return c;
    }
    if (surf.GetType() == GeomAbs_Cylinder) {
        auto ax = mate_axis(doc, instance, face);
        if (!ax) return std::nullopt;
        gp_Vec v(ax->point, mid);
        gp_Vec axial = gp_Vec(ax->dir) * v.Dot(gp_Vec(ax->dir));
        gp_Pnt origin = ax->point.Translated(axial);
        gp_Dir z = ax->dir;
        gp_Vec radial(origin, mid);
        gp_Dir x = radial.Magnitude() > 1e-9 ? gp_Dir(radial) : gp_Dir(1, 0, 0);
        if (std::abs(x.Dot(z)) > 0.95) x = z.Crossed(gp_Dir(0, 1, 0));
        c.origin = {origin.X(), origin.Y(), origin.Z()};
        c.z_dir = {z.X(), z.Y(), z.Z()};
        c.x_dir = {x.X(), x.Y(), x.Z()};
        c.name = "implicit cylinder";
        return c;
    }
    return std::nullopt;
}

namespace {

// Rotation of `from` onto `to` about `about`, as a world-space gp_Trsf.
gp_Trsf rotation_about(const gp_Pnt& about, const gp_Dir& from, const gp_Dir& to) {
    gp_Trsf out;
    gp_Quaternion q{gp_Vec(from), gp_Vec(to)};
    gp_Trsf rot;
    rot.SetRotation(q);
    gp_Trsf to_origin, back;
    to_origin.SetTranslation(gp_Vec(about.XYZ().Reversed()));
    back.SetTranslation(gp_Vec(about.XYZ()));
    out = back * rot * to_origin;
    return out;
}

// Writes correction * current placement back onto the instance.
bool move_instance(Document& doc, const EntityId& instance_id, const gp_Trsf& correction) {
    const Instance* inst = doc.instance(instance_id);
    if (!inst) return false;
    gp_Trsf t = correction * transform_of(*inst);
    gp_Quaternion q = t.GetRotation();
    gp_XYZ tr = t.TranslationPart();
    return doc.set_instance_transform(instance_id, {tr.X(), tr.Y(), tr.Z()},
                                      {q.X(), q.Y(), q.Z(), q.W()});
}

}  // namespace

bool apply_mate(Document& doc, const Mate& m) {
    if (m.type == MateType::Fixed) return doc.instance(m.instance_b) != nullptr;
    if (m.instance_b.is_null() || !doc.instance(m.instance_b)) {
        log::error("mate " + m.name + ": instance_b must be a component instance");
        return false;
    }
    // Fix restraint: skip transforms (instance stays where it was placed).
    if (doc.instance(m.instance_b)->fixed) return true;
    switch (m.type) {
        case MateType::PlaneCoincident: {
            auto a = mate_plane(doc, m.instance_a, m.face_a);
            auto b = mate_plane(doc, m.instance_b, m.face_b);
            if (!a || !b) {
                log::error("mate " + m.name + ": planar faces required");
                return false;
            }
            gp_Dir target = m.flip ? a->normal : a->normal.Reversed();
            gp_Trsf corr = rotation_about(b->point, b->normal, target);
            // b->point is the rotation center, so it is unmoved; close the
            // gap along A's normal to the requested offset.
            double gap = gp_Vec(a->point, b->point).Dot(gp_Vec(a->normal));
            gp_Trsf shift;
            shift.SetTranslation(gp_Vec(a->normal) * (m.offset - gap));
            return move_instance(doc, m.instance_b, shift * corr);
        }
        case MateType::PlaneParallel: {
            // Align normals (orientation only); leave translation free — the
            // SolidWorks Parallel standard mate for planar faces.
            auto a = mate_plane(doc, m.instance_a, m.face_a);
            auto b = mate_plane(doc, m.instance_b, m.face_b);
            if (!a || !b) {
                log::error("mate " + m.name + ": planar faces required");
                return false;
            }
            gp_Dir target = a->normal;
            if (gp_Vec(b->normal).Dot(gp_Vec(target)) < 0.0) target.Reverse();
            if (m.flip) target.Reverse();
            gp_Trsf corr = rotation_about(b->point, b->normal, target);
            return move_instance(doc, m.instance_b, corr);
        }
        case MateType::Concentric: {
            auto a = mate_axis(doc, m.instance_a, m.face_a);
            auto b = mate_axis(doc, m.instance_b, m.face_b);
            if (!a || !b) {
                log::error("mate " + m.name + ": cylindrical faces required");
                return false;
            }
            gp_Dir target = a->dir;
            if (gp_Vec(b->dir).Dot(gp_Vec(target)) < 0.0) target.Reverse();
            gp_Trsf corr = rotation_about(b->point, b->dir, target);
            // After rotation b->point is unchanged; translate its radial
            // offset from axis A to zero (axial slide stays free).
            gp_Vec v(b->point, a->point);
            gp_Vec axial = gp_Vec(a->dir) * v.Dot(gp_Vec(a->dir));
            gp_Trsf shift;
            shift.SetTranslation(v - axial);
            return move_instance(doc, m.instance_b, shift * corr);
        }
        case MateType::Fastened: {
            auto a = implicit_connector(doc, m.instance_a, m.face_a);
            auto b = implicit_connector(doc, m.instance_b, m.face_b);
            if (!a || !b) {
                log::error("mate " + m.name + ": connectors require planar or cylindrical faces");
                return false;
            }
            gp_Pnt oa(a->origin[0], a->origin[1], a->origin[2]);
            gp_Pnt ob(b->origin[0], b->origin[1], b->origin[2]);
            gp_Dir za(a->z_dir[0], a->z_dir[1], a->z_dir[2]);
            gp_Dir zb(b->z_dir[0], b->z_dir[1], b->z_dir[2]);
            gp_Dir xa(a->x_dir[0], a->x_dir[1], a->x_dir[2]);
            gp_Dir xb(b->x_dir[0], b->x_dir[1], b->x_dir[2]);
            gp_Dir z_target = m.flip ? za : za.Reversed();
            gp_Trsf corr = rotation_about(ob, zb, z_target);
            gp_Vec xb_rot = gp_Vec(xb).Transformed(corr);
            gp_Vec xa_vec(xa);
            gp_Vec z_t(z_target);
            gp_Vec xb_in = xb_rot - z_t * xb_rot.Dot(z_t);
            gp_Vec xa_in = xa_vec - z_t * xa_vec.Dot(z_t);
            if (xb_in.Magnitude() > 1e-9 && xa_in.Magnitude() > 1e-9) {
                gp_Trsf spin = rotation_about(ob, gp_Dir(xb_in), gp_Dir(xa_in));
                corr = spin * corr;
            }
            gp_Pnt dest = oa.Translated(gp_Vec(za) * m.offset);
            gp_Trsf shift;
            shift.SetTranslation(gp_Vec(ob, dest));
            return move_instance(doc, m.instance_b, shift * corr);
        }
        case MateType::Fixed:
            break;
    }
    return false;
}

bool solve_mates(Document& doc) {
    bool ok = true;
    for (const auto& m : doc.mates()) ok = apply_mate(doc, m) && ok;
    return ok;
}

}  // namespace sx
