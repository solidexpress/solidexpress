#include "sx/sketch_tools.hpp"

#include <algorithm>
#include <cmath>
#include <optional>
#include <unordered_map>
#include <utility>
#include <vector>

namespace sx::sketch_tools {
namespace {

constexpr double k_eps = 1e-6;
constexpr double k_pi = 3.14159265358979323846;
constexpr double k_two_pi = 2.0 * k_pi;

struct Vec2 {
    double x = 0, y = 0;
};

double dot(Vec2 a, Vec2 b) { return a.x * b.x + a.y * b.y; }
double cross(Vec2 a, Vec2 b) { return a.x * b.y - a.y * b.x; }
double hypot2(Vec2 v) { return std::hypot(v.x, v.y); }

Vec2 sub(Vec2 a, Vec2 b) { return {a.x - b.x, a.y - b.y}; }
Vec2 add(Vec2 a, Vec2 b) { return {a.x + b.x, a.y + b.y}; }
Vec2 mul(Vec2 a, double s) { return {a.x * s, a.y * s}; }

Vec2 unit(Vec2 v) {
    double len = hypot2(v);
    if (len < 1e-15) return {0, 0};
    return {v.x / len, v.y / len};
}

Vec2 line_end(const Sketch& s, const SketchEntity& e, PointRole role) {
    auto p = s.point_pos({e.id, role});
    return {(*p)[0], (*p)[1]};
}

void set_line_end(Sketch& s, const SketchEntity& e, PointRole role, Vec2 p) {
    if (role == PointRole::Start) {
        s.param_mut(e.params[0]) = p.x;
        s.param_mut(e.params[1]) = p.y;
    } else {
        s.param_mut(e.params[2]) = p.x;
        s.param_mut(e.params[3]) = p.y;
    }
}

// Line-line: parameter t on segment A in (0,1) if segments properly intersect.
std::optional<double> line_line_intersect_t(Vec2 a0, Vec2 a1, Vec2 b0, Vec2 b1) {
    Vec2 da = sub(a1, a0);
    Vec2 db = sub(b1, b0);
    double den = cross(da, db);
    if (std::abs(den) < 1e-15) return std::nullopt;  // parallel / degenerate
    Vec2 ab = sub(b0, a0);
    double t = cross(ab, db) / den;
    double u = cross(ab, da) / den;
    if (t <= k_eps || t >= 1.0 - k_eps || u <= k_eps || u >= 1.0 - k_eps)
        return std::nullopt;
    return t;
}

// Line-circle: parameters t in (0,1) where the segment meets the circle.
std::vector<double> line_circle_intersect_t(Vec2 a0, Vec2 a1, Vec2 c, double r) {
    std::vector<double> out;
    if (r <= 0) return out;
    Vec2 d = sub(a1, a0);
    Vec2 f = sub(a0, c);
    double A = dot(d, d);
    if (A < 1e-30) return out;
    double B = 2.0 * dot(f, d);
    double C = dot(f, f) - r * r;
    double disc = B * B - 4.0 * A * C;
    if (disc < -k_eps) return out;
    if (disc < 0) disc = 0;
    double sqrt_d = std::sqrt(disc);
    for (double sign : {-1.0, 1.0}) {
        double t = (-B + sign * sqrt_d) / (2.0 * A);
        if (t > k_eps && t < 1.0 - k_eps) out.push_back(t);
    }
    // Deduplicate near-tangent double root.
    if (out.size() == 2 && std::abs(out[0] - out[1]) < k_eps) out.pop_back();
    return out;
}

// Circle-circle: angles on circle A for proper intersection points.
std::vector<double> circle_circle_intersect_angles(Vec2 ca, double ra, Vec2 cb,
                                                   double rb) {
    std::vector<double> out;
    if (ra <= 0 || rb <= 0) return out;
    Vec2 d = sub(cb, ca);
    double dist = hypot2(d);
    if (dist < 1e-15) return out;  // coincident centers
    if (dist > ra + rb + k_eps || dist < std::abs(ra - rb) - k_eps) return out;

    double a = (ra * ra - rb * rb + dist * dist) / (2.0 * dist);
    double h2 = ra * ra - a * a;
    if (h2 < -k_eps) return out;
    if (h2 < 0) h2 = 0;
    double h = std::sqrt(h2);
    Vec2 p = add(ca, mul(d, a / dist));
    Vec2 perp = {-d.y / dist * h, d.x / dist * h};

    auto push_ang = [&](Vec2 pt) {
        double ang = std::atan2(pt.y - ca.y, pt.x - ca.x);
        out.push_back(ang);
    };
    if (h < k_eps) {
        push_ang(p);  // tangent
    } else {
        push_ang(add(p, perp));
        push_ang(sub(p, perp));
    }
    return out;
}

void unique_sorted(std::vector<double>& v) {
    std::sort(v.begin(), v.end());
    auto last = v.begin();
    for (auto it = v.begin(); it != v.end(); ++it) {
        if (last == v.begin() || std::abs(*it - *(last - 1)) > k_eps) {
            *last++ = *it;
        }
    }
    v.erase(last, v.end());
}

double normalize_angle(double a) {
    while (a < 0) a += k_two_pi;
    while (a >= k_two_pi) a -= k_two_pi;
    return a;
}

// Inclusive CCW sweep from sa to ea (empty span means a full turn).
bool angle_on_ccw(double ang, double sa, double ea) {
    double from = normalize_angle(ang - sa);
    double span = normalize_angle(ea - sa);
    if (span < k_eps) span = k_two_pi;
    return from <= span + k_eps;
}

struct EllipseAxes {
    double cx = 0, cy = 0, rx = 0, ry = 0, ang = 0;
};

std::optional<EllipseAxes> axes_of(const Sketch& s, const SketchEntity& e) {
    auto ax = s.ellipse_axes(e.id);
    if (!ax) return std::nullopt;
    return EllipseAxes{(*ax)[0], (*ax)[1], (*ax)[2], (*ax)[3], (*ax)[4]};
}

Vec2 ellipse_xy(const EllipseAxes& a, double t) {
    const double ca = std::cos(a.ang), sa = std::sin(a.ang);
    const double u = a.rx * std::cos(t), v = a.ry * std::sin(t);
    return {a.cx + u * ca - v * sa, a.cy + u * sa + v * ca};
}

double ellipse_param(const EllipseAxes& a, Vec2 p) {
    const double ca = std::cos(a.ang), sa = std::sin(a.ang);
    const double dx = p.x - a.cx, dy = p.y - a.cy;
    const double xl = dx * ca + dy * sa;
    const double yl = -dx * sa + dy * ca;
    return std::atan2(yl / a.ry, xl / a.rx);
}

bool point_on_ellipse(const EllipseAxes& a, Vec2 p) {
    if (a.rx < k_eps || a.ry < k_eps) return false;
    Vec2 q = ellipse_xy(a, ellipse_param(a, p));
    return hypot2(sub(p, q)) < 0.05;
}

// Line vs ellipse: parameters t on segment A. inclusive includes the ends.
std::vector<double> line_ellipse_intersect_t(Vec2 a0, Vec2 a1, const EllipseAxes& el,
                                             bool inclusive) {
    std::vector<double> out;
    if (el.rx < k_eps || el.ry < k_eps) return out;
    const double ca = std::cos(el.ang), sa = std::sin(el.ang);
    auto to_local = [&](Vec2 p) {
        double dx = p.x - el.cx, dy = p.y - el.cy;
        return Vec2{dx * ca + dy * sa, -dx * sa + dy * ca};
    };
    Vec2 p0 = to_local(a0);
    Vec2 d = sub(to_local(a1), p0);
    const double rx2 = el.rx * el.rx, ry2 = el.ry * el.ry;
    const double A = (d.x * d.x) / rx2 + (d.y * d.y) / ry2;
    const double B = 2.0 * (p0.x * d.x / rx2 + p0.y * d.y / ry2);
    const double C = (p0.x * p0.x) / rx2 + (p0.y * p0.y) / ry2 - 1.0;
    if (A < 1e-30) return out;
    double disc = B * B - 4.0 * A * C;
    if (disc < -k_eps) return out;
    if (disc < 0) disc = 0;
    const double sqrt_d = std::sqrt(disc);
    const double lo = inclusive ? -k_eps : k_eps;
    const double hi = inclusive ? 1.0 + k_eps : 1.0 - k_eps;
    for (double sign : {-1.0, 1.0}) {
        double t = (-B + sign * sqrt_d) / (2.0 * A);
        if (t > lo && t < hi) out.push_back(std::clamp(t, 0.0, 1.0));
    }
    if (out.size() == 2 && std::abs(out[0] - out[1]) < k_eps) out.pop_back();
    return out;
}

Vec2 ellipse_tangent(const EllipseAxes& a, double t) {
    const double ca = std::cos(a.ang), sa = std::sin(a.ang);
    const double du = -a.rx * std::sin(t), dv = a.ry * std::cos(t);
    return {du * ca - dv * sa, du * sa + dv * ca};
}

// Ellipse vs circle: ellipse parameters t at the hits. Newton on sign changes
// of |p(t) − c|² − r², sampled around the turn.
std::vector<double> ellipse_circle_intersect_params(const EllipseAxes& el, Vec2 c,
                                                    double r) {
    std::vector<double> out;
    if (r <= k_eps || el.rx < k_eps || el.ry < k_eps) return out;
    auto f = [&](double t) {
        Vec2 p = ellipse_xy(el, t);
        double dx = p.x - c.x, dy = p.y - c.y;
        return dx * dx + dy * dy - r * r;
    };
    auto df = [&](double t) {
        Vec2 p = ellipse_xy(el, t);
        Vec2 d = ellipse_tangent(el, t);
        return 2.0 * ((p.x - c.x) * d.x + (p.y - c.y) * d.y);
    };
    const int n = 72;
    double prev_t = 0.0;
    double prev_f = f(0.0);
    auto push_root = [&](double t) {
        t = normalize_angle(t);
        for (double a : out) {
            double d = std::abs(t - a);
            if (d < 1e-3 || std::abs(d - k_two_pi) < 1e-3) return;
        }
        if (std::abs(f(t)) > 1e-3 * std::max(1.0, r * r)) return;
        out.push_back(t);
    };
    if (std::abs(prev_f) < 1e-9) push_root(0.0);
    for (int i = 1; i <= n; ++i) {
        double t = k_two_pi * static_cast<double>(i) / n;
        double fv = f(t);
        if (fv * prev_f < 0.0 || std::abs(fv) < 1e-9) {
            double x = 0.5 * (prev_t + t);
            for (int k = 0; k < 16; ++k) {
                double d = df(x);
                if (std::abs(d) < 1e-18) break;
                x -= f(x) / d;
            }
            push_root(x);
        }
        prev_t = t;
        prev_f = fv;
    }
    return out;
}

// Solid cutters first. Construction fills in only while fewer than two solid
// hits exist: a real crossing is unchanged, and a construction-only corner
// can still trim.
void merge_construction_hits(std::vector<double>& solid, std::vector<double>& construction) {
    unique_sorted(solid);
    if (solid.size() >= 2) return;
    unique_sorted(construction);
    solid.insert(solid.end(), construction.begin(), construction.end());
    unique_sorted(solid);
}

bool collect_line_intersections(const Sketch& s, const SketchEntity& line,
                                EntityId self_id, std::vector<double>& ts) {
    Vec2 a0 = line_end(s, line, PointRole::Start);
    Vec2 a1 = line_end(s, line, PointRole::End);
    std::vector<double> solid;
    std::vector<double> construction;
    for (const SketchEntity& other : s.entities()) {
        if (other.id == self_id) continue;
        std::vector<double> hits;
        if (other.type == SketchEntityType::Line) {
            Vec2 b0 = line_end(s, other, PointRole::Start);
            Vec2 b1 = line_end(s, other, PointRole::End);
            if (auto t = line_line_intersect_t(a0, a1, b0, b1)) hits.push_back(*t);
        } else if (other.type == SketchEntityType::Circle) {
            Vec2 c = {s.param(other.params[0]), s.param(other.params[1])};
            double r = s.param(other.params[2]);
            hits = line_circle_intersect_t(a0, a1, c, r);
        } else if (other.type == SketchEntityType::Arc && other.params.size() >= 9) {
            Vec2 c = {s.param(other.params[0]), s.param(other.params[1])};
            double r = s.param(other.params[2]);
            Vec2 ps = {s.param(other.params[5]), s.param(other.params[6])};
            Vec2 pe = {s.param(other.params[7]), s.param(other.params[8])};
            double sa = std::atan2(ps.y - c.y, ps.x - c.x);
            double ea = std::atan2(pe.y - c.y, pe.x - c.x);
            Vec2 d = sub(a1, a0);
            double len2 = dot(d, d);
            auto push_if_on_line = [&](Vec2 p) {
                if (len2 < 1e-30) return;
                double t = dot(sub(p, a0), d) / len2;
                if (t <= k_eps || t >= 1.0 - k_eps) return;
                Vec2 proj = add(a0, mul(d, t));
                if (hypot2(sub(proj, p)) > 1e-3) return;
                hits.push_back(t);
            };
            for (double t : line_circle_intersect_t(a0, a1, c, r)) {
                Vec2 p = add(a0, mul(d, t));
                double ang = std::atan2(p.y - c.y, p.x - c.x);
                if (angle_on_ccw(ang, sa, ea)) hits.push_back(t);
            }
            push_if_on_line(ps);
            push_if_on_line(pe);
        } else if (other.type == SketchEntityType::Ellipse ||
                   other.type == SketchEntityType::EllipticalArc) {
            auto ax = axes_of(s, other);
            if (!ax) continue;
            Vec2 d = sub(a1, a0);
            double len2 = dot(d, d);
            auto push_if_on_line = [&](Vec2 p) {
                if (len2 < 1e-30) return;
                double t = dot(sub(p, a0), d) / len2;
                if (t <= k_eps || t >= 1.0 - k_eps) return;
                Vec2 proj = add(a0, mul(d, t));
                if (hypot2(sub(proj, p)) > 1e-3) return;
                hits.push_back(t);
            };
            auto on_span = [&](double t_ell) {
                if (other.type != SketchEntityType::EllipticalArc || other.params.size() < 7)
                    return true;
                return angle_on_ccw(t_ell, s.param(other.params[5]), s.param(other.params[6]));
            };
            for (double t : line_ellipse_intersect_t(a0, a1, *ax, false)) {
                Vec2 p = add(a0, mul(d, t));
                if (on_span(ellipse_param(*ax, p))) hits.push_back(t);
            }
            if (other.type == SketchEntityType::EllipticalArc && other.params.size() >= 11) {
                push_if_on_line({s.param(other.params[7]), s.param(other.params[8])});
                push_if_on_line({s.param(other.params[9]), s.param(other.params[10])});
            }
        }
        auto& dest = other.construction ? construction : solid;
        dest.insert(dest.end(), hits.begin(), hits.end());
    }
    merge_construction_hits(solid, construction);
    ts = std::move(solid);
    return !ts.empty();
}

bool collect_circle_intersections(const Sketch& s, const SketchEntity& circ,
                                  EntityId self_id, std::vector<double>& angs) {
    Vec2 c = {s.param(circ.params[0]), s.param(circ.params[1])};
    double r = s.param(circ.params[2]);
    std::vector<double> solid;
    std::vector<double> construction;
    for (const SketchEntity& other : s.entities()) {
        if (other.id == self_id) continue;
        std::vector<double> hits;
        if (other.type == SketchEntityType::Line) {
            Vec2 a0 = line_end(s, other, PointRole::Start);
            Vec2 a1 = line_end(s, other, PointRole::End);
            for (double t : line_circle_intersect_t(a0, a1, c, r)) {
                Vec2 p = add(a0, mul(sub(a1, a0), t));
                hits.push_back(std::atan2(p.y - c.y, p.x - c.x));
            }
        } else if (other.type == SketchEntityType::Circle) {
            Vec2 oc = {s.param(other.params[0]), s.param(other.params[1])};
            double or_ = s.param(other.params[2]);
            hits = circle_circle_intersect_angles(c, r, oc, or_);
        } else if (other.type == SketchEntityType::Ellipse ||
                   other.type == SketchEntityType::EllipticalArc) {
            auto ax = axes_of(s, other);
            if (ax) {
                auto on_span = [&](double t_ell) {
                    if (other.type != SketchEntityType::EllipticalArc ||
                        other.params.size() < 7)
                        return true;
                    return angle_on_ccw(t_ell, s.param(other.params[5]),
                                        s.param(other.params[6]));
                };
                for (double t : ellipse_circle_intersect_params(*ax, c, r)) {
                    if (!on_span(t)) continue;
                    Vec2 p = ellipse_xy(*ax, t);
                    hits.push_back(std::atan2(p.y - c.y, p.x - c.x));
                }
            }
        }
        auto& dest = other.construction ? construction : solid;
        dest.insert(dest.end(), hits.begin(), hits.end());
    }
    for (double& a : solid) a = normalize_angle(a);
    for (double& a : construction) a = normalize_angle(a);
    merge_construction_hits(solid, construction);
    angs = std::move(solid);
    return angs.size() >= 2;
}

bool trim_line(Sketch& s, EntityId id, double px, double py) {
    const SketchEntity* e = s.entity(id);
    if (!e || e->type != SketchEntityType::Line) return false;

    Vec2 a0 = line_end(s, *e, PointRole::Start);
    Vec2 a1 = line_end(s, *e, PointRole::End);
    Vec2 d = sub(a1, a0);
    double len2 = dot(d, d);
    if (len2 < 1e-30) return false;

    std::vector<double> ts;
    if (!collect_line_intersections(s, *e, id, ts)) return false;

    double t_pick = dot(sub({px, py}, a0), d) / len2;
    t_pick = std::clamp(t_pick, 0.0, 1.0);

    // Sub-segments: [0, t0], [t0, t1], ..., [tn-1, 1]. Find one containing pick.
    double lo = 0.0;
    double hi = ts[0];
    size_t seg = 0;  // 0 = first end, ts.size() = last end, else interior
    for (size_t i = 0; i <= ts.size(); ++i) {
        lo = (i == 0) ? 0.0 : ts[i - 1];
        hi = (i == ts.size()) ? 1.0 : ts[i];
        if (t_pick >= lo - k_eps && t_pick <= hi + k_eps) {
            seg = i;
            break;
        }
    }

    auto at_t = [&](double t) { return add(a0, mul(d, t)); };

    if (seg == 0) {
        // Trim start end-segment: move start to first intersection.
        set_line_end(s, *e, PointRole::Start, at_t(ts[0]));
        return true;
    }
    if (seg == ts.size()) {
        // Trim end end-segment: move end to last intersection.
        set_line_end(s, *e, PointRole::End, at_t(ts.back()));
        return true;
    }

    // Interior: replace with two lines [0, lo] and [hi, 1].
    Vec2 p_lo = at_t(lo);
    Vec2 p_hi = at_t(hi);
    s.remove_entity(id);
    s.add_line(a0.x, a0.y, p_lo.x, p_lo.y);
    s.add_line(p_hi.x, p_hi.y, a1.x, a1.y);
    return true;
}

bool trim_circle(Sketch& s, EntityId id, double px, double py) {
    const SketchEntity* e = s.entity(id);
    if (!e || e->type != SketchEntityType::Circle) return false;

    Vec2 c = {s.param(e->params[0]), s.param(e->params[1])};
    double r = s.param(e->params[2]);
    if (r <= 0) return false;

    std::vector<double> angs;
    if (!collect_circle_intersections(s, *e, id, angs)) return false;

    double pick_ang = normalize_angle(std::atan2(py - c.y, px - c.x));

    // Find consecutive intersection pair (wrapping) whose CCW arc contains pick.
    size_t n = angs.size();
    size_t i_start = 0;  // remaining arc ends at angs[i_start]; starts at next
    bool found = false;
    for (size_t i = 0; i < n; ++i) {
        double a0 = angs[i];
        double a1 = angs[(i + 1) % n];
        double span = (i + 1 < n) ? (a1 - a0) : (a1 + k_two_pi - a0);
        double from_a0 = (pick_ang >= a0) ? (pick_ang - a0) : (pick_ang + k_two_pi - a0);
        if (from_a0 <= span + k_eps) {
            // Remove [a0, a1]; keep from a1 CCW to a0.
            i_start = i;
            found = true;
            break;
        }
    }
    if (!found) return false;

    double rem_start = angs[(i_start + 1) % n];
    double rem_end = angs[i_start];
    // add_arc expects end CCW from start; if rem_end <= rem_start, bump by 2π.
    if (rem_end <= rem_start + k_eps) rem_end += k_two_pi;

    s.remove_entity(id);
    s.add_arc(c.x, c.y, r, rem_start, rem_end);
    return true;
}

bool collect_ellipse_intersections(const Sketch& s, const SketchEntity& ell,
                                   EntityId self_id, std::vector<double>& angs) {
    auto ax = axes_of(s, ell);
    if (!ax) return false;
    std::vector<double> solid;
    std::vector<double> construction;
    auto push_hit = [&](Vec2 p, bool constr) {
        if (!point_on_ellipse(*ax, p)) return;
        (constr ? construction : solid).push_back(normalize_angle(ellipse_param(*ax, p)));
    };
    for (const SketchEntity& other : s.entities()) {
        if (other.id == self_id) continue;
        const bool constr = other.construction;
        if (other.type == SketchEntityType::Line) {
            Vec2 a0 = line_end(s, other, PointRole::Start);
            Vec2 a1 = line_end(s, other, PointRole::End);
            Vec2 d = sub(a1, a0);
            for (double t : line_ellipse_intersect_t(a0, a1, *ax, true)) {
                push_hit(add(a0, mul(d, t)), constr);
            }
            push_hit(a0, constr);
            push_hit(a1, constr);
        } else if (other.type == SketchEntityType::Circle) {
            Vec2 c = {s.param(other.params[0]), s.param(other.params[1])};
            double r = s.param(other.params[2]);
            for (double t : ellipse_circle_intersect_params(*ax, c, r)) {
                push_hit(ellipse_xy(*ax, t), constr);
            }
        } else if (other.type == SketchEntityType::Arc && other.params.size() >= 9) {
            Vec2 c = {s.param(other.params[0]), s.param(other.params[1])};
            double r = s.param(other.params[2]);
            Vec2 ps = {s.param(other.params[5]), s.param(other.params[6])};
            Vec2 pe = {s.param(other.params[7]), s.param(other.params[8])};
            double sa = std::atan2(ps.y - c.y, ps.x - c.x);
            double ea = std::atan2(pe.y - c.y, pe.x - c.x);
            for (double t : ellipse_circle_intersect_params(*ax, c, r)) {
                Vec2 p = ellipse_xy(*ax, t);
                double ang = std::atan2(p.y - c.y, p.x - c.x);
                if (angle_on_ccw(ang, sa, ea)) push_hit(p, constr);
            }
            push_hit(ps, constr);
            push_hit(pe, constr);
        }
    }
    for (double& a : solid) a = normalize_angle(a);
    for (double& a : construction) a = normalize_angle(a);
    merge_construction_hits(solid, construction);
    angs = std::move(solid);
    unique_sorted(angs);
    return angs.size() >= 2;
}

bool trim_ellipse(Sketch& s, EntityId id, double px, double py) {
    const SketchEntity* e = s.entity(id);
    if (!e || e->type != SketchEntityType::Ellipse) return false;
    auto ax = axes_of(s, *e);
    if (!ax) return false;

    std::vector<double> angs;
    if (!collect_ellipse_intersections(s, *e, id, angs)) return false;

    double pick_ang = normalize_angle(ellipse_param(*ax, {px, py}));

    size_t n = angs.size();
    size_t i_start = 0;
    bool found = false;
    for (size_t i = 0; i < n; ++i) {
        double a0 = angs[i];
        double a1 = angs[(i + 1) % n];
        double span = (i + 1 < n) ? (a1 - a0) : (a1 + k_two_pi - a0);
        double from_a0 = (pick_ang >= a0) ? (pick_ang - a0) : (pick_ang + k_two_pi - a0);
        if (from_a0 <= span + k_eps) {
            i_start = i;
            found = true;
            break;
        }
    }
    if (!found) return false;

    double rem_start = angs[(i_start + 1) % n];
    double rem_end = angs[i_start];
    if (rem_end <= rem_start + k_eps) rem_end += k_two_pi;

    s.remove_entity(id);
    s.add_elliptical_arc(ax->cx, ax->cy, ax->rx, ax->ry, ax->ang, rem_start, rem_end);
    return true;
}

}  // namespace

std::string fillet_corner(Sketch& s, const std::string& line_a_id,
                          const std::string& line_b_id, double radius) {
    if (radius <= 0) return "";

    EntityId id_a = EntityId::from_string(line_a_id);
    EntityId id_b = EntityId::from_string(line_b_id);
    const SketchEntity* ea = s.entity(id_a);
    const SketchEntity* eb = s.entity(id_b);
    if (!ea || !eb || ea->type != SketchEntityType::Line ||
        eb->type != SketchEntityType::Line)
        return "";

    Vec2 a0 = line_end(s, *ea, PointRole::Start);
    Vec2 a1 = line_end(s, *ea, PointRole::End);
    Vec2 b0 = line_end(s, *eb, PointRole::Start);
    Vec2 b1 = line_end(s, *eb, PointRole::End);

    // Find shared (or nearly shared) corner and which end of each line it is.
    PointRole role_a = PointRole::Self;
    PointRole role_b = PointRole::Self;
    Vec2 corner{};
    auto try_pair = [&](PointRole ra, Vec2 pa, PointRole rb, Vec2 pb) {
        if (hypot2(sub(pa, pb)) > k_eps) return false;
        role_a = ra;
        role_b = rb;
        corner = mul(add(pa, pb), 0.5);
        return true;
    };
    if (!try_pair(PointRole::Start, a0, PointRole::Start, b0) &&
        !try_pair(PointRole::Start, a0, PointRole::End, b1) &&
        !try_pair(PointRole::End, a1, PointRole::Start, b0) &&
        !try_pair(PointRole::End, a1, PointRole::End, b1))
        return "";

    Vec2 other_a = (role_a == PointRole::Start) ? a1 : a0;
    Vec2 other_b = (role_b == PointRole::Start) ? b1 : b0;
    // Unit directions from the corner along each remaining segment.
    Vec2 ua = unit(sub(other_a, corner));
    Vec2 ub = unit(sub(other_b, corner));
    double len_a = hypot2(sub(other_a, corner));
    double len_b = hypot2(sub(other_b, corner));
    if (hypot2(ua) < 0.5 || hypot2(ub) < 0.5) return "";

    double cos_a = std::clamp(dot(ua, ub), -1.0, 1.0);
    double alpha = std::acos(cos_a);
    // Parallel / anti-parallel / degenerate wedge — no unique fillet.
    if (alpha < k_eps || alpha > k_pi - k_eps) return "";

    // Trim distance along each arm: r / tan(α/2).
    double half = alpha * 0.5;
    double trim = radius / std::tan(half);
    if (trim > len_a + k_eps || trim > len_b + k_eps) return "";

    Vec2 trim_a = add(corner, mul(ua, trim));
    Vec2 trim_b = add(corner, mul(ub, trim));

    // Center lies along the angle bisector at distance r / sin(α/2).
    Vec2 bis = unit(add(ua, ub));
    if (hypot2(bis) < 0.5) return "";
    Vec2 center = add(corner, mul(bis, radius / std::sin(half)));

    double ang_a = std::atan2(trim_a.y - center.y, trim_a.x - center.x);
    double ang_b = std::atan2(trim_b.y - center.y, trim_b.x - center.x);
    // Fillet central angle is π − α (< π). Prefer the CCW sweep matching that.
    double expected = k_pi - alpha;
    double ccw = ang_b - ang_a;
    while (ccw < 0) ccw += 2.0 * k_pi;
    while (ccw >= 2.0 * k_pi) ccw -= 2.0 * k_pi;
    double start_ang = ang_a;
    double end_ang = ang_b;
    PointRole arc_start_role_line = role_a;
    PointRole arc_end_role_line = role_b;
    EntityId line_for_start = id_a;
    EntityId line_for_end = id_b;
    if (std::abs(ccw - expected) > std::abs((2.0 * k_pi - ccw) - expected)) {
        start_ang = ang_b;
        end_ang = ang_a;
        arc_start_role_line = role_b;
        arc_end_role_line = role_a;
        line_for_start = id_b;
        line_for_end = id_a;
    }
    // Normalize so end is CCW from start (possibly end < start in (-π, π] form).
    while (end_ang < start_ang) end_ang += 2.0 * k_pi;

    set_line_end(s, *ea, role_a, trim_a);
    set_line_end(s, *eb, role_b, trim_b);

    EntityId arc = s.add_arc(center.x, center.y, radius, start_ang, end_ang);

    s.add_constraint(ConstraintType::Coincident,
                     {{arc, PointRole::Start}, {line_for_start, arc_start_role_line}});
    s.add_constraint(ConstraintType::Coincident,
                     {{arc, PointRole::End}, {line_for_end, arc_end_role_line}});

    return arc.str();
}

namespace {

using Offsetter = bool (*)(Sketch&, const SketchEntity&, EntityId, double,
                           std::vector<std::string>&);

bool offset_line(Sketch& s, const SketchEntity& e, EntityId id, double distance,
                 std::vector<std::string>& out) {
    double x1 = s.param(e.params[0]);
    double y1 = s.param(e.params[1]);
    double x2 = s.param(e.params[2]);
    double y2 = s.param(e.params[3]);
    Vec2 dir = {x2 - x1, y2 - y1};
    double len = hypot2(dir);
    if (len < 1e-15) return false;
    // Left normal of the direction vector.
    Vec2 n = {-dir.y / len, dir.x / len};
    Vec2 o = mul(n, distance);
    EntityId nid = s.add_line(x1 + o.x, y1 + o.y, x2 + o.x, y2 + o.y);
    s.add_constraint(ConstraintType::Parallel,
                     {{nid, PointRole::Self}, {id, PointRole::Self}});
    // Both ends, otherwise Parallel + one P2LDistance lets the copy slide
    // along the source and open the offset chain at the corners.
    s.add_constraint(ConstraintType::Distance,
                     {{nid, PointRole::Start}, {id, PointRole::Self}}, std::abs(distance), true);
    s.add_constraint(ConstraintType::Distance,
                     {{nid, PointRole::End}, {id, PointRole::Self}}, std::abs(distance), true);
    out.push_back(nid.str());
    return true;
}

bool offset_circle(Sketch& s, const SketchEntity& e, EntityId id, double distance,
                   std::vector<std::string>& out) {
    double cx = s.param(e.params[0]);
    double cy = s.param(e.params[1]);
    double r = s.param(e.params[2]);
    double nr = r + distance;
    if (nr <= k_eps) return false;
    EntityId nid = s.add_circle(cx, cy, nr);
    s.add_constraint(ConstraintType::Concentric,
                     {{nid, PointRole::Center}, {id, PointRole::Center}});
    // Radial Δ relation: copy.r − source.r = distance (associative).
    s.add_constraint(ConstraintType::Distance,
                     {{nid, PointRole::Self}, {id, PointRole::Self}}, distance, true);
    s.add_constraint(ConstraintType::Diameter, {{nid, PointRole::Self}}, nr * 2.0, false);
    out.push_back(nid.str());
    return true;
}

bool offset_arc(Sketch& s, const SketchEntity& e, EntityId id, double distance,
                std::vector<std::string>& out) {
    if (e.params.size() < 5) return false;
    double cx = s.param(e.params[0]);
    double cy = s.param(e.params[1]);
    double r = s.param(e.params[2]);
    double sa = s.param(e.params[3]);
    double ea = s.param(e.params[4]);
    double nr = r + distance;
    if (nr <= k_eps) return false;
    EntityId nid = s.add_arc(cx, cy, nr, sa, ea);
    s.add_constraint(ConstraintType::Concentric,
                     {{nid, PointRole::Center}, {id, PointRole::Center}});
    s.add_constraint(ConstraintType::Distance,
                     {{nid, PointRole::Self}, {id, PointRole::Self}}, distance, true);
    s.add_constraint(ConstraintType::Radius, {{nid, PointRole::Self}}, nr, false);
    out.push_back(nid.str());
    return true;
}

const std::unordered_map<SketchEntityType, Offsetter> kOffsetters = {
    {SketchEntityType::Line, offset_line},
    {SketchEntityType::Circle, offset_circle},
    {SketchEntityType::Arc, offset_arc},
};

bool near_uv(Vec2 a, Vec2 b) { return hypot2(sub(a, b)) <= 0.05; }

struct ChainEnd {
    EntityId id;
    PointRole role;
    Vec2 p;
};

std::vector<ChainEnd> chain_ends(const Sketch& s, EntityId id) {
    const SketchEntity* e = s.entity(id);
    if (!e) return {};
    if (e->type != SketchEntityType::Line && e->type != SketchEntityType::Arc) return {};
    auto a = s.point_pos({id, PointRole::Start});
    auto b = s.point_pos({id, PointRole::End});
    if (!a || !b) return {};
    return {{id, PointRole::Start, {(*a)[0], (*a)[1]}},
            {id, PointRole::End, {(*b)[0], (*b)[1]}}};
}

// Copies of a connected source chain inherit Coincident at the corners so
// PlaneGCS cannot slide the parallels apart after Offset.
void weld_offset_copies(Sketch& s, const std::vector<std::pair<EntityId, EntityId>>& pairs) {
    for (size_t i = 0; i < pairs.size(); ++i) {
        auto src_i = chain_ends(s, pairs[i].first);
        auto copy_i = chain_ends(s, pairs[i].second);
        if (src_i.size() != 2 || copy_i.size() != 2) continue;
        for (size_t j = i + 1; j < pairs.size(); ++j) {
            auto src_j = chain_ends(s, pairs[j].first);
            auto copy_j = chain_ends(s, pairs[j].second);
            if (src_j.size() != 2 || copy_j.size() != 2) continue;
            for (int a = 0; a < 2; ++a) {
                for (int b = 0; b < 2; ++b) {
                    if (!near_uv(src_i[static_cast<size_t>(a)].p,
                                 src_j[static_cast<size_t>(b)].p))
                        continue;
                    s.add_constraint(ConstraintType::Coincident,
                                     {{copy_i[static_cast<size_t>(a)].id,
                                       copy_i[static_cast<size_t>(a)].role},
                                      {copy_j[static_cast<size_t>(b)].id,
                                       copy_j[static_cast<size_t>(b)].role}});
                }
            }
        }
    }
}

}  // namespace

std::vector<std::string> offset_entities(Sketch& s,
                                         const std::vector<std::string>& entity_ids,
                                         double distance) {
    std::vector<std::string> out;
    if (std::abs(distance) <= k_eps) return out;
    out.reserve(entity_ids.size());
    std::vector<std::pair<EntityId, EntityId>> copies;

    for (const std::string& sid : entity_ids) {
        EntityId id = EntityId::from_string(sid);
        const SketchEntity* e = s.entity(id);
        if (!e) continue;
        const auto it = kOffsetters.find(e->type);
        if (it == kOffsetters.end()) continue;
        const size_t before = out.size();
        it->second(s, *e, id, distance, out);
        if (out.size() > before)
            copies.push_back({id, EntityId::from_string(out.back())});
    }
    weld_offset_copies(s, copies);
    return out;
}

bool trim_entity(Sketch& s, const std::string& entity_id, double px, double py) {
    EntityId id = EntityId::from_string(entity_id);
    const SketchEntity* e = s.entity(id);
    if (!e) return false;
    if (e->type == SketchEntityType::Line) return trim_line(s, id, px, py);
    if (e->type == SketchEntityType::Circle) return trim_circle(s, id, px, py);
    if (e->type == SketchEntityType::Ellipse) return trim_ellipse(s, id, px, py);
    return false;
}

namespace {

// Line A unrestricted vs segment B (u in [0,1]): return t on A if they meet.
std::optional<double> line_seg_intersect_t(Vec2 a0, Vec2 a1, Vec2 b0, Vec2 b1) {
    Vec2 da = sub(a1, a0);
    Vec2 db = sub(b1, b0);
    double den = cross(da, db);
    if (std::abs(den) < 1e-15) return std::nullopt;
    Vec2 ab = sub(b0, a0);
    double t = cross(ab, db) / den;
    double u = cross(ab, da) / den;
    if (u < -k_eps || u > 1.0 + k_eps) return std::nullopt;
    return t;
}

// Line A unrestricted vs full circle: all real t values.
std::vector<double> line_circle_intersect_t_all(Vec2 a0, Vec2 a1, Vec2 c,
                                                double r) {
    std::vector<double> out;
    if (r <= 0) return out;
    Vec2 d = sub(a1, a0);
    Vec2 f = sub(a0, c);
    double A = dot(d, d);
    if (A < 1e-30) return out;
    double B = 2.0 * dot(f, d);
    double C = dot(f, f) - r * r;
    double disc = B * B - 4.0 * A * C;
    if (disc < -k_eps) return out;
    if (disc < 0) disc = 0;
    double sqrt_d = std::sqrt(disc);
    for (double sign : {-1.0, 1.0}) {
        out.push_back((-B + sign * sqrt_d) / (2.0 * A));
    }
    if (out.size() == 2 && std::abs(out[0] - out[1]) < k_eps) out.pop_back();
    return out;
}

bool collect_extend_hits(const Sketch& s, const SketchEntity& line,
                         EntityId self_id, std::vector<double>& ts) {
    Vec2 a0 = line_end(s, line, PointRole::Start);
    Vec2 a1 = line_end(s, line, PointRole::End);
    for (const SketchEntity& other : s.entities()) {
        if (other.id == self_id || other.construction) continue;
        if (other.type == SketchEntityType::Line) {
            Vec2 b0 = line_end(s, other, PointRole::Start);
            Vec2 b1 = line_end(s, other, PointRole::End);
            if (auto t = line_seg_intersect_t(a0, a1, b0, b1)) ts.push_back(*t);
        } else if (other.type == SketchEntityType::Circle) {
            Vec2 c = {s.param(other.params[0]), s.param(other.params[1])};
            double r = s.param(other.params[2]);
            auto hits = line_circle_intersect_t_all(a0, a1, c, r);
            ts.insert(ts.end(), hits.begin(), hits.end());
        }
    }
    unique_sorted(ts);
    return !ts.empty();
}

}  // namespace

bool extend_entity(Sketch& s, const std::string& entity_id, double px,
                   double py) {
    EntityId id = EntityId::from_string(entity_id);
    const SketchEntity* e = s.entity(id);
    if (!e || e->type != SketchEntityType::Line) return false;

    Vec2 a0 = line_end(s, *e, PointRole::Start);
    Vec2 a1 = line_end(s, *e, PointRole::End);
    Vec2 d = sub(a1, a0);
    double len2 = dot(d, d);
    if (len2 < 1e-30) return false;

    // Nearest endpoint to the pick.
    double d0 = hypot2(sub({px, py}, a0));
    double d1 = hypot2(sub({px, py}, a1));
    bool extend_start = d0 <= d1;

    std::vector<double> ts;
    if (!collect_extend_hits(s, *e, id, ts)) return false;

    std::optional<double> best;
    if (extend_start) {
        // Forward from start is t < 0; nearest is the largest t < 0.
        for (double t : ts) {
            if (t < -k_eps && (!best || t > *best)) best = t;
        }
        if (!best) return false;
        set_line_end(s, *e, PointRole::Start, add(a0, mul(d, *best)));
    } else {
        // Forward from end is t > 1; nearest is the smallest t > 1.
        for (double t : ts) {
            if (t > 1.0 + k_eps && (!best || t < *best)) best = t;
        }
        if (!best) return false;
        set_line_end(s, *e, PointRole::End, add(a0, mul(d, *best)));
    }
    return true;
}

std::vector<std::string> pattern_entities(Sketch& s,
                                          const std::vector<std::string>& entity_ids,
                                          double dx, double dy, int count) {
    std::vector<std::string> out;
    if (count < 2) return out;
    if (std::hypot(dx, dy) < 1e-15) return out;

    out.reserve(entity_ids.size() * static_cast<size_t>(count - 1));

    for (const std::string& sid : entity_ids) {
        EntityId id = EntityId::from_string(sid);
        const SketchEntity* e = s.entity(id);
        if (!e) continue;

        const bool constr = e->construction;
        const SketchEntityType typ = e->type;

        // Snapshot geometry before creating copies (params stay valid).
        double p0 = 0, p1 = 0, p2 = 0, p3 = 0, p4 = 0;
        if (typ == SketchEntityType::Line) {
            p0 = s.param(e->params[0]);
            p1 = s.param(e->params[1]);
            p2 = s.param(e->params[2]);
            p3 = s.param(e->params[3]);
        } else if (typ == SketchEntityType::Circle) {
            p0 = s.param(e->params[0]);
            p1 = s.param(e->params[1]);
            p2 = s.param(e->params[2]);
        } else if (typ == SketchEntityType::Arc) {
            p0 = s.param(e->params[0]);
            p1 = s.param(e->params[1]);
            p2 = s.param(e->params[2]);
            p3 = s.param(e->params[3]);
            p4 = s.param(e->params[4]);
        } else if (typ == SketchEntityType::Ellipse) {
            auto ax = s.ellipse_axes(id);
            if (!ax) continue;
            p0 = (*ax)[0];
            p1 = (*ax)[1];
            p2 = (*ax)[2];
            p3 = (*ax)[3];
            p4 = (*ax)[4];
        } else if (typ == SketchEntityType::Spline) {
            // Copies below from fit points.
        } else {
            continue;
        }

        EntityId prev = id;
        for (int i = 1; i < count; ++i) {
            double ox = dx * i;
            double oy = dy * i;
            EntityId nid;
            if (typ == SketchEntityType::Line) {
                nid = s.add_line(p0 + ox, p1 + oy, p2 + ox, p3 + oy);
                s.add_constraint(ConstraintType::Parallel,
                                 {{nid, PointRole::Self}, {id, PointRole::Self}});
                s.add_constraint(ConstraintType::Distance,
                                 {{nid, PointRole::Start}, {prev, PointRole::Start}},
                                 std::hypot(dx, dy), true);
            } else if (typ == SketchEntityType::Circle) {
                nid = s.add_circle(p0 + ox, p1 + oy, p2);
                s.add_constraint(ConstraintType::Equal,
                                 {{nid, PointRole::Self}, {id, PointRole::Self}});
                s.add_constraint(ConstraintType::Distance,
                                 {{nid, PointRole::Center}, {prev, PointRole::Center}},
                                 std::hypot(dx, dy), true);
            } else if (typ == SketchEntityType::Ellipse) {
                nid = s.add_ellipse(p0 + ox, p1 + oy, p2, p3, p4);
            } else if (typ == SketchEntityType::Spline) {
                auto fits = s.spline_fit_points(id);
                for (auto& fp : fits) {
                    fp[0] += ox;
                    fp[1] += oy;
                }
                nid = s.add_spline(fits);
            } else {
                nid = s.add_arc(p0 + ox, p1 + oy, p2, p3, p4);
                s.add_constraint(ConstraintType::Equal,
                                 {{nid, PointRole::Self}, {id, PointRole::Self}});
            }
            if (constr) s.set_construction(nid, true);
            out.push_back(nid.str());
            prev = nid;
        }
    }
    return out;
}

namespace {

// Snapshot of a seed circle. Pointers into Sketch::entities_ dangle after add_*.
struct CircleSeed {
    EntityId id;
    double x = 0;
    double y = 0;
    double r = 0;
};

using CircularCopyFn = bool (*)(Sketch&, const CircleSeed&, Vec2, double, double,
                                EntityId, EntityId, std::vector<std::string>&);

bool copy_circle(Sketch& s, const CircleSeed& seed, Vec2 origin, double ca,
                 double sa, EntityId layout, EntityId seed_ray,
                 std::vector<std::string>& out) {
    double dx = seed.x - origin.x;
    double dy = seed.y - origin.y;
    double nx = origin.x + dx * ca - dy * sa;
    double ny = origin.y + dx * sa + dy * ca;
    EntityId copy = s.add_circle(nx, ny, seed.r);
    s.add_constraint(ConstraintType::Equal,
                     {{copy, PointRole::Self}, {seed.id, PointRole::Self}});
    EntityId ray = s.add_line(origin.x, origin.y, nx, ny);
    s.set_construction(ray, true);
    s.add_constraint(ConstraintType::Coincident,
                     {{ray, PointRole::Start}, {layout, PointRole::Center}});
    s.add_constraint(ConstraintType::Coincident,
                     {{ray, PointRole::End}, {copy, PointRole::Center}});
    s.add_constraint(ConstraintType::Equal,
                     {{ray, PointRole::Self}, {seed_ray, PointRole::Self}});
    const double ang = std::atan2(sa, ca);
    s.add_constraint(ConstraintType::Angle,
                     {{seed_ray, PointRole::Self}, {ray, PointRole::Self}}, ang, true);
    out.push_back(copy.str());
    return true;
}

const std::unordered_map<SketchEntityType, CircularCopyFn> kCircularKinds = {
    {SketchEntityType::Circle, copy_circle},
};

}  // namespace

std::vector<std::string> circular_pattern_entities(
    Sketch& s, const std::vector<std::string>& entity_ids, double cx, double cy,
    int count, double total_angle) {
    std::vector<std::string> out;
    if (count < 2 || std::abs(total_angle) <= k_eps || entity_ids.empty()) {
        return out;
    }

    std::vector<CircleSeed> seeds;
    seeds.reserve(entity_ids.size());
    for (const std::string& sid : entity_ids) {
        EntityId id = EntityId::from_string(sid);
        const SketchEntity* e = s.entity(id);
        if (!e || kCircularKinds.find(e->type) == kCircularKinds.end()) continue;
        CircleSeed seed;
        seed.id = id;
        seed.x = s.param(e->params[0]);
        seed.y = s.param(e->params[1]);
        seed.r = s.param(e->params[2]);
        seeds.push_back(seed);
    }
    if (seeds.empty()) return out;

    Vec2 origin{cx, cy};
    const CircleSeed& first = seeds.front();
    double pitch = std::hypot(first.x - cx, first.y - cy);
    if (pitch <= k_eps) return out;

    EntityId layout = s.add_circle(cx, cy, pitch);
    s.set_construction(layout, true);
    s.add_constraint(ConstraintType::Fix, {{layout, PointRole::Center}});

    const double step = total_angle / static_cast<double>(count);
    for (const CircleSeed& seed : seeds) {
        EntityId this_ray = s.add_line(cx, cy, seed.x, seed.y);
        s.set_construction(this_ray, true);
        s.add_constraint(ConstraintType::Coincident,
                         {{this_ray, PointRole::Start}, {layout, PointRole::Center}});
        s.add_constraint(ConstraintType::Coincident,
                         {{this_ray, PointRole::End}, {seed.id, PointRole::Center}});
        auto it = kCircularKinds.find(SketchEntityType::Circle);
        for (int i = 1; i < count; ++i) {
            double ang = step * static_cast<double>(i);
            it->second(s, seed, origin, std::cos(ang), std::sin(ang), layout,
                       this_ray, out);
        }
    }
    return out;
}

namespace {

Vec2 reflect_pt(Vec2 p, Vec2 a0, Vec2 ad, Vec2 an) {
    Vec2 d = sub(p, a0);
    Vec2 along = mul(ad, dot(d, ad));
    Vec2 across = mul(an, dot(d, an));
    return add(a0, sub(along, across));
}

}  // namespace

std::vector<std::string> mirror_entities(Sketch& s,
                                         const std::vector<std::string>& entity_ids,
                                         const std::string& axis_id) {
    std::vector<std::string> out;
    EntityId axis = EntityId::from_string(axis_id);
    const SketchEntity* ax = s.entity(axis);
    if (!ax || ax->type != SketchEntityType::Line) return out;
    auto a0p = s.point_pos({axis, PointRole::Start});
    auto a1p = s.point_pos({axis, PointRole::End});
    if (!a0p || !a1p) return out;
    Vec2 a0{(*a0p)[0], (*a0p)[1]};
    Vec2 a1{(*a1p)[0], (*a1p)[1]};
    Vec2 ad = unit(sub(a1, a0));
    if (hypot2(ad) < 1e-15) return out;
    Vec2 an{-ad.y, ad.x};
    auto refl = [&](double x, double y) { return reflect_pt({x, y}, a0, ad, an); };

    for (const std::string& sid : entity_ids) {
        if (sid == axis_id) continue;
        EntityId id = EntityId::from_string(sid);
        const SketchEntity* e = s.entity(id);
        if (!e) continue;
        EntityId copy;
        switch (e->type) {
            case SketchEntityType::Line: {
                Vec2 st = refl(s.param(e->params[0]), s.param(e->params[1]));
                Vec2 en = refl(s.param(e->params[2]), s.param(e->params[3]));
                copy = s.add_line(st.x, st.y, en.x, en.y);
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::Start}, {copy, PointRole::Start},
                                  {axis, PointRole::Self}});
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::End}, {copy, PointRole::End},
                                  {axis, PointRole::Self}});
                break;
            }
            case SketchEntityType::Circle: {
                Vec2 c = refl(s.param(e->params[0]), s.param(e->params[1]));
                copy = s.add_circle(c.x, c.y, s.param(e->params[2]));
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::Center}, {copy, PointRole::Center},
                                  {axis, PointRole::Self}});
                s.add_constraint(ConstraintType::Equal,
                                 {{copy, PointRole::Self}, {id, PointRole::Self}});
                break;
            }
            case SketchEntityType::Point: {
                Vec2 p = refl(s.param(e->params[0]), s.param(e->params[1]));
                copy = s.add_point(p.x, p.y);
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::Self}, {copy, PointRole::Self},
                                  {axis, PointRole::Self}});
                break;
            }
            case SketchEntityType::Arc: {
                Vec2 c = refl(s.param(e->params[0]), s.param(e->params[1]));
                const double r = s.param(e->params[2]);
                Vec2 st = refl(s.param(e->params[5]), s.param(e->params[6]));
                Vec2 en = refl(s.param(e->params[7]), s.param(e->params[8]));
                // Mirror reverses orientation: CCW from reflected end to start.
                const double sa = std::atan2(en.y - c.y, en.x - c.x);
                const double ea = std::atan2(st.y - c.y, st.x - c.x);
                copy = s.add_arc(c.x, c.y, r, sa, ea);
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::Center}, {copy, PointRole::Center},
                                  {axis, PointRole::Self}});
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::Start}, {copy, PointRole::End},
                                  {axis, PointRole::Self}});
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::End}, {copy, PointRole::Start},
                                  {axis, PointRole::Self}});
                break;
            }
            case SketchEntityType::Ellipse: {
                auto axv = s.ellipse_axes(id);
                if (!axv) continue;
                Vec2 c = refl((*axv)[0], (*axv)[1]);
                Vec2 maj{(*axv)[0] + (*axv)[2] * std::cos((*axv)[4]),
                         (*axv)[1] + (*axv)[2] * std::sin((*axv)[4])};
                Vec2 majr = refl(maj.x, maj.y);
                const double ang = std::atan2(majr.y - c.y, majr.x - c.x);
                copy = s.add_ellipse(c.x, c.y, (*axv)[2], (*axv)[3], ang);
                s.add_constraint(ConstraintType::Symmetric,
                                 {{id, PointRole::Center}, {copy, PointRole::Center},
                                  {axis, PointRole::Self}});
                break;
            }
            case SketchEntityType::EllipticalArc: {
                auto axv = s.ellipse_axes(id);
                if (!axv || e->params.size() < 11) continue;
                Vec2 c = refl((*axv)[0], (*axv)[1]);
                Vec2 st = refl(s.param(e->params[7]), s.param(e->params[8]));
                Vec2 en = refl(s.param(e->params[9]), s.param(e->params[10]));
                Vec2 maj{(*axv)[0] + (*axv)[2] * std::cos((*axv)[4]),
                         (*axv)[1] + (*axv)[2] * std::sin((*axv)[4])};
                Vec2 majr = refl(maj.x, maj.y);
                const double ang = std::atan2(majr.y - c.y, majr.x - c.x);
                const double sa = std::atan2(en.y - c.y, en.x - c.x) - ang;
                const double ea = std::atan2(st.y - c.y, st.x - c.x) - ang;
                copy = s.add_elliptical_arc(c.x, c.y, (*axv)[2], (*axv)[3], ang, sa, ea);
                break;
            }
            case SketchEntityType::Spline: {
                auto fits = s.spline_fit_points(id);
                for (auto& fp : fits) {
                    Vec2 r = refl(fp[0], fp[1]);
                    fp[0] = r.x;
                    fp[1] = r.y;
                }
                std::reverse(fits.begin(), fits.end());
                copy = s.add_spline(fits);
                if (fits.size() >= 2) {
                    s.add_constraint(ConstraintType::Symmetric,
                                     {{id, PointRole::Start}, {copy, PointRole::End},
                                      {axis, PointRole::Self}});
                    s.add_constraint(ConstraintType::Symmetric,
                                     {{id, PointRole::End}, {copy, PointRole::Start},
                                      {axis, PointRole::Self}});
                }
                break;
            }
            default:
                continue;
        }
        if (e->construction) s.set_construction(copy, true);
        out.push_back(copy.str());
    }
    return out;
}

}  // namespace sx::sketch_tools
