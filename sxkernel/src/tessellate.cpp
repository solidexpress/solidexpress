#include "sx/tessellate.hpp"

#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Polygon3D.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopLoc_Location.hxx>
#include "sx/occt_types.hpp"
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Trsf.hxx>

#include <stdexcept>

#include "sx/document.hpp"

namespace sx {

BodyMesh tessellate_body(const Document& doc, const EntityId& body_id,
                         double linear_deflection, double angular_deflection) {
    const Body* b = doc.body(body_id);
    if (!b) throw std::invalid_argument("tessellate_body: no such body");

    BodyMesh out;
    out.body = body_id;

    // (Re)mesh. OCCT caches triangulation on the shape; this is idempotent.
    BRepMesh_IncrementalMesh mesher(b->shape, linear_deflection, /*isRelative=*/false,
                                    angular_deflection, /*parallel=*/true);

    sx::occt::ShapeIndexedMap face_map;
    TopExp::MapShapes(b->shape, TopAbs_FACE, face_map);
    const auto& face_ids = b->subshape_ids.at(EntityKind::Face);

    for (int fi = 1; fi <= face_map.Extent(); ++fi) {
        const TopoDS_Face face = TopoDS::Face(face_map(fi));
        TopLoc_Location loc;
        Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
        if (tri.IsNull()) continue;

        FaceMesh fm;
        fm.face = face_ids[static_cast<size_t>(fi - 1)];
        const gp_Trsf& trsf = loc.Transformation();
        const bool reversed = (face.Orientation() == TopAbs_REVERSED);

        const int nb_nodes = tri->NbNodes();
        fm.positions.reserve(static_cast<size_t>(nb_nodes) * 3);
        fm.normals.reserve(static_cast<size_t>(nb_nodes) * 3);

        // Ensure per-node normals exist (computed from surface UV).
        tri->ComputeNormals();

        for (int i = 1; i <= nb_nodes; ++i) {
            gp_Pnt p = tri->Node(i).Transformed(trsf);
            fm.positions.push_back(static_cast<float>(p.X()));
            fm.positions.push_back(static_cast<float>(p.Y()));
            fm.positions.push_back(static_cast<float>(p.Z()));
            gp_Dir n = tri->Normal(i);
            gp_Vec nv(n.XYZ());
            nv.Transform(trsf);  // rotate normal by location (no scale expected)
            if (reversed) nv.Reverse();
            fm.normals.push_back(static_cast<float>(nv.X()));
            fm.normals.push_back(static_cast<float>(nv.Y()));
            fm.normals.push_back(static_cast<float>(nv.Z()));
        }

        const int nb_tris = tri->NbTriangles();
        fm.indices.reserve(static_cast<size_t>(nb_tris) * 3);
        for (int i = 1; i <= nb_tris; ++i) {
            int n1, n2, n3;
            tri->Triangle(i).Get(n1, n2, n3);
            if (reversed) std::swap(n2, n3);
            fm.indices.push_back(static_cast<uint32_t>(n1 - 1));
            fm.indices.push_back(static_cast<uint32_t>(n2 - 1));
            fm.indices.push_back(static_cast<uint32_t>(n3 - 1));
        }
        out.faces.push_back(std::move(fm));
    }

    // Edge polylines from the triangulation (for wireframe overlay).
    sx::occt::ShapeIndexedMap edge_map;
    TopExp::MapShapes(b->shape, TopAbs_EDGE, edge_map);
    const auto& edge_ids = b->subshape_ids.at(EntityKind::Edge);

    for (int ei = 1; ei <= edge_map.Extent(); ++ei) {
        const TopoDS_Edge edge = TopoDS::Edge(edge_map(ei));
        BodyMesh::EdgeLine el;
        el.edge = edge_ids[static_cast<size_t>(ei - 1)];

        TopLoc_Location loc;
        Handle(Poly_Polygon3D) poly = BRep_Tool::Polygon3D(edge, loc);
        if (!poly.IsNull()) {
            const gp_Trsf& trsf = loc.Transformation();
            for (int i = 1; i <= poly->NbNodes(); ++i) {
                gp_Pnt p = poly->Nodes().Value(i).Transformed(trsf);
                el.points.push_back(static_cast<float>(p.X()));
                el.points.push_back(static_cast<float>(p.Y()));
                el.points.push_back(static_cast<float>(p.Z()));
            }
        } else {
            // Fall back to polygon-on-triangulation from an adjacent face.
            Handle(Poly_Triangulation) tri;
            Handle(Poly_PolygonOnTriangulation) pot;
            BRep_Tool::PolygonOnTriangulation(edge, pot, tri, loc);
            if (!pot.IsNull() && !tri.IsNull()) {
                const gp_Trsf& trsf = loc.Transformation();
                for (int i = 1; i <= pot->NbNodes(); ++i) {
                    gp_Pnt p = tri->Node(pot->Nodes().Value(i)).Transformed(trsf);
                    el.points.push_back(static_cast<float>(p.X()));
                    el.points.push_back(static_cast<float>(p.Y()));
                    el.points.push_back(static_cast<float>(p.Z()));
                }
            }
        }
        if (!el.points.empty()) out.edges.push_back(std::move(el));
    }

    return out;
}

}  // namespace sx
