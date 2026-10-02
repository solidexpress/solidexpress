#include "sx/commands_sweep.hpp"

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepTools.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include "sx/occt_types.hpp"
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <stdexcept>

#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

namespace sx {

namespace {
int feature_counter = 0;

std::shared_ptr<void> snapshot(const Body& b) { return std::make_shared<Body>(b); }
const Body& snap(const std::shared_ptr<void>& p) {
    return *static_cast<const Body*>(p.get());
}

gp_Pnt to_pnt(const std::array<double, 3>& p) { return gp_Pnt(p[0], p[1], p[2]); }

TopoDS_Wire make_polyline_wire(const std::vector<std::array<double, 3>>& pts) {
    if (pts.size() < 2)
        throw std::runtime_error("Sweep: path needs at least two points");

    BRepBuilderAPI_MakeWire mk;
    for (size_t i = 1; i < pts.size(); ++i) {
        gp_Pnt a = to_pnt(pts[i - 1]);
        gp_Pnt b = to_pnt(pts[i]);
        if (a.Distance(b) < 1e-12)
            throw std::runtime_error("Sweep: zero-length path segment");
        BRepBuilderAPI_MakeEdge edge(a, b);
        if (!edge.IsDone())
            throw std::runtime_error("Sweep: failed to build path edge");
        mk.Add(edge.Edge());
    }
    if (!mk.IsDone()) throw std::runtime_error("Sweep: failed to build path wire");
    return mk.Wire();
}

TopoDS_Wire make_arc_wire(const Sketch& profile, const std::array<double, 3>& center,
                          const std::array<double, 3>& axis, double angle) {
    if (std::abs(angle) < 1e-12)
        throw std::runtime_error("Sweep: arc angle must be non-zero");

    const auto& o = profile.plane().origin;
    gp_Pnt start(o[0], o[1], o[2]);
    gp_Pnt c(center[0], center[1], center[2]);
    gp_Vec axis_v(axis[0], axis[1], axis[2]);
    if (axis_v.Magnitude() < 1e-12)
        throw std::runtime_error("Sweep: arc axis is zero");
    gp_Dir axis_d(axis_v);

    gp_Vec radial(c, start);
    // Project start onto plane through center perpendicular to axis.
    gp_Vec along = axis_d.XYZ() * radial.Dot(axis_d);
    gp_Vec in_plane = radial - along;
    if (in_plane.Magnitude() < 1e-12)
        throw std::runtime_error("Sweep: sketch origin lies on arc axis");

    gp_Pnt p0 = c.Translated(in_plane);
    gp_Ax2 ax(c, axis_d, gp_Dir(in_plane));
    gp_Circ circ(ax, in_plane.Magnitude());

    // End point by rotating p0 about the axis.
    gp_Ax1 ax1(c, axis_d);
    gp_Trsf rot;
    rot.SetRotation(ax1, angle);
    gp_Pnt p1 = p0.Transformed(rot);

    Handle(Geom_TrimmedCurve) arc;
    if (std::abs(std::abs(angle) - M_PI) < 1e-9) {
        // 180°: need an intermediate point (GC_MakeArcOfCircle with two points
        // is ambiguous for a semicircle).
        gp_Trsf half;
        half.SetRotation(ax1, angle / 2.0);
        gp_Pnt mid = p0.Transformed(half);
        GC_MakeArcOfCircle mk(p0, mid, p1);
        if (!mk.IsDone()) throw std::runtime_error("Sweep: failed to build arc path");
        arc = mk.Value();
    } else if (std::abs(angle) < 2.0 * M_PI - 1e-9) {
        gp_Trsf half;
        half.SetRotation(ax1, angle / 2.0);
        gp_Pnt mid = p0.Transformed(half);
        GC_MakeArcOfCircle mk(p0, mid, p1);
        if (!mk.IsDone()) throw std::runtime_error("Sweep: failed to build arc path");
        arc = mk.Value();
    } else {
        // Full circle: single closed edge from the Geom_Circle.
        Handle(Geom_Circle) gcirc = new Geom_Circle(circ);
        BRepBuilderAPI_MakeEdge edge(gcirc, 0.0, 2.0 * M_PI);
        if (!edge.IsDone()) throw std::runtime_error("Sweep: failed to build circle path");
        BRepBuilderAPI_MakeWire mk(edge.Edge());
        if (!mk.IsDone()) throw std::runtime_error("Sweep: failed to build arc wire");
        return mk.Wire();
    }

    BRepBuilderAPI_MakeEdge edge(arc);
    if (!edge.IsDone()) throw std::runtime_error("Sweep: failed to build arc edge");
    BRepBuilderAPI_MakeWire mk(edge.Edge());
    if (!mk.IsDone()) throw std::runtime_error("Sweep: failed to build arc wire");
    return mk.Wire();
}

}  // namespace

// --- SweepCommand ---

SweepCommand::SweepCommand(std::shared_ptr<const Sketch> profile,
                           std::vector<std::array<double, 3>> path_points, std::string name)
    : profile_(std::move(profile)), path_points_(std::move(path_points)),
      name_(std::move(name)) {
    if (name_.empty()) name_ = "Sweep " + std::to_string(++feature_counter);
}

SweepCommand::SweepCommand(std::shared_ptr<const Sketch> profile, std::array<double, 3> center,
                           std::array<double, 3> axis, double angle, std::string name)
    : profile_(std::move(profile)), arc_path_(true), arc_center_(center), arc_axis_(axis),
      arc_angle_(angle), name_(std::move(name)) {
    if (name_.empty()) name_ = "Sweep " + std::to_string(++feature_counter);
}

void SweepCommand::execute(Document& doc) {
    if (!profile_) throw std::runtime_error("Sweep: null profile sketch");

    std::string err;
    TopoDS_Shape face = profile_->profile_face(&err);
    if (face.IsNull()) throw std::runtime_error("Sweep: " + err);

    TopoDS_Wire spine;
    try {
        if (arc_path_) {
            spine = make_arc_wire(*profile_, arc_center_, arc_axis_, arc_angle_);
        } else {
            spine = make_polyline_wire(path_points_);
        }
    } catch (const std::runtime_error&) {
        throw;
    } catch (const Standard_Failure& e) {
        throw std::runtime_error(std::string("Sweep: path build failed: ") + e.what());
    }

    // MakePipe requires a G1-continuous spine and only sweeps the first smooth
    // run of a polyline with sharp corners. Single-edge spines (straight or
    // arc) use MakePipe; multi-edge polylines use MakePipeShell with a right-
    // corner transition so L-paths produce a full solid.
    TopoDS_Shape solid;
    try {
        sx::occt::ShapeIndexedMap edges;
        TopExp::MapShapes(spine, TopAbs_EDGE, edges);
        if (edges.Extent() <= 1) {
            BRepOffsetAPI_MakePipe pipe(spine, face);
            if (!pipe.IsDone()) throw std::runtime_error("Sweep: MakePipe failed");
            solid = pipe.Shape();
        } else {
            TopoDS_Wire profile_wire = BRepTools::OuterWire(TopoDS::Face(face));
            if (profile_wire.IsNull())
                throw std::runtime_error("Sweep: profile has no outer wire");
            BRepOffsetAPI_MakePipeShell shell(spine);
            shell.SetMode();
            shell.SetTransitionMode(BRepBuilderAPI_RightCorner);
            shell.Add(profile_wire, /*withContact=*/false,
                      /*withCorrection=*/true);
            shell.Build();
            if (!shell.IsDone())
                throw std::runtime_error("Sweep: MakePipeShell failed");
            if (!shell.MakeSolid())
                throw std::runtime_error("Sweep: MakePipeShell could not make solid");
            solid = shell.Shape();
        }
    } catch (const std::runtime_error&) {
        throw;
    } catch (const Standard_Failure& e) {
        throw std::runtime_error(std::string("Sweep: pipe failed: ") + e.what());
    }

    if (solid.IsNull() || !shape::is_valid(solid))
        throw std::runtime_error("Sweep: result is null or invalid");
    if (shape::count(solid).solids < 1)
        throw std::runtime_error("Sweep: result is not a solid");

    body_ = doc.add_body(solid, name_);
    saved_ = snapshot(*doc.body(body_));
}

void SweepCommand::undo(Document& doc) { doc.remove_body(body_); }

void SweepCommand::redo(Document& doc) {
    Body copy = snap(saved_);
    doc.restore_body(std::move(copy));
}

// --- LoftCommand ---

LoftCommand::LoftCommand(std::vector<std::shared_ptr<const Sketch>> profiles, bool ruled,
                         std::string name)
    : profiles_(std::move(profiles)), ruled_(ruled), name_(std::move(name)) {
    if (name_.empty()) name_ = "Loft " + std::to_string(++feature_counter);
}

void LoftCommand::execute(Document& doc) {
    if (profiles_.size() < 2)
        throw std::runtime_error("Loft: need at least two profile sketches");

    BRepOffsetAPI_ThruSections loft(/*isSolid=*/true, ruled_);
    for (size_t i = 0; i < profiles_.size(); ++i) {
        if (!profiles_[i]) throw std::runtime_error("Loft: null profile sketch");
        std::string err;
        TopoDS_Shape face_shape = profiles_[i]->profile_face(&err);
        if (face_shape.IsNull())
            throw std::runtime_error("Loft: profile " + std::to_string(i) + ": " + err);
        TopoDS_Face face = TopoDS::Face(face_shape);
        TopoDS_Wire wire = BRepTools::OuterWire(face);
        if (wire.IsNull())
            throw std::runtime_error("Loft: profile " + std::to_string(i) +
                                     ": no outer wire");
        loft.AddWire(wire);
    }

    TopoDS_Shape solid;
    try {
        loft.Build();
        if (!loft.IsDone()) throw std::runtime_error("Loft: ThruSections failed");
        solid = loft.Shape();
    } catch (const std::runtime_error&) {
        throw;
    } catch (const Standard_Failure& e) {
        throw std::runtime_error(std::string("Loft: ThruSections failed: ") +
                                 e.what());
    }

    if (solid.IsNull() || !shape::is_valid(solid))
        throw std::runtime_error("Loft: result is null or invalid");
    if (shape::count(solid).solids < 1)
        throw std::runtime_error("Loft: result is not a solid");

    body_ = doc.add_body(solid, name_);
    saved_ = snapshot(*doc.body(body_));
}

void LoftCommand::undo(Document& doc) { doc.remove_body(body_); }

void LoftCommand::redo(Document& doc) {
    Body copy = snap(saved_);
    doc.restore_body(std::move(copy));
}

}  // namespace sx
