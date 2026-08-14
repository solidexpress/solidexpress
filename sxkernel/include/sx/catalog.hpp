#pragma once
// In-base standard-parts catalog (Wave 4.12). Not a paid tier.

#include <optional>
#include <string>
#include <vector>

namespace sx::catalog {

struct Fastener {
    std::string designation;  // "M6x20"
    double diameter_mm = 6.0;
    double length_mm = 20.0;
    std::string kind = "hex_bolt";
};

const std::vector<Fastener>& fasteners();
std::optional<Fastener> find_fastener(const std::string& designation);

}  // namespace sx::catalog
