#pragma once
// Undoable assembly edits (instances + mates + transforms). Same pattern as
// GraphSnapshotCommand: callers mutate first, then push with before/after JSON.

#include <nlohmann/json.hpp>

#include <string>

#include "sx/command.hpp"

namespace sx {

class AssemblySnapshotCommand : public Command {
public:
    AssemblySnapshotCommand(std::string label, nlohmann::json before, nlohmann::json after)
        : label_(std::move(label)), before_(std::move(before)), after_(std::move(after)) {}

    std::string label() const override { return label_; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;

private:
    static void restore(Document& doc, const nlohmann::json& snapshot);
    std::string label_;
    nlohmann::json before_;
    nlohmann::json after_;
};

// { "instances": [...], "mates": [...] } using Instance/Mate JSON schemas.
nlohmann::json assembly_to_json(const Document& doc);
void assembly_from_json(Document& doc, const nlohmann::json& snapshot);

}  // namespace sx
