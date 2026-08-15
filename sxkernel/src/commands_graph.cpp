#include "sx/commands_graph.hpp"

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/log.hpp"

namespace sx {

void GraphSnapshotCommand::restore(Document& doc, const nlohmann::json& snapshot) {
    // Bodies the incoming graph will rebuild stay in place so its regenerate
    // routes through the naming service (ids/cards survive undo/redo); bodies
    // only the outgoing graph knows about are removed here since the incoming
    // graph has no memory of them.
    FeatureGraph incoming = FeatureGraph::from_json(snapshot);
    auto incoming_owns = [&](const EntityId& id) {
        for (const auto& f : incoming.timeline()) {
            if (f.output_body == id) return true;
            for (const auto& ob : f.output_bodies)
                if (ob == id) return true;
        }
        return false;
    };
    for (const auto& f : doc.graph().timeline()) {
        if (!f.output_body.is_null() && !incoming_owns(f.output_body) && doc.body(f.output_body))
            doc.remove_body(f.output_body);
        for (const auto& ob : f.output_bodies) {
            if (!incoming_owns(ob) && doc.body(ob)) doc.remove_body(ob);
        }
    }
    doc.set_graph(std::move(incoming));
    std::string err;
    if (!doc.graph().regenerate(doc, &err))
        log::error("GraphSnapshotCommand: regenerate failed: " + err);
}

void GraphSnapshotCommand::execute(Document& doc) { restore(doc, after_); }
void GraphSnapshotCommand::undo(Document& doc) { restore(doc, before_); }

}  // namespace sx
