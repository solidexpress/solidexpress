#include "sx/print.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <BRepBndLib.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_Surface.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <sstream>
#include <vector>

#include <nlohmann/json.hpp>

#include "sx/document.hpp"
#include "sx/entity.hpp"

namespace sx {
namespace {

std::array<double, 3> mul(const std::array<double, 9>& R, const std::array<double, 3>& p) {
    return {R[0] * p[0] + R[1] * p[1] + R[2] * p[2],
            R[3] * p[0] + R[4] * p[1] + R[5] * p[2],
            R[6] * p[0] + R[7] * p[1] + R[8] * p[2]};
}

gp_Dir face_normal(const TopoDS_Face& f) {
    BRepAdaptor_Surface adapt(f);
    if (adapt.GetType() == GeomAbs_Plane) {
        gp_Dir n = adapt.Plane().Axis().Direction();
        if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
        return n;
    }
    Standard_Real umin = 0, umax = 0, vmin = 0, vmax = 0;
    BRepTools::UVBounds(f, umin, umax, vmin, vmax);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
    GeomLProp_SLProps props(surf, 0.5 * (umin + umax), 0.5 * (vmin + vmax), 1, 1e-6);
    gp_Dir n(0, 0, 1);
    if (props.IsNormalDefined()) n = props.Normal();
    if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
    return n;
}

gp_Pnt face_mid(const TopoDS_Face& f) {
    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
    Standard_Real umin = 0, umax = 0, vmin = 0, vmax = 0;
    BRepTools::UVBounds(f, umin, umax, vmin, vmax);
    return surf->Value(0.5 * (umin + umax), 0.5 * (vmin + vmax));
}

double face_area(const TopoDS_Face& f) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(f, props);
    return props.Mass();
}

double ray_thickness(const TopoDS_Shape& solid, const gp_Pnt& mid, const gp_Dir& n) {
    gp_Pnt start = mid.Translated(gp_Vec(n) * -1e-3);
    gp_Lin lin(start, gp_Dir(-n.X(), -n.Y(), -n.Z()));
    IntCurvesFace_ShapeIntersector isect;
    isect.Load(solid, 1e-7);
    isect.Perform(lin, 1e-4, 1.0e6);
    double best = 1.0e9;
    for (int i = 1; i <= isect.NbPnt(); ++i) {
        const double w = isect.WParameter(i);
        if (w > 1e-4 && w < best) best = w;
    }
    return best > 1.0e8 ? 0.0 : best;
}

std::array<double, 9> rot_from_axes(const std::array<double, 3>& x,
                                    const std::array<double, 3>& y,
                                    const std::array<double, 3>& z) {
    // Rows are the images of the standard basis in print space.
    return {x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2]};
}

std::vector<std::array<double, 9>> cube_rotations() {
    const std::array<double, 3> e[3] = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
    std::vector<std::array<double, 9>> out;
    for (int z = 0; z < 3; ++z) {
        for (int zs : {1, -1}) {
            std::array<double, 3> Z{e[z][0] * zs, e[z][1] * zs, e[z][2] * zs};
            const int x0 = (z + 1) % 3;
            for (int twist = 0; twist < 4; ++twist) {
                std::array<double, 3> X = e[x0];
                std::array<double, 3> Y = {(Z[1] * X[2] - Z[2] * X[1]),
                                           (Z[2] * X[0] - Z[0] * X[2]),
                                           (Z[0] * X[1] - Z[1] * X[0])};
                if (twist % 2 == 1) {
                    const auto t = X;
                    X = {-Y[0], -Y[1], -Y[2]};
                    Y = t;
                    if (twist == 3) {
                        X = {-X[0], -X[1], -X[2]};
                        Y = {-Y[0], -Y[1], -Y[2]};
                    }
                } else if (twist == 2) {
                    X = {-X[0], -X[1], -X[2]};
                    Y = {-Y[0], -Y[1], -Y[2]};
                }
                // Re-orthogonalize Y = Z × X
                Y = {Z[1] * X[2] - Z[2] * X[1], Z[2] * X[0] - Z[0] * X[2],
                     Z[0] * X[1] - Z[1] * X[0]};
                out.push_back(rot_from_axes(X, Y, Z));
            }
        }
    }
    return out;
}

PrintReport analyze_with(const Document& doc, const EntityId& body, const PrintSetup& setup) {
    PrintReport r;
    const Body* b = doc.body(body);
    if (!b || b->shape.IsNull()) {
        r.digest = "No solid to print";
        r.wall_ok = false;
        r.fits_bed = false;
        return r;
    }

    Bnd_Box box;
    BRepBndLib::AddOptimal(b->shape, box, Standard_False);
    Standard_Real xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    const std::array<double, 3> corners[8] = {
        {xmin, ymin, zmin}, {xmax, ymin, zmin}, {xmin, ymax, zmin}, {xmax, ymax, zmin},
        {xmin, ymin, zmax}, {xmax, ymin, zmax}, {xmin, ymax, zmax}, {xmax, ymax, zmax},
    };
    double px0 = 1e9, py0 = 1e9, pz0 = 1e9, px1 = -1e9, py1 = -1e9, pz1 = -1e9;
    for (const auto& c : corners) {
        const auto p = mul(setup.rot, c);
        px0 = std::min(px0, p[0]);
        py0 = std::min(py0, p[1]);
        pz0 = std::min(pz0, p[2]);
        px1 = std::max(px1, p[0]);
        py1 = std::max(py1, p[1]);
        pz1 = std::max(pz1, p[2]);
    }
    r.height = pz1 - pz0;
    r.bbox_x = px1 - px0;
    r.bbox_y = py1 - py0;
    r.fits_bed = r.bbox_x <= setup.bed_x + 1e-6 && r.bbox_y <= setup.bed_y + 1e-6 &&
                 r.height <= setup.bed_z + 1e-6;

    const double sin_th = std::sin(setup.overhang_deg * 3.14159265358979323846 / 180.0);
    double min_t = 1e9;
    double over_a = 0.0;
    // Map faces to a stable OCCT order that matches Body::subshape_ids.
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b->shape, TopAbs_FACE, faces);
    const auto& face_ids = b->subshape_ids.at(EntityKind::Face);
    r.thin_faces.clear();
    r.overhang_face_areas.clear();
    for (int fi = 1; fi <= faces.Extent(); ++fi) {
        const TopoDS_Face f = TopoDS::Face(faces(fi));
        const gp_Pnt mid = face_mid(f);
        const gp_Dir n = face_normal(f);
        const double t = ray_thickness(b->shape, mid, n);
        if (t > 1e-6 && t < min_t) min_t = t;
        // Paint: flag thin faces.
        if (t > 1e-6 && t + 1e-6 < setup.min_wall) {
            r.thin_faces.push_back(face_ids[static_cast<size_t>(fi - 1)]);
        }

        const auto n_p = mul(setup.rot, {n.X(), n.Y(), n.Z()});
        const auto m_p = mul(setup.rot, {mid.X(), mid.Y(), mid.Z()});
        const bool on_bed = std::abs(m_p[2] - pz0) < 1e-3;
        if (!on_bed && n_p[2] < -sin_th) {
            const double a = face_area(f);
            over_a += a;
            r.overhang_face_areas.emplace_back(face_ids[static_cast<size_t>(fi - 1)], a);
        }
    }
    r.min_wall = min_t > 1e8 ? 0.0 : min_t;
    r.overhang_area = over_a;
    r.wall_ok = r.min_wall + 1e-6 >= setup.min_wall;
    r.overhang_ok = over_a < 1e-3;

    std::ostringstream ss;
    ss.setf(std::ios::fixed);
    ss.precision(2);
    ss << "min wall " << r.min_wall << " mm";
    if (!r.wall_ok) ss << " (thin)";
    ss << " · overhang " << r.overhang_area << " mm²";
    ss << (r.fits_bed ? " · fits bed" : " · off bed");
    r.digest = ss.str();
    return r;
}

}  // namespace

PrintReport print_analyze(const Document& doc, const EntityId& body) {
    return analyze_with(doc, body, doc.print_setup());
}

PrintReport print_orient(Document& doc, const EntityId& body) {
    PrintSetup best = doc.print_setup();
    PrintReport best_r = analyze_with(doc, body, best);
    for (const auto& R : cube_rotations()) {
        PrintSetup cand = best;
        cand.rot = R;
        const PrintReport rr = analyze_with(doc, body, cand);
        const bool better = (rr.overhang_area + 1e-4 < best_r.overhang_area) ||
                            (std::abs(rr.overhang_area - best_r.overhang_area) < 1e-4 &&
                             rr.height + 1e-4 < best_r.height);
        if (better) {
            best = cand;
            best_r = rr;
        }
    }
    doc.set_print_setup(best);
    return best_r;
}

void to_json(nlohmann::json& j, const PrintSetup& s) {
    j = nlohmann::json{{"bed_x", s.bed_x},
                       {"bed_y", s.bed_y},
                       {"bed_z", s.bed_z},
                       {"layer_height", s.layer_height},
                       {"min_wall", s.min_wall},
                       {"overhang_deg", s.overhang_deg},
                       {"nozzle_mm", s.nozzle_mm},
                       {"material", s.material},
                       {"rot", s.rot}};
}

void from_json(const nlohmann::json& j, PrintSetup& s) {
    if (j.contains("bed_x")) s.bed_x = j["bed_x"].get<double>();
    if (j.contains("bed_y")) s.bed_y = j["bed_y"].get<double>();
    if (j.contains("bed_z")) s.bed_z = j["bed_z"].get<double>();
    if (j.contains("layer_height")) s.layer_height = j["layer_height"].get<double>();
    if (j.contains("min_wall")) s.min_wall = j["min_wall"].get<double>();
    if (j.contains("overhang_deg")) s.overhang_deg = j["overhang_deg"].get<double>();
    if (j.contains("nozzle_mm")) s.nozzle_mm = j["nozzle_mm"].get<double>();
    if (j.contains("material") && j["material"].is_string())
        s.material = j["material"].get<std::string>();
    if (j.contains("rot") && j["rot"].is_array() && j["rot"].size() == 9)
        s.rot = j["rot"].get<std::array<double, 9>>();
}

}  // namespace sx
