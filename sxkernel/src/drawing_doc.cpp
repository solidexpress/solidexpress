#include "sx/drawing_doc.hpp"

#include <algorithm>
#include <cmath>
#include <map>

#include <BRepAlgoAPI_Section.hxx>
#include <BRep_Builder.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"

namespace sx {
namespace {

nlohmann::json arr3(const std::array<double, 3>& a) { return {a[0], a[1], a[2]}; }

std::array<double, 3> arr3_from(const nlohmann::json& j, std::array<double, 3> fallback) {
    if (!j.is_array() || j.size() < 3) return fallback;
    return {j[0].get<double>(), j[1].get<double>(), j[2].get<double>()};
}

TopoDS_Shape compound_all(const Document& doc) {
    TopoDS_Compound comp;
    BRep_Builder builder;
    builder.MakeCompound(comp);
    int n = 0;
    for (const auto& id : doc.body_ids()) {
        const Body* b = doc.body(id);
        if (!b || b->shape.IsNull()) continue;
        builder.Add(comp, b->shape);
        ++n;
    }
    return n == 0 ? TopoDS_Shape() : TopoDS_Shape(comp);
}

}  // namespace

void to_json(nlohmann::json& j, const DrawingDim& d) {
    j = nlohmann::json{{"id", d.id.str()},
                       {"view_id", d.view_id.str()},
                       {"a", d.a.str()},
                       {"b", d.b.str()},
                       {"kind", d.kind},
                       {"value", d.value}};
}

void from_json(const nlohmann::json& j, DrawingDim& d) {
    if (j.contains("id")) d.id = EntityId::from_string(j.at("id").get<std::string>());
    if (j.contains("view_id")) d.view_id = EntityId::from_string(j.at("view_id").get<std::string>());
    if (j.contains("a")) d.a = EntityId::from_string(j.at("a").get<std::string>());
    if (j.contains("b") && !j.at("b").get<std::string>().empty())
        d.b = EntityId::from_string(j.at("b").get<std::string>());
    d.kind = j.value("kind", "linear");
    d.value = j.value("value", 0.0);
}

void to_json(nlohmann::json& j, const DrawingView& v) {
    j = nlohmann::json{{"id", v.id.str()},
                       {"name", v.name},
                       {"kind", v.kind},
                       {"dir", arr3(v.dir)},
                       {"up", arr3(v.up)},
                       {"scale", v.scale},
                       {"offset_x", v.offset_x},
                       {"offset_y", v.offset_y},
                       {"section_point", arr3(v.section_point)},
                       {"section_normal", arr3(v.section_normal)}};
}

void from_json(const nlohmann::json& j, DrawingView& v) {
    if (j.contains("id")) v.id = EntityId::from_string(j.at("id").get<std::string>());
    v.name = j.value("name", "Front");
    v.kind = j.value("kind", "ortho");
    if (j.contains("dir")) v.dir = arr3_from(j.at("dir"), v.dir);
    if (j.contains("up")) v.up = arr3_from(j.at("up"), v.up);
    v.scale = j.value("scale", 1.0);
    v.offset_x = j.value("offset_x", 0.0);
    v.offset_y = j.value("offset_y", 0.0);
    if (j.contains("section_point")) v.section_point = arr3_from(j.at("section_point"), v.section_point);
    if (j.contains("section_normal"))
        v.section_normal = arr3_from(j.at("section_normal"), v.section_normal);
}

void to_json(nlohmann::json& j, const DrawingSheetDoc& s) {
    j = nlohmann::json{{"id", s.id.str()},
                       {"name", s.name},
                       {"title", s.title},
                       {"scale", s.scale},
                       {"show_bom", s.show_bom},
                       {"views", s.views},
                       {"dims", s.dims}};
}

void from_json(const nlohmann::json& j, DrawingSheetDoc& s) {
    if (j.contains("id")) s.id = EntityId::from_string(j.at("id").get<std::string>());
    s.name = j.value("name", "Sheet1");
    s.title = j.value("title", "SOLIDEXPRESS");
    s.scale = j.value("scale", 1.0);
    s.show_bom = j.value("show_bom", false);
    if (j.contains("views")) s.views = j.at("views").get<std::vector<DrawingView>>();
    if (j.contains("dims")) s.dims = j.at("dims").get<std::vector<DrawingDim>>();
}

void to_json(nlohmann::json& j, const CosmeticWeld& w) {
    j = nlohmann::json{{"id", w.id.str()},
                       {"edge", w.edge.str()},
                       {"symbol", w.symbol},
                       {"size", w.size}};
}

void from_json(const nlohmann::json& j, CosmeticWeld& w) {
    if (j.contains("id")) w.id = EntityId::from_string(j.at("id").get<std::string>());
    if (j.contains("edge")) w.edge = EntityId::from_string(j.at("edge").get<std::string>());
    w.symbol = j.value("symbol", "fillet");
    w.size = j.value("size", 3.0);
}

EntityId ensure_drawing_sheet(Document& doc) {
    if (!doc.drawing_sheets().empty()) return doc.drawing_sheets().front().id;
    DrawingSheetDoc sheet;
    sheet.id = EntityId::generate();
    sheet.name = "Sheet1";
    sheet.title = "SOLIDEXPRESS";
    auto add_view = [&](const char* name, std::array<double, 3> dir, std::array<double, 3> up,
                        double ox, double oy) {
        DrawingView v;
        v.id = EntityId::generate();
        v.name = name;
        v.kind = "ortho";
        v.dir = dir;
        v.up = up;
        v.offset_x = ox;
        v.offset_y = oy;
        sheet.views.push_back(v);
    };
    add_view("Front", {0, 1, 0}, {0, 0, 1}, 0, 0);
    add_view("Top", {0, 0, -1}, {0, 1, 0}, 0, 80);
    add_view("Right", {-1, 0, 0}, {0, 0, 1}, 80, 0);
    return doc.add_drawing_sheet(std::move(sheet));
}

double measure_dim_value(const Document& doc, const DrawingDim& dim) {
    if (dim.a.is_null()) return 0.0;
    if (dim.b.is_null() || dim.b == dim.a) {
        auto bb = measure::bounding_box(doc, dim.a);
        if (!bb) return 0.0;
        return bb->max[0] - bb->min[0];
    }
    if (auto d = measure::min_distance(doc, dim.a, dim.b)) return d->distance;
    auto ba = measure::bounding_box(doc, dim.a);
    auto bb = measure::bounding_box(doc, dim.b);
    if (!ba || !bb) return 0.0;
    return std::abs((ba->max[0] + ba->min[0]) * 0.5 - (bb->max[0] + bb->min[0]) * 0.5);
}

EntityId add_drawing_dim(Document& doc, const EntityId& sheet, const EntityId& view,
                         const EntityId& a, const EntityId& b) {
    DrawingSheetDoc* s = doc.drawing_sheet_mut(sheet);
    if (!s) {
        ensure_drawing_sheet(doc);
        s = doc.drawing_sheet_mut(doc.drawing_sheets().front().id);
    }
    if (!s) return {};
    DrawingDim d;
    d.id = EntityId::generate();
    d.view_id = view.is_null() && !s->views.empty() ? s->views.front().id : view;
    d.a = a;
    d.b = b;
    d.value = measure_dim_value(doc, d);
    s->dims.push_back(d);
    doc.bump_revision();
    return d.id;
}

int refresh_drawing_dims(Document& doc) {
    int n = 0;
    for (auto& sheet : doc.drawing_sheets_mut()) {
        for (auto& d : sheet.dims) {
            d.value = measure_dim_value(doc, d);
            ++n;
        }
    }
    if (n > 0) doc.bump_revision();
    return n;
}

std::vector<BomRow> bom_from_instances(const Document& doc) {
    std::map<std::string, BomRow> by;
    for (const auto& inst : doc.instances()) {
        const std::string key = inst.name.empty() ? inst.source_body.str() : inst.name;
        auto& row = by[key];
        row.name = key;
        row.qty += 1;
        row.source = inst.source_path;
    }
    std::vector<BomRow> out;
    int item = 1;
    for (auto& [k, row] : by) {
        row.item = item++;
        out.push_back(row);
    }
    return out;
}

drawings::ViewProjection project_drawing_view(const Document& doc, const DrawingView& view) {
    TopoDS_Shape all = compound_all(doc);
    if (all.IsNull()) return {};
    gp_Dir dir(view.dir[0], view.dir[1], view.dir[2]);
    gp_Dir up(view.up[0], view.up[1], view.up[2]);
    if (view.kind == "section") {
        gp_Pnt p(view.section_point[0], view.section_point[1], view.section_point[2]);
        gp_Dir n(view.section_normal[0], view.section_normal[1], view.section_normal[2]);
        try {
            BRepAlgoAPI_Section sec(all, gp_Pln(p, n), false);
            sec.ComputePCurveOn1(true);
            sec.Approximation(true);
            sec.Build();
            if (sec.IsDone() && !sec.Shape().IsNull()) all = sec.Shape();
        } catch (...) {
        }
    }
    return drawings::project(all, dir, up);
}

std::vector<drawings::Polyline2> section_hatch(const Document& doc, const DrawingView& view,
                                               double spacing) {
    std::vector<drawings::Polyline2> hatch;
    if (view.kind != "section") return hatch;
    auto proj = project_drawing_view(doc, view);
    if (proj.max_x <= proj.min_x || proj.max_y <= proj.min_y) return hatch;
    const double step = spacing > 1e-6 ? spacing : 4.0;
    for (double x = proj.min_x; x <= proj.max_x + 1e-9; x += step) {
        hatch.push_back({{x, proj.min_y}, {x + (proj.max_y - proj.min_y) * 0.15, proj.max_y}});
    }
    return hatch;
}

}  // namespace sx
