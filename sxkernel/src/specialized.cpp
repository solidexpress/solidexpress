#include "sx/specialized.hpp"

#include <cmath>
#include <memory>

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

namespace sx {

ConfigBom config_bom(const Document& doc) {
    ConfigBom out;
    out.configuration = doc.active_configuration();
    out.rows = bom_from_instances(doc);
    return out;
}

bool fillet_c2(Document& doc, const EntityId& body, const std::vector<int>& edges, double radius,
               double radius2, std::string* err) {
    const Body* b = doc.body(body);
    if (!b) {
        if (err) *err = "fillet_c2 needs a body";
        return false;
    }
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(b->shape, TopAbs_EDGE, map);
    try {
        BRepFilletAPI_MakeFillet mk(b->shape);
        for (int idx : edges) {
            if (idx < 1 || idx > map.Extent()) continue;
            if (radius2 > 0.0 && std::abs(radius2 - radius) > 1e-9)
                mk.Add(radius, radius2, TopoDS::Edge(map(idx)));
            else
                mk.Add(radius, TopoDS::Edge(map(idx)));
        }
        mk.Build();
        if (!mk.IsDone()) {
            if (err) *err = "C2 fillet failed";
            return false;
        }
        doc.replace_body_shape(body, mk.Shape());
        return true;
    } catch (...) {
        if (err) *err = "C2 fillet threw";
        return false;
    }
}

double subd_round_box(Document& doc, const EntityId& body, double radius, std::string* err) {
    const Body* b = doc.body(body);
    if (!b) {
        if (err) *err = "subd needs a body";
        return 0.0;
    }
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(b->shape, TopAbs_EDGE, map);
    std::vector<int> edges;
    for (int i = 1; i <= map.Extent(); ++i) edges.push_back(i);
    if (!fillet_c2(doc, body, edges, radius, radius, err)) return 0.0;
    return shape::volume(doc.body(body)->shape);
}

void pdm_commit(Document& doc, const std::string& message) { doc.add_pdm_entry(message); }

std::vector<PdmEntry> pdm_log(const Document& doc) {
    std::vector<PdmEntry> out;
    for (const auto& [msg, rev] : doc.pdm_entries()) out.push_back({msg, rev});
    return out;
}

TopoDS_Shape route_tube(const std::vector<std::array<double, 3>>& path, double radius,
                        std::string* err) {
    if (path.size() < 2 || radius <= 0.0) {
        if (err) *err = "tube needs two points and a radius";
        return {};
    }
    try {
        BRepBuilderAPI_MakeWire wire;
        for (size_t i = 1; i < path.size(); ++i) {
            gp_Pnt a(path[i - 1][0], path[i - 1][1], path[i - 1][2]);
            gp_Pnt b(path[i][0], path[i][1], path[i][2]);
            if (a.Distance(b) < 1e-9) continue;
            wire.Add(BRepBuilderAPI_MakeEdge(a, b).Edge());
        }
        if (!wire.IsDone()) {
            if (err) *err = "tube path is not a wire";
            return {};
        }
        const auto& p0 = path[0];
        const auto& p1 = path[1];
        gp_Vec along(p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]);
        if (along.Magnitude() < 1e-9) {
            if (err) *err = "tube start is degenerate";
            return {};
        }
        gp_Circ circ(gp_Ax2(gp_Pnt(p0[0], p0[1], p0[2]), gp_Dir(along)), radius);
        TopoDS_Wire profile = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(circ).Edge());
        TopoDS_Shape tube = BRepOffsetAPI_MakePipe(wire.Wire(), profile).Shape();
        if (tube.IsNull() && err) *err = "pipe failed";
        return tube;
    } catch (...) {
        if (err) *err = "route_tube threw";
        return {};
    }
}

int mold_split(Document& doc, const EntityId& body, const std::array<double, 3>& point,
               const std::array<double, 3>& normal, std::string* err) {
    const Body* b = doc.body(body);
    if (!b) {
        if (err) *err = "mold needs a body";
        return 0;
    }
    try {
        gp_Pnt p(point[0], point[1], point[2]);
        gp_Dir n(normal[0], normal[1], normal[2]);
        shape::Placement pl;
        pl.origin = {p.X() + n.X() * 500.0 - 500.0, p.Y() + n.Y() * 500.0 - 500.0,
                     p.Z() + n.Z() * 500.0 - 500.0};
        pl.z_dir = {n.X(), n.Y(), n.Z()};
        TopoDS_Shape cutter = shape::make_box(1000, 1000, 1000, pl);
        BRepAlgoAPI_Cut cut(b->shape, cutter);
        if (!cut.IsDone()) {
            if (err) *err = "mold cut failed";
            return 0;
        }
        doc.add_body(cut.Shape(), "Cavity");
        BRepAlgoAPI_Common common(b->shape, cutter);
        if (common.IsDone()) doc.add_body(common.Shape(), "Core");
        return 2;
    } catch (...) {
        if (err) *err = "mold_split threw";
        return 0;
    }
}

double mesh_boolean_volume(Document& doc, const EntityId& a, const EntityId& b,
                           const std::string& op, std::string* err) {
    const Body* ba = doc.body(a);
    const Body* bb = doc.body(b);
    if (!ba || !bb) {
        if (err) *err = "mesh boolean needs two bodies";
        return -1.0;
    }
    try {
        TopoDS_Shape out;
        if (op == "cut") {
            BRepAlgoAPI_Cut cut(ba->shape, bb->shape);
            if (!cut.IsDone()) return -1.0;
            out = cut.Shape();
        } else {
            BRepAlgoAPI_Fuse fuse(ba->shape, bb->shape);
            if (!fuse.IsDone()) return -1.0;
            out = fuse.Shape();
        }
        return shape::volume(out);
    } catch (...) {
        if (err) *err = "mesh boolean threw";
        return -1.0;
    }
}

double gear_driven_angle(double driver_angle, double ratio) { return driver_angle * ratio; }

EntityId add_pmi_dim(Document& doc, const EntityId& a, const EntityId& b) {
    const EntityId sheet = ensure_drawing_sheet(doc);
    const DrawingSheetDoc* s = doc.drawing_sheet(sheet);
    const EntityId view = (s && !s->views.empty()) ? s->views.front().id : EntityId{};
    return add_drawing_dim(doc, sheet, view, a, b);
}

double pmi_value(const Document& doc, const EntityId& dim_id) {
    for (const auto& sheet : doc.drawing_sheets()) {
        for (const auto& d : sheet.dims) {
            if (d.id == dim_id) return d.value;
        }
    }
    return 0.0;
}

int import_idf_board(Document& doc, double width, double height, std::string* err) {
    if (width <= 0.0 || height <= 0.0) {
        if (err) *err = "board needs positive size";
        return 0;
    }
    Feature f;
    f.type = FeatureType::Sketch;
    f.name = "IDF board";
    f.sketch = std::make_shared<Sketch>("IDF");
    f.sketch->add_line(0, 0, width, 0);
    f.sketch->add_line(width, 0, width, height);
    f.sketch->add_line(width, height, 0, height);
    f.sketch->add_line(0, height, 0, 0);
    doc.graph().add(std::move(f));
    return 4;
}

}  // namespace sx
