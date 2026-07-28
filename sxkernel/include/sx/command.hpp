#pragma once
// Undo/redo command stack. Every model mutation goes through a Command so the
// stack doubles as an operation log (future collaboration groundwork).

#include <memory>
#include <string>
#include <vector>

namespace sx {

class Document;

class Command {
public:
    virtual ~Command() = default;
    virtual std::string label() const = 0;
    virtual void execute(Document& doc) = 0;
    virtual void undo(Document& doc) = 0;
    // redo defaults to execute; override when execute has one-shot side effects.
    virtual void redo(Document& doc) { execute(doc); }
};

class CommandStack {
public:
    // Executes and takes ownership. Clears the redo list.
    void push(Document& doc, std::unique_ptr<Command> cmd);
    // Takes ownership without executing — for callers that already applied the
    // mutation (e.g. graph edit + regenerate). Undo/redo still work via the
    // command's undo/execute. Clears the redo list.
    void push_executed(std::unique_ptr<Command> cmd);
    bool can_undo() const { return !done_.empty(); }
    bool can_redo() const { return !undone_.empty(); }
    bool undo(Document& doc);
    bool redo(Document& doc);
    size_t depth() const { return done_.size(); }
    std::vector<std::string> labels() const;

private:
    std::vector<std::unique_ptr<Command>> done_;
    std::vector<std::unique_ptr<Command>> undone_;
};

}  // namespace sx
