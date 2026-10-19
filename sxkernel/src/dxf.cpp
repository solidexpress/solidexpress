#include "sx/dxf.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <set>
#include <sstream>
#include <utility>

#include <BRepAdaptor_Curve.hxx>
#include <BRep_Builder.hxx>
#include <GeomAbs_CurveType.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Elips.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include "sx/occt_types.hpp"

#include "sx/document.hpp"
#include "sx/drawing_doc.hpp"
#include "sx/drawings.hpp"
#include "sx/entity.hpp"
#include "sx/features.hpp"

namespace sx {
namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr double kTwoPi = 2.0 * kPi;

std::string trim(std::string s) {
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(s.begin());
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    return s;
}

bool next_pair(std::istream& in, int& code, std::string& value) {
    std::string line;
    if (!std::getline(in, line)) return false;
    try {
        code = std::stoi(trim(line));
    } catch (...) {
        return false;
    }
    if (!std::getline(in, value)) return false;
    value = trim(value);
    return true;
}

struct PolyVert {
    double x = 0, y = 0, bulge = 0;
};

void bulge_to_arc(const PolyVert& a, const PolyVert& b, DxfEntity& e) {
    e.kind = DxfEntity::Kind::Arc;
    const double theta = 4.0 * std::atan(a.bulge);
    const double dx = b.x - a.x;
    const double dy = b.y - a.y;
    const double chord = std::hypot(dx, dy);
    if (chord < 1e-15 || std::abs(std::sin(theta * 0.5)) < 1e-15) {
        e.kind = DxfEntity::Kind::Line;
        e.x1 = a.x;
        e.y1 = a.y;
        e.x2 = b.x;
        e.y2 = b.y;
        return;
    }
    const double r = std::abs(chord / (2.0 * std::sin(theta * 0.5)));
    const double mx = 0.5 * (a.x + b.x);
    const double my = 0.5 * (a.y + b.y);
    const double nx = -dy / chord;
    const double ny = dx / chord;
    const double off = r * std::cos(theta * 0.5);
    e.cx = mx + nx * off;
    e.cy = my + ny * off;
    e.radius = r;
    double sa = std::atan2(a.y - e.cy, a.x - e.cx);
    double ea = std::atan2(b.y - e.cy, b.x - e.cx);
    if (a.bulge > 0.0) {
        if (ea <= sa) ea += kTwoPi;
    } else {
        if (ea >= sa) ea -= kTwoPi;
    }
    e.start_angle = sa * 180.0 / kPi;
    e.end_angle = ea * 180.0 / kPi;
}

void emit_polyline(const std::vector<PolyVert>& verts, bool closed, std::vector<DxfEntity>& out) {
    if (verts.size() < 2) return;
    const size_t n = verts.size();
    const size_t segs = closed ? n : n - 1;
    for (size_t i = 0; i < segs; ++i) {
        const PolyVert& a = verts[i];
        const PolyVert& b = verts[(i + 1) % n];
        DxfEntity e;
        if (std::abs(a.bulge) < 1e-12) {
            e.kind = DxfEntity::Kind::Line;
            e.x1 = a.x;
            e.y1 = a.y;
            e.x2 = b.x;
            e.y2 = b.y;
        } else {
            bulge_to_arc(a, b, e);
        }
        out.push_back(e);
    }
}

bool is_known_entity(const std::string& v) {
    return v == "LINE" || v == "CIRCLE" || v == "ARC" || v == "ELLIPSE" || v == "SPLINE" ||
           v == "LWPOLYLINE" || v == "POLYLINE" || v == "VERTEX" || v == "SEQEND";
}

struct SheetFrame {
    gp_Dir x;
    gp_Dir y;
    std::array<double, 2> xy(const gp_Pnt& p) const {
        return {p.X() * x.X() + p.Y() * x.Y() + p.Z() * x.Z(),
                p.X() * y.X() + p.Y() * y.Y() + p.Z() * y.Z()};
    }
};

SheetFrame make_sheet(const gp_Dir& view_dir, const gp_Dir& up) {
    gp_Dir toward = view_dir.Reversed();
    gp_Dir sx = up.Crossed(toward);
    gp_Dir sy = toward.Crossed(sx);
    return {sx, sy};
}

void add_typed_edge(const TopoDS_Edge& edge, const SheetFrame& sheet, const gp_Dir& view_dir,
                    std::vector<DxfEntity>& out) {
    BRepAdaptor_Curve curve(edge);
    const GeomAbs_CurveType ty = curve.GetType();
    auto push_circle = [&](const gp_Circ& circ, bool full, double u0, double u1) {
        const gp_Dir axis = circ.Axis().Direction();
        const double ndot = std::abs(axis.Dot(view_dir));
        const auto c2 = sheet.xy(circ.Location());
        if (ndot < 1e-8) {
            // Edge-on: diameter line.
            gp_Vec major = circ.XAxis().Direction();
            if (std::abs(major.Dot(view_dir)) > 0.9) major = circ.YAxis().Direction();
            gp_Pnt a = circ.Location().Translated(major * circ.Radius());
            gp_Pnt b = circ.Location().Translated(major * (-circ.Radius()));
            const auto pa = sheet.xy(a);
            const auto pb = sheet.xy(b);
            if (std::hypot(pa[0] - pb[0], pa[1] - pb[1]) < 1e-9) return;
            DxfEntity e;
            e.kind = DxfEntity::Kind::Line;
            e.x1 = pa[0];
            e.y1 = pa[1];
            e.x2 = pb[0];
            e.y2 = pb[1];
            out.push_back(e);
            return;
        }
        DxfEntity e;
        e.cx = c2[0];
        e.cy = c2[1];
        e.radius = circ.Radius();
        if (ndot > 1.0 - 1e-8 && full) {
            e.kind = DxfEntity::Kind::Circle;
            out.push_back(e);
            return;
        }
        if (ndot > 1.0 - 1e-8) {
            e.kind = DxfEntity::Kind::Arc;
            gp_Pnt p0 = curve.Value(u0);
            gp_Pnt p1 = curve.Value(u1);
            const auto a = sheet.xy(p0);
            const auto b = sheet.xy(p1);
            e.start_angle = std::atan2(a[1] - e.cy, a[0] - e.cx) * 180.0 / kPi;
            e.end_angle = std::atan2(b[1] - e.cy, b[0] - e.cx) * 180.0 / kPi;
            out.push_back(e);
            return;
        }
        e.kind = DxfEntity::Kind::Ellipse;
        // Major stays r; minor is r * |n·view|.
        gp_Vec mx = circ.XAxis().Direction();
        if (std::abs(mx.Dot(view_dir)) > 0.9) mx = circ.YAxis().Direction();
        gp_Pnt maj = circ.Location().Translated(mx * circ.Radius());
        const auto m2 = sheet.xy(maj);
        e.major_x = m2[0] - e.cx;
        e.major_y = m2[1] - e.cy;
        e.ratio = ndot;
        out.push_back(e);
    };

    if (ty == GeomAbs_Line) {
        const auto a = sheet.xy(curve.Value(curve.FirstParameter()));
        const auto b = sheet.xy(curve.Value(curve.LastParameter()));
        if (std::hypot(a[0] - b[0], a[1] - b[1]) < 1e-9) return;
        DxfEntity e;
        e.kind = DxfEntity::Kind::Line;
        e.x1 = a[0];
        e.y1 = a[1];
        e.x2 = b[0];
        e.y2 = b[1];
        out.push_back(e);
        return;
    }
    if (ty == GeomAbs_Circle) {
        const double u0 = curve.FirstParameter();
        const double u1 = curve.LastParameter();
        const bool full = curve.IsClosed() || std::abs(std::abs(u1 - u0) - kTwoPi) < 1e-6;
        push_circle(curve.Circle(), full, u0, u1);
        return;
    }
    if (ty == GeomAbs_Ellipse) {
        const gp_Elips el = curve.Ellipse();
        const gp_Dir axis = el.Axis().Direction();
        if (std::abs(axis.Dot(view_dir)) < 1e-8) return;
        const auto c2 = sheet.xy(el.Location());
        gp_Pnt maj = el.Location().Translated(gp_Vec(el.XAxis().Direction()) * el.MajorRadius());
        const auto m2 = sheet.xy(maj);
        DxfEntity e;
        e.kind = DxfEntity::Kind::Ellipse;
        e.cx = c2[0];
        e.cy = c2[1];
        e.major_x = m2[0] - e.cx;
        e.major_y = m2[1] - e.cy;
        e.ratio = el.MinorRadius() / std::max(el.MajorRadius(), 1e-15);
        out.push_back(e);
        return;
    }
    if (ty == GeomAbs_BSplineCurve || ty == GeomAbs_BezierCurve) {
        DxfEntity e;
        e.kind = DxfEntity::Kind::Spline;
        e.degree = std::max(1, curve.Degree());
        const int samp = std::max(curve.NbPoles() + 1, 8);
        for (int i = 0; i < samp; ++i) {
            const double t = static_cast<double>(i) / (samp - 1);
            const double u =
                curve.FirstParameter() + t * (curve.LastParameter() - curve.FirstParameter());
            e.points.push_back(sheet.xy(curve.Value(u)));
        }
        if (e.points.size() >= 2) out.push_back(e);
    }
}

void dedupe_circles(std::vector<DxfEntity>& ents) {
    std::vector<DxfEntity> kept;
    kept.reserve(ents.size());
    for (const auto& e : ents) {
        if (e.kind != DxfEntity::Kind::Circle) {
            kept.push_back(e);
            continue;
        }
        bool dup = false;
        for (const auto& k : kept) {
            if (k.kind == DxfEntity::Kind::Circle && std::abs(k.cx - e.cx) < 1e-7 &&
                std::abs(k.cy - e.cy) < 1e-7 && std::abs(k.radius - e.radius) < 1e-7) {
                dup = true;
                break;
            }
        }
        if (!dup) kept.push_back(e);
    }
    ents.swap(kept);
}

std::vector<DxfEntity> typed_from_shape(const TopoDS_Shape& shape, const gp_Dir& view_dir,
                                        const gp_Dir& up) {
    std::vector<DxfEntity> out;
    if (shape.IsNull()) return out;
    const SheetFrame sheet = make_sheet(view_dir, up);
    sx::occt::ShapeIndexedMap edges;
    TopExp::MapShapes(shape, TopAbs_EDGE, edges);
    for (int i = 1; i <= edges.Extent(); ++i) {
        add_typed_edge(TopoDS::Edge(edges(i)), sheet, view_dir, out);
    }
    dedupe_circles(out);
    return out;
}

}  // namespace

std::vector<DxfEntity> read_dxf(const std::string& path, std::string* err,
                                std::vector<std::string>* refused) {
    std::ifstream in(path);
    if (!in) {
        if (err) *err = "cannot open DXF " + path;
        return {};
    }
    std::vector<DxfEntity> out;
    bool in_entities = false;
    int code = 0;
    std::string value;
    DxfEntity cur;
    bool have = false;
    enum class Mode { None, Entity, LwPoly, Polyline };
    Mode mode = Mode::None;
    std::vector<PolyVert> poly;
    PolyVert pv;
    bool pv_xy = false;
    bool poly_closed = false;
    std::set<std::string> skipped;

    auto flush_poly = [&] {
        if (pv_xy) {
            poly.push_back(pv);
            pv = {};
            pv_xy = false;
        }
        emit_polyline(poly, poly_closed, out);
        poly.clear();
        poly_closed = false;
        mode = Mode::None;
    };
    auto flush_ent = [&] {
        if (!have) return;
        if (cur.kind == DxfEntity::Kind::Spline) {
            if (cur.points.size() >= 2) out.push_back(cur);
        } else if (cur.kind == DxfEntity::Kind::Ellipse) {
            out.push_back(cur);
        } else if (cur.kind == DxfEntity::Kind::Line || cur.radius > 0.0) {
            out.push_back(cur);
        }
        have = false;
        cur = {};
        mode = Mode::None;
    };

    while (next_pair(in, code, value)) {
        if (code == 0 && value == "SECTION") {
            int c2 = 0;
            std::string v2;
            if (next_pair(in, c2, v2) && c2 == 2 && v2 == "ENTITIES") in_entities = true;
            continue;
        }
        if (code == 0 && value == "ENDSEC") {
            if (in_entities) {
                if (mode == Mode::LwPoly || mode == Mode::Polyline) flush_poly();
                flush_ent();
            }
            in_entities = false;
            continue;
        }
        if (!in_entities) continue;
        if (code == 0) {
            if (mode == Mode::LwPoly) flush_poly();
            if (value == "VERTEX" && mode == Mode::Polyline) {
                if (pv_xy) {
                    poly.push_back(pv);
                    pv = {};
                    pv_xy = false;
                }
                have = false;
                continue;
            }
            if (value == "SEQEND" && mode == Mode::Polyline) {
                flush_poly();
                continue;
            }
            flush_ent();
            if (value == "LINE") {
                cur.kind = DxfEntity::Kind::Line;
                have = true;
                mode = Mode::Entity;
            } else if (value == "CIRCLE") {
                cur.kind = DxfEntity::Kind::Circle;
                have = true;
                mode = Mode::Entity;
            } else if (value == "ARC") {
                cur.kind = DxfEntity::Kind::Arc;
                have = true;
                mode = Mode::Entity;
            } else if (value == "ELLIPSE") {
                cur.kind = DxfEntity::Kind::Ellipse;
                have = true;
                mode = Mode::Entity;
            } else if (value == "SPLINE") {
                cur.kind = DxfEntity::Kind::Spline;
                have = true;
                mode = Mode::Entity;
            } else if (value == "LWPOLYLINE") {
                mode = Mode::LwPoly;
                poly.clear();
                pv = {};
                pv_xy = false;
                poly_closed = false;
                have = false;
            } else if (value == "POLYLINE") {
                mode = Mode::Polyline;
                poly.clear();
                pv = {};
                pv_xy = false;
                poly_closed = false;
                have = false;
            } else if (value != "SEQEND" && value != "VERTEX" && !is_known_entity(value) &&
                       value != "ENDSEC" && value != "EOF") {
                skipped.insert(value);
                mode = Mode::None;
            }
            continue;
        }
        if (mode == Mode::LwPoly || (mode == Mode::Polyline && (code == 10 || code == 20 ||
                                                               code == 42 || code == 70))) {
            if (mode == Mode::LwPoly && code == 10) {
                if (pv_xy) {
                    poly.push_back(pv);
                    pv = {};
                    pv_xy = false;
                }
                pv.x = std::stod(value);
            } else if (code == 10) {
                pv.x = std::stod(value);
            } else if (code == 20) {
                pv.y = std::stod(value);
                pv_xy = true;
            } else if (code == 42) {
                pv.bulge = std::stod(value);
            } else if (code == 70) {
                try {
                    const int fl = std::stoi(value);
                    if (fl & 1) poly_closed = true;
                } catch (...) {
                }
            }
            continue;
        }
        if (!have) continue;
        switch (code) {
            case 10:
                if (cur.kind == DxfEntity::Kind::Spline) {
                    cur.points.push_back({std::stod(value), 0.0});
                } else {
                    cur.x1 = std::stod(value);
                    cur.cx = cur.x1;
                }
                break;
            case 20:
                if (cur.kind == DxfEntity::Kind::Spline && !cur.points.empty()) {
                    cur.points.back()[1] = std::stod(value);
                } else {
                    cur.y1 = std::stod(value);
                    cur.cy = cur.y1;
                }
                break;
            case 11:
                cur.x2 = std::stod(value);
                cur.major_x = cur.x2;
                break;
            case 21:
                cur.y2 = std::stod(value);
                cur.major_y = cur.y2;
                break;
            case 40:
                cur.radius = std::stod(value);
                cur.ratio = cur.radius;
                break;
            case 41:
                cur.param_start = std::stod(value);
                break;
            case 42:
                cur.param_end = std::stod(value);
                break;
            case 50:
                cur.start_angle = std::stod(value);
                break;
            case 51:
                cur.end_angle = std::stod(value);
                break;
            case 71:
                try {
                    cur.degree = std::stoi(value);
                } catch (...) {
                }
                break;
            default:
                break;
        }
    }
    if (mode == Mode::LwPoly || mode == Mode::Polyline) flush_poly();
    flush_ent();
    if (refused) {
        refused->assign(skipped.begin(), skipped.end());
    }
    if (out.empty() && err) {
        if (!skipped.empty()) {
            std::ostringstream ss;
            ss << "refused: ";
            bool first = true;
            for (const auto& s : skipped) {
                if (!first) ss << ", ";
                first = false;
                ss << s;
            }
            *err = ss.str();
        } else {
            *err = "no LINE/CIRCLE/ARC/ELLIPSE/SPLINE entities in " + path;
        }
    }
    return out;
}

int add_dxf_to_sketch(Sketch& sketch, const std::vector<DxfEntity>& entities) {
    int n = 0;
    for (const auto& e : entities) {
        if (e.kind == DxfEntity::Kind::Line) {
            sketch.add_line(e.x1, e.y1, e.x2, e.y2);
            ++n;
        } else if (e.kind == DxfEntity::Kind::Circle) {
            sketch.add_circle(e.cx, e.cy, e.radius);
            ++n;
        } else if (e.kind == DxfEntity::Kind::Arc) {
            const double s = e.start_angle * kPi / 180.0;
            const double t = e.end_angle * kPi / 180.0;
            sketch.add_arc(e.cx, e.cy, e.radius, s, t);
            ++n;
        } else if (e.kind == DxfEntity::Kind::Ellipse) {
            const double rx = std::hypot(e.major_x, e.major_y);
            const double ry = rx * (e.ratio > 0.0 ? e.ratio : 1.0);
            const double ang = std::atan2(e.major_y, e.major_x);
            const bool full = std::abs(e.param_end - e.param_start - kTwoPi) < 1e-6 ||
                              (std::abs(e.param_start) < 1e-9 && std::abs(e.param_end) < 1e-9) ||
                              (std::abs(e.param_start) < 1e-9 && std::abs(e.param_end - kTwoPi) < 1e-6);
            if (full) {
                sketch.add_ellipse(e.cx, e.cy, rx, ry, ang);
            } else {
                sketch.add_elliptical_arc(e.cx, e.cy, rx, ry, ang, e.param_start, e.param_end);
            }
            ++n;
        } else if (e.kind == DxfEntity::Kind::Spline && e.points.size() >= 2) {
            sketch.add_spline(e.points);
            ++n;
        }
    }
    return n;
}

EntityId import_dxf_sketch(Document& doc, const std::string& path, std::string* err) {
    std::vector<std::string> refused;
    auto ents = read_dxf(path, err, &refused);
    if (ents.empty()) return {};
    auto sk = std::make_shared<Sketch>("DXF");
    if (add_dxf_to_sketch(*sk, ents) == 0) {
        if (err) {
            if (!refused.empty()) {
                std::ostringstream ss;
                ss << "refused: ";
                for (size_t i = 0; i < refused.size(); ++i) {
                    if (i) ss << ", ";
                    ss << refused[i];
                }
                *err = ss.str();
            } else {
                *err = "DXF produced no sketch entities";
            }
        }
        return {};
    }
    Feature f;
    f.type = FeatureType::Sketch;
    f.name = "DXF";
    f.sketch = std::move(sk);
    return doc.graph().add(std::move(f));
}

bool write_dxf(const std::vector<DxfEntity>& entities, const std::string& path, std::string* err) {
    std::ofstream out(path);
    if (!out) {
        if (err) *err = "cannot write DXF " + path;
        return false;
    }
    out << std::setprecision(17);
    auto pair = [&](int code, const std::string& v) { out << code << "\n" << v << "\n"; };
    auto num = [&](int code, double v) { out << code << "\n" << v << "\n"; };
    pair(0, "SECTION");
    pair(2, "ENTITIES");
    for (const auto& e : entities) {
        if (e.kind == DxfEntity::Kind::Line) {
            pair(0, "LINE");
            pair(8, "0");
            num(10, e.x1);
            num(20, e.y1);
            num(11, e.x2);
            num(21, e.y2);
        } else if (e.kind == DxfEntity::Kind::Circle) {
            pair(0, "CIRCLE");
            pair(8, "0");
            num(10, e.cx);
            num(20, e.cy);
            num(40, e.radius);
        } else if (e.kind == DxfEntity::Kind::Arc) {
            pair(0, "ARC");
            pair(8, "0");
            num(10, e.cx);
            num(20, e.cy);
            num(40, e.radius);
            num(50, e.start_angle);
            num(51, e.end_angle);
        } else if (e.kind == DxfEntity::Kind::Ellipse) {
            pair(0, "ELLIPSE");
            pair(8, "0");
            num(10, e.cx);
            num(20, e.cy);
            num(11, e.major_x);
            num(21, e.major_y);
            num(40, e.ratio);
            num(41, e.param_start);
            num(42, e.param_end);
        } else if (e.kind == DxfEntity::Kind::Spline) {
            pair(0, "SPLINE");
            pair(8, "0");
            num(70, 8);  // planar
            num(71, e.degree);
            num(73, static_cast<double>(e.points.size()));
            for (const auto& p : e.points) {
                num(10, p[0]);
                num(20, p[1]);
            }
        }
    }
    pair(0, "ENDSEC");
    pair(0, "EOF");
    return true;
}

bool export_drawing_dxf(const Document& doc, const std::string& path, std::string* err) {
    std::vector<DxfEntity> ents;
    auto add_hlr = [&](const drawings::ViewProjection& v, double ox, double oy) {
        auto add_poly = [&](const drawings::Polyline2& pl) {
            for (size_t i = 1; i < pl.size(); ++i) {
                DxfEntity e;
                e.kind = DxfEntity::Kind::Line;
                e.x1 = pl[i - 1][0] + ox;
                e.y1 = pl[i - 1][1] + oy;
                e.x2 = pl[i][0] + ox;
                e.y2 = pl[i][1] + oy;
                ents.push_back(e);
            }
        };
        for (const auto& pl : v.visible) add_poly(pl);
        for (const auto& pl : v.hidden) add_poly(pl);
    };
    auto add_typed = [&](const TopoDS_Shape& shape, const gp_Dir& dir, const gp_Dir& up, double ox,
                         double oy) {
        for (auto e : typed_from_shape(shape, dir, up)) {
            if (e.kind == DxfEntity::Kind::Line) {
                e.x1 += ox;
                e.y1 += oy;
                e.x2 += ox;
                e.y2 += oy;
            } else {
                e.cx += ox;
                e.cy += oy;
                if (e.kind == DxfEntity::Kind::Spline) {
                    for (auto& p : e.points) {
                        p[0] += ox;
                        p[1] += oy;
                    }
                }
            }
            ents.push_back(e);
        }
    };
    auto compound_all = [&]() {
        TopoDS_Compound comp;
        BRep_Builder builder;
        builder.MakeCompound(comp);
        int n = 0;
        for (const auto& id : doc.body_ids()) {
            const Body* b = doc.body(id);
            if (!b || b->shape.IsNull()) continue;
            builder.Add(comp, b->shape);
            ++n;
        }
        return std::pair<TopoDS_Compound, int>{comp, n};
    };

    if (!doc.drawing_sheets().empty()) {
        for (const auto& view : doc.drawing_sheets().front().views) {
            gp_Dir dir(view.dir[0], view.dir[1], view.dir[2]);
            gp_Dir up(view.up[0], view.up[1], view.up[2]);
            add_hlr(project_drawing_view(doc, view), view.offset_x, view.offset_y);
            auto [comp, n] = compound_all();
            if (n > 0) add_typed(comp, dir, up, view.offset_x, view.offset_y);
        }
    } else {
        auto [comp, n] = compound_all();
        if (n == 0) {
            if (err) *err = "empty document";
            return false;
        }
        const gp_Dir dir(0, 1, 0);
        const gp_Dir up(0, 0, 1);
        add_hlr(drawings::project(comp, dir, up), 0, 0);
        add_typed(comp, dir, up, 0, 0);
    }
    if (ents.empty()) {
        if (err) *err = "drawing produced no entities";
        return false;
    }
    return write_dxf(ents, path, err);
}

}  // namespace sx
