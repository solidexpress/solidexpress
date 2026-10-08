# Rung 1 replan 18 — WP1: polygon AF is independent of the pointer bearing (L9 test net, no product code)

Status: planned. Plan: [`rung-01-replan-18.md`](rung-01-replan-18.md). Next walk: **sx-039** (the checklist embedded in the plan). Baseline: `main` `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed` (re-PLAN 17 complete plus the spin-outs #216–#225).

Start from `main`. Open one PR. Stay until quick CI (linux kernel, godot-smoke, website-demos) is green. Never wait for `macos-kernel` or `windows-export`. Do not edit `docs/plan/STATUS.md`. This WP is independent of the other WPs of the plan: start it now.

Triage items covered: **T1** (L9: the spec conflict and the ~2 % spread sx-038 saw). Walk rows unblocked: L9, A14.

## Rules for every BUILD agent (read first)

- **Repository:** `github.com/solidexpress/solidexpress` only. Never the `snadrus` fork. Do not touch PR #11.
- **Model / start:** grok-4.7, medium effort. Start from `main` (`starting_ref` = the full 40-character sha of `main` at launch; the plan was written against `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed`). If `main` has moved, say so in the PR body and carry on from the new tip. Function names below are stable; line numbers are not quoted.
- **One PR per WP, to `main`.** Open it **ready for review** (not draft). Never merge it yourself. Stay with the PR until quick CI is green: **linux kernel, godot-smoke, website-demos**. **Never wait for `macos-kernel` or `windows-export`.**
- **Do NOT edit `docs/plan/STATUS.md`** (take `main`'s version on any conflict). Put your notes (what changed, red-first output, skipped items with the reason) in the **PR body**.
- **Reproduce first.** Run the named suite(s) on the starting ref **before** any edit and paste the real output (the `FAIL -` lines) in the PR body. If a suite that the plan says is red is already green, stop, say so, change nothing, and open no PR.
- **Tests are real input.** Setup (placing geometry, entering a sketch, adding entities) may use the document / sketch API and `tests/lib/film_ui.gd`. Every press, key, motion and wheel **under test** is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed with `Viewport.push_input`. Forbidden on a path under test (the e2e lint fails the PR for `run_rung01_replan16_*` and later): `select_entity`, `.text =`, `.value =`, `.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =`. Boot at 1280x800 (`FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))`).
- **Register a suite** only by adding one new file `packaging/ci/suites.d/<name>.suite` (`<name>` = script basename without `run_` and `.gd`; keys `script=tests/<file>.gd`, `tier=ci|full`, optional `timeout=<s>`). **Never edit** `packaging/ci/run_godot_suites.sh`, `packaging/ci/run_suites.sh`, the Makefile `test-godot` recipe, `tools/lint_rung01_e2e.py` or `AGENTS.md`. Do not commit `.gd.uid` files.
- **Run suites one at a time** with `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` (and `DISPLAY=:1` for X11 suites): `tools/godot/godot --headless --path game --script tests/<file>.gd`. A suite passes when it prints `<n> checks, 0 failures` (films: `65 films, 0 failures`).
- **Before opening the PR run, one at a time:** the suites your WP names; `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; and the "Also run" list of your WP. Paste the last line of each in the PR body.
- **Never** pass `user://` or `res://` into GDExtension C++ (`SxDocument` / kernel I/O); `ProjectSettings.globalize_path(...)` first.
- **Parallel-safe edits.** The other WPs of this plan run at the same time on the same `main`. Edit **only** the files and functions your WP names. No reformatting, no moved code, no renames, no new status strings, no new top-of-file constants.
- **No design decisions are left to you.** Every choice is in the `Decisions` section of your WP. If the code on `main` contradicts a stated fact, stop, say so in the PR body, and implement the closest reading of the decision.

## Why

sx-038 L9 read `Polygon AF` 16.7157 / 16.9194 / 17.0717 at 20° / 70° / 110° and scored PARTIAL: the checklist said the pointer sits **on a vertex**, which is impossible at 20° and 110° with flats fixed horizontal, and the AF looked ~2 % bearing-dependent. The PLAN box measured it (log: the polygon probe, 8 bearings x snap ON / OFF at 150 physical px): every bearing prints the same `Polygon AF 26.4910 — flats horizontal — click to place (or type the size)`; the circumradius is always `AF / √3 = 15.2946 mm` and every hover is exactly 150.0 px from the centre. So **there is no product bug**: the spread was the walker measuring pixels in a scaled screenshot (1920x1200 screen, 1280x800 images) and the centre click snapping to the origin (the click was 11 px from the origin and the snap radius is `max(1.25, 0.02 × span)` mm ≈ 16 px, so the centre moved). The spec is decided in the plan (decision D2) and the sx-039 L9 row is rewritten. What is missing is a headless net that pins the invariance with **real pointer moves at equal pixel distance**, so a future change cannot reintroduce a bearing-dependent AF. That is this WP.

## Decisions (final)

1. **Spec.** Across-flats polygon, flats horizontal, start angle 0. The pointer sits on the circumscribed circle (not necessarily on a vertex). `AF = √3 × |pointer − centre|`, independent of the bearing. Hover status `Polygon AF %.4f — flats horizontal — click to place (or type the size)`. A typed size is the AF itself. **No product file changes.**
2. **Files you may edit:** new `game/tests/run_rung01_replan18_polyaf.gd` and new `packaging/ci/suites.d/rung01_replan18_polyaf.suite` (`script=tests/run_rung01_replan18_polyaf.gd`, `tier=ci`, `timeout=120`; if the measured run is above 60 s, use `tier=full` and say so in the PR body). Nothing else.
3. **If any assertion is red on the starting ref: stop.** Do not touch `sketch_mode.gd`, `viewport_interaction.gd` or any other product file. Paste the red output in the PR body and open the PR with the new script only: **no `.suite` file**, so CI stays green. Say so in the PR body. A red L9 net means the plan's measurement was wrong and a human re-plans.
4. **Template to copy:** `game/tests/run_rung01_replan17_walk.gd` — `_boot`, `_ground_sketch`, `_press_rail`, `_click_uv`, `_hover_uv`, `_zoom_model`, `_grab`, `_saw_log`, and its function `_check_polygon_bearings` (the existing L9 assertions at 20° / 70° / 110°, which compute the expected AF from the **measured** radius and so would not notice a bearing-dependent radius).

## Steps

Copy the boot / helper block of `run_rung01_replan17_walk.gd` into the new script (header comment names the checklist rows L9 / A14; title line `rung01 replan18 polygon AF invariance`). Write one test function `_run_case(snap: bool, centre_uv: Vector2)` and call it for the four cases below. Each case enters a sketch on the ground plane, presses the rail **Polygon** button, zooms so that **150 physical pixels = a known model distance** (use `_zoom_model` as the walk does; compute `ppm` = pixels per mm from two projected points, do not assume it), clicks the centre once with a real click, then for each bearing hovers with a real `InputEventMouseMotion` at **exactly 150.0 px** from the centre's screen position and reads `sm._hover`, `sm.polygon_preview_vertices()` and the status text.

Cases (all four must run in one script):

| Case | Snap | Centre (model, mm) |
|---|---|---|
| 1 | on (`sm.snap_enabled = true` before the centre click) | `(0, 0)` |
| 2 | off | `(0, 0)` |
| 3 | on | `(37.0, -21.0)` (away from the origin, so no origin snap) |
| 4 | off | `(37.0, -21.0)` |

Bearings: `20, 70, 110, 160, 200, 250, 290, 340` degrees (all ≥ 40 px away from the horizontal and vertical lines through the centre at 150 px; the H / V axis snap pulls a pointer that is nearer than the snap radius `max(1.25, 0.02 × span)` mm onto the axis).

Assertions per bearing (every one is a `check(...)`, message names the case and bearing):

- the hover status equals `Polygon AF %.4f — flats horizontal — click to place (or type the size)` with `%.4f` of `√3 × |sm._hover − centre_model|`;
- `polygon_preview_vertices()` has 6 entries, each at distance `|sm._hover − centre_model|` from the centre (±0.05 mm);
- the vertical extent of the vertices (max y − min y) equals the AF (±0.05 mm) (flats horizontal ⇒ the flat-to-flat distance is the y extent).

Assertions per case (across the 8 bearings):

- the 8 printed AF values are equal to each other within **0.2 %** (they are 0.000 % on the PLAN box at 150 px; 0.2 % is the pixel-rounding allowance);
- one more hover at 70° and **100 px**, and at 70° and **200 px**: AF ratios `100 : 150 : 200` equal `1 : 1.5 : 2` within 1 %.

Commit check (case 1 and case 3 only): after the last hover (340°, 150 px) press and release the left button at that same pixel (real events). The sketch now holds 6 lines forming the polygon, and the status begins `Polygon AF` with the **same** 4-decimal AF as the hover (read `_status_log`); `Esc` is not needed afterwards.

Typed size (case 1 only, a fresh sketch): rail Polygon, centre click at the origin, type `20` then Enter with real key events: status `Polygon AF 20.0000 — flats horizontal`.

## Acceptance (exact)

- `tools/godot/godot --headless --path game --script tests/run_rung01_replan18_polyaf.gd` prints `<n> checks, 0 failures` with n ≥ 120 on the starting ref (it is a regression net: **green before and after**; there is no product change).
- `python3 tools/lint_rung01_e2e.py` prints `<n> replan18 scripts are clean` (n ≥ 1); `python3 tools/lint_suites.py` prints `lint_suites: <n> suites ok`.
- No file other than the two new ones is in the diff.

## Also run

`tests/run_rung01_replan17_walk.gd` (`0 failures`, `WALK-SUMMARY stages=8 first_red=none`), `tests/run_rung01_replan11_poly.gd`.

## Rows unblocked

L9 (the sx-039 row asserts the same numbers by hand), A14.
