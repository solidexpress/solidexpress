#pragma once
// Print-first setup and analysis (docs/survey/print-first.md).
// Orientation lives on the document; the design solid is not silently rotated.

#include <array>
#include <string>
#include <utility>
#include <vector>

#include <nlohmann/json.hpp>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct PrintSetup {
    double bed_x = 220.0;
    double bed_y = 220.0;
    double bed_z = 250.0;
    double layer_height = 0.2;
    double min_wall = 1.2;
    double overhang_deg = 45.0;
    double nozzle_mm = 0.4;
    std::string material = "PLA";
    // Body → print-space rotation, row-major 3×3. Identity = design +Z is up.
    std::array<double, 9> rot{1, 0, 0, 0, 1, 0, 0, 0, 1};
};

struct PrintReport {
    double min_wall = 0.0;
    double overhang_area = 0.0;
    double height = 0.0;
    double bbox_x = 0.0;
    double bbox_y = 0.0;
    bool fits_bed = true;
    bool wall_ok = true;
    bool overhang_ok = true;
    std::string digest;
    // --- Wave 6.3 paint data ---
    // Faces whose local thickness is below PrintSetup::min_wall (ids in
    // TopExp::MapShapes order for the owning body).
    std::vector<EntityId> thin_faces;
    // Per-face overhang area (mm^2) for faces that exceed the overhang
    // threshold (face normal steeper than overhang_deg away from up), keyed
    // by face id. Faces not present have zero overhang area.
    std::vector<std::pair<EntityId, double>> overhang_face_areas;
};

PrintReport print_analyze(const Document& doc, const EntityId& body);
PrintReport print_orient(Document& doc, const EntityId& body);

void to_json(nlohmann::json& j, const PrintSetup& s);
void from_json(const nlohmann::json& j, PrintSetup& s);

}  // namespace sx
