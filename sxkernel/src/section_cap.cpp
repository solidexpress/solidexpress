#include "sx/section_cap.hpp"

#include <BRepAlgoAPI_Common.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <utility>

#include "sx/surface_ops.hpp"

namespace sx {
namespace {

void append_face(SectionCapMesh& out, const TopoDS_Face& face) {
    TopLoc_Location loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
    if (tri.IsNull() || tri->NbNodes() < 3 || tri->NbTriangles() < 1) return;

    const gp_Trsf& trsf = loc.Transformation();
    const bool reversed = face.Orientation() == TopAbs_REVERSED;
    const auto base = static_cast<uint32_t>(out.positions.size() / 3);

    for (int i = 1; i <= tri->NbNodes(); ++i) {
        gp_Pnt p = tri->Node(i).Transformed(trsf);
        out.positions.push_back(static_cast<float>(p.X()));
        out.positions.push_back(static_cast<float>(p.Y()));
        out.positions.push_back(static_cast<float>(p.Z()));
    }
    for (int i = 1; i <= tri->NbTriangles(); ++i) {
        int n1, n2, n3;
        tri->Triangle(i).Get(n1, n2, n3);
        if (reversed) std::swap(n2, n3);
        out.indices.push_back(base + static_cast<uint32_t>(n1 - 1));
        out.indices.push_back(base + static_cast<uint32_t>(n2 - 1));
        out.indices.push_back(base + static_cast<uint32_t>(n3 - 1));
    }
}

void tessellate_into(SectionCapMesh& out, const TopoDS_Shape& shape) {
    if (shape.IsNull()) return;
    BRepMesh_IncrementalMesh mesher(shape, /*linear=*/0.05, /*isRelative=*/false,
                                    /*angular=*/0.2, /*parallel=*/true);
    for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next())
        append_face(out, TopoDS::Face(ex.Current()));
}

// A face boolean can come back empty on a hollow solid. A paper-thin slab
// common still yields the wall cross-section, offset by half the slab.
SectionCapMesh cap_from_slab(const TopoDS_Shape& solid, const gp_Pnt& point, const gp_Dir& normal) {
    SectionCapMesh out;
    TopoDS_Shape tool = surf::plane_tool(solid, point, normal);
    if (tool.IsNull()) return out;
    const double half = 0.02;
    gp_Vec shift(normal);
    shift *= half;
    TopoDS_Shape slab = BRepPrimAPI_MakePrism(tool, shift * 2.0).Shape();
    if (slab.IsNull()) return out;
    // Centre the slab on the plane (the prism starts on the face and goes +normal).
    gp_Trsf back;
    back.SetTranslation(-shift);
    slab.Move(TopLoc_Location(back));

    BRepAlgoAPI_Common common(solid, slab);
    common.Build();
    if (!common.IsDone()) return out;
    tessellate_into(out, common.Shape());
    return out;
}

}  // namespace

bool SectionCapMesh::covers(double x, double y, double z, double tol) const {
    const double tol2 = tol * tol;
    for (size_t t = 0; t + 2 < indices.size(); t += 3) {
        const uint32_t i0 = indices[t];
        const uint32_t i1 = indices[t + 1];
        const uint32_t i2 = indices[t + 2];
        const double ax = positions[3 * i0], ay = positions[3 * i0 + 1], az = positions[3 * i0 + 2];
        const double bx = positions[3 * i1], by = positions[3 * i1 + 1], bz = positions[3 * i1 + 2];
        const double cx = positions[3 * i2], cy = positions[3 * i2 + 1], cz = positions[3 * i2 + 2];
        const double ux = bx - ax, uy = by - ay, uz = bz - az;
        const double vx = cx - ax, vy = cy - ay, vz = cz - az;
        const double nx = uy * vz - uz * vy;
        const double ny = uz * vx - ux * vz;
        const double nz = ux * vy - uy * vx;
        const double nlen2 = nx * nx + ny * ny + nz * nz;
        if (nlen2 < 1e-16) continue;
        const double dist = ((x - ax) * nx + (y - ay) * ny + (z - az) * nz) / std::sqrt(nlen2);
        if (dist * dist > tol2) continue;
        // Project onto the triangle and test the barycentric coordinates.
        const double px = x - nx * dist / std::sqrt(nlen2);
        const double py = y - ny * dist / std::sqrt(nlen2);
        const double pz = z - nz * dist / std::sqrt(nlen2);
        const double wx = px - ax, wy = py - ay, wz = pz - az;
        const double uu = ux * ux + uy * uy + uz * uz;
        const double uv = ux * vx + uy * vy + uz * vz;
        const double vv = vx * vx + vy * vy + vz * vz;
        const double wu = wx * ux + wy * uy + wz * uz;
        const double wv = wx * vx + wy * vy + wz * vz;
        const double den = uu * vv - uv * uv;
        if (std::abs(den) < 1e-16) continue;
        const double s = (vv * wu - uv * wv) / den;
        const double tt = (uu * wv - uv * wu) / den;
        // Absolute-ish: 1e-4 of a 120 mm edge is 0.01 mm, so a sample 0.5 mm
        // inside a wall counts and a point 1 mm outside the solid does not.
        const double slack = 1e-4;
        if (s >= -slack && tt >= -slack && s + tt <= 1.0 + slack) return true;
    }
    return false;
}

SectionCapMesh section_cap(const TopoDS_Shape& solid, double px, double py, double pz, double nx,
                           double ny, double nz) {
    SectionCapMesh out;
    if (solid.IsNull()) return out;
    gp_Vec nvec(nx, ny, nz);
    if (nvec.SquareMagnitude() < 1e-18) return out;
    const gp_Dir normal(nvec);
    const gp_Pnt point(px, py, pz);

    TopoDS_Shape tool = surf::plane_tool(solid, point, normal);
    if (!tool.IsNull()) {
        BRepAlgoAPI_Common common(solid, tool);
        common.Build();
        if (common.IsDone()) tessellate_into(out, common.Shape());
    }
    if (!out.empty()) return out;
    return cap_from_slab(solid, point, normal);
}

}  // namespace sx
