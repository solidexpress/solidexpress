// Headless exactness CLI. Prints JSON reports; used by tools/sx_exact.py.
#include <iostream>
#include <string>

#include "sx/document.hpp"
#include "sx/exactness.hpp"

static void usage() {
    std::cerr << "usage: sx_exact box-hole\n"
              << "       sx_exact help\n";
}

int main(int argc, char** argv) {
    const std::string cmd = argc > 1 ? argv[1] : "help";
    if (cmd == "help" || cmd == "-h" || cmd == "--help") {
        usage();
        return 0;
    }
    if (cmd == "box-hole") {
        sx::Document doc;
        const sx::EntityId body =
            sx::exactness::add_box_hole(doc, 20.0, 20.0, 10.0, 10.0);
        nlohmann::json out;
        out["body"] = sx::exactness::report_body(doc, body);
        out["features"] = sx::exactness::report_features(doc);
        std::cout << out.dump(2) << "\n";
        return 0;
    }
    usage();
    return 2;
}
