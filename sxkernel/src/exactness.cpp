#include "sx/exactness.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Circ.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Elips.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>

#include <stdexcept>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/occt_types.hpp"
#include "sx/shape_utils.hpp"

namespace sx {
namespace exactness {
namespace {

nlohmann::json xyz(double x, double y, double z) { return nlohmann::json::array({x, y, z}); }

nlohmann::json xyz(const gp_Pnt& p) { return xyz(p.X(), p.Y(), p.Z()); }

nlohmann::json xyz(const gp_Dir& d) { return xyz(d.X(), d.Y(), d.Z()); }

}  // namespace

const char* curve_type_name(int t) {
    switch (static_cast<GeomAbs_CurveType>(t)) {
        case GeomAbs_Line:
            return "GeomAbs_Line";
        case GeomAbs_Circle:
            return "GeomAbs_Circle";
        case GeomAbs_Ellipse:
            return "GeomAbs_Ellipse";
        case GeomAbs_Hyperbola:
            return "GeomAbs_Hyperbola";
        case GeomAbs_Parabola:
            return "GeomAbs_Parabola";
        case GeomAbs_BezierCurve:
            return "GeomAbs_BezierCurve";
        case GeomAbs_BSplineCurve:
            return "GeomAbs_BSplineCurve";
        case GeomAbs_OffsetCurve:
            return "GeomAbs_OffsetCurve";
        case GeomAbs_OtherCurve:
        default:
            return "GeomAbs_OtherCurve";
    }
}

const char* surface_type_name(int t) {
    switch (static_cast<GeomAbs_SurfaceType>(t)) {
        case GeomAbs_Plane:
            return "GeomAbs_Plane";
        case GeomAbs_Cylinder:
            return "GeomAbs_Cylinder";
        case GeomAbs_Cone:
            return "GeomAbs_Cone";
        case GeomAbs_Sphere:
            return "GeomAbs_Sphere";
        case GeomAbs_Torus:
            return "GeomAbs_Torus";
        case GeomAbs_BezierSurface:
            return "GeomAbs_BezierSurface";
        case GeomAbs_BSplineSurface:
            return "GeomAbs_BSplineSurface";
        case GeomAbs_SurfaceOfRevolution:
            return "GeomAbs_SurfaceOfRevolution";
        case GeomAbs_SurfaceOfExtrusion:
            return "GeomAbs_SurfaceOfExtrusion";
        case GeomAbs_OffsetSurface:
            return "GeomAbs_OffsetSurface";
        case GeomAbs_OtherSurface:
        default:
            return "GeomAbs_OtherSurface";
    }
}

nlohmann::json probe_edge(const TopoDS_Edge& edge) {
    nlohmann::json j;
    if (edge.IsNull()) {
        j["type"] = "null";
        return j;
    }
    BRepAdaptor_Curve curve(edge);
    const GeomAbs_CurveType t = curve.GetType();
    j["type"] = curve_type_name(static_cast<int>(t));
    j["first"] = curve.FirstParameter();
    j["last"] = curve.LastParameter();
    j["start"] = xyz(curve.Value(curve.FirstParameter()));
    j["end"] = xyz(curve.Value(curve.LastParameter()));
    switch (t) {
        case GeomAbs_Line: {
            const gp_Lin lin = curve.Line();
            j["origin"] = xyz(lin.Location());
            j["axis"] = xyz(lin.Direction());
            break;
        }
        case GeomAbs_Circle: {
            const gp_Circ c = curve.Circle();
            j["radius"] = c.Radius();
            j["centre"] = xyz(c.Location());
            j["axis"] = xyz(c.Axis().Direction());
            break;
        }
        case GeomAbs_Ellipse: {
            const gp_Elips e = curve.Ellipse();
            j["radius_major"] = e.MajorRadius();
            j["radius_minor"] = e.MinorRadius();
            j["centre"] = xyz(e.Location());
            j["axis"] = xyz(e.Axis().Direction());
            j["x_dir"] = xyz(e.XAxis().Direction());
            break;
        }
        case GeomAbs_BSplineCurve: {
            Handle(Geom_BSplineCurve) bs = curve.BSpline();
            if (!bs.IsNull()) {
                j["degree"] = bs->Degree();
                nlohmann::json poles = nlohmann::json::array();
                for (int i = 1; i <= bs->NbPoles(); ++i) poles.push_back(xyz(bs->Pole(i)));
                j["poles"] = std::move(poles);
            }
            break;
        }
        case GeomAbs_BezierCurve: {
            Handle(Geom_BezierCurve) bz = curve.Bezier();
            if (!bz.IsNull()) {
                j["degree"] = bz->Degree();
                nlohmann::json poles = nlohmann::json::array();
                for (int i = 1; i <= bz->NbPoles(); ++i) poles.push_back(xyz(bz->Pole(i)));
                j["poles"] = std::move(poles);
            }
            break;
        }
        default:
            break;
    }
    return j;
}

nlohmann::json probe_face(const TopoDS_Face& face) {
    nlohmann::json j;
    if (face.IsNull()) {
        j["type"] = "null";
        return j;
    }
    BRepAdaptor_Surface surf(face);
    const GeomAbs_SurfaceType t = surf.GetType();
    j["type"] = surface_type_name(static_cast<int>(t));
    switch (t) {
        case GeomAbs_Plane: {
            const gp_Pln pl = surf.Plane();
            j["origin"] = xyz(pl.Location());
            j["axis"] = xyz(pl.Axis().Direction());
            break;
        }
        case GeomAbs_Cylinder: {
            const gp_Cylinder c = surf.Cylinder();
            j["radius"] = c.Radius();
            j["location"] = xyz(c.Location());
            j["axis"] = xyz(c.Axis().Direction());
            break;
        }
        case GeomAbs_Cone: {
            const gp_Cone c = surf.Cone();
            j["radius"] = c.RefRadius();
            j["semi_angle"] = c.SemiAngle();
            j["location"] = xyz(c.Location());
            j["axis"] = xyz(c.Axis().Direction());
            break;
        }
        case GeomAbs_Sphere: {
            const gp_Sphere s = surf.Sphere();
            j["radius"] = s.Radius();
            j["centre"] = xyz(s.Location());
            break;
        }
        case GeomAbs_Torus: {
            const gp_Torus tor = surf.Torus();
            j["radius_major"] = tor.MajorRadius();
            j["radius_minor"] = tor.MinorRadius();
            j["location"] = xyz(tor.Location());
            j["axis"] = xyz(tor.Axis().Direction());
            break;
        }
        default:
            break;
    }
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    j["area"] = props.Mass();
    return j;
}

nlohmann::json probe_shape(const TopoDS_Shape& shape) {
    nlohmann::json j;
    if (shape.IsNull()) {
        j["volume"] = 0.0;
        j["area"] = 0.0;
        j["edges"] = nlohmann::json::array();
        j["faces"] = nlohmann::json::array();
        return j;
    }
    j["volume"] = shape::volume(shape);
    j["area"] = shape::area(shape);
    nlohmann::json edges = nlohmann::json::array();
    sx::occt::ShapeIndexedMap emap;
    TopExp::MapShapes(shape, TopAbs_EDGE, emap);
    for (int i = 1; i <= emap.Extent(); ++i) {
        const TopoDS_Edge e = TopoDS::Edge(emap(i));
        if (BRep_Tool::Degenerated(e)) continue;
        edges.push_back(probe_edge(e));
    }
    j["edges"] = std::move(edges);
    nlohmann::json faces = nlohmann::json::array();
    sx::occt::ShapeIndexedMap fmap;
    TopExp::MapShapes(shape, TopAbs_FACE, fmap);
    for (int i = 1; i <= fmap.Extent(); ++i) faces.push_back(probe_face(TopoDS::Face(fmap(i))));
    j["faces"] = std::move(faces);
    return j;
}

nlohmann::json report_body(const Document& doc, const EntityId& body) {
    nlohmann::json j;
    const Body* b = doc.body(body);
    if (!b) {
        j["error"] = "missing body";
        j["id"] = body.str();
        return j;
    }
    j = probe_shape(b->shape);
    j["id"] = b->id.str();
    j["name"] = b->name;
    return j;
}

namespace {

const char* sketch_entity_type_name(SketchEntityType t) {
    switch (t) {
        case SketchEntityType::Point:
            return "point";
        case SketchEntityType::Line:
            return "line";
        case SketchEntityType::Circle:
            return "circle";
        case SketchEntityType::Arc:
            return "arc";
        case SketchEntityType::Spline:
            return "spline";
        case SketchEntityType::Ellipse:
            return "ellipse";
        case SketchEntityType::EllipticalArc:
            return "elliptical_arc";
    }
    return "unknown";
}

nlohmann::json dump_sketch_entity(const Sketch& sketch, const SketchEntity& e) {
    nlohmann::json j;
    j["id"] = e.id.str();
    j["type"] = sketch_entity_type_name(e.type);
    j["construction"] = e.construction;
    j["external"] = e.external;
    if (!e.projected_from.empty()) j["projected_from"] = e.projected_from;
    auto p = [&](size_t i) { return sketch.param(e.params[i]); };
    switch (e.type) {
        case SketchEntityType::Point:
            if (e.params.size() >= 2) j["xy"] = nlohmann::json::array({p(0), p(1)});
            break;
        case SketchEntityType::Line:
            if (e.params.size() >= 4) {
                j["start"] = nlohmann::json::array({p(0), p(1)});
                j["end"] = nlohmann::json::array({p(2), p(3)});
            }
            break;
        case SketchEntityType::Circle:
            if (e.params.size() >= 3) {
                j["centre"] = nlohmann::json::array({p(0), p(1)});
                j["radius"] = p(2);
            }
            break;
        case SketchEntityType::Arc:
            if (e.params.size() >= 9) {
                j["centre"] = nlohmann::json::array({p(0), p(1)});
                j["radius"] = p(2);
                j["start_angle"] = p(3);
                j["end_angle"] = p(4);
                j["start"] = nlohmann::json::array({p(5), p(6)});
                j["end"] = nlohmann::json::array({p(7), p(8)});
            }
            break;
        case SketchEntityType::Spline: {
            nlohmann::json pts = nlohmann::json::array();
            for (const auto& xy : sketch.spline_fit_points(e.id))
                pts.push_back(nlohmann::json::array({xy[0], xy[1]}));
            j["fit_points"] = std::move(pts);
            break;
        }
        case SketchEntityType::Ellipse:
        case SketchEntityType::EllipticalArc: {
            if (auto axes = sketch.ellipse_axes(e.id)) {
                j["centre"] = nlohmann::json::array({(*axes)[0], (*axes)[1]});
                j["radius_major"] = (*axes)[2];
                j["radius_minor"] = (*axes)[3];
                j["angle"] = (*axes)[4];
            }
            break;
        }
    }
    return j;
}

}  // namespace

nlohmann::json report_sketch(const Sketch& sketch) {
    nlohmann::json j;
    j["id"] = sketch.id().str();
    j["name"] = sketch.name();
    const auto& pl = sketch.plane();
    j["plane"] = {{"origin", xyz(pl.origin[0], pl.origin[1], pl.origin[2])},
                  {"x_dir", xyz(pl.x_dir[0], pl.x_dir[1], pl.x_dir[2])},
                  {"y_dir", xyz(pl.y_dir[0], pl.y_dir[1], pl.y_dir[2])}};
    nlohmann::json ents = nlohmann::json::array();
    for (const auto& e : sketch.entities()) ents.push_back(dump_sketch_entity(sketch, e));
    j["entities"] = std::move(ents);
    nlohmann::json cons = nlohmann::json::array();
    for (const auto& c : sketch.constraints()) {
        nlohmann::json jc;
        jc["id"] = c.id.str();
        jc["type"] = to_string(c.type);
        jc["value"] = c.value;
        jc["driving"] = c.driving;
        jc["weak"] = c.weak;
        if (!c.expr.empty()) jc["expr"] = c.expr;
        cons.push_back(std::move(jc));
    }
    j["constraints"] = std::move(cons);
    return j;
}

nlohmann::json report_features(const Document& doc) {
    nlohmann::json arr = nlohmann::json::array();
    for (const auto& f : doc.graph().timeline()) {
        nlohmann::json jf;
        jf["id"] = f.id.str();
        jf["name"] = f.name;
        jf["type"] = to_string(f.type);
        jf["suppressed"] = f.suppressed;
        jf["params"] = f.params;
        jf["output_body"] = f.output_body.is_null() ? "" : f.output_body.str();
        if (f.sketch) jf["sketch"] = report_sketch(*f.sketch);
        arr.push_back(std::move(jf));
    }
    return arr;
}

nlohmann::json report(const Document& doc) {
    nlohmann::json j;
    nlohmann::json bodies = nlohmann::json::array();
    for (const auto& id : doc.body_ids()) bodies.push_back(report_body(doc, id));
    j["bodies"] = std::move(bodies);
    j["features"] = report_features(doc);
    return j;
}

EntityId add_box_hole(Document& doc, double dx, double dy, double dz, double diameter,
                      EntityId* box_fid, EntityId* hole_fid) {
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", dx}, {"b", dy}, {"c", dz}};
    const EntityId bid = doc.graph().add(std::move(box));
    if (box_fid) *box_fid = bid;

    Feature hole;
    hole.type = FeatureType::Hole;
    hole.params = {{"target", bid.str()},
                   {"type", "simple"},
                   {"position", nlohmann::json::array({dx / 2.0, dy / 2.0, dz})},
                   {"direction", nlohmann::json::array({0.0, 0.0, -1.0})},
                   {"diameter", diameter},
                   {"depth", 0.0},
                   {"cb_diameter", 0.0},
                   {"cb_depth", 0.0},
                   {"cs_diameter", 0.0},
                   {"cs_angle_deg", 90.0}};
    const EntityId hid = doc.graph().add(std::move(hole));
    if (hole_fid) *hole_fid = hid;

    std::string err;
    if (!doc.graph().regenerate(doc, &err)) {
        throw std::runtime_error("add_box_hole regenerate: " + err);
    }
    const Feature* bf = doc.graph().feature(bid);
    if (!bf) throw std::runtime_error("add_box_hole: missing box feature");
    return bf->output_body;
}

}  // namespace exactness
}  // namespace sx
