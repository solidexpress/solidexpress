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

bool apply_hole(ApplyCtx& ctx) {
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
                // Wave 6.2: hole Ø = nominal + hole_compensation; hex AF is
                // diameter (often "=jaw_af+clearance"). Do not add clearance
                // onto circular holes — that belongs on hex/slot only.
                std::string htype = params.value("type", "simple");
                double diameter = 0.0;
                if (params.contains("nominal")) {
                    const double nominal = num_param(params, "nominal", 0.0, env);
                    double comp = 0.0;
                    if (auto it = env.find("hole_compensation"); it != env.end())
                        comp = it->second;
                    diameter = nominal + comp;
                } else {
                    diameter = num_param(params, "diameter", 0.0, env);
                }
                if (diameter <= 0.0) return fail("invalid diameter");
                double depth_param = num_param(params, "depth", 0.0, env);
                double depth = depth_param > 0.0 ? depth_param : k_hole_through;
                std::vector<gp_Pnt> positions;
                if (params.contains("positions") && params["positions"].is_array() &&
                    !params["positions"].empty()) {
                    for (const auto& jp : params["positions"]) positions.push_back(pnt_from(jp));
                } else {
                    positions.push_back(pnt_from(params.at("position")));
                }
                TopoDS_Shape tool;
                for (const auto& pos : positions) {
                    TopoDS_Shape one = build_feature_hole_tool(
                        pos, dir_from(params.at("direction")), diameter, depth, htype,
                        num_param(params, "cb_diameter", 0.0, env),
                        num_param(params, "cb_depth", 0.0, env),
                        num_param(params, "cs_diameter", 0.0, env),
                        num_param(params, "cs_angle_deg", 90.0, env));
                    if (one.IsNull() || !shape::is_valid(one)) return fail("hole tool failed");
                    if (tool.IsNull()) {
                        tool = one;
                    } else {
                        BRepAlgoAPI_Fuse fuse(tool, one);
                        if (!fuse.IsDone()) return fail("hole tool fuse failed");
                        tool = fuse.Shape();
                    }
                }
                if (tool.IsNull() || !shape::is_valid(tool)) return fail("hole tool failed");
                BRepAlgoAPI_Cut cut(tb->shape, tool);
                if (!cut.IsDone()) return fail("hole cut failed");
                TopoDS_Shape result = cut.Shape();
                if (result.IsNull() || !shape::is_valid(result)) return fail("hole result invalid");
                if (shape::count(result).solids < 1 || shape::volume(result) <= 0.0)
                    return fail("hole destroyed the solid");
                doc.replace_body_shape(target, result);
                return true;
            
}
}
