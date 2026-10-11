#pragma once
// A TopoCue is one geometric reference to a face or an edge.
// resolve() walks a fixed strategy list; callers do not choose the order.

#include <nlohmann/json.hpp>

#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>

#include "sx/entity.hpp"

#include <string>

namespace sx {

class Document;
struct Body;

struct Vec3 {
    double x = 0;
    double y = 0;
    double z = 0;
};

struct TopoCue {
    Vec3 point;
    Vec3 dir;
    Vec3 size;
    Vec3 frac;
    double tol = 0.5;
    // Old cues store point and dir only. Relative matching stays off until
    // a fraction of the input shape's bounding box was recorded.
    bool has_frac = false;
};

struct Resolution {
    bool found = false;
    TopoDS_Shape shape;
    std::string lost;
};

// The shape a cue is resolved against, plus the reference the feature stored.
struct ShapeIndex {
    TopoDS_Shape shape;
    EntityKind kind = EntityKind::Edge;
    nlohmann::json ref;
    Document* doc = nullptr;
    const Body* body = nullptr;
};

Resolution resolve(const TopoCue& cue, const ShapeIndex& index);

TopoCue cue_from_edge(const TopoDS_Edge& edge, const TopoDS_Shape& owner);
TopoCue cue_from_face(const TopoDS_Face& face, const TopoDS_Shape& owner);
nlohmann::json cue_to_json(const TopoCue& cue);
TopoCue cue_from_json(const nlohmann::json& j);

// The stored cue still names this line (direction aligned, point within tol
// of the axis). Used so a rebuilt id is not allowed to overwrite the cue.
bool cue_names_line(const TopoCue& cue, const Vec3& point, const Vec3& dir);

// The stored cue still names this face (normal aligned, point on its plane).
bool cue_names_face(const TopoCue& stored, const TopoCue& fresh);

}  // namespace sx
