#include "sx/command.hpp"

#include "sx/document.hpp"

namespace sx {

void CommandStack::push(Document& doc, std::unique_ptr<Command> cmd) {
    cmd->execute(doc);
    done_.push_back(std::move(cmd));
    undone_.clear();
}

void CommandStack::push_executed(std::unique_ptr<Command> cmd) {
    done_.push_back(std::move(cmd));
    undone_.clear();
}

bool CommandStack::undo(Document& doc) {
    if (done_.empty()) return false;
    done_.back()->undo(doc);
    undone_.push_back(std::move(done_.back()));
    done_.pop_back();
    return true;
}

bool CommandStack::redo(Document& doc) {
    if (undone_.empty()) return false;
    undone_.back()->redo(doc);
    done_.push_back(std::move(undone_.back()));
    undone_.pop_back();
    return true;
}

std::vector<std::string> CommandStack::labels() const {
    std::vector<std::string> out;
    out.reserve(done_.size());
    for (const auto& c : done_) out.push_back(c->label());
    return out;
}

}  // namespace sx
