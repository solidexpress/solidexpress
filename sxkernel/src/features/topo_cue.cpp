#include "topo_cue.h"

#include "ops.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <ElCLib.hxx>
#include <ElSLib.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec.hxx>

#include "sx/document.hpp"
#include "sx/occt_types.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <sstream>

namespace sx {

namespace {

double mag2(const Vec3& v) { return v.x * v.x + v.y * v.y + v.z * v.z; }

double mag(const Vec3& v) { return std::sqrt(mag2(v)); }

double dot(const Vec3& a, const Vec3& b) { return a.x * b.x + a.y * b.y + a.z * b.z; }

Vec3 normalized(const Vec3& v) {
    const double m = mag(v);
    if (m < 1e-15) return {};
    return {v.x / m, v.y / m, v.z / m};
}

struct Extent {
    Vec3 lo;
    Vec3 hi;
    bool ok = false;

    static Extent of(const TopoDS_Shape& shape) {
        Extent e;
        if (shape.IsNull()) return e;
        Bnd_Box box;
        BRepBndLib::Add(shape, box);
        if (box.IsVoid()) return e;
        box.Get(e.lo.x, e.lo.y, e.lo.z, e.hi.x, e.hi.y, e.hi.z);
        e.ok = true;
        return e;
    }

    Vec3 span() const { return {hi.x - lo.x, hi.y - lo.y, hi.z - lo.z}; }

    double diagonal() const {
        const Vec3 s = span();
        return std::sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
    }

    Vec3 fraction(const Vec3& p) const {
        const Vec3 s = span();
        auto axis = [](double v, double origin, double length) {
            return (v - origin) / std::max(length, 1e-12);
        };
        return {axis(p.x, lo.x, s.x), axis(p.y, lo.y, s.y), axis(p.z, lo.z, s.z)};
    }

};

bool read_vec(const nlohmann::json& j, const char* key, Vec3& out) {
    if (!j.is_object() || !j.contains(key) || !j[key].is_array() || j[key].size() < 3) return false;
    out = {j[key][0].get<double>(), j[key][1].get<double>(), j[key][2].get<double>()};
    return true;
}

std::string format3(double v) {
    const double shown = std::round(v * 1000.0) / 1000.0;
    std::ostringstream os;
    os.setf(std::ios::fixed);
    os.precision(3);
    os << shown;
    return os.str();
}

std::string vec_text(const Vec3& v) {
    return "(" + format3(v.x) + ", " + format3(v.y) + ", " + format3(v.z) + ")";
}

const char* kind_word(EntityKind kind) {
    return kind == EntityKind::Face ? "face" : "edge";
}

std::string lost_cue(EntityKind kind, const TopoCue& cue, const char* prefix) {
    return std::string(prefix) + " " + kind_word(kind) + " cue point " + vec_text(cue.point) +
           " dir " + vec_text(cue.dir);
}

bool planar_normal(const TopoDS_Face& face, Vec3& n) {
    BRepAdaptor_Surface surf(face);
    if (surf.GetType() != GeomAbs_Plane) return false;
    gp_Dir d = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) d.Reverse();
    n = {d.X(), d.Y(), d.Z()};
    return true;
}

struct Sample {
    TopoDS_Shape shape;
    Vec3 point;
    Vec3 dir;
    Vec3 size;
    bool ok = false;
};

Sample sample_edge(const TopoDS_Edge& edge) {
    Sample s;
    if (BRep_Tool::Degenerated(edge)) return s;
    BRepAdaptor_Curve curve(edge);
    gp_Pnt p;
    gp_Vec v;
    curve.D1(0.5 * (curve.FirstParameter() + curve.LastParameter()), p, v);
    if (v.Magnitude() < 1e-12) return s;
    v.Normalize();
    s.shape = edge;
    s.point = {p.X(), p.Y(), p.Z()};
    s.dir = {v.X(), v.Y(), v.Z()};
    const Extent box = Extent::of(edge);
    if (box.ok) s.size = box.span();
    s.ok = true;
    return s;
}

Sample sample_face(const TopoDS_Face& face) {
    Sample s;
    Vec3 n;
    if (!planar_normal(face, n)) return s;
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    const gp_Pnt p = props.CentreOfMass();
    s.shape = face;
    s.point = {p.X(), p.Y(), p.Z()};
    s.dir = n;
    const Extent box = Extent::of(face);
    if (box.ok) s.size = box.span();
    s.ok = true;
    return s;
}

std::vector<Sample> samples_of(const ShapeIndex& index) {
    std::vector<Sample> out;
    if (index.shape.IsNull()) return out;
    const TopAbs_ShapeEnum occt_kind =
        index.kind == EntityKind::Face ? TopAbs_FACE : TopAbs_EDGE;
    sx::occt::ShapeIndexedMap map;
    TopExp::MapShapes(index.shape, occt_kind, map);
    out.reserve(static_cast<size_t>(map.Extent()));
    for (int i = 1; i <= map.Extent(); ++i) {
        Sample s = index.kind == EntityKind::Face ? sample_face(TopoDS::Face(map(i)))
                                                  : sample_edge(TopoDS::Edge(map(i)));
        if (s.ok) out.push_back(std::move(s));
    }
    return out;
}

Resolution strategy_stable_id(const TopoCue&, const ShapeIndex& index) {
    Resolution r;
    if (!index.doc || !index.body || index.ref.is_null() || index.ref.is_discarded()) return r;
    std::string why;
    TopoDS_Shape shape;
    if (feature_ops::resolve_topo_shape(*index.doc, *index.body, index.kind, index.ref, shape,
                                        &why)) {
        r.found = true;
        r.shape = std::move(shape);
        return r;
    }
    r.lost = why;
    return r;
}

// Absolute cue: the edge algorithm that already shipped (midpoint within
// 0.5 mm, or a line whose axis stays within 0.5 mm), and the face algorithm
// that slides the cue point along its normal onto the plane.
Resolution strategy_absolute(const TopoCue& cue, const ShapeIndex& index) {
    Resolution r;
    if (mag(cue.dir) < 1e-12 || index.shape.IsNull()) return r;
    const Vec3 want_dir = normalized(cue.dir);
    const double tol = cue.tol > 0.0 ? cue.tol : 0.5;
    const gp_Pnt want(cue.point.x, cue.point.y, cue.point.z);
    const gp_Vec want_n(want_dir.x, want_dir.y, want_dir.z);

    if (index.kind == EntityKind::Face) {
        sx::occt::ShapeIndexedMap faces;
        TopExp::MapShapes(index.shape, TopAbs_FACE, faces);
        double best = 1e300;
        for (int i = 1; i <= faces.Extent(); ++i) {
            const TopoDS_Face face = TopoDS::Face(faces(i));
            Vec3 n;
            if (!planar_normal(face, n)) continue;
            if (std::abs(dot(n, want_dir)) < 0.999) continue;
            BRepAdaptor_Surface surf(face);
            const gp_Pln pln = surf.Plane();
            const double shift = gp_Vec(want, pln.Location()).Dot(want_n);
            const gp_Pnt on_plane = want.Translated(want_n * shift);
            double u = 0, v = 0;
            ElSLib::PlaneParameters(pln.Position(), on_plane, u, v);
            BRepClass_FaceClassifier cl(face, gp_Pnt2d(u, v), 1e-4);
            if (cl.State() != TopAbs_IN && cl.State() != TopAbs_ON) continue;
            if (std::abs(shift) < best) {
                best = std::abs(shift);
                r.shape = face;
                r.found = true;
            }
        }
        return r;
    }

    sx::occt::ShapeIndexedMap map;
    TopExp::MapShapes(index.shape, TopAbs_EDGE, map);
    double best = 1e300;
    for (int i = 1; i <= map.Extent(); ++i) {
        const TopoDS_Edge edge = TopoDS::Edge(map(i));
        if (BRep_Tool::Degenerated(edge)) continue;
        BRepAdaptor_Curve curve(edge);
        gp_Pnt p;
        gp_Vec v;
        curve.D1(0.5 * (curve.FirstParameter() + curve.LastParameter()), p, v);
        if (v.Magnitude() < 1e-12) continue;
        v.Normalize();
        if (std::abs(v.Dot(want_n)) <= 0.95) continue;
        double score = 1e300;
        if (curve.GetType() == GeomAbs_Line) {
            const gp_Lin lin = curve.Line();
            const double perp = lin.Distance(want);
            if (perp > tol) continue;
            const double u = ElCLib::Parameter(lin, want);
            const double lo = std::min(curve.FirstParameter(), curve.LastParameter());
            const double hi = std::max(curve.FirstParameter(), curve.LastParameter());
            const double gap = u < lo ? (lo - u) : (u > hi ? (u - hi) : 0.0);
            if (gap > 25.0) continue;
            score = perp + gap * 1.0e-4;
        } else {
            const double dist = p.Distance(want);
            if (dist >= tol) continue;
            score = dist;
        }
        if (score < best) {
            best = score;
            r.shape = edge;
            r.found = true;
        }
    }
    return r;
}

double size_dist(const Vec3& a, const Vec3& b) {
    const double dx = a.x - b.x;
    const double dy = a.y - b.y;
    const double dz = a.z - b.z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

// Distance between two fraction points, scaled into millimetres by the
// bbox diagonal. That length is within 0.02 · diagonal exactly when the
// unit-box fraction distance is within 0.02.
double fraction_gap(const Vec3& a, const Vec3& b) {
    const double dx = a.x - b.x;
    const double dy = a.y - b.y;
    const double dz = a.z - b.z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

// Relative cue: same direction, fraction of the current bbox nearest the
// stored fraction. Accepted only when that entity is unique inside
// 0.02 · bbox diagonal. Face size breaks a remaining tie.
Resolution strategy_relative(const TopoCue& cue, const ShapeIndex& index) {
    Resolution r;
    if (!cue.has_frac || mag(cue.dir) < 1e-12 || index.shape.IsNull()) return r;
    const Extent box = Extent::of(index.shape);
    if (!box.ok || box.diagonal() < 1e-12) return r;
    const Vec3 want_dir = normalized(cue.dir);

    struct Cand {
        TopoDS_Shape shape;
        double dist = 0;
        double size = 0;
    };
    std::vector<Cand> near;
    for (const Sample& s : samples_of(index)) {
        if (std::abs(dot(normalized(s.dir), want_dir)) < 0.999) continue;
        const double dist = fraction_gap(box.fraction(s.point), cue.frac) * box.diagonal();
        if (dist > 0.02 * box.diagonal()) continue;
        near.push_back(Cand{s.shape, dist, size_dist(s.size, cue.size)});
    }
    if (near.empty()) return r;
    std::sort(near.begin(), near.end(), [](const Cand& a, const Cand& b) {
        if (a.dist != b.dist) return a.dist < b.dist;
        return a.size < b.size;
    });
    if (near.size() == 1) {
        r.found = true;
        r.shape = near.front().shape;
        return r;
    }
    if (index.kind == EntityKind::Face) {
        std::sort(near.begin(), near.end(), [](const Cand& a, const Cand& b) {
            if (a.size != b.size) return a.size < b.size;
            return a.dist < b.dist;
        });
        if (near[0].size + 1e-3 < near[1].size) {
            r.found = true;
            r.shape = near.front().shape;
            return r;
        }
    }
    r.lost = lost_cue(index.kind, cue, "ambiguous");
    return r;
}

using Strategy = Resolution (*)(const TopoCue&, const ShapeIndex&);

}  // namespace

Resolution resolve(const TopoCue& cue, const ShapeIndex& index) {
    // Order is this list. Call sites do not know it.
    static constexpr std::array<Strategy, 3> kStrategies = {
        strategy_stable_id,
        strategy_absolute,
        strategy_relative,
    };
    std::string why;
    for (const Strategy strategy : kStrategies) {
        Resolution r = strategy(cue, index);
        if (r.found) return r;
        if (!r.lost.empty()) why = r.lost;
    }
    Resolution lost;
    if (mag(cue.dir) > 1e-12) {
        const std::string named = lost_cue(index.kind, cue, "lost");
        lost.lost = why.empty() ? named : why + "; " + named;
    } else {
        lost.lost = why.empty() ? std::string("lost topology cue") : why;
    }
    return lost;
}

TopoCue cue_from_edge(const TopoDS_Edge& edge, const TopoDS_Shape& owner) {
    TopoCue cue;
    const Sample s = sample_edge(edge);
    if (!s.ok) return cue;
    cue.point = s.point;
    cue.dir = s.dir;
    cue.size = s.size;
    cue.tol = 0.5;
    const Extent box = Extent::of(owner);
    if (box.ok) {
        cue.frac = box.fraction(s.point);
        cue.has_frac = true;
    }
    return cue;
}

TopoCue cue_from_face(const TopoDS_Face& face, const TopoDS_Shape& owner) {
    TopoCue cue;
    const Sample s = sample_face(face);
    if (!s.ok) return cue;
    cue.point = s.point;
    cue.dir = s.dir;
    cue.size = s.size;
    cue.tol = 0.5;
    const Extent box = Extent::of(owner);
    if (box.ok) {
        cue.frac = box.fraction(s.point);
        cue.has_frac = true;
    }
    return cue;
}

nlohmann::json cue_to_json(const TopoCue& cue) {
    nlohmann::json j = {{"point", {cue.point.x, cue.point.y, cue.point.z}},
                        {"dir", {cue.dir.x, cue.dir.y, cue.dir.z}},
                        {"size", {cue.size.x, cue.size.y, cue.size.z}},
                        {"tol", cue.tol}};
    if (cue.has_frac) j["frac"] = {cue.frac.x, cue.frac.y, cue.frac.z};
    return j;
}

TopoCue cue_from_json(const nlohmann::json& j) {
    TopoCue cue;
    if (!j.is_object()) return cue;
    read_vec(j, "point", cue.point);
    if (!read_vec(j, "dir", cue.dir)) read_vec(j, "normal", cue.dir);
    read_vec(j, "size", cue.size);
    cue.has_frac = read_vec(j, "frac", cue.frac);
    if (j.contains("tol") && j["tol"].is_number()) cue.tol = j["tol"].get<double>();
    return cue;
}

bool cue_names_line(const TopoCue& cue, const Vec3& point, const Vec3& dir) {
    if (mag(cue.dir) < 1e-12 || mag(dir) < 1e-12) return false;
    const Vec3 want = normalized(cue.dir);
    const Vec3 got = normalized(dir);
    if (std::abs(dot(want, got)) <= 0.95) return false;
    const Vec3 delta{point.x - cue.point.x, point.y - cue.point.y, point.z - cue.point.z};
    const double along = dot(delta, want);
    const Vec3 perp{delta.x - want.x * along, delta.y - want.y * along, delta.z - want.z * along};
    const double tol = cue.tol > 0.0 ? cue.tol : 0.5;
    return mag(perp) <= tol;
}

bool cue_names_face(const TopoCue& stored, const TopoCue& fresh) {
    if (mag(stored.dir) < 1e-12 || mag(fresh.dir) < 1e-12) return false;
    if (std::abs(dot(normalized(stored.dir), normalized(fresh.dir))) < 0.999) return false;
    const Vec3 n = normalized(fresh.dir);
    const Vec3 delta{stored.point.x - fresh.point.x, stored.point.y - fresh.point.y,
                     stored.point.z - fresh.point.z};
    const double tol = stored.tol > 0.0 ? stored.tol : 0.5;
    return std::abs(dot(delta, n)) <= tol;
}

}  // namespace sx
