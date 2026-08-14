#include "sx/xref.hpp"

#include <cmath>

#include "sx/document.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"

namespace sx {

void to_json(nlohmann::json& j, const ContextSnapshot& c) {
    j = nlohmann::json{{"id", c.id.str()},
                       {"name", c.name},
                       {"source_body", c.source_body.str()},
                       {"consumer_feature", c.consumer_feature.str()},
                       {"source_path", c.source_path},
                       {"volume", c.volume},
                       {"height", c.height},
                       {"bbox_min", c.bbox_min},
                       {"bbox_max", c.bbox_max},
                       {"face_count", c.face_count}};
}

void from_json(const nlohmann::json& j, ContextSnapshot& c) {
    if (j.contains("id")) c.id = EntityId::from_string(j.at("id").get<std::string>());
    c.name = j.value("name", "");
    if (j.contains("source_body"))
        c.source_body = EntityId::from_string(j.at("source_body").get<std::string>());
    if (j.contains("consumer_feature")) {
        const auto s = j.at("consumer_feature").get<std::string>();
        if (!s.empty()) c.consumer_feature = EntityId::from_string(s);
    }
    c.source_path = j.value("source_path", "");
    c.volume = j.value("volume", 0.0);
    c.height = j.value("height", 0.0);
    if (j.contains("bbox_min")) c.bbox_min = j.at("bbox_min").get<std::array<double, 3>>();
    if (j.contains("bbox_max")) c.bbox_max = j.at("bbox_max").get<std::array<double, 3>>();
    c.face_count = j.value("face_count", 0);
}

namespace {

bool fill_from_body(const Document& doc, const EntityId& source, ContextSnapshot& snap,
                    std::string* err) {
    const Body* b = doc.body(source);
    if (!b || b->shape.IsNull()) {
        if (err) *err = "context needs a solid neighbor";
        return false;
    }
    snap.source_body = source;
    snap.volume = shape::volume(b->shape);
    snap.face_count = shape::count(b->shape).faces;
    if (auto bb = measure::bounding_box(doc, source)) {
        snap.bbox_min = bb->min;
        snap.bbox_max = bb->max;
        snap.height = bb->max[2] - bb->min[2];
    }
    return true;
}

}  // namespace

EntityId capture_context(Document& doc, const EntityId& source_body, const std::string& name,
                         std::string* err) {
    ContextSnapshot snap;
    snap.id = EntityId::generate();
    snap.name = name.empty() ? "Context" : name;
    if (!fill_from_body(doc, source_body, snap, err)) return {};
    return doc.add_context(std::move(snap));
}

bool is_context_stale(const Document& doc, const EntityId& context_id) {
    const ContextSnapshot* snap = doc.context(context_id);
    if (!snap) return false;
    const Body* b = doc.body(snap->source_body);
    if (!b || b->shape.IsNull()) return true;
    const double live_vol = shape::volume(b->shape);
    double live_h = snap->height;
    if (auto bb = measure::bounding_box(doc, snap->source_body))
        live_h = bb->max[2] - bb->min[2];
    return std::abs(live_vol - snap->volume) > 1e-4 || std::abs(live_h - snap->height) > 1e-4;
}

bool update_context(Document& doc, const EntityId& context_id, std::string* err) {
    ContextSnapshot* snap = doc.context_mut(context_id);
    if (!snap) {
        if (err) *err = "no such context";
        return false;
    }
    if (!fill_from_body(doc, snap->source_body, *snap, err)) return false;
    doc.bump_revision();
    return true;
}

}  // namespace sx
