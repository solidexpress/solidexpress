#pragma once
// Real surface / face-local solid ops behind the Knit, Thicken, ReplaceFace,
// Rib and Wrap features. Each returns a null shape on failure and, when given
// a non-null `err`, a short reason fit for a timeline badge.

#include <string>
#include <vector>

#include <TopoDS_Shape.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

namespace sx::surf {

// Sew faces / shells into one shape. A closed result becomes a solid, so six
// planes knit into a box rather than staying six loose sheets.
TopoDS_Shape knit(const std::vector<TopoDS_Shape>& parts, double tolerance = 1e-6,
                  std::string* err = nullptr);

// Give a face or shell thickness, turning a surface into a solid.
TopoDS_Shape thicken(const TopoDS_Shape& sheet, double offset, std::string* err = nullptr);

// A planar tool face spanning `solid`, for the datum-plane form of replace_face.
TopoDS_Shape plane_tool(const TopoDS_Shape& solid, const gp_Pnt& origin, const gp_Dir& normal);

// Trim `solid` back to `tool`, dropping the piece that carries `face`. The
// remaining topology is untouched, which is what makes this face-local rather
// than a whole-body offset.
TopoDS_Shape replace_face(const TopoDS_Shape& solid, const TopoDS_Shape& face,
                          const TopoDS_Shape& tool, std::string* err = nullptr);

// Rib solid: sweep `thickness` either side of an open polyline profile and
// raise it `height` along `dir`. Corner joints overlap so the rib is one solid.
TopoDS_Shape rib_solid(const std::vector<gp_Pnt>& profile, double thickness, double height,
                       const gp_Dir& dir, std::string* err = nullptr);

// `solid` grown (or shrunk, for a negative delta) by `delta` everywhere.
TopoDS_Shape offset_solid(const TopoDS_Shape& solid, double delta, std::string* err = nullptr);

// The part of `column` that lies within `depth` of the boundary of `solid` —
// just inside it, or just outside when `outward`. Cutting this stamp engraves
// a profile that follows the surface instead of slicing a slab through the body.
TopoDS_Shape surface_stamp(const TopoDS_Shape& solid, const TopoDS_Shape& column, double depth,
                           bool outward = false, std::string* err = nullptr);

// True when the shape carries at least one non-planar face — the cheap check
// that separates a real bend / blend from a fused box stand-in.
bool has_curved_face(const TopoDS_Shape& s);

}  // namespace sx::surf
