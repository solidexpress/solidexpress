# Post-rung-06 cleanup — layering, one fixture, then the candlestick demo film

Status: planned. Docs only. Baseline: this branch `24a8306` (`Rung 6: Revolve & Sweep candlestick`, PR #275; `git log 761b0a4..24a8306` is that one squash). Rung 6 walk 46/46. `check_rung06` final 7/7. Rung 1 walk 77/77. Rung 2 44/44. Rung 3 46/46. Rung 4 32/32. Rung 5 36/36. `check_rung05` final 10/10. Headless: 236 run, 0 failed. Manifests on this sha: **240** (`79 ci`, `157 full`, `4 known-red`), so the tier runs `79 + 157 = 236`. Checklists: [`rung-06-plan.md`](rung-06-plan.md), [`rung-06-result.md`](rung-06-result.md). Previous cleanup, same shape: [`post-rung-05-cleanup.md`](post-rung-05-cleanup.md) / [`post-rung-05-result.md`](post-rung-05-result.md) (PR #272): WalkChrome lifts, PipeFixture, flanged_pipe film. Website curator then featured tutor1/hexkey/flanged_pipe (PR #273) without growing the 12-card cap.

**Prompt for ONE BUILD agent.** Execute the work packages below in order, one commit per WP, on the branch you were given. Push that branch. Do not open a PR. This file is the only prompt. Part A (WP1–WP5, and WP6–WP7 only when the ★ rule says so) does not change product behaviour. Part B (WP8–WP10) is the candlestick film, its test, the rendered video, the poster, the how-to, and the website wiring. Part B is not optional and outranks every ★ WP. WP11 is the only full test pass. Do not build, walk, or run the tier before WP11 except for the cheap check named in that WP.

## Why this shape

Rung 6 landed green as one squash. The new tools already use tables in the places the rung plan named (`SketchEllipse.SPEC`, `SketchTangentArc.POLICY`, checker `PART` / `STAGES`, walk `STAGE_FILE`). Dummy renderer, parallel jobs, per-job `HOME`, WalkChrome shared gestures, and smoke-skip of dedicated film suites already landed in post-rung-4/5 and stay. What is still a pile is WP16’s late special-case fixes (sole-body cut target, fuse-by-volume, label parking, leftover Smart Dim selection), a 1078-line `WalkUI06`, six suites that clone `_init` and five byte-identical helpers, two dead symbols, no STATUS entry, and spent loop docs. Measured on `24a8306`:

| Fact | Number | Source |
|---|---|---|
| Walk UI | `WalkUI06` is 1078 lines, 68 methods. Shared names vs `WalkUI05`: 5 (`mm` byte-identical; `part` ratio 0.988, checker filename only). vs `WalkUI04`: 6, none identical. vs `WalkUI03`: 3, none identical. vs `WalkChrome`: 2 overrides (`part`, `sketch_on_datum`). Chrome already owns the post-rung-5 identical blocks (`_release_project`, `click_verb`, `check_probe`, `reopen`, `headless`, `select_face`, `dimension_line`, `clear_sketch_selection`, `frame_clickable`). Header of `chrome.py` already says “shared click and read helpers” | `tools/walk/rung6/ui06.py`, `tools/walk/chrome.py` |
| Rung-6 suites copy a boot | six scripts, 874 lines. `_init` ×6 (ratio 0.91–0.99; draft↔sweep 0.9898). Byte-identical pairs: `_click_named` (draft/sweep, 10 lines), `_pick_sketch` (draft/sweep, 17), `_last_arc` (horizontal_points/tangent_arc, 6), `_line` (refs/tangent_arc, 5), `_line_count` (ellipse/tangent_arc, 6) — 44 extra lines. All six `.uid` files exist | `game/tests/run_rung06_*.gd` |
| PART restated | `Rung06Part` hardcodes 220 / 20 / 10 / 60 / 150 / 17.5 / 5.0. Draft+sweep use it. Suites do not call `SxChecker.run("rung06", ["params"])`. Assertion literals restate Ø30 / 15° / 35×10 / y=10 | `game/tests/lib/rung06_part.gd`, `tools/check_rung06.py` `PART` |
| WP16 special cases | (1) `_boolean_target_fid` / `_sole_body_feature`: cut target = session → support host → host-face body → the only body (pencil-reopened jaw). (2) `ops_sweep.cpp` `keeps_target` / `fuse_ribbon`: reject a fuse whose volume is &lt; 90% of the target; among valid ribbons pick largest +X then largest volume. (3) `_park_labels_outside_host_face` / `_exit_clear_of_labels`: shortest face-edge exit whose plate misses parked labels (Ø130/Ø10/94). `_shortest_exit` unused. (4) `set_tool` SMART_DIM clears a leftover size-1 selection so two 120s stay lengths; CONVERT/OFFSET always clear. WalkChrome `clear_sketch_selection` + `frame_clickable` already keep rungs 3–5 dim/path clicks | `game/scripts/sketch_mode.gd`, `sxkernel/src/features/ops_sweep.cpp`, `tools/walk/chrome.py` |
| Dead symbols | `SketchTempAxes.axis_uv` (snap uses `snap_y_axis`). `SketchMode._shortest_exit` (parking now uses `_exit_clear_of_labels`). Count of each name in `game/**/*.gd` is 1 | finder in WP2 |
| One starter, dummy by default | already true. `run_suites.sh` default `--jobs nproc`, per-job `HOME`, `--rendering-driver dummy` unless `render=viewport`. Smoke skips `film_<id>_tests.suite`. Pixel `render=viewport` stays parked (§9 / §10 / §11) | `packaging/ci/run_suites.sh`, `game/tests/run_film_manifest_smoke.gd` |
| Same film, two starters | dedicated suites own `ubc_wrench`, `lesson2_box`, `tutor1`, `hexkey`, `flanged_pipe`. A candlestick suite would make a sixth double unless smoke skips it | `packaging/ci/suites.d/film_*_tests.suite` |
| Spent loop docs | `post-rung-05-cleanup.md` (README already says the next cleanup deletes it). Keep the live contracts (rung plans/results, post-rung-03/04/05 results, this file) | `docs/loop/README.md` |
| No rung-6 status entry | `docs/plan/STATUS.md` starts at Post-rung-5. The rung PR was told not to edit it | `STATUS.md` |

Not in this pass (already parked, or a second painter that is doing a different job): splitting `SketchMode` / `ViewportInteraction` ([roadmap.md §7](../plan/roadmap.md)), the §8–§11 rows, pixel `render=viewport`, CommandBus, Jaw template. `SketchEllipse.SPEC`, `SketchTangentArc.POLICY`, and WalkChrome lifts already exist — do not re-table them. Do not re-copy `mm` / `part` onto chrome (one-line wrappers that pass the checker script).

## Invariants (every WP, no exceptions)

Product behaviour is identical in Part A. A WP is done only when its own cheap check passes. The walks, the checkers, and the 236-suite tier are proved once, in WP11, not before.

1. No suite is retired. No suite is added in Part A. Run count stays **236** until WP9, then **237**.
2. The four `known-red` manifests stay `known-red`: `run_rung01_replan12_pick.gd`, `run_rung01_replan3_timeline.gd`, `run_rung01_replan_input.gd`, `run_rung01_sketch_tests.gd`. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.
3. Save files and wire formats do not change: `.sxp` keys, bridge command names and reply keys, automation ids (`sweep:Boss`, `sweep:Ok`, `finish:Draft`, `finish:DraftAngle`, `finish:Op`, `finish:End`, `finish:Distance`, `finish:Extrude`, `menu:TemporaryAxes`, `rail:Arc`, variant Tangent / Three Point, `variant:Circular` and the rest of rungs 1–5). Do not add or remove a bridge field.
4. Status texts the rows pin stay byte-identical, including `Select a profile sketch and a path sketch`, `Draft angle too large`, `Tangent Arc: radius must be positive`, `Horizontal needs two endpoints`, and the pinned New sentence.
5. `check_rung06.py` stage names, the `N/N passed` lines, and `PART` / `VOLUMES` values stay. `check_rung01.py`–`check_rung05.py` are not edited.
6. Never commit `.webm`, `.mp4`, `.avi`, `.mov`, or `.vtt` on this cleanup branch. The poster PNG is the only binary Part B commits here. WebM/VTT go to `cursor/demo-artifacts-candlestick` (handoff, not for merge) and `/opt/cursor/artifacts/`.
7. Never pass `user://` or `res://` into GDExtension. `ProjectSettings.globalize_path` first.
8. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. A new suite is one new file in `suites.d/`. Do not edit `run_suites.sh` unless a WP names it (none does: dummy + one-starter already hold).
9. `tools/website_demos.py` `EXPECTED_COUNT` is **12**. Do **not** add a `website` object to the candlestick film. Do **not** edit `published-demos.json` or `demo-catalog.json`. Do **not** swap or drop a featured id. The curated homepage set is at its cap; that choice belongs to the website curator (PR #273). Candlestick is added as an enabled film only (available for a later curator commit, the way #272 added flanged_pipe before #273 featured it).

### Cheap checks (not the full pass)

| Check | Command | When |
|---|---|---|
| C-lint | `python3 tools/lint_suites.py` | WP1, and any WP that touches `suites.d/` or the lint |
| C-dry | `python3 tools/walk_rung01.py --dry-run`, same for `walk_rung02.py` … `walk_rung06.py`, diff against the WP1 files | WP7 |
| C-tools | `python3 tools/test_check_rung06.py && python3 tools/test_lint_suites.py && python3 tools/test_walk_registry.py` | WP2, WP3, WP7 |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<one suite>'` | the single suite a WP names |
| C-grep | the grep the WP names | dead-code and doc WPs |
| C-web | `python3 tools/website_demos.py check` and `scripts/sx-check-website-demos --offline` | WP8, WP10 |

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call. Godot is `tools/godot/godot` 4.7-stable. Do not start the GUI app. Do not call `make test`, `make test-godot`, `confirm_all.sh`, or any `walk_rung0N.py` without `--dry-run` before WP11.

### Protected pins

- Rung-1 A15 still requires its fifteen banner floors and `known-red == 4`. Do not edit those literals.
- Rung-2 A25, rung-3 A26, rung-4 A21, rung-5 A25, and rung-6 A36 keep the clause names `kernel`, `godot`, `lint`, `unit`, `registry`, `errors`. They read logs. They do not gain a second launcher.
- `suites.baseline` is a ratchet. A new `.gd` needs its `.uid` (`make import` is allowed in WP8/WP9 for the new film files; do not commit `game/.godot/`). A deleted `.gd` takes its `.uid`.
- `WalkUI06.STAGE_FILE` and the locked rim constants (`R60_TAN`, `R12_BULGE`, `R12_CLIP`, `BASE_END`) stay in the walk. Do not invent a shared JSON for those rows.
- Pixel suites stay on dummy. Do not add `render=viewport`.

### Rules for the BUILD agent

- One commit per WP: `Post-rung-6 cleanup WP<n>: <title>`. Push after each commit. Do not open a PR.
- **Revert rule.** If a WP's cheap check is red after two honest attempts, `git revert` that commit, name the failing check in `docs/plan/roadmap.md` §12, append the WP to §12, and continue. Never loosen a check, raise a timeout, drop a `--only`, or edit a tier to get green.
- **★ WPs.** WP6 and WP7. Record `date` in the WP1 commit message. Start a ★ WP only after WP1–WP5 are green and fewer than 4 hours have passed since WP1. Otherwise park the whole WP in §12 and go to Part B. A skipped ★ WP is not started.
- No new third-party dependency. No comments that narrate the edit.
- Design rule: a new branch is a row in a table the file already has, or a value object, not another `if` on a string kind. A new file starts with a two-line comment that says what it owns.

## Libraries considered

| Candidate | Decision | Why |
|---|---|---|
| Godot `--rendering-driver dummy` vs headless Forward+ (lavapipe) | **already the default** (post-rung-4 WP3) | object-model/bridge tests never read pixels. Do not reopen `render=viewport` |
| Existing `FilmSteps` / `FilmHarness` / `SxChecker` / `HexKeyFixture` / `PipeFixture` / `Tutor1Fixture` | **use** (WP3, WP5, WP8, WP9) | hexkey / tutor1 / flanged_pipe already proved the shape |
| C++ `struct` POLICY like `FeatureMirror` in `ops_transform.cpp` | **use** (WP6) | named constants + helpers replace the WP16 lambdas; no new library |
| Python `dataclasses` | **keep** | no new library |
| `trimesh`, `pytest`, `vulture`, a new test framework | **no** | `unittest` and `numpy` already run. The oracle checkers stay |

## Decisions (final)

1. Part A adds no suite and retires none. `lint_suites: 240 suites ok (79 ci, 157 full, 4 known-red)` through WP8. WP9 adds `film_candlestick_tests` at `tier=full`: **241** suites (`79 ci`, `158 full`, `4 known-red`), **237 run, 0 failed**.
2. A suite script is started by `run_suites.sh` only. `run_film_manifest_smoke.gd` does not execute a film id that has `packaging/ci/suites.d/film_<id>_tests.suite`. Today that is `ubc_wrench`, `lesson2_box`, `tutor1`, `hexkey`, `flanged_pipe`. After WP9 it is also `candlestick`. The dedicated suite is the only starter of that film script. Smoke still runs every other enabled film once.
3. Dummy stays the starter. `render=viewport` stays parked. Do not edit `run_suites.sh`.
4. `tools/confirm_all.sh` is the only full pass (WP11). It already runs kernel, lints, unit tests, and `run_suites.sh` once, then the six walks with `SX_CONFIRM_DIR` set.
5. Suite millimetres come from `check_rung06.PART` via `SxChecker.run("rung06", ["params"])` (or a `CandlestickFixture.part()` that caches that JSON). Do not restate `220`, `20`, `10`, `60`, `150`, `35`, `30`, `25`, `15` as a second table in a suite. `VOLUMES` stays the volume source.
6. The film id is `candlestick`. It is click-only. The demo test may call the kernel and `SxChecker`. Follow flanged_pipe / hexkey: add the id to `ui_movie_manifest.json`; do **not** add a `website` object; do **not** edit `published-demos.json` or `demo-catalog.json`. This token cannot upload to Release `demo-movies`. Pending-publish commands name `solidexpress/solidexpress`. Push the rendered WebM/VTT to `origin/cursor/demo-artifacts-candlestick` (orphan handoff, same as `cursor/demo-artifacts-flanged-pipe`).
7. Test-speed rules already hold and stay: each test has exactly one starter, run in parallel by default, object-model/bridge tests that never read pixels run with the dummy renderer.

## Work packages

### WP1 — Clock and the lint line (no product code)

Goal: a recorded start time and proof the manifest count is the rung-6 bar, without running Godot.

Files: none in the tree. The commit message holds `start: <date -Is>`.

Change: run `date -Is` and `python3 tools/lint_suites.py`. Save `python3 tools/walk_rung01.py --dry-run` through `walk_rung06.py --dry-run` to `/tmp/sx-base/dry{1,2,3,4,5,6}.txt`. Expect the lint line `lint_suites: 240 suites ok (79 ci, 157 full, 4 known-red)`.

Expected delta: 0.

Check: C-lint matches that line. If it does not, stop. This plan assumes `24a8306` plus this cleanup file.

Revert: nothing was committed to the tree. If you made a commit by mistake, revert it.

### WP2 — Spent docs, the rung-6 status entry, dead symbols

Goal: the loop directory keeps the live contract, STATUS names rung 6, and two unreferenced symbols are gone.

Files / symbols:

- Delete `docs/loop/post-rung-05-cleanup.md` (this file replaces it; history: `git log -- docs/loop`). Keep `post-rung-05-result.md`.
- Keep `rung-06-plan.md`, `rung-06-result.md`, `rung-06-checklist.md`, `rung-06-prep.md` (the rung-6 plan cites the prep and frames).
- `docs/loop/README.md`: list what remains and say this file is deleted by the next cleanup.
- `docs/plan/STATUS.md`: add **Rung 6 — candlestick (PR #275)** above the Post-rung-5 entry. Shipped: tangent-arc constraints, two-point Horizontal, temp-axis snap + silhouette dim, real ellipse, sweep default fuse, circular spine, extrude-cut draft 15° inward, survey colours/glyphs/edges/hover/planes, 46-row walk, `check_rung06.py`. Bars: the table in `rung-06-result.md`. Suites **236 run + 4 known-red**. spine: arc.
- `docs/plan/roadmap.md`: append `## 12. Structural debt found after rung 6` (empty table with columns Item / What / Design / Why parked) and a Related bullet. First row, written now: pixel `render=viewport` still parked (§9 cap-colour miss); do not reopen it.
- Dead symbols, only if a re-run of the finders below still prints them: `SketchTempAxes.axis_uv` (`game/scripts/sketch_temp_axes.gd`), `SketchMode._shortest_exit` (`game/scripts/sketch_mode.gd`). Delete a helper only when its name's count is 1. Do not delete Godot overrides. `_face_exits` and `_exit_clear_of_labels` stay (parking uses them).

Change: `git rm` the spent doc. Grep the repo outside `.git` for that basename first; rewrite every inbound link to `rung-06-result.md` or `git log -- docs/loop`. Then STATUS and roadmap. Then the deletions.

Expected delta: about −360 lines of docs, −15 lines of code.

Check: C-grep finds no remaining path to `post-rung-05-cleanup.md` outside `.git`. C-tools. The GDScript finder prints none of the two names. C-lint still `240 suites ok`.

Revert: revert the commit if C-tools is red after two attempts. Doc deletions that already match the grep can stay only if the code deletion is what failed; in that case revert the whole commit anyway (one commit, one revert) and re-land the docs as a fresh commit with the same message plus `code deletions parked`.

Finders (from the repo root):

```python
# gdscript: print func names defined once under the rung-6 script list
import re, collections
from pathlib import Path
files = """game/scripts/sketch_ellipse.gd game/scripts/sketch_tangent_arc.gd
game/scripts/sketch_temp_axes.gd game/scripts/sketch_horizontal.gd
game/scripts/sweep_boss.gd game/scripts/ops_panel.gd
game/scripts/sketch_mode.gd game/scripts/automation_bridge.gd""".split()
text = {f: Path(f).read_text() for f in files if Path(f).exists()}
cnt = collections.Counter(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b",
    "\n".join(p.read_text(errors="ignore") for p in Path("game").rglob("*.gd"))))
engine = {"_ready","_process","_input","_gui_input","_draw","_init",
          "_get_minimum_size","_unhandled_key_input","_exit_tree","_can_drop_data"}
for f, src in text.items():
    for m in re.finditer(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\(", src, re.M):
        if m.group(1) not in engine and cnt[m.group(1)] == 1:
            print(f, m.group(1))
```

```python
# python: print walk/checker names defined once
import ast, glob, collections, re
files = glob.glob("tools/**/*.py", recursive=True)
src = {f: open(f).read() for f in files}
names = collections.Counter(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", "\n".join(src.values())))
for f in ("tools/walk/rung6/ui06.py", "tools/check_rung06.py", "tools/implicit_candlestick.py"):
    for n in ast.walk(ast.parse(src[f])):
        if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and names[n.name] == 1 and not n.name.startswith(("__", "row_")) and n.name != "main":
            print(f, n.name)
```

### WP3 — One candlestick fixture, one PART table

Goal: the six rung-6 suites stop each carrying a private boot. Kernel millimetres come from the checker. Byte-identical helpers live once.

Files / symbols:

- New `game/tests/lib/candlestick_fixture.gd` (`class_name CandlestickFixture`), same idea as `PipeFixture` / `HexKeyFixture`. Two-line header: the kernel-built candlestick the rung-6 suites share; click builders for the film land in WP5/WP8. It may call the kernel. It owns: `part()` (cached `SxChecker.run("rung06", ["params"])` JSON), `mm(key)`, `boot` (main.tscn into a `FilmContext`, status log, viewport size), `find_auto`, the kernel builders currently on `Rung06Part` (`add_revolve_profile`, `add_path`, `add_ellipse`) reading `PART` (`H`, `TOP_R`, `R10`, `PATH_Y`, `PATH_60`, `PATH_R150`, `ELLIPSE_MAJ` / `ELLIPSE_MIN` as half-axes). Move `_arc_through` with them.
- Delete `game/tests/lib/rung06_part.gd` and its `.uid` after callers move. Do not leave two `class_name`s for the same helper.
- Callers: all six `run_rung06_*.gd` delete a `_init` that is ratio ≥ 0.91 and call `CandlestickFixture.boot`. `run_rung06_draft.gd` and `run_rung06_sweep.gd` delete `_click_named` / `_pick_sketch` (byte-identical) in favour of fixture methods (same bodies). `run_rung06_horizontal_points.gd` / `run_rung06_tangent_arc.gd` share `_last_arc`. `run_rung06_refs.gd` / `run_rung06_tangent_arc.gd` share `_line`. `run_rung06_ellipse.gd` / `run_rung06_tangent_arc.gd` share `_line_count`. Click-built sequences that are not identical stay in the suite that owns them.
- Dimensions in the kernel builder and remaining hardcoded `220` / `20` / `35` / `15` in those builders read `CandlestickFixture.mm(...)`. Do not type them as a second table.

Change: where two copies differ, the difference is a parameter (viewport size, status sink, which case). Where they differ in behaviour, leave both and name the pair in the commit message. Do not change a check string.

Expected delta: about −120 net (new file ~200, deleted copies ~320).

Check: C-tools (`test_check_rung06.py` still green). C-one `--only 'rung06_sweep.suite'` and `--only 'rung06_draft.suite'`. Their `N checks, 0 failures` lines match a one-line capture you take at the start of the WP, before the edit (`--only` once, save the line, then edit).

Revert: if either line changes or the suite is red after two attempts, revert the whole WP.

### WP4 — BooleanTarget, FaceLabelPark, leftover Smart Dim as tables

Goal: the WP16 special-case fixes in GDScript become a table or a value object. Behaviour is identical. WalkChrome’s dim/path click keeps (`clear_sketch_selection`, `frame_clickable`) already shipped in post-rung-5 / rung-6 WP16 — do not move them; they are the abstraction.

Files / symbols:

- New `game/scripts/boolean_target.gd` (`class_name BooleanTarget`). Two-line header: Cut/fuse target resolution order. `POLICY` is an ordered array of keys `session` → `support_host` → `host_face` → `sole_body`. `resolve(sm)` is today’s `_boolean_target_fid` / `_sole_body_feature` body. `sketch_mode.gd` `_boolean_target_fid` becomes a one-line call. Delete `_sole_body_feature` once its only caller is this helper (inlined into `resolve`).
- New `game/scripts/face_label_park.gd` (`class_name FaceLabelPark`). Two-line header: host-face dim labels take the shortest screen-edge exit whose plate misses parked labels. Owns `_face_exits` / `_exit_clear_of_labels` (move them). `SketchMode._park_labels_outside_host_face` calls it. `_shortest_exit` is already deleted in WP2; do not revive it.
- `sketch_mode.gd` `set_tool`: replace the CONVERT/OFFSET/SMART_DIM leftover-clear `if`s with a small table `ARM_CLEAR` keyed by tool (`always` / `if_one` / `keep`). CONVERT and OFFSET are `always`. SMART_DIM is `if_one` (two-circle selection stays for the chip row). No other tool gains a row. Evidence strings stay.

Change: no new branch on a string kind outside those tables. Do not change when a cut finds a target, which exit a flange label takes, or which leftover selection Smart Dim drops.

Expected delta: about +120 / −80.

Check: C-one `--only 'rung06_draft.suite'` with the same check count as the start of the WP (sole-body / host-face cut). C-one `--only 'rung05_csp.suite'` (host-face Ø130/Ø10/94 parking) with the same check count. If you did not edit a parking caller’s assertions, the count must match a capture taken before the edit.

Revert: red or a changed check count → revert.

### WP5 — FilmSteps for tangent arc, 3-point, ellipse, sweep, draft cut (no film yet)

Goal: the click sequences the film will need, and that `run_rung06_tangent_arc.gd` / `run_rung06_ellipse.gd` / `run_rung06_draft.gd` already duplicate, live once. Suites call them. No new film file.

Files / symbols: `game/tests/lib/film_steps.gd`. Callers: the rung-6 suites only where the body is already a click-through of visible controls. `CandlestickFixture` may grow thin wrappers that call these.

Change: new click-only statics, two-line comment each:

- `pick_variant(ctx, label)` — click the visible VariantBar chip (`Tangent`, `Three Point`, …) or `sx_auto` `variant:<id>`. Hidden → `FilmUI._fail`.
- `tangent_arc(ctx, start, end)` — rail Arc, variant Tangent, click `start` (host endpoint), click `end`. Reuse `press_rail` / `click_uv`. Snap-off for the end click is allowed (walk: a 220 mm fit must not swallow the R10 chord) via the Snap rail button if it is visible; if the button is hidden, skip snap and still click.
- `three_point_arc(ctx, p1, bulge, p3)` — rail Arc, variant Three Point, three clicks.
- `ellipse3(ctx, centre, major, minor)` — rail Ellipse, three clicks. `FilmUI.draw_ellipse` already does centre/major/minor; call it (or press_rail + click_uv) so the film does not grow a second 3-click path. Do not revive a 2-click box ellipse.
- `swept_boss(ctx, profile_fid, path_fid)` — `sweep:Boss` (or the visible Swept Boss control), click the profile pad, click the path pad, `sweep:Ok`. Hidden → fail. HexKeyFixture.sweep is the shape; lift the click path, leave hex-key millimetres in HexKeyFixture.
- `draft_cut(ctx, distance, angle)` — finish Op Cut, End Blind, Distance `distance`, Draft On, DraftAngle `angle`, Extrude. Controls: `finish:Op`, `finish:End`, `finish:Distance`, `finish:Draft`, `finish:DraftAngle`, `finish:Extrude`. Missing → fail.

If a suite’s current path is not a visible-control click (kernel `add_arc` / `finish_revolve` / `sm.sketch.add_ellipse`), leave that suite’s helper and name it in the commit message. Do not teach the film a private call by extracting one. Do not change a check string. `FilmUI.apply_revolve` already exists — do not duplicate it.

Expected delta: about +160 / −40.

Check: C-one `--only 'rung06_tangent_arc.suite'` with the same check count as the start of the WP. C-one `--only 'rung06_ellipse.suite'` only if you edited it; otherwise skip.

Revert: red or a changed check count → revert.

### WP6 ★ — SweepFuse.POLICY (fuse by volume)

Goal: the WP16 fuse lambdas in `ops_sweep.cpp` become a named `struct SweepFuse` with POLICY constants, same shape as `FeatureMirror` in `ops_transform.cpp`. Behaviour is identical.

Files: `sxkernel/src/features/ops_sweep.cpp` only (do not add a .cpp; CMake stays). Callers of `keeps_target` / `fuse_ribbon` / the xmax-then-volume pick become `SweepFuse::…`.

Change:

```
struct SweepFuse {
    static constexpr double KEEP_RATIO = 0.90;   // merged volume vs target
    static constexpr double XMAX_TIE_MM = 0.5;   // ribbons within this of best +X
    static constexpr double MIN_VOLUME = 1.0e-3;
    static bool usable(const TopoDS_Shape&);
    static bool keeps_target(const TopoDS_Shape& body, const TopoDS_Shape& merged);
    static TopoDS_Shape pick_xmax_then_volume(const std::vector<TopoDS_Shape>&);
    static TopoDS_Shape fuse_ribbon(const TopoDS_Shape& body, const TopoDS_Shape& ribbon);
};
```

Move the existing lambda bodies unchanged. Fuzzy list `{1.0e-4, 1.0e-3, 0.05}` stays a constant on the struct. Frenet-on / Frenet-off / polyline trial order stays. Hex-key empty-part `op == "new"` path is untouched. Do not widen `KEEP_RATIO` or `XMAX_TIE_MM`. Do not change heal/unify.

Expected delta: about +40 / −40 (move, not new behaviour).

Check: C-one `--only 'rung06_sweep.suite'` with the same check count as the start of the WP. Then C-one `--only 'rung04_sweep.suite'` (hex key still one new body). Catch2 is not re-run here (WP11).

Revert: either suite red or a changed check count → revert the whole ★ WP and park it in §12. Do not ship a partial extract.

### WP7 ★ — WalkUI06 split into profile / path / cut

Goal: `WalkUI06` is no longer a 1078-line pile. Gesture groups live in modules the class mixes in. Dry-run output is byte-identical.

Files: `tools/walk/rung6/ui06.py` (class, `STAGE_FILE`, rim constants, `part` / `mm`). New `tools/walk/rung6/profile.py` (tangent/3-point/connecting rim/stems/clip). New `tools/walk/rung6/path.py` (temp axes, 60 / R150 / hook, silhouette 10). New `tools/walk/rung6/cut.py` (top-disc pick, draft cut, sweep arm). Mixins or functions that take `self`. Each new file starts with a two-line comment that says what it owns.

Change: move methods; do not rewrite click sequences. `mm` stays a one-line `PART` lookup. Do not move chrome-owned helpers. Evidence strings stay.

Expected delta: about 0 net (move), ui06.py under ~250 lines.

Check: C-dry diffs empty against `/tmp/sx-base/dry{1,2,3,4,5,6}.txt`. C-tools (`test_walk_registry.py`).

Revert: any dry-run diff → revert the whole ★ WP and park it in §12. Do not ship a partial split.

## Part B — Candlestick demo

Goal: a click-driven film of the rung-6 part (SolidWorks Tutorials – Revolve & Sweep, m7GuVfPN164), a headless demo test that fails when the film's end state is not that part, a video from `scripts/sx-movies`, a poster, a how-to, and the website wiring the publish script already implements — **without** changing the curated 12. Same shape as `flanged_pipe` (#272) before the curator featured it (#273). Binding rules: [`landing-protocol.md`](../plan/landing-protocol.md), `.cursor/rules/gdscript-click-driven-tests.mdc`, `.cursor/rules/website-published-demo-movies.mdc`. Current publish flow: `scripts/sx-movies one <id>` then `scripts/sx-publish-demo-movies` against Release `demo-movies` on **`solidexpress/solidexpress`**. Curated homepage set stays 12. Agent WebMs go to `cursor/demo-artifacts-<id>` (flanged_pipe: `origin/cursor/demo-artifacts-flanged-pipe`).

The story is the walk, compressed (`tools/walk/rung6/rows06_chunk*.py` and the step table in `rung-06-plan.md`): Front profile 20 / 220 / 90 + Tangent Arc R10 + 3-point R20 + R60 / R12.50, Revolve Blind 360 about the 220 line, Front path 60 + R150 + R20 hook (not a line) sitting 10 mm above the base, Right ellipse 35×10 coincident to the path start, Swept Boss fuse Follow path, top-disc Ø30 Cut Blind 25 draft 15° inward, showcase. No fillet.

### WP8 — Film `candlestick`, manifest, how-to

Goal: an enabled film the smoke skip does not execute (WP9 adds the suite that owns it; until that file exists, smoke would run it, so WP8 and WP9 are two commits but WP8's check is manifest load only, not a full smoke of every film).

Files:

- `game/tests/films/film_candlestick.gd` (`extends RefCounted`, `run_film(ctx)`), following `film_flanged_pipe.gd` / `film_hexkey.gd`. `FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))`, `movie_toast`, then beats: "Sketch the Front profile and revolve 360", "Path on Front: 60, R150, R20 hook, dim 10", "Ellipse 35×10 on Right, coincident to the path", "Swept Boss, fuse onto the revolve", "Cut Ø30 Blind 25, draft 15° inward". Then `ctx.camera.showcase_smooth`.
- Click path lives in `CandlestickFixture` (add the click builders next to the kernel ones) and the WP5 `FilmSteps` helpers. `FilmUI`, `FilmSteps`, `SxInput` only. A missing control fails the film. No `set_tool`, `exit_sketch` private, `graph_add_sweep`, `sm._set_selected`, kernel `add_ellipse` / `add_arc`, or other private call.
- Millimetres from `CandlestickFixture.mm(...)`. Do not type `220` / `35` / `15` in the film.
- If a beat has no visible control, `FilmUI._fail` and stop.
- Length aim ≤ 120 s at 30 fps. `quit_after` 4800 (ceiling only), same as hexkey / flanged_pipe. Raise to 6000 in this commit only if a local timing pass shows the caption timeline exceeding 4800 frames; say so in the commit message.
- Append to `game/tests/ui_movie_manifest.json`: `{"id": "candlestick", "title": "Candlestick: revolve, sweep, drafted cut", "script": "res://tests/films/film_candlestick.gd", "enabled": true, "quit_after": 4800, "blurb": "Revolve a Front profile, sweep an ellipse along an arc path, cut a 15° drafted hole."}`. No `website` object. Run `scripts/sx-sync-website` (Pages checkout absent exits 0). The two manifest JSON files must match (this also repairs the stale website copy left after #273).
- `docs/howto/candlestick.md`, numbered clicks, same shape as `docs/howto/flanged-pipe.md`. End with `Film: candlestick.` and a Pending publish block that quotes the commands in WP10. Do not tell the curator to bump `EXPECTED_COUNT` or swap a featured card.

Expected delta: about +450 (film + steps + how-to).

Check: `python3 -c 'import json; json.load(open("game/tests/ui_movie_manifest.json")); json.load(open("website/assets/ui_movie_manifest.json"))'` and `diff` of those two files is empty. C-web (`python3 tools/website_demos.py check` still 12 curated; `scripts/sx-check-website-demos --offline` passes). Do not run the film yet (WP9 does, once).

Revert: if the manifest diff or the offline website check is red after two attempts, revert. Do not hand-edit `website/features.html`. Do not bump `EXPECTED_COUNT`. Do not add a `website` object.

### WP9 — Demo test `run_film_candlestick_tests.gd`

Goal: one suite owns the film. It fails when the end state is not the checked part.

Files:

- `game/tests/run_film_candlestick_tests.gd` (`extends "res://tests/lib/sx_suite.gd"`, banner `print("film candlestick")`). `FilmHarness.boot(self, Vector2i(1600, 900))`, `manifest_entry("candlestick")`, `load_film`, `await film.run_film(ctx)`. Then, as a validation test: `FilmUI.fail_count == 0`; one body; bbox 304.1 × 220 × 224.0 within 0.2 (`PART` size from `BBOX_MAX - BBOX_MIN` via `SxChecker.run("rung06", ["params"])`, do not type a second copy of the millimetres); handle on +X (`xmax ≥ 180`); `last_graph_error` empty.
- Export with `doc.export_3mf` on a `ProjectSettings.globalize_path` temp path. `SxChecker.run("rung06", ["final", path])` exit 0 and the text contains `7/7 passed`. No hard-coded volume.
- Feature names: equal to the list this film's timeline actually produces. Capture it from the first green run of this suite and pin that string in the test in the same commit (the way `run_film_flanged_pipe_tests.gd` pins `FEATURES`). Do not invent the list in advance. Order is part of the pin.
- `packaging/ci/suites.d/film_candlestick_tests.suite`: `script=tests/run_film_candlestick_tests.gd`, `tier=full`, `timeout=480`. No `render=` key (the film does not call `get_texture`; dummy is correct). Commit the `.uid`. If C-one hits the timeout twice because the film is long, raise to 600 in the same WP (ceiling, not a loosened assertion) and say so.

Expected delta: about +150, plus one suite file.

Check: C-one `--only 'film_candlestick_tests.suite'` passes. C-lint prints `241 suites ok (79 ci, 158 full, 4 known-red)`. C-one `--only 'film_manifest_smoke.suite'` prints `- smoke skip candlestick` and does not print `- smoke candlestick`.

Revert: if the suite is red after two attempts, revert WP9 and WP8 (the film has no owner otherwise) and park Part B in §12. Do not weaken `7/7` or the bbox.

### WP10 — Render, poster, artifacts branch, publish note

Goal: a video and a poster from the existing movie scripts, a handoff branch with the WebM/VTT, and a written record that this token cannot put the video on the Release. Featured set unchanged.

Files on **this** branch: `website/assets/screenshots/candlestick.png` (the only binary). `docs/plan/STATUS.md` Pending publish under the Post-rung-6 cleanup entry you add in this commit (short: what WP8–WP9 added, suites **237 run + 4 known-red**, the token limitation, artifacts branch). `docs/howto/candlestick.md` already has the commands.

Change:

1. Calibrate with `scripts/sx-movies one precision_plate`, then `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-movies one candlestick` under `tmux` (`DISPLAY=:1`). If the wall-time estimate from the plate (plate seconds × candlestick duration / plate duration) exceeds 90 minutes, rerun with `SX_MOVIES_FPS=24`.
2. `ffprobe`: VP9, 1600×900, container duration within 10% of the caption timeline. Copy `candlestick.webm` and `candlestick.vtt` to `/opt/cursor/artifacts/`. Do not `git add` them on this branch.
3. Poster: the last picture of the **video track**, not a seek that falls past it. `lesson2_box` / `tutor1` / `flanged_pipe` dropped duplicate frames, so the video track ended before the container and `ffmpeg -sseof -0.1` on the muxed file missed the picture. Use the video-track end (`ffprobe -show_entries stream=duration` vs format duration) and grab that frame into `website/assets/screenshots/candlestick.png`.
4. Handoff branch, same as `origin/cursor/demo-artifacts-flanged-pipe`: orphan `cursor/demo-artifacts-candlestick` with `candlestick.webm`, `candlestick.vtt`, and a README that quotes the upload commands. Push it. Switch back to this cleanup branch. That branch is not for merge.
5. `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-publish-demo-movies --dry-run candlestick`. Keep the output in the STATUS note. `--feature` is parsed and unused; do not pass it as a substitute for the id. Do not pass `--feature` in a way that would rewrite the curated JSON.
6. `gh release view demo-movies -R solidexpress/solidexpress --json assets --jq '.assets[].name'`.
   - If `candlestick.webm` is listed (unexpected): still **do not** add a `website` object and **do not** bump `EXPECTED_COUNT`. STATUS says the curator may feature it later. The user forbade changing the featured set.
   - If it is not listed (expected; this token has no push on the Release): do not add `candlestick` to `published-demos.json` or `demo-catalog.json`. Do not add a `website` object. STATUS Pending publish is exactly:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber candlestick.webm candlestick.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies candlestick
```

A person who can upload then decides whether to feature it (swap, not grow past 12). `website/features.html` renders `demo-catalog.json` ∩ the live Release list. Do not hand-write a card.

Expected delta: one PNG plus a short STATUS section. Artifacts branch is a separate push.

Check: C-web still 12 curated. `git status` on this branch shows no `.webm` or `.vtt`.

Revert: if the offline check fails because the poster or the manifest is wrong, fix the poster path or revert the website file. Do not delete the film to go green. Do not leave WebM on this branch.

### WP11 — The single full pass

Goal: one run that builds, checks, and walks. Counts match the rung-6 result, plus the new film suite.

Command (this is the pass; do not also run `make test` or a second `run_suites.sh`):

```bash
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export OCCT_PREFIX=/opt/occt-8.0.1
tools/confirm_all.sh
```

`confirm_all.sh` builds, imports, runs kernel + lints + `test_check_rung02.py` … `test_check_rung06.py` + `test_walk_registry.py` + `run_suites.sh --tier full --keep-going` once, then the six walks on `:21` … `:26` reading `SX_CONFIRM_DIR`.

Required lines in its summary:

| Bar | Count |
|---|---|
| Rung 6 walk | 46 pass, 0 fail |
| `check_rung06` | final 7/7 |
| Rung 5 walk | 36 pass, 0 fail |
| `check_rung05` | final 10/10 |
| Rung 1 walk | 77 pass, 0 fail |
| Rung 1 checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7 |
| Rung 2 walk | 44 pass, 0 fail |
| `check_rung02` | final-60 16/16, final-65 16/16 |
| Rung 3 walk | 46 pass, 0 fail |
| `check_rung03` | final 29/29 |
| Rung 4 walk | 32 pass, 0 fail |
| `check_rung04` | final 5/5 |
| Headless | **237 run, 0 failed** |
| Lint | `241 suites ok (79 ci, 158 full, 4 known-red)` |
| Film | `film_candlestick_tests` is among the 237 and is not failed |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 237.

If Part B was reverted, the headless count stays **236** and there is no `candlestick` film; say so and do not invent the video. If a ★ WP was parked, say so; the bars do not change.

This WP has no product commit unless a count is wrong and the fix is a one-line correction you can justify from a WP above. A red bar is a report, not a silent edit. Do not wait for CI.

Write `docs/loop/post-rung-06-result.md` with the table, shipped/parked WPs, and the pending upload line. Push that commit.

## Acceptance

WP11's summary shows the table above (or the reduced table if a WP was reverted and §12 says so). `make` was not run a second time beside `confirm_all.sh`. No video file is in this branch’s git. `candlestick` is absent from `published-demos.json` and `demo-catalog.json`. `EXPECTED_COUNT` is still 12.

## Final report (keep it short)

Branch name. One line per WP: number, title, done or parked, net lines. Then the WP11 counts (walks 77/77, 44/44, 46/46, 32/32, 36/36, 46/46, `check_rung05` 10/10, `check_rung06` 7/7, headless 237 or 236) and the pending `gh release upload` line if the WebM was not on the Release. Head sha. No other prose.
