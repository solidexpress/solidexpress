# Replan 13 WP9 — walk, lint, Makefile, thick jaw-top row, spin-out rows (merges last)

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main` **after WP1–WP8 and the four spin-outs (#134, #135, #136, bc-1e0b30a3's PR) are merged**; if any is missing stop and report which). Edit only the files below. No product code. No `.gd.uid` files in the commit.

| File | Change |
|---|---|
| `game/tests/run_rung01_wrench.gd` | new rows (list below), real X11 input only (`_aim_pointer` + `_pointer_click`, `_push_key`); `thick checker prints 6/6` becomes `thick checker prints 7/7` **only if** the jaw row passes on the walk's own T=14 export (see Decision 2) |
| `tools/lint_rung01_e2e.py` | new `_lint_replan13`, called from `main()`; prints `<N> replan13 scripts are clean`, N = the number of `run_rung01_replan13_*.gd` files; **no hard-coded expected count** (the spin-outs each bumped the replan12 expected count and collided; do not repeat that) |
| `Makefile` | `test-godot` runs `game/tests/run_rung01_replan13_*.gd` (same loop as replan 12) |
| `tools/check_rung01.py` | one new `thick` row (Decision 2), a docstring note on DIAG (Decision 1), a helper `thick_jaw_top_probe(T)` so the unit test can pin the coordinates |
| `tools/test_check_rung01.py` | one test for `thick_jaw_top_probe` |

## Decisions (see `rung-01-replan-13.md` 13 and 18)

1. **DIAG does not follow T.** `check_rung01.py wrench` is the handout checker at T = 10 and stays hard-coded: its `1mm fillet top outer edge` and `1mm fillet on jaw top edge` probes are z ≈ 10 by definition of the handout. At T = 14 those two rows (plus `bbox Z` and, without a slot, `grip slot present`) are **expected** to fail; that is what the sx-033 DIAG run showed (18/22). The T-aware checker is `thick`. The docstring gains: *"DIAG: run `wrench` on a T≠10 file only to read the other fillet rows; `bbox Z (thickness)`, `1mm fillet top outer edge` and `1mm fillet on jaw top edge` fail by design at T≠10 — `thick` is the pass."*
2. **`thick` gains the jaw-top probe, because DIAG cannot see it.** At T = 14 nothing reads whether the jaw's top-edge 1 mm fillet survived the thickness edit (the wrench row probes z = 9.92, inside solid material at T = 14, so DIAG fails whether or not the fillet survived). New row `1mm jaw top fillet at new T`: `not inside(tr, jaw_top_probe)` with `jaw_top_probe = (200 + (10 − 10.08)·s2, (10 + 10.08)·s2, T − 0.08)`, `s2 = √2/2`, the same point as the wrench row `J(10, 10.08, 9.92)` shifted to the new top. Expected text `outside`. thick goes **6/6 → 7/7**. **Measure first:** run the new row against the walk's own T=14 export (`/tmp/sx-rung01-wrench-t14.3mf`, the headless walk produces it). If it passes, ship the row. If it fails, **do not loosen the probe or the tolerance**: that means the jaw top fillet is lost at T = 14 (a product bug); keep thick at 6/6, add the failing probe as a printed `INFO` line (not a row), and write the failure into `docs/loop/rung-01-leftovers-sx034.md` so the next plan owns it.
3. **Lint** gets the same camera needles as replan 12 (`_look_along`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =`) for the replan13 suites; they are validation suites, so script-side setup (`select_entity`, `begin_edit`, placing circles) is allowed, every press/key/motion under test is real.
4. **Walk stays honest.** The critique's honesty gaps become rows: the real rail Slot press, the Jaw click-2 repeat, the bottom-face click followed by a pointer move.

## Walk rows to add (print `B13.<n>` ids; every row real input; exact count is whatever the run prints, plan target 456 → at least 490)

1. **Slot by pointer (A11a, #136).** Press the rail `Slot` button with `_pointer_click` at the button centre (if `FilmUI.click_control` emits `pressed` instead of pressing, replace it for Slot, Smart Dim and Trim in this walk): the button is highlighted (`button_pressed`), status starts `Slot —`, type `5` Enter (radius), click the two centres, read `Slot c-c 150.0000 R5.0000`. Replaces the script arming at the grip-slot step (`select_sketch_tool(... SLOT)` line ~380) if that line does not already go through a pointer press.
2. **Jaw click 2 twice (A8, #135).** Click 1, click 2, click 2 again: after click 2 the status names the next step; the repeat does not commit a zero-width jaw (entity count unchanged), the status says so; click 3 commits.
3. **Chip row (A1, #134).** With two circles selected the chip row's global rect does not intersect the left rail rect and ends inside the viewport.
4. **Bottom-face pick (bc-1e0b30a3).** Key `8`, select the body, one real click on the bottom face, then **a separate pointer move of 40 px**: the body's bbox is unchanged, the status never says `Moved body`.
5. **Tool status (WP1).** Press Line, Smart Dim and Trim by pointer after a Jaw: the status starts with the tool word each time.
6. **Finish bar (WP1).** After the first extrude (Cut, Up To Surface set on a previous sketch) open a new sketch: Blind, New, Extrude enabled.
7. **Trim keeps the typed values (WP2).** After `Trimmed open jaw` exactly one width label and one angle label exist; they read `20` and `45°`; the measured wall angle is `45 ± 0.01°`.
8. **Fillet radius (WP3).** While Fillet is armed `StripRadius` equals the panel Radius (10, then 1).
9. **Refused fillet is clean (WP4).** After the walk's refused slot-floor R1.5, `main._document_is_dirty()` equals its value before the attempt.
10. **Frame (WP5).** In the blank sketch press `F` after the 200 dimension: both circles' extreme points are on screen.
11. **Measure marks (WP6).** After Shaft Lines `measure_overlay.has_anchor()` is false; with Circle armed ten pointer moves over the jaw leave no marks.
12. **Save As name (WP7).** In the jaw-sketch Save As step type the new name with no Ctrl+A: the dialog's filename equals the typed name.
13. **Popups (WP7).** The View ▼ popup's panel style is opaque.
14. **Typed fields (WP8).** Polygon preview radius follows three pointer moves; the Distance field never samples the old value after `14` Enter.
15. `thick checker prints 7/7` (or 6/6 under Decision 2's fallback).

## Failing-first

- `python3 tools/test_check_rung01.py` — new test `thick_jaw_top_probe(14.0)` returns `(199.9434, 14.1986, 13.92)` within 1e-3; red before the helper exists.
- The walk's `thick checker prints 7/7` row is red against the unmodified checker (it prints 6/6).
- `python3 tools/lint_rung01_e2e.py` ends with `<N> replan13 scripts are clean`; with a replan13 suite that uses `_look_along(` the lint fails (add and remove a throwaway line to see it red).

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib DISPLAY=:1
make build && make test-kernel
python3 tools/lint_rung01_e2e.py && python3 tools/test_check_rung01.py
timeout 900 tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone, nothing else running
python3 tools/check_rung01.py thick /tmp/sx-rung01-wrench-t14.3mf 14
python3 tools/check_rung01.py wrench /tmp/sx-rung01-wrench-t14.3mf     # DIAG, read only
```

Then every `game/tests/run_*.gd` one at a time with `timeout 120` against the whole-suite table (replan 12) plus the deltas listed in `rung-01-replan-13.md`.

## Do not

- Change any other checker formula or tolerance, `--allow-mirror`, or the DIAG rows' probes.
- Soften a failing walk row to make the count come out; report it.
- Edit product code to make a row pass (that is the owning WP's job; reopen it).
