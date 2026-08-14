// Headless CLI linking only sxkernel (Wave 3.8). No Godot.
//   sxcli bracket.sxp --set a=55 --export out.step
//   sxcli --new-bracket out.step

#include <iostream>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/sxp.hpp"

using namespace sx;

static void build_bracket(Document& doc) {
    Feature prim;
    prim.type = FeatureType::Primitive;
    prim.name = "bracket";
    prim.params = {{"kind", "box"}, {"a", 80.0}, {"b", 40.0}, {"c", 10.0}};
    doc.graph().add(std::move(prim));
    doc.graph().regenerate(doc);
}

int main(int argc, char** argv) {
    std::string in_sxp;
    std::string export_path;
    std::string set_name;
    std::string set_expr;
    bool new_bracket = false;
    for (int i = 1; i < argc; ++i) {
        const std::string a = argv[i];
        if (a == "--new-bracket" && i + 1 < argc) {
            new_bracket = true;
            export_path = argv[++i];
        } else if (a == "--export" && i + 1 < argc) {
            export_path = argv[++i];
        } else if (a == "--set" && i + 1 < argc) {
            const std::string kv = argv[++i];
            auto eq = kv.find('=');
            if (eq != std::string::npos) {
                set_name = kv.substr(0, eq);
                set_expr = kv.substr(eq + 1);
            }
        } else if (a == "--help" || a == "-h") {
            std::cout << "sxcli [file.sxp] [--set name=expr] [--export out.step]\n"
                      << "sxcli --new-bracket out.step\n";
            return 0;
        } else if (!a.empty() && a[0] != '-') {
            in_sxp = a;
        }
    }

    Document doc;
    std::string err;
    if (new_bracket) {
        build_bracket(doc);
    } else if (!in_sxp.empty()) {
        if (!load_sxp(doc, in_sxp, &err)) {
            std::cerr << err << "\n";
            return 1;
        }
    } else {
        build_bracket(doc);
    }

    if (!set_name.empty()) {
        doc.graph().variables().set(set_name, set_expr);
        if (!doc.graph().regenerate(doc, &err)) {
            std::cerr << err << "\n";
            return 2;
        }
    }

    if (export_path.empty()) export_path = "bracket.step";
    if (!interop::export_step(doc, export_path, &err)) {
        std::cerr << (err.empty() ? "export failed" : err) << "\n";
        return 3;
    }
    std::cout << "wrote " << export_path << "\n";
    return 0;
}
