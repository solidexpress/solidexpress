#pragma once
// Sheet-metal core (Wave 2): K-factor bend allowance and flange params.
// Flat lives in the same document — split viewport, not a second file.

#include <string>

#include <TopoDS_Shape.hxx>
#include <nlohmann/json.hpp>

#include "sx/shape_utils.hpp"

namespace sx::sheet {

// ISO-ish allowance: BA = angle * (R + K*T). Angle in radians.
double bend_allowance(double angle_rad, double thickness, double k_factor, double radius);

// Two-leg channel: L1 + L2 + BA − 2*T (outside dimensions).
double flat_length(double leg1, double leg2, double thickness, double k_factor, double radius,
                   double angle_rad = 1.5707963267948966);

struct FlangeParams {
    double length = 20.0;
    double thickness = 1.5;
    double k_factor = 0.44;
    double radius = 1.5;
    double angle_rad = 1.5707963267948966;
};

void to_json(nlohmann::json& j, const FlangeParams& p);
void from_json(const nlohmann::json& j, FlangeParams& p);

// A folded sheet and the blank it unfolds to. `folded` carries a real
// cylindrical bend face; `flat` is the developed blank, so their volumes agree
// to within the K-factor's departure from the mid-plane (K = 0.5).
struct FlangeBuild {
    TopoDS_Shape folded;
    TopoDS_Shape flat;
    double flat_length = 0.0;
    double bend_allowance = 0.0;
};

// Two legs joined by one bend, swept `width` deep. Legs follow the same
// convention as flat_length(): the straight portion of a leg is leg - thickness,
// the rest is consumed by the bend region. Returns null shapes when the legs
// are shorter than the thickness or the angle is not in (0, pi).
FlangeBuild build_flange(double base_leg, double flange_leg, double width,
                         const FlangeParams& p, const shape::Placement& at = {},
                         std::string* err = nullptr);

// Convert a thin solid: the smallest bbox side is the thickness. Flat is the
// mid-plane rectangle (the two larger sides).
bool is_thin_solid(const TopoDS_Shape& s, double* thickness);
double flat_area(const TopoDS_Shape& s);
TopoDS_Shape unfold_thin_solid(const TopoDS_Shape& s, std::string* err = nullptr);

}  // namespace sx::sheet
