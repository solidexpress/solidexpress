# Replan 13 WP6 — sketch hover ✕ marks and measure labels only while measuring; squashed circles classified

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main`). Edit only `game/scripts/measure_overlay.gd`, `game/scripts/viewport_interaction.gd` (`_update_sketch_measure` and the sketch hover branch only) and add `game/tests/run_rung01_replan13_measure.gd`. No `sketch_mode.gd` edit is needed: the overlay reads `sketch_mode.tool` and listens to `sketch_mode.tool_changed`.

Hunks (search by name; line numbers are `0573dea2`): `viewport_interaction.gd` sketch `InputEventMouseMotion` branch (~2603–2620: `sketch_mode.hover(p2)` then `_update_sketch_measure(p2)`), `_update_sketch_measure` (~2728), the `KEY_ESCAPE` rung that says `Measure cleared` (~2664) and `_on_view_document_changed` (~3711); `measure_overlay.gd` `update_sketch_hover` (~101), `clear_pair` (~55), `_rebuild`, new `set_sketch_tool_gate`.

## The bugs (sx-033 A4, A8, A9, A3)

Leftovers 6 and 12. After **Shaft Lines** red/orange `✕` and `H` markers sit on the Ø20/Ø45 lines; during **jaw-sketch circle work** a measure overlay (✕ plus live Δ labels) stays on screen and one more `Esc` is spent on `Measure cleared`. Circles also "look squashed when zoomed out".

## Classification (the plan's decision on each half of leftover 6)

| Observation | What it is in code | Verdict |
|---|---|---|
| Orange / red `✕` marks | `MeasureOverlay` sticky hover marks: `COLOR_MARK` (orange, retained) and `COLOR_MARK_ACTIVE` (red-orange, active). `viewport_interaction` calls `measure_overlay.update_sketch_hover(...)` on **every** sketch hover in **every** tool, so hovering a line with Line, Circle, Trim or Shaft Lines armed plants a sticky ✕ that survives the tool change, the commit and the deletion of its entity (`update_sketch_hover("")` returns early and keeps `anchor_point`). | **Product bug.** The measure marks are an inspector for the Select tool; draw tools must not leave them behind. This is also leftover 12 (the stuck overlay). |
| Live `Δ` / `H`-style labels next to the marks | The same overlay (`labels`, `segments`) between the active and the retained mark. | Same fix. |
| Blue `H` badges on the shaft lines | Constraint glyphs (`GLYPH_SYMBOLS["horizontal"] = "H"`, `COLOR_GLYPH` blue). `shaft_lines_selected` → `_infer_line` adds horizontal/tangent/on-circle constraints. **Expected feature.** | Not a bug unless one is orange (`selected_constraint` leaked, `COLOR_GLYPH_SELECTED`) or red (`COLOR_CONFLICT`, the solver reports a conflict). The test decides. |
| Circles "look squashed" zoomed out | Sketch circles are `ImmediateMesh` polylines under an orthographic camera. A squash means the ortho aspect differs from the window aspect, or the screenshot was scaled non-uniformly. | **Decided by a probe** (test item 6): if projected circle diameters are equal in x and y within 0.5% at 1280×800 and at 1920×1080, it is soft-GL / screenshot scaling, no product change, and sx-034 gets a rule. If not equal, the BUILD agent fixes the camera aspect in `orbit_camera.gd` `enter_sketch_view`/`_update_transform` (only that) and says so in the PR. |

## Decisions (see `rung-01-replan-13.md` 6 and 12)

- **Gate.** `_update_sketch_measure` returns early unless `sketch_mode.tool == SketchMode.Tool.SELECT`. When the tool is anything else the overlay is not updated and does not draw (`MeasureOverlay.sketch_gate_open` false makes `_draw_measure_overlay` skip the sketch marks).
- **Clear on arm.** `sketch_mode.tool_changed` to any non-SELECT tool calls `measure_overlay.clear_pair()` (connected once in `viewport_interaction` setup). Rail presses that do not change the tool but act on geometry (Shaft Lines, Jaw presets, Contours, Trim commit, Convert) call it through the same signal path: `SketchMode` already emits `status`; the overlay also listens to `sketch_mode.solve_updated` and clears when `anchor_entity` is no longer in `sketch.entity_ids()`.
- **Dead anchors.** `update_sketch_hover` drops the anchor (and `prev_*`) when its `anchor_entity` / `prev_entity` no longer exists.
- **Esc ladder unchanged** for the Select tool: with a ✕ planted, Esc says `Measure cleared` (replan 10/11 suites assert it). With a draw tool armed there is nothing to clear, so the replan-10 rule "Esc after a first point takes exactly two presses" holds without a measure press.
- **Sketch exit** clears the overlay (it already does through `_on_view_document_changed`; assert it).
- **Constraint glyph colours** are not changed unless the test finds an orange/red glyph on valid shaft lines; then the fix is in `shaft_lines_selected`/`_infer_line` (do not add a horizontal constraint to a line that the tangent + point-on-circle pair already fixes) and the PR says which glyph it was.

## Failing-first test — `game/tests/run_rung01_replan13_measure.gd` (create)

Template: `run_measure_overlay_tests.gd` (91 checks) for the overlay API, `run_rung01_replan12_rail.gd` for real pushed events.

1. Blank sketch, Ø20 at the origin, Ø45 at (200, 0), 200 dimension (A3 geometry). Arm Circle, push a mouse motion onto the Ø45 rim: `measure_overlay.has_anchor()` is **false** (red on `0573dea2`: true).
2. Arm Select, hover the rim: `has_anchor()` true (the inspector still works; this is the guard against over-fixing).
3. Hover with Select (anchor planted), then press Shaft Lines (select both circles, rail button): `has_anchor()` false and `measure_overlay.marks` is empty (red on baseline).
4. Delete the hovered entity with the Select tool: the anchor is cleared on the next motion event.
5. Jaw sketch (replan 12 A8 geometry): with the Circle tool armed, ten pushed motions over the shaft/jaw geometry leave `marks.size() == 0` and `labels.size() == 0`.
6. Squash probe: `camera.unproject_position` of `(c ± r, 0)` and `(0, c ± r)` of a Ø45 circle at the sketch view, at viewport sizes 1280×800 and 1920×1080 (`FilmUI.ensure_test_viewport`): |Δx| and |Δy| within 0.5% of each other. Print both ratios; the verdict goes in the PR body.
7. After Shaft Lines on the A3 geometry: every constraint glyph label (`_constraint_glyphs` children) has `modulate == COLOR_GLYPH`; `last_conflicting` and `last_redundant` are empty; `selected_constraint == ""`.
8. Esc ladder: Circle armed with a first point down → Esc, Esc exits (two presses, never a `Measure cleared` in between); Select with a planted ✕ → one Esc says `Measure cleared`.

**Expected red** on `0573dea2`: 1, 3, 4, 5 (the overlay plants marks under every tool). 6 and 7 are decision probes: record the numbers whichever way they land.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_measure.gd
for t in run_measure_overlay_tests run_rung01_replan10_esc run_rung01_replan11_esc run_rung01_replan8_esc \
         run_rung01_replan8_shaft run_rung01_replan11_dim run_rung01_replan9_chip; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
```

Counts equal the whole-suite table of replan 12 (measure 91/0, replan10_esc 25/0, replan11_esc 10/0, replan8_esc 20/0, shaft 37/0, replan11_dim 11/0). `run_rung01_replan9_chip` is also touched by #135; if it changed there, compare to `main` after #135.

## Do not

- Remove the sticky ✕ pair for the **3D** measure (outside a sketch) or the Select-tool sketch measure.
- Change colours, fonts or the Δu/Δv label text.
- Add a setting to turn the overlay off.
