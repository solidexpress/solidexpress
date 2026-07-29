#include "sx/mates.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <stdexcept>

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/log.hpp"

namespace sx {

const char* to_string(MateType t) {
    switch (t) {
        case MateType::Fixed: return "fixed";
        case MateType::PlaneCoincident: return "plane_coincident";
        case MateType::Concentric: return "concentric";
    }
    return "unknown";
}

MateType mate_type_from_string(const std::string& s) {
    if (s == "fixed") return MateType::Fixed;
    if (s == "plane_coincident") return MateType::PlaneCoincident;
    if (s == "concentric") return MateType::Concentric;
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
    // Classify enclosure on the source face (orientation is placement-invariant);
    // transform the axis into the reference frame afterward.
    TopoDS_Shape raw = doc.resolve(face);
    if (raw.IsNull() || raw.ShapeType() != TopAbs_FACE) return std::nullopt;
    const TopoDS_Face& src = TopoDS::Face(raw);
    BRepAdaptor_Surface src_surf(src);
    if (src_surf.GetType() != GeomAbs_Cylinder) return std::nullopt;
    const double radius = src_surf.Cylinder().Radius();
    // REVERSED cylindrical faces are hole walls (material outside); FORWARD are
    // outer bosses/pins. Verified against BRepPrimAPI_MakeCylinder / Cut.
    const bool encloses = (src.Orientation() == TopAbs_REVERSED);

    TopoDS_Shape f = reference_face(doc, instance, face);
    if (f.IsNull()) return std::nullopt;
    BRepAdaptor_Surface surf(TopoDS::Face(f));
    if (surf.GetType() != GeomAbs_Cylinder) return std::nullopt;
    gp_Ax1 ax = surf.Cylinder().Axis();
    return MateAxis{ax.Location(), ax.Direction(), radius, encloses};
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
        case MateType::Concentric: {
            // Radial constraint: one face must enclose the other (hole around
            // pin) with a declared positive clearance (offset) that the
            // geometry satisfies. Axes-only mates without fit are rejected.
            if (m.offset <= 0.0) {
                log::error("mate " + m.name +
                           ": concentric requires a positive radial tolerance");
                return false;
            }
            auto a = mate_axis(doc, m.instance_a, m.face_a);
            auto b = mate_axis(doc, m.instance_b, m.face_b);
            if (!a || !b) {
                log::error("mate " + m.name + ": cylindrical faces required");
                return false;
            }
            if (a->encloses == b->encloses) {
                log::error("mate " + m.name +
                           ": concentric requires enclosure (hole around pin)");
                return false;
            }
            const double r_hole = a->encloses ? a->radius : b->radius;
            const double r_pin = a->encloses ? b->radius : a->radius;
            const double clearance = r_hole - r_pin;
            if (clearance + 1e-9 < m.offset) {
                log::error("mate " + m.name +
                           ": radial clearance " + std::to_string(clearance) +
                           " is below tolerance " + std::to_string(m.offset));
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

std::optional<MateAxis> instance_revolute_axis(const Document& doc,
                                              const EntityId& instance) {
    if (instance.is_null() || !doc.instance(instance)) return std::nullopt;
    for (const auto& m : doc.mates()) {
        if (m.type != MateType::Concentric) continue;
        if (m.instance_b != instance) continue;
        // Prefer the grounded / A-side axis (stable under B's motion).
        auto ax = mate_axis(doc, m.instance_a, m.face_a);
        if (ax) return ax;
        return mate_axis(doc, m.instance_b, m.face_b);
    }
    return std::nullopt;
}

}  // namespace sx
