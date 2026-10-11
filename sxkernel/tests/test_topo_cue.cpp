// Tests for cue refresh, edge midpoint sampling, and fixed-decimal format.
// The helpers own the geometry; this file only asserts their results.

#include <catch.hpp>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRep_Builder.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <cmath>

#include "features/ops.hpp"
#include "features/topo_cue.h"

using nlohmann::json;

TEST_CASE("refresh_cue stores, replaces the same shape, and keeps another", "[topo_cue]") {
    sx::TopoCue along;
    along.point = gp_XYZ(0, 0, 0);
    along.dir = gp_XYZ(1, 0, 0);
    along.tol = 0.5;

    json cues = json::object();
    REQUIRE(sx::refresh_cue(cues, "e", along, sx::EntityKind::Edge));
    REQUIRE(cues.contains("e"));
    REQUIRE(cues["e"]["point"][0].get<double>() == 0.0);
    REQUIRE_FALSE(cues["e"].contains("frac"));

    sx::TopoCue moved = along;
    moved.point = gp_XYZ(4.0, 0.1, 0.0);
    REQUIRE(sx::refresh_cue(cues, "e", moved, sx::EntityKind::Edge));
    REQUIRE(cues["e"]["point"][0].get<double>() == 4.0);

    sx::TopoCue other;
    other.point = gp_XYZ(0, 0, 0);
    other.dir = gp_XYZ(0, 1, 0);
    other.tol = 0.5;
    REQUIRE_FALSE(sx::refresh_cue(cues, "e", other, sx::EntityKind::Edge));
    REQUIRE(cues["e"]["dir"][0].get<double>() == 1.0);
    REQUIRE(cues["e"]["point"][0].get<double>() == 4.0);

    sx::TopoCue zero;
    zero.tol = 0.5;
    REQUIRE_FALSE(sx::refresh_cue(cues, "e", zero, sx::EntityKind::Edge));
    REQUIRE(cues["e"]["point"][0].get<double>() == 4.0);
}

TEST_CASE("edge_midpoint_sample on a line and a degenerate edge", "[topo_cue]") {
    const TopoDS_Edge line =
        BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge();
    gp_Pnt p;
    gp_Vec t;
    REQUIRE(sx::feature_ops::edge_midpoint_sample(line, p, t));
    REQUIRE(p.Distance(gp_Pnt(5, 0, 0)) < 1e-7);
    REQUIRE(std::abs(std::abs(t.X()) - 1.0) < 1e-9);
    REQUIRE(std::abs(t.Y()) < 1e-9);
    REQUIRE(std::abs(t.Z()) < 1e-9);

    TopoDS_Edge degenerate = line;
    BRep_Builder().Degenerated(degenerate, true);
    REQUIRE_FALSE(sx::feature_ops::edge_midpoint_sample(degenerate, p, t));
}

TEST_CASE("format_fixed prints fixed decimals and rounds", "[topo_cue]") {
    REQUIRE(sx::feature_ops::format_fixed(5.0, 4) == "5.0000");
    REQUIRE(sx::feature_ops::format_fixed(1.25, 1) == "1.3");
}
