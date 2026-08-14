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

// Wave 6.5 — mechanic-tool catalog (shop tooling, not a full Toolbox).
// Provides a small in-base table so the UI can surface common drop-ins.
struct MechanicTool {
    // kind: "open_end", "hex_socket", "driver_bit", "nozzle_hex"
    std::string kind;
    // Human-readable size code (e.g., "AF10", "7mm").
    std::string designation;
    // Across-flats size for hex-based tools (mm). 0.0 when not applicable.
    double af_mm = 0.0;
    // Optional nominal size for non-AF variants (e.g., nozzle orifice).
    double size_mm = 0.0;
};

// Entire mechanic-tool table (static, in-memory).
const std::vector<MechanicTool>& mechanic_tools();
// Filtered view by kind.
std::vector<MechanicTool> mechanic_tools_of_kind(const std::string& kind);
// Lookup by kind + designation (exact match).
std::optional<MechanicTool> find_mechanic_tool(const std::string& kind,
                                               const std::string& designation);

}  // namespace sx::catalog
