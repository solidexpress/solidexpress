#include "sx/measure.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <TopExp_Explorer.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools.hxx>
#include <Bnd_Box.hxx>
#include <Geom_Surface.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Mat.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include "face_interior.hpp"

namespace sx::measure {

std::optional<DistanceResult> min_distance(const Document& doc, const EntityId& a,
                                           const EntityId& b) {
    TopoDS_Shape sa = doc.resolve(a);
    TopoDS_Shape sb = doc.resolve(b);
    if (sa.IsNull() || sb.IsNull()) return std::nullopt;

    BRepExtrema_DistShapeShape dist(sa, sb);
    if (!dist.IsDone() || dist.NbSolution() < 1) return std::nullopt;

    gp_Pnt pa = dist.PointOnShape1(1);
    gp_Pnt pb = dist.PointOnShape2(1);
    DistanceResult r;
    r.distance = dist.Value();
    r.point_a = {pa.X(), pa.Y(), pa.Z()};
    r.point_b = {pb.X(), pb.Y(), pb.Z()};
    return r;
}

std::optional<DistanceResult> closest_point(const Document& doc, const EntityId& shape,
                                            const std::array<double, 3>& from) {
    TopoDS_Shape s = doc.resolve(shape);
    if (s.IsNull()) return std::nullopt;

    const gp_Pnt p(from[0], from[1], from[2]);
    TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(p);
    BRepExtrema_DistShapeShape dist(v, s);
    if (!dist.IsDone() || dist.NbSolution() < 1) return std::nullopt;

    gp_Pnt pb = dist.PointOnShape2(1);
    DistanceResult r;
    r.distance = dist.Value();
    r.point_a = from;
    r.point_b = {pb.X(), pb.Y(), pb.Z()};
    return r;
}

std::optional<std::array<double, 3>> face_midpoint(const Document& doc,
                                                   const EntityId& face) {
    TopoDS_Shape s = doc.resolve(face);
    if (s.IsNull() || s.ShapeType() != TopAbs_FACE) return std::nullopt;
    const TopoDS_Face f = TopoDS::Face(s);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
    if (surf.IsNull()) return std::nullopt;
    double umin = 0, umax = 0, vmin = 0, vmax = 0;
    BRepTools::UVBounds(f, umin, umax, vmin, vmax);
    const gp_Pnt p = surf->Value(0.5 * (umin + umax), 0.5 * (vmin + vmax));
    return std::array<double, 3>{p.X(), p.Y(), p.Z()};
}

namespace {

bool point_inside_face(const TopoDS_Face& face, const gp_Pnt& p) {
    BRepClass_FaceClassifier cl(face, p, 1e-5);
    return cl.State() == TopAbs_IN;
}

// Distance from `p` to the nearest non-degenerate edge, and that foot.
double boundary_clearance(const TopoDS_Face& face, const gp_Pnt& p, gp_Pnt& foot) {
    double best = 1e300;
    TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(p);
    for (TopExp_Explorer ex(face, TopAbs_EDGE); ex.More(); ex.Next()) {
        const TopoDS_Edge edge = TopoDS::Edge(ex.Current());
        if (BRep_Tool::Degenerated(edge)) continue;
        BRepExtrema_DistShapeShape dist(v, edge);
        if (!dist.IsDone() || dist.NbSolution() < 1) continue;
        if (dist.Value() < best) {
            best = dist.Value();
            foot = dist.PointOnShape2(1);
        }
    }
    return best;
}

// Grid sample nearest the UV-box centre that lies inside the face. A full
// rectangle lands on its centre. An annulus lands just outside the hole.
bool uv_centre_sample(const TopoDS_Face& face, gp_Pnt& out) {
    double u0, u1, v0, v1;
    BRepTools::UVBounds(face, u0, u1, v0, v1);
    BRepAdaptor_Surface surf(face);
    const int n = 16;
    double best = 1e300;
    bool found = false;
    for (int i = 1; i < n; ++i) {
        for (int j = 1; j < n; ++j) {
            const double fu = static_cast<double>(i) / n;
            const double fv = static_cast<double>(j) / n;
            const double u = u0 + (u1 - u0) * fu;
            const double v = v0 + (v1 - v0) * fv;
            BRepClass_FaceClassifier cl(face, gp_Pnt2d(u, v), 1e-7);
            if (cl.State() != TopAbs_IN) continue;
            const double d = (fu - 0.5) * (fu - 0.5) + (fv - 0.5) * (fv - 0.5);
            if (d < best) {
                best = d;
                out = surf.Value(u, v);
                found = true;
            }
        }
    }
    return found;
}

// Walk the sample away from the nearest boundary until clearance stops
// growing. A rectangle is already at its centre, so it does not move. An
// annulus walks to the ring midline, far enough that a 2.5 mm edge snap
// does not steal the click.
void walk_to_interior(const TopoDS_Face& face, gp_Pnt& p) {
    BRepAdaptor_Surface surf(face);
    if (surf.GetType() != GeomAbs_Plane) return;
    const gp_Dir n = surf.Plane().Axis().Direction();
    for (int iter = 0; iter < 16; ++iter) {
        gp_Pnt foot;
        const double d = boundary_clearance(face, p, foot);
        if (d > 1e6) return;
        gp_Vec away(foot, p);
        const gp_Vec normal(n);
        away -= normal * away.Dot(normal);
        if (away.SquareMagnitude() < 1e-12) return;
        away.Normalize();
        bool stepped = false;
        double step = 4.0;
        for (int attempt = 0; attempt < 8 && step > 0.05; ++attempt) {
            const gp_Pnt trial = p.Translated(away * step);
            if (!point_inside_face(face, trial)) {
                step *= 0.5;
                continue;
            }
            gp_Pnt foot2;
            const double d2 = boundary_clearance(face, trial, foot2);
            if (d2 > d + 1e-3) {
                p = trial;
                stepped = true;
                break;
            }
            step *= 0.5;
        }
        if (!stepped) return;
    }
}

}  // namespace

bool face_interior_point(const TopoDS_Face& face, gp_Pnt& out) {
    if (!uv_centre_sample(face, out)) return false;
    walk_to_interior(face, out);
    return point_inside_face(face, out);
}

std::optional<std::array<double, 3>> face_pick_point(const Document& doc,
                                                     const EntityId& face) {
    TopoDS_Shape s = doc.resolve(face);
    if (s.IsNull() || s.ShapeType() != TopAbs_FACE) return std::nullopt;
    gp_Pnt p;
    if (!face_interior_point(TopoDS::Face(s), p)) return std::nullopt;
    return std::array<double, 3>{p.X(), p.Y(), p.Z()};
}

std::optional<BBox> bounding_box(const Document& doc, const EntityId& id) {
    TopoDS_Shape s = doc.resolve(id);
    if (s.IsNull()) return std::nullopt;

    Bnd_Box box;
    BRepBndLib::AddOptimal(s, box, /*useTriangulation=*/false);
    if (box.IsVoid()) return std::nullopt;

    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    BBox r;
    r.min = {xmin, ymin, zmin};
    r.max = {xmax, ymax, zmax};
    return r;
}

std::optional<MassProps> mass_properties(const Document& doc, const EntityId& body) {
    if (!doc.body(body)) return std::nullopt;
    TopoDS_Shape s = doc.resolve(body);
    if (s.IsNull()) return std::nullopt;

    GProp_GProps vol_props;
    BRepGProp::VolumeProperties(s, vol_props);
    GProp_GProps surf_props;
    BRepGProp::SurfaceProperties(s, surf_props);

    gp_Pnt c = vol_props.CentreOfMass();
    gp_Mat I = vol_props.MatrixOfInertia();

    MassProps r;
    r.volume = vol_props.Mass();
    r.surface_area = surf_props.Mass();
    r.center_of_mass = {c.X(), c.Y(), c.Z()};
    // gp_Mat is 1-based; store row-major.
    r.inertia = {I(1, 1), I(1, 2), I(1, 3), I(2, 1), I(2, 2), I(2, 3),
                 I(3, 1), I(3, 2), I(3, 3)};
    return r;
}

double edge_length(const Document& doc, const EntityId& edge) {
    TopoDS_Shape s = doc.resolve(edge);
    if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) return 0.0;
    GProp_GProps props;
    BRepGProp::LinearProperties(s, props);
    return props.Mass();
}

double face_area(const Document& doc, const EntityId& face) {
    TopoDS_Shape s = doc.resolve(face);
    if (s.IsNull() || s.ShapeType() != TopAbs_FACE) return 0.0;
    GProp_GProps props;
    BRepGProp::SurfaceProperties(s, props);
    return props.Mass();
}

static std::optional<gp_Dir> planar_outward_normal(const TopoDS_Shape& face) {
    if (face.IsNull() || face.ShapeType() != TopAbs_FACE) return std::nullopt;
    BRepAdaptor_Surface surf(TopoDS::Face(face));
    if (surf.GetType() != GeomAbs_Plane) return std::nullopt;
    gp_Dir n = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
    return n;
}

std::optional<double> angle_between_faces(const Document& doc, const EntityId& f1,
                                          const EntityId& f2) {
    auto n1 = planar_outward_normal(doc.resolve(f1));
    auto n2 = planar_outward_normal(doc.resolve(f2));
    if (!n1 || !n2) return std::nullopt;
    return n1->Angle(*n2);
}

std::optional<double> interference_volume(const Document& doc, const EntityId& a,
                                          const EntityId& b) {
    const Body* ba = doc.body(a);
    const Body* bb = doc.body(b);
    if (!ba || !bb || ba->shape.IsNull() || bb->shape.IsNull()) return std::nullopt;
    BRepAlgoAPI_Common common(ba->shape, bb->shape);
    if (!common.IsDone()) return std::nullopt;
    TopoDS_Shape overlap = common.Shape();
    if (overlap.IsNull()) return 0.0;
    GProp_GProps props;
    BRepGProp::VolumeProperties(overlap, props);
    const double v = props.Mass();
    return v < 1e-9 ? 0.0 : v;
}

}  // namespace sx::measure
