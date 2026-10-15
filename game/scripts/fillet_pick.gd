class_name FilletPick
extends RefCounted
## Fillet/chamfer pick policy and the rung-3 corner → view table.
## OpsPanel asks; it does not branch on modifiers or hit kind.


## (first_pick, modifier, hit_kind) → action.
## modifier: "plain" | "shift". hit_kind: "edge" | "face".
const POLICY: Array[Dictionary] = [
	{"first": true, "mod": "plain", "hit": "edge", "action": "toggle_edge"},
	{"first": true, "mod": "plain", "hit": "face", "action": "take_face"},
	{"first": true, "mod": "shift", "hit": "edge", "action": "toggle_edge"},
	{"first": true, "mod": "shift", "hit": "face", "action": "take_face"},
	{"first": false, "mod": "plain", "hit": "edge", "action": "toggle_edge"},
	{"first": false, "mod": "plain", "hit": "face", "action": "refuse_face"},
	{"first": false, "mod": "shift", "hit": "edge", "action": "toggle_edge"},
	{"first": false, "mod": "shift", "hit": "face", "action": "add_face"},
]

## Pinned by run_rung01_replan12_pick.gd — do not change the wording.
const REFUSE_FACE := "No edge near click — click on an edge (a face click fillets the whole face only as the first pick)"

## Vertical corner (x, y) of the 120×120 base → view key that shows it
## without the Ø70 boss rim winning the pick (M12). Pick at mid-height.
const CORNERS: Array[Dictionary] = [
	{"x": 60.0, "y": 60.0, "view": KEY_2},
	{"x": 60.0, "y": -60.0, "view": KEY_2},
	{"x": -60.0, "y": 60.0, "view": KEY_6},
	{"x": -60.0, "y": -60.0, "view": KEY_6},
]


static func decide(first_pick: bool, shift: bool, hit_kind: String) -> String:
	var mod := "shift" if shift else "plain"
	for row in POLICY:
		if bool(row["first"]) != first_pick:
			continue
		if str(row["mod"]) != mod:
			continue
		if str(row["hit"]) != hit_kind:
			continue
		return str(row["action"])
	return "miss"


static func pick_point_for_corner(x: float, y: float, z_mid: float = 15.0) -> Vector3:
	return Vector3(x, y, z_mid)
