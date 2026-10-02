#include <catch.hpp>

#include "test_temp.hpp"

#include <BRep_Builder.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shell.hxx>

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

EntityId extrude_circle(Document& doc, FeatureGraph& graph, double thin) {
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = std::make_shared<Sketch>("Circle");
    skf.sketch->add_circle(0, 0, 10.0);
    auto sk_id = graph.add(std::move(skf));
    Feature ext;
    ext.type = FeatureType::Extrude;
    ext.params = {{"sketch", sk_id.str()},
                  {"distance", 10.0},
                  {"op", "new"},
                  {"end", "blind"},
                  {"thin_thickness", thin}};
    return graph.add(std::move(ext));
}

TopoDS_Shape box_missing_one_face() {
    TopoDS_Shape box = shape::make_box(10, 10, 10);
    BRep_Builder builder;
    TopoDS_Shell shell;
    builder.MakeShell(shell);
    bool skipped = false;
    for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next()) {
        if (!skipped) {
            skipped = true;
            continue;
        }
        builder.Add(shell, ex.Current());
    }
    return shell;
}

}  // namespace

TEST_CASE("circle thin wall is refused; thin 0 is a closed solid", "[rung01][replan]") {
    auto circle = std::make_shared<Sketch>("Circle");
    circle->add_circle(0, 0, 10.0);
    std::string face_err;
    TopoDS_Shape thin_face = circle->thin_profile_face(1.0, false, false, &face_err);
    CHECK(thin_face.IsNull());
    CHECK(face_err.find("Thin wall is on") != std::string::npos);
    CHECK(face_err.find("set 0 for a solid") != std::string::npos);

    Document doc;
    FeatureGraph graph;
    EntityId ext_id = extrude_circle(doc, graph, 1.0);
    std::string err;
    REQUIRE_FALSE(graph.regenerate(doc, &err));
    CHECK(err.find("Thin wall is on") != std::string::npos);
    CHECK(err.find("set 0 for a solid") != std::string::npos);
    CHECK(doc.body_ids().empty());
    CHECK(doc.body(graph.feature(ext_id)->output_body) == nullptr);

    json params = graph.feature(ext_id)->params;
    params["thin_thickness"] = 0.0;
    REQUIRE(graph.set_params(ext_id, params));
    REQUIRE(graph.regenerate(doc, &err));
    const Body* body = doc.body(graph.feature(ext_id)->output_body);
    REQUIRE(body != nullptr);
    CHECK(shape::count(body->shape).solids >= 1);

    sx::test::TmpFile solid("rung01_replan_solid.3mf");
    std::string last_export_error = "stale";
    REQUIRE(interop::export_3mf(doc, solid.path, &last_export_error));
    CHECK(last_export_error.empty());
    CHECK(std::filesystem::exists(solid.path));

    Document open;
    open.add_body(box_missing_one_face(), "Open");
    const std::string bad_path =
        (std::filesystem::temp_directory_path() / "rung01_replan_open.3mf").string();
    {
        std::ofstream preexisting(bad_path, std::ios::binary);
        preexisting << "stale zip";
    }
    REQUIRE(std::filesystem::exists(bad_path));
    last_export_error = "stale";
    REQUIRE_FALSE(interop::export_3mf(open, bad_path, &last_export_error));
    CHECK(last_export_error.find("open") != std::string::npos);
    int bad = 0, total = 0;
    REQUIRE(std::sscanf(last_export_error.c_str(),
                        "3MF mesh is open (%d/%d edges not shared twice)", &bad, &total) == 2);
    CHECK(bad > 0);
    CHECK(total >= bad);
    const std::string sentence = "3MF mesh is open (" + std::to_string(bad) + "/" +
                                 std::to_string(total) + " edges not shared twice)";
    CHECK(last_export_error == sentence);
    CHECK_FALSE(std::filesystem::exists(bad_path));
    std::remove(bad_path.c_str());
}
