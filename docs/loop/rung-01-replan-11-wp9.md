# Replan 11 WP9 — the slot sketch follows the face

You are a BUILD agent. Implement only this WP. Second and last C++ work package.

C++ files, and no others:

- `sxkernel/include/sx/sketch.hpp`
- `sxkernel/src/sketch.cpp`
- `sxkernel/src/features.cpp`

GDScript and the checker:

- `game/scripts/sketch_mode.gd` — support fields, `begin`, `begin_edit`, `begin_on_plane`, `_ensure_sketch_feature`, the `graph_add_sketch` arm of `exit_sketch`, and a new static `_support_side` next to `derive_face_plane`
- `game/scripts/main.gd` — `_start_sketch_on_face` only
- `tools/check_rung01.py` — the `kind == 'thick'` branch only, one new row

Do not edit `ops_dress.cpp` (WP2). Do not edit `sxcore`. Do not add a GDExtension method. Support params go through the existing `graph_set_params_no_regen`.

Rebase onto WP4, WP6, and WP8 before editing `sketch_mode.gd`. Those hunks are the trim cutter, the dimension labels, and the polygon block. This WP does not touch them.

## Behaviour

A sketch started on a face remembers which body and which side. A later thickness edit moves that sketch plane onto the same side of the updated body. The grip slot cut, drawn on the top face, stays open from the new top. Old documents that have no support keys keep the absolute plane they were saved with.

Keys, stored on the sketch **feature** params (they already round-trip in `timeline[].params`):

| Key | Value |
|---|---|
| `support_host` | feature id string from `feature_of_body` (the extrude or primitive that owns the body) |
| `support_normal` | `[x, y, z]` unit normal, the outward normal `derive_face_plane` returned |
| `support_side` | `"max"` or `"min"` |

`feature_of_body` returns the feature whose `output_body` equals the body id. Cuts call `replace_body_shape` on that same body, so the host id stays the original extrude even after the jaw cut. At slot-sketch apply time the host body is already the latest shape, and the max +Z face is the new top.

Ground sketches and `begin_on_plane` write no keys. `begin_edit` does not clear the feature params.

`_start_sketch_on_face`: if `face_id` is set and the derived plane is not ok, do not call `begin`. Emit `plane["message"]` and return. That is the false `Sketch on ground (XY)` fix. WP10 owns the cancel status sentence.

## C++

### `Sketch::set_plane`

In `sxkernel/include/sx/sketch.hpp`, after `plane()` (line 105):

```cpp
void set_plane(SketchPlane plane);
```

In `sxkernel/src/sketch.cpp`, after the constructor (line 88):

```cpp
void Sketch::set_plane(SketchPlane plane) {
    plane_ = std::move(plane);
    revision_++;
}
```

This does not clear entities, constraints, or params. JSON load does not need to call it.

### Rebind on sketch apply

`features.cpp` already includes `BRepAdaptor_Surface.hxx`, `GeomAbs_SurfaceType.hxx`, `TopExp_Explorer.hxx`, `TopoDS.hxx`, `gp_Dir.hxx`, and `gp_Vec.hxx`. If `TopAbs_Orientation` is not visible, add `#include <TopAbs_Orientation.hxx>`.

Add this function in the anonymous namespace above `FeatureGraph::apply` (the namespace closes at line 909):

```cpp
void rebind_sketch_support(FeatureGraph& graph, Document& doc, Feature& f) {
    if (!f.sketch) return;
    if (!f.params.contains("support_host") || !f.params["support_host"].is_string()) return;
    if (!f.params.contains("support_normal") || !f.params["support_normal"].is_array()
        || f.params["support_normal"].size() < 3) return;
    gp_Vec want(f.params["support_normal"][0].get<double>(),
                f.params["support_normal"][1].get<double>(),
                f.params["support_normal"][2].get<double>());
    if (want.Magnitude() < 1e-12) return;
    want.Normalize();
    const Feature* host = graph.feature(
        EntityId::from_string(f.params["support_host"].get<std::string>()));
    if (host == nullptr || host->output_body.is_null()) return;
    const Body* body = doc.body(host->output_body);
    if (body == nullptr || body->shape.IsNull()) return;
    std::string side = "max";
    if (f.params.contains("support_side") && f.params["support_side"].is_string())
        side = f.params["support_side"].get<std::string>();
    bool have = false;
    double best = 0.0;
    for (TopExp_Explorer ex(body->shape, TopAbs_FACE); ex.More(); ex.Next()) {
        const TopoDS_Face face = TopoDS::Face(ex.Current());
        BRepAdaptor_Surface surf(face);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (gp_Vec(n).Dot(want) < 0.999) continue;
        const double offset = gp_Vec(surf.Plane().Location().XYZ()).Dot(want);
        if (!have || (side == "min" ? offset < best : offset > best)) {
            best = offset;
            have = true;
        }
    }
    if (!have) return;
    SketchPlane pl = f.sketch->plane();
    pl.origin = {want.X() * best, want.Y() * best, want.Z() * best};
    f.sketch->set_plane(std::move(pl));
}
```

`Plane().Location()` lies on the plane, so the offset is correct after the orientation flip. Keep `x_dir` and `y_dir`. A missing host or a missing matching face leaves the plane alone.

Replace the sketch case in `FeatureGraph::apply` (line 930):

```cpp
case FeatureType::Sketch:
    rebind_sketch_support(*this, doc, f);
    if (f.params.contains("converted_edges")) rebuild_converted_points(doc, f.id);
    return true;
```

Read `f.params`, not the `resolve_params` copy. No keys means the function returns immediately, so `run_rung01_sketch_tests` stays **70 checks, 7 failures**.

Do not add a Catch2 case. `make test-kernel` stays `All tests passed (7900 assertions in 330 test cases)`.

## GDScript

Fields next to `target_fid` (line 87):

```gdscript
var support_host := ""
var support_normal := Vector3.ZERO
var support_side := ""
```

```gdscript
func _clear_support() -> void:
	support_host = ""
	support_normal = Vector3.ZERO
	support_side = ""
```

`begin` gains an optional dictionary. Callers that omit it are ground sketches.

```gdscript
func begin(origin: Vector3, normal: Vector3, x_hint: Vector3 = Vector3.ZERO,
		support: Dictionary = {}) -> void:
	editing_fid = ""
	_clear_support()
	if not support.is_empty():
		support_host = str(support.get("host", ""))
		support_normal = support.get("normal", Vector3.ZERO)
		support_side = str(support.get("side", "max"))
	_setup_plane(origin, normal, x_hint)
	sketch = SxSketch.new()
	sketch.set_plane(origin, plane_x, plane_y)
	_activate_session()
	status.emit("Sketch: Select · Line · Rect · Circle · Exit Sketch · Esc discard")
```

`begin_on_plane`: call `_clear_support()` next to `editing_fid = ""`.

`begin_edit`: call `_clear_support()` after a successful load, before `_activate_session`. The feature params stay on the feature. Do not write params from `begin_edit`.

Static helper next to `derive_face_plane`. Top face +Z is `"max"` because its centre has the larger offset along +Z. A bottom face stores the outward normal `(0,0,-1)` and is also `"max"` along that normal.

```gdscript
static func support_side(doc: SxDocument, body_id: String, face_id: String,
		normal: Vector3) -> String:
	var n := normal.normalized()
	var face_bb: Dictionary = doc.measure_bbox(face_id)
	if face_bb.is_empty():
		return "max"
	var face_c: Vector3 = (face_bb["min"] + face_bb["max"]) * 0.5
	var face_off := face_c.dot(n)
	var max_off := face_off
	var min_off := face_off
	for fid in doc.get_face_ids(body_id):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var c: Vector3 = (bb["min"] + bb["max"]) * 0.5
		var off := c.dot(n)
		max_off = maxf(max_off, off)
		min_off = minf(min_off, off)
	if absf(face_off - max_off) <= absf(face_off - min_off):
		return "max"
	return "min"
```

Do not compare tessellated face normals here. The kernel dot test is 0.999 against the stored unit normal.

Write keys only when a new sketch feature is created and `support_host` is not empty. `set_params` replaces the whole object, so merge.

```gdscript
func _write_sketch_support(fid: String) -> void:
	if support_host == "" or view == null or view.doc == null:
		return
	var params := {}
	for f in view.doc.graph_features():
		if str(f.get("id", "")) != fid:
			continue
		var parsed = JSON.parse_string(str(f.get("params", "{}")))
		if typeof(parsed) == TYPE_DICTIONARY:
			params = parsed
		break
	params["support_host"] = support_host
	params["support_normal"] = [support_normal.x, support_normal.y, support_normal.z]
	params["support_side"] = support_side if support_side != "" else "max"
	view.doc.graph_set_params_no_regen(fid, JSON.stringify(params))
```

`graph_set_params_no_regen` does not push an undo step. Call it immediately after `graph_add_sketch` succeeds, before any later feature is added, so the next undo snapshot (the extrude) includes the keys. Do not add an sxcore method to fold the write into `graph_add_sketch`.

In `_ensure_sketch_feature`, after the successful `graph_add_sketch` branch sets `editing_fid`:

```gdscript
_write_sketch_support(sk_fid)
```

Do not write on the `editing_fid != ""` update path.

In `exit_sketch`, after `fid = view.doc.graph_add_sketch(sketch)` succeeds (the `else` arm, line 518), call `_write_sketch_support(fid)` before `_end_sketch_session()`.

### `main.gd` `_start_sketch_on_face`

Replace the function (line 1356):

```gdscript
func _start_sketch_on_face(face_id: String, body_id: String) -> void:
	var origin := Vector3.ZERO
	var normal := Vector3(0, 0, 1)
	var plane_msg := "Sketch on ground (XY)"
	sketch_mode.target_fid = ""
	if face_id != "" and body_id != "":
		sketch_mode.target_fid = view.feature_of_body(body_id)
		var fn := view.face_normal(body_id, face_id)
		var plane: Dictionary = SketchMode.derive_face_plane(
			view.doc, face_id, body_id, fn)
		plane_msg = plane["message"]
		if not plane["ok"]:
			_on_status(plane_msg)
			return
		origin = plane["origin"]
		normal = plane["normal"]
		var side := SketchMode.support_side(view.doc, body_id, face_id, normal)
		sketch_mode.begin(origin, normal, Vector3.ZERO, {
			"host": sketch_mode.target_fid,
			"normal": normal,
			"side": side,
		})
		_on_sketch_session_started(plane_msg)
		return
	sketch_mode.begin(origin, normal)
	_on_sketch_session_started(plane_msg)
```

`_start_sketch_on_ground` stays a plain `begin` with no support dictionary.

## Checker

In `tools/check_rung01.py`, inside `if kind == 'thick':`, after the jaw row and before `r.show()` (line 190). Use the `fx, fy` already chosen. Do not change the wrench-mode slot formulas.

```python
        W = align(V, fx, fy, (-10, -22.5, 0)); tr = tri_arrays(W, T)
        z_open = T_ - 1.25
        xs = [x for x in np.arange(60, 130, 1.0) if not inside(tr, (float(x), 0.0, z_open))]
        xm = float(np.median(xs)) if len(xs) else None
        floor = None
        if xm is not None:
            hit = first_hit(tr, (xm, 0.0, T_ + 5.0), (0, 0, -1))
            floor = None if hit is None else (T_ + 5.0) - hit
        slot_ok = (
            xm is not None
            and not inside(tr, (xm, 0.0, T_ - 1.25))
            and floor is not None and abs(floor - (T_ - 2.5)) <= TOL
            and not inside(tr, (xm, 0.0, T_ - 0.5))
        )
        r.add('grip slot open from the top', slot_ok,
              '' if slot_ok else f'xm={xm} floor={floor}',
              'open at z=T-1.25, floor T-2.5, solid skin absent at z=T-0.5')
```

One row. thick 4/4 becomes 5/5. A buried slot (floor still at 7.5 after T=14) fails this row. Do not require sx-031 3MF files to pass it.

## Build

```
make build
make test-kernel
```

`make test-kernel` prints `All tests passed (7900 assertions in 330 test cases)`.

## Test

`game/tests/run_rung01_replan11_slot.gd`. Boot `res://scenes/main.tscn` the way `run_rung01_replan11_views.gd` does (FilmUI, 1280×800). This is a validation script: it may call `insert_primitive`, `graph_set_params`, and `sketch.add_line`. It must not call `_look_along` or write `camera.yaw`.

`insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))` sits on z=0 and is 10 mm tall, so the top face is z=10. Find that face with `get_face_ids` and `measure_bbox` (largest centre z, tiny z extent). Do not call `select_entity`.

Nine `check()` calls:

1. `_start_sketch_on_face("no-such-face", body)` leaves `sketch_mode.active == false` and the status contains `Could not measure`.
2. `_start_sketch_on_face(top, body)` leaves the session active and the status contains `Sketch on face` and `+Z`.
3. `support_host == feature_of_body(body)`, `support_side == "max"`, `support_normal.z > 0.9`.
4. Add a closed rectangle with four `add_line` calls, corners `(-4,-2)` `(4,-2)` `(4,2)` `(-4,2)`. `finish_extrude(2.5, "cut", "blind")`. The sketch feature's params JSON contains `support_host`. The session ends. If the status contains `open profile`, the four endpoints are not shared and the test is wrong; do not loosen the product.
5. Set the primitive feature's `c` to `14` with `graph_set_params` (merge the existing params object; `c` is the box height). `graph_get_sketch` plane origin z is within 0.05 of 14.
6. Mesh of the body is not inside at `(0, 0, 12.75)`.
7. Mesh is not inside at `(0, 0, 13.5)`.
8. Mesh is inside at `(0, 0, 11.0)` (below the 2.5 mm floor at 11.5).
9. `_start_sketch_on_ground()` then `support_host == ""` and the status contains `Sketch on ground (XY)`. The cut sketch feature's params still contain `support_host`.

Copy `_load_mesh` and `_inside` from `run_rung01_wrench.gd` (lines 2867 and 2918). Do not import the walk.

Red on `b3161bba` before the product edit (the test file may be committed first): checks 1, 3, 4, 5, 6, and 7 fail. Check 1 fails because `begin` runs anyway. Checks 6 and 7 fail because the pocket stays at z 7.5–10, so z=12.75 and z=13.5 are solid. Check 8 can pass on both sides. Green line:

```
9 checks, 0 failures
```

Command:

```
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_slot.gd
```

Also run `run_rung01_sketch_tests.gd` and confirm **70 checks, 7 failures**. Do not commit `.gd.uid`.

## Do not

- Add a kernel blend, a new sxcore method, or a Catch2 assertion.
- Rebind when the three keys are absent.
- Call `begin` when the face plane is not ok.
- Edit `_fillet_all`, trim, or the polygon block.
