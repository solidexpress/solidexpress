# Replan 14 WP8 — walk rows, `_lint_replan14`, Makefile loop, the DIAG note, STATUS (merges last)

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` **after WP1–WP7 and #151 are merged** (#148–#150 and #152 already are); if any is missing stop and report which). Edit only the files below. **No product code.** Read [`rung-01-replan-14.md`](rung-01-replan-14.md) (waves, the sx-035 checklist delta and rules 37–40) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (item 18) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

| File | Change |
|---|---|
| `game/tests/run_rung01_wrench.gd` | new `B14.*` rows (list below), real input only (`_pointer_click`-style helpers and `_push_key` already in the file; the rail / timeline / dialog presses through `FilmUI.click_control`) |
| `tools/lint_rung01_e2e.py` | new `_lint_replan14`, called from `main()`; prints `<N> replan14 scripts are clean` |
| `Makefile` | `test-godot` runs `game/tests/run_rung01_replan14_*.gd` (same loop as replan 13, right after it, ~line 152) |
| `tools/check_rung01.py` | the DIAG docstring (line 15) lists the four rows; new helper `diag_expected_failures_at_t(T)`; a printed `DIAG:` header when the bbox Z is not 10 (item 18). **Do not change `thick`, any probe or any tolerance** |
| `tools/test_check_rung01.py` | one new test for the helper |
| `docs/plan/STATUS.md` | one entry at the top (format of the existing ones) |

## Item 18 — the DIAG checker note (the only "tooling" leftover)

Verbatim, `6-A13c-diag.txt` (T = 14 export): `FAIL  grip slot present at y=0,z=8.75  got 0 samples open`; the DIAG failures at T = 14 are `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge` (18/22 rows, 5760 triangles). The sx-034 checklist text said three. `check_rung01.py` line 15 says three: `bbox Z (thickness)`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge`. The fourth is real and by design: the wrench row probes the grip slot at `z = 8.75` (between the floor fillet 7.5–8.5 and the rim fillet 9–10), which at T = 14 is inside solid material, so it reads `0 samples open`. `wrench` is the T = 10 handout checker; `thick` is the T-aware pass (7/7).

**Decisions (replan-14 decision 13):**

1. `wrench` stays hard-coded at T = 10. Nothing about its probes, rows, tolerances or exit code changes; `thick` is untouched.
2. Docstring: line 15 lists **four** rows, adding `grip slot present at y=0,z=8.75`.
3. New module-level helper `diag_expected_failures_at_t(T)` in `check_rung01.py`: returns the list of the four row names (`['bbox Z (thickness)', 'grip slot present at y=0,z=8.75', '1mm fillet top outer edge', '1mm fillet on jaw top edge']`) when `abs(T - 10) > TOL`, else `[]`. It is pure (no numpy), documents the expectation in one place, and is what the unit test pins.
4. In the `wrench` branch of `main()`, after the three bbox rows are added, if `abs(ext[2] - 10) > TOL` print one line **before** the results table: `DIAG: bbox Z is <ext[2]:.3f> mm, not 10 — this is the T=10 handout checker; at T≠10 these four rows fail by design: <names>. Use \`thick\` for the pass.` The table and the exit code are unchanged (still non-zero on any failing row). Do not suppress or reclassify a row.
5. The docstring line also says: "`bbox Z`, the grip slot and both fillet rows fail by design at T≠10; the other rows are the diagnostic."

`tools/test_check_rung01.py`: one new test class `DiagNoteTests` with `test_four_rows_fail_by_design_at_t14` (the helper returns the four names for 14.0, `[]` for 10.0 and for 10.1 within TOL=0.2, and the names are exactly those in the critique) and nothing else. Run `python3 tools/test_check_rung01.py`; it must pass and the existing tests are unchanged.

## `_lint_replan14`

Copy `_lint_replan13` (`tools/lint_rung01_e2e.py` ~492): glob `run_rung01_replan14_*.gd`, error if there are none, apply `_lint_replan11_camera(src, errors, prefix, extra_yaw_pitch_ok=("_zoom_model",))` to each. Call it from `main()` after `_lint_replan13(errors)` and print after the replan13 line:

```
n14 = len(list(TESTS.glob("run_rung01_replan14_*.gd")))
print(f"lint_rung01_e2e: {n14} replan14 scripts are clean")
```

No hard-coded count (replan 12 / 13 taught that spin-outs bump it). Earlier WPs grepped their own suites for the needles; WP8 is where lint enforces them: if a replan-14 suite trips a needle (`_look_along(`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =`) **fix the suite** (use real keys / wheel) or, if the line is script-side setup that the replan-13 rule already allows, say so; do not widen the allow-list beyond `_zoom_model`. Report which suite and line in the PR.

## Makefile

In `test-godot`, after the replan13 loop:

```
	@for f in game/tests/run_rung01_replan14_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
```

## Walk rows — `game/tests/run_rung01_wrench.gd`

The honesty gaps the critique named (headless green, GUI red) become walk rows. Print each as `B14.<n>` with real input only: the file's own `_pointer_click` / `_aim_pointer` / `_push_key` helpers and `FilmUI.click_control`. No `select_entity`, `.text =`, `.value =`, `*.emit`, `set_extrude_distance`, `_look_along`, `set_view(`, `.yaw` / `.pitch` writes on a path under test (the lint enforces these on the walk). Place each row at the point of the walk where its state exists (the walk's own order is the sx-034 / sx-035 order); extract each into a small `_b14_<name>(ctx)` function so the diff is readable and grep-able. **Plan target: at least 590 checks, 0 failures** (551 + the rows below; the exact count is what the run prints, never edited to match). If a row fails because a product WP did not fix its item, do not weaken the row: reopen that WP and say which.

Re-verify rows (the five failed sx-034 rows; they exist today in some form, the new rows pin them against the GUI failure):

| Id | Where | Row (real input) | Pass |
|---|---|---|---|
| `B14.1` (A8) | jaw sketch, today's Jaw rows | click 1, click 2, **click 2 again at the same pixel**, click 3 | the repeat does not print `Jaw committed` and the entity count is unchanged (#148); click 3 commits |
| `B14.2` (A9) | after `F` in the face sketch | read the origin's screen x and the rail's right edge (`ChromeDock.rail_right`); click the pivot centre without moving the view | origin x ≥ rail right + 30; the click lands (`Circle r=5.0000`); camera pose unchanged by the click (#149) |
| `B14.3` (A9b) | Up To Surface cut | after the cut | status contains `Up To Surface 10.0000 mm` and not the Blind spin value (#150) |
| `B14.4` (A11a) | the real rail Slot press | press the rail Slot, type radius 5 Enter, click the first centre, read the entry field label, type 150 Enter | label `c-c`; status starts `Slot c-c 150.0000 R5.0000` (#151) |
| `B14.5` (L3) | Fillet armed | type 10 in the panel Radius then Tab; type 1.5 in the strip `R` then Tab | after each Tab: strip text, panel text and the status `r=` show the same number (#152) |

New rows (one or more per product WP; each is a *real-input* version of the WP's own suite row):

| Id | WP | Row |
|---|---|---|
| `B14.6` | WP1 | in the jaw sketch list the dimension labels, File → Save As (real menu, real dialog, name typed with real keys), list again: identical text list, no second `45°`, no extra `5` / `22.5`; hover a label with its editor open: no Δ overlay (`SketchMode.dimension_label_screen_rects()` against `constraint_glyph_screen_rects()` for overlap: none) |
| `B14.7` | WP2 | Fillet armed after key `3`: real click on the strip `R` ▲, type `10`, Enter, press `3`: camera is Top, field text `10`; the same through the panel Radius; Polygon + Circle field: Ctrl+A leaves the sketch selection untouched, first Esc status `First point dropped — Esc again exits the sketch` |
| `B14.8` | WP3 | body selected, face picked, Fillet armed: `Fillet` and `Chamfer` button x identical (±1 px) in the three states; the context bar rect does not intersect `Snap`, the top menu row or the left rail, and is inside 1280×800 |
| `B14.9` | WP4 | before Trim: Jaw commit, real Ctrl+Z: status `Undo: Jaw`, the jaw entities are gone; Ctrl+Shift+Z (and Ctrl+Y): `Redo: Jaw`, back; undo to empty: `Nothing to undo` |
| `B14.10` | WP5 | part mode, key `3`: wheel-in 3 notches then out 3 with the pointer on the head: the unprojected world point under the pointer moves ≤ 2 px each notch; `F` (body selected) status `Framed selection`, `Shift+F` `Framed all`, printed once each |
| `B14.11` | WP6 | rail Jaw press: `JawTool` pressed, `ToolRect` not, chip row hidden; rail Rect then lights Rect with the five chips; rail Circle, one centre click: status `Circle — centre set, click the rim or type a radius` |
| `B14.12` | WP7 | click the pencil on the sketch row: `sketch_mode.active`, status `Editing sketch`, no rename field; exit; File → Open, type an existing `.sxp` name with real keys: the Open button is enabled (if a headless run cannot reproduce soft-GL, the row still asserts it) and a real click opens it |
| `B14.13` | item 16 | the first extrude's body is named `extrude <n>` where `<n>` is its timeline index (assert the **rule**, not the literal `3`: `"extrude %d" % index`) |

Where a real-input path does not exist in the walk yet (the Save As dialog typing, the timeline pencil), build it from `FilmUI.activate_menu_id`, `FilmUI.click_control` and `_push_key`; do not call the model. Keep every row independent: if one fails, the rest still run (`check` never aborts).

If adding all rows pushes the walk past ~20 min on the CI runner, move the Save As, Open and timeline rows (`B14.6`, `B14.12`) to the **end** of the walk (after `_triball_one_esc`) rather than dropping them.

## STATUS

One entry at the top of `docs/plan/STATUS.md`, newest first, same style: `## Rung 1 replan 14 — sx-034 leftovers`; three or four bullets: the seven suites by name (`run_rung01_replan14_{savelabels,focuskeys,ctxbar,undo,camera,railstatus,polish}.gd`), the `SxSketch.snapshot()` / `restore()` bindings (WP4's only C++), the walk's `B14.*` rows and final count, the DIAG note (the four by-design rows at T = 14), and one sentence: "sx-035 rules 37–40 (body names are timeline indices; read labels not pictures; after a commit the viewport owns the keys; undo reads the status) live in `docs/loop/rung-01-replan-14.md`." Gate: the walk and `tools/lint_rung01_e2e.py`. Do not edit other entries.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
python3 tools/test_check_rung01.py
python3 tools/lint_rung01_e2e.py          # prints "<N> replan14 scripts are clean" (N = 7 once WP1-7 are in) and the replan13 line
tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone; paste the final "<N> checks, 0 failures"
for f in game/tests/run_rung01_replan14_*.gd; do tools/godot/godot --headless --path game --script res://$(echo $f | sed 's|^game/||') 2>&1 | tail -1; done
make test-godot   # stops at the first failing script; the known failures are listed in AGENTS.md
python3 tools/check_rung01.py wrench <any T=14 3mf>   # shows the DIAG header; fails four rows, exit non-zero, by design
```

The walk's own checker rows (blank 5/5, wrench 28/28, thick 7/7, nut 7/7) must stay as they are. `make test-godot` still has the pre-existing failures in `AGENTS.md`; record them and do not fix them here.

## Acceptance

- `python3 tools/test_check_rung01.py` passes with one more test; `thick` and every probe are byte-identical (`git diff tools/check_rung01.py` shows only the docstring, the helper and the DIAG print).
- Lint prints `<N> replan14 scripts are clean` with `N >= 1` (7 after the WPs) and exits 0; `make test-godot` runs the replan-14 suites.
- The walk is green: 0 failures, at least 590 checks, blank 5/5, wrench 28/28, thick 7/7, nut 7/7; each `B14.*` row printed.
- STATUS entry added; no other docs, no product code changed.
- PR body: the walk's final line, the lint lines, the DIAG header output for a T = 14 file, and the list of rows that needed a product fix first (or "none").

## Do not

- Change `thick`, any other probe, tolerance or exit code in `check_rung01.py`; add a thickness argument to `wrench`.
- Edit product code (`game/scripts`, `sxcore`, `sxkernel`) or any WP's own suite except to satisfy lint with the reported change.
- Weaken or delete an existing walk row; use `select_entity`, `.text =`, `.value =` or camera writes in the walk.
- Add a hard-coded count to the lint, or widen its allow-list beyond `_zoom_model`.
