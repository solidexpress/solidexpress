#include "ops.hpp"

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Wire.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>

#include "sx/occt_types.hpp"
#include "sx/curves.hpp"
#include "sx/document.hpp"
#include "sx/interop.hpp"
#include "sx/log.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sheet_metal.hpp"
#include "sx/sketch3d.hpp"
#include "sx/solver.hpp"
#include "sx/surface_ops.hpp"
#include "sx/xref.hpp"

#include <algorithm>
#include <cmath>

using nlohmann::json;

namespace sx::feature_ops {

bool apply_import(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                // File is re-read on every regenerate; path is an external
                // document dependency (acceptable for this BASE feature).
                if (!params.contains("path") || !params["path"].is_string())
                    return fail("missing path");
                const std::string path = params["path"].get<std::string>();
                const double scale = num_param(params, "scale", 1.0, env);
                const bool is_stl = f.type == FeatureType::ImportStl;

                Document tmp;
                std::string ierr;
                auto ids = is_stl ? interop::import_stl(tmp, path, &ierr)
                                  : interop::import_step(tmp, path, &ierr);
                if (ids.empty())
                    return fail(ierr.empty()
                                    ? (is_stl ? "STL import failed" : "STEP import failed")
                                    : ierr);
                const int index = is_stl ? 0 : params.value("index", 0);
                if (index < 0 || static_cast<size_t>(index) >= ids.size())
                    return fail("shape index out of range");
                const Body* src = tmp.body(ids[static_cast<size_t>(index)]);
                if (!src || src->shape.IsNull()) return fail("imported shape is null");

                TopoDS_Shape result = src->shape;
                if (std::abs(scale - 1.0) > 1e-15) {
                    if (scale <= 0.0) return fail("scale must be positive");
                    gp_Trsf t;
                    t.SetScale(gp_Pnt(0, 0, 0), scale);
                    result = BRepBuilderAPI_Transform(result, t, /*copy=*/true).Shape();
                    if (result.IsNull() || !shape::is_valid(result))
                        return fail("scale transform failed");
                }
                if (params.value("heal", true) && !is_stl) {
                    std::string report;
                    result = interop::heal_shape(result, &report);
                    f.params["heal_report"] = report;
                }
                put_body(doc, f.output_body, result, f.name);
                return true;
            
}
bool apply_direct_edit(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                TopoDS_Shape face_shape;
                if (params.contains("face") && params["face"].is_string()) {
                    face_shape = doc.resolve(EntityId::from_string(params["face"].get<std::string>()));
                } else if (params.contains("face_index")) {
                    sx::occt::ShapeIndexedMap faces;
                    TopExp::MapShapes(tb->shape, TopAbs_FACE, faces);
                    int idx = params["face_index"].get<int>();
                    if (idx < 1 || idx > faces.Extent()) return fail("face index out of range");
                    face_shape = faces(idx);
                }
                if (face_shape.IsNull() || face_shape.ShapeType() != TopAbs_FACE)
                    return fail("direct edit needs a face");
                const std::string kind = params.value("kind", "push_pull");
                if (kind == "delete_face") {
                    BRepAlgoAPI_Defeaturing def;
                    def.SetShape(tb->shape);
                    def.AddFaceToRemove(TopoDS::Face(face_shape));
                    def.Build();
                    if (!def.IsDone()) return fail("delete face failed");
                    TopoDS_Shape result = def.Shape();
                    if (result.IsNull() || !shape::is_valid(result))
                        return fail("delete face result invalid");
                    doc.replace_body_shape(target, result);
                    return true;
                }
                double distance = num_param(params, "distance", 0.0, env);
                gp_Dir dir(0, 0, 1);
                if (params.contains("direction") && params["direction"].is_array())
                    dir = dir_from(params["direction"]);
                else {
                    BRepAdaptor_Surface surf(TopoDS::Face(face_shape));
                    if (surf.GetType() == GeomAbs_Plane) {
                        dir = surf.Plane().Axis().Direction();
                        if (face_shape.Orientation() == TopAbs_REVERSED) dir.Reverse();
                    }
                }
                if (std::abs(distance) < 1e-12) return true;
                gp_Vec vec(dir);
                vec *= distance;
                TopoDS_Shape prism = BRepPrimAPI_MakePrism(face_shape, vec).Shape();
                if (prism.IsNull()) return fail("direct edit prism failed");
                TopoDS_Shape result;
                if (distance >= 0.0) {
                    BRepAlgoAPI_Fuse fuse(tb->shape, prism);
                    if (!fuse.IsDone()) return fail("push/pull fuse failed");
                    result = fuse.Shape();
                } else {
                    BRepAlgoAPI_Cut cut(tb->shape, prism);
                    if (!cut.IsDone()) return fail("push/pull cut failed");
                    result = cut.Shape();
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("direct edit result invalid");
                if (shape::count(result).solids < 1 || shape::volume(result) <= 0.0)
                    return fail("direct edit destroyed the solid");
                doc.replace_body_shape(target, result);
                return true;
            
}
bool apply_replace_face(ApplyCtx& ctx) {
    Document& doc = ctx.doc;
    Feature& f = ctx.feature;
    const json& params = ctx.params;
    const auto& env = ctx.env;
    auto fail = [&](const std::string& msg) { return ctx.fail(msg); };
    auto find_feature_body = [&](const std::string& key) { return ctx.find_feature_body(key); };
    auto feature = [&](const EntityId& id) { return ctx.graph.feature(id); };
    (void)feature;

                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                sx::occt::ShapeIndexedMap faces;
                TopExp::MapShapes(tb->shape, TopAbs_FACE, faces);
                TopoDS_Shape face;
                if (params.contains("face") && params["face"].is_string()) {
                    face = doc.resolve(EntityId::from_string(params["face"].get<std::string>()));
                } else {
                    const int idx = params.value("face_index", 1);
                    if (idx < 1 || idx > faces.Extent()) return fail("face index out of range");
                    face = faces(idx);
                }
                if (face.IsNull()) return fail("replace face needs a face of the target");

                TopoDS_Shape tool;
                if (params.contains("tool") && params["tool"].is_string()) {
                    const Body* ob = doc.body(find_feature_body("tool"));
                    if (!ob) return fail("missing replacement surface");
                    tool = ob->shape;
                } else if (params.contains("plane_origin") && params.contains("plane_normal")) {
                    tool = surf::plane_tool(tb->shape, pnt_from(params["plane_origin"]),
                                            dir_from(params["plane_normal"]));
                } else {
                    return fail("replace face needs a tool surface or a plane");
                }
                if (tool.IsNull()) return fail("replacement surface is empty");

                std::string rerr;
                TopoDS_Shape result = surf::replace_face(tb->shape, face, tool, &rerr);
                if (result.IsNull()) return fail(rerr);
                doc.replace_body_shape(target, result);
                return true;
            
}
}
