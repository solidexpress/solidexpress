# Replan 15 WP1 — Enter in a Radius field keeps Fillet armed (N2 / leftover 9)

You are a BUILD agent (grok-4.7, medium effort, standard speed, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only the files and hunks below and add `game/tests/run_rung01_replan15_armedkeys.gd`. Read [`rung-01-replan-15.md`](rung-01-replan-15.md) (decisions 1, 11, 13) and [`rung-01-leftovers-sx035.md`](rung-01-leftovers-sx035.md) (item 9) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. **Do not merge your own PR**: mark it ready for review and stop; the parent merges.

| File | Hunk (search by name; line numbers are `d534765c` and will have shifted) |
|---|---|
| `game/scripts/ops_panel.gd` | the `radius_le.text_submitted.connect(func …)` lambda in `_build_body_ops` (~237–241); new `func commit_radius_field_enter() -> bool` placed right after `try_commit_pending()` (~1961) |
| `game/scripts/viewport_interaction.gd` | the `strip_le.text_submitted.connect(func …)` lambda inside `_build_selection_strip` (~500–505) **only** |
| `game/tests/run_rung01_replan14_focuskeys.gd` | the rows that re-arm when Fillet is no longer armed: steps **3b** (~397), **7** (~485) and **8** (~544), each `if main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES:` block (see "Tests that encode the bug") |
| `game/tests/run_rung01_wrench.gd` | `_b14_focuskeys_fillet` (~4092) and `_b14_fillet_tab` (~4146) **only** |
| `game/tests/run_rung01_replan13_radius.gd`, `run_rung01_replan3_fillet.gd`, `run_chamfer_sketch_layout_tests.gd` | only if the reproduce run shows a row there depends on the old Enter-cancel (each presses Enter in a Radius field). Say which row in the PR |

## Do not collide with #168 (merged)

#168 rewrote the strip `R` block and the panel Radius spin: `value_changed`, `focus_entered`, `focus_exited`, the `gui_input` Tab handler, `_commit_strip_radius`, `_write_strip_radius`, `_sync_strip_dressup_radius`, `_commit_panel_radius`, `_reveal_radius`, `ui_spin.gd`. **You change the two `text_submitted` lambdas and add one function. Nothing else in those blocks.** Do not touch Tab handling, focus modes, `release_focus_on_commit`, or any status string #168 prints. If your change makes a #168 assertion in `run_rung01_replan13_radius.gd` or `run_rung01_replan14_focuskeys.gd` red, that is the bug (the row encoded the old behaviour) only when it is one of the re-arm rows named above; otherwise stop and report.

## The bug (sx-035 N2 / A11b; leftover 9)

Verbatim: on `d408a8c7` "after strip Enter, `3` → `Top view` but **Fillet disarmed**; after re-arm, keys `3` / `4` did nothing while Fillet stayed armed." Expected: after Tab / Enter / spinner on the strip (or panel) Radius the viewport owns the keys; `3` / `4` / `8` print the view status and **Fillet remains armed**; the field keeps the committed value.

Repro: wrench part, click the body → `Fillet` (`Fillet r=1.00 — edit Radius, click edges, Enter`). Click the strip `R` text, Ctrl+A, `1`, `0`, Enter. Press `3`.

## Causes (read on `d534765c`; hypotheses until the gate runs)

1. **Enter disarms when nothing is selected** (high confidence). Both Enter handlers call `try_commit_pending()`:
   - strip: `strip_le.text_submitted` → `_commit_strip_radius()`, `_sync_strip_dressup_radius()`, `ops_panel.try_commit_pending()`, `return_viewport_keys.call_deferred()`;
   - panel: `radius_le.text_submitted` → `_commit_panel_radius()`, `if _pending == FILLET_EDGES or CHAMFER_EDGES: try_commit_pending()`, `_return_viewport_keys()`.
   `try_commit_pending()` → `_commit_armed_dressup()`, which with `view.selected_edges` empty, `view.selected_edge == ""` and no selected face sets `_pending = Pending.NONE`, emits `dressup_armed_changed(false, …)` and prints `No edges selected — cancelled`. That is the "disarmed after Enter" in the walk. `return_viewport_keys()` (`grab_focus()`) is what lets the next `3` change the view — so the view changed (`Top view`) while Fillet was already gone.
2. **The replan-14 tests hide it.** `run_rung01_replan14_focuskeys.gd` step 3b, step 7 and step 8 start with `if main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES: ctx.view.select_entity(body, ""); await _arm_fillet_strip(ctx)` — they silently re-arm. The walk's `_b14_fillet_tab` says so in a comment (`B14.7 types 10 Enter with no edges selected; that Enter applies/cancels the pick (No edges selected — cancelled). Re-arm so Tab can emit r=.`) and re-arms by clicking the Fillet strip button.
3. **"After re-arm keys 3 / 4 did nothing"** is probably the pre-#168 Tab / arm focus (#168 fixed arm → `3` and Tab → `4`; its row `1b` / `3b` is the regression net). If the gate shows a key row still red after cause 1 is fixed, that is a second bug: report the focus owner (`vp.gui_get_focus_owner()`) and fix it in `return_viewport_keys` only.

## Decision (replan 15, decision 1)

New `OpsPanel.commit_radius_field_enter() -> bool`:

```
## Enter inside the strip / panel Radius field. Commits the number the caller
## already pushed, and applies only when edges are already picked. With nothing
## picked the fillet stays armed so the next view key / edge click works.
func commit_radius_field_enter() -> bool:
	if _pending != Pending.FILLET_EDGES and _pending != Pending.CHAMFER_EDGES:
		return false
	if view != null and (not view.selected_edges.is_empty() or view.selected_edge != ""):
		return try_commit_pending()
	_emit_armed_dressup_status()
	return false
```

- The two `text_submitted` lambdas call it instead of `try_commit_pending()` (strip: unconditionally after the two commit lines; panel: replaces the `if … try_commit_pending()` block). Everything else in each lambda stays (`_return_viewport_keys` / `return_viewport_keys.call_deferred()`).
- A lone selected **face** with no edges is *not* "picked" here (the face-first path adds the face's edges to `selected_edges` on click, so a real face pick still applies). Do not change `_commit_armed_dressup`, `try_commit_pending`, `arm_or_apply_fillet`, `_start_or_apply_dressup` or the viewport `_gui_key` KEY_ENTER branch: viewport Enter and the second press of the strip Fillet button with nothing selected keep saying `No edges selected — cancelled`.
- With nothing selected, Enter leaves the status `Fillet r=10.00 — edit Radius, click edges, Enter` (from `_emit_armed_dressup_status`, the existing string) and the field text as committed (`10 mm`).

## Reproduce-first gate

Write `run_rung01_replan15_armedkeys.gd` first (template: `run_rung01_replan14_focuskeys.gd` `_part_rows`: `_boot`, `_place_box`, `_arm_fillet_strip`, `_click_at`, `_push_key`, `_strip` / `_panel_spin` helpers — copy the helpers, do not edit that file for them). Run it on the starting ref **before** any product edit and paste the output. Expected on `d534765c`: rows A3 and B2 (the Enter rows) red (`_pending == NONE`, status `No edges selected — cancelled`); every other row green (they are the net for #168). If A3 / B2 are green, stop and report which cause you found instead (do not invent one).

## The suite (`run_rung01_replan15_armedkeys.gd`, real input only, 1280×800)

Setup may place a box (`FilmUI.place_primitive` / the helper in `focuskeys`) and select it through the document API; every click / key below is a real event through the viewport. Each row asserts, after the step: `ops_panel._pending == OpsPanel.Pending.FILLET_EDGES` (**armed**), the strip `R` visible, and the key result.

| Row | Steps | Assertions |
|---|---|---|
| A1 | arm (strip Fillet button), `3` | `Top view`, armed |
| A2 | strip ▲ then ▼ (`_spin_arrow_pos`), `3` | `Top view`, armed, field text unchanged by the key (no stray `3`) |
| A3 | click strip text, Ctrl+A, `1`,`0`, **Enter**, then `4` | armed; camera Back (`Back view`); strip text starts `10`; panel parses 10; status after Enter is `Fillet r=10.00 — edit Radius, click edges, Enter` (log, before the `4`); `No edges selected` never appears |
| A4 | same with **Tab** | armed, `4` → Back (net for #168) |
| B1 | panel Radius: arrows, `3` | armed, Top |
| B2 | panel Radius click, Ctrl+A, `1`,`0`, **Enter**, `4`, `8`, `3` | armed after each key; Back, Bottom, Top; strip and panel both parse 10 |
| C1 | **Enter applies with edges**: arm, `3` (Top), click a real box top-edge pixel (`FilmUI.model_to_screen` of an edge midpoint), type radius `1`, Enter in the strip | one `fillet` feature added; status starts `Fillet 1 edges 1.00 applied` or `Fillet edge 1.00 applied` (the scope word follows `_apply_dressup`); `_pending == NONE` (applied disarms, as before) |
| C2 | **viewport Enter still cancels**: arm, no pick, focus the viewport (click empty canvas), press Enter | `_pending == NONE`, status `No edges selected — cancelled` (unchanged behaviour, pinned) |
| C3 | Chamfer: arm Chamfer, strip type `2`, Enter, `3` | armed (`CHAMFER_EDGES`), Top |
| D1 | after A3, press the strip **Fillet** button again | because it is armed the second press commits with nothing selected → `No edges selected — cancelled`, `_pending == NONE` (unchanged, pinned) |
| D2 | Esc with the field focused after A3 | the armed fillet is cleared within two Esc presses (same ladder `focuskeys` 8 pins) |

Counts are what the run prints. No `select_entity` / `.text =` / `.value =` / `*.emit` on a path under test (selecting the box in setup is allowed).

## Tests that encode the bug (edit minimally and say so in the PR)

- `run_rung01_replan14_focuskeys.gd`: in steps 3b, 7 and 8 replace the conditional re-arm with `check(main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "<step>: Fillet still armed after the previous Enter")` and delete the re-arm body; add the same `check` immediately after the step-3 Enter / `KEY_4` and after the step-7 panel Enter / `KEY_4`. Do not change any other row.
- `run_rung01_wrench.gd` `_b14_focuskeys_fillet`: after each of the two `KEY_ENTER` pushes add `check(ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES, "B14.7 Fillet still armed after Enter")`. `_b14_fillet_tab`: replace the unconditional `click_control(… "Arm fillet")` with a click **only when** `ctx.main.ops_panel._pending != OpsPanel.Pending.FILLET_EDGES`, and drop the now-false comment (clicking the button while armed is the second-press commit and would cancel it).
- Run `run_rung01_replan13_radius.gd`, `run_rung01_replan3_fillet.gd` and `run_chamfer_sketch_layout_tests.gd`; for any red row decide whether it depended on Enter cancelling; if it did, change only that assertion; otherwise report.

## Do not

- Do not change Tab, spinner or click-off handling, focus modes, `release_focus_on_commit`, the strip layout, or any #168 line outside the two lambdas.
- Do not make viewport Enter, the Fillet button's second press, or Esc keep a Fillet armed with nothing picked.
- Do not edit `_apply_dressup`, `_commit_armed_dressup` or the `applied` wording (WP6 pins it).
- Do not re-order the arm status or add statuses.

## Run before the PR

New suite (0 failures); `python3 tools/lint_rung01_e2e.py`; `run_rung01_replan14_focuskeys.gd`, `run_rung01_replan13_radius.gd`, `run_rung01_replan12_fillet.gd`, `run_rung01_replan12_pick.gd`, `run_rung01_replan11_fillet_ui.gd`, `run_rung01_replan3_fillet.gd`, `run_chamfer_sketch_layout_tests.gd`, `run_rung01_replan14_ctxbar.gd`, and `run_rung01_wrench.gd` (0 failures, 5/5, 7/7, 28/28, 7/7). PR title: `Rung 1 replan 15 WP1: Enter in a Radius field keeps Fillet armed`. PR body: leftover 9 fixed; the reproduce-first run (paste); the masked rows you changed and why; any soft-GL classification.
