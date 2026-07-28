#pragma once
// Per-type FeatureGraph::apply handlers. Implementation detail of features.cpp —
// not part of the public sxkernel API.

#include <nlohmann/json.hpp>

#include <map>
#include <string>

#include <TopoDS_Shape.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/entity.hpp"
#include "sx/features.hpp"
#include "sx/ids.hpp"

namespace sx::feature_ops {

struct ApplyCtx {
    FeatureGraph& graph;
    Document& doc;
    Feature& feature;
    const nlohmann::json& params;  // already resolve_params'd
    const std::map<std::string, double>& env;
    std::string* err;

    EntityId find_feature_body(const std::string& key) const {
        if (!params.contains(key)) return {};
        const Feature* ref =
            graph.feature(EntityId::from_string(params[key].get<std::string>()));
        return ref ? ref->output_body : EntityId{};
    }

    // True when the referenced feature is missing or suppressed — modifying
    // features should no-op rather than fail the whole regenerate.
    bool target_inactive(const std::string& key) const {
        if (!params.contains(key)) return true;
        const Feature* ref =
            graph.feature(EntityId::from_string(params[key].get<std::string>()));
        return ref == nullptr || ref->suppressed;
    }

    bool fail(const std::string& msg) const {
        if (err) *err = feature.name + ": " + msg;
        return false;
    }
};

bool apply_fillet_chamfer(ApplyCtx& ctx);
bool apply_shell(ApplyCtx& ctx);
bool apply_offset(ApplyCtx& ctx);
bool apply_push_pull(ApplyCtx& ctx);
bool apply_draft(ApplyCtx& ctx);
bool apply_mirror(ApplyCtx& ctx);
bool apply_linear_pattern(ApplyCtx& ctx);
bool apply_circular_pattern(ApplyCtx& ctx);
bool apply_boolean(ApplyCtx& ctx);

bool resolve_topo_shape(Document& doc, const Body& body, EntityKind kind,
                        const nlohmann::json& ref, TopoDS_Shape& out, std::string* why);

gp_Pnt pnt_from(const nlohmann::json& a);
gp_Dir dir_from(const nlohmann::json& a);
void put_body(Document& doc, const EntityId& id, const TopoDS_Shape& shape,
              const std::string& name);
void ensure_pattern_slots(Feature& f, int count, Document& doc);

}  // namespace sx::feature_ops
