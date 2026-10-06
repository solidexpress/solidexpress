# Replan 13 WP2 — Power Trim keeps the dimensions the user typed (20 and 45°), no piled labels

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main`). Edit only `game/scripts/sketch_mode.gd` (the hunks below) and add `game/tests/run_rung01_replan13_trim.gd`.

`sketch_mode.gd` hunks you own (search by name; line numbers are `0573dea2`): `_trim_open_jaw` (~2558–2735, the part after the wall surgery: the `_record_dimension("distance", …)` and `_record_dimension("angle", …)` calls and `_drop_stale_dimensions()`), `_drop_stale_dimensions`, `_record_dimension`, the `_snap_jaw_hits_through_centre` / `half` recompute inside `_trim_open_jaw`. #135 edits the Jaw **creation** path (`_click_rect`, the preview); do not touch it. If #135 merged first, rebase; the hunks are disjoint.

## The bug (sx-033 A8/A9)

Leftover 4: after Power Trim the jaw labels drift and pile up. The width label reads `20.0005` and the angle `45.0007°` although the walker typed 20 and 45; the 3MF-measured wall is about 45.4° after setting 45.

## Cause (read in `_trim_open_jaw` on `0573dea2`; **reproduce first**)

1. **The typed values are discarded, the measured ones are recorded.** After Trim the old floor/wall dimensions point at deleted entities and `_drop_stale_dimensions()` drops them. The function then calls `sketch.add_constraint("distance", …, width)` with `width = h0.distance_to(h1)` (the geometric distance of the recomputed floor, not the typed 20) and `sketch.add_constraint("angle", …, ang)` with `ang = _lines_signed_angle(hx, wall0)` (the **measured** angle). The solver then holds the geometry to the drifted numbers, and `_dimension_label_text` prints them (`snappedf(…, 0.0001)`), so `20.0005` / `45.0007°` are the new truth.
2. **The geometry drifts before the numbers are recorded.** `_snap_jaw_hits_through_centre(walls, cc, dir)` moves the wall hits onto the line through the head centre while the `keep` points stay put; the new wall direction is `keep - hit`, so a hit that moved by `ε` rotates the wall by about `ε / length`. The second recompute (`half`, `fdir`) rebuilds the floor from `cc ± fdir * half` with `half = across.length() * 0.5` taken from the already-moved hits. That is where the ≈ 0.4° and the 0.0005 mm come from.
3. **Labels pile up.** The new dimensions are appended to `dimensions` while the pre-trim width/angle entries survive when one of their referenced entities survives (a wall keeps its id), so two width labels (20 and 20.0005) and two angle labels share the head area. `_rebuild_dimension_labels` stacks them (`label_stack`) but they are still two labels for one fact.

## Decisions (see `rung-01-replan-13.md` 4)

- **Typed value wins.** Before any wall surgery, `_trim_open_jaw` captures `jaw_width` and `jaw_angle` from the live dimension records that name the jaw's floor/walls (the `distance` record on the jaw's short side and the `angle` record against the datum line). If none exists (the jaw was drawn but never labelled by hand), the **current measured values rounded to 1e-4** are the typed values. After the surgery the new `distance` and `angle` constraints are added with the captured numbers, not `width` / `ang`.
- **The wall direction is set from the captured angle**, not from `keep - hit`: after `_snap_jaw_hits_through_centre`, each wall's `keep` point is re-derived on the arc from the hit along `dir` rotated to the captured angle (`_ray_circle_point(hit, dir_from_angle, cc, cr)`). The 2.0° / 0.0009 dot guards stay as they are.
- **One label per fact.** After recording, any other `distance` record whose entities are the jaw floor, and any `angle` record whose entity pair is `[datum line, a jaw wall]`, is removed. `_drop_stale_dimensions` keeps dropping records of dead entities.
- **`Dimension updated` is not re-emitted**; the status stays `Trimmed open jaw`.
- No change to which entities the trim deletes, to the weld, to the arc, or to the cutter chooser (`run_rung01_replan10_trim`, `_replan11_trim` stay as they are).

## Failing-first test — `game/tests/run_rung01_replan13_trim.gd` (create)

Template: `run_rung01_replan11_trim.gd` (`_boot`, `_build_jaw`). The new test builds the jaw through the product path so the dimension records exist: `sm.start_jaw_tool()`, three `sm.click(...)` calls (head centre, the end of the long side, half the width), then `sm.set_dimension_value(i, 20)` / `(j, 45)` for the width and the angle record, then the cutter centreline and `sm.trim_at(SHAFT_SIDE)`.

1. After the trim, exactly **one** `distance` dimension names the jaw floor and exactly one `angle` dimension names a jaw wall (`sm.dimensions` filtered by type; count == 1 each).
2. Their values are `20.0` and `45.0` within `1e-6` (they were typed, not measured); `sm._dimension_label_text(dim)` is exactly `20` and `45°`.
3. Geometry: the floor length is `20 ± 1e-3`; the wall direction angle against the datum line is `45 ± 0.01°` (compute from `entity_info`, not from the dimension); the two walls are parallel within `0.01°`.
4. Re-run `sm.run_solve()` and read the dimension values again: unchanged (the solver holds them).
5. A second `trim_at` still says `Jaw is already open`; `SketchMode.profile_is_closed(sm.sketch)`; `last_dofs`/`last_conflicting` empty.
6. Label rectangles: for every pair of labels in `_dimension_labels` (use `_dimension_label_rect` with the camera scale from `_label_px_scale`) the rectangles do not overlap (`Rect2.intersects` false).
7. Repeat 1–3 with the typed values 15 and 30° and with a Ø5 hole at the origin (the A9 geometry) to prove the capture is not special to 20/45.

**Expected red** on `0573dea2` (hypothesis, record the real run first): 1 (two width labels), 2 and 3 (`20.0005`, `45.0007`, wall about `45.4°`). If a check is green on baseline, keep it as a regression row and say so in the PR; do not delete it.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_trim.gd
for s in replan10_trim replan11_trim replan5_trim replan12_labels replan6_cut replan8_cut replan10_cut; do
  tools/godot/godot --headless --path game --script res://tests/run_rung01_$s.gd; done
```

`run_rung01_replan5_trim` has **one pre-existing failure** on `0573dea2` (whole-suite table in replan 12); it must stay exactly one. The walk (`run_rung01_wrench.gd`, 456/0) must still print 456/0: its jaw is typed at 20 and 45 and the `thick`/`wrench` checkers measure the 3MF, so a better trim can only help them.

## Do not

- Round the geometry to hide the drift (no `snappedf` on `entity_info` values).
- Loosen `INFER_TOL`, `EPS`, `CAP_DEG` or the weld tolerances.
- Delete `_snap_jaw_hits_through_centre`; its offset-cutter case (checker u=3 / floor-from-u=10) is covered by `run_rung01_replan10_trim`.
