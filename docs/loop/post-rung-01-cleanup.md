# Post-rung-01 cleanup — code and tool organization, then the wrench demo film

Status: planned. Docs only. Baseline: `main` `202c448` (`Bump VERSION to 0.0.13`, PR #241; verified with `git fetch origin main` when this plan was written). Rung 1 (UBC wrench + nut) passed its 77-row GUI checklist through `tools/walk_rung01.py`; the headless tier is 204 suites (60 `ci` + 144 `full`) plus 4 `known-red` manifests. Previous plan: [`rung-01-replan-21.md`](rung-01-replan-21.md) (the checklist the walk implements; kept). Runner contract: [`automation-bridge.md`](automation-bridge.md).

**Prompt for ONE BUILD agent (grok-4.6 medium).** Execute WP1 to WP16 below in order, one commit per WP, in a single PR. This file is the only prompt: no per-WP files, no parallel waves. Behaviour must not change. Part A (WP1–WP13) is code and tool organization. Part B (WP14–WP16) is the wrench demo film and its website entry.

## Why this shape

Rung 1 took 21 re-plans. Each round added a test script named after its round, copied the helpers it needed, and left a plan doc behind. The product is green, but the repo is organized by *when* things were written, not by *what they are*. Measured on `202c448`:

| Fact | Number | Source |
|---|---|---|
| Docs in `docs/loop/` | 93 files, 22,595 lines, 2.1 MB; 89 of them (21,741 lines) are per-round plans, per-WP files and leftovers | `ls docs/loop`, `wc -l` |
| `run_*.gd` test scripts | 209 scripts, 87,856 lines; 149 are `run_rung01_*` (71,867 lines) | `wc -l game/tests/run_*.gd` |
| `func check(...)` copies | 209, all hand-pasted: 203 are the same body up to parameter names and spacing, 6 differ (`run_film_manifest_smoke.gd` and `run_film_caption_tests.gd` have no `checks` counter; `run_rung01_replan15_chain`, `replan15_jawstub`, `replan16_walk`, `replan17_walk` track a `_stage`) | md5 of function bodies |
| Duplicated input helpers across tests | `_boot` 106 copies (1,617 lines), `_zoom` 48 (1,232 lines, 8 variants), `_push_key` 66 (872 lines, 42 variants), `_x11_click_screen` 45 (805 lines), `_click_uv` 59 (425 lines), `_x11_click` 43 (232 lines), `_type_text` 21 (218 lines) | md5 of function bodies |
| Suites whose checks are a subset of another suite | `run_rung01_replan15_chain.gd` (1,775 lines): 106 of 106 labels also in `run_rung01_replan15_jawstub.gd`. `run_rung01_replan16_walk.gd` (1,821 lines): 122 of 123 labels also in `run_rung01_replan17_walk.gd`, whose header says "Copy of the replan16 walk plus…". | label-overlap probe (Appendix B) |
| `game/scripts/sketch_mode.gd` | 10,136 lines, 417 funcs, 109 vars; `Tool` enum with 19 members is `match`ed in 9 separate tables (`_undo_tool_label`, `tool_arm_hint`, `variants_for_tool`, `numeric_field_key`, `click`, `_update_preview`, …) | `grep 'match tool'` |
| Tool metadata in four places | `SketchMode.Tool`, the rail table in `main.gd` (`SketchMode.Tool.SELECT, "select", "Select (S)", "Select"` … lines ~910–925), `TOOL_NAMES` in `automation_bridge.gd`, the family map in `main.gd` ~1870 | read |
| `game/scripts/main.gd` | 4,596 lines; `_work_mode` is a bare string compared 16 times; File menu is magic ids 0–15 plus a parallel `FileAction` enum | read |
| `sxkernel/src/features.cpp` | 2,295 lines; `FeatureGraph::apply` is one `switch` of ~1,060 lines (lines 969–2030). Fillet, Chamfer, Shell, Offset, Draft, Mirror, patterns and Boolean already delegate to `src/features/ops_*.cpp`; the other 25 cases are inline (Extrude/Revolve 210 lines, Loft 142, Sweep 70, DirectEdit 63, Hole 56, Wrap 55, Path 49 …). `to_string`, `feature_type_from_string` and `creates_body` are three hand-written name/enum/policy lists. | read |
| `tools/walk_rung01.py` | 3,385 lines, one `Walk` class, 78 `row_*` methods dispatched by `getattr` through the `ROWS` and `CHUNKS` lists; five inline `import re` / `import math` | read |
| `tools/lint_rung01_e2e.py` | 573 lines; twelve near-identical `_lint_replanN` functions, one hard-coded `expected 10 run_rung01_replan12_*.gd` | read |
| Dead code | 23 GDScript functions with zero other references (list in WP3); 5 kernel API functions with zero callers; `docs/index.html`, `docs/features.html`, `docs/assets/` are a stale second copy of `website/` (GitHub Pages is not enabled on this repo: `gh api repos/solidexpress/solidexpress/pages` → 404) | Appendix A |
| CI | the OCCT cache + build block is pasted 6 times: `ci.yml` (3), `linux-test-build.yml` (1), `release.yml` (2) | `grep install_occt .github/workflows/*.yml` |

## Invariants (every WP, no exceptions)

Behaviour is identical. A WP is done only when all of these hold at its commit:

1. `make build && make test-kernel` pass (kernel Catch2 + `sxvoice_tests`).
2. `make test-tools` and `python3 tools/lint_rung01_e2e.py` pass (this includes `lint_suites`).
3. The Godot tier is green: every manifest with `tier=ci` or `tier=full` passes (`suites: N run, 0 failed`). **N is 204 at the baseline and drops only by the suites WP6 retires** (Decision 1). The 4 `known-red` manifests do not regress.
4. The rung-1 walk is green at the checkpoints below: `OCCT_PREFIX=/opt/occt-8.0.1 DISPLAY=:1 python3 tools/walk_rung01.py --a15 --out /tmp/sx-walk` gives 77/77 PASS, checkers blank 5/5, wrench 28/28, noext 28/28, thick 7/7, wrench at T=14 shows exactly 4 by-design DIAG failures, nut 7/7. The walk's A15 row already runs `lint_rung01_e2e`, `lint_suites` and the whole `make test-godot`, so one walk is also a full-tier run.
5. **Check-count ledger unchanged.** `grep -E '^[0-9]+ checks, [0-9]+ failures$' <test-godot log>` after the WP must equal the baseline ledger (WP1) line for line, except the lines of the two suites WP6 retires and the one intentional `+1` check WP6 adds to `run_rung01_replan17_walk.gd`. This catches a codemod that silently drops a check.

### Gate names used below

| Gate | Command | When |
|---|---|---|
| G-fast | the WP's own command (listed per WP), usually `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --only '<glob>'` | after every edit batch |
| G-ci | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --tier ci` (the 60 suites CI runs) | end of every WP that touches `game/` |
| G-kernel | `make build && make test-kernel` | end of every WP that touches `sxkernel/`, `sxcore/`, `sxvoice/` |
| G-tools | `make test-tools && python3 tools/lint_rung01_e2e.py` | end of every WP that touches `tools/`, `packaging/ci/`, `game/tests/` |
| G-tier | `mkdir -p /tmp/sx-after && KEEP_GOING=1 make test-godot 2>&1 \| tee /tmp/sx-after/test-godot.log`, then `diff /tmp/sx-base/ledger.txt <(grep -E '^[0-9]+ checks, [0-9]+ failures$' /tmp/sx-after/test-godot.log)` (invariant 5) | checkpoints CP1, CP2, CP3 |
| G-walk | the walk command of invariant 4 | checkpoints CP2, CP3 |

Checkpoints: **CP1** after WP6, **CP2** after WP10, **CP3** at the end of Part A (after WP13, or after the last WP not parked). Part B needs G-ci, G-tier for its own suite, and the website check, not a second walk.

Environment (from `AGENTS.md`): `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib:$LD_LIBRARY_PATH` for every direct `tools/godot/godot` call; `DISPLAY=:1`; Godot is `tools/godot/godot` 4.7-stable. `make test-godot` bakes `game/.godot` on the first run. Never pass `user://` or `res://` into GDExtension C++.

### Protected files and pins (do not change meaning)

- `tools/check_rung01.py` is the oracle. Do not edit it, do not replace its hand-rolled mesh code with a library (rejected below).
- The walk's A15 row pins literals. They are listed here so nothing breaks silently: `"5 replan21 scripts are clean"` in the e2e lint output, `"208 suites ok"` and `"4 known-red"` in the `lint_suites` output, `suites: >=204 run, 0 failed`, and fifteen banner + floor pairs (`rung01 wrench walk` ≥ 702 checks, `rung01 replan19 keys` ≥ 151, `shield` ≥ 32, `jaw` ≥ 77, `hint` ≥ 30, `glyphs` ≥ 83, `timeline` ≥ 75, `camera` ≥ 25, `fillet pick` ≥ 44, `polish` ≥ 68, `rung01 replan21 sketch undo` ≥ 40, `angle` ≥ 80, `pick` ≥ 36, `dressup` ≥ 20, `state` ≥ 40). `_a15_floor` finds a banner, then the next line matching `(\d+) checks, (\d+) failures`. **Keep those 15 suites, their `print("rung01 …")` banners and their check counts.** WP6 rewrites the literals that depend on the suite count; nothing else in A15 changes.
- Do not rename or delete any `run_rung01_replan19_*`, `run_rung01_replan21_*` or `run_rung01_wrench.gd`.
- `suites.baseline` is a ratchet: a name leaves it only in the commit that deletes the suite (WP6).
- New `.gd` files need their `.gd.uid` committed (run `make import`, then `git add game/**/*.uid`). Deleted `.gd` files take their `.uid` with them.
- Never commit `.webm`, `.mp4`, `.avi`, `.mov` or `.vtt` anywhere (`scripts/sx-check-website-demos` fails the build).

### Rules for the BUILD agent

- One commit per WP, message `Post-rung-1 cleanup WP<n>: <title>`. Push after every WP; open the PR after WP1 (draft), mark it ready at the end.
- **Revert rule.** If a WP's gates are red after two honest attempts, `git revert` that WP's commit, note what failed and which suite in the PR body (the Parked-work step after WP13 writes it to `docs/plan/roadmap.md`), and continue with the next WP. Never loosen a check, never raise a timeout, never edit `suites.d` tiers to get green.
- **Stop line.** WP11, WP12 and WP13 are marked ★. Record `date` in WP1. Start a ★ WP only if all earlier gates are green and less than 6 hours of wall time have passed since WP1. A skipped ★ WP is parked, not partly done.
- Quick CI after each push is **kernel, godot-smoke, website-demos**. Use `get_ci_status` on the PR. Never wait for `windows-export` or `macos-kernel`.
- Do not use any new third-party dependency. Do not add comments that narrate the change.

## Ranked refactors (the survey)

Ranked by payoff per unit of risk. "In PR" is the WP that does it; "Parked" rows are written to the roadmap by the Parked-work step after WP13 so nothing lives only here.

| Rank | Refactor | What / where | Design that replaces the conditionals or copies | Expected reduction | Risk | Verified by | In PR |
|---|---|---|---|---|---|---|---|
| 1 | Purge loop-doc clutter and the stale `docs/` site copy | `docs/loop/*` (89 files), `docs/index.html`, `docs/features.html`, `docs/assets/` | Keep four loop docs plus an index; history stays in git | −21,741 lines in 89 files; −~620 lines of stale HTML/JSON | none (docs) | `scripts/sx-check-website-demos --offline`, grep for inbound links | WP2 |
| 2 | One `SxSuite` base for test scripts | 209 `game/tests/run_*.gd` | `check`, `checks`, `failures`, `finish()` live in `tests/lib/sx_suite.gd`; scripts `extends "res://tests/lib/sx_suite.gd"` | ≈ −2,000 lines | low (tests only) | ledger diff, G-tier | WP4 |
| 3 | One `SxInput` library for pointer and key helpers | `_push_key`, `_click_uv`, `_zoom`, `_x11_click*`, `_type_text`, `_hover_uv`, `_boot`, `_keycode_for_char` pasted in 20–106 scripts | static functions in `tests/lib/sx_input.gd`; `SxSuite` keeps one-line delegates so call sites do not change; scripts keep only variants that differ on purpose | ≈ −2,500 to −3,500 lines | low-medium (a variant may differ in a way a check relies on) | ledger diff, G-tier | WP5 |
| 4 | Retire suites fully covered by another suite | `run_rung01_replan15_chain.gd`, `run_rung01_replan16_walk.gd` | the one missing label of the replan16 walk moves into the replan17 walk first | −3,596 lines, −2 suites | low | label-overlap probe before and after, G-tier | WP6 |
| 5 | Dead code | 23 GDScript functions, 5 kernel functions | delete | ≈ −250 lines | low (compile + parse) | G-kernel, G-ci | WP3 |
| 6 | `lint_rung01_e2e.py` as a rule table | `tools/lint_rung01_e2e.py` | one `RULES` list of `(glob, forbidden needles, structural checks)`; scans `tests/lib/sx_*.gd` too | 573 → ≈ 250 lines | low-medium (a lint can silently weaken) | mutation fixtures in a new `tools/test_lint_rung01_e2e.py` | WP7 |
| 7 | Split `walk_rung01.py` into a package with a row registry | `tools/walk_rung01.py` (3,385 lines, 78 rows) | `tools/walk/` with `harness.py`, `ui.py`, `jaw_geometry.py`, `rows_chunk1.py` … `rows_chunk6.py`; `@row("A8", chunk=3)` registers rows and replaces `ROWS`, `CHUNKS` and `getattr(self, "row_" + id)` | no net lines; largest file 3,385 → ≤ 700 | medium (only the 10-minute walk checks it) | `--rows` subsets, then the full walk, report diff | WP8 |
| 8 | Kernel feature table and `apply` split | `sxkernel/src/features.cpp` | one constexpr `FeatureTypeInfo` table (name, `creates_body` policy) drives `to_string`, `feature_type_from_string`, `creates_body`; the 25 inline `case` bodies move to `src/features/ops_*.cpp` behind the existing `ApplyCtx`; `apply` becomes a lookup in a handler table | `features.cpp` 2,295 → ≈ 1,100; `apply` 1,060 → ≈ 60 lines; −70 lines of name tables | medium (mechanical moves, many captured locals) | G-kernel after every moved case, then CP2 | WP9 |
| 9 | Table-driven `main.gd` menus and work modes, command table in the bridge | `main.gd` `_on_file_menu`, `FileAction`, `_work_mode`; `automation_bridge.gd` `_run` | `FileActionSpec` rows `{label, filter, mode, handler}` build the menu and the dialog dispatch; `WorkMode` enum plus one `{rail visibility, overlay}` row per mode; bridge `COMMANDS` dictionary `{name: {handler, settle_frames, reports_disposition}}` | ≈ −150 lines of `match`/`elif`, magic ids gone | medium (UI, ids are used by tests) | menu/ui suites, bridge suite, walk | WP10 |
| 10 ★ | One geometry helper instead of seven | `_point_segment_distance`, `_point_segment_distance2`, `_point_line_distance`, `_segment_rect_distance`, `_rect_gap`, `_point_rect_gap_px` in `sketch_mode.gd`; `_point_segment_distance2/3`, `_closest_point_on_segment3` in `document_view.gd` | `SketchGeom` static helpers built on Godot's `Geometry2D.get_closest_point_to_segment`, `Geometry2D.segment_intersects_segment`, `Geometry3D.get_closest_point_to_segment` | ≈ −90 lines | medium (pick tolerances are tuned; degenerate segments) | sketch suites, walk | WP11 |
| 11 ★ | `SketchToolSpec` registry | `sketch_mode.gd` nine `match tool` tables, `main.gd` rail table and family map, `automation_bridge.gd` `TOOL_NAMES`, `viewport_interaction.gd` 38 `Tool.` comparisons | one `SketchToolSpec` row per tool: id, label, rail hint, shortcut, icon, default variant, variants, numeric-field key, undo label, arm hint, `draws_with_points`; `match tool` becomes `spec.<field>`; click and preview stay in `SketchMode` but are looked up by spec | ≈ −300 lines of conditionals; adding a tool = one row | medium-high (touches every sketch tool) | all sketch suites, walk | WP12 |
| 12 ★ | CI composite action for OCCT | `.github/workflows/ci.yml` (3 blocks) | `.github/actions/setup-occt/action.yml` (cache + `install_occt.sh`) | ≈ −70 lines | low, but only CI exercises it | quick CI | WP13 |
| 13 | Parked: split `SketchMode` | `sketch_mode.gd` jaw trim (~1,500 lines: `_trim_open_jaw` … `_seal_tangent_bosses`) and dimension / glyph label layout (~2,700 lines, `_rebuild_dimension_labels` … `_repel_glyph_items`) | `JawTrim` and `SketchLabelLayout` as `RefCounted` helpers that receive a narrow context (sketch, camera, view rect) instead of reading 100 members | 10,136 → ≈ 5,500 lines | high (reads ~100 members, 20 rounds of tuning) | walk rows A8–A11, N21–N26, L12 | parked |
| 14 | Parked: split `ViewportInteraction` | 24 `_strip_*` members and 15 `_sketch_*` press/release members, a 299-line `_input` | `SelectionStrip` as its own `Control`; `SketchPointerGesture` state machine (press, release, box, abandon, swallow) | 8,000 → ≈ 6,500 lines | high (input; dead first clicks took rounds 17–19) | `tools/gui_click_probe.sh`, walk | parked |
| 15 | Parked: `CommandRegistry` drift | `command_registry.gd` documents keys; live handlers bind them locally | handlers register against the table | small | medium | `run_help_tests.gd` | parked |

### Libraries considered

| Candidate | Decision | Why |
|---|---|---|
| Godot built-in `Geometry2D` / `Geometry3D` | **use** (WP11) | already in the engine; replaces hand-rolled segment math |
| `magic_enum` (C++ enum↔string) | **no** | a new third-party header and `NOTICE` entry for one 35-entry enum; a constexpr table also carries the `creates_body` policy |
| GUT / GdUnit4 | **no** | would re-plumb 209 `--script` suites, the runner, the 15 A15 floors and CI; `SxSuite` gets the same dedupe at no dependency cost |
| `trimesh` for `check_rung01.py` | **no** | the checker is the oracle for 28/28; changing its mesh code changes what "pass" means |
| `pytest` | **no** | `unittest` already runs under `make test-tools` |

## Decisions (final: the BUILD agent does not choose)

1. Count arithmetic: after WP6 the suite counts are **204 − 2 = 202** run (59 `ci` + 143 `full`) and 4 `known-red`; `lint_suites` prints `206 suites ok (59 ci, 143 full, 4 known-red)`. The user-facing "204" in the task was the baseline; two suites are retired on purpose.
2. A15 derives its counts from the tools instead of literals (WP6): it parses `lint_suites: N suites ok (C ci, F full, R known-red)` and requires the `make test-godot` line `suites: X run, 0 failed` with `X == C + F`. The 15 banner/floor pairs stay as they are.
3. `tests/lib/sx_suite.gd` is extended by **path** (`extends "res://tests/lib/sx_suite.gd"`), not by `class_name`: headless `--script` runs can start before the global class cache knows a new name (the note at the top of `movie_maker_run_one.gd` records the same trap).
4. Scripts whose `check` or helper differs from the canonical one in behaviour keep their own override and call `super.check(cond, what)`; the codemod never guesses.
5. The press/release lint (`no await between pressed=true and pressed=false`) must scan `tests/lib/sx_input.gd`, because the helpers it targets move there. Do this in WP5, in the same commit.
6. No `.webm` is ever committed. The film is rendered outside the repo tree (`/tmp/sx-movies`), attached to the PR as an artifact, and published by a person with write access (this token has none: `gh api repos/solidexpress/solidexpress.github.io --jq .permissions` → `push:false`). The PR stays green by adding the film to the game manifest and a poster, and by adding its id to `published-demos.json` and `demo-catalog.json` **only when the asset is already on the `demo-movies` Release**.

## Work packages

### WP1 — Baseline, ledger, start time (no code)

1. `git checkout -b cursor/post-rung-01-cleanup-<suffix>` from `origin/main`. Run `date` and write it in the PR body as `start`.
2. `make build`, then `mkdir -p /tmp/sx-base`, then run, saving output:
   - `make test-kernel 2>&1 | tee /tmp/sx-base/kernel.log`
   - `make test-tools 2>&1 | tee /tmp/sx-base/tools.log` and `python3 tools/lint_rung01_e2e.py 2>&1 | tee /tmp/sx-base/e2e.log`
   - `KEEP_GOING=1 make test-godot 2>&1 | tee /tmp/sx-base/test-godot.log`; `grep -E '^[0-9]+ checks, [0-9]+ failures$' /tmp/sx-base/test-godot.log > /tmp/sx-base/ledger.txt`; expect `suites: 204 run, 0 failed`; record the ledger line count (about one line per suite that prints the standard footer).
   - `make test-godot-known-red` and `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --tier known-red --run 2>&1 | tee /tmp/sx-base/known-red.log` (note any `NOW GREEN`).
   - `OCCT_PREFIX=/opt/occt-8.0.1 DISPLAY=:1 python3 tools/walk_rung01.py --a15 --out /tmp/sx-base/walk 2>&1 | tee /tmp/sx-base/walk.log`; confirm `SUMMARY.txt` shows 77 rows all PASS and the checker files `check-*.txt` show blank 5/5, wrench 28/28, noext 28/28, thick 7/7, four DIAG lines at T=14, nut 7/7. Save the verdicts: `python3 -c 'import json; print("\n".join(r["row"]+" "+r["verdict"] for r in json.load(open("/tmp/sx-base/walk/walk_report.json"))["rows"]))' > /tmp/sx-base/walk-verdicts.txt`.
3. If anything is red at baseline, stop and report: this plan assumes a green `main`.
4. Open the PR as a draft (title `Post-rung-1 cleanup: organization pass and wrench demo`). Body: the baseline numbers above and the WP list with checkboxes.

Done when: the five baseline artifacts exist and the PR exists. Nothing in the repo changes.

### WP2 — Loop-doc purge, stale site copy, manifest comments (docs and data only)

1. Keep in `docs/loop/`: `automation-bridge.md`, `linux-test-build.md`, `rung-01-plan.md`, `rung-01-replan-21.md`, this file. Delete the other 89 files (`git rm`). Before deleting, run `grep -rn 'rung-01-\|docs/loop' --include='*' -I . | grep -v '^./docs/loop/' | grep -v '^./.git/'`. Known inbound links: `docs/plan/STATUS.md` (three lines that cite `rung-01-replan-14/15` and sx-035 rules) and `website/README.md` (`linux-test-build.md`, kept). Rewrite the three STATUS lines to cite the rule or gate directly and say "history: `git log -- docs/loop/rung-01-replan-15.md`".
2. Add `docs/loop/README.md` (≤ 30 lines): what remains, that the walk is `tools/walk_rung01.py`, that history is in git (`git log --diff-filter=D --name-only -- docs/loop`), and that `tools/gui_click_probe.sh` stays (it sends real X11 clicks, which the in-engine bridge does not; it is the dead-first-click probe from re-PLAN 17).
3. Delete `docs/index.html`, `docs/features.html`, `docs/assets/` (stale copy of `website/`; Pages is not enabled on this repo). Update the `globs:` front matter of `.cursor/rules/website-published-demo-movies.mdc` and `.cursor/rules/website-latest-release-downloads.mdc` to drop `docs/index.html docs/features.html`. `scripts/sx-check-website-demos` still scans `docs/` for stray video files; leave that loop.
4. The five `tier=full` manifests with the comment `# known-red on main; tier=full so make test-godot still runs it and CI does not` (`camera_tests`, `howto_tests`, `icon_tests`, `infer_tests`, `place_tests`) are green at baseline (the full tier is green). Remove the stale comment line from each file. Do not change `script`, `tier` or `timeout`.
5. If WP1's known-red run printed `NOW GREEN: <script>`, change that manifest to `tier=full` and delete its `reason=` line; otherwise leave the four known-red manifests alone (they are product defects with written reasons; fixing them changes behaviour).

Done when: `scripts/sx-check-website-demos --offline`, `python3 tools/lint_suites.py` and `make test-tools` pass; `grep -rn 'docs/loop/rung-01-replan-\(1[0-9]\|[0-9]\)\b' .` outside this file finds nothing. Reduction: −21,741 lines in `docs/loop`, ≈ −620 lines under `docs/`.

### WP3 — Dead code

1. GDScript: the 23 functions below have exactly one occurrence of their name anywhere under `game/` (definition only; string callers such as `call("name")` or `has_method("name")` would add occurrences, so none exist). Re-run Appendix A first; delete only names it still lists.
   `document_view.gd`: `import_feature_id`, `set_selection_notes` · `main.gd`: `_latest_path_fid`, `hide_timeline_if_idle` · `ops_panel.gd`: `_start_or_apply_dressup`, `_arm_last_hole_move` · `scale_bar_hud.gd`: `set_mm_scale` · `selection_service.gd`: `toggle_in`, `clear_sets`, `primary_from_set` · `sketch_context_chrome.gd`: `_keep_variant_below_finish`, `show_merge_menu` · `sketch_mode.gd`: `_circle_meets_cutter`, `_hole_screen_clearance`, `_add_semicircle`, `set_sketch_picture_size`, `clear_sketch_picture` · `sketch_pad_overlay.gd`: `pads_in_rect` · `timeline_panel.gd`: `_pin_width` · `transform_hud.gd`: `is_pointer_over` · `viewport_interaction.gd`: `_place_input`, `_tree_blocks_pointer` · `world_gizmos.gd`: `set_grid_visible`.
   If `selection_service.gd` ends with no functions left that anything uses, delete the file and its `.uid`; otherwise keep the rest. After deleting a function, delete any `const`, `var` or helper that only it used (re-run Appendix A until it prints nothing new).
2. Kernel: `subd_round_box` (`specialized.hpp`), `describe_edge` (`shape_utils.hpp`), `find_mechanic_tool` (`catalog.hpp`), `add_connector`, `remove_connector` (`document.hpp`) are declared and defined but never called, bound or tested. **Keep any of them whose name appears in `docs/plan/*.md` or `docs/survey/*.md`** (`grep -rn '<name>' docs/plan docs/survey`): a roadmap seam is not dead code. Delete the rest (declaration and definition).
3. `tools/`: no change.

Done when: G-kernel, G-ci and `preflight` pass (`make preflight`), and the Appendix A script prints no new candidates. Reduction ≈ −250 lines.

### WP4 — `SxSuite`: one `check`, one footer

1. Create `game/tests/lib/sx_suite.gd`:
   - `extends SceneTree`; members `var checks := 0`, `var failures := 0`.
   - `func check(cond: bool, what: String) -> void` with the exact current body (`  ok   - ` / `  FAIL - ` prefixes, `printerr` on failure).
   - `func finish() -> void: print("%d checks, %d failures" % [checks, failures]); quit(1 if failures > 0 else 0)`.
   The printed footer must stay byte-identical (`N checks, M failures`): A15's floor parser and the ledger read it.
2. Write a throw-away codemod in `/tmp/codemod_suite.py` (do not commit it). For each `game/tests/run_*.gd` that `extends SceneTree`, has `var failures := 0` and `var checks := 0`, and whose `check` body is, after normalizing parameter names, single-line `if c: print(...)` forms and trailing comments, the canonical one (203 scripts): change `extends SceneTree` to `extends "res://tests/lib/sx_suite.gd"`, delete the two `var` lines and the `check` function, and replace the trailing `print("%d checks, %d failures" % [...])` + `quit(...)` pair with `finish()`. Skip and list the 6 scripts that differ: the two film scripts that have no `checks` counter keep their own `check` and their own `failures`; the `_stage` trackers (`replan17_walk`, `replan15_jawstub`; the other two are retired in WP6, so leave them alone) drop the two `var` lines and call `super.check(cond, what)` from their override after the stage bookkeeping instead of duplicating the counting.
3. Do it in three batches: the first is the A15-floor suites plus `run_rung01_wrench.gd` (`--only 'rung01_replan19*'`, `--only 'rung01_replan21*'`, `--only 'rung01_wrench.suite'`; their banners and counts must match the floors), the second is the remaining `run_rung01_*` scripts, the third is the non-rung scripts. Use `run_suites.sh --tier full --only '<glob>' --list` to see what a glob matches. Run `G-fast` (`packaging/ci/run_suites.sh --only '<glob>'`) after each batch and compare each script's `N checks, M failures` line with `/tmp/sx-base/ledger.txt`.
4. Never touch the banner `print("rung01 …")` lines.

Done when: G-tools, G-ci pass and the ledger of the converted scripts is unchanged. Reduction ≈ −2,000 lines.

### WP5 — `SxInput`: one copy of each input helper

1. Create `game/tests/lib/sx_input.gd` with `static func` versions of the **majority** copy of each helper (take the body that appears most often in the md5 table of Appendix B): `push_key(vp, code, mods)`, `push_mouse(vp, pos, pressed)`, `x11_click_screen(vp, pos)`, `x11_click(ctrl)`, `type_text(vp, text)`, `keycode_for_char(ch)`, `click_uv(ctx, uv, label)`, `hover_uv(ctx, uv)`, `zoom(ctx, center, span)`, `boot(root, tree, size)`. Reuse `FilmUI` (`click_control`, `viewport_click`, `sketch_uv_to_screen`, `model_to_screen`) instead of re-implementing anything it already has; if a majority body duplicates a `FilmUI` function, call it.
2. In `SxSuite` add one-line delegates with the **old names and signatures** (`func _push_key(vp, code, mods = 0): await SxInput.push_key(vp, code, mods)` and so on) so no call site changes.
3. Codemod (again in `/tmp`): in every script, delete a helper definition only when its body is byte-identical to the majority body; any other variant stays and is renamed `_<name>_local` only if its signature differs from the base delegate (a signature mismatch is a parse error). List the kept variants in the PR body.
4. **Lint, same commit** (Decision 5): in `tools/lint_rung01_e2e.py` add `game/tests/lib/sx_suite.gd` and `game/tests/lib/sx_input.gd` to the scanned sources for the press/release rule (`_lint_x11_click_await`) and the forbidden-needle lists, and keep every existing per-glob check as it is. Prove the lint still bites: temporarily put `await get_tree().process_frame` between `pressed = true` and `pressed = false` in `sx_input.gd`, confirm `python3 tools/lint_rung01_e2e.py` fails, revert.
5. Batches as in WP4, `G-fast` after each.

Done when: G-tools, G-ci pass, ledger unchanged for every converted script, mutation check done. Reduction ≈ −2,500 to −3,500 lines. Note: `run_rung01_wrench.gd` (702-check floor) is converted last in this WP; verify its check count against the floor right after converting it.

### WP6 — Retire the two fully superseded suites; derive the counts

1. Re-run Appendix B. Proceed only if it still reports `replan15_chain ⊆ replan15_jawstub` with 0 missing labels and `replan16_walk ⊆ replan17_walk` with ≤ 1 missing label.
2. Add the one missing replan16 label to `run_rung01_replan17_walk.gd` as a real assertion at the matching step (read the replan16 walk around that label; the assertion must be genuine, not `check(true, …)`). Its check count rises by 1, which is allowed.
3. `git rm` `game/tests/run_rung01_replan15_chain.gd`, `run_rung01_replan16_walk.gd`, their `.uid` files, and their manifests `packaging/ci/suites.d/rung01_replan15_chain.suite`, `rung01_replan16_walk.suite`. Remove `run_rung01_replan15_chain.gd` from `packaging/ci/suites.baseline` (the walk script was never in it).
4. Update every pin the deletion breaks, found by `grep -rn 'replan15_chain\|replan16_walk\|154\|208 suites\|>= *204' tools packaging game/tests docs/plan`:
   - `game/tests/run_rung01_replan16_suites.gd`: `base_n == 154` → `153`; the message text with it.
   - `tools/test_lint_suites.py`: `assertGreaterEqual(len(baseline), 154)` → `153` (the other `>=` bounds, 29 and 155, still hold); fix any literal that names a deleted file.
   - `tools/walk_rung01.py` row A15 (Decision 2): parse `lint_suites: (\d+) suites ok \((\d+) ci, (\d+) full, (\d+) known-red\)` and require the `make test-godot` line `suites: X run, 0 failed` with `X == ci + full` and `known-red == 4`; drop the `"208 suites ok"` and `>= 204` literals. Keep the `"5 replan21 scripts are clean"` literal (WP7 keeps that line).
   - `docs/plan/STATUS.md`: the line that cites `run_rung01_replan16_walk.gd` now cites `run_rung01_replan17_walk.gd`.
5. Ledger: the two retired scripts' lines leave the ledger; every other line is unchanged.

Done when: `python3 tools/lint_suites.py` prints `lint_suites: 206 suites ok (59 ci, 143 full, 4 known-red)`; G-tools, G-ci pass.

**CP1 (after WP6):** G-kernel, G-tools, G-tier (expect `suites: 202 run, 0 failed`, ledger = baseline minus the two retired lines). No walk yet.

### WP7 — `lint_rung01_e2e.py` as a rule table

1. Replace `_lint_replan3` … `_lint_replan12`, `_lint_replan_n` with one table `RULES: list[Rule]` where `Rule = (glob, forbidden: tuple[str, ...], extra: tuple[Callable, ...], min_files: int)`. Keep every existing needle list (`REPLAN3_FORBIDDEN`, `REPLAN4_EXTRA_FORBIDDEN`, `REPLAN5_FORBIDDEN`, camera needles, `WALK_PRESS_RELEASE_EXTRA`) as named tuples; a rule applies the same needles to the same globs as today. Drop the `expected 10 run_rung01_replan12_*.gd` count; use `min_files` ≥ 1 per rule so a deleted round does not fail.
2. Keep the final output line `lint_rung01_e2e: 5 replan21 scripts are clean` (the A15 literal) and print one line per rule group.
3. Add `tools/test_lint_rung01_e2e.py` (`unittest`): for each needle family, write a fixture `.gd` into a temp tests dir with one forbidden token, run the linter against it (add a `--tests-dir` option, default the repo), and assert exit 1 with the file:line in the output; assert a clean fixture exits 0. Register it in `make test-tools` (Makefile recipe line `python3 tools/test_lint_rung01_e2e.py`).

Done when: G-tools passes; running the old linter (`git stash`-free: `git show HEAD~1:tools/lint_rung01_e2e.py > /tmp/old_lint.py`) and the new one on the same tree both exit 0, and on a tree with one injected forbidden token (`interaction._input` in a replan3 script) both exit 1 with the same file:line. Reduction 573 → ≈ 250 lines plus ≈ 120 lines of tests.

### WP8 — Split `walk_rung01.py` into a package with a row registry

1. Create `tools/walk/` with `__init__.py`, `harness.py` (`Walk` base: process launch/shutdown, `clause`, `verdict_of`, `run_row`, `write_report`, checkpoints), `ui.py` (bridge sugar: `click`, `menu`, `field`, `type_into`, dialogs, `save_as`, `export_3mf`, `open_file`, `file_new`), `jaw_geometry.py` (`jaw_basis`, `wall_screen_points`, `_jaw_wall_screen`, badge/rect helpers), `rows_chunk1.py` … `rows_chunk6.py` (the `row_*` methods, one module per chunk of the existing `CHUNKS`), and `registry.py` with `@row("A8", chunk=3)`.
2. The registry replaces `ROWS`, `CHUNKS` and `getattr(self, f"row_{rid}")`: `ROWS` becomes the registration order within each chunk, so **the order of rows is unchanged** (copy it from the current `ROWS`; a unit test asserts equality with a frozen list of the 77 ids). `EXPECT` and `CHECKPOINT` move next to the rows they describe.
3. `tools/walk_rung01.py` stays as a ≤ 60-line entry point with the same arguments (`--rows`, `--from`, `--a15`, `--checkpoint`, `--app`, `--out`, `--resolution`, `--display`, `--no-launch`, `--godot`, `--port`) and the same behaviour, so every documented command and the A15 text keep working. Move the five inline `import re` / `import math` to the top of their modules.
4. `tools/lint_rung01_e2e.py` reads `tools/walk_rung01.py` as source (`_lint_walk`): point it at the package files (glob `tools/walk/*.py` plus the entry point) so the walk lint still sees the code it lints.
5. Add `tools/test_walk_registry.py`: frozen id list equals registry order; every id has a chunk; every chunk id is in `CHUNKS`-equivalent order.

Done when, in this order: G-tools; `python3 tools/walk_rung01.py --rows N22,A1,A2 --out /tmp/sx-w1` PASS; `--from A15 --a15` PASS; then the full walk equals `/tmp/sx-base/walk-verdicts.txt` row for row. Reduction: no net lines; largest file 3,385 → ≤ 700 lines.

### WP9 — Kernel: one feature-type table, then move the inline `apply` cases

1. `FeatureType` table (`sxkernel/src/features.cpp`, `include/sx/features.hpp`): add `struct FeatureTypeInfo { FeatureType type; const char* name; bool (*creates_body)(const Feature&); }` and one `constexpr` array `kFeatureTypes[]` with the 35 rows. `to_string` and `feature_type_from_string` become loops over it (the error text `unknown feature type: <s>` stays); `creates_body` calls the row's policy (`always`, `never`, `op_is_new`, `mirror_body_mode`, `no_target`, … as small named functions that carry the exact conditions now in the `if` chain). A Catch2 test asserts every `FeatureType` value round-trips through `to_string` → `feature_type_from_string` (`sxkernel/tests/test_features_order.cpp`).
2. Move the inline `case` bodies of `FeatureGraph::apply` into `src/features/ops_*.cpp`, **one case per commit-sized step, in this order** (smallest risk first, build and `make test-kernel` after each): `Primitive`, `Sketch`; `Hole`; `Path`, `Sweep`; `HelixSweep`, `Thread`; `ImportStep`/`ImportStl`; `DirectEdit`; `Rib`, `Thicken`, `Wrap`; `Flange`, `Knit`, `ReplaceFace`; `FrameMember`, `InContext`, `ConvertSheet`, `UserFeature`; `Datum`, `Weld`, `Sketch3D`; `Loft`; `Extrude`/`Revolve` last (210 lines). New files: `ops_solid.cpp` (Extrude, Revolve, Primitive), `ops_sweep.cpp` (Path, Sweep, Loft, HelixSweep, Thread), `ops_hole.cpp`, `ops_import.cpp` (Import*, DirectEdit, ReplaceFace), `ops_misc.cpp` (the rest). Each uses the existing `feature_ops::ApplyCtx` and declares `bool apply_<name>(ApplyCtx&)` in `src/features/ops.hpp`. The sketch-path helpers (`simplify_path_*`, `sketch_ordered_polyline`, `join_polylines`, `chain_points`, `densify_catmull`, lines ~466–900 of `features.cpp`) move with the case that owns them into `src/features/path_geometry.cpp` (declared in `ops.hpp`); `rebind_sketch_support` and the `*_edge_cue` helpers stay with `regenerate`.
3. `FeatureGraph::apply` becomes: resolve params, build `ApplyCtx`, look up `kApplyHandlers[type]` (a `constexpr` array indexed by `FeatureType`, with a compile-time check that every enumerator has a handler), call it; keep the `try { … } catch (Standard_Failure&) … catch (std::exception&)` wrapper and the final `fail("unhandled feature type")`. CMake already globs `src/features/*.cpp`.
4. Behaviour is identical: no parameter, error string or ordering changes. If a moved body used a captured local (`find_feature_body`, `fail`), use the `ApplyCtx` member of the same name.

Done when: G-kernel is green after **every** moved case; at the end G-ci and `sxcore` build (`make build`); then CP2. `features.cpp` ≈ 1,100 lines, `apply` ≈ 60 lines.

### WP10 — `main.gd` file/mode tables and the bridge command table

1. `main.gd` File menu: add `FileActionSpec` rows (`label`, `menu_id`, `dialog_mode`, `filter`, `handler`) in one array; `_populate_file_menu()` builds the popup from it, `_on_file_menu(id)` looks the row up, and the `FileAction` dialog dispatch (`match action:` at ~4245 and ~3098) reads the same row. **`menu_id` keeps today's numbers (0–15)** because `FilmUI.activate_menu_id` and the walk use them. A new `run_menu_tests`-style assertion (extend `run_menu_tests.gd`) checks that every id present today still maps to the same label.
2. `main.gd` work modes: `enum WorkMode { MODEL, DRAW, SHEET, FORM, CAM, SIM }` with a `WORK_MODES` dictionary `{WorkMode.DRAW: {"name": "Draw", "rail": …, "overlay": …}}`; `_work_mode` becomes the enum, `_update_mode_overlays()` and `_update_left_rail()` read the row instead of 16 string comparisons. The menu shows the same names (`names[id]` at ~2178 comes from the table).
3. `automation_bridge.gd`: replace `match cmd:` plus the two inline arrays (`cmd in ["state", "trace", …]`, `cmd in ["click", "double_click", …]`) with a `COMMANDS` dictionary `{"click": {"call": _cmd_pointer, "frames": 2, "reports": true}, …}`. `_run` becomes: normalize, look up, `await call`, apply `frames` and `reports`. The wire protocol (command names, reply keys, `settled_frames`, `trace_cursor`, `disposition`, `focus`, `status`) does not change; `docs/loop/automation-bridge.md` stays correct.
4. G-fast: `packaging/ci/run_suites.sh --only 'menu_tests.suite'`, `--only 'automation_bridge_tests.suite'`, `--only 'ui_tests.suite'`, `--only 'layout_tests.suite'`, `--only 'help_tests.suite'`.

Done when: those, G-ci, G-tools pass. Then **CP2**: G-kernel, G-tier with ledger diff, and **G-walk** (77/77 and the checker lines of invariant 4, verdict list equal to `/tmp/sx-base/walk-verdicts.txt`). If CP2 is red, bisect by reverting WP10, then WP9, and apply the Revert rule to the guilty WP.

### WP11 ★ — `SketchGeom`: one set of segment and rect distance helpers

1. Create `game/scripts/sketch_geom.gd` (`class_name SketchGeom`, static functions): `point_segment_distance(p, a, b)`, `segment_rect_distance(a, b, rect)`, `point_rect_distance(p, rect)`, `point_segment_distance_3d(p, a, b)`, `closest_point_on_segment_3d(p, a, b)`. Implement with `Geometry2D.get_closest_point_to_segment`, `Geometry2D.segment_intersects_segment` and `Geometry3D.get_closest_point_to_segment`. For a zero-length segment return the distance to `a` (the engine does the same).
2. Replace the call sites in `sketch_mode.gd` (`_point_segment_distance`, `_point_segment_distance2`, `_point_line_distance`, `_segment_rect_distance`, `_point_rect_distance`, `_rect_gap`, `_point_rect_gap_px`) and `document_view.gd` (`_point_segment_distance2`, `_point_segment_distance3`, `_closest_point_on_segment3`), one function at a time, deleting the old definition once its last caller is gone. Do **not** change a tolerance constant.
3. Tests may keep their private copies; do not touch them here.

Done when: G-fast = `--only '*sketch*'`, `--only '*picks*'`, `--only '*selectbox*'` (not `rung01_replan12_pick`, which is known-red), then G-ci. Reduction ≈ −90 lines.

### WP12 ★ — `SketchToolSpec`: one row per tool

1. Create `game/scripts/sketch_tool_spec.gd` (`class_name SketchToolSpec`, `RefCounted`) with fields `id: int`, `key: String`, `label`, `rail_hint`, `icon`, `shortcut`, `default_variant`, `variants: Array`, `numeric_key: Callable`, `undo_label`, `arm_hint`, and a static `TABLE` indexed by `SketchMode.Tool`. Move **text and flags only**: the strings now spread over `_undo_tool_label`, `tool_arm_hint`, `variants_for_tool`, `numeric_field_key`, the `set_tool` default-variant `match`, the rail table at `main.gd` ~910–925, the family map at `main.gd` ~1870 and `automation_bridge.gd` `TOOL_NAMES`.
2. Replace each `match tool:` that returns text or a variant list with `SketchToolSpec.of(tool).<field>`. Keep the existing special cases that depend on state (`Jaw armed → no variants`, `Slot with single-DOF preview → "slot_cc"`) as small `Callable`s in the row, not as `if` chains in `SketchMode`.
3. `automation_bridge.gd` `TOOL_NAMES` is generated from the table; a test (extend `run_automation_bridge_tests.gd`) asserts the names equal today's list `["None", "Line", …, "Chamfer"]` in order.
4. **Do not** touch the click handlers, the preview drawing or `viewport_interaction.gd` in this WP; those are parked (rank 13, 14). Convert the 38 `Tool.` comparisons in `viewport_interaction.gd` only where they read text.

Done when: `run_sketch_tests`, `run_sketch_tools_tests`, `run_rung01_replan17_tools`, `run_rung01_replan20_rail`, `run_rung01_sx036_rail`, `run_automation_bridge_tests` and G-ci pass, with the ledger unchanged. Reduction ≈ −300 lines of conditionals.

### WP13 ★ — CI composite action for OCCT (last Part A WP)

1. Create `.github/actions/setup-occt/action.yml` (inputs: `version`, `cache-key`; steps: `actions/cache@v4` on `/opt/occt-<version>`, then `mkdir`, `chown`, `packaging/ci/install_occt.sh`). Use it for the three blocks in `ci.yml` (`kernel`, `macos-kernel`, `godot-smoke`) with the same cache keys they use today (`occt-8.0.1-linux-x64-shared-tbb-freetype-rapidjson-v1`, `…-macos-arm64-…-v1`).
2. Leave `release.yml` and `linux-test-build.yml` unchanged (they do not run on a PR, so a regression would surface only at release time); park the conversion in the Deferred table.
3. Verify with quick CI only: `kernel`, `godot-smoke`, `website-demos` green on the pushed commit. Do not wait for `macos-kernel` (it uses the action too: if it is red when you read it, look at the log once; a bug in the shared action is a revert, a runner flake is not).

**CP3 (end of Part A):** G-kernel, G-tools, G-tier (ledger diff), G-walk. Then write the parked work (below).

### Parked work (written by the BUILD agent at the end of Part A)

Append a section `## 7. Structural debt (deferred refactors)` to `docs/plan/roadmap.md` containing the Deferred table: ranks 13–15 above (with the design column verbatim), the `release.yml` / `linux-test-build.yml` composite-action conversion, every ★ WP that was skipped, and every WP the Revert rule parked (with the failing suite). Add a `docs/plan/STATUS.md` entry "Post-rung-1 cleanup" listing what shipped (WP numbers, line counts removed, suite count 202 + 4 known-red). Then delete nothing else from this file; it is the record.

## Part B — the wrench demo

Goal: a click-driven film of the UBC wrench (the rung-1 build), a headless demo test that fails if the film's end state is not the checked wrench, a rendered video, and a card in the website's features section. Rules that bind: [`landing-protocol.md`](../plan/landing-protocol.md) (movie template, website demos), `.cursor/rules/gdscript-click-driven-tests.mdc` (films click only), `.cursor/rules/website-published-demo-movies.mdc`.

The story is the headless walk's blank-to-export path, compressed (source: `game/tests/run_rung01_wrench.gd` `_walk`, lines ~213–510, and `docs/howto/print-a-wrench.md`): New part → ground sketch → Ø20 pivot circle and Ø45 head circle 200 mm apart, Smart Dimension 200 → Shaft Lines chip → Extrude 10 → sketch on the top face → centre rectangle jaw hex AF 20 at 45° with centrelines → Power Trim → Cut Up To Surface → grip slot R5 → fillets (neck R10, top and bottom faces R1) → timeline edit thickness 10 → 14 → File ▸ Export 3MF.

### WP14 — Film `ubc_wrench`, manifest entry, how-to

1. `game/tests/films/film_ubc_wrench.gd` (`extends RefCounted`, `run_film(ctx)`), following [`film_sketch_tools.gd`](../../game/tests/films/film_sketch_tools.gd): `movie_toast("A parametric wrench, from a blank part to a print file", 2.0)`, then 8 to 10 `beat`s that name the user action ("Draw the pivot and head circles", "Dimension the centres 200 apart", "Add the shaft lines", "Extrude 10", "Open the jaw: centrelines, then Power Trim", "Cut up to the bottom face", "Grip slot", "Round the neck and faces", "Change the thickness to 14 — the jaw and slot stay through", "Export 3MF"), FilmUI/FilmJaw clicks only (`FilmUI.enter_sketch`, `draw_circle`, `set_sketch_dim`, `apply_extrude`, `select_face`, `FilmJaw.draw_on_axis`, `activate_menu_id`, `viewport_click`), then `camera.showcase_smooth`. No private API calls (`set_tool`, `exit_sketch`, `trim_at`, `set_extrude_distance`, …). If a step has no clickable path, **fail the film with `FilmUI._fail` and fix the app or drop the beat**; do not add a bypass. Where the walk needs an `_x11_click`-style helper, call the matching `SxInput` static (WP5) rather than copying it.
2. Length: ≤ 90 s at 30 fps. Set `quit_after` to 3600 (ceiling only).
3. Manifest: append to `game/tests/ui_movie_manifest.json`: `{"id": "ubc_wrench", "title": "Parametric wrench: blank to 3MF", "script": "res://tests/films/film_ubc_wrench.gd", "enabled": true, "quit_after": 3600}` and run `scripts/sx-sync-website` (copies the manifest to `website/assets/ui_movie_manifest.json`; the Pages checkout is absent, which exits 0).
4. How-to: add `docs/howto/ubc-wrench.md` with the exact click path of the film, same numbered style as the other how-tos, and a one-line "see also" from `docs/howto/print-a-wrench.md` (that file describes a different Box + Hole Wizard route; do not rewrite it).
5. `run_film_manifest_smoke.gd` already runs every enabled manifest film headless; confirm it picks the new one up (`--only 'film_manifest_smoke.suite'`).

Done when: `packaging/ci/run_suites.sh --only 'film_manifest_smoke.suite'` passes with `ubc_wrench` in its output, and `scripts/sx-check-website-demos --offline` passes.

### WP15 — Demo test `run_film_ubc_wrench_tests.gd`

1. `game/tests/run_film_ubc_wrench_tests.gd` (`extends "res://tests/lib/sx_suite.gd"`, banner `print("film ubc_wrench")`, **new banner; not one of the 15 A15 floors**). It boots `main.tscn` the way `run_film_manifest_smoke.gd` `_run_one` does (same `FilmContext`, 1600×900 test viewport), loads the film script from the manifest entry, `await film.run_film(ctx)`, then asserts as a *validation* test (kernel and `SxDocument` calls are allowed here): exactly one body; its volume within 0.5 % of the value the walk's `wrench.3mf` has (read it from `/tmp/sx-base/walk/wrench.3mf` once, hard-code the number with a comment naming the source); thickness 14 mm after the timeline step; the feature list has the expected types in order (`sketch`, `extrude`, `sketch`, `extrude` (cut, up to surface), `sketch`, `extrude` (cut, blind 2.5), fillets); `last_graph_error()` empty; `FilmUI.fail_count == 0`.
2. Export through `doc.export_3mf(globalized_temp_path)` (never `user://`), run `python3 tools/check_rung01.py thick <file> 14` and `check_rung01.py wrench <file>` via `OS.execute` the way `run_rung01_wrench.gd` `_run_checker` does, and assert `thick` 7/7 and the four by-design DIAG failures at T=14 (the same facts the walk asserts).
3. Manifest `packaging/ci/suites.d/film_ubc_wrench_tests.suite`: `script=tests/run_film_ubc_wrench_tests.gd`, `tier=full`, `timeout=300`. (`full`, not `ci`: it needs numpy for the checker and runs ~1 minute; `godot-smoke` installs numpy, but the `ci` tier is the CI gate and stays as it is.)
4. Count arithmetic after this WP: `lint_suites: 207 suites ok (59 ci, 144 full, 4 known-red)`; the A15 row derives counts (WP6), so it stays green.

Done when: the suite passes alone (`--only 'film_ubc_wrench_tests.suite'`), G-tools passes, and the final tier run in WP16 shows `suites: 203 run, 0 failed`.

### WP16 — Render, poster, publish tooling, website entry

1. Calibrate: time `scripts/sx-movies one precision_plate` (an existing short film; `DISPLAY=:1`, lavapipe renders on CPU) to learn the seconds-per-frame, then run `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-movies one ubc_wrench` inside `tmux` (session `ubc-wrench-render`). If the estimated render exceeds 90 minutes, rerun with `SX_MOVIES_FPS=24`. Output: `/tmp/sx-movies/ubc_wrench.webm` and `.vtt`. Verify with `ffprobe` (VP9, 1600×900, duration within 10 % of the beat sum) and look at three frames (start, jaw cut, end) with `ffmpeg -ss … -frames:v 1`. Copy `ubc_wrench.webm` to `/opt/cursor/artifacts/` so it is attached to the PR; **do not `git add` it**.
2. Poster: `ffmpeg -y -sseof -0.1 -i /tmp/sx-movies/ubc_wrench.webm -frames:v 1 website/assets/screenshots/ubc_wrench.png`. The poster is the only binary that goes into git (an unpublished poster is allowed by `sx-check-website-demos`; "extra posters are OK").
3. Publishing tooling (the existing `scripts/sx-publish-demo-movies` uploads **every** enabled manifest film and overwrites `published-demos.json` with all of them; with 66 enabled films and 8 published, running it as is would advertise 58 films that have no WebM): add `scripts/sx-publish-demo-movies [--dry-run] [--feature] ID [ID …]`. With ids: render nothing; require `$SX_MOVIES_OUT/<id>.webm`; extract the poster; `gh release upload demo-movies -R solidexpress/solidexpress.github.io --clobber` only those assets; **append** the ids to `website/assets/published-demos.json` (sorted, no duplicates); with `--feature` also append `{"id", "title", "blurb"}` to `demo-catalog.json` `featured` (title from the manifest entry, blurb from an optional `blurb` field you add to the `ubc_wrench` manifest entry). `--dry-run` prints those actions and makes no `gh` call or file change. Without ids the script behaves exactly as today. Add a `unittest` (`tools/test_publish_demo_movies.py`, run in `make test-tools`) that runs the script with `--dry-run` against a temp copy of the JSON files and asserts the planned edits.
4. Website entry, gated on the asset:
   - Run `gh release view demo-movies -R solidexpress/solidexpress.github.io --json assets --jq '.assets[].name'`.
   - **If `ubc_wrench.webm` is listed** (a person uploaded it): run `scripts/sx-publish-demo-movies --feature --dry-run ubc_wrench`, review, then the same without `--dry-run` minus the upload (`SX_SKIP_UPLOAD=1`), commit the two JSON edits, run `scripts/sx-check-website-demos` (online) and expect it green.
   - **If it is not listed (the expected case; this token has no push access):** commit the manifest entry, the poster and the tooling only. Do **not** add `ubc_wrench` to `published-demos.json` or `demo-catalog.json`: the checker refuses a featured id that is not on the Release, and the site must never show a dead play button. Put the exact human step in the PR body and in `docs/plan/STATUS.md` under "Pending publish": `gh release upload demo-movies -R solidexpress/solidexpress.github.io --clobber ubc_wrench.webm ubc_wrench.vtt` (the two files attached to the PR), then `scripts/sx-publish-demo-movies --feature ubc_wrench` with `SX_SKIP_UPLOAD=1`, then a one-line follow-up commit.
5. `website/features.html` needs no markup change: it renders `demo-catalog.json` ∩ the live Release asset list through `assets/demo.js`. Do not hand-write a `data-demo` card.
6. Final gate for Part B: `scripts/sx-check-website-demos` (online) green, `make test-tools`, G-ci, `--only 'film_ubc_wrench_tests.suite'`, `--only 'film_manifest_smoke.suite'`; push; quick CI (`kernel`, `godot-smoke`, `website-demos`) green; mark the PR ready.

## Final report (keep it short)

PR URL, then one line per WP: number, title, outcome (done / parked), net lines. Then three facts: suites run (`202 + 1 = 203`, 4 known-red), walk 77/77, and the pending human step for the video if the WebM was not on the Release. No other prose.

## Appendix A — dead-code finder (GDScript)

Run from the repo root; prints functions defined once and never referenced (the identifier regex also matches inside string literals, so `call("name")` callers count).

```python
import re, glob, collections
files = glob.glob("game/**/*.gd", recursive=True)
text = {f: open(f).read() for f in files}
cnt = collections.Counter(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", "\n".join(text.values())))
engine = {"_ready","_process","_input","_gui_input","_draw","_init","_unhandled_input","_exit_tree",
          "_enter_tree","_physics_process","_notification","_unhandled_key_input","_shortcut_input",
          "_get_drag_data","_can_drop_data","_drop_data","_pressed","_to_string","_get_minimum_size",
          "_has_point","_make_custom_tooltip"}
for f in sorted(files):
    if "/tests/" in f:
        continue
    for m in re.finditer(r"^func ([A-Za-z_][A-Za-z0-9_]*)\(", text[f], re.M):
        if m.group(1) not in engine and cnt[m.group(1)] == 1:
            print(f, m.group(1))
```

## Appendix B — label-overlap and helper-variant probes (tests)

```python
import re, glob, hashlib, collections
def labels(t):
    out = set()
    for m in re.finditer(r'check\((?:[^()"]|\([^()]*\))*?,\s*"((?:[^"\\]|\\.)*)"', t):
        s = re.sub(r"%[-+0-9.]*[a-z]", "#", m.group(1))
        out.add(re.sub(r"\d+(\.\d+)?", "#", s))
    return out
S = {f: labels(open(f).read()) for f in sorted(glob.glob("game/tests/run_*.gd"))}
for f, m in S.items():
    for g, n in S.items():
        if f != g and len(m) >= 3 and len(m & n) / len(m) >= 0.9:
            print(round(len(m & n) / len(m), 2), f, "⊆", g, "missing", len(m - n))
def bodies(name):
    c = collections.Counter()
    for f in glob.glob("game/tests/run_*.gd"):
        for m in re.finditer(r"^(?:static )?func " + name + r"\(.*?(?=^(?:static )?func |\Z)", open(f).read(), re.M | re.S):
            c[hashlib.md5(m.group(0).rstrip().encode()).hexdigest()[:6]] += 1
    return c.most_common(3)
for n in ["_push_key", "_click_uv", "_zoom", "_x11_click_screen", "_x11_click", "_type_text", "_hover_uv", "_boot"]:
    print(n, bodies(n))
```

Expected at the baseline: exactly the three pairs `replan15_chain ⊆ replan15_jawstub` (1.0, 0 missing), `replan16_walk ⊆ replan17_walk` (0.99, 1 missing) and `replan15_jawstub ⊆ replan15_chain` (0.96, 4 missing, **not** a retirement candidate: jawstub stays).
