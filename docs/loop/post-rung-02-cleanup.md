# Post-rung-02 cleanup — layering and de-duplication, then the Lesson 2 box demo film

Status: planned. Docs only. Baseline: `main` `fb627c4` (`Rung 2: SolidWorks Student Guide Lesson 2 box`, PR #246; checked with `git log` when this plan was written). Rung 1 (UBC wrench + nut) walks 77/77. Rung 2 (the Lesson 2 box) walks 44/44; its `final` checker is 16/16 at width 60 and 65. Headless tier at baseline: `lint_suites: 210 suites ok (62 ci, 144 full, 4 known-red)`, so `suites: 206 run, 0 failed`. Checklists the walks implement: [`rung-01-replan-21.md`](rung-01-replan-21.md), [`rung-02-plan.md`](rung-02-plan.md). Runner contract: [`automation-bridge.md`](automation-bridge.md). Previous cleanup, same shape: [`post-rung-01-cleanup.md`](post-rung-01-cleanup.md) (WP2 here deletes it).

**Prompt for ONE BUILD agent (Cursor CLI, grok-4.7 medium).** Execute WP1 to WP15 in order, one commit per WP, in a single PR. This file is the only prompt: no per-WP files, no parallel waves. Behaviour must not change in Part A (WP1–WP12). Part B (WP13–WP15) is the box demo film, its test, the rendered video and the website entry. Part B is not optional and outranks every ★ WP.

## Why this shape

Rung 2 landed as one 55-file PR (+6,663 / −529). The product is green, but the new code copied the rung-1 shape instead of sharing it, and a few "temporary" seams stayed. Measured on `fb627c4`:

| Fact | Number | Source |
|---|---|---|
| Rung classes inherit each other | `WalkApp02` extends `WalkApp`; 33 `row_*` names (`row_A1` … `row_N12`) exist in both rungs' mixins, so a rung-2 row wins only by MRO order; the registry stores `fn.__name__` and finds it again with `getattr` | `tools/walk/app02.py`, `registry.py` `_assemble` |
| Legacy registry mirrors | `registry.ROWS`, `CHUNKS`, `EXPECT`, `ROW_HANDLERS` are module globals refilled by `app.py` lines 24–34 (four `.update()` calls plus two hand-patched variant handlers) for `test_walk_registry.py`; `Rung` already holds the same data | `tools/walk/app.py` |
| Generic base holds rung-1 code | `Walk` (harness) carries `build_open_jaw`, `build_cut_file`, `build_wip_file` and picks a chunk policy with `getattr(self, "_policy_rung01")` from a string on `Rung` | `harness.py` 403–547, `rung.py` `policy` |
| Two copies of each gesture | `ui02.py` (913 lines, 92 methods) re-implements pairs of `ui.py` (387 lines): `save_part`≈`save_as`, `export_and_check`≈`export_3mf`+`checker`, `draw_circle`≈`circle`, `ground_sketch`≈`sketch_ground`, `timeline_rows`≈`_timeline_names`, `edit_label_to`≈`edit_dim`, `sketch_circles`≈`_entities`. Of 50 `ui.py` methods, about 25 are called from both rungs and 20 from rung 1 only (Appendix C) | read |
| Tier gate written twice | rung 1 row A15 and rung 2 row A25 each run `make test-godot` / `run_suites.sh`, parse `suites: N run, M failed` and `lint_suites: … (C ci, F full, R known-red)`; six more `subprocess.run` sites build argv by hand | `rows_chunk6.py` 298–372, `ui02.py` 820–913, `harness.py` 281 |
| Dead Python | 6 functions with one occurrence: `open_checkpoint`, `_off_badges`, `checkpoint_file`, `_left_external`, `_bottom_external`, `click_edge_near` | Appendix B |
| `check_rung02.py` | 535 lines: 156 are `ImplicitPart` ("Tests only", used by `test_check_rung02.py`); `Row` duplicates `geom.R`; `_parse_rest` + `_usage` hand-roll what `argparse` does | read |
| `SketchEdgeRefs` does two jobs | a 32-row string-keyed table (`"between\|circle_center\|external_line"`, rows differ only by `line`↔`external_line`, `circle`↔`arc`, and order) is the Smart Dim intent table, and `convert_click` is Convert-on-a-face. The file header says so; the class name says neither. `convert_click` reads `mode._ensure_sketch_feature`, `_undo_note`, `run_solve`, `_redraw`, `convert_pierce_points`, `host_face_id`, `support_host`, `support_normal` | `game/scripts/sketch_edge_refs.gd` |
| Plane frame stored three times | `SketchMode` keeps `plane_origin`, `plane_x`, `plane_y` as three vars (51 uses in `sketch_mode.gd`, 15 more in 5 files) next to `PlaneBasis`, which is built once and unpacked. `begin_on_plane` and `begin_edit` set the three by hand. `x_hint` is an unused parameter of `begin` and `_setup_plane` (callers pass `Vector3.ZERO`) | `plane_basis.gd`, `sketch_mode.gd` 571–660 |
| "Face with this normal" written four times | `SketchEdgeRefs._face_edge_set` (dot > 0.7, best), bridge `_find_face_by_normal` (≥ 0.999, furthest along the normal), `FilmUI.find_face_by_normal`, and `ShellChrome._face_is_planar` (reads the mesh normals again) | read |
| `ShellChrome` reaches up | `get_parent()` duck-typed twice (`ix.view`, `ix.sketch_mode`); `viewport_interaction.gd` preloads it as `_ShellChrome` while the file also declares `class_name ShellChrome` and calls `has_method("panel")`. `ops_panel._shell()` keeps a second, older Shell apply path behind `has_method("apply_shell_thickness")` | `shell_chrome.gd`, `ops_panel.gd` 1494–1520 |
| Bridge | two caches with the same shape (`_faces_cached`, `_edges_cached`), the new one keyed by a formatted string (`_camera_stamp`); 15 `has_method` guards, 6 of them on `SxDocument` methods that are always bound (`revision`, `body_volume`, `measure_face_area`, `graph_features`); each face record carries `mid` and `centre` with the same value | `automation_bridge.gd` 1870–1980 |
| Kernel: `TopoCue` internals | `Vec3` + hand-written `mag`, `dot`, `normalized` although OCCT's `gp_XYZ` is linked; `planar_normal` (topo_cue.cpp) and `planar_face_normal` (ops_dress.cpp); the "midpoint + unit tangent" sample copied three times (`features.cpp` 975, `topo_cue.cpp` 131 and 236); three number formatters (`format3`, `format_mm`, `shape_utils` `fmt`); the "store the fresh cue unless the stored one names something else" rule written twice (`apply_shell`, `remember_dressup_edge_cues`); `fresh.dir.x == 0.0 && …y… && …z…` twice | `sxkernel/src/features/` |
| Kernel: second memory of the same thing | `FeatureGraph::edge_memory_` stores `{px,py,pz,dx,dy,dz}` per edge id (a `TopoCue` without a fraction) next to the cues; `remember_live_edges`, `cue_still_names`, `remember_dressup_edge_cues` (about 110 lines) live in `features.cpp` (1,227 lines); `sx_document.cpp` reads `recall_edge` | `features.cpp`, `features.hpp` 169–190 |
| Binding layer holds kernel logic | `SxDocument::sketch_add_external_edge` extracts the line endpoints with `BRepAdaptor_Curve`, rejects non-lines and tags construction inside the GDExtension; the kernel's sibling `convert_edges_to_sketch` is in `sketch3d.cpp` | `sxcore/src/sx_document.cpp` |
| Rung-2 suites copy each other | `_build_box` ×3, `_fillet_z_edges` ×2, `_boot` ×3, `_on_status`/`_note_status` ×3, `_distance_edit` ×3, `_only_body` ×2 across the three `run_rung02_*.gd` | `game/tests/` |
| Test helpers still pasted | `_on_status` 82 copies (45 and 23 byte-identical bodies), `_distance_edit` 18, `_boot` 107 (many variants), a `_run_checker` or `OS.execute … tools/check_rung0N.py` block in 8 scripts; `run_film_manifest_smoke.gd` `_run_one` and `run_film_ubc_wrench_tests.gd` each build the same `FilmContext` and load the same film script | Appendix E |
| Film helpers private | `film_ubc_wrench.gd` (494 lines) holds 19 private helpers (`_press_rail`, `_click_uv`, `_type_dim`, `_type_distance`, `_pick_finish`, `_pick_option`, `_select_body`, `_arm_fillet`, `_commit_fillet`, `_fillet_at`, `_export_3mf`, …) that the box film needs too | read |
| Red on `main` | `python3 tools/test_publish_demo_movies.py` fails: it asserts `ubc_wrench` is not in `published-demos.json`, and it now is (the wrench film is on Release `demo-movies`: `gh release view demo-movies -R solidexpress/solidexpress.github.io` lists `ubc_wrench.webm` and `.vtt`). So `make test-tools` is red | run |
| Stale docs | `docs/loop/`: 8 files, 1,723 lines; `post-rung-01-cleanup.md` (executed), `rung-02-build-notes.md` (red output and measurements, already in PR #246) and `rung-01-plan.md` (superseded by the replan-21 checklist) are spent. `docs/plan/STATUS.md` has no rung-2 entry and its "Pending publish" paragraph for the wrench is now false | read |
| Dead GDScript | 3 functions with one occurrence: `timeline_panel._focus_extrude_distance` (replaced by `_focus_row_field`), `ui_spin.rearm_replace_after_commit`, `ui_spin._is_reformat_of` | Appendix A |

Not in this pass (parked, already in [`roadmap.md` §7](../plan/roadmap.md)): splitting `SketchMode` (10,153 lines) and `ViewportInteraction` (8,023 lines), `CommandRegistry` drift. WP2 adds the new debt found here to a new roadmap §8.

## Invariants (every WP, no exceptions)

Behaviour is identical. A WP is done only when all of these hold at its commit:

1. `make build && make test-kernel` pass. If `make` cannot finish `configure` on this VM (the rung-2 build notes record a Boost-header gap), run the same test binaries the recipes run (`build/sxkernel/sxkernel_tests`, `build/sxvoice/sxvoice_tests`) and say so in the PR body.
2. From WP2 on: `make test-tools` passes (it is red at baseline for the reason above) and `python3 tools/lint_rung01_e2e.py` passes.
3. The Godot tier is green: `suites: N run, 0 failed` with **N = 206 through WP12 and 207 after WP14** (Part B adds one suite). No suite is retired. The 4 `known-red` manifests do not regress.
4. **Check-count ledger unchanged.** `grep -E '^[0-9]+ checks, [0-9]+ failures$' <test-godot log>` equals the baseline ledger (WP1) line for line, except the lines the new suite adds in WP14 and checks a WP adds on purpose (each is named in its WP). This catches a codemod that drops a check.
5. **Both walks at CP1 and CP2** (checkpoints below), default resolution `1280x800`:
   - Rung 1: `OCCT_PREFIX=/opt/occt-8.0.1 DISPLAY=:1 python3 tools/walk_rung01.py --a15 --resolution 1280x800 --out /tmp/sx-walk1` gives 77/77 PASS; checker lines blank 5/5, wrench 28/28, noext 28/28, thick 7/7, wrench at T=14 shows exactly the 4 by-design DIAG failures, nut 7/7.
   - Rung 2: `SX_AUTOMATION=1 DISPLAY=:1 python3 tools/walk_rung02.py --a15 --resolution 1280x800 --out /tmp/sx-walk2` gives `44 rows PASS 44`; `check_rung02.py final` 16/16 on `final-60.3mf` and on `final-65.3mf` (`--width 65`); the stage checkers `base`, `rounded`, `shell` print the same `N/N passed` lines as WP1 recorded.
   Each walk's A15 / A25 row already runs the lints and the whole tier, so one walk of each is also a full-tier run.
6. Save files and wire formats do not change: `.sxp` keys (`edge_cues`, `face_cues`, the edge-memory array), bridge command names and reply keys, status texts the rows pin, and automation ids (`strip:shell`, `finish:Thickness`, `finish:Ok`, `rail:*`). The single allowed wire change is WP10's removal of the duplicate `mid` on face records, with both readers migrated in the same commit (Decision 4).

### Gate names used below

| Gate | Command | When |
|---|---|---|
| G-fast | the WP's own command, usually `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --only '<glob>'` | after every edit batch |
| G-ci | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --tier ci` | end of every WP that touches `game/` |
| G-kernel | `make build && make test-kernel` | end of every WP that touches `sxkernel/`, `sxcore/` |
| G-tools | `make test-tools && python3 tools/lint_rung01_e2e.py` | end of every WP that touches `tools/`, `scripts/`, `packaging/ci/`, `game/tests/` |
| G-tier | `mkdir -p /tmp/sx-after && KEEP_GOING=1 make test-godot 2>&1 \| tee /tmp/sx-after/test-godot.log`, then `diff /tmp/sx-base/ledger.txt <(grep -E '^[0-9]+ checks, [0-9]+ failures$' /tmp/sx-after/test-godot.log)` | CP1, CP2 |
| G-walk | the two walk commands of invariant 5, then compare each `walk_report.json` row verdicts with `/tmp/sx-base/walk{1,2}-verdicts.txt` | CP1, CP2 |

Checkpoints: **CP1** after WP7 (kernel, checkers and the walk package are done; both walks run because WP6–WP7 rewrote the runner), **CP2** at the end of Part A (after WP12). Part B needs G-ci, its own suite, `film_manifest_smoke`, and the website check, not a third walk.

Environment (from `AGENTS.md`): `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib:$LD_LIBRARY_PATH` for every direct `tools/godot/godot` call; `DISPLAY=:1`; Godot is `tools/godot/godot` 4.7-stable; `numpy` is installed (the checkers need it). Never pass `user://` or `res://` into GDExtension C++.

### Protected files and pins (do not change meaning)

- `tools/check_rung01.py` is the rung-1 oracle. Do not edit it. `geom.R` keeps working for it (WP5 keeps `R` as an alias).
- `check_rung02.py` row names (`bbox`, `watertight`, `corner R10`, `wall x`, `wall y`, `floor`, `open top`, `hole axis`, `hole Ø10`, `hole only in x walls`, `volume`, `usage`), the final `N/N passed` line, exit codes and the JSON of `params` are pinned by `test_check_rung02.py` and the walk.
- Rung-1 A15 pins `"5 replan21 scripts are clean"`, `known-red == 4`, the derived `suites: X run, 0 failed` with `X == C + F`, and the fifteen banner and floor pairs (`rung01 wrench walk` ≥ 702 … `rung01 replan21 state` ≥ 40). Keep those suites, banners and counts.
- Rung-2 A25 reads `lint_suites`, `test_check_rung02.py`, `test_walk_registry.py` and the binaries; keep those names or update A25 in the same commit.
- Status texts the rung-2 rows pin (`Convert: external line`, `Convert — click an edge of this face`, `Convert: edge is not on this face`, `Shell 5.0000 mm applied`, `Shell needs a planar face — nothing added`, `Shell thickness … (limit) — nothing added`, `Extrude Blind 50.0000 mm`, the six `Sketch on face (plane …)` lines). The list is in `rung-02-build-notes.md`, which WP2 deletes: before deleting, `grep` each text in `tools/walk/` and `game/tests/`; every one must already be pinned there, and any that is not goes into the row that uses it.
- `suites.baseline` is a ratchet. New `.gd` files need their `.gd.uid` committed (`make import`, then `git add game/**/*.uid`); deleted `.gd` files take their `.uid`.
- Never commit `.webm`, `.mp4`, `.avi`, `.mov` or `.vtt` (`scripts/sx-check-website-demos` fails the build). The poster PNG is the only binary Part B commits.
- Do not rename or delete any `run_rung01_replan19_*`, `run_rung01_replan21_*`, `run_rung01_wrench.gd`, `run_rung02_*.gd`.

### Rules for the BUILD agent

- One commit per WP, message `Post-rung-2 cleanup WP<n>: <title>`. Push after every WP. Open the PR (draft) after WP1, mark it ready at the end.
- **Revert rule.** If a WP's gates are red after two honest attempts, `git revert` its commit, note what failed and which suite in the PR body, add the WP to roadmap §8 (WP2 creates it; the last WP of Part A appends), and continue. Never loosen a check, raise a timeout, or edit `suites.d` tiers to get green.
- **Optional WPs.** WP4, WP7 and WP10 are marked ★. Record `date` in WP1. Start a ★ WP only if all earlier gates are green and under 5 hours have passed since WP1; otherwise park it (roadmap §8) and go on. A skipped ★ WP is parked whole, not partly done. If WP12 or WP9 gets reverted, say so: Part B copies the helpers it needs into the film and the PR body records the debt.
- Quick CI after each push is **kernel, godot-smoke, website-demos** (`get_ci_status`). Never wait for `windows-export` or `macos-kernel`; if `macos-kernel` is red, read its log once: a compile error in a file you touched (WP3, WP4: `gp_XYZ`, new headers) is yours.
- No new third-party dependency. No comments that narrate the change.
- Design rule for every WP: where a table, an enum, a small value object or an engine built-in exists, use it instead of adding an `if` branch. Every new file starts with a two-line comment saying what it owns. A reader must understand a function from its file and one narrow parameter object, never from the caller's private members.

## Ranked refactors (the survey)

| Rank | Refactor | What / where | Design that replaces the copy or the conditionals | Expected reduction | Risk | Verified by | In PR |
|---|---|---|---|---|---|---|---|
| 1 | Spent docs, red test, stale status | 3 loop docs, `test_publish_demo_movies.py`, `STATUS.md`, 3 dead GDScript functions, `x_hint` | delete; the test uses temp copies of the JSON; STATUS gets the rung-2 entry | −~600 lines of docs | none | `make test-tools`, grep for inbound links | WP2 |
| 2 | `TopoCue` internals | `topo_cue.h/.cpp`, `ops_dress.cpp`, `features.cpp`, `solver_planegcs.cpp` | `gp_XYZ` instead of `Vec3` + hand math; one `planar_face_normal`, one `edge_midpoint_sample`, one `format_fixed`; one `refresh_cue` used by Shell and the dress-up memory | ≈ −90 lines | low-medium (error texts and cue JSON are pinned) | Catch2 for each helper, G-kernel | WP3 |
| 3 ★ | One cue memory, binding without kernel logic | `FeatureGraph::edge_memory_`, `remember_*` in `features.cpp`, `sketch_add_external_edge` in `sx_document.cpp` | `CueMemory` (a `TopoCue` map, same JSON) in `features/cue_memory.cpp`; `sx::add_external_edge` in `sketch3d.cpp` | `features.cpp` 1,227 → ≈ 1,100; binding −25 lines | medium (save format) | a Catch2 test that loads a pre-change JSON literal, G-kernel | WP4 |
| 4 | Checker tooling | `check_rung02.py`, `geom.py` | `ImplicitPart` to its own test-only module; `Row` folded into `geom.Report` (`R` stays as alias); `argparse` | 535 → ≈ 360 | low | unit tests, byte-compare CLI output on the tests' meshes | WP5 |
| 5 | Rungs own their rows | `tools/walk/registry.py`, `app.py`, `app02.py`, `rung.py`, `harness.py` | `@row` stores the function; `Rung.chunk_start` is a strategy object; no inheritance between rungs; no module-level mirrors | ≈ −80 lines; MRO trap gone | medium (only the walks run it) | `--dry-run` byte-identical, registry test, subset walks | WP6 |
| 6 ★ | One gesture, one gate runner, one `proc.run` | `ui.py` + `ui02.py`, A15 + A25, 6 `subprocess.run` sites | merge each pair to the superset signature; `walk/gates.py` and `walk/proc.py` | ≈ −350 lines | medium | CP1 walks | WP7 |
| 7 | One plane owner; one face query | `plane_basis.gd`, `sketch_mode.gd`, `document_view.gd`, 4 face-by-normal copies | `PlaneBasis` wraps one `Transform3D` (`to_world`, `to_uv`); `plane_origin/x/y` become read-only properties; `DocumentView.faces_matching(body, normal, min_dot)` | ≈ −60 lines | medium (51 uses) | rung-2 plane suite (70 checks), sketch suites | WP8 |
| 8 | Smart Dim table and Convert-edge as two things | `sketch_edge_refs.gd` | `SmartDimTable` (kind enum, classes, ≈ 11 rules instead of 32 string rows); `ConvertEdge` that takes a narrow context of `Callable`s | ≈ −100 lines | medium (every Smart Dim) | a test that old-table and new-table agree on all 75 `(channel, kind, kind)` keys; rung-1 dim suites | WP9 |
| 9 ★ | `ShellChrome` injection, bridge caches | `shell_chrome.gd`, `ops_panel.gd`, `automation_bridge.gd` | context object in place of `get_parent()`; delete the old `_shell()` path; one `ViewCache`; typed calls in place of 6 dead `has_method` guards | ≈ −90 lines | low-medium | menu/ui/bridge suites, CP2 | WP10 |
| 10 | Test library | `SxChecker`, `FilmHarness`, status log in `SxSuite` | one class each for the 8 checker blocks, the two film boot copies, 82 `_on_status` | ≈ −900 lines | low (tests only) | ledger, G-tier | WP11 |
| 11 | Film steps and the box fixture | `film_ubc_wrench.gd`, 3 `run_rung02_*.gd` | `FilmSteps` (click-only statics), `BoxFixture` (validation suites only) | ≈ −450 lines | low | ledger, the wrench film test | WP12 |

### Libraries considered

| Candidate | Decision | Why |
|---|---|---|
| OCCT `gp_XYZ` / `gp_Dir` for `Vec3` | **use** (WP3) | already linked; `Dot`, `Modulus`, `Normalized` replace the hand code; JSON stays arrays of 3 doubles |
| Godot `Transform3D` / `Plane` | **use** (WP8) | uv↔world is `plane * Vector3(u, v, 0)` and `plane.affine_inverse() * p`; `Plane.distance_to` replaces the `absf((mid - origin).dot(n))` test |
| GDScript enums + typed `Dictionary[K, V]` (4.4+) | **use** (WP9) | enum kinds replace `"a\|b\|c"` string keys |
| `Callable` ports in place of private-member reach | **use** (WP9, WP10) | a node is understandable from its constructor argument |
| Python `argparse` | **use** (WP5) | replaces `_parse_rest` / `_usage`; the `usage` row and exit codes stay |
| Python `dataclasses` / `typing.Protocol` | **use** (WP5, WP6) | `Report`, `Row`; `Solid` protocol for the two mesh sources |
| `trimesh` (mesh, volume, ray queries) | **no** | a new dependency for tools that already pass with `numpy`; `check_rung01.py` is the oracle and `geom.py` is shared with it |
| `pytest` / `vulture` | **no** | `unittest` already runs under `make test-tools`; Appendix A and B are the dead-code probes |
| `std::format` (C++20) for `format_fixed` | **no** | Apple libc++ availability on `macos-kernel`; one helper over `std::ostringstream` is enough |
| nlohmann `NLOHMANN_DEFINE_TYPE_*` for `TopoCue` | **no** | the macros cannot express `has_frac` (derived from the presence of `frac`) or the old-cue tolerance |
| Eigen for `Vec3` | **no** | only the `planegcs` target links it |
| GUT / GdUnit4 | **no** | would re-plumb 212 `--script` suites and A15's 15 floors |

## Decisions (final: the BUILD agent does not choose)

1. Count arithmetic: **no suite is retired in Part A**, so N stays 206 through WP12. WP14 adds `film_lesson2_box_tests` (`tier=full`): 207 run, `lint_suites: 211 suites ok (62 ci, 145 full, 4 known-red)`. WP3, WP4, WP5, WP9 add Catch2 cases or `unittest` cases, not Godot suites. A15 and A25 derive counts from the tools, so neither needs a literal edited.
2. `.sxp` compatibility: WP3 and WP4 do not rename `edge_cues`, `face_cues` or the edge-memory array. (Fillet's `face_cues` is an array of `{point, normal}`; Shell's is an object keyed by face id. Same key, two schemas under different feature types. Renaming would need a loader migration: parked in roadmap §8.)
3. WP9's table is checked against the old one before the old one is deleted: dump `SketchEdgeRefs._ROWS` into a frozen dictionary in the new test, assert `SmartDimTable.resolve` returns the same `form`, `point`, `point_role`, `label_anchor`, `also` for every `(channel, kind_a, kind_b)` over the 3 channels and 5 kinds, and `{}` where the old table has no row.
4. WP10 removes `mid` from face records only. Rung 1 reads `f["mid"]` at `ui.py` 167–176 (`top_face`, bottom face); both change to `f["centre"]` in the same commit, and `docs/loop/automation-bridge.md` is updated. Edge records keep `mid`.
5. The edge cache stays keyed by the document revision only (the face cache is also keyed by the camera because rung 2 found stale pixels). Whether edge `screen` positions go stale across a camera move is a latent question; roadmap §8 records it, this pass does not change it. The bridge's timeline-row workaround (`_activate_missed_button`, the timeline branch of `_control_click_pos`) also stays: it compensates for a row rect that the viewport treats as the model, which is a product defect, parked in §8.
6. Part B follows the wrench's publishing rule: the film is rendered outside the tree (`/tmp/sx-movies`), attached to the PR, and published by a person with write access (`gh api repos/solidexpress/solidexpress.github.io --jq .permissions` → `push:false` for this token). The id enters `published-demos.json` and `demo-catalog.json` only when the asset is already on the Release.

## Work packages

### WP1 — Baseline, ledger, start time (no code)

1. `git fetch origin main`, `git checkout -b cursor/post-rung-02-cleanup-<suffix>` from `origin/main`. Run `date`; write it in the PR body as `start`.
2. `make build`, `mkdir -p /tmp/sx-base`, then save:
   - `make test-kernel 2>&1 | tee /tmp/sx-base/kernel.log` (note the `assertions in N test cases` line; it may rise later, never fall).
   - `make test-tools 2>&1 | tee /tmp/sx-base/tools.log` (**expected red**: only `test_publish_demo_movies.py`, fixed in WP2; any other failure stops the plan) and `python3 tools/lint_rung01_e2e.py | tee /tmp/sx-base/e2e.log`.
   - `KEEP_GOING=1 make test-godot 2>&1 | tee /tmp/sx-base/test-godot.log`; `grep -E '^[0-9]+ checks, [0-9]+ failures$' /tmp/sx-base/test-godot.log > /tmp/sx-base/ledger.txt`; expect `suites: 206 run, 0 failed`.
   - `python3 tools/walk_rung01.py --dry-run > /tmp/sx-base/dry1.txt` and `python3 tools/walk_rung02.py --dry-run > /tmp/sx-base/dry2.txt`.
   - The two walks (invariant 5) into `/tmp/sx-base/walk1` and `/tmp/sx-base/walk2`. Save verdicts: `python3 -c 'import json,sys; print("\n".join(r["row"]+" "+r["verdict"] for r in json.load(open(sys.argv[1]))["rows"]))' /tmp/sx-base/walk1/walk_report.json > /tmp/sx-base/walk1-verdicts.txt` (same for walk2). Copy every `check-*.txt` the walks print; record each `N/N passed` line as the checker bar.
   - Golden checker output: for each fixture mesh `tools/test_check_rung02.py` writes, or simply for `final-60.3mf` / `final-65.3mf` from walk2, save `python3 tools/check_rung02.py <stage> <file> [--width W] > /tmp/sx-base/chk-<stage>-<W>.txt` for all four stages.
3. If anything other than the one known test is red, stop and report: this plan assumes a green `main`.
4. Open the PR as a draft (title `Post-rung-2 cleanup: layering pass and the Lesson 2 box demo`). Body: baseline numbers and the WP list with checkboxes.

Done when: the artifacts above exist and the PR exists. Nothing in the repo changes.

### WP2 — Spent docs, the red test, stale status, dead code

1. **Red test.** `scripts/sx-publish-demo-movies` hard-codes `PUBLISHED` and `CATALOG` under `website/assets/`. Add env overrides `SX_PUBLISHED_JSON` and `SX_CATALOG_JSON` (defaults unchanged; document them in the header comment's env list). Rewrite `tools/test_publish_demo_movies.py` to copy both JSON files and a manifest-compatible id into a temp dir, point the overrides at the copies, remove `ubc_wrench` from the temp published list, and assert the dry-run prints the planned append and leaves the temp files byte-identical; add a second case that runs without `--dry-run` and `SX_SKIP_UPLOAD=1` against the temp copies (poster extraction needs `ffmpeg`; the test writes a one-frame webm with `ffmpeg -f lavfi -i color=c=black:s=64x64:d=0.1 -c:v libvpx-vp9` and skips itself with `unittest.skip` when `ffmpeg` is absent) and asserts the id is appended once, sorted, no duplicates, and the real repo files are untouched. Remove the stale `assertNotIn("ubc_wrench", …)` on the repo file and the `-> void` annotation (not a Python type).
2. **Docs.** `git rm docs/loop/post-rung-01-cleanup.md docs/loop/rung-02-build-notes.md docs/loop/rung-01-plan.md`. First run `grep -rn 'post-rung-01-cleanup\|rung-02-build-notes\|rung-01-plan' . -I | grep -v '^./.git/'`; known inbound links: `docs/loop/README.md`, `docs/loop/rung-02-plan.md` line 5, `docs/plan/STATUS.md` line 7, `docs/plan/roadmap.md` line 241. Rewrite each to cite the gate or say "history: `git log -- docs/loop/<file>`". Do the status-text pin check of "Protected files" before deleting `rung-02-build-notes.md`. Update `docs/loop/README.md` to list what remains (`automation-bridge.md`, `linux-test-build.md`, `rung-01-replan-21.md`, `rung-02-plan.md`, this file) and to say this file is deleted by the next cleanup.
3. **STATUS.** Add a "Rung 2 — Lesson 2 box (PR #246)" entry above "Post-rung-1 cleanup": what shipped (`PlaneBasis`, `TopoCue`, Shell chip, Convert on a face, point-line Smart Dim, bridge face identity, `Rung` descriptor, `check_rung02.py`, 44-row walk), the suite count 206 + 4 known-red, the checker bar. Replace the "Pending publish" paragraph under the cleanup entry with one line: `ubc_wrench` is on Release `demo-movies` and in `published-demos.json` and `demo-catalog.json`. (Part B writes the box's "Pending publish" if needed.)
4. **Roadmap §8.** Append `## 8. Structural debt found after rung 2` to `docs/plan/roadmap.md` with a table of: the Decision-2 schema split, the Decision-5 edge-cache question, the timeline-row workaround, the `_dim_user_typed` / `_dim_replace_next` / `_dim_focus_from_tool` / `_dim_select_gen` / `_dim_last_good` flags in `sketch_context_chrome.gd` (13 `_dim_*` vars; design: one `DimEntry` state enum `ARMED_PREVIEW → FOCUSED → TYPED` instead of five booleans; risk high: typed-length and replace-on-focus rules), and a row per ★ WP that gets parked. Link §8 from the "Related" list.
5. **Dead code.** Re-run Appendices A and B first; delete only names they still list: the 3 GDScript functions and the 6 Python functions in the survey table (for `checkpoint_file` also delete the module global it reads). Drop `x_hint` from `SketchMode.begin` and `_setup_plane` and the `Vector3.ZERO` argument at `main.gd` 1631 (`begin_on_plane` is a different function and keeps its arguments). Delete any `const`, `var` or helper only a deleted function used.

Done when: `make test-tools` passes (`test_publish_demo_movies.py` green), `scripts/sx-check-website-demos --offline` passes, `grep -rn 'post-rung-01-cleanup\|rung-02-build-notes\|rung-01-plan' .` outside `.git` finds nothing, G-ci passes, and Appendices A and B print nothing new.

### WP3 — `TopoCue` internals: one vector type, one helper per repeated block

Before each step, diff the copies. If two copies differ in behaviour, keep the difference as a named parameter; never guess which one is right.

1. `topo_cue.h`: replace `struct Vec3` by `gp_XYZ` in `TopoCue` (`point`, `dir`, `size`, `frac`). Delete `mag2`, `mag`, `dot`, `normalized`, `vec_text`'s field access and `Extent::span`'s hand arithmetic in favour of `gp_XYZ` operations; keep one `unit_or_zero(gp_XYZ)` (OCCT's `Normalized` throws on a zero vector, the old code returned zero). Add `bool is_zero(const gp_XYZ&)` using `SquareModulus() == 0.0` (exact, as today) and use it for the two `dir.x == 0 && …` tests. `cue_to_json` / `cue_from_json` keep the same JSON (arrays of 3 doubles; `frac` present only when `has_frac`). Update the one `Vec3{…}` use in `features.cpp` (`cue_still_names`).
2. One `planar_face_normal(const TopoDS_Face&, gp_Dir&)` (declared in `features/ops.hpp`, defined in `ops_common.cpp`) replaces `planar_normal` and `planar_face_normal`. One `edge_midpoint_sample(const TopoDS_Edge&, gp_Pnt&, gp_Vec& unit_tangent) -> bool` replaces the three `curve.D1(0.5 * (First + Last), …)` blocks (it returns false for degenerate edges or a zero tangent, as `sample_edge` does).
3. One `std::string format_fixed(double v, int decimals)` in `ops_common.cpp` replaces `format3` (3 decimals, rounds to 0.001 first), `format_mm` and `shape_utils.cpp` `fmt` (only if its output is byte-identical for every use; if not, leave `fmt` alone and say why in the PR). Every error and status string that tests pin stays byte-identical.
4. `refresh_cue(nlohmann::json& cues, const std::string& key, const TopoCue& fresh, EntityKind kind) -> bool` (declared next to `cue_names_face`): skip when `is_zero(fresh.dir)`; when a stored cue exists and `cue_names_line` / `cue_names_face` says it names something else, keep it; otherwise store `cue_to_json(fresh)`. `apply_shell` and `remember_dressup_edge_cues` both call it. This removes the second copy of the rule.
5. `solver_planegcs.cpp`: the signed-area expression for `addConstraintP2LDistance` becomes `static bool point_left_of_line(point, line)` with a comment of intent (the point keeps the side it already occupies).

Add Catch2 cases in `sxkernel/tests/test_topo_cue.cpp` (new file, added to the existing test target): `refresh_cue` stores when absent, replaces when the stored cue names the same shape, keeps when it names another; `edge_midpoint_sample` on a line and on a degenerate edge; `format_fixed(5.0, 4) == "5.0000"` and a value that rounds. `test_regen_resize.cpp` and `test_shell_filleted.cpp` stay green unedited.

Done when: G-kernel (assertions ≥ baseline), G-ci. Reduction ≈ −90 lines in `src/features/` plus the new tests.

### WP4 ★ — One cue memory; a binding that only binds

1. `src/features/cue_memory.h/.cpp`: `class CueMemory` owns `std::map<std::string, TopoCue>` (the live-edge memory), with `remember_live_edges(const FeatureGraph&, Document&)`, `refresh_feature_cues(FeatureGraph&, Feature&, Document&)` (the body of `remember_dressup_edge_cues` with the `kJobs` table and `cue_still_names`), `const TopoCue* find(const std::string& id) const`, `to_json()` and `from_json()`. **The JSON layout is exactly today's** (the edge-memory array of 6 numbers per id, features.cpp lines ~1187 and ~1220). `FeatureGraph` holds one `CueMemory cues_;` and loses `EdgeMemory`, `edge_memory_`, `remember_edge` and `recall_edge` from `features.hpp`; the one reader in `sx_document.cpp` (line ~992) calls `doc_->graph().cues().find(edge_s)`.
2. `sketch3d.cpp`: `EntityId add_external_edge(Document&, const EntityId& sketch_fid, const EntityId& edge_id)` holding the logic now in `SxDocument::sketch_add_external_edge` (idempotent on `projected_from`, planar-line check, `project_line_edge`, `set_construction`). The binding becomes: parse ids, `apply_graph_edit("convert edge", [&]{ added = sx::add_external_edge(*doc_, fid, eid); return !added.is_null(); })`, return the id string. Declare it in `include/sx/sketch3d.hpp` beside `convert_edges_to_sketch`.
3. Catch2: (a) load a `.sxp`-style graph JSON literal written before this WP (an edge-memory array with two ids) and assert `find` returns the same point and direction and `to_json` reproduces the literal; (b) on a box, `add_external_edge` of a line edge makes one external construction entity, a second call returns the same id, an arc edge returns null.

Done when: G-kernel, G-ci, `rung02_face_edges`, `convert_entities_tests` and `film_manifest_smoke` pass; `features.cpp` ≤ 1,120 lines; the binding method is ≤ 12 lines.

### WP5 — Checker tooling

1. `tools/geom.py`: add `Row` (a frozen dataclass: `name`, `ok`, `got`, `want`) and `Report` (the current `R`, plus `extend(rows)`); keep `R = Report` so `check_rung01.py` (protected) is untouched. `show()` output stays byte-identical.
2. `tools/check_rung02.py`: import `Row` and `Report` from `geom` and delete the local `Row` and the `R` loop in `main`. Move `ImplicitPart`, `_in_rounded` and the `TriMesh`-independent helpers it alone uses to `tools/implicit_part.py` (imported only by `test_check_rung02.py`; update its imports). Add a `Solid` `typing.Protocol` (`bbox`, `volume`, `inside`, `hits`, `topology`) in `check_rung02.py` that `TriMesh` and `ImplicitPart` satisfy, and type the probes against it.
3. Replace `_parse_rest` and `_usage` with `argparse`: positional `stage` (`base|rounded|shell|final|params`), positional `file` (optional for `params`), `--width` (`60` or `65`, default 60). Read `test_check_rung02.py` first: keep the exit codes (0 pass, 1 fail, 2 for `-h` / no args) and the `usage` row for bad input (subclass `ArgumentParser.error` to print the row through `Report` and return 1).
4. Add unittest cases to `test_check_rung02.py` for the CLI paths that had none (bad stage, bad width, missing file, `params`).

Done when: G-tools; for each of the four stages the new CLI output is byte-identical to `/tmp/sx-base/chk-<stage>-<W>.txt` (`diff`); `check_rung02.py` ≤ 380 lines.

### WP6 — Rungs own their rows (`tools/walk/`)

1. `registry.row(...)` stores the function object, not `fn.__name__`; `_assemble` builds `handlers` from those functions. `install(name, app_cls)` no longer calls `getattr`. A row is run as `handler(walk)`.
2. `Rung.chunk_start: Callable[[Walk, int, bool], None]` replaces the `policy` string. Two implementations: `checkpoint_reload` (today's `_policy_checkpoint`, used by rung 2) and `Rung1ChunkStart` (today's `_policy_rung01`, with `build_open_jaw`, `build_cut_file`, `build_wip_file` moved out of `Walk`). `Walk.ensure_chunk_start` calls `self.rung.chunk_start(self, chunk, force)`. `Walk` (harness) then contains nothing that names a rung.
3. Separate the rung-2 class from the rung-1 class: `WalkApp02` no longer extends `WalkApp`. Make `tools/walk/gestures.py` (the shared base: the methods Appendix C lists as called from both rungs, plus `Walk`) and move rung-1-only gestures, `jaw_geometry.py`, `variants.py`, the six `rows_chunk*.py` and the rung-1 chunk-start into `tools/walk/rung1/`; `ui02.py` and the five `rows02_chunk*.py` into `tools/walk/rung2/`. `git mv` so history follows. The 33 same-named rows no longer share a class.
4. Delete the module globals `ROWS`, `CHUNKS`, `EXPECT`, `ROW_HANDLERS` and the six patch lines in `app.py`, including the hand-registered `A8b-variant-walk` / `A9-variant-walk` handlers. Those two are not rows (the registry test counts 75 rows + 2 variants = 77): register them in a `Rung.variants: dict[str, Callable]` field (replacing today's `variants: bool`) through a `@variant("A8b-variant-walk")` decorator, keep their ids and order, and let `run_variants` and `--dry-run` read that dict. Update `test_walk_registry.py` to read `RUNG1` / `RUNG2` (importing `walk.app` and `walk.app02` installs them) and keep every frozen list.
5. `walk_rung01.py` and `walk_rung02.py` keep their arguments and docstrings; `--dry-run` prints the same lines.

Done when: G-tools; `python3 tools/walk_rung01.py --dry-run` and `walk_rung02.py --dry-run` equal `/tmp/sx-base/dry1.txt` and `dry2.txt` (`diff`); live subsets pass: `walk_rung01.py --rows N22,A1,A2 --out /tmp/sx-w1` and `walk_rung02.py --rows N1,A1,A2,A3 --out /tmp/sx-w2`; `grep -rn 'getattr(self, policy\|ROW_HANDLERS\|registry.ROWS' tools` finds nothing.

### WP7 ★ — One gesture per action, one gate runner, one `proc.run`

1. `tools/walk/proc.py`: `run(args, *, cwd, env=None) -> subprocess.CompletedProcess` (an `OSError` becomes returncode 127, as `_make` does) and `tail(out, err) -> str`. `Walk.checker`, rung-1 row A15, and rung-2 `part`, `_make`, `_kernel_tests`, `_godot_tier` use it; no other `subprocess.run` remains under `tools/walk/`.
2. `tools/walk/gates.py`: `parse_suites(text) -> (ci, full, known_red)` for `lint_suites` output, `parse_tier(text) -> (run, failed)` for `suites: N run, M failed`, and `run_tier(walk)` (preflight plus `run_suites.sh --tier full --keep-going` with the fallback comment about `configure`). Rung-1 A15 and rung-2 A25 call these; their clause names and evidence strings stay as they are.
3. Merge the gesture pairs from the survey table (`save_part`→`save_as`, `export_and_check`→`export_3mf` + `checker`, `draw_circle`→`circle`, `ground_sketch`→`sketch_ground(key=None)`, `timeline_rows`→`_timeline_names` generalised, `edit_label_to`→`edit_dim`, `sketch_circles`→`_entities(kind="circle")`). The surviving method takes the superset of arguments; every caller is updated; the **evidence strings and clause names rows pin do not change**. Delete what is left unused (re-run Appendix B).

Done when: G-tools and **CP1**: G-kernel, G-tier (ledger equal), both walks (invariant 5) with verdicts equal to the baseline lists.

**CP1 note.** If CP1 is red, bisect by reverting WP7, then WP6, then WP4, and apply the Revert rule to the guilty WP.

### WP8 — One plane owner, one face query

1. `PlaneBasis` holds one `Transform3D frame` (basis columns `x`, `y`, `normal`; origin) with `for_face(normal, origin)` (unchanged maths, including the `_Z_PARALLEL_SQ` rule), `from_axes(origin, x, y)`, `to_world(uv: Vector2) -> Vector3`, `to_uv(world: Vector3) -> Vector2`, and read-only `origin`, `x`, `y`, `normal`. `SketchMode` holds `var plane: PlaneBasis`; `plane_origin`, `plane_x`, `plane_y` stay as read-only properties (`get: return plane.origin`) so the 15 outside uses (`main.gd`, `document_view.gd`, `viewport_interaction.gd`, `ops_panel.gd`, `measure_overlay.gd`, the bridge) are untouched. Inside `sketch_mode.gd` replace `plane_origin + plane_x * u + plane_y * v` and its inverse with `plane.to_world` / `plane.to_uv`; `begin_on_plane`, `begin_edit` and `_setup_plane` assign `plane` once. `plane_normal()` returns `plane.normal` for the same values it returns today (check the 3D-leg case: `x × y` can be `−normal`; keep today's result, not the cleaner one).
2. `DocumentView.faces_matching(body_id, normal, min_dot) -> Array[Dictionary]` (each `{id, normal, centre}`) and `DocumentView.face_is_planar(body_id, face_id) -> bool` (the mesh-normal test now in `ShellChrome._face_is_planar`). The four copies of the survey table call them and keep their own tolerance and tie-break as arguments (`min_dot`, and a `Callable` or an `Array.reduce` at the call site): `SketchEdgeRefs._face_edge_set`, bridge `_find_face_by_normal`, `FilmUI.find_face_by_normal`, `ShellChrome`. Use `Plane.distance_to` for the `absf((mid - origin).dot(n)) <= 0.75` check at `sketch_mode.gd` ~567.
3. `run_rung02_plane_basis.gd` gets a case for `to_uv(to_world(uv)) == uv` on the six faces (+1 test per face is allowed; name the delta in the PR).

Done when: G-fast `--only 'rung02_plane_basis.suite'` (70 checks + the named delta), `--only 'rung02_face_edges.suite'`, `--only '*sketch*'`, `--only 'rung01_replan7_facepick.suite'`, `--only 'extrude_frame_tests.suite'`, then G-ci. `grep -n 'plane_origin =\|plane_x =\|plane_y =' game/scripts/sketch_mode.gd` finds nothing.

### WP9 — Smart Dim table and Convert-edge as two things

1. `game/scripts/smart_dim_table.gd` (`class_name SmartDimTable`): `enum Kind { LINE, CIRCLE, ARC, CIRCLE_CENTER, ARC_CENTER }`, with `external: bool` carried next to `LINE` by the caller (`_smart_dim_kind` returns a small value). Classes: `LINE_LIKE` (line, external line), `ROUND` (circle, arc), `CENTRE` (circle centre, arc centre). The rules (channel, class, class → form and options) are ≈ 11 rows: single LINE_LIKE → `line_length` + `angle_to_horizontal`; single ROUND → `diameter`; between CENTRE×CENTRE → `centres`; CENTRE×LINE_LIKE → `point_line` point `a`; LINE_LIKE×CENTRE → `point_line` point `b`; between and selection LINE_LIKE×LINE_LIKE → `angle`; selection ROUND×external line → `point_line` point `a`, role `center`; selection external line×ROUND → point `b`. The one rule that depends on `external` says so (`requires_external`). `resolve(channel, kind_a, kind_b)` returns the same dictionary shape as today (`form`, `point`, `point_role`, `label_anchor`, `also`), `{}` for no rule.
2. Decision 3's equivalence test goes into the existing `game/tests/run_sketch_tools_tests.gd` (frozen copy of the old `_ROWS` plus one loop; no new suite; its check count rises by the number of loop assertions, named in the PR body). The old `_ROWS` is deleted in the commit where that test is green.
3. `game/scripts/sketch_convert_edge.gd` (`class_name SketchConvertEdge`, `RefCounted`) replaces `SketchEdgeRefs.convert_click`: it is built with one small context object (`doc`, `view`, `plane: PlaneBasis`, `host_face_id`, `support_host`, `support_normal` and `Callable`s `ensure_feature`, `commit(label)` (undo note, solve, redraw), `status(text)`, `fallback()` for the pierce-point path). `SketchMode` builds the context once per click; no line of the new file names a `SketchMode` member. The three status constants (`ADDED`, `NOT_ON_FACE`, `NOT_LINE`) and `FACE_TOL` / `OTHER_TOL` move with it. Delete `sketch_edge_refs.gd` and its `.uid`.

Done when: G-fast `--only 'rung02_face_edges.suite'` (57), `--only 'convert_entities_tests.suite'`, `--only 'rung01_replan4*'`, `--only 'rung01_replan5*'`, `--only 'rung01_replan6*'`, `--only 'sketch_tools_tests.suite'`, then G-ci.

### WP10 ★ — `ShellChrome` injection, one bridge cache, no dead guards

1. `ShellChrome.bind(view: Callable, sketching: Callable)` (called from `viewport_interaction.gd` right after `build`) replaces both `get_parent()` reads. `viewport_interaction.gd` uses `ShellChrome` by `class_name` (drop the `_ShellChrome` preload and the `has_method("panel")` guard; type the member). `ops_panel._shell()` becomes the one-line delegate to `interaction.apply_shell_thickness`; the older path under it is deleted. First `grep -n '_shell()\|_thickness_spin' game/tests/*.gd`: if a suite calls `OpsPanel._shell` with no `interaction`, give that suite an `interaction` instead of keeping the fallback.
2. Bridge: `ViewCache` (`RefCounted`: `var key`, `var value`, `func get(new_key, build: Callable)`) replaces `_face_cache`, `_face_cache_key` and `_edge_cache`, `_edge_cache_rev`. The face key is an `Array` `[revision, camera.global_transform, camera.projection, camera.size]` compared with `==`; `_camera_stamp` and `_face_view_key` are deleted. The edge key stays the revision (Decision 5).
3. Delete the `has_method` guards the Appendix D probe marks `BOUND` (`revision`, `body_volume`, `measure_face_area`, `graph_features`); type `view` as `DocumentView` where the bridge calls `face_normal`. The other nine guards (`ix.box_colours`, `_file_dialog_name_edit`, `dimension_label_screen_rects`, `_label_px_scale`, `constraint_glyph_screen_rects`, `glyph_debug`) guard script members and stay.
4. Face records lose `mid` (Decision 4): `_face_record`, `_find_face_by_normal`/`_resolve_face_query` read `centre`; `ui.py` `top_face` and the bottom-face lookup read `f["centre"]`; `run_automation_bridge_tests.gd` reads `centre` only; `docs/loop/automation-bridge.md` face section is updated.

Done when: G-fast `--only 'automation_bridge_tests.suite'`, `--only 'rung02_shell_chip.suite'`, `--only 'ui_tests.suite'`, `--only 'menu_tests.suite'`, then G-ci; `grep -n '_camera_stamp\|_face_cache_key' game` finds nothing.

### WP11 — Test library: checker runner, film harness, status log

1. `game/tests/lib/sx_checker.gd`: `static func run(rung: String, args: Array) -> Dictionary` returning `{code, text}` (it resolves the repo root from `ProjectSettings.globalize_path("res://")`, runs `python3 tools/check_<rung>.py …` through `OS.execute`, prints the text). The 8 scripts the Appendix E probe lists use it; every `check` label stays as is.
2. `game/tests/lib/film_harness.gd`: `static func boot(tree: SceneTree, size := Vector2i(0, 0)) -> FilmContext` (instantiate `main.tscn`, two frames, `FilmContext` with `camera`, `clock`, `tree`, `FilmUI.ensure_test_viewport`), `static func manifest_entry(id) -> Dictionary`, `static func load_film(entry) -> Object` (null plus a `check`-able reason when the script does not parse or has no `run_film`). `run_film_manifest_smoke.gd._run_one` and `run_film_ubc_wrench_tests.gd` use them; banners and labels stay.
3. `SxSuite`: `var status_log := PackedStringArray()`, `func listen_status(main)` connecting the sketch-mode and interaction `status` signals, and the majority `_on_status` body. Delete the 45 and 23 identical copies by codemod (byte-identical bodies only; the others stay and are listed in the PR body). `FilmUI.distance_edit(ctx) -> LineEdit` (the majority body of the 18 `_distance_edit` copies) replaces the identical ones the same way.

Done when: G-tools, G-ci, then G-tier with the ledger equal to baseline (this is the codemod WP: run it, not just G-ci). Reduction ≈ −900 lines.

### WP12 — Film steps and the box fixture

1. `game/tests/lib/film_steps.gd` (`FilmSteps`, static functions): the generic helpers of `film_ubc_wrench.gd`: `press_rail`, `click_uv`, `type_dim`, `type_distance`, `pick_finish`, `pick_option`, `select_body`, `arm_fillet`, `commit_fillet`, `fillet_at`, `only_body`, `circles`, `export_3mf`. Click-only: they call `FilmUI` and `SxInput`, never `sm.*` or `doc.*` mutators, and they fail through `FilmUI._fail`. `film_ubc_wrench.gd` calls them and shrinks to its story (target ≤ 330 lines). Rung-1-specific helpers (`_edit_jaw_labels`, `_shaft_lines`, `_draw_centreline`, `_fillet_neck`, `_set_boss_distance`) stay in that film.
2. `game/tests/lib/box_fixture.gd` (`BoxFixture`, **validation suites only**, it may call the kernel): `build_box(ctx)` (the 100 × 60 × 50 block by rectangle + Distance field + Extrude, as the three suites do now), `fillet_z_edges(ctx, r)`, `only_body(ctx)`, `bbox(ctx)`. The three `run_rung02_*.gd` use it; their private copies are deleted. Their check counts stay 57, 70 and 38 (plus WP8's named delta).
3. The ubc wrench demo test `film_ubc_wrench_tests` must pass unchanged: same volume, same features, `check_rung01.py thick` 7/7.

Done when: G-fast `--only 'film_ubc_wrench_tests.suite'`, `--only 'rung02_*'`, `--only 'film_manifest_smoke.suite'`, then G-ci and **CP2**: G-kernel, G-tools, G-tier (ledger equal), both walks with verdicts equal to the baseline lists. Then append the parked ★ WPs and Revert-rule WPs to roadmap §8, and add a STATUS entry "Post-rung-2 cleanup" (WP numbers, lines removed, suites 206 + 4 known-red, before Part B).

## Part B — the Lesson 2 box demo

Goal: a click-driven film of the rung-2 box, a headless demo test that fails if the film's end state is not the checked box, a rendered video, a poster, and a card in the website's features section. Same shape as `ubc_wrench`. Rules that bind: [`landing-protocol.md`](../plan/landing-protocol.md) (movie template, website demos), `.cursor/rules/gdscript-click-driven-tests.mdc` (films click only), `.cursor/rules/website-published-demo-movies.mdc`.

The story is the walk's chain (source: `tools/walk/rung2/rows02_chunk*.py` and [`rung-02-plan.md`](rung-02-plan.md) "The PDF, step by step"), compressed: ground sketch → corner rectangle 100 × 65 → Smart Dim 100 and 65 → edit 65 to 60 → Extrude 50 → one R10 Fillet on the four corner edges → Shell 5 with the top face open → sketch on the right-hand face → Ø10 circle, two Convert edges, Smart Dim Ø10, 25 and 40 → Cut Through All → edit 60 back to 65 and watch the fillet, shell and hole follow.

### WP13 — Film `lesson2_box`, manifest entry, how-to

1. `game/tests/films/film_lesson2_box.gd` (`extends RefCounted`, `run_film(ctx)`), following [`film_ubc_wrench.gd`](../../game/tests/films/film_ubc_wrench.gd): `ensure_test_viewport(ctx, Vector2i(1600, 900))`, `movie_toast("A hollow box with a side hole — resize it and everything follows", 2.0)`, then these beats (each names the user action): "Sketch a rectangle on the ground", "Dimension it: 100 by 65, then change 65 to 60", "Extrude 50", "Round the four corners R10 in one fillet", "Shell 5, open the top", "Sketch on the right-hand face", "Ø10 hole, 25 from the left edge, 40 from the bottom", "Cut through all", "Change the width back to 65 — fillet, shell and hole follow", then `ctx.camera.showcase_smooth`. Use `FilmUI`, `FilmSteps` (WP12) and `SxInput`. The new steps this film needs go into `FilmSteps` as click-only statics: `pick_corner_edges(ctx, body)` (a `corner → view key` table as in the walk's `CORNERS`: Iso for the three visible corners, Right or Left for the hidden one; each pick is `FilmUI.viewport_click` on the projected edge middle), `shell_selected_face(ctx, mm)` (clicks the `strip:shell` chip, types the thickness, presses Apply), `open_side_face_sketch(ctx, normal, view_key)`, `convert_edge(ctx, world)` (rail Convert, click). If a step has no clickable path, **fail the film with `FilmUI._fail` and fix the app or drop the beat**; no private calls (`set_tool`, `exit_sketch`, `graph_add_fillet`, `trim_at`, …).
2. Length ≤ 90 s at 30 fps; `quit_after` 3600 (ceiling only).
3. Manifest: append `{"id": "lesson2_box", "title": "Lesson 2 box: sketch, fillet, shell, side hole, resize", "script": "res://tests/films/film_lesson2_box.gd", "enabled": true, "quit_after": 3600, "blurb": "Rectangle, extrude, one fillet, shell, a hole from the side, then resize — the features follow."}` to `game/tests/ui_movie_manifest.json`; run `scripts/sx-sync-website` (it copies the manifest to `website/assets/ui_movie_manifest.json`; the Pages checkout is absent, which exits 0).
4. How-to `docs/howto/lesson2-box.md`: numbered exact click path of the film in the style of `docs/howto/ubc-wrench.md`, "Film: `lesson2_box`." at the end.
5. `run_film_manifest_smoke.gd` already runs every enabled film headless: confirm it prints `smoke lesson2_box`.

Done when: `--only 'film_manifest_smoke.suite'` passes with `lesson2_box` in its output; `scripts/sx-check-website-demos --offline` passes; `python3 -c 'import json; [json.load(open(p)) for p in ("game/tests/ui_movie_manifest.json","website/assets/ui_movie_manifest.json")]'` and a `diff` of the two manifests are clean.

### WP14 — Demo test `run_film_lesson2_box_tests.gd`

1. `game/tests/run_film_lesson2_box_tests.gd` (`extends "res://tests/lib/sx_suite.gd"`, banner `print("film lesson2_box")`, a new banner, not one of the 15 A15 floors). It uses `FilmHarness.boot(self, Vector2i(1600, 900))`, `manifest_entry("lesson2_box")`, `load_film`, `await film.run_film(ctx)`, then asserts as a *validation* test (kernel and `SxDocument` calls are allowed): `FilmUI.fail_count == 0`; exactly one body; bbox 100 × 65 × 50 within 0.2; volume within 0.5 % of `volumes["65"]["final"]` read from `python3 tools/check_rung02.py params` (through `SxChecker`; no hard-coded number); feature names equal `sketch 1, extrude 2, fillet 3, Shell 5.0000 mm, sketch 5, extrude 6` in order, the fillet has 4 edges, the last extrude is a cut with end `through_all`; `last_graph_error()` empty.
2. Export with `doc.export_3mf(globalized_temp_path)` (never `user://`) and run `SxChecker.run("rung02", ["final", path, "--width", "65"])`: exit 0 and `16/16 passed` in the text.
3. Manifest `packaging/ci/suites.d/film_lesson2_box_tests.suite`: `script=tests/run_film_lesson2_box_tests.gd`, `tier=full`, `timeout=300`. (`full`: it needs numpy and runs about a minute.)
4. Count arithmetic: `lint_suites: 211 suites ok (62 ci, 145 full, 4 known-red)`; `suites: 207 run, 0 failed`.

Done when: the suite passes alone (`--only 'film_lesson2_box_tests.suite'`), G-tools passes, and a final `KEEP_GOING=1 make test-godot` shows `suites: 207 run, 0 failed` with the ledger equal to baseline plus the new suite's lines.

### WP15 — Render, poster, publish tooling, website entry

1. Calibrate: time `scripts/sx-movies one precision_plate`, then `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-movies one lesson2_box` inside `tmux` (session `lesson2-box-render`, `DISPLAY=:1`). If the estimate exceeds 90 minutes, rerun with `SX_MOVIES_FPS=24`. Verify with `ffprobe` (VP9, 1600 × 900, duration within 10 % of the beat sum) and look at three frames (the rectangle, the shell, the end) with `ffmpeg -ss … -frames:v 1`. Copy `lesson2_box.webm` and `.vtt` to `/opt/cursor/artifacts/` so they attach to the PR. **Do not `git add` them.**
2. Poster: `ffmpeg -y -sseof -0.1 -i /tmp/sx-movies/lesson2_box.webm -frames:v 1 website/assets/screenshots/lesson2_box.png` (the only binary that goes into git).
3. Publishing tooling exists (`scripts/sx-publish-demo-movies [--dry-run] [--feature] ID`, WP2 added the JSON overrides): run `SX_MOVIES_OUT=/tmp/sx-movies scripts/sx-publish-demo-movies --dry-run --feature lesson2_box` and keep the output in the PR body.
4. Website entry, gated on the asset: `gh release view demo-movies -R solidexpress/solidexpress.github.io --json assets --jq '.assets[].name'`.
   - **If `lesson2_box.webm` is listed:** run the publish script with `SX_SKIP_UPLOAD=1 --feature lesson2_box`, review, commit the two JSON edits, run `scripts/sx-check-website-demos` (online) and expect green.
   - **If it is not listed (the expected case; this token has no push access):** commit the manifest entry, the poster and the how-to only. Do **not** add `lesson2_box` to `published-demos.json` or `demo-catalog.json` (the checker refuses a featured id that is not on the Release). Put the exact human step in the PR body and in `docs/plan/STATUS.md` under "Pending publish": `gh release upload demo-movies -R solidexpress/solidexpress.github.io --clobber lesson2_box.webm lesson2_box.vtt`, then `SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature lesson2_box`, then a one-line follow-up commit.
5. `website/features.html` needs no markup change: it renders `demo-catalog.json` ∩ the live Release asset list through `assets/demo.js`. Do not hand-write a `data-demo` card.
6. Final gate for Part B: `scripts/sx-check-website-demos` green (`--offline` if the network blocks it, and say so), `make test-tools`, G-ci, `--only 'film_lesson2_box_tests.suite'`, `--only 'film_manifest_smoke.suite'`; push; quick CI (`kernel`, `godot-smoke`, `website-demos`) green; mark the PR ready.

## Acceptance for the whole plan

All of: rung-1 walk 77/77 and rung-2 walk 44/44 at 1280×800 (CP2 run, verdicts equal to WP1's); every checker at the WP1 bar (rung 1: blank 5/5, wrench 28/28, noext 28/28, thick 7/7, T=14 four DIAG, nut 7/7; rung 2: `final` 16/16 at 60 and 65, stages as recorded); `suites: 207 run, 0 failed` with 4 known-red unchanged and the ledger equal to baseline plus the new suite; `make test-kernel` and `make test-tools` green; quick CI green; `lesson2_box.webm` attached to the PR.

## Final report (keep it short)

PR URL, then one line per WP: number, title, outcome (done / parked), net lines. Then three facts: suites run (`206 + 1 = 207`, 4 known-red), walks 77/77 and 44/44, and the pending human step for the video if the WebM was not on the Release. No other prose.

## Appendix A — dead-code finder (GDScript)

Run from the repo root; prints functions defined once and never referenced (the identifier regex also matches inside strings, so `call("name")` callers count). At `fb627c4` it prints `timeline_panel.gd _focus_extrude_distance`, `ui_spin.gd rearm_replace_after_commit`, `ui_spin.gd _is_reformat_of`.

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
    for m in re.finditer(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\(", text[f], re.M):
        if m.group(1) not in engine and cnt[m.group(1)] == 1:
            print(f, m.group(1))
```

## Appendix B — dead-code finder (Python)

Prints functions and classes defined once and never referenced under `tools/` and `scripts/` (rows `row_*` and tests excluded). At `fb627c4`: `open_checkpoint`, `_off_badges`, `checkpoint_file`, `_left_external`, `_bottom_external`, `click_edge_near`.

```python
import ast, glob, collections, re
files = glob.glob("tools/**/*.py", recursive=True) + glob.glob("scripts/**/*.py", recursive=True)
src = {f: open(f).read() for f in files}
names = collections.Counter()
for t in src.values():
    names.update(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", t))
for f, t in sorted(src.items()):
    if "/test_" in f:
        continue
    for n in ast.walk(ast.parse(t)):
        if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and names[n.name] == 1 \
                and not n.name.startswith(("__", "row_", "test_")) and n.name != "main":
            print(f, n.name)
```

## Appendix C — which `ui.py` gestures each rung calls (WP6, WP7)

```python
import re, glob
ui = open("tools/walk/ui.py").read()
meths = re.findall(r"^    def ([A-Za-z_0-9]+)\(", ui, re.M)
r1 = "".join(open(f).read() for f in glob.glob("tools/walk/rows_chunk*.py") + ["tools/walk/variants.py", "tools/walk/jaw_geometry.py"])
r2 = "".join(open(f).read() for f in glob.glob("tools/walk/rows02_chunk*.py") + ["tools/walk/ui02.py"])
for m in meths:
    a = len(re.findall(r"self\.%s\b" % m, r1 + ui)); b = len(re.findall(r"self\.%s\b" % m, r2))
    print("both" if a and b else "rung2" if b else "rung1" if a else "none", m)
```

Expected at the baseline: `both` is `refresh S click lit_names field control type_into enter esc esc_until set_option save_as export_3mf file_new sketch_ground dims dim_texts find_dim _dim_editor_open edit_dim _type_dim_editor _entities edges _timeline_names _show_timeline`; `rung2` is `open_file`. Methods that print `none` may still be called by `harness.py` (`_bbox_x`, `_circle_span` feed `_gate_state`); check `harness.py` before moving or deleting one.

## Appendix D — `has_method` guards that are always true (WP10)

```python
import re, glob
bound = set(re.findall(r'D_METHOD\("([A-Za-z_0-9]+)"', "".join(open(f).read() for f in glob.glob("sxcore/src/*.cpp"))))
txt = open("game/scripts/automation_bridge.gd").read()
for m in re.finditer(r'(\S+)\.has_method\("([A-Za-z_0-9]+)"\)', txt):
    print(m.group(1)[-30:], m.group(2), "BOUND" if m.group(2) in bound else "-")
```

At the baseline `BOUND` is `revision` (×2), `body_volume`, `measure_face_area`, `graph_features`.

## Appendix E — helper-copy probe for the tests (WP11, WP12)

```python
import re, glob, hashlib, collections
def bodies(name):
    c = collections.Counter(); total = 0
    for f in glob.glob("game/tests/run_*.gd"):
        for m in re.finditer(r"^(?:static )?func " + name + r"\(.*?(?=^(?:static )?func |\Z)", open(f).read(), re.M | re.S):
            total += 1; c[hashlib.md5(m.group(0).rstrip().encode()).hexdigest()[:6]] += 1
    return total, c.most_common(3)
for n in ["_boot", "_on_status", "_note_status", "_distance_edit", "_only_body"]:
    print(n, bodies(n))
```

Baseline: `_boot` 107 (top body 8), `_on_status` 82 (45 and 23), `_note_status` 3, `_distance_edit` 18 (top body 9), `_only_body` 10 (top body 7). The `tools/check_rung0N.py` runner blocks: `grep -ln 'tools/check_rung0' game/tests/*.gd` lists 8 files (`run_film_ubc_wrench_tests`, `run_rung01_replan15_jawstub`, `…replan15_thick`, `…replan17_walk`, `…replan20_jaw`, `…replan3_timeline`, `…replan8_shaft`, `run_rung01_wrench`).
