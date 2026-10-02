// OCCT 8 container aliases. Prefer these over the deprecated TopTools_* /
// TColgp_* typedef headers (removed iterators; typedefs warn since 8.0.0).
#pragma once

#include <NCollection_Array1.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_IndexedMap.hxx>
#include <NCollection_List.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

namespace sx::occt {

using ShapeList = NCollection_List<TopoDS_Shape>;
using ShapeIndexedMap =
    NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>;
using ShapeIndexedDataMapOfList = NCollection_IndexedDataMap<
    TopoDS_Shape, ShapeList, TopTools_ShapeMapHasher>;
using Array1OfPnt = NCollection_Array1<gp_Pnt>;

}  // namespace sx::occt
