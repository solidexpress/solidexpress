#include "sx/sketch_tools.hpp"

#include <algorithm>
#include <cmath>
#include <optional>
#include <unordered_map>
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

bool collect_line_intersections(const Sketch& s, const SketchEntity& line,
                                EntityId self_id, std::vector<double>& ts) {
    Vec2 a0 = line_end(s, line, PointRole::Start);
    Vec2 a1 = line_end(s, line, PointRole::End);
    for (const SketchEntity& other : s.entities()) {
        if (other.id == self_id || other.construction) continue;
        if (other.type == SketchEntityType::Line) {
            Vec2 b0 = line_end(s, other, PointRole::Start);
            Vec2 b1 = line_end(s, other, PointRole::End);
            if (auto t = line_line_intersect_t(a0, a1, b0, b1)) ts.push_back(*t);
        } else if (other.type == SketchEntityType::Circle) {
            Vec2 c = {s.param(other.params[0]), s.param(other.params[1])};
            double r = s.param(other.params[2]);
            auto hits = line_circle_intersect_t(a0, a1, c, r);
            ts.insert(ts.end(), hits.begin(), hits.end());
        }
    }
    unique_sorted(ts);
    return !ts.empty();
}

bool collect_circle_intersections(const Sketch& s, const SketchEntity& circ,
                                  EntityId self_id, std::vector<double>& angs) {
    Vec2 c = {s.param(circ.params[0]), s.param(circ.params[1])};
    double r = s.param(circ.params[2]);
    for (const SketchEntity& other : s.entities()) {
        if (other.id == self_id || other.construction) continue;
        if (other.type == SketchEntityType::Line) {
            Vec2 a0 = line_end(s, other, PointRole::Start);
            Vec2 a1 = line_end(s, other, PointRole::End);
            for (double t : line_circle_intersect_t(a0, a1, c, r)) {
                Vec2 p = add(a0, mul(sub(a1, a0), t));
                angs.push_back(std::atan2(p.y - c.y, p.x - c.x));
            }
        } else if (other.type == SketchEntityType::Circle) {
            Vec2 oc = {s.param(other.params[0]), s.param(other.params[1])};
            double or_ = s.param(other.params[2]);
            auto hits = circle_circle_intersect_angles(c, r, oc, or_);
            angs.insert(angs.end(), hits.begin(), hits.end());
        }
    }
    for (double& a : angs) a = normalize_angle(a);
    unique_sorted(angs);
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

bool offset_line(Sketch& s, const SketchEntity& e, EntityId /*id*/, double distance,
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
    // The driving size of a full-circle offset is the diameter the callout
    // shows. The radius stays the circle parameter.
    s.add_constraint(ConstraintType::Diameter, {{nid, PointRole::Self}}, nr * 2.0, true);
    out.push_back(nid.str());
    return true;
}

const std::unordered_map<SketchEntityType, Offsetter> kOffsetters = {
    {SketchEntityType::Line, offset_line},
    {SketchEntityType::Circle, offset_circle},
};

}  // namespace

std::vector<std::string> offset_entities(Sketch& s,
                                         const std::vector<std::string>& entity_ids,
                                         double distance) {
    std::vector<std::string> out;
    if (std::abs(distance) <= k_eps) return out;
    out.reserve(entity_ids.size());

    for (const std::string& sid : entity_ids) {
        EntityId id = EntityId::from_string(sid);
        const SketchEntity* e = s.entity(id);
        if (!e) continue;
        const auto it = kOffsetters.find(e->type);
        if (it == kOffsetters.end()) continue;  // Arc and other kinds skipped.
        it->second(s, *e, id, distance, out);
    }
    return out;
}

bool trim_entity(Sketch& s, const std::string& entity_id, double px, double py) {
    EntityId id = EntityId::from_string(entity_id);
    const SketchEntity* e = s.entity(id);
    if (!e) return false;
    if (e->type == SketchEntityType::Line) return trim_line(s, id, px, py);
    if (e->type == SketchEntityType::Circle) return trim_circle(s, id, px, py);
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
        } else {
            continue;  // points unsupported
        }

        for (int i = 1; i < count; ++i) {
            double ox = dx * i;
            double oy = dy * i;
            EntityId nid;
            if (typ == SketchEntityType::Line) {
                nid = s.add_line(p0 + ox, p1 + oy, p2 + ox, p3 + oy);
            } else if (typ == SketchEntityType::Circle) {
                nid = s.add_circle(p0 + ox, p1 + oy, p2);
            } else {
                nid = s.add_arc(p0 + ox, p1 + oy, p2, p3, p4);
            }
            if (constr) s.set_construction(nid, true);
            out.push_back(nid.str());
        }
    }
    return out;
}

}  // namespace sx::sketch_tools
