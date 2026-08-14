#include "sx/dxf.hpp"

#include <cctype>
#include <cmath>
#include <fstream>
#include <sstream>

#include <BRep_Builder.hxx>
#include <gp_Dir.hxx>

#include "sx/document.hpp"
#include "sx/drawing_doc.hpp"
#include "sx/drawings.hpp"
#include "sx/features.hpp"

namespace sx {
namespace {

std::string trim(std::string s) {
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(s.begin());
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    return s;
}

bool next_pair(std::istream& in, int& code, std::string& value) {
    std::string line;
    if (!std::getline(in, line)) return false;
    try {
        code = std::stoi(trim(line));
    } catch (...) {
        return false;
    }
    if (!std::getline(in, value)) return false;
    value = trim(value);
    return true;
}

}  // namespace

std::vector<DxfEntity> read_dxf(const std::string& path, std::string* err) {
    std::ifstream in(path);
    if (!in) {
        if (err) *err = "cannot open DXF " + path;
        return {};
    }
    std::vector<DxfEntity> out;
    bool in_entities = false;
    int code = 0;
    std::string value;
    DxfEntity cur;
    bool have = false;
    auto flush = [&] {
        if (!have) return;
        if (cur.kind == DxfEntity::Kind::Line || cur.radius > 0.0) out.push_back(cur);
        have = false;
        cur = {};
    };
    while (next_pair(in, code, value)) {
        if (code == 0 && value == "SECTION") {
            int c2 = 0;
            std::string v2;
            if (next_pair(in, c2, v2) && c2 == 2 && v2 == "ENTITIES") in_entities = true;
            continue;
        }
        if (code == 0 && value == "ENDSEC") {
            if (in_entities) flush();
            in_entities = false;
            continue;
        }
        if (!in_entities) continue;
        if (code == 0) {
            flush();
            if (value == "LINE") {
                cur.kind = DxfEntity::Kind::Line;
                have = true;
            } else if (value == "CIRCLE") {
                cur.kind = DxfEntity::Kind::Circle;
                have = true;
            } else if (value == "ARC") {
                cur.kind = DxfEntity::Kind::Arc;
                have = true;
            } else if (value == "LWPOLYLINE" || value == "POLYLINE") {
                // Treat as a sequence of LINE vertices collected below.
                cur.kind = DxfEntity::Kind::Line;
                have = false;
            }
            continue;
        }
        if (!have) continue;
        switch (code) {
            case 10: cur.x1 = std::stod(value); cur.cx = cur.x1; break;
            case 20: cur.y1 = std::stod(value); cur.cy = cur.y1; break;
            case 11: cur.x2 = std::stod(value); break;
            case 21: cur.y2 = std::stod(value); break;
            case 40: cur.radius = std::stod(value); break;
            case 50: cur.start_angle = std::stod(value); break;
            case 51: cur.end_angle = std::stod(value); break;
            default: break;
        }
    }
    flush();
    if (out.empty() && err) *err = "no LINE/CIRCLE/ARC entities in " + path;
    return out;
}

int add_dxf_to_sketch(Sketch& sketch, const std::vector<DxfEntity>& entities) {
    int n = 0;
    for (const auto& e : entities) {
        if (e.kind == DxfEntity::Kind::Line) {
            sketch.add_line(e.x1, e.y1, e.x2, e.y2);
            ++n;
        } else if (e.kind == DxfEntity::Kind::Circle) {
            sketch.add_circle(e.cx, e.cy, e.radius);
            ++n;
        } else if (e.kind == DxfEntity::Kind::Arc) {
            const double s = e.start_angle * M_PI / 180.0;
            const double t = e.end_angle * M_PI / 180.0;
            sketch.add_arc(e.cx, e.cy, e.radius, s, t);
            ++n;
        }
    }
    return n;
}

EntityId import_dxf_sketch(Document& doc, const std::string& path, std::string* err) {
    auto ents = read_dxf(path, err);
    if (ents.empty()) return {};
    auto sk = std::make_shared<Sketch>("DXF");
    if (add_dxf_to_sketch(*sk, ents) == 0) {
        if (err) *err = "DXF produced no sketch entities";
        return {};
    }
    Feature f;
    f.type = FeatureType::Sketch;
    f.name = "DXF";
    f.sketch = std::move(sk);
    return doc.graph().add(std::move(f));
}

bool write_dxf(const std::vector<DxfEntity>& entities, const std::string& path, std::string* err) {
    std::ofstream out(path);
    if (!out) {
        if (err) *err = "cannot write DXF " + path;
        return false;
    }
    auto pair = [&](int code, const std::string& v) { out << code << "\n" << v << "\n"; };
    auto num = [&](int code, double v) {
        out << code << "\n" << v << "\n";
    };
    pair(0, "SECTION");
    pair(2, "ENTITIES");
    for (const auto& e : entities) {
        if (e.kind == DxfEntity::Kind::Line) {
            pair(0, "LINE");
            pair(8, "0");
            num(10, e.x1);
            num(20, e.y1);
            num(11, e.x2);
            num(21, e.y2);
        } else if (e.kind == DxfEntity::Kind::Circle) {
            pair(0, "CIRCLE");
            pair(8, "0");
            num(10, e.cx);
            num(20, e.cy);
            num(40, e.radius);
        } else if (e.kind == DxfEntity::Kind::Arc) {
            pair(0, "ARC");
            pair(8, "0");
            num(10, e.cx);
            num(20, e.cy);
            num(40, e.radius);
            num(50, e.start_angle);
            num(51, e.end_angle);
        }
    }
    pair(0, "ENDSEC");
    pair(0, "EOF");
    return true;
}

bool export_drawing_dxf(const Document& doc, const std::string& path, std::string* err) {
    std::vector<DxfEntity> ents;
    auto add_proj = [&](const drawings::ViewProjection& v, double ox, double oy) {
        auto add_poly = [&](const drawings::Polyline2& pl) {
            for (size_t i = 1; i < pl.size(); ++i) {
                DxfEntity e;
                e.kind = DxfEntity::Kind::Line;
                e.x1 = pl[i - 1][0] + ox;
                e.y1 = pl[i - 1][1] + oy;
                e.x2 = pl[i][0] + ox;
                e.y2 = pl[i][1] + oy;
                ents.push_back(e);
            }
        };
        for (const auto& pl : v.visible) add_poly(pl);
        for (const auto& pl : v.hidden) add_poly(pl);
    };
    if (!doc.drawing_sheets().empty()) {
        for (const auto& view : doc.drawing_sheets().front().views) {
            add_proj(project_drawing_view(doc, view), view.offset_x, view.offset_y);
        }
    } else {
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
        if (n == 0) {
            if (err) *err = "empty document";
            return false;
        }
        add_proj(drawings::project(comp, gp_Dir(0, 1, 0), gp_Dir(0, 0, 1)), 0, 0);
    }
    if (ents.empty()) {
        if (err) *err = "drawing produced no entities";
        return false;
    }
    return write_dxf(ents, path, err);
}

}  // namespace sx
