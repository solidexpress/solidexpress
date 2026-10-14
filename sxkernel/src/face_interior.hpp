#pragma once
// One interior sample for a face: the UV-grid point nearest the middle of
// the parameter box that BRepClass_FaceClassifier marks TopAbs_IN.
// Dress-up face cues and measure::face_pick_point both call this. A UV-box
// centre of an annulus falls in the hole; this sample does not.

#include <TopoDS_Face.hxx>
#include <gp_Pnt.hxx>

namespace sx::measure {

bool face_interior_point(const TopoDS_Face& face, gp_Pnt& out);

}  // namespace sx::measure
