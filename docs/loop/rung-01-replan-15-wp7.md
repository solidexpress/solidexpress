# Replan 15 WP7 — the walk rows, `_lint_replan15`, the Makefile loop, the UUID guard, STATUS

You are a BUILD agent (grok-4.7, medium effort, standard speed, `starting_ref` = the full 40-character sha of `main` **after WP1–WP6 are merged** (and WP3b if the parent launched it)). Read [`rung-01-replan-15.md`](rung-01-replan-15.md) (decisions 12, 14 and the sx-036 checklist) first. **If any of WP1–WP6 is missing from `main`, stop and report which** (check: `ops_panel.gd` has `commit_radius_field_enter`; `sketch_mode.gd` has `contour_highlight_state`; `main.gd` has `_with_3mf_extension`; `viewport_interaction.gd` has `_post_finish_chip_guard_until_msec`; `sketch_mode.gd` `_chain_breaker_status` no longer formats `breaker_id`; the six `run_rung01_replan15_*.gd` suites exist).

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. **Do not merge your own PR**: mark it ready for review and stop; the parent merges.

| File | Hunk (search by name; line numbers are `d534765c`, expect drift) |
|---|---|
| `game/tests/run_rung01_wrench.gd` | new `B15.*` rows and `_b15_*` helpers (placed after `_b14_polish`, end of file); one `await` line per row at the call sites below; `_on_sketch_status` (~70) UUID guard; `_press_extrude` (~2502) real click; `_fillet_face` (~780) `applied` assertion and the slot-floor edge-length assertion. **WP1 already changed `_b14_focuskeys_fillet` and `_b14_fillet_tab`: do not touch those two** |
| `tools/lint_rung01_e2e.py` | new `_lint_replan15` after `_lint_replan14`; its call and the `replan15 scripts are clean` print in `main` |
| `Makefile` | the `test-godot` target: one more `for f in game/tests/run_rung01_replan15_*.gd` loop after the replan14 loop |
| `docs/plan/STATUS.md` | a new entry at the top (format below) |
| `docs/loop/rung-01-replan-15.md` | the one-line `Status:` header only (`plan only` → `merged: WP1–WP7 on main at <sha>`) |

Do not edit `tools/check_rung01.py`, `docs/loop/linux-test-build.md` (no change expected), any `game/scripts/` or `sxcore/` / `sxkernel/` file, or any other suite (if a replan15 suite needs a change, report which WP owns it).

## 1. UUID guard (decision 9)

In `_on_sketch_status` (the walk's status hook) add: a status whose text matches the regex `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` (use `RegEx`; compile once as a `const`/static var) is appended to `_bad_status` and printed to stderr, like the existing "Failed to …" patterns. `_take_bad_status()` then fails the walk's existing `err == ""` checks. The guard's proof is the walk staying at 0 failures while every status goes through it (a synthetic status fed to `_on_sketch_status` would be a script shortcut on a tested path, so there is no such row); WP6's suite owns the positive UUID case.

## 2. Walk rows (`B15.*`; real input only; no `select_entity`, `_look_along(`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =` on a path under test)

The walk already builds the whole wrench through the GUI. Add these rows at the named places. Each is a `check(...)` with the `B15.n` prefix. Print one line `  B15.n <what>` before each group (as `B14.*` do).

| Row | Where (search by name) | What (real input) | Asserts |
|---|---|---|---|
| B15.1 N2 | `_human_fillet_picks`, right after `_b14_fillet_tab` | Fillet armed (strip button), click the strip `R` field, select-all, type `1`, `0`, **Enter**, then `3`, `4`; then the panel Radius field (click, select-all, `1`, `0`, Enter) then `3` | after the Enter and after each key `ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET_EDGES`; `Top view` / `Back view` printed; the strip `R` and the panel both read 10; status after Enter is `Fillet r=10.00 — edit Radius, click edges, Enter`; **no** `No edges selected` anywhere in the log. Then re-arm state for the following rows as the existing code expects (the next line in `_human_fillet_picks` already presses `3` and clicks the neck corner) |
| B15.2 contours | `_draw_centre_rect` (the head circle + the centre rectangle cross, so the sketch has ≥ 2 regions here: confirm by `print` of `sm.sketch.contour_count()` once; **if it is 1**, use the fallback below) | read `chrome._contour_bar.visible`; hover chip 2 (real `InputEventMouseMotion` at its centre); read `sm.contour_highlight_state()`; click chip 1 off then on (`_x11_click`) | bar visible with ≥ 2 chips; `focus == 1` with `fills[1] ≈ 0.5`; `fills[0] ≈ 0.28`; after the off-click `fills[0] == 0` and the log's last entry starts `Contour 1 of` and ends `— skipped`; after the on-click it ends `— included`; leave every chip on (the later Extrude must still use all regions: `_assert_contours_stay_on` is the existing net) |
| | fallback if the bar is hidden there | draw a throwaway circle (real Circle tool, centre at the empty `(120, 15)` UV, rim click) so the sketch has two regions, run the row, then delete it with the real Select tool (click the rim, `Delete`) and assert the entity count is back to what it was | same asserts; the deleted circle leaves no overlay: `contour_highlight_state().count` returns to 1 or 0 |
| B15.3 trim chain | the jaw sketch stage, after the existing trim rows | the existing walk's cutter is a Centerline; add `check(FileAccess.file_exists("res://tests/run_rung01_replan15_chain.gd"), "B15.3 the Line-cutter chain suite exists")` (the chain is proven by that suite; do not duplicate it here) | one row |
| B15.4 export | after `_export_via_dialog(ctx, "wrench.3mf")` and before the thick edit | one more export through the real dialog, name typed **without** an extension (copy `_export_via_dialog` into `_b15_export_noext(ctx, name)`; do not add a parameter to the existing helper) | file `/tmp/sx-rung01-<name>.3mf` exists; status begins `Exported 3MF → ` and ends `.3mf`; no extension-less file left |
| B15.5 Extrude | `_press_extrude` (real click, below) and the wrench blank extrude | after the blank's Extrude, a **second** real click at the same pixel (stored in `_last_extrude_pos` by `_press_extrude`) within 600 ms | still one extrude feature, one body, no `jaw_af` in the log, the last status is `Extrude Blind 10.0000 mm` |
| B15.6 key 0 | right after `_b14_camera` (part mode, body selected, no field focused) | real key `0`, then `3` | status `No view for key 0 — use 1 2 3 4 6 7 8`; the camera pose is unchanged by `0` (compare yaw / pitch read-only before / after); `3` → `Top view` |
| B15.7 applied | `_fillet_face` (top, bottom, slot floor) and `_fillet_neck` | clear `_status_log` before `_commit_fillet`; after it | `_status_has(" applied")` and the status label contains `applied`; never `Feature created` |
| B15.8 slot floor | `_fillet_face`, `label == "slot floor"`, right after the click and before the commit | read `ctx.view.selected_edges` and their lengths (`ctx.view.doc.get_edge_lines(body)`; map ids to segment lengths) | ≥ 2 selected edges with length within 1 mm of 150 (floor straight edges) **and** none within 1 mm of 175.4 or 42.2 (the sx-035 neck-loop symptom); the status lists the floor loop |
| B15.9 R1.5 | `_refuse_slot_floor` (existing) | no new row; the existing `1.25` assertion is the pin | — |

Also, in `_press_extrude`, replace `FilmUI.click_control(ctx, btn, …)` with a **real click**: store `_last_extrude_pos := btn.get_global_rect().get_center()`, `await _x11_click_screen(ctx.main.get_viewport(), _last_extrude_pos)`, then the same three `process_frame`s. `FilmUI.click_control` sends no mouse event (cue + `pressed.emit()`), so the walk never proved a real press on Extrude. If this makes any Extrude in the walk fail where it passed before, that is item 7 reproduced in the full flow: **do not revert**; report the stage and the status log and stop (the parent reopens WP5).

Expected total: the walk's check count grows from 646 by ≈ 45 (plan target ≥ 690); record the real number in the PR. Everything else in the walk is unchanged; `err == ""` rows keep passing; nut 7/7, blank 5/5, wrench 28/28, thick 7/7.

## 3. `_lint_replan15` (decision 12)

```
def _lint_replan15(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan15_*.gd"))
    if len(paths) < 1:
        errors.append("expected at least 1 run_rung01_replan15_*.gd")
    for path in paths:
        src = path.read_text(encoding="utf-8")
        prefix = f"{path.relative_to(ROOT)}:"
        _lint_replan11_camera(src, errors, prefix, extra_yaw_pitch_ok=("_zoom_model",))
```

Call it in `main()` after `_lint_replan14(errors)` and print `lint_rung01_e2e: {n15} replan15 scripts are clean` after the replan14 line (`n15 = len(list(TESTS.glob("run_rung01_replan15_*.gd")))`). No hard count (the same rule as replan 14). The camera needles stay exactly `_look_along(`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =` (with the existing `_zoom_model` allowance). Run the lint on a copy of a replan15 suite with a `set_view(` line appended to prove it fails, then delete the copy (do not commit it).

## 4. Makefile

In `test-godot`, after the replan14 loop add the same shape of loop for `run_rung01_replan15_*.gd` (tab-indented, `|| exit 1`).

## 5. STATUS entry (top of `docs/plan/STATUS.md`, format of the existing `## sx-035 …` entries; fill the numbers from the real runs)

```
## Rung 1 replan 15 — sx-035 leftovers
- Six real-input suites on main: `run_rung01_replan15_{armedkeys,contours,chain,export,extrude,strings}.gd` (+ `_chain_<stage>` only if WP3b ran). Enter in a Radius field no longer disarms Fillet / Chamfer (it applies only with edges picked); Contours chips highlight their region (`SxSketch.contour_outlines`, the only C++ change) and name it in the status; the profile-Line jaw → Up To Surface cut → slot → fillets → export chain is a regression net (headless, checker 28/28 and 7/7); Export 3MF always ends in `.3mf`; a second click at the Extrude pixel cannot hit an AF chip (600 ms guard); the chain-break status shows no entity id; key `0` says `No view for key 0 …`; `applied` is the Fillet / Chamfer success wording; a label click with Jaw armed is pinned.
- The wrench walk gained `B15.*` rows (N2, contours, export without extension, second Extrude click, key 0, `applied`, slot-floor edge lengths) **<N> checks, 0 failures**; nut 7/7, wrench 28/28, thick 7/7, blank 5/5. `_press_extrude` now sends a real mouse press (the walk used to call `pressed.emit()`). The walk fails on any status containing a UUID.
- sx-036 checklist delta: `docs/loop/rung-01-replan-15.md` (N10–N14, A11d reads `applied`). Plan: `docs/loop/rung-01-replan-15.md`, critique: `docs/loop/rung-01-leftovers-sx035.md`. Gate: the walk, the six suites, `tools/lint_rung01_e2e.py`.
```

## Run before the PR

`python3 tools/lint_rung01_e2e.py` (prints `<N> replan15 scripts are clean`); the walk alone with `export DISPLAY=:1` (0 failures, record the total, blank 5/5, nut 7/7, wrench 28/28, thick 7/7); every `game/tests/run_rung01_replan15_*.gd`; every `run_rung01_replan14_*.gd`; `run_parse_sweep_tests.gd`; `make test-godot` (stops at the first failure: run the failing script alone to see it, and compare with the pre-existing failures in `AGENTS.md`). PR title: `Rung 1 replan 15 WP7: walk rows, lint, Makefile, UUID guard`. PR body: the walk total, which rows needed the fallback, whether the real Extrude click changed any walk stage, the lint proof, the STATUS text.
