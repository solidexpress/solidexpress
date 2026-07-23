class_name Shortcuts
## Central keyboard / mouse shortcut registry for the F1 help overlay.
## Entries mirror the live bindings in orbit_camera, viewport_interaction, and main.


const TABLE: Array[Dictionary] = [
	# View (orbit_camera.gd + viewport_interaction display/section/gizmos)
	{"keys": "Empty-space drag", "context": "View", "desc": "Orbit camera"},
	{"keys": "Right-drag", "context": "View", "desc": "Orbit camera (click alone opens context menu)"},
	{"keys": "Two-finger drag", "context": "View", "desc": "Orbit camera (trackpad; hold left-click for more sensitivity)"},
	{"keys": "Shift+Two-finger", "context": "View", "desc": "Pan camera (trackpad)"},
	{"keys": "3-finger grip / Middle-drag", "context": "View", "desc": "Pan (SX/Fusion) or orbit (SW nav preset)"},
	{"keys": "Alt+Left-drag", "context": "View", "desc": "Orbit camera (SX/SW; Fusion pans like middle)"},
	{"keys": "Shift+Middle", "context": "View", "desc": "Orbit (SX/Fusion) or pan (SW nav preset)"},
	{"keys": "Alt+Shift+Left-drag", "context": "View", "desc": "Pan (SX/SW) or orbit (Fusion)"},
	{"keys": "Double-Middle", "context": "View", "desc": "Zoom extents — fit selection (or all)"},
	{"keys": "Wheel / pinch", "context": "View", "desc": "Zoom toward cursor (Ctrl+two-finger drag also zooms on Linux); zoom-out gently recenters on the model"},
	{"keys": "Ctrl+Empty-drag", "context": "View", "desc": "Rubber-band box select"},
	{"keys": "Space", "context": "View", "desc": "Orientation panel (views / fit / named view)"},
	{"keys": "Right-click", "context": "Model", "desc": "Selection context menu (Fillet / Active plane / Look at / Hide / Delete)"},
	{"keys": "Rotate arcs / Pull tip", "context": "Model", "desc": "Rotate about X/Y/Z or push/pull selected face"},
	{"keys": "F", "context": "View", "desc": "Zoom extents — fit selection (or all if none), centered on the objects"},
	{"keys": "Shift+F", "context": "View", "desc": "Zoom extents — fit all visible bodies"},
	{"keys": "1", "context": "View", "desc": "Front view + zoom extents"},
	{"keys": "2", "context": "View", "desc": "Right view + zoom extents"},
	{"keys": "3", "context": "View", "desc": "Top view + zoom extents"},
	{"keys": "7", "context": "View", "desc": "Isometric view + zoom extents"},
	{"keys": "5", "context": "View", "desc": "Toggle orthographic / perspective"},
	{"keys": "View → Save", "context": "View", "desc": "Save named view (orientation + zoom + target)"},
	{"keys": "View → Saved name", "context": "View", "desc": "Restore that named view including zoom"},
	{"keys": "W", "context": "View", "desc": "Cycle display mode (shaded / edges / wireframe)"},
	{"keys": "K", "context": "View", "desc": "Toggle section view"},
	{"keys": "G", "context": "View", "desc": "Toggle origin gizmos and grid"},
	{"keys": "View → Set Active Plane…", "context": "Model", "desc": "Click a flat face (or empty ground to reset) as the body-move plane"},
	# Model (viewport_interaction.gd)
	{"keys": "Click", "context": "Model", "desc": "Select body (again for face / edge)"},
	{"keys": "Empty click", "context": "Model", "desc": "Clear selection"},
	{"keys": "Hover A then B", "context": "Model", "desc": "Measure: X on A, then diagonal + Δx/Δy/Δz to B’s nearest edge (one pair)"},
	{"keys": "Esc (with measure X)", "context": "Model", "desc": "Clear the hover measure pair"},
	{"keys": "Shift+Click", "context": "Model", "desc": "Add / toggle multi-select (empty click keeps selection)"},
	{"keys": "Ctrl+Click", "context": "Model", "desc": "Add / toggle multi-select"},
	{"keys": "Shift+Left-drag (empty)", "context": "Model", "desc": "Window box select — only fully enclosed bodies / sketch pads"},
	{"keys": "Shift+Right-drag (empty)", "context": "Model", "desc": "Crossing box select — partial capture counts"},
	{"keys": "Ctrl+Left-drag (empty)", "context": "Model", "desc": "Window box select (alias of Shift+left-drag)"},
	{"keys": "Join / Subtract / Intersect / Group / Similar", "context": "Model", "desc": "Multi-body strip — booleans, isolate group, expand by feature kind"},
	{"keys": "Drag body", "context": "Model", "desc": "Move on the active plane; shows old/new center + editable Δ"},
	{"keys": "Lift grip (inset elevator)", "context": "Model", "desc": "Double-headed grip along the active-plane normal — leave / approach the plane"},
	{"keys": "Set as active plane", "context": "Model", "desc": "Face RMB / selection strip — use that flat face as the move plane"},
	{"keys": "X / Y / Z (while moving)", "context": "Model", "desc": "Lock the body move to that axis (Z = lift along plane normal; tap again to free)"},
	{"keys": "Stretch arrow (face)", "context": "Model", "desc": "Single outward chevron — stretch that face; Enter refines Δ"},
	{"keys": "Drag rotate arc", "context": "Model", "desc": "Rotate about that axis; Enter refines Δ°"},
	{"keys": "Drag face", "context": "Model", "desc": "Push / pull selected face"},
	{"keys": "Del / Backspace", "context": "Model", "desc": "Delete selected body (or component instance)"},
	{"keys": "Ctrl+A", "context": "Model", "desc": "Select all faces on body (or all bodies)"},
	{"keys": "Ctrl+X", "context": "Model", "desc": "Cut selected bodies to clipboard"},
	{"keys": "Ctrl+C", "context": "Model", "desc": "Copy selected bodies to clipboard"},
	{"keys": "Ctrl+V", "context": "Model", "desc": "Paste bodies offset 20% of bounds on the ground plane"},
	{"keys": "Ctrl+Shift+V", "context": "Model", "desc": "Paste Special (custom / in-place offset)"},
	{"keys": "Edit menu", "context": "Model", "desc": "Undo / Redo / Cut / Copy / Paste / Paste Special / Select All / Delete"},
	{"keys": "Drag instance", "context": "Model", "desc": "Move a component instance; mates re-solve on release"},
	{"keys": "Ctrl+Z", "context": "Model", "desc": "Undo"},
	{"keys": "Ctrl+Y", "context": "Model", "desc": "Redo"},
	{"keys": "Ctrl+Shift+Z", "context": "Model", "desc": "Redo"},
	# Voice (voice_capture.gd — hold-to-talk; registry is documentation only)
	{"keys": "V (hold)", "context": "Model", "desc": "Push-to-talk voice capture"},
	# Sketch (viewport_interaction._sketch_input)
	{"keys": "S", "context": "Sketch", "desc": "Select tool"},
	{"keys": "L", "context": "Sketch", "desc": "Line tool"},
	{"keys": "R", "context": "Sketch", "desc": "Rectangle tool"},
	{"keys": "C", "context": "Sketch", "desc": "Circle tool"},
	{"keys": "T", "context": "Sketch", "desc": "Trim tool"},
	{"keys": "X", "context": "Sketch", "desc": "Toggle construction on selection"},
	{"keys": "Ctrl+X / C / V / A", "context": "Sketch", "desc": "Cut / Copy / Paste / Select-all sketch entities"},
	{"keys": "Click badge", "context": "Sketch", "desc": "Select a constraint (H/V/∥/⊥/=/◉ glyphs)"},
	{"keys": "Del", "context": "Sketch", "desc": "Delete the selected constraint badge"},
	{"keys": "Click dimension", "context": "Sketch", "desc": "Edit the value in place (Enter commits)"},
	{"keys": "Digits / finish-bar mm", "context": "Sketch", "desc": "While rubber-banding (1 DOF): type length/radius; Enter places; Esc unlocks"},
	{"keys": "Right-click", "context": "Sketch", "desc": "End line chain"},
	{"keys": "Esc", "context": "Sketch", "desc": "Clear measure ✕, then discard sketch"},
	{"keys": "Exit Sketch", "context": "Sketch", "desc": "Commit sketch (yellow pad) and restore camera"},
	# Timeline (timeline_panel.gd)
	{"keys": "Drag row", "context": "Timeline", "desc": "Reorder features (blocked drops flash red)"},
	{"keys": "Drag rollback bar", "context": "Timeline", "desc": "Suspend features below the bar (double-click = roll to end)"},
	# File (main.gd _unhandled_input)
	{"keys": "Ctrl+S", "context": "File", "desc": "Save"},
	{"keys": "Ctrl+O", "context": "File", "desc": "Open"},
]


static func all() -> Array[Dictionary]:
	return TABLE


static func by_context() -> Dictionary:
	var out: Dictionary = {}
	for entry in TABLE:
		var ctx: String = entry["context"]
		if not out.has(ctx):
			out[ctx] = [] as Array
		(out[ctx] as Array).append(entry)
	return out


static func describe(keys: String) -> String:
	for entry in TABLE:
		if entry["keys"] == keys:
			return entry["desc"]
	return ""
