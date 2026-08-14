#include "sx/query.hpp"

#include <sstream>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/entity.hpp"
#include "sx/features.hpp"

namespace sx {
namespace {

std::string trim_key(const std::string& s) {
    auto a = s.find_first_not_of(" \t");
    auto b = s.find_last_not_of(" \t");
    if (a == std::string::npos) return {};
    return s.substr(a, b - a + 1);
}

}  // namespace

std::vector<QueryHit> run_query(const Document& doc, const std::string& query) {
    std::vector<QueryHit> hits;
    std::string type_filter;
    std::string created_by;
    std::string adjacent_to;
    std::istringstream in(query);
    std::string tok;
    while (in >> tok) {
        auto eq = tok.find('=');
        if (eq == std::string::npos) continue;
        std::string k = trim_key(tok.substr(0, eq));
        std::string v = trim_key(tok.substr(eq + 1));
        if (k == "type") type_filter = v;
        if (k == "created-by") created_by = v;
        if (k == "adjacent-to") adjacent_to = v;
    }
    if (!adjacent_to.empty()) {
        try {
            const EntityId seed = EntityId::from_string(adjacent_to);
            const Card* c = doc.cards().find(seed);
            if (c) {
                for (const auto& r : c->relations) {
                    const Card* rc = doc.cards().find(r);
                    const std::string kind = rc ? to_string(rc->kind) : "face";
                    if (!type_filter.empty() && kind != type_filter &&
                        !(type_filter == "face" && kind == "face"))
                        continue;
                    if (r == seed) continue;
                    hits.push_back({r, kind});
                }
            }
        } catch (...) {
        }
        return hits;
    }
    if (!created_by.empty()) {
        try {
            const Feature* f = doc.graph().feature(EntityId::from_string(created_by));
            if (f && !f->output_body.is_null()) {
                const Body* b = doc.body(f->output_body);
                if (b) {
                    EntityKind want = EntityKind::Face;
                    if (type_filter == "edge") want = EntityKind::Edge;
                    if (type_filter == "body") {
                        hits.push_back({b->id, "body"});
                        return hits;
                    }
                    auto it = b->subshape_ids.find(want);
                    if (it != b->subshape_ids.end()) {
                        for (const auto& id : it->second)
                            hits.push_back({id, type_filter.empty() ? "face" : type_filter});
                    }
                }
            }
        } catch (...) {
        }
        return hits;
    }
    if (type_filter == "body" || type_filter.empty()) {
        for (const auto& id : doc.body_ids()) hits.push_back({id, "body"});
    }
    return hits;
}

std::string card_digest(const Feature& f) {
    std::ostringstream ss;
    ss << to_string(f.type);
    if (!f.name.empty()) ss << " “" << f.name << "”";
    if (f.params.contains("kind")) ss << " " << f.params["kind"].get<std::string>();
    if (f.params.contains("op")) ss << " " << f.params["op"].get<std::string>();
    if (f.params.contains("end")) ss << " end=" << f.params["end"].get<std::string>();
    if (f.params.contains("diameter")) ss << " Ø" << f.params["diameter"].get<double>();
    if (f.params.contains("context")) ss << " in-context";
    if (f.params.contains("recipe")) ss << " recipe=" << f.params["recipe"].get<std::string>();
    return ss.str();
}

}  // namespace sx
