# Post-rung-03 cleanup — layering, one test starter, then the Tutor1 demo film

Status: planned. Docs only. Baseline: `main` `44d149a` (`Rung 3: Learn SOLIDWORKS Lesson 1 Parts (Tutor1)`, PR #252; `git log 04f9edc4..44d149a` is that one squash, +9,645 / −360, 101 files). Rung 3 walk 46/46. `check_rung03` base 3/3, boss 4/4, cut 5/5, r5 14/14, rounded 16/16, final 29/29, final-reopen 29/29. Rung 1 walk 77/77 (blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7). Rung 2 walk 44/44 (final 16/16 at width 60 and 65). Headless: 213 run, 0 failed. Manifests on this sha: **217** (`67 ci`, `146 full`, `4 known-red`), so the tier runs `67 + 146 = 213`. Checklists: [`rung-03-plan.md`](rung-03-plan.md), [`rung-03-result.md`](rung-03-result.md). Previous cleanup, same shape: [`post-rung-02-cleanup.md`](post-rung-02-cleanup.md) (WP2 deletes it). History: `git log -- docs/loop`.

**Prompt for ONE BUILD agent.** Execute the work packages below in order, one commit per WP, on the branch you were given. Push that branch. Do not open a PR. This file is the only prompt. Part A (WP1–WP5, and WP6–WP7 only when the ★ rule says so) does not change product behaviour. Part B (WP8–WP10) is the Tutor1 film, its test, the rendered video, the poster, the how-to, and the website note. Part B is not optional and outranks every ★ WP. WP11 is the only full test pass. Do not build, walk, or run the tier before WP11 except for the cheap check named in that WP.

## Why this shape

Rung 3 landed green as one squash. The new code already uses tables in a few places (`FilletPick.POLICY`, `SketchOriginAnchor.RULES`, `SectionPlane.PRESETS`, kernel `kOffsetters` / `kProjectors`, `FacePick.match_normal`). What is still a pile is copy-paste and a runner that treats every suite the same. Measured on `44d149a`:

| Fact | Number | Source |
|---|---|---|
| Walk UI copied | `WalkUI03` is 1,013 lines, 90 methods. 65 names also exist on `WalkUI02`. **41 are byte-identical (237 lines of bodies).** `part()` differs only by `check_rung03.py` vs `check_rung02.py`. Ratio ≥ 0.94: `try_extrude`, `clear_sketch_selection`, `rail_label_nodes`, `select_body`, `_headless_report`, `apply_shell`, `pick_edge_again`. Under 0.85 (leave them): `covered`, `select_face`, `pick_corner_edges`, `headless`, `arm_fillet` | `tools/walk/rung3/ui03.py`, `tools/walk/rung2/ui02.py` |
| Rung-3 suites copy a boss | six scripts, 2,069 lines. `_boot` ×5 (no two bodies match), `_only_body` ×4, and `_build_boss` / `_open_z_face` / `_face_at_z` / `_click_model` / `_extrude` / `_volume` / `_status_since` repeated across `run_rung03_{convert_circle,offset,fillet_face,section}.gd` | `game/tests/run_rung03_*.gd` |
| Numbers live twice | `check_rung03.PART` is the table. `ImplicitPart03.for_stage` restates `h0=30`, `boss_d=70`, `boss_h=25`, `hole_d=60`, `side=120` | `tools/check_rung03.py`, `tools/implicit_part03.py` |
| Offset still branches on kind | `SketchOffset.BUILDERS` is a bool map. `click` then has three `kind == "circle"` arms (inward limit, empty-result text, applied text). The kernel already dispatches `kOffsetters` | `game/scripts/sketch_offset.gd` `click` ~139–163; `sxkernel/src/sketch_tools.cpp` `kOffsetters` |
| Corner helper with no caller | `FilletPick.view_for_corner` occurs once. `FilletPick.CORNERS` stays (the fillet suite reads it). `SketchOffset.is_panel_visible` occurs once. `WalkUI03.shell_back` occurs once (the suite has its own `_shell_back`) | finder in WP2 |
| One runner, every suite painted the same | `run_suites.sh` is parallel by default (`--jobs`, default `nproc`), one `HOME` per job, and **every** suite gets `--rendering-driver dummy`. The two scripts that read a framebuffer then return without checking when the display name contains `headless`: `run_rung03_section.gd` `_assert_cap_pixels`, `run_rung01_replan16_chrome.gd` `_assert_viewport_columns` | `packaging/ci/run_suites.sh` ~250–260 |
| Same film, two starters | 67 enabled films. `run_film_manifest_smoke.gd` runs all of them. `film_ubc_wrench_tests` and `film_lesson2_box_tests` run those two again. A Tutor1 suite would make a third double | `game/tests/run_film_manifest_smoke.gd`, `packaging/ci/suites.d/film_*_tests.suite` |
| Walk gates can launch the tier again | `confirm_all.sh` runs the suite pass once and exports `SX_CONFIRM_DIR`. `gates.take` / `run_tier` read that log. A walk whose `headless()` misses the cache calls `run_tier`, which runs `preflight_sxcore.gd` plus `run_suites.sh` again. Three walks with `--a15` and no cache run the tier three times | `tools/walk/gates.py` `run_tier`, `tools/confirm_all.sh`, `ui02.headless`, `ui03.headless` |
| Spent loop docs | `post-rung-02-cleanup.md` (373 lines; README says the next cleanup deletes it), `rung-03-replan-1.md` (437), `rung-03-critique-2.md` (70), `docs/loop/rung-03-walk1/` and `rung-03-walk2/` (15 files, the failed walks). The live contract is the plan and the result | `docs/loop/README.md` |
| No rung-3 status entry | `docs/plan/STATUS.md` starts at Rung 2. The rung PR was told not to edit it | `STATUS.md` |

Not in this pass (already parked, or a second painter that is doing a different job): splitting `SketchMode` / `ViewportInteraction` ([roadmap.md §7](../plan/roadmap.md)), the §8 rows, and merging the section shader with `SectionCap`. The shader discards the near half and the back faces (`document_view.gd` `_make_section_shader`); `SectionCap` fills the cut in screen space. Both stay. WP2 records that in §9.

## Invariants (every WP, no exceptions)

Product behaviour is identical in Part A. A WP is done only when its own cheap check passes. The walks, the checkers, and the 213-suite tier are proved once, in WP11, not before.

1. No suite is retired. No suite is added in Part A. Run count stays **213** until WP9, then **214**.
2. The four `known-red` manifests stay `known-red`: `run_rung01_replan12_pick.gd`, `run_rung01_replan3_timeline.gd`, `run_rung01_replan_input.gd`, `run_rung01_sketch_tests.gd`. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.
3. Save files and wire formats do not change: `.sxp` keys, bridge command names and reply keys, automation ids (`strip:shell`, `offset:Distance`, `offset:Reverse`, `offset:Ok`, `hud:Section`, `popup:Front|Top|Right`, `rail:Offset`, `variant:Center`). Do not add or remove a bridge field.
4. Status texts the rows pin stay byte-identical, including `FilletPick.REFUSE_FACE`, `SketchOffset` `ZERO_REFUSED` / `TOO_FAR` / `NOTHING` / `APPLIED_CIRCLE` / `APPLIED_LINE`, `Shell 1.0000 mm applied`, and `SectionPlane.CAP_COLOUR` `(158, 168, 184)`.
5. `check_rung03.py` stage names, the `N/N passed` lines, and `PART` / `VOLUMES` values stay. `check_rung01.py` is not edited.
6. Never commit `.webm`, `.mp4`, `.avi`, `.mov`, or `.vtt`. The poster PNG is the only binary Part B commits.
7. Never pass `user://` or `res://` into GDExtension. `ProjectSettings.globalize_path` first.
8. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. A new suite is one new file in `suites.d/`. WP3 may edit `run_suites.sh` and `lint_suites.py` because that is the runner change, not a new suite.

### Cheap checks (not the full pass)

| Check | Command | When |
|---|---|---|
| C-lint | `python3 tools/lint_suites.py` | WP1, and any WP that touches `suites.d/` or the lint |
| C-dry | `python3 tools/walk_rung01.py --dry-run`, same for `walk_rung02.py` and `walk_rung03.py`, diff against the WP1 files | WP4, WP6 |
| C-tools | `python3 tools/test_check_rung03.py && python3 tools/test_lint_suites.py && python3 tools/test_walk_registry.py` | WP2, WP3, WP5 |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<one suite>'` | the single suite a WP names |
| C-grep | the grep the WP names | dead-code and doc WPs |

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call. Godot is `tools/godot/godot` 4.7-stable. Do not start the GUI app. Do not call `make test`, `make test-godot`, `confirm_all.sh`, or any `walk_rung0N.py` without `--dry-run` before WP11.

### Protected pins

- Rung-1 A15 still requires its fifteen banner floors and `known-red == 4`. Do not edit those literals.
- Rung-2 A25 and rung-3 A26 keep the clause names `kernel`, `godot`, `lint`, `unit`, `registry`, `errors`. They read logs. They do not gain a second launcher.
- `suites.baseline` is a ratchet. A new `.gd` needs its `.uid` (`make import` is allowed only in WP8/WP9 for the new files; do not commit `game/.godot/`). A deleted `.gd` takes its `.uid`.
- `FilletPick.CORNERS` and `FilletPick.POLICY` stay. The walk's `CORNERS` tuple in `ui03.py` stays in the walk (Python cannot import the GDScript const). Do not invent a shared JSON for four rows.

### Rules for the BUILD agent

- One commit per WP: `Post-rung-3 cleanup WP<n>: <title>`. Push after each commit. Do not open a PR.
- **Revert rule.** If a WP's cheap check is red after two honest attempts, `git revert` that commit, name the failing check in the next commit message's body only if you must (prefer a line in `docs/plan/roadmap.md` §9), append the WP to §9, and continue. Never loosen a check, raise a timeout, drop a `--only`, or edit a tier to get green.
- **★ WPs.** WP6 and WP7. Record `date` in the WP1 commit message. Start a ★ WP only after WP1–WP5 are green and fewer than 4 hours have passed since WP1. Otherwise park the whole WP in §9 and go to Part B. A skipped ★ WP is not started.
- No new third-party dependency. No comments that narrate the edit.
- Design rule: a new branch is a row in a table the file already has, or a value object, not another `if` on a string kind. A new file starts with a two-line comment that says what it owns.

## Libraries considered

| Candidate | Decision | Why |
|---|---|---|
| Godot `--rendering-driver dummy` vs headless Forward+ (lavapipe) | **use as a per-suite flag** (WP3) | already how this binary starts. Dummy skips Vulkan for tests that never read a picture. A framebuffer read needs the real headless driver |
| Existing `FilmSteps` / `BoxFixture` / `SxChecker` / `FilmHarness` | **use** (WP5, WP8, WP9) | the Lesson 2 film already proved the shape |
| Python `dataclasses` | **keep** | `ImplicitPart03` already uses one. No new library |
| `trimesh`, `pytest`, `vulture`, a new test framework | **no** | `unittest` and `numpy` already run. The oracle checkers stay |

## Decisions (final)

1. Part A adds no suite and retires none. `lint_suites: 217 suites ok (67 ci, 146 full, 4 known-red)` through WP8. WP9 adds `film_tutor1_tests` at `tier=full`: **218** suites (`67 ci`, `147 full`, `4 known-red`), **214 run, 0 failed**.
2. A suite script is started by `run_suites.sh` only. `run_film_manifest_smoke.gd` does not execute a film id that has `packaging/ci/suites.d/film_<id>_tests.suite`. Today that is `ubc_wrench` and `lesson2_box`. After WP9 it is also `tutor1`. The dedicated suite is the only starter of that film script. Smoke still runs every other enabled film once.
3. `render=dummy` (the default when the key is absent) is `--headless --rendering-driver dummy`. `render=viewport` is `--headless` without `dummy`, so lavapipe draws. The only scripts that read `get_texture` / `force_draw` are `run_rung03_section.gd` and `run_rung01_replan16_chrome.gd`. Those two manifests set `render=viewport` and their headless early-return is deleted, so the pixel checks actually run. The walk's L7 pixel clauses stay: the walk is a different script on a display, not a second launch of the suite.
4. `tools/confirm_all.sh` is the only full pass (WP11). It already runs kernel, lints, unit tests, and `run_suites.sh` once, then the three walks with `SX_CONFIRM_DIR` set. WP3 adds a unit test that `run_tier` returns the cached log and does not call `proc.run` when that log exists. Do not make `run_tier` spawn when the cache is present.
5. `ImplicitPart03.for_stage` reads `PART` from `check_rung03`. It does not restate the millimetres. `VOLUMES` stays the volume source (already imported).
6. The Tutor1 film id is `tutor1` (the video's save name). It is click-only. The demo test may call the kernel and `SxChecker`. The id is not added to `published-demos.json` or `demo-catalog.json` unless `tutor1.webm` is already on Release `demo-movies`. This token cannot upload there (same fact STATUS records for `lesson2_box`).

## Work packages

### WP1 — Clock and the lint line (no product code)

Goal: a recorded start time and proof the manifest count is the rung-3 bar, without running Godot.

Files: none in the tree. The commit message holds `start: <date -Is>`.

Change: run `date -Is` and `python3 tools/lint_suites.py`. Save `python3 tools/walk_rung01.py --dry-run`, `walk_rung02.py --dry-run`, and `walk_rung03.py --dry-run` to `/tmp/sx-base/dry{1,2,3}.txt`. Expect the lint line `lint_suites: 217 suites ok (67 ci, 146 full, 4 known-red)`.

Expected delta: 0.

Check: C-lint matches that line. If it does not, stop. This plan assumes `44d149a`.

Revert: nothing was committed to the tree. If you made a commit by mistake, revert it.

### WP2 — Spent docs, the rung-3 status entry, dead symbols

Goal: the loop directory keeps the live contract, STATUS names rung 3, and three unreferenced symbols are gone.

Files / symbols:

- Delete `docs/loop/post-rung-02-cleanup.md`, `docs/loop/rung-03-replan-1.md`, `docs/loop/rung-03-critique-2.md`, `docs/loop/rung-03-walk1/`, `docs/loop/rung-03-walk2/`.
- Keep `rung-03-plan.md` and `rung-03-result.md`. Rewrite the result's first paragraph so it does not cite the deleted critique or walk directories. Keep its bar table. One sentence is enough for the old 4/10 score: it is history, `git log -- docs/loop`.
- `docs/loop/README.md`: list what remains (`automation-bridge.md`, `linux-test-build.md`, `rung-01-replan-21.md`, `rung-02-plan.md`, `rung-03-plan.md`, `rung-03-result.md`, this file) and say this file is deleted by the next cleanup.
- `docs/plan/STATUS.md`: add **Rung 3 — Tutor1 (PR #252)** above the Rung 2 entry. Shipped: origin anchor, face `pick` / `plane`, circle convert, Offset Entities, Shift+face fillet, section presets and cap, 46-row walk, `check_rung03.py`. Bars: the table in `rung-03-result.md`. Suites **213 run + 4 known-red**.
- `docs/plan/roadmap.md`: append `## 9. Structural debt found after rung 3` (empty table with columns Item / What / Design / Why parked) and a Related bullet. First row, written now: section shader discards, `SectionCap` fills; do not merge them in this pass (`document_view.gd` `_make_section_shader`, `section_cap.gd`).
- Dead symbols, only if a re-run of the finders below still prints them: `FilletPick.view_for_corner` (`game/scripts/fillet_pick.gd`), `SketchOffset.is_panel_visible` (`game/scripts/sketch_offset.gd`), `WalkUI03.shell_back` (`tools/walk/rung3/ui03.py`). Do not delete `FilletPick.CORNERS`. Delete a helper only when its name's count is 1.

Change: `git rm` the spent docs. Grep the repo outside `.git` for those basenames first; rewrite every inbound link to `rung-03-result.md` or `git log -- docs/loop`. Then the STATUS and roadmap edits. Then the three deletions.

Expected delta: about −1,000 lines of docs, −30 lines of code.

Check: C-grep finds no remaining path to the deleted basenames outside `.git`. C-tools. The GDScript finder and the Python finder print none of the three names. C-one `--only 'rung03_fillet_face.suite'` (it reads `FilletPick.CORNERS`).

Revert: revert the commit if C-one or C-tools is red after two attempts. Doc deletions that already match the grep can stay only if the code deletion is what failed; in that case revert the whole commit anyway (one commit, one revert) and re-land the docs as a fresh commit with the same message plus `code deletions parked`.

Finders (from the repo root):

```python
# gdscript: print func names defined once under the rung-3 script list
import re, collections
files = "game/scripts/document_view.gd game/scripts/face_pick.gd game/scripts/fillet_pick.gd game/scripts/main.gd game/scripts/ops_panel.gd game/scripts/section_cap.gd game/scripts/section_plane.gd game/scripts/shell_chrome.gd game/scripts/sketch_convert_edge.gd game/scripts/sketch_mode.gd game/scripts/sketch_offset.gd game/scripts/sketch_origin_anchor.gd game/scripts/view_hud.gd game/scripts/viewport_interaction.gd".split()
text = {f: open(f).read() for f in files}
cnt = collections.Counter(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", "\n".join(open(f).read() for f in __import__('glob').glob('game/**/*.gd', recursive=True))))
engine = {"_ready","_process","_input","_gui_input","_draw","_init"}
for f in files:
    for m in re.finditer(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\(", text[f], re.M):
        if m.group(1) not in engine and cnt[m.group(1)] == 1:
            print(f, m.group(1))
```

```python
# python: print walk/checker names defined once
import ast, glob, collections, re
files = glob.glob("tools/**/*.py", recursive=True)
src = {f: open(f).read() for f in files}
names = collections.Counter(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", "\n".join(src.values())))
for f in ("tools/walk/rung3/ui03.py", "tools/check_rung03.py", "tools/implicit_part03.py", "tools/solid.py"):
    for n in ast.walk(ast.parse(src[f])):
        if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and names[n.name] == 1 and not n.name.startswith(("__", "row_")) and n.name != "main":
            print(f, n.name)
```

### WP3 — One starter per suite, dummy only when nothing is drawn

Goal: each suite script is launched once per pass, in parallel by default, with its own `HOME`. A test that never reads a framebuffer does not start a renderer. A test that reads one does, and the check is not skipped.

Files / symbols:

- `packaging/ci/run_suites.sh` — the `GODOT_RUN` array and `parse_manifest`.
- `tools/lint_suites.py` — `ALLOWED_KEYS`.
- `tools/test_lint_suites.py` — the unknown-key case stays; add the two cases below.
- `packaging/ci/suites.d/rung03_section.suite`, `packaging/ci/suites.d/rung01_replan16_chrome.suite` — add `render=viewport`.
- `game/tests/run_rung03_section.gd` `_assert_cap_pixels` and `game/tests/run_rung01_replan16_chrome.gd` `_assert_viewport_columns` — delete the `DisplayServer.get_name().contains("headless")` return.
- `game/tests/run_film_manifest_smoke.gd` `_init` loop.
- `tools/walk/gates.py` `run_tier` / `take`. A new test function in `tools/test_lint_suites.py` or a few lines in an existing tools test: with `SX_CONFIRM_DIR` pointing at a temp dir that contains `godot.log` and `godot.rc`, `run_tier(walk)` returns that text and the test's fake `proc.run` is not called. Use a tiny fake walk object (`repo` only). Do not start Godot in that test.

Change:

1. Manifest key `render` is `dummy` or `viewport`. Absent means `dummy`. Any other value is exit 2, same as a bad tier. `lint_suites.py` allows the key.
2. Lint rule, in `lint_suites.py`: if the script source contains `get_texture` or `force_draw`, the manifest must say `render=viewport`. Otherwise it must not say `render=viewport`. Wire this into `manifest_errors` so `test_lint_suites.py` can drive it with `SX_SUITES_DIR`.
3. `run_suites.sh` keeps `--jobs` default `nproc`, per-job `HOME` / `XDG_*`, and `PYTHONUSERBASE`. For `render=dummy` the argv stays `--headless --rendering-driver dummy`. For `render=viewport` it is `--headless` only.
4. Smoke: before `_run_one`, if `film_<id>_tests.suite` exists under `res://` is wrong (suites live outside the Godot tree). Resolve the repo root with `ProjectSettings.globalize_path("res://")` and a `../packaging/ci/suites.d` join, and skip when that file exists. Print `- smoke skip <id> owned by film_<id>_tests`. Do not load the film. The existing run line is `- smoke <id>`.
5. `run_tier`: keep `take("godot")` as the first line. The unit test locks that.

Expected delta: about +80 / −20.

Check: C-tools, including a temp-dir lint case that a `get_texture` script with `render=dummy` fails and a script without `get_texture` with `render=viewport` fails. C-lint on the real tree. C-one `--only 'rung03_section.suite'` and C-one `--only 'rung01_replan16_chrome.suite'` so the pixel checks run instead of printing `skipped (headless display)`. C-one `--only 'film_manifest_smoke.suite'` prints `- smoke skip ubc_wrench` and `- smoke skip lesson2_box` and does not print `- smoke ubc_wrench` or `- smoke lesson2_box`.

The smoke suite's check count drops by the checks those two films used to add. That is the only ledger delta in Part A. Record the new smoke line in the WP3 commit message (`N films` is 65 executed, plus 2 skip lines). Do not "fix" it by running the films inside smoke.

Revert: if either pixel suite is red after two attempts, revert the whole WP (the smoke skip included), park WP3 in §9, and continue. Do not leave the skip removed while `render=dummy`.

### WP4 — One copy of the shared walk gestures

Goal: `WalkUI02` and `WalkUI03` keep only the methods that differ. The 41 identical methods live once.

Files / symbols: new `tools/walk/chrome.py` (`class WalkChrome`). `tools/walk/rung2/ui02.py` `WalkUI02`, `tools/walk/rung3/ui03.py` `WalkUI03`. `tools/walk/app02.py` `WalkApp02`, `tools/walk/app03.py` `WalkApp03` (MRO stays rows, then the UI class, then `WalkGestures`; the UI class extends `WalkChrome`).

Change: move the 41 byte-identical methods onto `WalkChrome` and delete them from both UI classes. Header comment: shared click and read helpers for rung 2 and rung 3. `part(self)` becomes `WalkChrome.part(self, script: str)` and each UI class keeps a one-line `part` that passes `check_rung02.py` or `check_rung03.py` (that one-liner is the rung's own method, not a copy of the body). Do not move `covered`, `select_face`, `pick_corner_edges`, `headless`, `arm_fillet`, or `shell_back` (deleted in WP2). Do not change clause names or evidence strings.

Expected delta: about −230 lines net (`WalkChrome` gains the 237, both copies lose them, plus the two `part` wrappers).

Check: C-dry diffs empty against `/tmp/sx-base/dry{1,2,3}.txt`. C-tools (`test_walk_registry.py`).

Revert: if any dry-run diff is non-empty, revert. Do not edit a row to match a new print.

### WP5 — One Tutor1 fixture, one PART table

Goal: the four click suites stop each carrying a private boss builder. The analytic part reads the checker's table.

Files / symbols:

- New `game/tests/lib/tutor1_fixture.gd` (`class_name Tutor1Fixture`), same idea as `BoxFixture`. It may call the kernel. It owns the shared sequence only: boot `main.tscn` into a `FilmContext`, status log, `open_z_face`, `click_model`, `extrude`, `only_body`, `volume`, `build_boss` (centre rect on the ground, extrude `PART`-height 30, circle on `z = 30`, extrude fuse 25). Two-line header: the click-built Tutor1 boss the rung-3 suites share.
- Callers: `run_rung03_convert_circle.gd`, `run_rung03_offset.gd`, `run_rung03_fillet_face.gd`, `run_rung03_section.gd`. Delete their private copies of those helpers. `run_rung03_origin_anchor.gd` and `run_rung03_part_check.gd` do not build that boss; leave them, except a status/boot helper that is byte-identical may call the fixture.
- `tools/implicit_part03.py` `ImplicitPart03.for_stage`: dimensions come from `check_rung03.PART` (`H0`, `BOSS_D`, `BOSS_H`, `HOLE_D`, `SIDE`). Stage rows stay the data that says which radii and which wall are on.

Change: where two copies differ, the difference is a parameter (viewport size, status sink). Where they differ in behaviour, leave both and name the pair in the commit message. Do not change a check string.

Expected delta: about −450 net (new file ~200, deleted copies ~650).

Check: C-tools (`test_check_rung03.py` must still pass with the PART-backed solid). C-one `--only 'rung03_offset.suite'` and `--only 'rung03_convert_circle.suite'`. Their `N checks, 0 failures` lines match a one-line capture you take at the start of the WP, before the edit (`--only` once, save the line, then edit).

Revert: if either line changes or the suite is red after two attempts, revert the whole WP.

### WP6 ★ — Shared body where the two UIs almost match

Goal: the ratio ≥ 0.94 pairs become one method when the diff is only a name or a number.

Files: `tools/walk/chrome.py`, `ui02.py`, `ui03.py`. Methods: `try_extrude`, `clear_sketch_selection`, `rail_label_nodes`, `select_body`, `_headless_report`, `apply_shell`, `pick_edge_again`. Also `apply_enter`, `_ensure_finish_bar`, `s0` if and only if `diff -u` shows a checker name, a status string, or a numeric default.

Change: put the surviving method on `WalkChrome` with the extra argument. Update both callers. If a hunk is not one of those three kinds of difference, leave that pair and list it in the commit message. Evidence strings stay.

Expected delta: about −100, or 0 for each pair you leave.

Check: C-dry empty. C-tools.

Revert: any dry-run diff → revert the whole ★ WP and park it in §9. Do not ship a partial merge.

### WP7 ★ — Offset kind table

Goal: `SketchOffset.click` does not branch on `kind == "circle"`.

Files / symbols: `game/scripts/sketch_offset.gd` `BUILDERS`, `click`, `_resolve_source`.

Change: replace the bool map with a dictionary of rows, one per kind the kernel already offsets:

```gdscript
# kind → how a successful offset is told to the user, and whether Reverse
# can eat the radius. The kernel kOffsetters table decides what is built.
const KINDS := {
    "circle": {"applied": "circle", "inward_limit": true},
    "line": {"applied": "line", "inward_limit": false},
}
```

`applied: "circle"` selects `APPLIED_CIRCLE` (the radius format stays). `applied: "line"` selects `APPLIED_LINE`. Inward limit and the empty-result text read `inward_limit`. Status strings stay byte-identical. Do not edit `sketch_tools.cpp`.

Expected delta: about −20.

Check: C-one `--only 'rung03_offset.suite'` with the same check count as the start of the WP.

Revert: red or a changed check count → revert and park in §9.

## Part B — Tutor1 demo

Goal: a click-driven film of the rung-3 part (Learn SOLIDWORKS Lesson 1: Parts), a headless demo test that fails when the film's end state is not that part, a video from `scripts/sx-movies`, a poster, a how-to, and the website wiring the publish script already implements. Same shape as `lesson2_box`. Binding rules: [`landing-protocol.md`](../plan/landing-protocol.md), `.cursor/rules/gdscript-click-driven-tests.mdc`, `.cursor/rules/website-published-demo-movies.mdc`.

The story is the walk, compressed (`tools/walk/rung3/rows03_chunk*.py` and the step table in `rung-03-plan.md`): ground sketch, centre rectangle 120 × 120, Smart Dim both sides, extrude blind 30, sketch on the front face (`z = 30`), circle Ø70, extrude fuse 25, sketch on the boss top (`z = 55`), Offset 5 inward, extrude cut through all, fillet R5 on the four vertical corners then Shift+click the front face (9 edges), fillet R1.5 on the annulus, shell 1 on the back face, section Top then section off, showcase.

### WP8 — Film `tutor1`, manifest, how-to

Goal: an enabled film the smoke skip does not execute (WP9 adds the suite that owns it; until that file exists, smoke would run it, so WP8 and WP9 are two commits but WP8's check is manifest load only, not a full smoke of every film).

Files:

- `game/tests/films/film_tutor1.gd` (`extends RefCounted`, `run_film(ctx)`), following `film_lesson2_box.gd`. `FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))`, `movie_toast`, then beats: "Sketch a 120 by 120 rectangle from the centre", "Extrude 30", "Boss: circle on the front face, diameter 70, extrude 25", "Offset the rim 5 mm inward and cut through", "Round the corners and the front face, R5", "Round the hole rims, R1.5", "Shell 1, open the back", "Section on the Top plane, then off". Then `ctx.camera.showcase_smooth`.
- New click-only statics on `game/tests/lib/film_steps.gd` if a beat has no helper yet: `centre_rect` (rail `Rect`, variant `Center`, two clicks), `offset_rim` (rail `Offset`, `offset:Distance`, `offset:Reverse`, click, `offset:Ok`), `shift_click_face` (a real pointer click with Shift held, through `FilmUI` / `SxInput`, never `graph_add_fillet`), `section_top` (`hud:Section`, `popup:Top`) and `section_off`. Reuse `press_rail`, `click_uv`, `type_dim`, `type_distance`, `pick_finish`, `arm_fillet`, `commit_fillet`, `shell_selected_face`, `open_side_face_sketch`, `only_body`.
- If a beat has no visible control, `FilmUI._fail` and stop. No `set_tool`, `exit_sketch`, `graph_add_fillet`, or other private call.
- Length aim ≤ 120 s at 30 fps. `quit_after` 4800 (ceiling only).
- Append to `game/tests/ui_movie_manifest.json`: `{"id": "tutor1", "title": "Tutor1: boss, offset cut, fillets, shell, section", "script": "res://tests/films/film_tutor1.gd", "enabled": true, "quit_after": 4800, "blurb": "Centre rectangle, a boss, an inward offset cut, two fillets, a 1 mm shell, and a Top section."}`. Run `scripts/sx-sync-website` (Pages checkout absent exits 0). The two manifest JSON files must match.
- `docs/howto/tutor1.md`, numbered clicks, same shape as `docs/howto/lesson2-box.md`. End with `Film: tutor1.` and a Pending publish block that quotes the commands in WP10.

Expected delta: about +400 (film + steps + how-to).

Check: `python3 -c 'import json; json.load(open("game/tests/ui_movie_manifest.json")); json.load(open("website/assets/ui_movie_manifest.json"))'` and `diff` of those two files is empty. `scripts/sx-check-website-demos --offline` passes. Do not run the film yet (WP9 does, once).

Revert: if the manifest diff or the offline website check is red after two attempts, revert. Do not hand-edit `website/features.html`.

### WP9 — Demo test `run_film_tutor1_tests.gd`

Goal: one suite owns the film. It fails when the end state is not the checked part.

Files:

- `game/tests/run_film_tutor1_tests.gd` (`extends "res://tests/lib/sx_suite.gd"`, banner `print("film tutor1")`). `FilmHarness.boot(self, Vector2i(1600, 900))`, `manifest_entry("tutor1")`, `load_film`, `await film.run_film(ctx)`. Then, as a validation test: `FilmUI.fail_count == 0`; one body; bbox 120 × 120 × 55 within 0.2 (`PART` `SIDE` and `TOP`, read them, do not type a second copy of the millimetres into a comment that can drift — a local `Vector3` taken from the checker's JSON via `SxChecker.run("rung03", ["params"])` is the read); section is off (`section_enabled == false`) so the export is the solid.
- Export with `doc.export_3mf` on a `ProjectSettings.globalize_path` temp path. `SxChecker.run("rung03", ["final", path])` exit 0 and the text contains `29/29 passed`. No hard-coded volume.
- Feature names: equal to the list this film's timeline actually produces. Capture it from the first green run of this suite and pin that string in the test in the same commit (the way `run_film_lesson2_box_tests.gd` pins `FEATURES`). Do not invent the list in advance. Order is part of the pin. The fillet count on the R5 feature is 4 edges or 9 edges according to what that run shows — pin the number the green run printed, and say which in the commit message.
- `packaging/ci/suites.d/film_tutor1_tests.suite`: `script=tests/run_film_tutor1_tests.gd`, `tier=full`, `timeout=300`. No `render=` key (the film does not call `get_texture`; dummy is correct). Commit the `.uid`.

Expected delta: about +150, plus one suite file.

Check: C-one `--only 'film_tutor1_tests.suite'` passes. C-lint prints `218 suites ok (67 ci, 147 full, 4 known-red)`. C-one `--only 'film_manifest_smoke.suite'` prints `- smoke skip tutor1` and does not print `- smoke tutor1`.

Revert: if the suite is red after two attempts, revert WP9 and WP8 (the film has no owner otherwise) and park Part B in §9. Do not weaken `29/29` or the bbox.

### WP10 — Render, poster, publish note

Goal: a video and a poster from the existing movie scripts, and a written record that this token cannot put the video on the Release.

Files: `website/assets/screenshots/tutor1.png` (the only binary). `docs/plan/STATUS.md` Pending publish under the Post-rung-3 entry you add in this commit (short: what WP8–WP9 added, suites **214 run + 4 known-red**, the token limitation). `docs/howto/tutor1.md` already has the commands.

Change:

1. Calibrate with `scripts/sx-movies one precision_plate`, then `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-movies one tutor1` under `tmux` (`DISPLAY=:1`). If the wall-time estimate from the plate (plate seconds × tutor1 duration / plate duration) exceeds 90 minutes, rerun with `SX_MOVIES_FPS=24`.
2. `ffprobe`: VP9, 1600×900, container duration within 10% of the caption timeline. Copy `tutor1.webm` and `tutor1.vtt` to `/opt/cursor/artifacts/`. Do not `git add` them.
3. Poster: the last picture of the **video track**, not a seek that falls past it. `lesson2_box` dropped duplicate frames, so the video track ended before the container and `ffmpeg -sseof -0.1` on the muxed file missed the picture (STATUS, Post-rung-2 cleanup). Use the video-track end (`ffprobe -show_entries format=duration` vs stream duration) and grab that frame into `website/assets/screenshots/tutor1.png`.
4. `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-publish-demo-movies --dry-run --feature tutor1`. Keep the output in the STATUS note.
5. `gh release view demo-movies -R solidexpress/solidexpress.github.io --json assets --jq '.assets[].name'`.
   - If `tutor1.webm` is listed: `SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature tutor1`, commit the JSON, `scripts/sx-check-website-demos`.
   - If it is not listed (expected; this token has no push on `solidexpress/solidexpress.github.io`): do not add `tutor1` to `published-demos.json` or `demo-catalog.json`. STATUS Pending publish is exactly:

```
gh release upload demo-movies -R solidexpress/solidexpress.github.io --clobber tutor1.webm tutor1.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature tutor1
```

Then one follow-up commit of the two JSON files, by a person who can upload. `website/features.html` renders `demo-catalog.json` ∩ the live Release list. Do not hand-write a card.

Expected delta: one PNG plus a short STATUS section.

Check: `scripts/sx-check-website-demos --offline`. `git status` shows no `.webm` or `.vtt`.

Revert: if the offline check fails because the poster or the manifest is wrong, fix the poster path or revert the website file. Do not delete the film to go green.

### WP11 — The single full pass

Goal: one run that builds, checks, and walks. Counts match the rung-3 result, plus the new film suite.

Command (this is the pass; do not also run `make test` or a second `run_suites.sh`):

```bash
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export OCCT_PREFIX=/opt/occt-8.0.1
tools/confirm_all.sh
```

`confirm_all.sh` builds, imports, runs kernel + lints + `test_check_rung02.py` + `test_check_rung03.py` + `test_walk_registry.py` + `run_suites.sh --tier full --keep-going` once, then the three walks on `:21` `:22` `:23` reading `SX_CONFIRM_DIR`.

Required lines in its summary:

| Bar | Count |
|---|---|
| Rung 3 walk | 46 pass, 0 fail |
| `check_rung03` | base 3/3, boss 4/4, cut 5/5, r5 14/14, rounded 16/16, final 29/29, final-reopen 29/29 |
| Rung 1 walk | 77 pass, 0 fail |
| Rung 1 checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7 |
| Rung 2 walk | 44 pass, 0 fail |
| `check_rung02` | final-60 16/16, final-65 16/16 |
| Headless | **214 run, 0 failed** |
| Lint | `218 suites ok (67 ci, 147 full, 4 known-red)` |
| Film | `film_tutor1_tests` is among the 214 and is not failed |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 214.

If WP3 was reverted, the pixel suites are still in the 214 and the smoke suite still runs `ubc_wrench` and `lesson2_box`; say so. If Part B was reverted, the headless count stays **213** and there is no `tutor1` film; say so and do not invent the video.

This WP has no product commit unless a count is wrong and the fix is a one-line correction you can justify from a WP above. A red bar is a report, not a silent edit. Do not wait for CI.

## Acceptance

WP11's summary shows the table above (or the reduced table if a WP was reverted and §9 says so). `make` was not run a second time beside `confirm_all.sh`. No video file is in git. `tutor1` is absent from `published-demos.json` and `demo-catalog.json` unless the Release listing in WP10 contained `tutor1.webm`.

## Final report (keep it short)

Branch name. One line per WP: number, title, done or parked, net lines. Then the WP11 counts (walks 46/46, 77/77, 44/44, headless 214 or 213) and the pending `gh release upload` line if the WebM was not on the Release. No other prose.
