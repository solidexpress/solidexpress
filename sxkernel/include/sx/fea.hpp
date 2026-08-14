#pragma once
// Linear static FEA helpers (Wave 4.4). Closed-form beam — no CalculiX/Gmsh.

namespace sx::fea {

// Cantilever tip deflection δ = F L³ / (3 E I). Units N, mm, MPa, mm⁴ → mm.
double cantilever_deflection(double force_n, double length_mm, double e_mpa, double i_mm4);

// Rectangular section I = w t³ / 12.
double rect_inertia(double width_mm, double thickness_mm);

}  // namespace sx::fea
