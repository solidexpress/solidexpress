# Leftovers after sx-034 (main `d3cff60a` / replan-13 WP1–WP9)

Source: the sx-034 GUI critique of `SolidExpress-d3cff60-occt8.0.1-linux-x86_64.tar.gz` (sha256 `61e652514f738147c9ab54e4e9c2626a72eb0dc945469183cd0b94293e58602d`, OCCT 8.0.1, soft GL, 1280×800, one session, walk 2026-10-06), plus its `LEFTOVERS-BRIEF.md`. This file condenses both so a BUILD agent never needs the walker's box. Only the **eighteen leftovers** below are planned, in [`rung-01-replan-14.md`](rung-01-replan-14.md). The five failed rows already have their own fixes and are **not** re-planned.

**Verdict: FAIL, 8.5/10** (up from 7.5–8 at sx-033). Pass bar is score ≥ 9 and every row PASS.

## What is green (do not regress)

- Real-GUI checkers on files exported from the app: blank **5/5**, wrench **28/28** (real Slot, `flipX=False flipY=False`, grip slot 159.993, slot-floor R1 PASS), thick **7/7** (both `1mm top fillet at new T` and `1mm jaw top fillet at new T`), nut **7/7**. 3MF bbox `232.5 × 44.949 × 10.0`.
- Headless: lint clean (`8 replan13 scripts are clean`), walk **551/0**, nut 7/7, wrench 28/28, thick 7/7, blank 5/5, all eight replan13 suites 0 failures (arm 135, chrome 53, dirty 21, frame 68, measure 76, radius 39, trim 28, typed 34). Kernel 336 cases / 7966 assertions (WP9's report).
- 41 checklist rows: **36 PASS, 5 FAIL**. Every L row of sx-034 passed except L3.

## The five failed rows (already fixed or in flight — verify only)

| Row | Symptom (verbatim) | Fix | State when this plan was written (`main` = `305dcbff`) |
|---|---|---|---|
| A8 | repeated click 2 → `Jaw committed — width 0.0000, long side 44.9° …` | [#148](https://github.com/solidexpress/solidexpress/pull/148) | **merged** `949cf865` |
| A9 | after sketch `F` the origin sat under the left rail (x≈97, rail edge ≈145); the pivot click needed a view move (rule 28) | [#149](https://github.com/solidexpress/solidexpress/pull/149) | **merged** `47d20a12` |
| A9b | cut to the opposite face printed `Extrude Up To Surface 20.0000 mm`, the cut went 10 mm | [#150](https://github.com/solidexpress/solidexpress/pull/150) | **merged** `305dcbff` |
| A11a | typed slot length printed `Length 150.0000 mm`, want `Slot c-c 150.0000 R5.0000 — typed` | [#151](https://github.com/solidexpress/solidexpress/pull/151) | open, `sketch_context_chrome.gd` `_sync_dim_affordance`, `sketch_mode.gd` `click` (Slot arm) + `slot_cc_status*`, `viewport_interaction.gd` `_apply_dim_edit` |
| L3 | panel `10.0`, strip `R 0.0 mm`, status `Fillet r=1.00 …` after typing 10 + Tab | [#152](https://github.com/solidexpress/solidexpress/pull/152) | merged (`93d31af`); it changed `ops_panel.gd` Radius spin + `set_dressup_radius` + `_arm_dressup`; `viewport_interaction.gd` strip radius (`_build_selection_strip` radius spin, `_on_dressup_radius_changed`, `_write_strip_radius`, `_commit_strip_radius`, `_sync_strip_dressup_radius`) |

Replan 14 only **re-verifies** these rows (sx-035 checklist delta).

## Leftover → work package

Numbering is the brief's (item 16 = the critique's L-17, item 17 = L-16). Severity: **B** blocks-pass (a strict critic fails a row on it), **U** usability, **C** cosmetic.

| # | Leftover | Sev | Verdict | WP |
|---|---|---|---|---|
| 1 | Save As inside a sketch adds duplicate / extra dimension labels | **B** | Product bug (hypothesis: `_save_current` re-enters the sketch and `_restore_dimensions_from_sketch` rebuilds a label for every dimensional constraint, including duplicates and typed radii that were never labelled live) | WP1 |
| 2 | View hotkey `3` typed into the focused Fillet strip `R` field | **B** | Product bug (field keeps focus after spinner / Enter) | WP2 |
| 3 | Part context bar shifts ~54 px between states; a Fillet click lands on Chamfer | **B** | Product bug (bar is centre-anchored: `PRESET_CENTER_TOP`, ±420) | WP3 |
| 4 | Part context bar overlaps the menu bar / Snap field, clips at the right edge | U | Same root cause as 3 | WP3 |
| 5 | Ctrl+A in a sketch numeric field also selects all sketch entities | U | Reproduce first (guards exist) | WP2 |
| 6 | First Esc in a focused sketch numeric field only blurs it | U | Product bug | WP2 |
| 7 | Ctrl+Z in a sketch does not undo sketch edits | U (high) | Missing feature: sketch edits are not on any undo stack | WP4 (one small C++ binding) |
| 8 | Part-mode `F` does nothing and prints no status | U | Reproduce first (may be item 2's stale focus); status is missing either way | WP5 |
| 9 | Wheel zoom is not anchored at the cursor | U | Reproduce first (`zoom_at` exists; `_nudge_pivot_on_zoom_out` moves the pivot) | WP5 |
| 10 | Jaw press highlights Rect on the rail; Jaw chip row is one `Center Three Point` chip | U | Product bug | WP6 |
| 11 | Slot length field stays labelled `Radius r` | U | **Covered by #151** (`label_text = "c-c"`); WP6 only adds the regression assertion | WP6 (verify) |
| 12 | Circle centre click prints no status | U | Product bug | WP6 |
| 13 | Dimension labels drawn on the constraint-glyph cluster | U | Product bug | WP1 |
| 14 | Timeline pencil opens Rename, not Edit Sketch | U | Product bug | WP7 |
| 15 | File → Open: Open button stays disabled with a file selected or typed | U | Reproduce first (may be soft-GL) | WP7 |
| 16 | First body named `extrude 3` | C | **Closed, no code**: the name is `<type> <timeline index>` (`sxkernel/src/features.cpp` ~182; datum plane = 1, sketch = 2, extrude = 3). Changing it needs C++ and breaks strings tests read (`# Face 5 of extrude 3`). Documented as sx-035 rule 37 | WP8 (checklist only) |
| 17 | Hovering a dimension label draws the Δu/Δv overlay while its editor is open | C | Product bug | WP1 |
| 18 | `check_rung01.py wrench` on a T≠10 export probes the grip slot at hard-coded z=8.75 (DIAG at T=14 fails 4 rows, the checklist said 3) | C (tooling) | Tooling | WP8 |

## The items, with verbatim evidence

Status strings are verbatim from the app. Line numbers are hints at `d3cff60a`; the WP prompts name hunks by function.

### 1. Save As inside a sketch adds duplicate / extra dimension labels (blocks-pass)

Before the save there was exactly one `20` and one `45°`. After File → Save As with the sketch open: a second `45°` label overlapping a new `22.5` label at the head top, and a `5` label at the pivot circle. They persist. Status `Saved /workspace/sx-034/out/pre-cut.sxp`; the sketch stayed open.

Repro: New doc. Sketch on XY: Ø20 at the origin, Ø45 at +200 (Smart Dim 200), Shaft Lines, Extrude 10. Sketch on the top face (z=10): circle at origin, type radius `5`; circle at head centre, type `22.5`; Jaw with 3 distinct clicks; Select tool, click the width label → `20`, the angle label → `45`; along-jaw construction line, cross-jaw Centerline; Trim on the shaft side → `Trimmed open jaw` (labels: one `20`, one `45°`). File → Save As `pre-cut.sxp`: two `45°` plus `22.5` and `5`.

Expected: Save / Save As never changes the set of dimension labels in an open sketch; no duplicates; typed circle radii are labelled both before and after, or in neither case (one policy, same after File → Open of the saved file).

Hint: `main.gd` `_save_current` does `exit_sketch()` → `view.save` → `begin_edit(fid)`; `begin_edit` → `_activate_session` clears `dimensions` and calls `_restore_dimensions_from_sketch`, which appends a record for **every** `distance|radius|diameter|angle` constraint in the kernel sketch. The live list only holds the records the user's actions created.

### 2. View hotkeys swallowed by the selection-strip `R` field (blocks-pass)

With Fillet armed, the strip `R` field keeps keyboard focus after the spinner ▲/▼ or typing + Enter. A later `3` is typed into the field and the camera does not move. Walker used HUD View ▸ Top instead (A11b), and skipped key `3` in A11e.

Repro: wrench part, click the body → Fillet (`Fillet r=1.00 — edit Radius, click edges, Enter`); click the strip `R` ▲ then ▼, or type `10` Enter; press `3`.

Expected: Enter, Tab and spinner clicks commit and return focus to the viewport; a viewport click releases the field; afterwards `1`–`8` change the view (status e.g. `Top view`). Digits go to the field only while the caret is in it after the user clicked into the text. Same for the Modify-panel Radius SpinBox.

Hint: `viewport_interaction.gd` routes view digits through `_input` / `_unhandled_input` (`block_nav = _text_field_has_focus() or _sketch_keys_blocked()`) and `_gui_key` (`SxUi.numeric_field_focused`); Esc already releases (`cancel_stack`).

### 3 and 4. Part context bar layout (blocks-pass / usability)

Measured positions (1280×800), body selected, nothing armed: `Fillet` x≈662, `Chamfer` x≈729. Face selected (adds `Sketch`, `Look at`, `Active plane`) or Fillet armed (adds the `R` field): `Fillet` x≈608, `Chamfer` x≈675. Walk A11d: "First context-bar click landed on Chamfer (`Chamfer r=1.00 …`) because the bar had shifted". Item 4: the bar's left end (`Group`, `Similar`) draws under the menu row and over the `Snap 0.1 mm` field; face selected + Fillet armed runs off the right edge (`Dele…`).

Bar contents at body selected: `Group Similar Hole Hole Wizard… TriBall Fillet Chamfer AF 10 12 14 Hide Delete`.

Expected: the bar is left-anchored at a fixed x, fully below the menu / Snap row, right of the left rail and panel; the common items keep their x whatever is appended after them; when it does not fit it wraps inside the window. Nothing overlaps `Snap`.

Hint: `viewport_interaction.gd` `_build_selection_strip` (`SelectionStrip`, `PRESET_CENTER_TOP`, offsets −420…420, top 8) in a `PanelContainer`; menu row is `top_chrome` / `FileMenu` / `PlaceSnapBar` in `main.gd` `_build_ui`; `ChromeDock.top_inset` / `rail_right` already exist.

### 5. Ctrl+A in a sketch numeric field also selects all sketch entities

Polygon AF 20 at the origin; Circle tool, click the centre, click into the Radius field, Ctrl+A: status `Selected 6 sketch entities`. Guards exist at `viewport_interaction.gd` `_sketch_input` (Ctrl branch) and `_gui_key`. Expected: Ctrl+A selects the field text only; no status change, no sketch selection change.

### 6. Esc in a focused sketch numeric field only blurs it

Circle centre placed, Radius field focused: first Esc releases the field and the rubber band keeps following; the ladder becomes three presses (blur, `First point dropped — Esc again exits the sketch`, exit). Expected: the first Esc releases the field **and** drops the pending point (`First point dropped — Esc again exits the sketch`), keeping the two-press ladder of A6. Hunk: `sketch_context_chrome.gd` `_on_dim_edit_gui_input` Esc branch.

### 7. Ctrl+Z inside a sketch does not undo sketch edits

After `Jaw committed — …`, Ctrl+Z printed nothing and removed nothing; the walker reopened the file. Expected: in an open sketch Ctrl+Z undoes the last sketch operation (entity add, Jaw, Trim, dimension edit) and prints `Undo: Jaw` (name of the op); Ctrl+Shift+Z / Ctrl+Y redoes (`Redo: Jaw`); nothing to undo → `Nothing to undo`. Hint: `main.gd` `_unhandled_input` Ctrl+Z (`view.doc.can_undo()`), `edit_undo`, `viewport_interaction.gd` `_gui_key` `KEY_Z` all act on the document; the live `SxSketch` is not on that stack.

### 8. Part-mode Frame (`F`) does nothing

Part mode, Top, zoomed on one end: `F` gave no camera change and no status. The HUD `Frame` button prints `Framed selection` / `Framed all` (`main.gd` `fit_requested`). Expected: `F` frames the selection or all bodies like the HUD button, prints a status, and the result lands right of the left panel inside the window. (Sketch-mode `F` printed `Sketch view fit` without framing the part at sx-034 chunk 2; #149 reworked it — re-check on main, fix only if it still fails.)

### 9. Wheel zoom is not anchored at the cursor

"wheel zoom-out appeared to push content away from the cursor"; "Wheel zoom toward the head barely zoomed"; "Wheel zoom-out recentred view so the slot's far end is off-screen". Expected: the model point under the pointer stays under it (±2 px) across wheel notches, ortho and perspective, sketch and part. Hint: `orbit_camera.gd` `zoom_at` already shifts the pivot by `(1 − factor)`; `_nudge_pivot_on_zoom_out` then moves the pivot toward the content on zoom-out.

### 10. Pressing Jaw highlights Rect; Jaw chip row is one chip

Status correct (`Jaw — click 1 centre, click 2 end of the long side, click 3 half the width`) but the **Rect** rail button is highlighted and the chip row is one chip, `Center Three Point`. Expected: Jaw's own rail button is highlighted (L1), Rect is not; chips are named for Jaw or absent. Hint: `main.gd` rail (`JawTool` is outside the `ButtonGroup`; `_sync_sketch_rail_highlight` keys on `sx_tool`); `sketch_mode.gd` `start_jaw_tool` = `set_tool(RECT)` + variant, `variants_for_tool` returns `["center_three_point"]` while `_jaw_armed`.

### 11. Slot length field stays labelled `Radius r` — covered by #151

After the first centre the field showed `21.31 mm`, then `150.0 mm`, still labelled `Radius r`. #151 relabels it `c-c` (and hides the `r` cue). WP6 adds one regression assertion.

### 12. Circle centre click prints no status

Status stays `Circle — click the centre, then the rim (or type a radius)`. Expected e.g. `Circle — centre set, click the rim or type a radius`.

### 13. Dimension labels on the constraint-glyph cluster

The `20` label sits on the glyph cluster at the head centre; the angle label's first glyph is under the ⊥ icon, and users are told to click the first glyph (rule 27). Expected: no label rect intersects a constraint-glyph rect.

### 14. Timeline pencil opens Rename, not Edit Sketch

Pencil next to `sketch 2` → rename field; re-entry needed a double-click on the name. Expected: the pencil on a sketch row opens Edit Sketch; rename stays on F2 and a context menu.

### 15. File → Open: Open stays disabled

With `blank.sxp` selected or typed the Open button stayed disabled; double-click worked. Expected: Open enabled when the name field holds an existing `.sxp` in the shown directory. (Reproduce first: may be soft-GL.)

### 16. First body named `extrude 3` — closed, no code

By design: `<feature type> <timeline index>`; the first extrude in a document that has a datum plane and a sketch is feature 3. Added to the sx-035 soft-GL rules as rule 37.

### 17. Hovering a label shows the Δ overlay while its editor is open

Select, click the angle label (editor opens), hover over it: Δu/Δv/length overlay draws. Expected: suppressed while the editor is open.

### 18. DIAG checker probes the slot at z=8.75

`6-A13c-diag.txt`: `FAIL  grip slot present at y=0,z=8.75  got 0 samples open` at T=14; the DIAG failures at T=14 are `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge` (18/22, 5760 tris). The sx-034 checklist text said three. Expected: either `wrench` accepts an optional thickness (as `thick` does) or the docstring/checklist say DIAG at T=14 fails four rows by design. **Do not change `thick`**; do not change any other probe or tolerance.

## Not counted (environment / walker)

Screenshot lag (rules 8/36), dropped first keys in Radius / Extrude fields and sometimes BackSpace / Ctrl+A (rule 1/30), a stale desktop clipboard paste, dropped pointer moves after clicks (rule 12), one parent-approved pan after A9 (continuity only), the A3 head-dy 0.5 (local `a3_head_y.py` window margin flake, fixed locally), and "Thin off (no Flip control shown)" on A9b (rule 16 only needs flip off). One watch item: an accidental sketch-edit entry while picking the slot floor for L7 (probably a rule-2 retry read as a double-click); file it only if it recurs with a single click.

## Honesty gaps the critique named (headless green, GUI red)

No suite covered: post-save labels, focus / view hotkeys with a field focused, context-bar layout. Replan 14 adds one suite per area; each asserts through real events, at 1280×800 for layout.
