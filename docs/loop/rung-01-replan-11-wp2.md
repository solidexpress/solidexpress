# Replan 11 WP2 — fillet errors name the edge

You are a BUILD agent. Implement only this WP. One C++ file: `sxkernel/src/features/ops_dress.cpp`. Plus the new Godot test below. Do not edit `ops_panel.gd` (that is WP3). Do not edit `features.cpp` (that is WP9).

Base: `b3161bba` or any later replan-11 WP that does not touch this file. WP2 has no product dependency.

## Why the strings look like this

`apply_fillet_chamfer` (line 276) fails in two ways:

- Radius above half the shortest departure: `ctx.fail("fillet failed (limit " + format_mm(limit) + ")")` at line 312. `ctx.fail` prefixes the feature name, so GDScript sees `fillet 8: fillet failed (limit 5.000)`.
- `build_fillet` (line 222) returns false and `fillet_unified` also fails: `ctx.fail("fillet failed")` at line 319. `NbFaultyContours` / `FaultyContour` / `Edge` exist on `BRepFilletAPI_MakeFillet` (OCCT 8.0.1 and 7.6). `FaultyContour(I)` returns a contour index, not a shape. `Edge(ic, j)` returns the edge. Index `I` is 1-based.

The phrase names the **picked** edge that imposed the tightest limit (the one in the selection the user can click again), not the adjacent departure edge. Kind is `vertical` when the curve is a line and `|direction.Z| >= 0.95`, otherwise `line`. Circles are `arc`.

Exact kernel sentences, after the feature-name prefix:

```
fillet failed (limit 5.000; 179.833 mm line at (189.917, 10.000, 10.000))
fillet failed (32.200 mm arc at (193.500, 15.900, 10.000))
fillet failed
```

`format_mm` stays 3 decimal places. Keep the words `limit ` and `fillet failed` so `_dressup_radius_refused` still matches. Chamfer strings are unchanged.

## Code

Add this helper next to `format_mm` (line 114):

```cpp
std::string edge_phrase(const TopoDS_Edge& edge) {
    BRepAdaptor_Curve curve(edge);
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    const char* kind = "curve";
    if (curve.GetType() == GeomAbs_Line) {
        kind = std::abs(curve.Line().Direction().Z()) >= 0.95 ? "vertical" : "line";
    } else if (curve.GetType() == GeomAbs_Circle) {
        kind = "arc";
    } else if (curve.GetType() == GeomAbs_Ellipse) {
        kind = "ellipse";
    } else if (curve.GetType() == GeomAbs_BSplineCurve || curve.GetType() == GeomAbs_BezierCurve) {
        kind = "spline";
    }
    gp_Pnt mid;
    curve.D0(0.5 * (curve.FirstParameter() + curve.LastParameter()), mid);
    return format_mm(props.Mass()) + " mm " + kind + " at (" + format_mm(mid.X()) + ", "
           + format_mm(mid.Y()) + ", " + format_mm(mid.Z()) + ")";
}

void note_faulty_contour(BRepFilletAPI_MakeFillet& mk, std::string* fault) {
    if (!fault) return;
    fault->clear();
    if (mk.NbFaultyContours() < 1) return;
    const int ic = mk.FaultyContour(1);
    if (mk.NbEdges(ic) < 1) return;
    const TopoDS_Edge fe = mk.Edge(ic, 1);
    if (!fe.IsNull()) *fault = edge_phrase(fe);
}
```

Change `build_fillet` to take `std::string* fault` as its last argument. On `!mk.IsDone()` call `note_faulty_contour(mk, fault)` and return false. On the catch, leave `fault` empty and return false. Success path unchanged.

Change `fillet_unified` the same way: pass `fault` into `build_fillet`.

In the fillet branch of `apply_fillet_chamfer`:

```cpp
double limit = std::numeric_limits<double>::infinity();
TopoDS_Edge limit_edge;
// inside the resolve loop, after the edge is resolved:
const double this_limit = 0.5 * min_departure_length(tb->shape, edge);
if (this_limit < limit) {
    limit = this_limit;
    limit_edge = edge;
}
resolved.push_back(edge);
```

Replace the two failure returns:

```cpp
if (limit < 1e290 && asked > limit + 1e-4) {
    std::string extra;
    if (!limit_edge.IsNull()) extra = "; " + edge_phrase(limit_edge);
    return ctx.fail("fillet failed (limit " + format_mm(limit) + extra + ")");
}
std::string fault;
if (!build_fillet(tb->shape, resolved, v, r2, result, &fault)) {
    TopoDS_Shape recovered;
    std::string fault2;
    if (fillet_unified(tb->shape, resolved, v, r2, recovered, &fault2))
        result = recovered;
    else {
        if (fault.empty()) fault = fault2;
        if (!fault.empty()) return ctx.fail("fillet failed (" + fault + ")");
        return ctx.fail("fillet failed");
    }
}
```

`GProp_GProps` and `BRepGProp` are already used in this file (`min_departure_length`). `GeomAbs_CurveType` is already included.

## Build

```
make build
make test-kernel
```

`make test-kernel` must still print `All tests passed`. Do not add a Catch2 case. The Godot test is the proof.

## Test

Create `game/tests/run_rung01_replan11_fillet_err.gd`. This is a validation test: it builds a box through `SxDocument` on the live main scene and calls `graph_add_fillet`. It does not click.

```gdscript
extends SceneTree
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_fillet_err.gd

var failures := 0
var checks := 0

func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)

func _init() -> void:
	print("rung01 replan11 WP2 fillet error strings")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var doc = main.view.doc
	# Feature-graph box. Direct add_box() has no feature id, so graph_add_fillet cannot target it.
	var body: String = main.view.insert_primitive("box", Vector3.ZERO, Vector3(20, 10, 10))
	await process_frame
	var fid := main.view.feature_of_body(body)
	check(fid != "", "box has a feature id")
	var edges: PackedStringArray = doc.get_edge_ids(body)
	check(edges.size() >= 1, "box has edges")
	var long_id := ""
	var best_len := 0.0
	for e in edges:
		var L := float(doc.measure_edge_length(e))
		if L > best_len:
			best_len = L
			long_id = e
	# Radius larger than half the shortest departure on a 10 mm box edge.
	var made: String = doc.graph_add_fillet(fid, PackedStringArray([long_id]), 50.0)
	var err := str(doc.last_graph_error())
	check(made == "", "r=50 is refused")
	check(err.contains("limit "), "error contains limit (got %s)" % err)
	check(err.contains(" mm "), "error names a length (got %s)" % err)
	check(err.contains(" at ("), "error names a midpoint (got %s)" % err)
	# A tiny radius on one edge must still succeed and clear the error.
	var ok: String = doc.graph_add_fillet(fid, PackedStringArray([long_id]), 0.2)
	check(ok != "", "r=0.2 applies (err %s)" % str(doc.last_graph_error()))
	check(not str(doc.last_graph_error()).contains("fillet failed"), "success clears the fillet error")
	main.queue_free()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
```

Count the `check()` calls: 8. If `add_box` is not a method, delete that branch and keep `insert_primitive` only; do not drop a `check()`. Green:

```
8 checks, 0 failures
```

Red on `b3161bba` before this WP: the limit error is `fillet failed (limit X.XXX)` with no ` mm ` and no ` at (`, so those two checks fail. The r=0.2 row still passes.

The box is 20×10×10, so a radius of 50 is over the limit. Do not weaken the string assertions.

Command:

```
make build
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_fillet_err.gd
make test-kernel
```

## Do not

- Change the chamfer failure string.
- Remove the `fillet soft-skip` log.
- Auto-retry a failed face fillet.
