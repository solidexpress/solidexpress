#include "sx/autodim.hpp"

#include <cmath>

#include "sx/sketch.hpp"

namespace sx {
namespace {

std::array<double, 2> line_dir(const Sketch& sk, const SketchEntity& e) {
    if (e.type != SketchEntityType::Line || e.params.size() < 4) return {1, 0};
    const double x1 = sk.param(e.params[0]);
    const double y1 = sk.param(e.params[1]);
    const double x2 = sk.param(e.params[2]);
    const double y2 = sk.param(e.params[3]);
    double dx = x2 - x1, dy = y2 - y1;
    const double len = std::hypot(dx, dy);
    if (len < 1e-9) return {1, 0};
    return {dx / len, dy / len};
}

double line_len(const Sketch& sk, const SketchEntity& e) {
    if (e.type != SketchEntityType::Line || e.params.size() < 4) return 0;
    return std::hypot(sk.param(e.params[2]) - sk.param(e.params[0]),
                      sk.param(e.params[3]) - sk.param(e.params[1]));
}

}  // namespace

int auto_dimension(Sketch& sketch) {
    int n = 0;
    for (const auto& c : sketch.constraints()) {
        if (!c.weak) continue;
        if (sketch.set_constraint_weak(c.id, false)) ++n;
    }
    return n;
}

std::vector<ProposeChip> propose_on_select(const Sketch& sketch,
                                           const std::vector<EntityId>& selected) {
    std::vector<const SketchEntity*> lines;
    auto consider = [&](const SketchEntity& e) {
        if (e.type == SketchEntityType::Line) lines.push_back(&e);
    };
    if (selected.empty()) {
        for (const auto& e : sketch.entities()) consider(e);
    } else {
        for (const auto& id : selected) {
            if (const SketchEntity* e = sketch.entity(id)) consider(*e);
        }
    }
    std::vector<ProposeChip> out;
    for (size_t i = 0; i < lines.size(); ++i) {
        for (size_t j = i + 1; j < lines.size(); ++j) {
            const auto da = line_dir(sketch, *lines[i]);
            const auto db = line_dir(sketch, *lines[j]);
            const double dot = std::abs(da[0] * db[0] + da[1] * db[1]);
            if (dot > 0.98) {
                out.push_back({"parallel", lines[i]->id, lines[j]->id, dot});
            } else if (dot < 0.15) {
                out.push_back({"perpendicular", lines[i]->id, lines[j]->id, 1.0 - dot});
            }
            const double la = line_len(sketch, *lines[i]);
            const double lb = line_len(sketch, *lines[j]);
            if (la > 1e-6 && lb > 1e-6 && std::abs(la - lb) / std::max(la, lb) < 0.05)
                out.push_back({"equal", lines[i]->id, lines[j]->id, 1.0});
        }
    }
    return out;
}

}  // namespace sx
