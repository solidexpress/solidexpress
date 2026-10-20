# Rung 8 failing — handoff after 3+ fix attempts

Test-and-fix agent: this file plus [`rung-08-plan.md`](rung-08-plan.md) and [`rung-08-checklist.md`](rung-08-checklist.md). Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`. Tree that wrote this: `b787e32`. Confirm dir: `build/confirm-wp11`.

Walk **8 product is green** (47/47 from row 1, `check_rung08.py` pin 3/3, pipes 5/5, bolted 7/7, final 10/10). The bar is red because **headless is 17 failed** (A37 and every other A15-class row) and **rung 7 walk is product-red**.

## Finding 1 — A37 / A15-class: `suites: 262 run, 17 failed`

Rows: walk1 A15, walk2 A25, walk3 A26, walk4 A21, walk5 A25, walk6 A36, walk7 A37, walk8 A37. Same shared `godot.rc`. `--a15` required.

Confirm list (`build/confirm-wp11/godot.log` ~27000):

| Suite | Symptom on this tree |
|---|---|
| `run_film_spanner_tests.gd` | `extrude 3: boolean failed`; features stop at sketch 1 + extrude 2; fillet 4 limit 5.066 on 6 mm vertical at (23.929, 10, 0); bbox 232.571×33.000×10 vs 281.4×54.6; `check_rung07.py final` 2/8 then 3/8 |
| `run_rung01_preview_rebuild.gd` | T=10 pivot/jaw not open before edit; T=14 preview and committed mesh pivot/jaw not through |
| `run_rung01_replan10_cut.gd` | handout jaw attempt 4: `Cut left an open shell (4398/8796 edges not shared twice)` — contour on the body’s own edge; volume 53128→53128 |
| `run_rung01_replan15_jawstub.gd` | same jaw/cut family |
| `run_rung01_replan17_walk.gd` | flake in isolation (`/tmp/sx-godot-clean` still red this pass) |
| `run_rung01_replan20_glyphs.gd` | red in isolation |
| `run_rung01_replan20_jaw.gd` | jaw family |
| `run_rung01_replan3_distance.gd` | red in isolation |
| `run_rung01_replan8_cut.gd` | cut family |
| `run_rung01_sx038_regress.gd` | **flake** — failed in the 262-run, PASS when isolated |
| `run_rung03_offset.gd` | red in isolation |
| `run_rung07_boss.gd` | neck/boss bbox 232.6×33 vs 281.4×54.6 (handle missing) |
| `run_rung07_offset.gd` | offset after missing handle |
| `run_sketch_to_3d_ui_tests.gd` | red in isolation |
| `run_sweep_loft_solid_tests.gd` | guided loft UI: `loft 5: guided loft: OCCT could not follow the guide` (kernel L3 replica is green) |
| `run_ui_tests.gd` | red in isolation |
| `run_workflow_tests.gd` | 275 checks, 1 failure (instance path) |

Tried (did not clear the 17):

1. Serial Godot `--jobs 1` (earlier session reported those 18 PASS; not reproduced). Full-tier marathon still 17.
2. Isolated rerun of the 17 in `/tmp/sx-godot-clean/`: 16 still fail; `sx038_regress` flipped to PASS.
3. `SX_WALK_JOBS=1` so walks do not starve the suite pass. Walks 1–6/8 product went green; the 17 stayed.

Do **not** mark these `tier=known-red` to get A37 green. Hypothesis worth one more product pass: handle-contour / jaw-cut boolean (open shell, extrude-3) is the common geometry cause; ViewCube click-steal is secondary (walk1 product 76/76 still built the wrench). Dummy renderer cannot pin 3D pixels; geometry failures are OCCT/UI, not lavapipe.

Cheap recheck after a fix: `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only film_spanner_tests` then `replan10_cut` then the rest of the 17, **not** overlapping a walk. Then walk8 `--from A37 --a15` with `SX_CONFIRM_DIR` and `ckpts` from `build/confirm-wp11/walk8/` (`assembly.sxp` / `final.sxp`).

## Finding 2 — Walk 7 A22 handle contour (rung 7 product)

Confirm walk7: 35 PASS / 11 FAIL / wall 697.1s (overlapped the 17-suite rerun). Clean solo `/tmp/sx-rung07-solo`: 28 PASS / 13 FAIL / 5 BLOCKED, wall 972.4s.

- A22: handle contour reported included, but second extrude did not commit (`still in a sketch`).
- Cascade: A23–A26 BLOCKED; L4 order `['sketch','extrude']`; A28 Convert inserted Torus; A29 offset arcs n=1; A30–A32 one-body fail (handle xmax 256.5, Y 27.295 — extrude 2 only); A33–A35 / L5 / N4 checker red.
- Confirm (not solo) got a second extrude + fillet 4 but **no −X open end**: bbox 232.571×33.000×10.000 min (23.929, −16.500, −5.000); volume 28418.816 vs 38782; `check_rung07.py final` **3/8** (watertight, handleSide, recessBoth only).
- Same bbox as `run_film_spanner_tests.gd` / `run_rung07_boss.gd`.

Tried: confirm walk7 (overlapped load), then a clean solo on :38. No third product edit — the jaw-cut / handle-boolean is the same as Finding 1. Rung 1 walk product stayed 76/76 on this tree (A15 only), so the GUI walk path for the **open-end wrench** still lands; the **combination spanner** handle/jaw path does not.

Fix the boolean / contour (Finding 1) and re-walk rung 7 from row 1 with `SX_WALK_JOBS=1` and no overlapping suite run.

## Not findings

- Walk 8 N2 / A7 / A8 / A16 / A17 / A23 / A35: walker bugs, fixed on this branch (Fixed-nudge catch, Front via OriginPlanes, `sketch_pin_profile` closed PinFixture, mate uuid vs JSON-RPC id, pin quaternion dumps, head −Z 287.5, `reopen_code` 0-or-1). Do not re-open.
- WP-V1…V8 cheap suites: not in the 17. V7 skipped the light sheet (blue readable). Dummy-renderer V1 uses a colour-type-6 fixture PNG.
- 4 `tier=known-red` suites (`replan12_pick`, `replan3_timeline`, `replan_input`, `rung01_sketch_tests`) — listed, not run, not this handoff.
- `run_film_caption_tests.gd` / `run_ui_scroll_tests.gd` stay unregistered.
