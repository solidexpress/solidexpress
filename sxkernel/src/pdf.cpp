#include "sx/pdf.hpp"

#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>

namespace sx {
namespace {

std::string pdf_escape(const std::string& s) {
    std::string o;
    for (char c : s) {
        if (c == '(' || c == ')' || c == '\\') o.push_back('\\');
        o.push_back(c);
    }
    return o;
}

void line_ops(std::ostringstream& c, double x1, double y1, double x2, double y2) {
    c << x1 << " " << y1 << " m " << x2 << " " << y2 << " l S\n";
}

}  // namespace

bool write_pdf(const std::vector<drawings::PlacedView>& views, const std::string& path,
               double scale, const std::string& title) {
    if (views.empty()) return false;
    double min_x = 1e9, min_y = 1e9, max_x = -1e9, max_y = -1e9;
    for (const auto& pv : views) {
        min_x = std::min(min_x, pv.offset_x + pv.view.min_x);
        min_y = std::min(min_y, pv.offset_y + pv.view.min_y);
        max_x = std::max(max_x, pv.offset_x + pv.view.max_x);
        max_y = std::max(max_y, pv.offset_y + pv.view.max_y);
    }
    const double margin = 20.0;
    const double w = std::max(200.0, (max_x - min_x) * scale + margin * 2);
    const double h = std::max(200.0, (max_y - min_y) * scale + margin * 2 + 24);

    std::ostringstream content;
    content << "0.15 0.15 0.16 RG 0.6 w\n";
    auto mapx = [&](double x) { return (x - min_x) * scale + margin; };
    auto mapy = [&](double y) { return (y - min_y) * scale + margin + 16; };
    for (const auto& pv : views) {
        for (const auto& pl : pv.view.visible) {
            if (pl.size() < 2) continue;
            for (size_t i = 1; i < pl.size(); ++i) {
                line_ops(content, mapx(pv.offset_x + pl[i - 1][0]), mapy(pv.offset_y + pl[i - 1][1]),
                         mapx(pv.offset_x + pl[i][0]), mapy(pv.offset_y + pl[i][1]));
            }
        }
        content << "[2 2] 0 d 0.45 0.45 0.48 RG\n";
        for (const auto& pl : pv.view.hidden) {
            if (pl.size() < 2) continue;
            for (size_t i = 1; i < pl.size(); ++i) {
                line_ops(content, mapx(pv.offset_x + pl[i - 1][0]), mapy(pv.offset_y + pl[i - 1][1]),
                         mapx(pv.offset_x + pl[i][0]), mapy(pv.offset_y + pl[i][1]));
            }
        }
        content << "[] 0 d 0.15 0.15 0.16 RG\n";
    }
    content << "BT /F1 10 Tf 12 " << (h - 16) << " Td (" << pdf_escape(title) << ") Tj ET\n";
    const std::string stream = content.str();

    std::ostringstream pdf;
    auto obj = [&](int n, const std::string& body) {
        return std::to_string(n) + " 0 obj\n" + body + "\nendobj\n";
    };
    std::string o1 = obj(1, "<< /Type /Catalog /Pages 2 0 R >>");
    std::string o2 = obj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>");
    std::ostringstream page;
    page << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 " << w << " " << h
         << "] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>";
    std::string o3 = obj(3, page.str());
    std::ostringstream cobj;
    cobj << "<< /Length " << stream.size() << " >>\nstream\n" << stream << "endstream";
    std::string o4 = obj(4, cobj.str());
    std::string o5 = obj(5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

    pdf << "%PDF-1.4\n";
    std::vector<std::string> objs{o1, o2, o3, o4, o5};
    std::vector<long> xref;
    xref.push_back(0);
    for (const auto& o : objs) {
        xref.push_back(static_cast<long>(pdf.tellp()));
        pdf << o;
    }
    const long xref_pos = static_cast<long>(pdf.tellp());
    pdf << "xref\n0 " << (objs.size() + 1) << "\n";
    pdf << "0000000000 65535 f \n";
    for (size_t i = 1; i < xref.size(); ++i) {
        char buf[32];
        std::snprintf(buf, sizeof(buf), "%010ld 00000 n \n", xref[i]);
        pdf << buf;
    }
    pdf << "trailer << /Size " << (objs.size() + 1) << " /Root 1 0 R >>\nstartxref\n"
        << xref_pos << "\n%%EOF\n";

    std::ofstream out(path, std::ios::binary);
    if (!out) return false;
    out << pdf.str();
    return static_cast<bool>(out);
}

}  // namespace sx
