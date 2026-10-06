# Replan 13 WP8 — the polygon preview is what the click commits; the Distance field never shows the old value

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main`; if #134/#136 are still open, rebase onto them before the PR, they edit `sketch_context_chrome.gd`). Edit only the hunks below and add `game/tests/run_rung01_replan13_typed.gd`.

| File | Hunk (search by name; line numbers are `0573dea2`) |
|---|---|
| `game/scripts/sketch_mode.gd` | `_update_preview` — the `Tool.POLYGON:` arm (~5494–5520), `hover` (~4716), `effective_hover` (~1132), the POLYGON arm of `click` (~3318) only if the commit and the preview must share one helper (new `_polygon_start_angle(c, tip)`) |
| `game/scripts/sketch_context_chrome.gd` | `_write_extrude_spin` (~650), `_reassert_distance_line` (~685), `_commit_distance_text` (~636), `focus_distance_for_typing` (~356) |

Two independent leftovers, each with a **reproduce-first gate**: if the headless probe cannot reproduce it, it is soft-GL (screenshot lag, rule 8; first move dropped, rule 12), the BUILD agent records the probe output in the PR body and changes **no product code** for that half.

## Part A — polygon preview (leftover 9)

sx-033 A14: after the Polygon centre click, an off-axis pointer move left the preview not following until the AF value was typed.

Cause candidates (read on `0573dea2`; the test decides which):

1. **Motion not delivered while the AF blank has focus.** After the centre click the dim blank takes focus (`focus_distance_for_typing`, `_dim_editing`). If `hover()` is skipped (`_sketch_keys_blocked()`, a focused `LineEdit` swallowing motion, or `_viewport_owns_pointer` false over a chrome strip) the preview freezes at the last delivered point until typing locks the length (`set_length_override` → `_update_preview`). This matches "stops following until AF is typed" best.
2. **Early exit in `_update_preview`.** Geometry is only built when `_tool_points.size() > 0 or _snap_marker != null …`; check that the polygon centre stays in `_tool_points` after an infer snap.
3. **Orientation snap (by design, listed so nobody "fixes" it).** The across-flats preview uses `start_angle = round(angle / 30°) × 30°` while the pointer steers and `start_angle = 0` once a length is typed (`_length_override >= 0`); the committed polygon matches (`click` uses the same two rules). A pointer move inside one 30° bucket therefore changes the radius but not the orientation. That is correct and stays.

Decisions (see `rung-01-replan-13.md` 9): **the preview follows every delivered pointer motion and equals what the next action commits.** If cause 1 or 2 is real, fix the delivery (a focused AF blank must not stop `hover()`; only keys are blocked). The orientation rules of cause 3 stay; extract them into one helper `_polygon_start_angle(c, tip, typed)` used by both `_update_preview` and the POLYGON commit so the two can never diverge. Vertex variant unchanged.

### Test (`run_rung01_replan13_typed.gd`, part A)

Real pushed motions through `Viewport.push_input` (`run_rung01_replan12_rail.gd` template); the preview vertices are read from `sm._preview_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]`.

1. Polygon tool, `across_flats`, centre click at (0, 0). Push motions to three off-axis points (`(14, 6)`, `(10, 12)`, `(-12, 9)`), `await process_frame` after each. After each: the number of preview vertices is non-zero, the circumscribed radius of the preview hexagon equals `|tip| / √3` within 1e-3 (it **follows** the pointer).
2. After the third motion, the pointer-steered preview orientation equals the orientation `click(tip)` commits (commit on a duplicate session; compare vertex sets within 1e-4).
3. Type `20` into the AF blank (real keys): the preview is flats horizontal and radius `20/√3`; Enter commits the same vertex set (`Polygon AF 20.0000 — flats horizontal`).
4. The nut checker's geometry: the committed hexagon's two horizontal flats are at `y = ±10` after the typed AF (regression for A14, `run_rung01_replan11_poly` stays 8/0).
5. Vertex variant: preview equals commit (no behaviour change).

**Expected red** on `0573dea2` (hypothesis): 1 if cause 1 or 2 is real (the preview radius stays at the last pre-focus value). 2–5 are expected green on baseline and are the regression net for the helper extraction. If 1 is green, Part A is soft-GL (rule 12, the first motion after a click is dropped by the desktop): record the probe output and make no product change.

## Part B — Distance field flash (leftover 10)

sx-033: after typing the finish-bar Distance (for example `14`) the field briefly shows the **old** value before the typed one.

Cause candidate: `_write_extrude_spin` sets `_extrude_spin.value = v`; the `SpinBox` reformats its `LineEdit` on a deferred update (`"7"` → `"7.0"`), and the code re-asserts the typed text with `_reassert_distance_line.call_deferred`. Between the `SpinBox`'s own update and the re-assert, one frame can draw the spin's **previous formatted value**. Also `focus_distance_for_typing` writes `_distance_origin = _extrude_spin.value` before the seed lands.

Decision: no flash is allowed on any frame. If the probe sees one, make `_write_extrude_spin` write the text **before** the value change is observable (set `edit.text` first with `_distance_syncing = true`, then `value`, then the same re-assert), and drop the extra deferred call that races the SpinBox update. If no frame shows the old value in the headless probe, record it as soft-GL (the screenshot lags one action) and change nothing.

### Test (part B)

1. Finish bar open (`FilmUI.enter_sketch`), Distance `20`. Focus the field (real key `E`-focus path used by `run_rung01_replan2_distance.gd`), push the keys `1`, `4` and `Enter`. After **every** key and for 5 consecutive `process_frame`s after Enter, record `edit.text`; assert that no sample contains `20` after the first key and that the last sample parses to `14`.
2. Same through the unfocused burst (`focus_distance_for_typing("14")`).
3. `ExtrudeReadout` text equals the field on every sample.
4. Escape (`distance_origin` restore) shows `20` again and never an intermediate third value.

**Expected red**: unknown; the probe decides. Keep the spy loop as the regression net either way.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_typed.gd
for t in run_rung01_replan11_poly run_rung01_replan2_distance run_rung01_replan3_distance run_rung01_replan4_numeric \
         run_rung01_replan_finishbar run_rung01_replan12_status run_rung01_replan10_cut; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
```

Counts equal the whole-suite table of replan 12 (poly 8/0, replan2_distance 32/0, replan3_distance 48/0, numeric 59/0, finishbar 53/0).

## Do not

- Change the committed polygon geometry, `INFER_TOL`, the `polygon_sides` clamp or the AF/vertex naming.
- Remove `_reassert_distance_line` (it protects typing `7` then `.5`); reorder around it.
- Add a debounce or delay to hide a flash.
