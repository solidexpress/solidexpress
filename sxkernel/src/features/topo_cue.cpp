#include "topo_cue.h"

#include "ops.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepGProp.hxx>
#include <Bnd_Box.hxx>
#include <ElCLib.hxx>
#include <ElSLib.hxx>
#include <GeomAbs_CurveType.hxx>
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

namespace sx {

namespace {

// OCCT Normalized throws when the modulus is at most gp::Resolution().
gp_XYZ unit_or_zero(const gp_XYZ& v) {
    if (v.Modulus() < 1e-15) return gp_XYZ(0.0, 0.0, 0.0);
    return v.Normalized();
}

bool is_zero(const gp_XYZ& v) { return v.SquareModulus() == 0.0; }

struct Extent {
    gp_XYZ lo;
    gp_XYZ hi;
    bool ok = false;

    static Extent of(const TopoDS_Shape& shape) {
        Extent e;
        if (shape.IsNull()) return e;
        Bnd_Box box;
        BRepBndLib::Add(shape, box);
        if (box.IsVoid()) return e;
        double x0 = 0, y0 = 0, z0 = 0, x1 = 0, y1 = 0, z1 = 0;
        box.Get(x0, y0, z0, x1, y1, z1);
        e.lo = gp_XYZ(x0, y0, z0);
        e.hi = gp_XYZ(x1, y1, z1);
        e.ok = true;
        return e;
    }

    gp_XYZ span() const { return hi - lo; }

    double diagonal() const { return span().Modulus(); }

    gp_XYZ fraction(const gp_XYZ& p) const {
        const gp_XYZ s = span();
        auto axis = [](double v, double origin, double length) {
            return (v - origin) / std::max(length, 1e-12);
        };
        return gp_XYZ(axis(p.X(), lo.X(), s.X()), axis(p.Y(), lo.Y(), s.Y()),
                      axis(p.Z(), lo.Z(), s.Z()));
    }

};

bool read_vec(const nlohmann::json& j, const char* key, gp_XYZ& out) {
    if (!j.is_object() || !j.contains(key) || !j[key].is_array() || j[key].size() < 3) return false;
    out = gp_XYZ(j[key][0].get<double>(), j[key][1].get<double>(), j[key][2].get<double>());
    return true;
}

std::string vec_text(const gp_XYZ& v) {
    return "(" + feature_ops::format_fixed(v.X(), 3) + ", " + feature_ops::format_fixed(v.Y(), 3) +
           ", " + feature_ops::format_fixed(v.Z(), 3) + ")";
}

const char* kind_word(EntityKind kind) {
    return kind == EntityKind::Face ? "face" : "edge";
}

std::string lost_cue(EntityKind kind, const TopoCue& cue, const char* prefix) {
    return std::string(prefix) + " " + kind_word(kind) + " cue point " + vec_text(cue.point) +
           " dir " + vec_text(cue.dir);
}

struct Sample {
    TopoDS_Shape shape;
    gp_XYZ point;
    gp_XYZ dir;
    gp_XYZ size;
    bool ok = false;
};

Sample sample_edge(const TopoDS_Edge& edge) {
    Sample s;
    gp_Pnt p;
    gp_Vec v;
    if (!feature_ops::edge_midpoint_sample(edge, p, v)) return s;
    s.shape = edge;
    s.point = p.XYZ();
    s.dir = v.XYZ();
    const Extent box = Extent::of(edge);
    if (box.ok) s.size = box.span();
    s.ok = true;
    return s;
}

Sample sample_face(const TopoDS_Face& face) {
    Sample s;
    gp_Dir n;
    if (!feature_ops::planar_face_normal(face, n)) return s;
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    const gp_Pnt p = props.CentreOfMass();
    s.shape = face;
    s.point = p.XYZ();
    s.dir = n.XYZ();
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
    if (cue.dir.Modulus() < 1e-12 || index.shape.IsNull()) return r;
    const gp_XYZ want_dir = unit_or_zero(cue.dir);
    const double tol = cue.tol > 0.0 ? cue.tol : 0.5;
    const gp_Pnt want(cue.point.X(), cue.point.Y(), cue.point.Z());
    const gp_Vec want_n(want_dir);

    if (index.kind == EntityKind::Face) {
        sx::occt::ShapeIndexedMap faces;
        TopExp::MapShapes(index.shape, TopAbs_FACE, faces);
        double best = 1e300;
        for (int i = 1; i <= faces.Extent(); ++i) {
            const TopoDS_Face face = TopoDS::Face(faces(i));
            gp_Dir n;
            if (!feature_ops::planar_face_normal(face, n)) continue;
            if (std::abs(n.XYZ().Dot(want_dir)) < 0.999) continue;
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
        gp_Pnt p;
        gp_Vec v;
        if (!feature_ops::edge_midpoint_sample(edge, p, v)) continue;
        if (std::abs(v.Dot(want_n)) <= 0.95) continue;
        BRepAdaptor_Curve curve(edge);
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

double size_dist(const gp_XYZ& a, const gp_XYZ& b) { return (a - b).Modulus(); }

// Distance between two fraction points, scaled into millimetres by the
// bbox diagonal. That length is within 0.02 · diagonal exactly when the
// unit-box fraction distance is within 0.02.
double fraction_gap(const gp_XYZ& a, const gp_XYZ& b) { return (a - b).Modulus(); }

// Relative cue: same direction, fraction of the current bbox nearest the
// stored fraction. Accepted only when that entity is unique inside
// 0.02 · bbox diagonal. Face size breaks a remaining tie.
Resolution strategy_relative(const TopoCue& cue, const ShapeIndex& index) {
    Resolution r;
    if (!cue.has_frac || cue.dir.Modulus() < 1e-12 || index.shape.IsNull()) return r;
    const Extent box = Extent::of(index.shape);
    if (!box.ok || box.diagonal() < 1e-12) return r;
    const gp_XYZ want_dir = unit_or_zero(cue.dir);

    struct Cand {
        TopoDS_Shape shape;
        double dist = 0;
        double size = 0;
    };
    std::vector<Cand> near;
    for (const Sample& s : samples_of(index)) {
        if (std::abs(unit_or_zero(s.dir).Dot(want_dir)) < 0.999) continue;
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
    if (cue.dir.Modulus() > 1e-12) {
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
    nlohmann::json j = {{"point", {cue.point.X(), cue.point.Y(), cue.point.Z()}},
                        {"dir", {cue.dir.X(), cue.dir.Y(), cue.dir.Z()}},
                        {"size", {cue.size.X(), cue.size.Y(), cue.size.Z()}},
                        {"tol", cue.tol}};
    if (cue.has_frac) j["frac"] = {cue.frac.X(), cue.frac.Y(), cue.frac.Z()};
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

bool cue_names_line(const TopoCue& cue, const gp_XYZ& point, const gp_XYZ& dir) {
    if (cue.dir.Modulus() < 1e-12 || dir.Modulus() < 1e-12) return false;
    const gp_XYZ want = unit_or_zero(cue.dir);
    const gp_XYZ got = unit_or_zero(dir);
    if (std::abs(want.Dot(got)) <= 0.95) return false;
    const gp_XYZ delta = point - cue.point;
    const double along = delta.Dot(want);
    const gp_XYZ perp = delta - want * along;
    const double tol = cue.tol > 0.0 ? cue.tol : 0.5;
    return perp.Modulus() <= tol;
}

bool cue_names_face(const TopoCue& stored, const TopoCue& fresh) {
    if (stored.dir.Modulus() < 1e-12 || fresh.dir.Modulus() < 1e-12) return false;
    if (std::abs(unit_or_zero(stored.dir).Dot(unit_or_zero(fresh.dir))) < 0.999) return false;
    const gp_XYZ n = unit_or_zero(fresh.dir);
    const gp_XYZ delta = stored.point - fresh.point;
    const double tol = stored.tol > 0.0 ? stored.tol : 0.5;
    return std::abs(delta.Dot(n)) <= tol;
}

bool refresh_cue(nlohmann::json& cues, const std::string& key, const TopoCue& fresh,
                 EntityKind kind) {
    if (is_zero(fresh.dir)) return false;
    if (cues.contains(key)) {
        const TopoCue stored = cue_from_json(cues[key]);
        const bool same = kind == EntityKind::Face ? cue_names_face(stored, fresh)
                                                    : cue_names_line(stored, fresh.point, fresh.dir);
        if (!same) return false;
    }
    cues[key] = cue_to_json(fresh);
    return true;
}

}  // namespace sx
