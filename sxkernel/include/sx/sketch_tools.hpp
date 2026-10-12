#pragma once
// Pure 2D sketch geometry tools (fillet, offset, trim, extend, pattern).
// No OCCT dependency.

#include <string>
#include <vector>

#include "sx/sketch.hpp"

namespace sx::sketch_tools {

// Trim two lines that share a corner and insert a tangent fillet arc.
// Returns the new arc entity id, or "" on failure.
std::string fillet_corner(Sketch& s, const std::string& line_a_id,
                          const std::string& line_b_id, double radius);

// Offset each entity by signed distance (OFFSETTERS table by entity type).
// Lines: a parallel copy (positive = left of direction). Circles: a new
// profile circle with Concentric to the source and a driving Radius =
// r + signed distance. Distance ≈ 0, or a circle with r + d ≤ 0, is refused
// (empty result, sketch unchanged for that entity). Arcs are skipped.
// Returns new entity ids in input order (omitting skips / refusals).
std::vector<std::string> offset_entities(Sketch& s,
                                         const std::vector<std::string>& entity_ids,
                                         double distance);

// Trim the portion of a line or circle nearest to (px, py), bounded by its
// intersections with other non-construction lines/circles.
//
// LINE: intersections at parameter t in (0,1). End-segment trim shortens the
// existing line; interior trim removes it and adds two shorter lines.
// CIRCLE: with >= 2 intersections, replaces the circle with an ARC spanning
// the remaining (untrimmed) portion via Sketch::add_arc.
//
// Constraints that reference a removed/replaced entity are dropped (same as
// Sketch::remove_entity). End-segment line trim keeps the entity id, so its
// constraints remain (endpoints may move).
// Returns false if the entity is missing/unsupported or has no trimmable
// intersection near the pick.
bool trim_entity(Sketch& s, const std::string& entity_id, double px, double py);

// Extend a LINE's nearest-to-pick endpoint along the line until the first
// forward intersection with another non-construction entity (other lines as
// segments, circles as full circles). Updates that endpoint in place (entity
// id unchanged). Circles/arcs and other kinds are unsupported in v1 (false).
// Returns false if missing/unsupported or no forward intersection.
bool extend_entity(Sketch& s, const std::string& entity_id, double px,
                   double py);

// Linear pattern: create count-1 translated copies of each entity (offset
// i*(dx,dy) for i = 1..count-1). Lines: both endpoints; circles: center
// (radius kept); arcs: center shifted, radius/angles kept. Construction
// flags copy through. count < 2 or zero direction → empty, unchanged.
// Returns ids of all newly created copies (input order, then copy index).
std::vector<std::string> pattern_entities(Sketch& s,
                                          const std::vector<std::string>& entity_ids,
                                          double dx, double dy, int count);

}  // namespace sx::sketch_tools
