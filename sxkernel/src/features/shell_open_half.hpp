#pragma once
// Owns: shelling a solid half of an already-open body without thickening
// existing walls. Plug-plane split, shell the solid piece, fuse keepers.

#include <string>

#include <TopoDS_Shape.hxx>

#include "sx/occt_types.hpp"

namespace sx::feature_ops {

bool shell_keeping_open_walls(const TopoDS_Shape& body, const sx::occt::ShapeList& remove_faces,
                              double thickness, TopoDS_Shape& result, std::string* err);

}  // namespace sx::feature_ops
