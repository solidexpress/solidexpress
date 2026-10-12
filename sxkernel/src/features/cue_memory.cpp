#include "features/cue_memory.h"

#include <TopoDS.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include "features/ops.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"

namespace sx {

namespace {

// True when `point`/`dir` is the same line the stored cue already names.
// Topological naming can hand a fillet's old edge id to a different curve
// after the blend consumes it. That must not replace the pre-fillet cue.
bool cue_still_names(const nlohmann::json& cue, const gp_Pnt& point, const gp_Vec& dir) {
    if (!cue.is_object() || (!cue.contains("point") && !cue.contains("dir"))) return true;
    const TopoCue stored = cue_from_json(cue);
    return cue_names_line(stored, gp_XYZ(point.X(), point.Y(), point.Z()),
                          gp_XYZ(dir.X(), dir.Y(), dir.Z()));
}

}  // namespace

void CueMemory::remember_live_edges(const FeatureGraph&, Document& doc) {
    for (const auto& body_id : doc.body_ids()) {
        const Body* body = doc.body(body_id);
        if (!body) continue;
        auto it = body->subshape_ids.find(EntityKind::Edge);
        if (it == body->subshape_ids.end()) continue;
        for (const auto& eid : it->second) {
            TopoDS_Shape shape = doc.resolve(eid);
            if (shape.IsNull() || shape.ShapeType() != TopAbs_EDGE) continue;
            const TopoDS_Edge edge = TopoDS::Edge(shape);
            gp_Pnt p;
            gp_Vec v;
            if (!feature_ops::edge_midpoint_sample(edge, p, v)) continue;
            TopoCue cue;
            cue.point = gp_XYZ(p.X(), p.Y(), p.Z());
            cue.dir = gp_XYZ(v.X(), v.Y(), v.Z());
            edges_[eid.str()] = cue;
        }
    }
}

void CueMemory::refresh_feature_cues(FeatureGraph& graph, Feature& f, Document& doc) {
    struct CueJob {
        FeatureType type;
        const char* refs;
        const char* cues;
        EntityKind kind;
    };
    // Fillet and chamfer remember edges. Shell remembers the removed faces.
    // A new dress-up reference is another row, not another branch at the call.
    static constexpr CueJob kJobs[] = {
        {FeatureType::Fillet, "edges", "edge_cues", EntityKind::Edge},
        {FeatureType::Chamfer, "edges", "edge_cues", EntityKind::Edge},
        {FeatureType::Shell, "faces", "face_cues", EntityKind::Face},
    };
    const CueJob* job = nullptr;
    for (const auto& candidate : kJobs)
        if (candidate.type == f.type) job = &candidate;
    if (!job) return;
    if (!f.params.contains(job->refs) || !f.params[job->refs].is_array()) return;
    if (!f.params.contains("target") || !f.params["target"].is_string()) return;
    const Feature* ref =
        graph.feature(EntityId::from_string(f.params["target"].get<std::string>()));
    if (!ref || ref->output_body.is_null()) return;
    const Body* tb = doc.body(ref->output_body);
    if (!tb) return;
    nlohmann::json cues = f.params.value(job->cues, nlohmann::json::object());
    if (!cues.is_object()) return;
    bool changed = false;
    for (const auto& je : f.params[job->refs]) {
        if (!je.is_string()) continue;
        const std::string key = je.get<std::string>();
        const bool have = cues.contains(key);
        TopoDS_Shape es;
        std::string why;
        if (feature_ops::resolve_topo_shape(doc, *tb, job->kind, je, es, &why)) {
            TopoCue fresh = job->kind == EntityKind::Face
                                ? cue_from_face(TopoDS::Face(es), tb->shape)
                                : cue_from_edge(TopoDS::Edge(es), tb->shape);
            if (refresh_cue(cues, key, fresh, job->kind)) changed = true;
            continue;
        }
        if (job->kind != EntityKind::Edge) continue;
        const TopoCue* mem = find(key);
        if (!mem) continue;
        gp_Pnt mem_p(mem->point.X(), mem->point.Y(), mem->point.Z());
        gp_Vec mem_d(mem->dir.X(), mem->dir.Y(), mem->dir.Z());
        if (have && !cue_still_names(cues[key], mem_p, mem_d)) continue;
        // A cue that already names this line keeps its fraction. Replacing it
        // with the point/dir memory would drop the relative match.
        if (have) continue;
        TopoCue stored;
        stored.point = mem->point;
        stored.dir = mem->dir;
        stored.tol = 0.5;
        cues[key] = cue_to_json(stored);
        changed = true;
    }
    if (changed) f.params[job->cues] = std::move(cues);
}

const TopoCue* CueMemory::find(const std::string& id) const {
    auto it = edges_.find(id);
    if (it == edges_.end()) return nullptr;
    return &it->second;
}

nlohmann::json CueMemory::to_json() const {
    nlohmann::json mem = nlohmann::json::object();
    for (const auto& [id, e] : edges_)
        mem[id] = {e.point.X(), e.point.Y(), e.point.Z(), e.dir.X(), e.dir.Y(), e.dir.Z()};
    return mem;
}

void CueMemory::from_json(const nlohmann::json& j) {
    edges_.clear();
    if (!j.is_object()) return;
    for (auto it = j.begin(); it != j.end(); ++it) {
        const auto& a = it.value();
        if (!a.is_array() || a.size() < 6) continue;
        TopoCue cue;
        cue.point = gp_XYZ(a[0].get<double>(), a[1].get<double>(), a[2].get<double>());
        cue.dir = gp_XYZ(a[3].get<double>(), a[4].get<double>(), a[5].get<double>());
        edges_.emplace(it.key(), cue);
    }
}

}  // namespace sx
