#include "sx/commands_hollow.hpp"

#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <TopoDS.hxx>
#include "sx/occt_types.hpp"

#include <stdexcept>

#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

namespace sx {

namespace {
std::shared_ptr<void> snapshot(const Body& b) {
    return std::make_shared<Body>(b);
}
const Body& snap(const std::shared_ptr<void>& p) {
    return *static_cast<const Body*>(p.get());
}

// Resolve face ids; all must be Face subshapes of the same body.
EntityId validate_faces(Document& doc, const std::vector<EntityId>& faces, const char* what) {
    if (faces.empty())
        throw std::invalid_argument(std::string(what) + ": no faces");

    EntityId body_id;
    for (const auto& fid : faces) {
        auto ref = doc.find_subshape(fid);
        if (!ref || ref->kind != EntityKind::Face)
            throw std::invalid_argument(std::string(what) + ": id is not a face");
        if (body_id.is_null()) {
            body_id = ref->body;
        } else if (body_id != ref->body) {
            throw std::invalid_argument(std::string(what) + ": faces belong to different bodies");
        }
    }
    return body_id;
}
}  // namespace

// --- ShellCommand ---

void ShellCommand::execute(Document& doc) {
    body_ = validate_faces(doc, faces_, "ShellCommand");
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("ShellCommand: body missing");

    saved_before_ = snapshot(*b);

    sx::occt::ShapeList remove_faces;
    for (const auto& fid : faces_) {
        TopoDS_Shape s = doc.resolve(fid);
        if (s.IsNull()) throw std::invalid_argument("ShellCommand: face not found");
        remove_faces.Append(s);
    }

    BRepOffsetAPI_MakeThickSolid mk;
    mk.MakeThickSolidByJoin(b->shape, remove_faces, -thickness_, 1e-3);
    if (!mk.IsDone())
        throw std::runtime_error("ShellCommand: thick solid failed");

    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        throw std::runtime_error("ShellCommand: result is null or invalid");

    doc.replace_body_shape(body_, result);
    saved_after_ = snapshot(*doc.body(body_));
}

void ShellCommand::undo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_before_);
    doc.restore_body(std::move(copy));
}

void ShellCommand::redo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_after_);
    doc.restore_body(std::move(copy));
}

// --- OffsetBodyCommand ---

void OffsetBodyCommand::execute(Document& doc) {
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("OffsetBodyCommand: no such body");

    saved_before_ = snapshot(*b);

    BRepOffsetAPI_MakeOffsetShape mk;
    mk.PerformByJoin(b->shape, offset_, 1e-3);
    if (!mk.IsDone())
        throw std::runtime_error("OffsetBodyCommand: offset failed");

    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        throw std::runtime_error("OffsetBodyCommand: result is null or invalid");

    doc.replace_body_shape(body_, result);
    saved_after_ = snapshot(*doc.body(body_));
}

void OffsetBodyCommand::undo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_before_);
    doc.restore_body(std::move(copy));
}

void OffsetBodyCommand::redo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_after_);
    doc.restore_body(std::move(copy));
}

}  // namespace sx
