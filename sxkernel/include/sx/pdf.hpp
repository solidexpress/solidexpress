#pragma once
// Tiny vector PDF writer. No dependency — enough for a drawing sheet of
// polylines, dims, and a title block. libdxfrw / cairo stay banned.

#include <string>
#include <vector>

#include "sx/drawings.hpp"

namespace sx {

// Writes a one-page PDF (mm mapped to points). Returns false on I/O failure.
bool write_pdf(const std::vector<drawings::PlacedView>& views, const std::string& path,
               double scale = 1.0, const std::string& title = "SOLIDEXPRESS");

}  // namespace sx
