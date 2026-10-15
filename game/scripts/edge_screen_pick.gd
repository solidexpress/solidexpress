class_name EdgeScreenPick
extends RefCounted
## Which of two edges a screen click is on.
##
## Closer to the cursor wins. Inside TIE_PX, the edge more parallel to the
## view wins (an end-on vertical beats the arc it meets). A stacked twin —
## the same direction, the same pixel — keeps the one nearer the camera,
## so a side view takes the visible edge and not the one behind it.


## Screen distances inside this band are one click, not two.
const TIE_PX := 8.0
## Alignment must differ by more than this before the end-on edge wins.
const ALIGN := 0.05
## Same pixel: below this, two projections are the same place on screen.
const STACK_PX := 1.0
## |dir · other| at or above this means the edges run together.
const PARALLEL := 0.999
## Nearer by less than this (mm) is the same depth.
const DEPTH_MM := 1.0


var px: float
var align: float
var cam: float
var dir: Vector3


func _init(screen_px: float, view_align: float, camera_mm: float, edge_dir: Vector3) -> void:
	px = screen_px
	align = view_align
	cam = camera_mm
	dir = edge_dir


## True when this edge is the one under the cursor, ahead of `other`.
func beats(other: EdgeScreenPick) -> bool:
	if px + TIE_PX < other.px:
		return true
	if other.px + TIE_PX < px:
		return false
	if align > other.align + ALIGN:
		return true
	if other.align > align + ALIGN:
		return false
	if _stacked_twin(other):
		return cam + DEPTH_MM < other.cam
	return px < other.px


func _stacked_twin(other: EdgeScreenPick) -> bool:
	return absf(px - other.px) <= STACK_PX and absf(dir.dot(other.dir)) >= PARALLEL
