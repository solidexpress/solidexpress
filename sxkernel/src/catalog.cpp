#include "sx/catalog.hpp"

namespace sx::catalog {

const std::vector<Fastener>& fasteners() {
    static const std::vector<Fastener> table = {
        {"M3x10", 3.0, 10.0, "hex_bolt"},
        {"M4x12", 4.0, 12.0, "hex_bolt"},
        {"M5x16", 5.0, 16.0, "hex_bolt"},
        {"M6x20", 6.0, 20.0, "hex_bolt"},
        {"M8x25", 8.0, 25.0, "hex_bolt"},
        {"M10x30", 10.0, 30.0, "hex_bolt"},
    };
    return table;
}

std::optional<Fastener> find_fastener(const std::string& designation) {
    for (const auto& f : fasteners()) {
        if (f.designation == designation) return f;
    }
    return std::nullopt;
}

}  // namespace sx::catalog
