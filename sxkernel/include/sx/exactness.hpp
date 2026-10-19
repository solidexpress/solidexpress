#pragma once
// Exactness probes: kernel curve/surface types, BRepGProp volume/area,
// and feature params as written. Later L/S WPs assert on this, not mesh.

#include <nlohmann/json.hpp>
#include <string>

#include "sx/ids.hpp"

class TopoDS_Edge;
class TopoDS_Face;
class TopoDS_Shape;

namespace sx {

class Document;
class Sketch;

namespace exactness {

const char* curve_type_name(int geom_abs_curve_type);
const char* surface_type_name(int geom_abs_surface_type);

nlohmann::json probe_edge(const TopoDS_Edge& edge);
nlohmann::json probe_face(const TopoDS_Face& face);
nlohmann::json probe_shape(const TopoDS_Shape& shape);

nlohmann::json report_body(const Document& doc, const EntityId& body);
nlohmann::json report_sketch(const Sketch& sketch);
nlohmann::json report_features(const Document& doc);
nlohmann::json report(const Document& doc);

// Builds a box with a through hole. Returns the box output body.
// diameter is the hole Ø (10 → circle radius 5).
EntityId add_box_hole(Document& doc, double dx, double dy, double dz, double diameter,
                      EntityId* box_fid = nullptr, EntityId* hole_fid = nullptr);

}  // namespace exactness
}  // namespace sx
