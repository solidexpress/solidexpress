#pragma once
// Drawing document (Wave 1.6–1.8): sheets, views, associative dims, BOM.
// Views are stored in the .sxp; HLR is computed on demand from the live model.

#include <array>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "sx/drawings.hpp"
#include "sx/ids.hpp"

namespace sx {

class Document;

struct DrawingDim {
    EntityId id;
    EntityId view_id;
    EntityId a;  // naming UUID (body, face, or edge)
    EntityId b;
    std::string kind = "linear";
    double value = 0.0;  // last measured, refreshed on preview
};

struct DrawingView {
    EntityId id;
    std::string name = "Front";
    std::string kind = "ortho";  // ortho | section | detail | flat
    std::array<double, 3> dir{0, 1, 0};
    std::array<double, 3> up{0, 0, 1};
    double scale = 1.0;
    double offset_x = 0.0;
    double offset_y = 0.0;
    std::array<double, 3> section_point{0, 0, 0};
    std::array<double, 3> section_normal{0, 1, 0};
};

struct BomRow {
    int item = 0;
    std::string name;
    int qty = 0;
    std::string source;
};

struct CosmeticWeld {
    EntityId id;
    EntityId edge;
    std::string symbol = "fillet";
    double size = 3.0;
};

struct DrawingSheetDoc {
    EntityId id;
    std::string name = "Sheet1";
    std::string title = "SOLIDEXPRESS";
    double scale = 1.0;
    bool show_bom = false;
    std::vector<DrawingView> views;
    std::vector<DrawingDim> dims;
};

void to_json(nlohmann::json& j, const DrawingDim& d);
void from_json(const nlohmann::json& j, DrawingDim& d);
void to_json(nlohmann::json& j, const DrawingView& v);
void from_json(const nlohmann::json& j, DrawingView& v);
void to_json(nlohmann::json& j, const DrawingSheetDoc& s);
void from_json(const nlohmann::json& j, DrawingSheetDoc& s);
void to_json(nlohmann::json& j, const CosmeticWeld& w);
void from_json(const nlohmann::json& j, CosmeticWeld& w);

// Ensure the document has a third-angle three-view sheet. Returns its id.
EntityId ensure_drawing_sheet(Document& doc);

// Linear dim between two named entities (or the X-extent of one body when b is
// null). Value is the live 3D measurement — that is what "associative" means.
EntityId add_drawing_dim(Document& doc, const EntityId& sheet, const EntityId& view,
                         const EntityId& a, const EntityId& b = {});

// Refresh every dim value from the live model. Returns how many updated.
int refresh_drawing_dims(Document& doc);

// Instance quantities, grouped by source-body name.
std::vector<BomRow> bom_from_instances(const Document& doc);

// HLR (+ optional hatch) for one stored view.
drawings::ViewProjection project_drawing_view(const Document& doc, const DrawingView& view);

// Hatch lines for a section view (empty for ortho).
std::vector<drawings::Polyline2> section_hatch(const Document& doc, const DrawingView& view,
                                               double spacing = 4.0);

// Measure a dim from the live model (X-extent when b is null).
double measure_dim_value(const Document& doc, const DrawingDim& dim);

}  // namespace sx
