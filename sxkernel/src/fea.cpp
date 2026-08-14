#include "sx/fea.hpp"

namespace sx::fea {

double cantilever_deflection(double force_n, double length_mm, double e_mpa, double i_mm4) {
    if (e_mpa <= 0.0 || i_mm4 <= 0.0) return 0.0;
    return force_n * length_mm * length_mm * length_mm / (3.0 * e_mpa * i_mm4);
}

double rect_inertia(double width_mm, double thickness_mm) {
    return width_mm * thickness_mm * thickness_mm * thickness_mm / 12.0;
}

}  // namespace sx::fea
