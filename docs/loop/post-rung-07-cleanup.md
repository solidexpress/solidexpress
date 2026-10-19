# Post-rung-07 cleanup — layering, one fixture, then the combination-spanner demo film

Status: Part B parked (WP8–WP10). WP1–WP7 shipped. Result: [`post-rung-07-result.md`](post-rung-07-result.md) (written in WP11). Headless **244**.

Parked: C-one `film_spanner_tests.suite` stayed red after three honest attempts (S marking menu, off-screen handle clicks, R30 pick hit the C ellipse / 204 mm handle edge). WP8 and WP9 reverted. WP10 not started. See [`roadmap.md`](../plan/roadmap.md) §13. Baseline: this branch `4d16894` (`Rung 7: combination spanner`, PR #280; `git log 628ca50..4d16894` is that one squash). Rung 7 walk 46/46. `check_rung07` final 8/8. Rung 1 walk 77/77. Rung 2 44/44. Rung 3 46/46. Rung 4 32/32. Rung 5 36/36. Rung 6 46/46. `check_rung05` final 10/10. `check_rung06` final 7/7. Headless: 244 run, 0 failed. Manifests on this sha: **248** (`82 ci`, `162 full`, `4 known-red`), so the tier runs `82 + 162 = 244`. Checklists: [`rung-07-plan.md`](rung-07-plan.md), [`rung-07-result.md`](rung-07-result.md), [`rung-07-failing.md`](rung-07-failing.md). Previous cleanup, same shape: [`post-rung-06-result.md`](post-rung-06-result.md) (PR #278 Part A + #279 candlestick film). Website curator featured tutor1/hexkey/flanged_pipe (PR #273) without growing the 12-card cap. Candlestick is available, not featured.

**Prompt for ONE BUILD agent.** Execute the work packages below in order, one commit per WP, on the branch you were given. Push that branch. Do not open a PR. This file is the only prompt. Part A (WP1–WP5, and WP6–WP7 only when the ★ rule says so) does not change product behaviour. Part B (WP8–WP10) is the combination-spanner film, its test, the rendered video, the poster, the how-to, and the website wiring. Part B is not optional and outranks every ★ WP. WP11 is the only full test pass. Do not build, walk, or run the tier before WP11 except for the cheap check named in that WP.

## Why this shape

Rung 7 landed green as one squash. The new tools already use tables in the places the rung plan named (`check_rung07.PART`, `SpannerFixture.part`/`mm`, `FeatureMirror.POLICY`, walk `STAGE_FILE`). Dummy renderer, parallel jobs, per-job `HOME`, WalkChrome shared gestures, FilmSteps (ellipse3 / three_point / convert / offset / feature_mirror / fillet), and smoke-skip of dedicated film suites already landed in post-rung-4/5/6 and stay. What is still a pile is the late special-case fixes (neck fillet AABB clip / undo-if-Y-balloons, MakeFillet-first ordering for Convert, jaw-tip coincident and weld), a 1105-line `WalkUI07`, seven suites that clone `_boot`/`_world`/`_x_jaw` and restate millimetres, four dead symbols, no STATUS entry, and spent loop docs. Measured on `4d16894`:

| Fact | Number | Source |
|---|---|---|
| Walk UI | `WalkUI07` is 1105 lines, 84 methods. Shared names vs `WalkUI06`: 12 (`_arm_sketch_tool`, `_click_sketch_geom`, `_set_snap`, `constraint_types`, `mm`, `sketch_on_datum` byte-identical or near; `part` ratio 0.987, checker filename only). vs `WalkChrome`: 2 overrides (`part`, `sketch_on_datum`). Chrome already owns `frame_clickable`, `show_sketch_point`, wait helpers. `_frame_uv` is a one-line `frame_clickable` wrapper (13 call sites) | `tools/walk/rung7/ui07.py`, `tools/walk/chrome.py` |
| Rung-7 suites copy a boot | seven scripts, 1258 lines. `_boot` ×3 (trim / coincident / mirror). `_world`/`_x_jaw`/`DEG:=17` ×2 (trim / coincident; restates 12.5 / 27.5 / 20 / 15). `_line` ×2. `_count_type` ×3. `PLATE_X := 240.0` restates `CENTER`. boss / offset / mirror_fillet / mirror_plane already call `SpannerFixture.boot` | `game/tests/run_rung07_*.gd` |
| PART restated | no `Rung07Part`. `SpannerFixture.part()` caches `SxChecker.run("rung07", ["params"])`. Walk `mm` reads `check_rung07.PART`. Suites that still type 17 / 12.5 / 25 / 240 are a second table | `game/tests/lib/spanner_fixture.gd`, `tools/check_rung07.py` `PART` |
| Late special cases | (1) Neck fillet AABB clip (`aabb_of` / `clip_to_body_aabb` / `clip_result_to_start_aabb`) plus walk `fillet_z_edges` undo-if-Y-balloons. (2) MakeFillet-first then void-wedge fallback so Convert sees circular arcs (A28). (3) Jaw tip coincident: upper → `ellipse_major()`, lower → −Y steep tip; `weld_open_profile` before Midplane (N2 open at −24.9, 5.4). (4) Frame pumps: already `WalkChrome.frame_clickable`. (5) 3MF wait/retry: already `WalkGestures.export_3mf` (3 attempts, 20 s poll). (6) Mid-chunk `--from`: already `checkpoint.resolve_open_parts` + `ckpts/<prev>.sxp` | `sxkernel/src/features/ops_dress.cpp`, `tools/walk/rung7/ui07.py`, `tools/walk/gestures.py`, `tools/walk/checkpoint.py` |
| Dead symbols | GD: `SpannerFixture.set_handle_construction`, `contour_at` (count 1). Py: `WalkUI07._contour_note`, `check_all_contours` (defined, never called) | finder in WP2 |
| One starter, dummy by default | already true. `run_suites.sh` default `--jobs nproc`, per-job `HOME`, `--rendering-driver dummy` unless `render=viewport`. Smoke skips `film_<id>_tests.suite`. Pixel `render=viewport` stays parked | `packaging/ci/run_suites.sh`, `game/tests/run_film_manifest_smoke.gd` |
| Same film, two starters | dedicated suites own `ubc_wrench`, `lesson2_box`, `tutor1`, `hexkey`, `flanged_pipe`, `candlestick`. A spanner suite would make a seventh double unless smoke skips it | `packaging/ci/suites.d/film_*_tests.suite` |
| Spent loop docs | the post-rung-6 cleanup plan (this file replaces it; history: `git log -- docs/loop`). Keep the live contracts (rung plans/results, post-rung-03/04/05/06 results, this file) | `docs/loop/README.md` |
| No rung-7 status entry | `docs/plan/STATUS.md` starts at Post-rung-6 / Candlestick film / Rung 6. The rung PR was told not to edit it | `STATUS.md` |

Already the abstraction — do not re-table: `WalkChrome.frame_clickable`, `WalkGestures.export_3mf` retry, `checkpoint.resolve_open_parts` / `--from`, `SpannerFixture.part`/`mm` for callers that already use it, `FilmSteps.ellipse3` / `three_point_arc` / `convert_edge` / `offset_rim` / `feature_mirror` / `fillet_at`. Do not reverse MakeFillet-first. Do not widen AABB slack or `RADIUS_VS_THICK`.

Not in this pass (already parked, or a second painter that is doing a different job): splitting `SketchMode` / `ViewportInteraction` ([roadmap.md §7](../plan/roadmap.md)), the §8–§12 rows, pixel `render=viewport`, CommandBus, Jaw template. `SketchEllipse.SPEC`, `SweepFuse.POLICY`, `FeatureMirror.POLICY`, and WalkChrome lifts already exist — do not re-table them. Do not re-copy `mm` / `part` onto chrome (one-line wrappers that pass the checker script).

## Invariants (every WP, no exceptions)

Product behaviour is identical in Part A. A WP is done only when its own cheap check passes. The walks, the checkers, and the 244-suite tier are proved once, in WP11, not before.

1. No suite is retired. No suite is added in Part A. Run count stays **244** until WP9, then **245**.
2. The four `known-red` manifests stay `known-red`: `run_rung01_replan12_pick.gd`, `run_rung01_replan3_timeline.gd`, `run_rung01_replan_input.gd`, `run_rung01_sketch_tests.gd`. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.
3. Save files and wire formats do not change: `.sxp` keys, bridge command names and reply keys, automation ids (`finish:Op`, `finish:End`, `finish:Distance`, `finish:Extrude`, `rail:Convert`, `chip:Fillet`, variant Three Point / Centerline / Inscribed, and the rest of rungs 1–6). Do not add or remove a bridge field.
4. Status texts the rows pin stay byte-identical, including `Offset: distance must be greater than 0`, `Select a closed profile`, `no selected contour`, `fillet failed`, and the pinned New sentence.
5. `check_rung07.py` stage names, the `N/N passed` lines, and `PART` / `VOLUMES` values stay. `check_rung01.py`–`check_rung06.py` are not edited.
6. Never commit `.webm`, `.mp4`, `.avi`, `.mov`, or `.vtt` on this cleanup branch. The poster PNG is the only binary Part B commits here. WebM/VTT go to `cursor/demo-artifacts-spanner` (handoff, not for merge) and `/opt/cursor/artifacts/`.
7. Never pass `user://` or `res://` into GDExtension. `ProjectSettings.globalize_path` first.
8. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. A new suite is one new file in `suites.d/`. Do not edit `run_suites.sh` unless a WP names it (none does: dummy + one-starter already hold).
9. `tools/website_demos.py` `EXPECTED_COUNT` is **12**. Do **not** add a `website` object to the spanner film. Do **not** edit `published-demos.json` or `demo-catalog.json`. Do **not** swap or drop a featured id. The curated homepage set is at its cap; that choice belongs to the website curator (PR #273). Spanner is added as an enabled film only (available for a later curator commit, the way #279 added candlestick).

### Cheap checks (not the full pass)

| Check | Command | When |
|---|---|---|
| C-lint | `python3 tools/lint_suites.py` | WP1, and any WP that touches `suites.d/` or the lint |
| C-dry | `python3 tools/walk_rung01.py --dry-run`, same for `walk_rung02.py` … `walk_rung07.py`, diff against the WP1 files | WP7 |
| C-tools | `python3 tools/test_check_rung07.py && python3 tools/test_lint_suites.py && python3 tools/test_walk_registry.py` | WP2, WP3, WP7 |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<one suite>'` | the single suite a WP names |
| C-grep | the grep the WP names | dead-code and doc WPs |
| C-web | `python3 tools/website_demos.py check` and `scripts/sx-check-website-demos --offline` | WP8, WP10 |

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call. Godot is `tools/godot/godot` 4.7-stable. Do not start the GUI app. Do not call `make test`, `make test-godot`, `confirm_all.sh`, or any `walk_rung0N.py` without `--dry-run` before WP11.

Walks are resumable. When a later WP has to fix walk row N, rerun from N with `tools/walk_rung07.py --from N` and the restored checkpoint (`ckpts/<prev>.sxp`). Only the final pass (WP11) runs from row 1 with no restores.

### Protected pins

- Rung-1 A15 still requires its fifteen banner floors and `known-red == 4`. Do not edit those literals.
- Rung-2 A25, rung-3 A26, rung-4 A21, rung-5 A25, rung-6 A36, and rung-7 A37 keep the clause names `kernel`, `godot`, `lint`, `unit`, `registry`, `errors`. They read logs. They do not gain a second launcher.
- `suites.baseline` is a ratchet. A new `.gd` needs its `.uid` (`make import` is allowed in WP8/WP9 for the new film files; do not commit `game/.godot/`). A deleted `.gd` takes its `.uid`.
- `WalkUI07.STAGE_FILE` and the locked millimetres in `check_rung07.PART` stay. Do not invent a shared JSON for those rows. Handle-ellipse contacts `22.944` / `23.929` and ring chord `226.876` stay named constants next to `handle_xy`; do not type them as a second PART table.
- Pixel suites stay on dummy. Do not add `render=viewport`.
- Neck fillet try order stays MakeFillet → fuse-wedge (neck) → unify → fuse-wedge. AABB clip stays on neck results. Convert of R30/R20 must still emit `external arc`.

### Rules for the BUILD agent

- One commit per WP: `Post-rung-7 cleanup WP<n>: <title>`. Push after each commit. Do not open a PR. Push at least every 30 minutes even if a WP is still open (WIP commits are fine; the next WP commit can squash the WIP only if it has not been pushed — if it has, leave the WIP and continue).
- **Revert rule.** If a WP's cheap check is red after **three** honest attempts, `git revert` that commit (or restore the files), name the failing check in `docs/plan/roadmap.md` §13, append the WP to §13, note it in this file, and continue. Never loosen a check, raise a timeout except the WP9 ceiling, drop a `--only`, or edit a tier to get green.
- **★ WPs.** WP6 and WP7. Record `date` in the WP1 commit message. Start a ★ WP only after WP1–WP5 are green and fewer than 4 hours have passed since WP1. Otherwise park the whole WP in §13 and go to Part B. A skipped ★ WP is not started.
- No new third-party dependency. No comments that narrate the edit.
- Design rule: a new branch is a row in a table the file already has, or a value object, not another `if` on a string kind. A new file starts with a two-line comment that says what it owns.

## Libraries considered

| Candidate | Decision | Why |
|---|---|---|
| Godot `--rendering-driver dummy` vs headless Forward+ (lavapipe) | **already the default** (post-rung-4 WP3) | object-model/bridge tests never read pixels. Do not reopen `render=viewport` |
| Existing `FilmSteps` / `FilmHarness` / `SxChecker` / `SpannerFixture` / `PipeFixture` / `CandlestickFixture` | **use** (WP3, WP6, WP8, WP9) | hexkey / tutor1 / flanged_pipe / candlestick already proved the shape |
| C++ `struct` POLICY like `SweepFuse` / `FeatureMirror` | **use** (WP4) | named constants + helpers replace the AABB / MakeFillet lambdas; no new library |
| Python `dataclasses` | **keep** | no new library. `WeldPolicy` / `NeckRow` are small frozen dataclasses or module constants |
| `trimesh`, `pytest`, `vulture`, a new test framework | **no** | `unittest` and `numpy` already run. The oracle checkers stay |

## Decisions (final)

1. Part A adds no suite and retires none. `lint_suites: 248 suites ok (82 ci, 162 full, 4 known-red)` through WP8. WP9 adds `film_spanner_tests` at `tier=full`: **249** suites (`82 ci`, `163 full`, `4 known-red`), **245 run, 0 failed**.
2. A suite script is started by `run_suites.sh` only. `run_film_manifest_smoke.gd` does not execute a film id that has `packaging/ci/suites.d/film_<id>_tests.suite`. Today that is `ubc_wrench`, `lesson2_box`, `tutor1`, `hexkey`, `flanged_pipe`, `candlestick`. After WP9 it is also `spanner`. The dedicated suite is the only starter of that film script. Smoke still runs every other enabled film once.
3. Dummy stays the starter. `render=viewport` stays parked. Do not edit `run_suites.sh`.
4. `tools/confirm_all.sh` is the only full pass (WP11). It already runs kernel, lints, unit tests, and `run_suites.sh` once, then the seven walks with `SX_CONFIRM_DIR` set.
5. Suite millimetres come from `check_rung07.PART` via `SxChecker.run("rung07", ["params"])` (or `SpannerFixture.mm` / `deg()` that cache that JSON). Do not restate `17`, `55`, `50`, `12.5`, `20`, `15`, `33`, `25`, `240`, `10`, `6`, `30`, `5`, `1`, `3` as a second table in a suite. `VOLUMES` stays the volume source.
6. The film id is `spanner`. It is click-only. The demo test may call the kernel and `SxChecker`. Follow candlestick / flanged_pipe / hexkey: add the id to `ui_movie_manifest.json`; do **not** add a `website` object; do **not** edit `published-demos.json` or `demo-catalog.json`. This token cannot upload to Release `demo-movies`. Pending-publish commands name `solidexpress/solidexpress`. Push the rendered WebM/VTT to `origin/cursor/demo-artifacts-spanner` (orphan handoff, same as `cursor/demo-artifacts-candlestick`).
7. Test-speed rules already hold and stay: each test has exactly one starter, run in parallel by default, object-model/bridge tests that never read pixels run with the dummy renderer.

## Work packages

### WP1 — Clock and the lint line (no product code)

Goal: a recorded start time and proof the manifest count is the rung-7 bar, without running Godot.

Files: none in the tree. The commit message holds `start: <date -Is>`.

Change: run `date -Is` and `python3 tools/lint_suites.py`. Save `python3 tools/walk_rung01.py --dry-run` through `walk_rung07.py --dry-run` to `/tmp/sx-base/dry{1,2,3,4,5,6,7}.txt`. Expect the lint line `lint_suites: 248 suites ok (82 ci, 162 full, 4 known-red)`.

Expected delta: 0.

Check: C-lint matches that line. If it does not, stop. This plan assumes `4d16894` plus this cleanup file.

Revert: nothing was committed to the tree. If you made a commit by mistake, revert it.

### WP2 — Spent docs, the rung-7 status entry, dead symbols

Goal: the loop directory keeps the live contract, STATUS names rung 7, and four unreferenced symbols are gone.

Files / symbols:

- Delete the spent post-rung-6 cleanup plan (this file replaces it; history: `git log -- docs/loop`). Keep `post-rung-06-result.md`.
- Keep `rung-07-plan.md`, `rung-07-result.md`, `rung-07-failing.md`, `rung-07-checklist.md`, `rung-07-prep.md` (the rung-7 plan cites the prep and frames). Keep rung-6 plan/result/checklist/prep.
- `docs/loop/README.md`: list what remains and say this file is deleted by the next cleanup.
- `docs/plan/STATUS.md`: add **Rung 7 — combination spanner (PR #280)** above the Post-rung-6 / Candlestick entries. Shipped: 17° construction, 3-click ellipse 55 steep × 50 along 17°, Parallel jaw offsets, Mirror Entities + Symmetric, Power Trim ellipse → C and two AF-25 hexes → 12-point, Mid Plane 10 / 6, R30/R20 neck fillets (MakeFillet-first + AABB clip), Convert + Offset 5 Cut Blind 1, R3, Feature Mirror about Front, R1, 46-row walk, `check_rung07.py`. Bars: the table in `rung-07-result.md`. Suites **244 run + 4 known-red**.
- `docs/plan/roadmap.md`: append `## 13. Structural debt found after rung 7` (empty table with columns Item / What / Design / Why parked) and a Related bullet. First row, written now: pixel `render=viewport` still parked (§9 cap-colour miss); do not reopen it.
- Dead symbols, only if a re-run of the finders below still prints them: `SpannerFixture.set_handle_construction`, `SpannerFixture.contour_at` (`game/tests/lib/spanner_fixture.gd`), `WalkUI07._contour_note`, `WalkUI07.check_all_contours` (`tools/walk/rung7/ui07.py`). Delete a helper only when its name's count is 1. Do not delete Godot overrides. `dump_contours`, `contour_by_area`, `set_contours` stay.

Change: `git rm` the spent doc. Grep the repo outside `.git` for that basename first; rewrite every inbound link to `rung-07-result.md` or `git log -- docs/loop`. Then STATUS and roadmap. Then the deletions.

Expected delta: about −380 lines of docs, −40 lines of code.

Check: C-grep finds no remaining path to the deleted cleanup-plan basename outside `.git`. C-tools. The finders print none of the four names. C-lint still `248 suites ok`.

Revert: revert the commit if C-tools is red after three attempts. Doc deletions that already match the grep can stay only if the code deletion is what failed; in that case revert the whole commit anyway (one commit, one revert) and re-land the docs as a fresh commit with the same message plus `code deletions parked`.

Finders (from the repo root):

```python
# gdscript: print func names defined once under the rung-7 script list
import re, collections
from pathlib import Path
files = """game/tests/lib/spanner_fixture.gd game/scripts/sketch_mode.gd
game/scripts/ops_panel.gd game/scripts/automation_bridge.gd""".split()
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
for f in ("tools/walk/rung7/ui07.py", "tools/check_rung07.py"):
    for n in ast.walk(ast.parse(src[f])):
        if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and names[n.name] == 1 and not n.name.startswith(("__", "row_")) and n.name != "main":
            print(f, n.name)
```

### WP3 — One PART table, one boot, shared millimetres

Goal: the seven rung-7 suites stop restating millimetres or carrying a private boot. Kernel millimetres come from the checker. Byte-identical helpers live once.

Files / symbols:

- `game/tests/lib/spanner_fixture.gd` already owns `part` / `mm` / `deg` / `world` / `x_jaw` / `boot` / `line`. Callers that still have `_boot` (trim, coincident, mirror) delete it and call `SpannerFixture.boot`. Callers that still have `_world` / `_x_jaw` / `DEG := 17` delete them and call `SpannerFixture.world` / `x_jaw` / `deg()`. `run_rung07_mirror_plane.gd` reads `SpannerFixture.mm("CENTER")` instead of `PLATE_X := 240.0`.
- Lift `_line` (trim / coincident) onto `SpannerFixture.line` (already present; delete the copies). Lift `_count_type` onto the fixture (one body). Click-built sequences that are not identical stay in the suite that owns them.
- Dimensions in remaining hardcoded `12.5` / `27.5` / `20` / `15` / `17` in those suites read `SpannerFixture.mm(...)` / `deg()`. Do not type them as a second table. `SPAN := 90` zoom is a viewport span, not a PART key — leave it or pass it as a parameter.

Change: where two copies differ, the difference is a parameter (viewport size, status sink, which case). Where they differ in behaviour, leave both and name the pair in the commit message. Do not change a check string.

Expected delta: about −80 net.

Check: C-tools (`test_check_rung07.py` still green). C-one `--only 'rung07_trim.suite'` and `--only 'rung07_coincident.suite'`. Their `N checks, 0 failures` lines match a one-line capture you take at the start of the WP, before the edit (`--only` once, save the line, then edit).

Revert: if either line changes or the suite is red after three attempts, revert the whole WP.

### WP4 — NeckFillet.POLICY (AABB clip + MakeFillet-first)

Goal: the neck-fillet special-case helpers in `ops_dress.cpp` become a named `struct NeckFillet` with POLICY constants, same shape as `SweepFuse` / `FeatureMirror`. Behaviour is identical.

Files: `sxkernel/src/features/ops_dress.cpp` only (do not add a .cpp; CMake stays). Callers of `aabb_of` / `common_with` / `clip_to_body_aabb` / `neck_z_edge` / `any_neck_z_edge` / `fuse_concave_z_fillet(s)` / `clip_result_to_start_aabb` become `NeckFillet::…`. The try order in `apply_fillet_chamfer` becomes a small table or named steps on the struct; do not reverse it.

Change:

```
struct NeckFillet {
    static constexpr double XY_ALIGN_MM = 0.2;
    static constexpr double MIN_Z_LEN = 0.2;
    static constexpr double RADIUS_VS_THICK = 2.0;
    static constexpr double AABB_XZ_SLACK = 1.0;
    static constexpr double MIN_VOLUME = 0.5;
    static constexpr double VOID_ANGLE_MIN_RAD = 100.0 * M_PI / 180.0;
    static constexpr double UNIFY_LIN = 1e-6;
    static constexpr double UNIFY_ANG = 1e-4;

    static bool is_z_edge(const TopoDS_Edge&, gp_Pnt& a, gp_Pnt& b, double& z0, double& z1);
    static bool is_neck(const TopoDS_Edge&, double radius, gp_Pnt& a, gp_Pnt& b, double& z0, double& z1);
    static bool any(const std::vector<TopoDS_Edge>&, double radius);
    static TopoDS_Shape aabb_of(const TopoDS_Shape&, bool slack_y);
    static TopoDS_Shape common_with(const TopoDS_Shape&, const TopoDS_Shape&);
    static TopoDS_Shape clip_add(const TopoDS_Shape& body, const TopoDS_Shape& add);
    static TopoDS_Shape clip_result(const TopoDS_Shape& start, const TopoDS_Shape& result);
    static bool fuse_wedge(const TopoDS_Shape&, const TopoDS_Edge&, double radius, TopoDS_Shape& out);
    static bool fuse_wedges(const TopoDS_Shape&, const std::vector<TopoDS_Edge>&, double radius, TopoDS_Shape& out);
};
```

Move the existing function bodies unchanged. `wedge_prism` / `offset_meet` / `face_xy_normal` may stay file-local helpers called by `fuse_wedge`. Do not widen `RADIUS_VS_THICK`, `VOID_ANGLE_MIN_RAD`, or AABB slack. Do not skip `clip_result` on a successful MakeFillet of a neck edge. Do not change heal/unify tolerances. Chamfer path is untouched.

Expected delta: about +50 / −50 (move, not new behaviour).

Check: C-one `--only 'rung07_boss.suite'` with the same check count as the start of the WP. Then C-one `--only 'rung03_fillet.suite'` or `--only 'rung05_fillet.suite'` if that suite exists and is cheap (slot / box corners must still refuse a too-large R). Catch2 is not re-run here (WP11).

Revert: either suite red or a changed check count → revert the whole WP and park it in §13. Do not ship a partial extract.

### WP5 — Walk neck fillet + jaw tip + weld as tables

Goal: the walk special cases become named constants / a small table. Click sequences stay. Dry-run output is byte-identical. No Godot.

Files: `tools/walk/rung7/ui07.py` and callers in `rows07_chunk1.py` / `rows07_chunk3.py`.

Change:

- `NeckRow` table next to `STAGE_FILE`: open-end R30 at `handle_xy(True)[0]` / `handle_xy(False)[0]`, box-end R20 at the Ø33 left chord `(CENTER − sqrt((RING_D/2)² − HANDLE_HALF²), ±HANDLE_HALF)`. `fillet_z_edges` stays; A24/A25 pass the table rows instead of raw tuples. `bbox_y_ok` slop `0.4` is `NeckRow.Y_SLOP`. Undo-if-balloon loop stays (three attempts).
- `jaw_tip_uv(upper)` returns `ellipse_major()` for upper and `world(0, −ELLIPSE_MAJ/2)` for lower. A10 and `weld_open_profile` call it. Do not send both jaws to `ellipse_major()`.
- `WeldPolicy` frozen constants: `DUP_MM = 1e-3`, `PAIR_MM = 1.6`, `JAW_NEAR_MM = 2.5`. `weld_open_profile` reads them. Evidence strings stay.

Do not move chrome-owned helpers. Do not change wait_idle histograms. Do not re-table `export_3mf` or `--from`.

Expected delta: about +40 / −30.

Check: C-dry diffs empty against `/tmp/sx-base/dry{1,2,3,4,5,6,7}.txt`. C-tools (`test_walk_registry.py`).

Revert: any dry-run diff → revert.

### WP6 ★ — FilmSteps midplane extrude (no film yet)

Goal: the click sequence the film will need for Mid Plane 10 / 6 (and that PipeFixture already almost has for Blind) lives once. Suites call it only where the body is already a click-through of visible controls. No new film file.

Files / symbols: `game/tests/lib/film_steps.gd`. `SpannerFixture` may grow a thin wrapper.

Change: new click-only static, two-line comment:

- `midplane_extrude(ctx, distance, op_index)` — `finish:Op` at `op_index` (0 New, 1 Cut, 2 Fuse — same as `pick_finish` / PipeFixture), `finish:End` Midplane (index 2 per `sketch_context_chrome.gd`), Distance `distance`, `finish:Extrude`. Hidden → `FilmUI._fail`. Reuse `pick_finish` / `type_distance`. After OK, `ctx.after_regen`. If the sketch is still active, `FilmUI.exit_sketch`.

If a suite’s current path is kernel `sm.finish_extrude` (boss / offset / mirror_fillet / mirror_plane), leave that suite’s helper and name it in the commit message. Do not teach the film a private call by extracting one. Do not change a check string. `FilmUI.apply_extrude` is Blind-only — do not silently widen it.

Expected delta: about +40.

Check: C-one `--only 'rung05_csp.suite'` or another suite that already uses `pick_finish`, only if you edited it; otherwise C-lint still `248 suites ok`. Do not run the film yet.

Revert: red or a changed check count → revert the whole ★ WP and park it in §13.

### WP7 ★ — WalkUI07 split into profile / boss / dress

Goal: `WalkUI07` is no longer a 1105-line pile. Gesture groups live in modules the class mixes in. Dry-run output is byte-identical.

Files: `tools/walk/rung7/ui07.py` (class, `STAGE_FILE`, `part` / `mm` / `deg` / `world` / geometry helpers). New `tools/walk/rung7/profile.py` (ellipse, jaws, trim, hex, handle, coincident, weld). New `tools/walk/rung7/boss.py` (contours, try_extrude, twelve-point bore). New `tools/walk/rung7/dress.py` (fillet_z_edges, convert, offset, recess, feature mirror). Mixins or functions that take `self`. Each new file starts with a two-line comment that says what it owns.

Change: move methods; do not rewrite click sequences. `mm` stays a one-line `PART` lookup. Do not move chrome-owned helpers. Evidence strings stay. Import mixins the way `WalkUI06` does (`from walk.rung7.profile import ProfileGestures` … `class WalkUI07(ProfileGestures, BossGestures, DressGestures, WalkChrome)`). Keep geometry helpers (`x_jaw`, `handle_xy`, `ellipse_major`) on the class in `ui07.py` so mixins can call them.

Expected delta: about 0 net (move), ui07.py under ~250 lines.

Check: C-dry diffs empty against `/tmp/sx-base/dry{1,2,3,4,5,6,7}.txt`. C-tools (`test_walk_registry.py`).

Revert: any dry-run diff → revert the whole ★ WP and park it in §13. Do not ship a partial split.

## Part B — Combination-spanner demo

Goal: a click-driven film of the rung-7 part (How to Sketch Combination Spanner in Solidworks, RZB8m9li098), a headless demo test that fails when the film's end state is not that part, a video from `scripts/sx-movies`, a poster, a how-to, and the website wiring the publish script already implements — **without** changing the curated 12. Same shape as `candlestick` (#279) and `flanged_pipe` (#272) before the curator featured the latter (#273). Binding rules: [`landing-protocol.md`](../plan/landing-protocol.md), `.cursor/rules/gdscript-click-driven-tests.mdc`, `.cursor/rules/website-published-demo-movies.mdc`. Current publish flow: `scripts/sx-movies one <id>` then `scripts/sx-publish-demo-movies` against Release `demo-movies` on **`solidexpress/solidexpress`**. Curated homepage set stays 12. Agent WebMs go to `cursor/demo-artifacts-<id>` (candlestick: `origin/cursor/demo-artifacts-candlestick`).

The story is the walk, compressed (`tools/walk/rung7/rows07_chunk*.py` and the step table in `rung-07-plan.md`): Front 17° construction, 3-click ellipse 55 steep × 50 along 17°, Parallel jaw offsets 12.50 length 20, Mirror Entities, 3-point R15, Power Trim C opening −X, Ø33 + two AF-25 hexes Power Trim 12-point, centre 240, handle half-width 10 Horizontal then Mirror, Mid Plane 10 heads then Mid Plane 6 handle fuse, R30 / R20 neck fillets, Convert + Offset 5 Cut Blind 1, R3, Feature Mirror about Front, R1 remaining.

### WP8 — Film `spanner`, manifest, how-to

Goal: an enabled film the smoke skip does not execute (WP9 adds the suite that owns it; until that file exists, smoke would run it, so WP8 and WP9 are two commits but WP8's check is manifest load only, not a full smoke of every film).

Files:

- `game/tests/films/film_spanner.gd` (`extends RefCounted`, `run_film(ctx)`), following `film_candlestick.gd` / `film_flanged_pipe.gd`. `FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))`, `movie_toast`, then beats: "Sketch the Front C: 17°, ellipse 55×50, Parallel jaws, Mirror, R15, Power Trim", "Ø33, two AF-25 hexes, Power Trim 12-point, handle 10", "Mid Plane 10 heads, Mid Plane 6 handle", "R30 / R20 neck fillets", "Convert + Offset 5, Cut Blind 1, R3, Feature Mirror Front, R1". Then `ctx.camera.showcase_smooth`.
- Click path lives in `SpannerFixture` (add the click builders next to the existing kernel/boot helpers) and the WP6 `FilmSteps` helpers. `FilmUI`, `FilmSteps`, `SxInput` only. A missing control fails the film. No `set_tool`, `exit_sketch` private, `sm.finish_extrude`, `sm.sketch.add_line` / `add_ellipse`, `add_twelve_point`, `OriginPlanes.begin`, `graph_add_*`, or other private call. Follow WalkUI07 clicks (named Front datum, walk UVs, finish-bar Midplane, Convert rail, Offset, Feature Mirror datum Front).
- Millimetres from `SpannerFixture.mm(...)`. Do not type `17` / `55` / `240` / `30` in the film.
- If a beat has no visible control, `FilmUI._fail` and stop.
- Length aim ≤ 120 s at 30 fps. `quit_after` 4800 (ceiling only), same as candlestick / hexkey / flanged_pipe. Raise to 6000 in this commit only if a local timing pass shows the caption timeline exceeding 4800 frames; say so in the commit message.
- Append to `game/tests/ui_movie_manifest.json`: `{"id": "spanner", "title": "Combination spanner: ellipse, 12-point, mid-plane, mirrored recess", "script": "res://tests/films/film_spanner.gd", "enabled": true, "quit_after": 4800, "blurb": "Front C and 12-point box end, mid-plane 10/6, neck fillets, offset recess mirrored about Front."}`. No `website` object. Run `scripts/sx-sync-website` (Pages checkout absent exits 0). The two manifest JSON files must match.
- `docs/howto/spanner.md`, numbered clicks, same shape as `docs/howto/candlestick.md`. End with `Film: spanner.` and a Pending publish block that quotes the commands in WP10. Do not tell the curator to bump `EXPECTED_COUNT` or swap a featured card.

Expected delta: about +550 (film + steps + how-to).

Check: `python3 -c 'import json; json.load(open("game/tests/ui_movie_manifest.json")); json.load(open("website/assets/ui_movie_manifest.json"))'` and `diff` of those two files is empty. C-web (`python3 tools/website_demos.py check` still 12 curated; `scripts/sx-check-website-demos --offline` passes). Do not run the film yet (WP9 does, once).

Revert: if the manifest diff or the offline website check is red after three attempts, revert. Do not hand-edit `website/features.html`. Do not bump `EXPECTED_COUNT`. Do not add a `website` object.

### WP9 — Demo test `run_film_spanner_tests.gd`

Goal: one suite owns the film. It fails when the end state is not the checked part.

Files:

- `game/tests/run_film_spanner_tests.gd` (`extends "res://tests/lib/sx_suite.gd"`, banner `print("film spanner")`). `FilmHarness.boot(self, Vector2i(1600, 900))`, `manifest_entry("spanner")`, `load_film`, `await film.run_film(ctx)`. Then, as a validation test: `FilmUI.fail_count == 0`; one body; bbox 281.4 × 54.6 × 10.0 within 0.2 (`PART` size from `BBOX_SIZE` or `BBOX_MAX - BBOX_MIN` via `SxChecker.run("rung07", ["params"])`, do not type a second copy of the millimetres); handle on +X (`xmax ≥ PART.HANDLE_XMAX_MIN` or ≥ 250); open end on −X (`xmin ≤ PART.OPEN_XMIN_MAX` or ≤ −24.5); `last_graph_error` empty.
- Export with `doc.export_3mf` on a `ProjectSettings.globalize_path` temp path. `SxChecker.run("rung07", ["final", path])` exit 0 and the text contains `8/8 passed`. No hard-coded volume.
- Feature names: equal to the list this film's timeline actually produces. Capture it from the first green run of this suite and pin that string in the test in the same commit (the way `run_film_candlestick_tests.gd` pins `FEATURES`). Do not invent the list in advance. Order is part of the pin.
- `packaging/ci/suites.d/film_spanner_tests.suite`: `script=tests/run_film_spanner_tests.gd`, `tier=full`, `timeout=480`. No `render=` key (the film does not call `get_texture`; dummy is correct). Commit the `.uid`. If C-one hits the timeout twice because the film is long, raise to 600 in the same WP (ceiling, not a loosened assertion) and say so.

Expected delta: about +150, plus one suite file.

Check: C-one `--only 'film_spanner_tests.suite'` passes. C-lint prints `249 suites ok (82 ci, 163 full, 4 known-red)`. C-one `--only 'film_manifest_smoke.suite'` prints `- smoke skip spanner` and does not print `- smoke spanner`.

Revert: if the suite is red after three attempts, revert WP9 and WP8 (the film has no owner otherwise) and park Part B in §13. Do not weaken `8/8` or the bbox.

### WP10 — Render, poster, artifacts branch, publish note

Goal: a video and a poster from the existing movie scripts, a handoff branch with the WebM/VTT, and a written record that this token cannot put the video on the Release. Featured set unchanged.

Files on **this** branch: `website/assets/screenshots/spanner.png` (the only binary). `docs/plan/STATUS.md` Pending publish under the Post-rung-7 cleanup entry you add in this commit (short: what WP8–WP9 added, suites **245 run + 4 known-red**, the token limitation, artifacts branch). `docs/howto/spanner.md` already has the commands.

Change:

1. Calibrate with `scripts/sx-movies one precision_plate`, then `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-movies one spanner` under `tmux` (`DISPLAY=:1`). If the wall-time estimate from the plate (plate seconds × spanner duration / plate duration) exceeds 90 minutes, rerun with `SX_MOVIES_FPS=24`.
2. `ffprobe`: VP9, 1600×900, container duration within 10% of the caption timeline. Copy `spanner.webm` and `spanner.vtt` to `/opt/cursor/artifacts/`. Do not `git add` them on this branch.
3. Poster: the last picture of the **video track**, not a seek that falls past it. `lesson2_box` / `tutor1` / `flanged_pipe` / `candlestick` dropped duplicate frames, so the video track ended before the container and `ffmpeg -sseof -0.1` on the muxed file missed the picture. Use the video-track end (`ffprobe -show_entries stream=duration` vs format duration) and grab that frame into `website/assets/screenshots/spanner.png`.
4. Handoff branch, same as `origin/cursor/demo-artifacts-candlestick`: orphan `cursor/demo-artifacts-spanner` with `spanner.webm`, `spanner.vtt`, and a README that quotes the upload commands. Push it. Switch back to this cleanup branch. That branch is not for merge.
5. `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-publish-demo-movies --dry-run spanner`. Keep the output in the STATUS note. `--feature` is parsed and unused; do not pass it as a substitute for the id. Do not pass `--feature` in a way that would rewrite the curated JSON.
6. `gh release view demo-movies -R solidexpress/solidexpress --json assets --jq '.assets[].name'`.
   - If `spanner.webm` is listed (unexpected): still **do not** add a `website` object and **do not** bump `EXPECTED_COUNT`. STATUS says the curator may feature it later. The user forbade changing the featured set.
   - If it is not listed (expected; this token has no push on the Release): do not add `spanner` to `published-demos.json` or `demo-catalog.json`. Do not add a `website` object. STATUS Pending publish is exactly:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber spanner.webm spanner.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies spanner
```

A person who can upload then decides whether to feature it (swap, not grow past 12). `website/features.html` renders `demo-catalog.json` ∩ the live Release list. Do not hand-write a card.

Expected delta: one PNG plus a short STATUS section. Artifacts branch is a separate push.

Check: C-web still 12 curated. `git status` on this branch shows no `.webm` or `.vtt`.

Revert: if the offline check fails because the poster or the manifest is wrong, fix the poster path or revert the website file. Do not delete the film to go green. Do not leave WebM on this branch.

### WP11 — The single full pass

Goal: one run that builds, checks, and walks. Counts match the rung-7 result, plus the new film suite.

Command (this is the pass; do not also run `make test` or a second `run_suites.sh`):

```bash
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export OCCT_PREFIX=/opt/occt-8.0.1
tools/confirm_all.sh
```

`confirm_all.sh` builds, imports, runs kernel + lints + `test_check_rung02.py` … `test_check_rung07.py` + `test_walk_registry.py` + `run_suites.sh --tier full --keep-going` once, then the seven walks on `:21` … `:27` reading `SX_CONFIRM_DIR`.

Required lines in its summary:

| Bar | Count |
|---|---|
| Rung 7 walk | 46 pass, 0 fail |
| `check_rung07` | final 8/8 |
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
| Headless | **245 run, 0 failed** |
| Lint | `249 suites ok (82 ci, 163 full, 4 known-red)` |
| Film | `film_spanner_tests` is among the 245 and is not failed |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 245.

If Part B was reverted, the headless count stays **244** and there is no `spanner` film; say so and do not invent the video. If a ★ WP was parked, say so; the bars do not change.

This WP has no product commit unless a count is wrong and the fix is a one-line correction you can justify from a WP above. A red bar is a report, not a silent edit. Do not wait for CI.

Write `docs/loop/post-rung-07-result.md` with the table, shipped/parked WPs, and the pending upload line. Push that commit.

## Acceptance

WP11's summary shows the table above (or the reduced table if a WP was reverted and §13 says so). `make` was not run a second time beside `confirm_all.sh`. No video file is in this branch’s git. `spanner` is absent from `published-demos.json` and `demo-catalog.json`. `EXPECTED_COUNT` is still 12.

## Final report (keep it short)

Branch name. One line per WP: number, title, done or parked, net lines. Then the WP11 counts (walks 77/77, 44/44, 46/46, 32/32, 36/36, 46/46, 46/46, `check_rung05` 10/10, `check_rung06` 7/7, `check_rung07` 8/8, headless 245 or 244) and the pending `gh release upload` line if the WebM was not on the Release. Head sha. No other prose.
