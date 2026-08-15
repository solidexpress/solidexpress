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

const std::vector<MechanicTool>& mechanic_tools() {
    // Minimal, opinionated set of shop-tool sizes (metric-focused).
    // AF = across flats (mm). Nozzle assumes common hotend hex sizes.
    static const std::vector<MechanicTool> table = {
        // Open-end wrench heads (blank) — AF flats for hex hardware
        {"open_end", "AF8", 8.0, 0.0},
        {"open_end", "AF10", 10.0, 0.0},
        {"open_end", "AF12", 12.0, 0.0},
        {"open_end", "AF13", 13.0, 0.0},
        {"open_end", "AF17", 17.0, 0.0},
        // Hex socket (internal hex) — Allen sizes seen on M4–M8 fasteners
        {"hex_socket", "AF4", 4.0, 0.0},
        {"hex_socket", "AF5", 5.0, 0.0},
        {"hex_socket", "AF6", 6.0, 0.0},
        {"hex_socket", "AF8", 8.0, 0.0},
        {"hex_socket", "AF10", 10.0, 0.0},
        // Driver bit blank — 1/4\" hex (6.35) and metric options
        {"driver_bit", "AF6", 6.0, 0.0},
        {"driver_bit", "AF6.35", 6.35, 0.0},
        {"driver_bit", "AF8", 8.0, 0.0},
        {"driver_bit", "AF10", 10.0, 0.0},
        // 3D printer nozzle hex (typical 7 mm; include one alternate)
        {"nozzle_hex", "7mm", 7.0, 0.4},
        {"nozzle_hex", "8mm", 8.0, 0.6},
    };
    return table;
}

std::vector<MechanicTool> mechanic_tools_of_kind(const std::string& kind) {
    std::vector<MechanicTool> out;
    for (const auto& t : mechanic_tools()) {
        if (t.kind == kind) out.push_back(t);
    }
    return out;
}

std::optional<MechanicTool> find_mechanic_tool(const std::string& kind,
                                               const std::string& designation) {
    for (const auto& t : mechanic_tools()) {
        if (t.kind == kind && t.designation == designation) return t;
    }
    return std::nullopt;
}

}  // namespace sx::catalog
