#pragma once
// Wave 4 spikes that still ship a user-visible benefit (L1). Each is a real
// kernel op, not a comment: config-aware BOM, C2 fillet tag, SubD-to-box
// rounding, PDM log, tube route, mold split, mesh boolean volume, gear ratio,
// PMI dim, IDF board outline.

#include <array>
#include <string>
#include <vector>

#include <TopoDS_Shape.hxx>

#include "sx/drawing_doc.hpp"
#include "sx/ids.hpp"

namespace sx {

class Document;

// 4.1 Config-aware BOM: same as instance BOM plus the active configuration name.
struct ConfigBom {
    std::string configuration;
    std::vector<BomRow> rows;
};
ConfigBom config_bom(const Document& doc);

// 4.2 C2 fillet: two-radius blend recorded as continuity="c2".
bool fillet_c2(Document& doc, const EntityId& body, const std::vector<int>& edges,
               double radius, double radius2, std::string* err = nullptr);

// 4.5 SubD spike: fillet every edge of a box (OpenSubdiv later). Returns volume.
double subd_round_box(Document& doc, const EntityId& body, double radius,
                      std::string* err = nullptr);

// 4.6 PDM-lite: append a version note; persisted in the document revision log.
struct PdmEntry {
    std::string message;
    uint64_t revision = 0;
};
void pdm_commit(Document& doc, const std::string& message);
std::vector<PdmEntry> pdm_log(const Document& doc);

// 4.7 Route a circular tube along a 3D polyline. Returns the solid.
TopoDS_Shape route_tube(const std::vector<std::array<double, 3>>& path, double radius,
                        std::string* err = nullptr);

// 4.8 Mold: split a solid by a plane into two bodies (core / cavity).
int mold_split(Document& doc, const EntityId& body, const std::array<double, 3>& point,
               const std::array<double, 3>& normal, std::string* err = nullptr);

// 4.9 Mesh boolean: fuse/cut a solid against another (mesh imported as a body).
double mesh_boolean_volume(Document& doc, const EntityId& a, const EntityId& b,
                           const std::string& op, std::string* err = nullptr);

// 4.10 Gear ratio on a revolute pair: driven = driver * ratio.
double gear_driven_angle(double driver_angle, double ratio);

// 4.11 PMI: a 3D linear dim stored like a drawing dim, measured in model space.
struct PmiDim {
    EntityId id;
    EntityId a;
    EntityId b;
    double value = 0.0;
};
EntityId add_pmi_dim(Document& doc, const EntityId& a, const EntityId& b);
double pmi_value(const Document& doc, const EntityId& dim_id);

// 4.13 Minimal IDF board: a rectangle outline as a sketch (not a schematic).
int import_idf_board(Document& doc, double width, double height, std::string* err = nullptr);

}  // namespace sx
