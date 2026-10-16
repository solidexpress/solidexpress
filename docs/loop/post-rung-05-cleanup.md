# Post-rung-05 cleanup — layering, one fixture, then the flanged-pipe demo film

Status: planned. Docs only. Baseline: `main` `8bd01c3` (`Rung 5: flanged pipe, mirror + circular pattern (9/10)`, PR #270; `git log 962a820..8bd01c3` is that one squash, +6,333 / −138, 59 files). Rung 5 walk 36/36. `check_rung05` final 10/10. Rung 1 walk 77/77. Rung 2 44/44. Rung 3 46/46. Rung 4 32/32. Headless: 228 run, 0 failed. Manifests on this sha: **232** (`75 ci`, `153 full`, `4 known-red`), so the tier runs `75 + 153 = 228`. Checklists: [`rung-05-plan.md`](rung-05-plan.md), [`rung-05-result.md`](rung-05-result.md). Previous cleanup, same shape: [`post-rung-03-cleanup.md`](post-rung-03-cleanup.md) (WP2 deletes it). What post-rung-4 shipped is [`post-rung-04-result.md`](post-rung-04-result.md) (PR #258): region pick, dummy `render=`, click budget, hexkey film.

**Prompt for ONE BUILD agent.** Execute the work packages below in order, one commit per WP, on the branch you were given. Push that branch. Do not open a PR. This file is the only prompt. Part A (WP1–WP5, and WP6–WP7 only when the ★ rule says so) does not change product behaviour. Part B (WP8–WP10) is the flanged-pipe film, its test, the rendered video, the poster, the how-to, and the website wiring. Part B is not optional and outranks every ★ WP. WP11 is the only full test pass. Do not build, walk, or run the tier before WP11 except for the cheap check named in that WP.

## Why this shape

Rung 5 landed green as one squash. The new code already uses tables in the places the rung plan named (`SketchCircularPattern.SPEC`, `MirrorFeatures.SPEC`, kernel `FeatureMirror.POLICY`, `ImplicitPipe.STAGE`, checker `PART` / `VOLUMES`, walk `FACES` / `STAGE_FILE`). Dummy renderer, parallel jobs, per-job `HOME`, and smoke-skip of dedicated film suites already landed in post-rung-4 (PR #258) and stay. What is still a pile is copy-paste across the new walk and the five rung-5 suites, four unreferenced symbols, four missing `.uid` files, and spent loop docs. Measured on `8bd01c3`:

| Fact | Number | Source |
|---|---|---|
| Walk UI copied | `WalkUI05` is 720 lines, 49 methods. 20 names also exist on `WalkUI03`. **7 are byte-identical.** 8 names also exist on `WalkUI04`; **4 are byte-identical (`_release_project`, `click_verb`, `check_probe`, `reopen` — 31 lines of bodies).** Ratio ≥ 0.94: `_headless_report`, `headless`, `apply_shell`, `select_face`, `try_extrude`. `part()` differs only by `check_rung05.py` vs `check_rung04.py` / `check_rung03.py`. None of these live on `WalkChrome` yet. Header of `chrome.py` still says “rung 2 and rung 3” | `tools/walk/rung5/ui05.py`, `tools/walk/rung4/ui04.py`, `tools/walk/rung3/ui03.py`, `tools/walk/chrome.py` |
| Rung-5 suites copy a pipe | five scripts, 1,486 lines. `_boot` ×5 (ratio 0.85–1.0). `_build_mirrored` byte-identical in `run_rung05_fillet.gd` and `run_rung05_reshell.gd` (40-line bodies). `_find_auto` ×3 identical. `_click_front` ×2 identical. `_output_body` / `_z_faces` ×2 identical. `_spin` ×2 identical. `PITCH := 94.0` and `HOLE_R := 5.0` restated in three scripts; millimetres already live in `check_rung05.PART` | `game/tests/run_rung05_*.gd`, `tools/check_rung05.py` |
| Dead symbols | `_selection_centroid`, `_add_rotated_copy` (old centroid circular pattern; `apply_circular_pattern` is the live path). `_mirror_source_feature_id` (collector is `_mirror_source_ids`). `WalkUI05.features_of` (no caller). Count of each name in the tree is 1 | finder in WP2 |
| Missing `.uid` | `run_rung05_fillet.gd`, `run_rung05_mirror.gd`, `run_rung05_reshell.gd`, `sketch_vertical.gd`. Shell and CSP already have theirs. `class_name SketchVertical` has no uid | `game/tests/run_rung05_*.gd`, `game/scripts/sketch_vertical.gd` |
| One starter, dummy by default | already true. `run_suites.sh` default `--jobs nproc`, per-job `HOME`, `--rendering-driver dummy` unless `render=viewport`. Smoke skips `film_<id>_tests.suite`. Pixel `render=viewport` stays parked (§9 / §10) | `packaging/ci/run_suites.sh`, `game/tests/run_film_manifest_smoke.gd`, `docs/plan/roadmap.md` §9–§10 |
| Same film, two starters | 69 enabled films. `run_film_manifest_smoke.gd` runs those without a dedicated suite. `film_ubc_wrench_tests`, `film_lesson2_box_tests`, `film_tutor1_tests`, `film_hexkey_tests` own those four. A flanged-pipe suite would make a fifth double unless smoke skips it | `game/tests/run_film_manifest_smoke.gd`, `packaging/ci/suites.d/film_*_tests.suite` |
| Spent loop docs | `post-rung-03-cleanup.md` says the next cleanup deletes it. Keep the live contracts (rung plans/results, post-rung-03/04 results, this file) | `docs/loop/README.md` |
| No rung-5 status entry | `docs/plan/STATUS.md` starts at Post-rung-4. The rung PR was told not to edit it | `STATUS.md` |

Not in this pass (already parked, or a second painter that is doing a different job): splitting `SketchMode` / `ViewportInteraction` ([roadmap.md §7](../plan/roadmap.md)), the §8–§10 rows, pixel `render=viewport`, CommandBus, Jaw template. Kernel `FeatureMirror.POLICY`, `SketchCircularPattern.SPEC`, and `SketchOffset.KINDS` already exist — do not re-table them.

## Invariants (every WP, no exceptions)

Product behaviour is identical in Part A. A WP is done only when its own cheap check passes. The walks, the checkers, and the 228-suite tier are proved once, in WP11, not before.

1. No suite is retired. No suite is added in Part A. Run count stays **228** until WP9, then **229**.
2. The four `known-red` manifests stay `known-red`: `run_rung01_replan12_pick.gd`, `run_rung01_replan3_timeline.gd`, `run_rung01_replan_input.gd`, `run_rung01_sketch_tests.gd`. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.
3. Save files and wire formats do not change: `.sxp` keys, bridge command names and reply keys, automation ids (`strip:shell`, `pattern:Count`, `pattern:Angle`, `pattern:Ok`, `variant:Circular`, `mirror:Features`, `mirror:Plane`, `mirror:Add`, `mirror:Ok`, `finish:Thickness`, `finish:Ok`, `rail:Pattern`, `timeline:row:…`). Do not add or remove a bridge field.
4. Status texts the rows pin stay byte-identical, including `SketchCircularPattern.REFUSALS` / `APPLIED`, `MirrorFeatures.REFUSALS` / `APPLIED`, `Shell 10.0000 mm applied`, `Fillet 4 edges 5.00 applied`, and the Shell thickness-limit sentence.
5. `check_rung05.py` stage names, the `N/N passed` lines, and `PART` / `VOLUMES` values stay. `check_rung01.py`–`check_rung04.py` are not edited.
6. Never commit `.webm`, `.mp4`, `.avi`, `.mov`, or `.vtt`. The poster PNG is the only binary Part B commits.
7. Never pass `user://` or `res://` into GDExtension. `ProjectSettings.globalize_path` first.
8. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. A new suite is one new file in `suites.d/`. Do not edit `run_suites.sh` unless a WP names it (none does: dummy + one-starter already hold).
9. `tools/website_demos.py` `EXPECTED_COUNT` is **12**. Do not add a `website` object to a new film, and do not edit `published-demos.json` or `demo-catalog.json`, unless WP10 finds `<id>.webm` already on Release `demo-movies` of `solidexpress/solidexpress`. Hexkey, tutor1, and lesson2_box are the precedent (manifest + poster + pending publish).

### Cheap checks (not the full pass)

| Check | Command | When |
|---|---|---|
| C-lint | `python3 tools/lint_suites.py` | WP1, and any WP that touches `suites.d/` or the lint |
| C-dry | `python3 tools/walk_rung01.py --dry-run`, same for `walk_rung02.py` … `walk_rung05.py`, diff against the WP1 files | WP3, WP6 |
| C-tools | `python3 tools/test_check_rung05.py && python3 tools/test_lint_suites.py && python3 tools/test_walk_registry.py` | WP2, WP3, WP4 |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<one suite>'` | the single suite a WP names |
| C-grep | the grep the WP names | dead-code and doc WPs |
| C-web | `python3 tools/website_demos.py check` and `scripts/sx-check-website-demos --offline` | WP8, WP10 |

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call. Godot is `tools/godot/godot` 4.7-stable. Do not start the GUI app. Do not call `make test`, `make test-godot`, `confirm_all.sh`, or any `walk_rung0N.py` without `--dry-run` before WP11.

### Protected pins

- Rung-1 A15 still requires its fifteen banner floors and `known-red == 4`. Do not edit those literals.
- Rung-2 A25, rung-3 A26, rung-4 A21, and rung-5 A25 keep the clause names `kernel`, `godot`, `lint`, `unit`, `registry`, `errors`. They read logs. They do not gain a second launcher.
- `suites.baseline` is a ratchet. A new `.gd` needs its `.uid` (`make import` is allowed in WP2 for the four missing uids, and in WP8/WP9 for the new film files; do not commit `game/.godot/`). A deleted `.gd` takes its `.uid`.
- `WalkUI05.FACES`, `STAGE_FILE`, and `MIRROR_TYPES` stay in the walk. Do not invent a shared JSON for those rows.
- Pixel suites stay on dummy. Do not add `render=viewport`.

### Rules for the BUILD agent

- One commit per WP: `Post-rung-5 cleanup WP<n>: <title>`. Push after each commit. Do not open a PR.
- **Revert rule.** If a WP's cheap check is red after two honest attempts, `git revert` that commit, name the failing check in `docs/plan/roadmap.md` §11, append the WP to §11, and continue. Never loosen a check, raise a timeout, drop a `--only`, or edit a tier to get green.
- **★ WPs.** WP6 and WP7. Record `date` in the WP1 commit message. Start a ★ WP only after WP1–WP5 are green and fewer than 4 hours have passed since WP1. Otherwise park the whole WP in §11 and go to Part B. A skipped ★ WP is not started.
- No new third-party dependency. No comments that narrate the edit.
- Design rule: a new branch is a row in a table the file already has, or a value object, not another `if` on a string kind. A new file starts with a two-line comment that says what it owns.

## Libraries considered

| Candidate | Decision | Why |
|---|---|---|
| Godot `--rendering-driver dummy` vs headless Forward+ (lavapipe) | **already the default** (post-rung-4 WP3) | object-model/bridge tests never read pixels. Do not reopen `render=viewport` |
| Existing `FilmSteps` / `FilmHarness` / `SxChecker` / `HexKeyFixture` / `Tutor1Fixture` | **use** (WP4, WP8, WP9) | hexkey and tutor1 already proved the shape |
| Python `dataclasses` | **keep** | `ImplicitPipe` already uses one. No new library |
| `trimesh`, `pytest`, `vulture`, a new test framework | **no** | `unittest` and `numpy` already run. The oracle checkers stay |

## Decisions (final)

1. Part A adds no suite and retires none. `lint_suites: 232 suites ok (75 ci, 153 full, 4 known-red)` through WP8. WP9 adds `film_flanged_pipe_tests` at `tier=full`: **233** suites (`75 ci`, `154 full`, `4 known-red`), **229 run, 0 failed**.
2. A suite script is started by `run_suites.sh` only. `run_film_manifest_smoke.gd` does not execute a film id that has `packaging/ci/suites.d/film_<id>_tests.suite`. Today that is `ubc_wrench`, `lesson2_box`, `tutor1`, `hexkey`. After WP9 it is also `flanged_pipe`. The dedicated suite is the only starter of that film script. Smoke still runs every other enabled film once.
3. Dummy stays the starter. `render=viewport` stays parked. Do not edit `run_suites.sh`.
4. `tools/confirm_all.sh` is the only full pass (WP11). It already runs kernel, lints, unit tests, and `run_suites.sh` once, then the five walks with `SX_CONFIRM_DIR` set.
5. Suite millimetres come from `check_rung05.PART` via `SxChecker.run("rung05", ["params"])` (or a `PipeFixture.part()` that caches that JSON). Do not restate `94`, `5`, `150`, `250`, `10`, `225`, `130` as a second table in a suite. `VOLUMES` stays the volume source.
6. The film id is `flanged_pipe` (the video's save name). It is click-only. The demo test may call the kernel and `SxChecker`. Follow hexkey: add the id to `ui_movie_manifest.json`; do **not** add a `website` object, and do **not** edit `published-demos.json` or `demo-catalog.json`, unless `flanged_pipe.webm` is already on Release `demo-movies` of `solidexpress/solidexpress` (current publisher default in `scripts/sx-publish-demo-movies`). This token cannot upload there (same fact STATUS records for hexkey / tutor1). Pending-publish commands name that repo, not `solidexpress.github.io`.
7. Test-speed rules already hold and stay: each test has exactly one starter, run in parallel by default, object-model/bridge tests that never read pixels run with the dummy renderer.

## Work packages

### WP1 — Clock and the lint line (no product code)

Goal: a recorded start time and proof the manifest count is the rung-5 bar, without running Godot.

Files: none in the tree. The commit message holds `start: <date -Is>`.

Change: run `date -Is` and `python3 tools/lint_suites.py`. Save `python3 tools/walk_rung01.py --dry-run` through `walk_rung05.py --dry-run` to `/tmp/sx-base/dry{1,2,3,4,5}.txt`. Expect the lint line `lint_suites: 232 suites ok (75 ci, 153 full, 4 known-red)`.

Expected delta: 0.

Check: C-lint matches that line. If it does not, stop. This plan assumes `8bd01c3`.

Revert: nothing was committed to the tree. If you made a commit by mistake, revert it.

### WP2 — Spent docs, the rung-5 status entry, dead symbols, missing uids

Goal: the loop directory keeps the live contract, STATUS names rung 5, four unreferenced symbols are gone, and the four missing `.uid` files exist.

Files / symbols:

- Delete `docs/loop/post-rung-03-cleanup.md` (this file replaces it; history: `git log -- docs/loop`).
- Keep `rung-05-plan.md` and `rung-05-result.md`. Keep `post-rung-03-result.md` and `post-rung-04-result.md`. Keep `rung-04-prep.md` and `rung-04-checklist.md` (the rung-4 plan cites them).
- `docs/loop/README.md`: list what remains and say this file is deleted by the next cleanup.
- `docs/plan/STATUS.md`: add **Rung 5 — flanged pipe (PR #270)** above the Post-rung-4 entry. Shipped: two-face Shell chip, Circular Sketch Pattern 8/360 about origin, Feature Mirror (fuse New, skip Shell, one body), re-shell that does not thicken +Z walls, Fillet R5 on both flange outer faces, 36-row walk, `check_rung05.py`. Bars: the table in `rung-05-result.md`. Suites **228 run + 4 known-red**.
- `docs/plan/roadmap.md`: append `## 11. Structural debt found after rung 5` (empty table with columns Item / What / Design / Why parked) and a Related bullet. First row, written now: pixel `render=viewport` still parked (§9 cap-colour miss); do not reopen it.
- Dead symbols, only if a re-run of the finders below still prints them: `SketchMode._selection_centroid`, `SketchMode._add_rotated_copy` (`game/scripts/sketch_mode.gd`), `OpsPanel._mirror_source_feature_id` (`game/scripts/ops_panel.gd`), `WalkUI05.features_of` (`tools/walk/rung5/ui05.py`). Delete a helper only when its name's count is 1. Do not delete Godot overrides (`_get_minimum_size`, `_unhandled_key_input`, `_exit_tree`, `_can_drop_data`). Do not delete `_try_pick_region` unless the finder still prints it **and** `_apply_region_pick` remains the live caller from the click path (verify; region pick shipped in post-rung-4).
- Missing uids: `make import` (headless) then commit only the four new `.uid` files. Do not commit `game/.godot/`.

Change: `git rm` the spent doc. Grep the repo outside `.git` for that basename first; rewrite every inbound link to `rung-05-result.md` or `git log -- docs/loop`. Then STATUS and roadmap. Then the deletions. Then the uids.

Expected delta: about −400 lines of docs, −40 lines of code, +4 uid files.

Check: C-grep finds no remaining path to `post-rung-03-cleanup.md` outside `.git`. C-tools. The GDScript finder and the Python finder print none of the four names. C-lint still `232 suites ok`.

Revert: revert the commit if C-tools is red after two attempts. Doc deletions that already match the grep can stay only if the code deletion is what failed; in that case revert the whole commit anyway (one commit, one revert) and re-land the docs as a fresh commit with the same message plus `code deletions parked`.

Finders (from the repo root):

```python
# gdscript: print func names defined once under the rung-5 script list
import re, collections
from pathlib import Path
files = """game/scripts/mirror_features.gd game/scripts/sketch_circular_pattern.gd
game/scripts/sketch_vertical.gd game/scripts/shell_chrome.gd
game/scripts/ops_panel.gd game/scripts/timeline_panel.gd
game/scripts/sketch_mode.gd game/scripts/automation_bridge.gd""".split()
text = {f: Path(f).read_text() for f in files}
cnt = collections.Counter(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b",
    "\n".join(p.read_text(errors="ignore") for p in Path("game").rglob("*.gd"))))
engine = {"_ready","_process","_input","_gui_input","_draw","_init",
          "_get_minimum_size","_unhandled_key_input","_exit_tree","_can_drop_data"}
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
for f in ("tools/walk/rung5/ui05.py", "tools/check_rung05.py", "tools/implicit_pipe.py"):
    for n in ast.walk(ast.parse(src[f])):
        if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and names[n.name] == 1 and not n.name.startswith(("__", "row_")) and n.name != "main":
            print(f, n.name)
```

### WP3 — One copy of the identical walk gestures

Goal: `WalkUI03` / `WalkUI04` / `WalkUI05` keep only the methods that differ. Byte-identical methods live once on `WalkChrome`.

Files / symbols: `tools/walk/chrome.py` (`class WalkChrome`). `tools/walk/rung3/ui03.py`, `tools/walk/rung4/ui04.py`, `tools/walk/rung5/ui05.py`. Do not touch `ui02.py` unless a method is byte-identical with a copy you move (then delete that copy too).

Change: move the byte-identical methods onto `WalkChrome` and delete them from the UI classes that held them. Header comment of `chrome.py` becomes: shared click and read helpers for the rung walks. Confirmed identical on `8bd01c3`:

- ui04 ≡ ui05: `_release_project`, `click_verb`, `check_probe`, `reopen`
- ui03 ≡ ui05: `_ensure_finish_bar`, `_face_record`, `apply_enter`, `profile_circles`, `selected_edge_count` (and `_release_project` if not already moved)

`part(self)` stays a one-line wrapper that passes `check_rung0N.py` (already `WalkChrome.part(self, script)`). Do not move `headless`, `_headless_report`, `try_extrude`, `apply_shell`, `select_face`, `rects_overlap` (formatting or a checker/log name differs — ★ WP6). Do not change clause names or evidence strings.

Expected delta: about −80 to −120 lines net.

Check: C-dry diffs empty against `/tmp/sx-base/dry{1,2,3,4,5}.txt`. C-tools (`test_walk_registry.py`).

Revert: if any dry-run diff is non-empty, revert. Do not edit a row to match a new print.

### WP4 — One pipe fixture, one PART table

Goal: the five rung-5 suites stop each carrying a private boot and a private mirrored-pipe builder. Millimetres come from the checker.

Files / symbols:

- New `game/tests/lib/pipe_fixture.gd` (`class_name PipeFixture`), same idea as `Tutor1Fixture` / `HexKeyFixture`. It may call the kernel. It owns: `part()` (cached `SxChecker.run("rung05", ["params"])` JSON), `boot` (main.tscn into a `FilmContext`, status log, viewport size), `find_auto`, `build_mirrored` (kernel: cyl → shell both ends → flange fuse → cut 8 holes → feature mirror of those four), `build_reshelled` (that plus Shell 10 on `z = −260` and the `z = 0` plug), `output_body`, `z_faces`. Two-line header: the kernel-built UBC pipe the rung-5 suites share.
- Callers: `run_rung05_fillet.gd` and `run_rung05_reshell.gd` delete `_build_mirrored` / `_output_body` / `_z_faces` / `_boot`. `run_rung05_shell.gd` and `run_rung05_mirror.gd` and `run_rung05_csp.gd` delete a `_boot` / `_find_auto` that is byte-identical. Click-built sequences (`_cylinder`, `_pipe`, `_pattern_eight`) stay in the suite that owns them — they are not the same as the kernel builder.
- Dimensions in the kernel builder and in remaining hardcoded `PITCH` / `HOLE_R` / radii read `PipeFixture.part()["PART"]`. Do not type `94` / `5` / `150` as a second table.

Change: where two copies differ, the difference is a parameter (viewport size, status sink). Where they differ in behaviour, leave both and name the pair in the commit message. Do not change a check string.

Expected delta: about −200 net (new file ~180, deleted copies ~380).

Check: C-tools (`test_check_rung05.py` still green). C-one `--only 'rung05_reshell.suite'` and `--only 'rung05_fillet.suite'`. Their `N checks, 0 failures` lines match a one-line capture you take at the start of the WP, before the edit (`--only` once, save the line, then edit).

Revert: if either line changes or the suite is red after two attempts, revert the whole WP.

### WP5 — FilmSteps for pattern, mirror, two-face shell (no film yet)

Goal: the click sequences the film will need, and that `run_rung05_mirror.gd` / `run_rung05_shell.gd` already duplicate, live once. Suites call them. No new film file.

Files / symbols: `game/tests/lib/film_steps.gd`. Callers: `run_rung05_shell.gd` `_shell_chip` / two-face pick, `run_rung05_mirror.gd` `_pattern_eight` / `_shell_ends` / `_a17_four_features` only where the body is already a click-through of visible controls.

Change: new click-only statics, two-line comment each:

- `two_face_shell(ctx, first, second, mm)` — click face `first`, Shift+click `second` (each a `{normal, plane, view_key}`), `strip:shell`, `finish:Thickness`, `finish:Ok`. Reuse `click_face` / `shift_click_face` / `shell_selected_face` if they already do this; add only the two-face arm.
- `circular_pattern(ctx, count, angle)` — rail `Pattern`, variant `Circular` (`variant:Circular` or the Circular chip), `pattern:Count`, `pattern:Angle`, `pattern:Ok`. Selection of the seed stays the caller's job (a real click, not `sm._set_selected`).
- `feature_mirror(ctx, plane_normal, plane_offset, names)` — `mirror:Features`, click the plane face, Shift+click each `timeline:row:<name>`, `mirror:Ok`. If a control is hidden, `FilmUI._fail` and stop.

If a suite's current path is not a visible-control click (for example `sm._set_selected([seed])` in `_pattern_eight`), leave that suite's helper and name it in the commit message. Do not teach the film a private call by extracting one. Do not change a check string.

Expected delta: about +80 / −40.

Check: C-one `--only 'rung05_shell.suite'` with the same check count as the start of the WP. C-one `--only 'rung05_csp.suite'` only if you edited it; otherwise skip.

Revert: red or a changed check count → revert.

### WP6 ★ — Shared body where the walk UIs almost match

Goal: the ratio ≥ 0.94 pairs become one method when the diff is only a name or a number.

Files: `tools/walk/chrome.py`, `ui03.py`, `ui04.py`, `ui05.py`. Methods: `_headless_report`, `headless`, `try_extrude`, `apply_shell`, `select_face`. Also `rects_overlap` if and only if `diff -u` is whitespace. Also `sketch_on_datum` if ui04 ≡ ui05 except a local variable.

Change: put the surviving method on `WalkChrome` with the extra argument (log prefix `a25`/`a26`, unit script `test_check_rung0N.py`, `plane=` default). Update callers. If a hunk is not a checker name, a status string, or a numeric default, leave that pair and list it in the commit message. Evidence strings stay.

Expected delta: about −100, or 0 for each pair you leave.

Check: C-dry empty. C-tools.

Revert: any dry-run diff → revert the whole ★ WP and park it in §11. Do not ship a partial merge.

### WP7 ★ — `headless` log names as a table

Goal: `_headless_report` does not hard-code `a25` vs `a26` vs `a15` in four copies.

Files: `tools/walk/chrome.py` only, if WP6 already moved `headless`. Otherwise skip this WP (park: “WP6 not started”).

Change: a small table on `WalkChrome` keyed by rung (`unit` script, log stem). Each UI class sets `_UNIT = "test_check_rung05.py"` (etc.) or passes it. No new branch on a string rung id outside that table.

Expected delta: about −40.

Check: C-dry empty. C-tools.

Revert: dry-run diff → revert and park in §11.

## Part B — Flanged-pipe demo

Goal: a click-driven film of the rung-5 part (UBC ELEC391 Exercise 3: pipe section), a headless demo test that fails when the film's end state is not that part, a video from `scripts/sx-movies`, a poster, a how-to, and the website wiring the publish script already implements. Same shape as `hexkey` / `tutor1`. Binding rules: [`landing-protocol.md`](../plan/landing-protocol.md), `.cursor/rules/gdscript-click-driven-tests.mdc`, `.cursor/rules/website-published-demo-movies.mdc`. Current publish flow: `scripts/sx-movies one <id>` then `scripts/sx-publish-demo-movies` against Release `demo-movies` on **`solidexpress/solidexpress`** (PR #268; `tools/website_demos.py` / `SX_DEMO_RELEASE_REPO`). Curated homepage set stays 12 unless that Release already lists the new WebM.

The story is the walk, compressed (`tools/walk/rung5/rows05_chunk*.py` and the step table in `rung-05-plan.md`): Front circle Ø150, extrude Blind 250, Shell 10 both planar ends, flange Ø225 Fuse 10, Ø130 + Ø10 at `(0, 94)` with distance 94 and Vertical, Circular Sketch Pattern 8 / 360°, Cut Blind 10, Feature Mirror of the four features about `z = 0`, re-shell the −Z half 10, Fillet R5 on both flange outer faces, showcase.

### WP8 — Film `flanged_pipe`, manifest, how-to

Goal: an enabled film the smoke skip does not execute (WP9 adds the suite that owns it; until that file exists, smoke would run it, so WP8 and WP9 are two commits but WP8's check is manifest load only, not a full smoke of every film).

Files:

- `game/tests/films/film_flanged_pipe.gd` (`extends RefCounted`, `run_film(ctx)`), following `film_hexkey.gd` / `film_tutor1.gd`. `FilmUI.ensure_test_viewport(ctx, Vector2i(1600, 900))`, `movie_toast`, then beats: "Sketch a Ø150 circle on Front and extrude 250", "Shell 10, both ends", "Flange Ø225, fuse 10", "Bore Ø130, eight Ø10 holes on a 94 mm pitch, cut 10", "Mirror the four features about z = 0", "Shell the mirrored half 10", "Fillet R5 on both flange faces". Then `ctx.camera.showcase_smooth`.
- Click path lives in `game/tests/lib/pipe_fixture.gd` (add the click builders next to the kernel ones) and/or the WP5 `FilmSteps` helpers. `FilmUI`, `FilmSteps`, `SxInput` only. A missing control fails the film. No `set_tool`, `exit_sketch` private, `graph_add_fillet`, `graph_add_mirror`, `sm._set_selected`, or other private call.
- If a beat has no visible control, `FilmUI._fail` and stop.
- Length aim ≤ 120 s at 30 fps. `quit_after` 4800 (ceiling only), same as hexkey.
- Append to `game/tests/ui_movie_manifest.json`: `{"id": "flanged_pipe", "title": "Flanged pipe: shell, pattern, mirror, fillet", "script": "res://tests/films/film_flanged_pipe.gd", "enabled": true, "quit_after": 4800, "blurb": "Ø150 tube, two-face shell, flange with an 8-hole circular pattern, feature mirror, re-shell, R5 rims."}`. No `website` object. Run `scripts/sx-sync-website` (Pages checkout absent exits 0). The two manifest JSON files must match.
- `docs/howto/flanged-pipe.md`, numbered clicks, same shape as `docs/howto/hexkey.md`. End with `Film: flanged_pipe.` and a Pending publish block that quotes the commands in WP10.

Expected delta: about +400 (film + steps + how-to).

Check: `python3 -c 'import json; json.load(open("game/tests/ui_movie_manifest.json")); json.load(open("website/assets/ui_movie_manifest.json"))'` and `diff` of those two files is empty. C-web (`python3 tools/website_demos.py check` still 12 curated; `scripts/sx-check-website-demos --offline` passes). Do not run the film yet (WP9 does, once).

Revert: if the manifest diff or the offline website check is red after two attempts, revert. Do not hand-edit `website/features.html`. Do not bump `EXPECTED_COUNT`.

### WP9 — Demo test `run_film_flanged_pipe_tests.gd`

Goal: one suite owns the film. It fails when the end state is not the checked part.

Files:

- `game/tests/run_film_flanged_pipe_tests.gd` (`extends "res://tests/lib/sx_suite.gd"`, banner `print("film flanged_pipe")`). `FilmHarness.boot(self, Vector2i(1600, 900))`, `manifest_entry("flanged_pipe")`, `load_film`, `await film.run_film(ctx)`. Then, as a validation test: `FilmUI.fail_count == 0`; one body; bbox 225 × 225 × 520 within 0.2 (`PART` `FLANGE_D` and `BBOX_MAX - BBOX_MIN`, read them via `SxChecker.run("rung05", ["params"])`, do not type a second copy of the millimetres); `last_graph_error` empty.
- Export with `doc.export_3mf` on a `ProjectSettings.globalize_path` temp path. `SxChecker.run("rung05", ["final", path])` exit 0 and the text contains `10/10 passed`. No hard-coded volume.
- Feature names: equal to the list this film's timeline actually produces. Capture it from the first green run of this suite and pin that string in the test in the same commit (the way `run_film_tutor1_tests.gd` pins `FEATURES`). Do not invent the list in advance. Order is part of the pin. Fillet edge count is 4 according to the walk; pin the number the green run printed, and say which in the commit message.
- `packaging/ci/suites.d/film_flanged_pipe_tests.suite`: `script=tests/run_film_flanged_pipe_tests.gd`, `tier=full`, `timeout=420`. No `render=` key (the film does not call `get_texture`; dummy is correct). Commit the `.uid`.

Expected delta: about +150, plus one suite file.

Check: C-one `--only 'film_flanged_pipe_tests.suite'` passes. C-lint prints `233 suites ok (75 ci, 154 full, 4 known-red)`. C-one `--only 'film_manifest_smoke.suite'` prints `- smoke skip flanged_pipe` and does not print `- smoke flanged_pipe`.

Revert: if the suite is red after two attempts, revert WP9 and WP8 (the film has no owner otherwise) and park Part B in §11. Do not weaken `10/10` or the bbox.

### WP10 — Render, poster, publish note

Goal: a video and a poster from the existing movie scripts, and a written record that this token cannot put the video on the Release.

Files: `website/assets/screenshots/flanged_pipe.png` (the only binary). `docs/plan/STATUS.md` Pending publish under the Post-rung-5 entry you add in this commit (short: what WP8–WP9 added, suites **229 run + 4 known-red**, the token limitation). `docs/howto/flanged-pipe.md` already has the commands.

Change:

1. Calibrate with `scripts/sx-movies one precision_plate`, then `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-movies one flanged_pipe` under `tmux` (`DISPLAY=:1`). If the wall-time estimate from the plate (plate seconds × flanged_pipe duration / plate duration) exceeds 90 minutes, rerun with `SX_MOVIES_FPS=24`.
2. `ffprobe`: VP9, 1600×900, container duration within 10% of the caption timeline. Copy `flanged_pipe.webm` and `flanged_pipe.vtt` to `/opt/cursor/artifacts/`. Do not `git add` them.
3. Poster: the last picture of the **video track**, not a seek that falls past it. `lesson2_box` / `tutor1` dropped duplicate frames, so the video track ended before the container and `ffmpeg -sseof -0.1` on the muxed file missed the picture (STATUS, Post-rung-2/3 cleanup). Use the video-track end (`ffprobe -show_entries stream=duration` vs format duration) and grab that frame into `website/assets/screenshots/flanged_pipe.png`.
4. `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-publish-demo-movies --dry-run --feature flanged_pipe`. Keep the output in the STATUS note.
5. `gh release view demo-movies -R solidexpress/solidexpress --json assets --jq '.assets[].name'`.
   - If `flanged_pipe.webm` is listed: add a `website` object on the manifest entry, bump `EXPECTED_COUNT` to 13 in `tools/website_demos.py` (and its test), `SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature flanged_pipe`, commit the JSON, `scripts/sx-check-website-demos`.
   - If it is not listed (expected; this token has no push on the Release): do not add `flanged_pipe` to `published-demos.json` or `demo-catalog.json`. Do not add a `website` object. STATUS Pending publish is exactly:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber flanged_pipe.webm flanged_pipe.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature flanged_pipe
```

Then one follow-up commit of the two JSON files (and the `website` object + `EXPECTED_COUNT`) by a person who can upload. `website/features.html` renders `demo-catalog.json` ∩ the live Release list. Do not hand-write a card.

Expected delta: one PNG plus a short STATUS section.

Check: C-web. `git status` shows no `.webm` or `.vtt`.

Revert: if the offline check fails because the poster or the manifest is wrong, fix the poster path or revert the website file. Do not delete the film to go green.

### WP11 — The single full pass

Goal: one run that builds, checks, and walks. Counts match the rung-5 result, plus the new film suite.

Command (this is the pass; do not also run `make test` or a second `run_suites.sh`):

```bash
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export OCCT_PREFIX=/opt/occt-8.0.1
tools/confirm_all.sh
```

`confirm_all.sh` builds, imports, runs kernel + lints + `test_check_rung02.py` … `test_check_rung05.py` + `test_walk_registry.py` + `run_suites.sh --tier full --keep-going` once, then the five walks on `:21` … `:25` reading `SX_CONFIRM_DIR`.

Required lines in its summary:

| Bar | Count |
|---|---|
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
| Headless | **229 run, 0 failed** |
| Lint | `233 suites ok (75 ci, 154 full, 4 known-red)` |
| Film | `film_flanged_pipe_tests` is among the 229 and is not failed |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 229.

If Part B was reverted, the headless count stays **228** and there is no `flanged_pipe` film; say so and do not invent the video. If a ★ WP was parked, say so; the bars do not change.

This WP has no product commit unless a count is wrong and the fix is a one-line correction you can justify from a WP above. A red bar is a report, not a silent edit. Do not wait for CI.

Write `docs/loop/post-rung-05-result.md` with the table, shipped/parked WPs, and the pending upload line. Push that commit.

## Acceptance

WP11's summary shows the table above (or the reduced table if a WP was reverted and §11 says so). `make` was not run a second time beside `confirm_all.sh`. No video file is in git. `flanged_pipe` is absent from `published-demos.json` and `demo-catalog.json` unless the Release listing in WP10 contained `flanged_pipe.webm`.

## Final report (keep it short)

Branch name. One line per WP: number, title, done or parked, net lines. Then the WP11 counts (walks 77/77, 44/44, 46/46, 32/32, 36/36, `check_rung05` 10/10, headless 229 or 228) and the pending `gh release upload` line if the WebM was not on the Release. Head sha. No other prose.
