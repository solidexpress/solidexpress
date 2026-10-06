# Replan 14 WP3 — the part context bar stays put and stays on screen

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only `game/scripts/viewport_interaction.gd` (the hunks below) and add `game/tests/run_rung01_replan14_ctxbar.gd`. Read [`rung-01-replan-14.md`](rung-01-replan-14.md) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (items 3, 4) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

| File | Hunk (search by name; line numbers are `305dcbff`) |
|---|---|
| `game/scripts/viewport_interaction.gd` | `_build_selection_strip` **outer container only** (~293–307: the `PanelContainer`, its anchors / offsets, the `HBoxContainer row`), `_refresh_selection_strip` (~4714), new `_layout_selection_strip()`, a `resized` / `visibility_changed` connect for it |

**#152 (merged, on `main`) rewrote the `_strip_radius` block** inside `_build_selection_strip` (~375–420: the SpinBox, its `value_changed`, `focus_entered`, `focus_exited`) and the radius helpers at ~4864–4990. Do not edit those lines. Change the row container type in the three lines that create it (`var row := HBoxContainer.new()` … `_selection_strip.add_child(row)`), leave every `row.add_child(...)` line and the `_strip_radius_box` construction alone. Line numbers move with #152; search by name. The edit surface is the container creation only. `WP2` adds one call line after `_build_selection_strip()` in `_ready`: keep that line.

## The bugs (sx-034 A5 / A11b / A11d / L-3 / L-4; leftovers 3 and 4)

The part context bar is `SelectionStrip` (a `PanelContainer`, `set_anchors_preset(PRESET_CENTER_TOP)`, offsets −420 … 420, top 8, bottom 44) holding one `HBoxContainer`. Content at body selected, nothing armed: `Group Similar Hole Hole Wizard… TriBall Fillet Chamfer AF 10 12 14 Hide Delete`.

**Item 3 — the bar shifts ~54 px between states.** Measured at 1280×800: body selected, nothing armed: `Fillet` x≈662, `Chamfer` x≈729. Face selected (adds `Sketch`, `Look at`, `Active plane`) or Fillet armed (adds the `R` field): `Fillet` x≈608, `Chamfer` x≈675. In the walk a click on the first Fillet position armed **Chamfer** (`Chamfer r=1.00 …`). The pass rule asks for first-try fillets.

Repro: wrench part, key `3`. Click the body; note the `Fillet` x. Click the top face (`Selected <uuid>`, panel `# Face 5 of extrude 3`). Click the same x → Chamfer arms.

**Item 4 — the bar overlaps the menu row and runs off the right edge.** Its left end (`Group`, `Similar`) draws under the File / Insert / View menu row and over the `Snap 0.1 mm` field (`PlaceSnapBar`); with a face selected and Fillet armed its right end is cut off (`Dele…`).

## Cause (read on `305dcbff`)

The panel is anchored to the **top centre** and the content is wider than ±420, so the `PanelContainer` grows symmetrically around the centre: every item that is appended makes the existing ones move left by half the added width. The y of 8 is inside `top_chrome` (`TopChrome`, at `_CHROME_PAD` = 4; the menu row and `PlaceSnapBar`), so the bar sits on top of it. Nothing constrains the width to the window.

## Decisions (see `rung-01-replan-14.md` 6)

- **Left anchor.** `SelectionStrip` uses `PRESET_TOP_LEFT`; `position.x = x_fixed`, `position.y = y_fixed`, set by `_layout_selection_strip()`:
  - `x_fixed = max(ChromeDock.rail_right, <right edge of LeftStack> + 8)`. `ChromeDock.rail_right` is already refreshed by `main.gd` `_apply_chrome_docks`. If, in the test, `rail_right` differs between the three states (body / face / armed) because the left panel resizes, use the largest value any state yields (the Modify panel's fixed minimum width is 230) so that `x_fixed` is a function of the **left panel only**, never of the bar's own content.
  - `y_fixed = max(ChromeDock.top_inset, <bottom of TopChrome in this control's coordinates> + 4)`. `top_chrome` is reached through `get_tree().root.find_child("TopChrome", true, false)` once and cached; fall back to `ChromeDock.top_inset` when absent (other test scenes).
- **Order.** The common items (Group … Chamfer) come first in the row, in today's order; the state-specific items (`R` field, `Sketch`, `Look at`, `Active plane`, the jaw `AF` chips) after Chamfer; `Hide` and `Delete` stay last. Do not reorder the common items. (Today's `row.add_child` order already satisfies this; the test pins it.)
- **Wrap inside the window.** The row becomes an `HFlowContainer` (`add_theme_constant_override("h_separation", 6)`, `v_separation` 4). `_layout_selection_strip()` sets the panel width to `min(content_width, viewport_width − x_fixed − 8)` (content width = the sum of the visible children's minimum widths plus separations), `reset_size()`, then re-reads the height. Called from `_refresh_selection_strip`, on `item_rect_changed` / `visibility_changed` of the radius box and the optional buttons, and on the viewport `size_changed`.
- **The bar does not eat clicks outside its own rect.** The panel's size is the content size (or the capped size), `mouse_filter` stays `STOP` only while visible and `IGNORE` otherwise (existing behaviour of `_refresh_selection_strip`). The pointer-over-UI test at ~2412 (`ctrl.get_global_rect()`, area ≤ 25 % of the viewport) keeps working; if a wrapped bar exceeds 25 % of a small window, raise nothing: wrapping at 1280×800 gives a bar well under it.
- **No visual change** beyond position and wrapping: same buttons, tooltips, sizes, `StripRadius` behaviour (that is #152), same visibility rules in `_refresh_selection_strip`.

## Failing-first test — `game/tests/run_rung01_replan14_ctxbar.gd` (create)

Template: `run_rung01_replan13_frame.gd` (`_boot` at 1280×800, `FilmUI`) and `run_rung01_replan12_pick.gd` (box body, face pick). Setup may place the body with helpers; every click is a real event.

1. Boot at 1280×800. Place a box (`FilmUI.place_primitive`), key `3` (Top), real click on the body. Record `r_body[name] = get_global_rect()` for `StripGroup`, `StripFillet`, `StripChamfer`, and the panel rect `bar_body`.
2. Real click on the top face (the same click refines to a face once the body is selected): `Sketch`, `Look at`, `Active plane` become visible. Record `r_face`.
3. Press `StripFillet` with a real click **at the centre recorded in `r_body`**: the status starts `Fillet` (never `Chamfer`), the `R` field is visible. Record `r_armed`.
4. Assert, for `StripGroup`, `StripFillet`, `StripChamfer`: `position` and `size` equal across the three records within 1 px (red on baseline: Fillet x moves ~54 px).
5. In every state (`bar_body`, `bar_face`, `bar_armed`): `bar.position.y ≥ top_chrome bottom` and the bar rect does not intersect the `FileMenu` rect, the `PlaceSnapBar` rect (find by name) or any visible child of `TopChrome`; `bar.position.x ≥ left_stack right`; `bar.end.x ≤ 1280` and `bar.end.y ≤ 800`; every visible child button's global rect is inside the bar's rect and inside the window (no clipping). (Red on baseline: overlap with `PlaceSnapBar`, right edge > 1280 in face + armed.)
6. A real click at a canvas point that lies right of `bar.end.x` and at the bar's y reaches the viewport (pick / deselect happens, the bar does not swallow it).
7. Item order: the visible children's x are non-decreasing in the order `Group, Similar, Hole, Hole Wizard…, TriBall, Fillet, Chamfer` in every state.
8. Resize the window to 1024×768 (`FilmUI.ensure_test_viewport(ctx, Vector2i(1024, 768))`) and repeat 5: the bar wraps to two rows, nothing is clipped, nothing overlaps the menu row.
9. Deselect (real Esc): the bar hides and `mouse_filter` is `IGNORE`. Select a body again: `Fillet` is at the same x as in step 1.

**Expected red** on `305dcbff`: 4 (Fillet / Chamfer x differ), 5 (overlap, right edge), 8 (clipping); 1–3 and 6–7 may be green. Record the real rects.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_ctxbar.gd
for t in run_rung01_replan13_radius run_rung01_replan12_pick run_rung01_replan12_fillet run_rung01_fillet_tests \
         run_rung01_replan11_fillet_ui run_rung01_replan10_esc run_rung01_replan12_rail run_menu_tests; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
python3 tools/lint_rung01_e2e.py
tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone
```

Counts equal the whole-suite table. The walk's context-bar clicks (`StripFillet`, `StripChamfer` by name or by rect) must still land; if a walk helper hard-coded a bar position, report it instead of editing the walk (WP8 owns it).

## Acceptance

- The new suite is green and was red on the starting ref.
- At 1280×800, `Fillet` and `Chamfer` rects are identical (±1 px) for body selected, face selected and Fillet armed.
- The bar is fully below the menu / Snap row, right of the left panel, inside the window; it wraps instead of clipping at 1024×768.
- Replan 12 / 13 fillet, pick and radius suites and the walk unchanged; lint clean.
- PR body: items 3, 4 fixed, with the before / after rect table from step 4.

## Do not

- Re-centre, re-skin or re-label the bar, or move any item between "common" and "state-specific".
- Edit the strip radius block, `_sync_strip_dressup_radius` or any #152 helper.
- Change `top_chrome`, `PlaceSnapBar` or the sketch chip rows (#134).
- Add a toolbar for the sketch session (the strip stays hidden while sketching).
