class_name WorldGizmos
extends Node3D
## Reference grid on the active move plane (default: model XY / Z = 0).
## RGB origin sticks live on the ViewHud (OriginTriadHud), not on this plate.
## Sibling of DocumentView under ModelSpace.
##
## Line spacing follows camera zoom: minor cells stay at least MIN_MINOR_PX
## wide on screen before the sheet steps up a decade (0.01 → 0.1 → 1 → 10…).

## Default / minimum sheet half-extent (mm). Coarser LODs grow the sheet so
## coverage stays useful when zoomed out.
const GRID_HALF := 50.0
## Finest minor step (mm); matches place-snap SpinBox minimum.
const GRID_STEP_FINEST := 0.01
## Default minor / major when no camera LOD has run yet.
const GRID_STEP := 0.1
const GRID_MAJOR := 1.0
## Major lines every N minor steps (decade grid).
const MAJOR_EVERY := 10
## Do not draw minor lines denser than this on screen (stops the plaid look).
## Tuned just under the default-view ~4 px / 0.1 mm cell so empty-scene zoom
## keeps the fine sheet; further zoom-out steps up by decades.
const MIN_MINOR_PX := 3.5
## Keep roughly this many minor steps from center to edge.
const TARGET_HALF_STEPS := 500
const GRID_HALF_MAX := 50000.0

## Low alpha so bodies and sketches read through the sheet.
const COLOR_GRID := Color(0.32, 0.33, 0.36, 0.18)
const COLOR_GRID_MAJOR := Color(0.48, 0.49, 0.54, 0.28)
const COLOR_GRID_CENTER_X := Color(0.72, 0.28, 0.26, 0.40)
const COLOR_GRID_CENTER_Y := Color(0.28, 0.68, 0.32, 0.40)

var gizmos_visible := true
var grid_visible := true
## Current LOD (mm). Public so the scale bar can label the major cell.
var grid_step_mm := GRID_STEP
var grid_major_mm := GRID_MAJOR
var grid_half_mm := GRID_HALF

var _grid: MeshInstance3D
## Stash if set_active_plane runs before _ready builds the grid.
var _pending_plane: Dictionary = {}


func _ready() -> void:
	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	_grid.mesh = _make_grid_mesh(grid_step_mm, grid_major_mm, grid_half_mm)
	_grid.material_override = _unshaded_vertex_color_material()
	add_child(_grid)
	if not _pending_plane.is_empty():
		set_active_plane(_pending_plane["origin"], _pending_plane["normal"])
		_pending_plane.clear()

	_apply_visibility()


func set_gizmos_visible(on: bool) -> void:
	gizmos_visible = on
	_apply_visibility()


func set_grid_visible(on: bool) -> void:
	grid_visible = on
	_apply_visibility()


## Rebuild the sheet so minor cells are ≥ MIN_MINOR_PX on screen.
## `px_per_mm` is pixels per model millimetre at the orbit pivot.
func refresh_lod(px_per_mm: float) -> void:
	var step := pick_minor_step_mm(px_per_mm)
	var major := step * float(MAJOR_EVERY)
	var half := clampf(step * float(TARGET_HALF_STEPS), GRID_HALF, GRID_HALF_MAX)
	if is_equal_approx(step, grid_step_mm) and is_equal_approx(half, grid_half_mm):
		return
	grid_step_mm = step
	grid_major_mm = major
	grid_half_mm = half
	if _grid == null:
		return
	_grid.mesh = _make_grid_mesh(step, major, half)


## Decade minor step that keeps cells at least MIN_MINOR_PX wide.
static func pick_minor_step_mm(px_per_mm: float) -> float:
	var ppm := maxf(px_per_mm, 1e-9)
	var step := GRID_STEP_FINEST
	# Cap so a pathological zoom cannot runaway the loop.
	for _i in range(12):
		if step * ppm >= MIN_MINOR_PX:
			return step
		step *= 10.0
	return step


## Place the white reference grid on `origin` with in-plane axes derived from
## `normal` (mesh is authored on local XY).
func set_active_plane(origin: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	if n.length_squared() < 1e-12:
		n = Vector3(0, 0, 1)
	var x := n.cross(Vector3(0, 0, 1))
	if x.length_squared() < 1e-12:
		x = Vector3.RIGHT
	else:
		x = x.normalized()
	var y := n.cross(x).normalized()
	if _grid == null:
		# Called before _ready in some headless setups — stash for _ready.
		_pending_plane = {"origin": origin, "normal": n}
		return
	_grid.transform = Transform3D(Basis(x, y, n), origin)


func _apply_visibility() -> void:
	if _grid:
		_grid.visible = gizmos_visible and grid_visible


func _unshaded_vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Reference grid on local XY (Z = 0); transform places it on the active plane.
func _make_grid_mesh(step: float, major: float, half: float) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Integer indices avoid float drift so major lines land on `major`.
	var n := int(round(half / step))
	var major_every := maxi(int(round(major / step)), 1)
	for k in range(-n, n + 1):
		var i := float(k) * step
		var is_center := k == 0
		var is_major := not is_center and (k % major_every) == 0
		# Lines parallel to Y (constant X).
		if is_center:
			im.surface_set_color(COLOR_GRID_CENTER_Y)
		elif is_major:
			im.surface_set_color(COLOR_GRID_MAJOR)
		else:
			im.surface_set_color(COLOR_GRID)
		im.surface_add_vertex(Vector3(i, -half, 0))
		im.surface_add_vertex(Vector3(i, half, 0))
		# Lines parallel to X (constant Y).
		if is_center:
			im.surface_set_color(COLOR_GRID_CENTER_X)
		elif is_major:
			im.surface_set_color(COLOR_GRID_MAJOR)
		else:
			im.surface_set_color(COLOR_GRID)
		im.surface_add_vertex(Vector3(-half, i, 0))
		im.surface_add_vertex(Vector3(half, i, 0))
	im.surface_end()
	return im
