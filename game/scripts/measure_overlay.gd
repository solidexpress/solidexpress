class_name MeasureOverlay
extends Node
## Measure chrome state: AABB size labels on the selection, plus up to two
## sticky hover ✕ marks (touch A → X sticks; approach a snap on B → second X
## plants while A is retained). The active mark drives live cardinal + diagonal
## dims. Drawn in screen space by ViewportInteraction at a DPI-stable font size
## (not tied to window size — stays readable when the app is resized).

signal changed

const COLOR_X := Color(0.95, 0.35, 0.3)
const COLOR_Y := Color(0.35, 0.9, 0.4)
const COLOR_Z := Color(0.4, 0.55, 1.0)
const COLOR_DIAG := Color(0.95, 0.9, 0.35)
const COLOR_BOUND := Color(0.85, 0.88, 0.95)
## Idle / retained previous ✕.
const COLOR_MARK := Color(1.0, 0.55, 0.2)
## Active ✕ while it drives a snap / live pair (more orange-red).
const COLOR_MARK_ACTIVE := Color(0.95, 0.35, 0.25)
const MAX_STICKY := 2

const BOUND_OFFSET_FRAC := 0.08
const BOUND_OFFSET_MIN := 2.5
## Label / mark base size in screen px (UiScale applies DPI; not window size).
const FONT_PX := 14
# DPI-stable overlay font: fraction of viewport height (≈ FONT_PX at 560 px).
const SCREEN_FRAC := 1.0 / 40.0

var view: DocumentView
## Optional sketch session for 2D measure mode (Δu/Δv along plane axes).
var sketch_mode: SketchMode

## Active (measure-driving) sticky ✕.
var anchor_point: Variant = null  # Vector3 when set
var anchor_body := ""
## Sketch-mode entity id for A (when measuring sketch entities).
var anchor_entity := ""
## True while the cursor is still on the active anchor body (X follows nearest edge).
var following := false
## Retained previous sticky ✕ (null when only one mark). Kept when a new snap
## plants a second mark so nearby snaps do not erase the prior reference.
var prev_point: Variant = null  # Vector3 when set
var prev_body := ""
var prev_entity := ""
## Last live B point while hovering a second body (null when not showing pair).
var _last_b: Variant = null

## Screen-draw lists (model-space points); rebuilt on every update.
var segments: Array = []  # {a: Vector3, b: Vector3, color: Color}
var marks: Array = []  # {p: Vector3, color: Color}
var labels: Array = []  # {p: Vector3, text: String, color: Color}


## Clear both sticky ✕ marks and live dims (keeps selection bound dims until refresh).
func clear_pair() -> void:
	anchor_point = null
	anchor_body = ""
	anchor_entity = ""
	prev_point = null
	prev_body = ""
	prev_entity = ""
	following = false
	_last_b = null
	_rebuild()


func clear_all() -> void:
	clear_pair()


## Hover update. Leaving A pins the X so B can compare against it.
## Pair dimensions exist only while hovering B; leave B → dims vanish, X stays.
## Callers pass an already-snapped `hit_point` (corner / edge mid / surface mid).
func update_hover(body: String, hit_point: Vector3) -> void:
	if view == null:
		return
	if body == "":
		if anchor_point == null:
			return
		# Pin A when the cursor leaves — do not drop the X; hide pair dims.
		following = false
		_rebuild()
		return

	if anchor_body == "" or body == anchor_body:
		# First touch / still on A / returned to A — X follows measure snap.
		anchor_body = body
		anchor_entity = ""
		anchor_point = hit_point
		following = true
		_rebuild()
		return

	# Touching a different body B: pin A, show live dims to `hit_point`
	# (caller chooses edge / perpendicular foot / etc.).
	following = false
	_rebuild(hit_point)


## Sketch-mode hover: entity id "" clears live B / pins A. Hit is model-space.
func update_sketch_hover(entity_id: String, hit_point: Vector3) -> void:
	if sketch_mode == null or not sketch_mode.active:
		return
	if entity_id == "":
		if anchor_point == null:
			return
		following = false
		_rebuild()
		return
	if anchor_entity == "" or entity_id == anchor_entity:
		anchor_entity = entity_id
		anchor_body = "sketch:" + entity_id
		anchor_point = hit_point
		following = true
		_rebuild()
		return
	following = false
	_rebuild(hit_point)


## Plant / move the active ✕ onto `body` at the nearest measure snap to
## `hit_point`. With one sticky already on another body, retains it as `prev`
## and plants a second mark (up to MAX_STICKY). With two stickies already,
## relocates only the active mark. Approaching a snap on the previous mark's
## body promotes that mark back to active.
func relocate_anchor(body: String, hit_point: Vector3) -> void:
	if view == null or body == "":
		return
	var snap: Vector3 = view.closest_measure_snap(body, hit_point)

	# Snap on the retained mark's body — promote it and update.
	if prev_point != null and body == prev_body:
		_swap_active_prev()
		anchor_point = snap
		anchor_entity = ""
		following = true
		_rebuild()
		return

	# Still on the active body — follow without touching prev.
	if anchor_point != null and body == anchor_body:
		anchor_point = snap
		anchor_entity = ""
		following = true
		_rebuild()
		return

	# New body while an active mark exists: keep the prior ✕ when we still
	# have a free sticky slot; otherwise relocate active only.
	if anchor_point != null and body != anchor_body:
		if prev_point == null:
			prev_point = anchor_point
			prev_body = anchor_body
			prev_entity = anchor_entity
		anchor_body = body
		anchor_entity = ""
		anchor_point = snap
		following = true
		_rebuild()
		return

	# First plant.
	anchor_body = body
	anchor_entity = ""
	anchor_point = snap
	following = true
	_rebuild()


## Show live pair dims to an explicit point (e.g. closest corner of a place ghost).
## Requires a pinned/following anchor; no-ops otherwise.
func set_live_target(point: Vector3) -> void:
	if anchor_point == null:
		return
	following = false
	_rebuild(point)


## Hide live B dims but keep the pinned X (leave-B / leave-ghost).
func clear_live_target() -> void:
	if anchor_point == null:
		return
	following = false
	_rebuild()


## Refresh selection AABB size labels (and redraw pair if any).
func refresh_bounds() -> void:
	_rebuild(_last_b if _last_b != null else null)


func has_anchor() -> bool:
	return anchor_point != null


func has_prev() -> bool:
	return prev_point != null


func is_showing_pair() -> bool:
	return anchor_point != null and _last_b != null


func sticky_count() -> int:
	var n := 0
	if anchor_point != null:
		n += 1
	if prev_point != null:
		n += 1
	return n


func _swap_active_prev() -> void:
	var tp: Variant = anchor_point
	var tb := anchor_body
	var te := anchor_entity
	anchor_point = prev_point
	anchor_body = prev_body
	anchor_entity = prev_entity
	prev_point = tp
	prev_body = tb
	prev_entity = te


func _rebuild(b_point: Variant = null) -> void:
	_last_b = b_point if b_point != null and typeof(b_point) == TYPE_VECTOR3 else null
	segments.clear()
	marks.clear()
	labels.clear()

	var two_stickies := anchor_point != null and prev_point != null
	var inter_sticky := two_stickies and _last_b == null and not following
	# Bound size labels only when idle (no live A→B / A↔prev pair crowding the view).
	if _last_b == null and not inter_sticky:
		_append_selection_bounds()

	if prev_point != null:
		var p: Vector3 = prev_point
		marks.append({"p": p, "color": COLOR_MARK})

	if anchor_point != null:
		var a: Vector3 = anchor_point
		var driving := following or _last_b != null or inter_sticky
		marks.append({"p": a, "color": COLOR_MARK_ACTIVE if driving else COLOR_MARK})
		if _last_b != null:
			var b: Vector3 = _last_b
			marks.append({"p": b, "color": COLOR_DIAG})
			_append_pair_dims(a, b)
		elif inter_sticky:
			var prev: Vector3 = prev_point
			_append_pair_dims(a, prev)

	changed.emit()


func _append_selection_bounds() -> void:
	if view == null:
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var size: Vector3 = mx - mn
	if size.length_squared() < 1e-12:
		return
	var pad := maxf(size.length() * BOUND_OFFSET_FRAC, BOUND_OFFSET_MIN)

	var ax0 := Vector3(mn.x, mn.y - pad, mn.z)
	var ax1 := Vector3(mx.x, mn.y - pad, mn.z)
	_add_dim_seg(ax0, ax1, COLOR_BOUND)
	labels.append({"p": (ax0 + ax1) * 0.5, "text": "%.2f" % size.x, "color": COLOR_BOUND, "rank": 10})

	var ay0 := Vector3(mn.x - pad, mn.y, mn.z)
	var ay1 := Vector3(mn.x - pad, mx.y, mn.z)
	_add_dim_seg(ay0, ay1, COLOR_BOUND)
	labels.append({"p": (ay0 + ay1) * 0.5, "text": "%.2f" % size.y, "color": COLOR_BOUND, "rank": 11})

	var az0 := Vector3(mx.x + pad, mn.y, mn.z)
	var az1 := Vector3(mx.x + pad, mn.y, mx.z)
	_add_dim_seg(az0, az1, COLOR_BOUND)
	labels.append({"p": (az0 + az1) * 0.5, "text": "%.2f" % size.z, "color": COLOR_BOUND, "rank": 12})


func _append_pair_dims(a: Vector3, b: Vector3) -> void:
	var d := b - a
	# Sketch mode: project Δ onto plane axes as Δu / Δv (RGB = plane X/Y).
	if sketch_mode != null and sketch_mode.active:
		_append_sketch_pair_dims(a, b)
		return
	# Stagger label stations along each segment + a perpendicular nudge so the
	# three cardinals and the diagonal don't share one midpoint in 3D.
	_add_dim_seg(a, b, COLOR_DIAG)
	labels.append({
		"p": a.lerp(b, 0.55) + _perp_nudge(d, Vector3(0, 0, 1), 1.6),
		"text": "%.2f" % a.distance_to(b),
		"color": COLOR_DIAG,
		"rank": 0,
	})

	if absf(d.x) > 1e-4:
		var bx := Vector3(b.x, a.y, a.z)
		_add_dim_seg(a, bx, COLOR_X)
		labels.append({
			"p": a.lerp(bx, 0.35) + Vector3(0, 1.2, 1.2),
			"text": "Δx %.2f" % absf(d.x),
			"color": COLOR_X,
			"rank": 1,
		})
	if absf(d.y) > 1e-4:
		var by0 := Vector3(b.x, a.y, a.z)
		var by1 := Vector3(b.x, b.y, a.z)
		_add_dim_seg(by0, by1, COLOR_Y)
		labels.append({
			"p": by0.lerp(by1, 0.5) + Vector3(1.2, 0, 1.2),
			"text": "Δy %.2f" % absf(d.y),
			"color": COLOR_Y,
			"rank": 2,
		})
	if absf(d.z) > 1e-4:
		var bz0 := Vector3(b.x, b.y, a.z)
		var bz1 := b
		_add_dim_seg(bz0, bz1, COLOR_Z)
		labels.append({
			"p": bz0.lerp(bz1, 0.65) + Vector3(1.2, 1.2, 0),
			"text": "Δz %.2f" % absf(d.z),
			"color": COLOR_Z,
			"rank": 3,
		})


func _append_sketch_pair_dims(a: Vector3, b: Vector3) -> void:
	var px: Vector3 = sketch_mode.plane_x
	var py: Vector3 = sketch_mode.plane_y
	var d := b - a
	var du := d.dot(px)
	var dv := d.dot(py)
	_add_dim_seg(a, b, COLOR_DIAG)
	labels.append({
		"p": a.lerp(b, 0.55) + _perp_nudge(d, sketch_mode.plane_normal(), 1.6),
		"text": "%.2f" % a.distance_to(b),
		"color": COLOR_DIAG,
		"rank": 0,
	})
	if absf(du) > 1e-4:
		var bu: Vector3 = a + px * du
		_add_dim_seg(a, bu, COLOR_X)
		labels.append({
			"p": a.lerp(bu, 0.4) + py * 1.2,
			"text": "Δu %.2f" % absf(du),
			"color": COLOR_X,
			"rank": 1,
		})
	if absf(dv) > 1e-4:
		var bv0: Vector3 = a + px * du
		var bv1: Vector3 = b
		_add_dim_seg(bv0, bv1, COLOR_Y)
		labels.append({
			"p": bv0.lerp(bv1, 0.5) + px * 1.2,
			"text": "Δv %.2f" % absf(dv),
			"color": COLOR_Y,
			"rank": 2,
		})


func _perp_nudge(along: Vector3, prefer: Vector3, amount: float) -> Vector3:
	var n := along.cross(prefer)
	if n.length_squared() < 1e-10:
		n = along.cross(Vector3(0, 1, 0))
	if n.length_squared() < 1e-10:
		return Vector3(0, 0, amount)
	return n.normalized() * amount


func _add_dim_seg(a: Vector3, b: Vector3, color: Color) -> void:
	segments.append({"a": a, "b": b, "color": color})
