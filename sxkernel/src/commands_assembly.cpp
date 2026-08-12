#include "sx/commands_assembly.hpp"

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/log.hpp"
#include "sx/mates.hpp"

namespace sx {

nlohmann::json assembly_to_json(const Document& doc) {
    nlohmann::json instances = nlohmann::json::array();
    for (const auto& inst : doc.instances()) instances.push_back(inst);
    nlohmann::json mates = nlohmann::json::array();
    for (const auto& m : doc.mates()) mates.push_back(m);
    return nlohmann::json{{"instances", std::move(instances)}, {"mates", std::move(mates)}};
}

void assembly_from_json(Document& doc, const nlohmann::json& snapshot) {
    // Clear mates first (they reference instances), then instances.
    while (!doc.mates().empty()) {
        const EntityId id = doc.mates().front().id;
        if (!doc.remove_mate(id)) break;
    }
    while (!doc.instances().empty()) {
        const EntityId id = doc.instances().front().id;
        if (!doc.remove_instance(id)) break;
    }

    if (snapshot.contains("instances") && snapshot["instances"].is_array()) {
        for (const auto& ji : snapshot["instances"]) {
            try {
                Instance inst = ji.get<Instance>();
                if (!doc.body(inst.source_body)) {
                    log::warn("assembly restore: dropping instance — missing source " +
                              inst.source_body.str());
                    continue;
                }
                doc.restore_instance(std::move(inst));
            } catch (const std::exception& e) {
                log::warn(std::string("assembly restore: bad instance: ") + e.what());
            }
        }
    }
    if (snapshot.contains("mates") && snapshot["mates"].is_array()) {
        for (const auto& jm : snapshot["mates"]) {
            try {
                Mate m = jm.get<Mate>();
                if (!m.instance_b.is_null() && !doc.instance(m.instance_b)) {
                    log::warn("assembly restore: dropping mate — missing instance " +
                              m.instance_b.str());
                    continue;
                }
                doc.restore_mate(std::move(m));
            } catch (const std::exception& e) {
                log::warn(std::string("assembly restore: bad mate: ") + e.what());
            }
        }
    }
}

void AssemblySnapshotCommand::restore(Document& doc, const nlohmann::json& snapshot) {
    assembly_from_json(doc, snapshot);
}

void AssemblySnapshotCommand::execute(Document& doc) { restore(doc, after_); }
void AssemblySnapshotCommand::undo(Document& doc) { restore(doc, before_); }

}  // namespace sx
