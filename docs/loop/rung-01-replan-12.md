# Rung 1 replan 12 — fillet picks, fillets survive T14, one-click labels, rail clicks, panel dismiss

Status: plan only. No product code in this change.

Baseline: `main` at `2606160cb61f5e06cc3c0c3dbb4d5e2d6dbf2d1a`, **confirmed still the tip when this plan was written** (replan-11 WP1–WP11, #113–#124). Replan 11 is [`rung-01-replan-11.md`](rung-01-replan-11.md). The sx-032 critique of that build scored **8.5/10** and failed rung 1. Leftovers, verbatim: [`rung-01-leftovers-sx032.md`](rung-01-leftovers-sx032.md). Do not re-critique sha256 `367de12a`.

BUILD agents are grok-4.6 high. Each work package has its own prompt. Launch a BUILD agent with that file alone:

| WP | Prompt |
|---|---|
| WP1 | [`rung-01-replan-12-wp1.md`](rung-01-replan-12-wp1.md) |
| WP2 | [`rung-01-replan-12-wp2.md`](rung-01-replan-12-wp2.md) |
| WP3 | [`rung-01-replan-12-wp3.md`](rung-01-replan-12-wp3.md) |
| WP4 | [`rung-01-replan-12-wp4.md`](rung-01-replan-12-wp4.md) |
| WP5 | [`rung-01-replan-12-wp5.md`](rung-01-replan-12-wp5.md) |
| WP6 | [`rung-01-replan-12-wp6.md`](rung-01-replan-12-wp6.md) |
| WP7 | [`rung-01-replan-12-wp7.md`](rung-01-replan-12-wp7.md) |

The prompts are the implementation. This file is the decisions, the merge order, the suite table, and the sx-033 checklist. Do not redesign anything a prompt already specifies.

Godot stays `tools/godot/godot` (4.7-stable). Do not switch the pin to 4.7.1. Put `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` before every Godot command and run Godot scripts as `--script res://tests/<name>.gd` from `--path game`. The first Godot run on a fresh checkout bakes `game/.godot`; run `tools/godot/godot --headless --path game --import` once first. Do not commit `.gd.uid` files. The walk (`run_rung01_wrench.gd`) clicks real X11 widgets: also `export DISPLAY=:1`.

Line numbers below and in the prompts were read on `2606160c`. After another WP lands, search for the function name instead of trusting a shifted line number. `git apply` is a convenience, not a requirement: every prompt names the function, and the diffs in the prompts are the measured ones.

**How this plan was measured.** The planning agent applied every diff in these prompts to a scratch tree on `2606160c`, ran every test, and reverted the tree before committing this document. Red counts are the new test run on unmodified `2606160c` product code (kernel rebuilt from baseline sources); green counts are the same test after the diff. A BUILD run that disagrees with a count is a product failure to report, not a number to edit.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and the first try works. sx-032 passed every checker on GUI files but lost time to eight traps. This plan removes them:

- A single click on the first glyph of any dimension label opens the editor. Labels are smaller (font 18, not 28) and never overlap on screen.
- A sketch click 30 px right of the visible left rail lands on the canvas. Nothing invisible covers the canvas.
- A Top-view corner click arms the vertical neck edge. A wall click or a press off the solid never replaces or wipes the armed set. A hidden edge is never snapped to through a wall. `Esc` ends an armed pick.
- `Fillet 2 edges 10.00 applied` stays on the status line, and `— removed` names the removed edge and its length.
- The timeline Distance panel closes on `Esc` (reverting the preview) and on a click on empty viewport (keeping the value).
- A top-face or slot-floor R1 fillet **survives a thickness edit** (T=10 → 14). A fillet that does lose edges says so by name instead of silently doing nothing.
- File → Save As inside a sketch keeps the sketch open.
- The Slot, jaw, Circle, Select and Centerline tools say what they did, so a walker can read the slot length back.

**Pass bar.** Score ≥ 9. nut 7/7, blank 5/5, wrench 28/28, thick **6/6** (one new row) on files exported from the GUI. Walk 0 failures. `run_rung01_wrench.gd` 0 failures. The part was made in the real GUI with no script-side shortcut. 3MF dimensions within 0.2 mm. **First-try fillets from the views the app offers.**

Checker commands (thick gains one row; the other three are unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf          # 5/5
python3 tools/check_rung01.py nut    nut.3mf            # 7/7
python3 tools/check_rung01.py wrench wrench.3mf         # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14  # 6/6
```

Do not pass `--allow-mirror`. Exit code 0 is the pass. Do not change any other checker formula or tolerance.

## What stayed green (do not redo)

These shipped in replan 10 and 11 and passed in the sx-032 GUI walk. Do not redo them and do not regress them. Their suites are in the whole-suite table.

- A6: Esc after a first point takes two presses (`First point dropped — Esc again exits the sketch`, then `Sketch cancelled`).
- A8: the dimension editor works on both labels (`Dimension updated`, 20 and 45°). Only the hit area was wrong (WP2).
- A9: Trim with a leftover along-jaw construction line: `Trimmed open jaw`, then `Jaw is already open — nothing left to trim here`. The Trim cutter chooser, the named refusal and the jaw-scoped construction replace are untouched.
- A9b: the closed Up To Surface jaw cut (fuzzy boolean). A8b: the Esc ladder keeps a sketch that holds geometry.
- A16: View menu with Back/Left/Bottom; keys 4/6/8; orbit off Top.
- Fillets: the status lists edge lengths and kinds; a re-click removes an edge; face-first R1 applies (never `No edges selected`); the fillet refusal names the limit or the faulty edge.
- A13: Distance pre-selected; the slot sketch follows its support face (thick slot row). A3: head centre y 0.000. A14: `Polygon AF 20.0000 — flats horizontal`, nut 7/7 first try. A7 `Sketch on face (plane +Z @ origin …)`.
- A10 exact `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; A10b File → New resets Op/End.
- Headless on `2606160c`: `run_rung01_wrench.gd` **413/0**; all 11 replan11 suites green; lint `4 replan10` + `11 replan11 scripts are clean`; `make test-kernel` **7900 assertions in 330 test cases**.

## Measured evidence (all on `2606160c`)

1. **The rail hypothesis is right.** With a face sketch open and a Circle tool armed, `gui_get_hovered_control()` at (175, 400) is `LeftStack` (`main.gd` `left_stack`), 322×694 px at the top-left. The sketch rail ends at x≈145. `LeftStack` is a `VBoxContainer` with the default `MOUSE_FILTER_STOP`; once the Selection card hides it still keeps the 280 px `_CARD_W` minimum width and a Container never shrinks without `reset_size()`. `viewport_interaction.gd` `_viewport_owns_pointer` is false there, so the click is dropped silently. After the WP3 change the same probe hovers `Interaction` and `LeftStack` is 141×560.
2. **Why the T=14 fillets vanish.** Face-derived fillets store edge ids plus absolute `edge_cues` (midpoint + direction, 0.5 mm gate). A thickness edit re-mints the ids and moves every vertical edge's midpoint by 2 mm in Z, so `match_edge_cue` finds nothing and `apply_fillet_chamfer` soft-skips every edge (`fillet soft-skip: missing edge uuid …`, ~21 lines in the walk log) while `graph_regenerate` reports ok. The walk exports `/tmp/sx-rung01-wrench-t14.3mf` with **2438 triangles** (all fillets gone); after WP1 the same flow exports **5760** triangles and thick prints `6/6`.
3. **Why a hard failure is wrong.** The first prototype failed the feature when every edge was lost. That broke `run_critic_walk_tests` (4 failures): ordinary flows (a later sketch, a hole through a filleted face) lose edges silently at baseline and the user expects the edit to stand. Decision 8 therefore warns instead of failing.
4. **Esc never ended an armed Fillet.** Outside a sketch `Esc` goes to `viewport_interaction.gd` `_input` → `cancel_stack()` (line ~4478). `ops_panel.cancel_pending_pick()` is only reached from `_gui_key`, which is never called for Esc outside a sketch. One Esc clears the selection and leaves Fillet armed; the next Enter is `No edges selected — cancelled`. WP6 adds the pending-pick rung to `cancel_stack`. The new walk exposed this.
5. **A kernel crash on the same path.** A stale five-edge set at R10 (three 10 mm verticals and two 179.8 mm lines, as the baseline walk accumulates it) segfaults inside `BRepFilletAPI_MakeFillet::NbEdges` from `note_faulty_contour` (`ops_dress.cpp` line 147) on **unmodified `2606160c`**: the new walk steps abort the baseline process with `handle_crash: Program crashed with signal 11`. WP1 guards the index (`ic < 1 || ic > mk.NbContours()`); the refusal then names the limit edge.
6. **`edge_near_screen` must test occlusion.** A wall click at (100, 10, 5) from Back view snapped to the slot's 150 mm floor edge that sits behind the wall (14 px away on screen). WP6 samples the edge's nearest point and drops it when a face is closer to the camera.
7. **Why `run_rung01_replan11_ux.gd` passed while the GUI failed.** It called `main.cancel_property_panel()` and `_commit_property_panel_on_deselect()` directly, and it fed Esc through the `_unhandled_input` fallback of `PropertyPanel`, which only runs when nothing else consumes the key. In the GUI `Interaction._input` consumes Esc first (`cancel_stack`) and an empty press returns from the `_press_empty` branch before the deselect hook. The walk had the same blind spot: `_triball_one_esc` called `cancel_property_panel()` itself. WP5 tests with real pushed events through the viewport; WP7 replaces the walk's script call with a real key.
8. **The 150.3466 slot was a walker slip.** The Slot tool takes the rubber-band length unless a length is typed. `_add_slot` said nothing. WP4 prints `Slot c-c 150.0000 R5.0000` so the walker reads the length back before cutting.

## Decisions (nothing left open)

1. **Label size and stacking.** `Label3D` font 18 (was 28), `pixel_size` 0.004, `outline_size` 4. Labels whose anchors are closer than 14 mm in the sketch plane stack upward by 28 label px (`label.offset`), counted per earlier label in `taken`. The stack index and the text are stored on the dimension dict as `label_stack` and `label_text` next to `label_pos`.
2. **Label hit test.** The hit is the projected text rectangle plus an 8 px pad, using `ThemeDB.fallback_font` width and height at font 18 and the fixed-size px factor `k = pixel_size * viewport_height / 2` (divided by `tan(fov/2)` for a perspective camera; orthographic uses `k` as is). The smallest gap wins; ties go to the nearer rectangle centre. The old 22 px anchor circle and the 6 mm sketch-space radius stay as fallbacks, in that order. `click()`'s early SELECT/SMART_DIM dimension check and the `_sketch_input` drag guard call `dimension_hit` unchanged. The walk and the GUI walker click the **first glyph**, never the centre.
3. **Left stack.** `left_stack.mouse_filter = MOUSE_FILTER_IGNORE` (the cards and buttons inside keep their own filters), `left_stack.minimum_size_changed` is connected to `left_stack.reset_size` (deferred), and `_reflow_left_stack` ends with `left_stack.reset_size()` before `_sync_bottom_docks()`. No other chrome changes. The sketch click is never silent: the hover probe in the rail test fails if any control but `Interaction` is under the pointer.
4. **Fillet pick camera.** `_accumulate_dressup_edge` passes the viewport camera to both `edge_near_point` calls. The tie-break (8 px, end-on edge wins) already exists in `edge_near_point`.
5. **Face click while edges are armed.** A face click expands to the whole face only as the **first** pick. Once any edge is armed: snap to the nearest edge within **14 screen px** (`DRESSUP_SNAP_PX`) via the new `DocumentView.edge_near_screen`, which skips edges hidden behind a wall; if none, keep the set and say `No edge near click — click on an edge (a face click fillets the whole face only as the first pick)`. A pick never replaces the set.
6. **Press off the solid.** In `_on_release` the `_press_empty` branch runs only when no armed pick consumes the viewport (`ops_panel.consumes_viewport_pick()`). While armed, a press that misses the solid goes to `ops_panel.handle_viewport_miss(screen, camera)`: an edge within **10 px** of the press (`DRESSUP_SILHOUETTE_PX`) is toggled (a silhouette edge seen edge-on), otherwise the status is `Missed the solid — click a face or edge`. The set, the panel and the armed state are never touched.
7. **Fillet status sentences.** Removal: `<pick status> — removed <len> mm <kind>` (e.g. `… — removed 10.0 mm vertical`). Applied: `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters` (the applied text leads; `open_feature_params(fid, lead)` replaces only the `Feature created` head and keeps each tail). No other caller passes a lead, so every existing `Feature created …` string is unchanged. A grep for `Feature created` in `game/tests` finds no assertion that depends on the fillet case.
8. **Fillets survive a thickness edit (kernel, option c).** A fillet/chamfer feature persists `face_cues` — `[{point, normal}]` for every **planar face whose edges are all in the fillet's edge set** (at least three edges). On every apply the feature first resolves its edge ids and edge cues as today; if some do not resolve, each face cue is matched to the planar face with the same normal (dot ≥ 0.999) whose plane, after sliding the cue point along the normal, contains it (`BRepClass_FaceClassifier`, 1e-4); the face with the smallest slide wins (the top face beats a pocket floor). All that face's edges join the set. `face_cues` are re-written from the rebuilt body on every successful apply. Documents saved before WP1 have no `face_cues`: no migration, they get the warning in 9.
9. **Lost edges warn, they do not fail.** `FeatureGraph` gains `warnings()` / `add_warning()`, cleared at the start of `regenerate`. A fillet/chamfer that resolves fewer edges than it names adds `<name>: all N edges lost on rebuild — it changes nothing now` or `<name>: L of N edges lost on rebuild`. The rebuild still succeeds and the edit stands. Surfaces: `SxDocument.graph_warnings()`, `graph_features()[i]["warning"]`, a `⚠` badge (`WarnBadge`, tooltip = text) on the timeline row, and the `PropertyPanel._set_param` status (`Preview: distance = 14 — <warnings>`). Chamfer used to abandon the whole feature on the first missing edge; it now behaves like fillet.
10. **Index guard.** `note_faulty_contour` returns when `ic < 1 || ic > mk.NbContours() || mk.NbEdges(ic) < 1`. No other blend strategy changes (replan-11 decision 1 stands: fillet the R10 neck first).
11. **Thick checker: yes, one row.** `1mm top fillet at new T`: `not inside(tr, (-9.9, 0.0, T_ - 0.1))` with the expected text `outside`, appended after `grip slot open from the top`. thick 5/5 becomes **6/6**. Same probe as the wrench row `1mm fillet top outer edge` but at the new thickness; that wrench row fails at T=14 by design (hard-coded z=10), so the thick row is the only checker that sees the loss. This is the only checker change.
12. **Esc ladder.** `cancel_stack()` order: (1) an open timeline property panel is cancelled (`Edits cancelled`, focused field released); (2) an armed pick ends (`ops_panel.cancel_pending_pick()`: `Edge pick cancelled`, the picked edges drop, the **body stays selected**, a focused field is released); (3) the existing rungs (focused field, TriBall, selection). One real Esc ends the armed Fillet.
13. **Panel dismiss.** An empty-viewport press (not armed) calls `_commit_property_panel_on_deselect()` (`dismiss_keep_preview()`: the previewed value is kept). Esc cancels the preview (the distance returns to its old value).
14. **Save As keeps the sketch.** `_save_current` captures the camera pose, calls `exit_sketch()` (which returns the sketch feature id), saves, then `begin_edit(fid)`, `_on_sketch_session_started("Editing sketch")`, `refresh_sketch_pads`, `apply_pose`, `set_tool(SELECT)`. The status is still `Saved <path>`. Replan-11 decision 16 stands: the saved file contains the sketch. `run_rung01_replan11_ux.gd` is updated for the new rule.
15. **Save As dialog.** The dialog opens with `current_file = current_path.get_file()` (or `untitled.sxp`) and `current_dir = current_path.get_base_dir()` when the path is absolute. The status already prints the resolved path, which is the read-back for a relative path (rule 24 below).
16. **Statuses.** `Slot c-c %.4f R%.4f` (plus ` — typed` when a length was typed), `Jaw committed — width %.4f, long side %.1f° — click a label to edit it`, `Circle — click the centre, then the rim (or type a radius)`, `Select — click geometry, or a dimension label to edit it`, `Centerline — click 2 points (construction, never part of the profile)`, `Centerline added — construction, not part of the profile`. Rect's `Rect — click 1 first corner, …` stays.
17. **Lint.** `tools/lint_rung01_e2e.py` gains `_lint_replan12`: all seven `run_rung01_replan12_*.gd` files get the camera needles (`_look_along`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =`); they are validation suites, so script-side setup is allowed, the pointer and camera paths under test are real events and key taps. The summary line is `7 replan12 scripts are clean`. The Makefile gets the same loop as replan 11.
18. **Walk.** `run_rung01_wrench.gd` goes from 413 to **456** checks (+43). It gains the human fillet picks, a real Esc after the refused slot floor, the T=14 probes, the panel Esc/click-away, the rail click, first/last glyph label clicks and Save As inside the jaw sketch, and `thick checker prints 6/6`.

### Items with no code (reason each)

- **Circle chips vanish during the preview.** The chip row is the tool's variants (Center / Three Point); it follows the armed tool and is hidden while a first point is pending by design (replan-10 chrome). The status now says what the tool wants (decision 16). No change.
- **The WorldGizmos grid draws over the solid in face sketches.** `GRID_HALF 50` is the sketch-plane grid. It is a product-look decision and it never blocked a click or a checker row. No change; revisit only if a walker reports it hides geometry.
- **The constraint chip row overlaps the rail.** After the WP3 sizing fix the rail is 141 px wide and the chip row anchors to `sketch_toolbar`'s right edge; re-measure in sx-033 (row A1). If it still overlaps, record it in the next leftovers.
- **After Extrude the left panel covers the Sketch button.** The same stale `LeftStack` width. WP3 addresses it; re-measure in sx-033.
- **File → New keeps the old radius/distance chips.** `reset_finish_defaults()` already resets Op/End/thin/flip; the radius chip is a user preference and the nut row passes with it. No change.
- **Fillet is not on the left rail.** A layout decision for a later rung; Fillet is on the selection strip and the Modify card, both reachable in the handout.
- **Face select takes two clicks.** By design (click selects the body, the second click refines to the face). The fillet face-first flow does not need it.
- **The A17 Contours row never appeared.** `refresh_contours` shows the row only when `contour_count() > 1` (several closed regions, the blank sketch's three). A wrench jaw sketch has one contour, so the row correctly stays hidden. The Centerline chips are covered by `run_rung01_replan11_chrome.gd`. sx-033 reads A17 only on the blank sketch.
- **Relative-path Save As.** The status prints the resolved path (`Saved <path>`); the dialog now pre-fills the file name. No path-joining change.

## Work packages

| WP | What | Files (hunks) | Test | Depends on |
|---|---|---|---|---|
| WP1 | Fillet face cues, lost-edge warnings, index guard, warning badge | `sxkernel/src/features/ops_dress.cpp`, `sxkernel/include/sx/features.hpp`, `sxkernel/src/features.cpp` (`regenerate`), `sxcore/src/sx_document.{hpp,cpp}`, `game/scripts/property_panel.gd` `_set_param`, `game/scripts/timeline_panel.gd` `_make_row` | `sxkernel/tests/test_rung01_replan12_fillet.cpp` + `run_rung01_replan12_fillet.gd` | none. **The only kernel WP.** `make build`, `make test-kernel` |
| WP2 | Dimension labels: size, stacking, screen-rect hit | `sketch_mode.gd` consts near `DIM_LABEL_OFFSET`, the new label helper functions, `_rebuild_dimension_labels`, `dimension_hit`; `run_rung01_replan6_cut.gd` `_labels_are_stacked` | `run_rung01_replan12_labels.gd` | none |
| WP3 | Left stack no longer swallows canvas clicks; Save As keeps the sketch; Save As dialog name | `main.gd` `_build_ui` (left_stack), `_reflow_left_stack`, `_show_file_dialog`, `_save_current`; `run_rung01_replan11_ux.gd` save check | `run_rung01_replan12_rail.gd`, `run_rung01_replan12_dialog.gd` | none |
| WP4 | Tool statuses (slot, jaw, circle, select, centerline) | `sketch_mode.gd` `set_tool`, `click` (Centerline and Slot arms), `_click_rect` (jaw arm) | `run_rung01_replan12_status.gd` | none; if WP2 merged first, rebase (disjoint hunks) |
| WP5 | Timeline panel closes on Esc and empty click | `viewport_interaction.gd` `cancel_stack` (first rung) and `_on_release` (`_press_empty` branch, one line) | `run_rung01_replan12_panel.gd` | none |
| WP6 | Fillet picks: camera, face-click rule, press off the solid, statuses, Esc ends the pick | `ops_panel.gd` `_apply_dressup`, `_open_last_feature`, `cancel_pending_pick`, `_accumulate_dressup_edge` (+ new functions); `document_view.gd` (new functions after `edge_near_point`, `_polyline_screen_distance`); `main.gd` `open_feature_params`; `viewport_interaction.gd` `cancel_stack` (second rung), `_on_release` (armed branch) | `run_rung01_replan12_pick.gd` | WP5 merged first (same two functions in `viewport_interaction.gd`); rebase on WP3 (`main.gd`) |
| WP7 | Walk, lint, thick row, Makefile | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile`, `tools/check_rung01.py` thick branch | the walk, the lint, `check_rung01.py thick` | **All of WP1–WP6 merged** |

Parallel waves:

| Wave | WPs | Why |
|---|---|---|
| A | WP1, WP2, WP3, WP5 | Different files (kernel + two panels; `sketch_mode.gd` labels; `main.gd`; `viewport_interaction.gd`). Together. |
| B | WP4 (after WP2), WP6 (after WP5 and WP3) | Same-file WPs list disjoint hunks below; rebase before the PR. |
| Last | WP7 | The walk needs every product change; if any of WP1–WP6 is not merged WP7 does not start. |

Merge order: WP1, WP2, WP3, WP5, WP4, WP6, WP7.

Hunks, per file:

- `sketch_mode.gd`: WP2 owns the consts next to `DIM_LABEL_OFFSET` (~142), the helpers inserted before `_rebuild_dimension_labels` (~5035), `_rebuild_dimension_labels` and `dimension_hit` (~5213). WP4 owns `set_tool` (~932), the Centerline commit inside `click` (~3284), the Slot arm of `click` (~3387) and the jaw arm of `_click_rect` (~3465). They share no lines.
- `main.gd`: WP3 owns `_build_ui` left_stack (~476), `_reflow_left_stack` (~1861), `_show_file_dialog` (~3116), `_save_current` (~3141). WP6 owns `open_feature_params` (~1889). No shared lines.
- `viewport_interaction.gd`: WP5 adds the **first** rung to `cancel_stack` (~1574) and one line inside the `_press_empty` branch of `_on_release` (~3376). WP6 adds the **second** rung to `cancel_stack` (right after WP5's rung) and changes the `if _press_empty:` condition and the armed branch below it. Merge WP5 first; WP6's prompt shows the code after WP5.
- C++: WP1 touches exactly `sxkernel/src/features/ops_dress.cpp`, `sxkernel/include/sx/features.hpp`, `sxkernel/src/features.cpp`, `sxcore/src/sx_document.cpp`, `sxcore/src/sx_document.hpp`, and adds `sxkernel/tests/test_rung01_replan12_fillet.cpp` (picked up by the existing glob in `sxkernel/CMakeLists.txt`; `make build` re-runs CMake). No other WP touches C++. After WP1: `make build`, then `make test-kernel` must print `All tests passed (7943 assertions in 333 test cases)` (was 7900 / 330; +3 cases, +43 assertions). `sxcore` gains `graph_warnings()` and the `warning` key in `graph_features()`; Godot must be restarted/rebuilt against the new `libsxcore.so`.

PR titles:

- `Rung 1 replan 12 WP1: fillets survive a thickness edit`
- `Rung 1 replan 12 WP2: dimension labels are clickable where they are drawn`
- `Rung 1 replan 12 WP3: sketch clicks next to the rail, Save As keeps the sketch`
- `Rung 1 replan 12 WP4: sketch tool and slot statuses`
- `Rung 1 replan 12 WP5: timeline panel closes on Esc and click-away`
- `Rung 1 replan 12 WP6: fillet picks use the camera and survive a miss`
- `Rung 1 replan 12 WP7: walk, lint, thick row and Makefile`

## Red and green counts for the new tests

Red = the new test on unmodified `2606160c` (kernel rebuilt from baseline sources). Green = after the WP.

| Test | Red on `2606160c` | Green |
|---|---|---|
| `[replan12]` Catch2 (`test_rung01_replan12_fillet.cpp`) | does not compile (`warnings()` does not exist) | `All tests passed (43 assertions in 3 test cases)` |
| `run_rung01_replan12_fillet.gd` | `19 checks, 6 failures` | `19 checks, 0 failures` |
| `run_rung01_replan12_labels.gd` | `20 checks, 5 failures` | `20 checks, 0 failures` |
| `run_rung01_replan12_rail.gd` | `17 checks, 10 failures` | `17 checks, 0 failures` |
| `run_rung01_replan12_dialog.gd` | `3 checks, 2 failures` | `3 checks, 0 failures` |
| `run_rung01_replan12_status.gd` | `9 checks, 8 failures` | `9 checks, 0 failures` |
| `run_rung01_replan12_panel.gd` | `12 checks, 4 failures` | `12 checks, 0 failures` |
| `run_rung01_replan12_pick.gd` | `27 checks, 16 failures` | `27 checks, 0 failures` |
| `run_rung01_wrench.gd` (WP7 version) on baseline product code | aborts with `handle_crash: Program crashed with signal 11` after 331 `ok` and 21 `FAIL` lines | `456 checks, 0 failures` |

`python3 tools/lint_rung01_e2e.py` ends with `lint_rung01_e2e: 7 replan12 scripts are clean`.

## Whole-suite check (every WP, and WP7 last)

Run every `game/tests/run_*.gd` with `timeout 120` (`make test-godot` alone stops at the first failure). Run the suites **one at a time with nothing else running**: under load `run_rung01_sketch_tests` once printed `58 checks, 22 failures` and then `70/7` on a quiet rerun. All suites were measured on `2606160c` and again with every WP applied.

| Suite (`timeout 120 tools/godot/godot --headless --path game --script res://tests/<suite>.gd`) | On `2606160c` | After all WPs | Note |
|---|---|---|---|
| `run_assembly_tests` | 87 checks, 4 failures | 87 checks, 4 failures | pre-existing |
| `run_camera_tests` | 104 checks, 0 failures | 104 checks, 0 failures |  |
| `run_catalog_tool_tests` | 15 checks, 0 failures | 15 checks, 0 failures |  |
| `run_chamfer_sketch_layout_tests` | 9 checks, 0 failures | 9 checks, 0 failures |  |
| `run_clearance_tests` | 23 checks, 0 failures | 23 checks, 0 failures |  |
| `run_construction_tests` | 22 checks, 0 failures | 22 checks, 0 failures |  |
| `run_convert_entities_tests` | 4 checks, 0 failures | 4 checks, 0 failures |  |
| `run_critic_walk_tests` | 46 checks, 0 failures | 46 checks, 0 failures |  |
| `run_dead_chrome_tests` | 28 checks, 0 failures | 28 checks, 0 failures |  |
| `run_display_tests` | 88 checks, 0 failures | 88 checks, 0 failures |  |
| `run_drag_tests` | 33 checks, 0 failures | 33 checks, 0 failures |  |
| `run_film_caption_tests` | no summary line (rc=0) | no summary line (rc=0) | prints no summary line; rc 0 |
| `run_film_manifest_smoke` | no summary line (rc=124) | no summary line (rc=124) | prints no summary line; times out at 120 s on both trees (rc 124) |
| `run_help_tests` | 251 checks, 0 failures | 251 checks, 0 failures |  |
| `run_hole_wizard_tests` | 11 checks, 0 failures | 11 checks, 0 failures |  |
| `run_howto_tests` | 91 checks, 2 failures | 91 checks, 2 failures | pre-existing (Alt-orbit / nav preset) |
| `run_icon_tests` | 13 checks, 2 failures | 13 checks, 2 failures | pre-existing (a 1-2 char button without an icon) |
| `run_infer_tests` | 44 checks, 0 failures | 44 checks, 0 failures |  |
| `run_insert_component_tests` | 42 checks, 2 failures | 42 checks, 2 failures | pre-existing |
| `run_layout_tests` | 33 checks, 0 failures | 33 checks, 0 failures |  |
| `run_mate_tests` | 15 checks, 0 failures | 15 checks, 0 failures |  |
| `run_measure_overlay_tests` | 91 checks, 0 failures | 91 checks, 0 failures |  |
| `run_mechanic_blocker_tests` | 33 checks, 0 failures | 33 checks, 0 failures |  |
| `run_menu_tests` | 55 checks, 2 failures | 55 checks, 2 failures | pre-existing |
| `run_mirror_feature_tests` | 20 checks, 0 failures | 20 checks, 0 failures |  |
| `run_move_snap_tests` | 21 checks, 0 failures | 21 checks, 0 failures |  |
| `run_open_in_slicer_tests` | 6 checks, 0 failures | 6 checks, 0 failures |  |
| `run_parse_sweep_tests` | 238 checks, 0 failures | 245 checks, 0 failures | parses every `game/tests/*.gd`: +7 new files |
| `run_place_tests` | 110 checks, 1 failures | 110 checks, 1 failures | pre-existing (nav preset) |
| `run_pliers_motion_tests` | 26 checks, 0 failures | 26 checks, 0 failures |  |
| `run_print_tests` | 9 checks, 0 failures | 9 checks, 0 failures |  |
| `run_property_tests` | 17 checks, 1 failures | 17 checks, 1 failures | pre-existing |
| `run_rung01_chrome_tests` | 41 checks, 0 failures | 41 checks, 0 failures |  |
| `run_rung01_fillet_tests` | 30 checks, 0 failures | 30 checks, 0 failures |  |
| `run_rung01_replan10_cut` | 114 checks, 0 failures | 114 checks, 0 failures |  |
| `run_rung01_replan10_esc` | 25 checks, 0 failures | 25 checks, 0 failures |  |
| `run_rung01_replan10_new` | 19 checks, 0 failures | 19 checks, 0 failures |  |
| `run_rung01_replan10_trim` | 38 checks, 0 failures | 38 checks, 0 failures |  |
| `run_rung01_replan11_chrome` | 6 checks, 0 failures | 6 checks, 0 failures |  |
| `run_rung01_replan11_dim` | 11 checks, 0 failures | 11 checks, 0 failures |  |
| `run_rung01_replan11_dimhit` | 6 checks, 0 failures | 6 checks, 0 failures |  |
| `run_rung01_replan11_esc` | 10 checks, 0 failures | 10 checks, 0 failures |  |
| `run_rung01_replan11_fillet_err` | 8 checks, 0 failures | 8 checks, 0 failures |  |
| `run_rung01_replan11_fillet_ui` | 14 checks, 0 failures | 14 checks, 0 failures |  |
| `run_rung01_replan11_poly` | 8 checks, 0 failures | 8 checks, 0 failures |  |
| `run_rung01_replan11_slot` | 9 checks, 0 failures | 9 checks, 0 failures |  |
| `run_rung01_replan11_trim` | 12 checks, 0 failures | 12 checks, 0 failures |  |
| `run_rung01_replan11_ux` | 12 checks, 0 failures | 12 checks, 0 failures | WP3 changes the save check, same count |
| `run_rung01_replan11_views` | 13 checks, 0 failures | 13 checks, 0 failures |  |
| `run_rung01_replan12_dialog` | file absent | 3 checks, 0 failures | new (WP 3) |
| `run_rung01_replan12_fillet` | file absent | 19 checks, 0 failures | new (WP 1) |
| `run_rung01_replan12_labels` | file absent | 20 checks, 0 failures | new (WP 2) |
| `run_rung01_replan12_panel` | file absent | 12 checks, 0 failures | new (WP 5) |
| `run_rung01_replan12_pick` | file absent | 27 checks, 0 failures | new (WP 6) |
| `run_rung01_replan12_rail` | file absent | 17 checks, 0 failures | new (WP 3) |
| `run_rung01_replan12_status` | file absent | 9 checks, 0 failures | new (WP 4) |
| `run_rung01_replan2_camera` | 50 checks, 0 failures | 50 checks, 0 failures |  |
| `run_rung01_replan2_commit` | 35 checks, 0 failures | 35 checks, 0 failures |  |
| `run_rung01_replan2_distance` | 32 checks, 0 failures | 32 checks, 0 failures |  |
| `run_rung01_replan2_layout` | 22 checks, 0 failures | 22 checks, 0 failures |  |
| `run_rung01_replan2_pointer` | 37 checks, 0 failures | 37 checks, 0 failures |  |
| `run_rung01_replan2_shell` | 63 checks, 0 failures | 63 checks, 0 failures |  |
| `run_rung01_replan3_blank` | 62 checks, 0 failures | 62 checks, 0 failures |  |
| `run_rung01_replan3_distance` | 48 checks, 0 failures | 48 checks, 0 failures |  |
| `run_rung01_replan3_fillet` | 60 checks, 0 failures | 60 checks, 0 failures |  |
| `run_rung01_replan3_input` | 110 checks, 1 failures | 110 checks, 1 failures | pre-existing |
| `run_rung01_replan3_shell` | 43 checks, 6 failures | 43 checks, 6 failures | pre-existing |
| `run_rung01_replan3_timeline` | 105 checks, 1 failures | 105 checks, 1 failures | pre-existing |
| `run_rung01_replan4_dialog` | 47 checks, 0 failures | 47 checks, 0 failures |  |
| `run_rung01_replan4_numeric` | 59 checks, 0 failures | 59 checks, 0 failures |  |
| `run_rung01_replan4_smartdim` | 47 checks, 0 failures | 47 checks, 0 failures |  |
| `run_rung01_replan5_face` | 98 checks, 0 failures | 98 checks, 0 failures |  |
| `run_rung01_replan5_session` | 63 checks, 0 failures | 63 checks, 0 failures |  |
| `run_rung01_replan5_shell` | 96 checks, 0 failures | 96 checks, 0 failures |  |
| `run_rung01_replan5_smartdim` | 66 checks, 0 failures | 66 checks, 0 failures |  |
| `run_rung01_replan5_trim` | 117 checks, 1 failures | 117 checks, 1 failures | pre-existing |
| `run_rung01_replan6_chrome` | 64 checks, 0 failures | 64 checks, 0 failures |  |
| `run_rung01_replan6_cut` | 100 checks, 0 failures | 100 checks, 0 failures | WP2 rewrites `_labels_are_stacked`, same count |
| `run_rung01_replan6_export` | 56 checks, 0 failures | 56 checks, 0 failures |  |
| `run_rung01_replan6_smartdim` | 81 checks, 0 failures | 81 checks, 0 failures |  |
| `run_rung01_replan7_anchor` | 5 checks, 0 failures | 5 checks, 0 failures |  |
| `run_rung01_replan7_facepick` | 31 checks, 0 failures | 31 checks, 0 failures |  |
| `run_rung01_replan8_cut` | 13 checks, 0 failures | 13 checks, 0 failures |  |
| `run_rung01_replan8_esc` | 20 checks, 0 failures | 20 checks, 0 failures |  |
| `run_rung01_replan8_rail` | 89 checks, 0 failures | 89 checks, 0 failures |  |
| `run_rung01_replan8_shaft` | 37 checks, 0 failures | 37 checks, 0 failures |  |
| `run_rung01_replan9_chip` | 23 checks, 0 failures | 23 checks, 0 failures |  |
| `run_rung01_replan9_dim` | 35 checks, 0 failures | 35 checks, 0 failures |  |
| `run_rung01_replan9_dirty` | 13 checks, 0 failures | 13 checks, 0 failures |  |
| `run_rung01_replan_finishbar` | 53 checks, 0 failures | 53 checks, 0 failures |  |
| `run_rung01_replan_input` | 37 checks, 0 failures | 37 checks, 0 failures |  |
| `run_rung01_replan_panel` | 29 checks, 0 failures | 29 checks, 0 failures |  |
| `run_rung01_replan_shell` | 34 checks, 1 failures | 34 checks, 1 failures |  |
| `run_rung01_replan_sketch` | 56 checks, 0 failures | 56 checks, 0 failures |  |
| `run_rung01_sketch_tests` | 70 checks, 7 failures | 70 checks, 7 failures | pre-existing; flakes under load (58/22 once) |
| `run_rung01_wrench` | 413 checks, 0 failures | 456 checks, 0 failures | WP7 adds 43 checks; needs `DISPLAY=:1`, run alone |
| `run_see_the_print_tests` | 8 checks, 0 failures | 8 checks, 0 failures |  |
| `run_select_tests` | 100 checks, 0 failures | 100 checks, 0 failures |  |
| `run_sketch_expr_dim_tests` | 6 checks, 0 failures | 6 checks, 0 failures |  |
| `run_sketch_fully_defined_tests` | 6 checks, 0 failures | 6 checks, 0 failures |  |
| `run_sketch_parity_tests` | 30 checks, 0 failures | 30 checks, 0 failures |  |
| `run_sketch_tests` | 83 checks, 0 failures | 83 checks, 0 failures |  |
| `run_sketch_to_3d_ui_tests` | 47 checks, 2 failures | 47 checks, 2 failures | pre-existing |
| `run_sketch_tools_tests` | 141 checks, 13 failures | 141 checks, 13 failures | pre-existing |
| `run_sweep_loft_solid_tests` | 30 checks, 0 failures | 30 checks, 0 failures |  |
| `run_tests` | 97 checks, 0 failures | 97 checks, 0 failures |  |
| `run_timeline_ux_tests` | 35 checks, 0 failures | 35 checks, 0 failures |  |
| `run_triball_hex_polish_tests` | 19 checks, 0 failures | 19 checks, 0 failures |  |
| `run_ui_button_coverage_tests` | no summary line (rc=1) | no summary line (rc=1) | prints no summary line; rc 1 on both trees (36 checks, 3 failures, 35 buttons probed) |
| `run_ui_scroll_tests` | 5 checks, 0 failures | 5 checks, 0 failures |  |
| `run_ui_tests` | 275 checks, 0 failures | 275 checks, 0 failures |  |
| `run_viewcube_tests` | 39 checks, 0 failures | 39 checks, 0 failures |  |
| `run_visibility_tests` | 34 checks, 0 failures | 34 checks, 0 failures |  |
| `run_visual_ux_tests` | 86 checks, 1 failures | 86 checks, 1 failures | pre-existing |
| `run_voice_tests` | 29 checks, 0 failures | 29 checks, 0 failures |  |
| `run_workflow_tests` | 82 checks, 0 failures | 82 checks, 0 failures |  |
| `run_wrench_blockers_tests` | 36 checks, 0 failures | 36 checks, 0 failures |  |
| `run_wrench_chrome_tests` | 6 checks, 0 failures | 6 checks, 0 failures |  |
| `run_wrench_cut_tests` | 21 checks, 0 failures | 21 checks, 0 failures |  |
| `run_wrench_placement_tests` | 18 checks, 0 failures | 18 checks, 0 failures |  |
| `run_wrench_through_tests` | 23 checks, 0 failures | 23 checks, 0 failures |  |

Every suite not in the pre-existing-failure list prints `0 failures`. The pre-existing mismatches are the same ones replan 11 listed (nav preset `FUSION` vs tests that assume `SOLIDEXPRESS`; one `run_infer_tests`-style DOF mismatch; the icon test). Do not flip `nav_preset` and do not edit those tests to hide a failure.

Deltas this plan requires (everything else is identical before and after):

| Suite | On `2606160c` | After all WPs |
|---|---|---|
| `run_parse_sweep_tests` | 238 checks, 0 failures | 245 checks, 0 failures (it parses every `game/tests/*.gd`; +7 new files) |
| `run_rung01_wrench` | 413 checks, 0 failures | 456 checks, 0 failures (WP7 adds 43) |
| `run_rung01_replan12_fillet` / `_labels` / `_rail` / `_dialog` / `_status` / `_panel` / `_pick` | file absent | 19 / 20 / 17 / 3 / 9 / 12 / 27 checks, 0 failures |
| `run_rung01_replan6_cut` | 100 checks, 0 failures | 100 checks, 0 failures (WP2 rewrites `_labels_are_stacked`, same count) |
| `run_rung01_replan11_ux` | 12 checks, 0 failures | 12 checks, 0 failures (WP3 changes the save check, same count) |
| `make test-kernel` | `All tests passed (7900 assertions in 330 test cases)` | `All tests passed (7943 assertions in 333 test cases)` |
| `python3 tools/lint_rung01_e2e.py` | `11 replan11 scripts are clean` last line | adds `7 replan12 scripts are clean` |
| `python3 tools/test_check_rung01.py` | `Ran 4 tests … OK` | unchanged |

## sx-033 GUI checklist

Walk order, same as sx-032, with the new rows inserted where they belong: A1, A2, A3, A4, A5, A5b, A7, A6, A7b, A8, A8b, A9 (includes A17), **A9c**, A9b, A16, A11a, A11b, A11c, A11d, **A11e**, A12, A13, **A13b**, **A13c**, then scratch A10, A10b, A14, then A15. Keep the blank open through A13c. A10 and A14 start a new document. Keep the sx-032 row ids.

| Row | WP | Action | Pass looks like |
|---|---|---|---|
| A1 | carry, WP3 | Read the left rail in a new sketch | All 18 labels. The chip row does not run over the rail |
| A2 | carry | Press Jaw, then Rect | Jaw status, then `Rect — click 1 first corner, click 2 the opposite corner`. Chips Center / Three Point, then Corner |
| A3 | carry | Ø20 at the origin, Ø45 to the right, Smart Dim the two centres along +X, type 200 | `Dimension updated`. Head centre y within 0.05 of the pivot y |
| A4 | carry | Shaft Lines | `Shaft lines: 2 added` |
| A5 | carry | Extrude 10, export | blank **5/5** |
| A5b | carry | Discard Cancel, then Save As `blank.sxp` | Cancel keeps the blank. The dialog opens on `blank.sxp` or `untitled.sxp`, not `*.3mf` (WP3) |
| A7 | carry | Sketch on the top face | `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)` |
| A6 | carry | Circle tool, one click, Esc, Esc | `First point dropped — Esc again exits the sketch`, then exit. Exactly two presses. The Circle press itself reads `Circle — click the centre, then the rim (or type a radius)` (WP4) |
| A7b | carry | Sketch on the top face again | Face sketch opens |
| A8 | WP2, WP4 | Jaw, width 20. **One click on the first glyph** of the width label, then of the angle label. Type 45 on the angle | After the jaw commit the status reads `Jaw committed — width …, long side …° — click a label to edit it`. Each label opens on the **first** click with the text selected (no second click). `Dimension updated`. Walls at 45°; included angle 90° ± 0.05° |
| A8b | carry | Select a jaw line, Esc ladder | `Selection cleared — …`, sketch still there. Selecting the Select tool reads `Select — click geometry, or a dimension label to edit it` |
| A9 | WP3 | Pivot hole **at the origin next to the left rail**: Circle, click the origin, type the radius or click the rim | The first click lands (status/preview follows). Never move or zoom the view to dodge the rail; one repeated dead click is a product failure. Then the along-jaw construction line and the cross-jaw cutter; Power Trim on the shaft side: `Trimmed open jaw`, then `Jaw is already open — nothing left to trim here` |
| A17 | carry | While drawing those lines read the Line/Centerline chips and (blank sketch only) the Contours row | Chips do not overlap. The Contours row shows only when the sketch has more than one closed region. A Centerline commit reads `Centerline added — construction, not part of the profile` |
| A9c | WP3 | File → Save As while the jaw sketch is open; name it; OK | `Saved <path>`; the sketch finish bar and Select tool are still there; the profile is still drawn; Extrude on it still works |
| A9b | carry | Cut, Up To Surface, opposite face | Closed jaw cut |
| A16 | carry | View menu; keys `4`, `6`, `8`; orbit off Top | Back/Left/Bottom in the menu; the camera moves |
| A11a | WP4 | Slot R5, 150 centre to centre, cut blind 2.5 | **Read back `Slot c-c 150.0000 R5.0000`** (add ` — typed` if you typed the length). If wrong, Smart Dim the c-c to 150. Then the cut |
| A11b | WP6 | Fillet armed. Key `3` (Top). **Click each neck corner.** Then key `4` (Back) and click the +Y wall; then press on empty background. Enter at radius 10 | Corner click status `Fillet: 1 edge(s) — 10.0 mm vertical …` (not the 32.3 mm arc). A wall click keeps the earlier pick (adds an edge only if one is within 14 px, otherwise `No edge near click …`). The press off the solid says `Missed the solid — click a face or edge` and keeps the set and the panel. Enter: `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters` (not `Feature created`) |
| A11c | WP6 | Add one wrong edge, click it again | Status ends `— removed <length> mm <kind>` (e.g. `removed 179.8 mm line`). Enter on the two verticals still applies |
| A11d | carry | Select the top face first, Fillet, Enter at radius 1 (after the neck fillet), then the bottom face | Applies; never `No edges selected — cancelled` while a face is selected. On a sharp neck `fillet the R10 neck first` |
| A11e | WP6 | **Slot-floor R1 from Top, after the top and bottom faces.** Fillet, radius 1, key `3`, click the slot floor face, Enter | Applies (`Fillet <n> edges 1.00 applied …`). Press Esc once after any refused attempt: the status reads `Edge pick cancelled` and Fillet is no longer armed |
| A12 | carry | Export `wrench.3mf` | wrench **28/28**, `flipX=False flipY=False` |
| A13 | carry | Timeline, first extrude, Distance 14 (text pre-selected), Enter | The distance previews 14; the status carries no `lost on rebuild` text |
| A13b | WP5 | With the Distance field still focused press **Esc**; reopen, type 14 Enter; then **click empty viewport** | Esc closes the panel and the distance returns to 10 (`Edits cancelled`). The empty click closes the panel and keeps 14 |
| A13c | WP1, WP7 | Export `wrench-t14.3mf`; run `check_rung01.py thick wrench-t14.3mf 14`; also run `check_rung01.py wrench wrench-t14.3mf` as **DIAG** | thick **6/6** including `1mm top fillet at new T`. DIAG header reports about **5760 tris** (2438 means the fillets were lost). DIAG is `18/22`: exactly `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge` and `1mm fillet on jaw top edge` fail (their probes hard-code z=10); `head-shaft R10 fillet ±Y`, `R10 fillet not oversized` and `1mm fillet bottom outer edge` PASS. Record every fillet row |
| A10 | carry | Ø100 extruded, Ø90 cut on the face | Exact `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.` |
| A10b | carry | File → New, read the finish bar | New / Blind / Extrude enabled |
| A14 | carry | Polygon, centre click, type AF 20 with the pointer off the X axis. Hole radius 5. Extrude 7.5 | nut **7/7**; status contains `flats horizontal` |
| A15 | WP7 | lint and `run_rung01_wrench.gd` | lint prints `7 replan12 scripts are clean`; walk `456 checks, 0 failures` |

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 6/6, walk 0 failures, first-try fillets from Top (key `3`), Front (`1`), Back (`4`) or Iso (`7`).

## Soft-GL protocol (sx-033 walker)

Rules 1–16 of replan 10 and 17–22 of replan 11 still apply:

17. **View keys, not a hidden camera.** Neck fillets are picked from key `1` (Front), `3` (Top), `4` (Back) or `7` (Iso). Zoom with the wheel or Frame (`F`). If a Top-view corner click selects a long edge, the status names its length; click that edge again to remove it, then click the corner once more. Do not orbit with a test helper.
18. **Fillet refusal is specific.** `exceeds the … mm limit` means remove the named edge or lower the radius. `fillet the R10 neck first` means do the two vertical neck edges at R10, then the faces at R1. A bare `too large for selected edge(s)` is a product failure.
19. **Trim with the leftover line still there.** Draw the along-jaw construction line and leave it. If the status names the along-jaw line, delete that one line and click Trim again; record it. Silence or a refusal that does not name a line fails A9.
20. **Dimension labels are one click.** Select tool, one click, read the field, type, Enter. A double-click is not required. If the first click does nothing, repeat once (rule 2) and then fail the row.
21. **Polygon pointer.** After the centre click, move the pointer off-axis on purpose, then type `20` in the AF field. The nut checker is the pass.
22. **Thickness.** The slot must be open at the new top. A thick row failing is a product failure even if the other rows pass.

New in this replan:

23. **Read the slot back.** After the Slot tool's second click read the status `Slot c-c 150.0000 R5.0000` before cutting. If it differs, Smart Dim the centre-to-centre to 150 and re-read. A slot of 150.3466 is a walker slip, not a tool bug.
24. **Read every typed or resolved path back.** Save As and Export status lines print the resolved path (`Saved <path>`, `Exported 3MF → <path>`). A relative name is joined silently, so confirm the directory in the status before moving on.
25. **Slot-floor R1 from Top, after the top and bottom faces.** Fillet, radius 1, key `3`, click the slot floor face, Enter. A refused R1.5 attempt first is fine; end it with one Esc (`Edge pick cancelled`) before the next arm.
26. **After the T=14 export run the wrench checker as DIAG** and record the fillet rows (see A13c). The thick checker is the pass; DIAG is the evidence.
27. **Click the first glyph of a label, not its centre.** The label is a rectangle of drawn text; the first glyph is inside it at every zoom. Never click the centre of a long label such as `Ø45`.
28. **Never move the view to dodge the left rail.** A sketch click 30 px right of the visible rail must land. A dead click there is a product failure after one repeat (rule 2): record the hovered control if the tooling shows it and stop the row.
29. **Esc ends an armed pick.** If Fillet stays armed after one Esc (the status does not say `Edge pick cancelled`), that is a product failure; do not press Esc a third time to hide it.
30. **No llvmpipe, Mesa or renderer changes.** Soft-GL dropped keystrokes three times in sx-032 (`/` in Save As, radius `2.5`, radius `2.0`); read-back caught all three. That stays the rule (keep 1–22): read back before you commit. No driver WP.

## Out of scope

- Soft-GL / llvmpipe / Mesa / Godot renderer. Switching Godot off 4.7-stable.
- Checker formulas or tolerances other than the one thick row in decision 11.
- `docs/plan/*` and wave features. The snadrus fork. PR #11.
- The replan-10/11 work listed under "What stayed green".
- A kernel blend that fillets the jaw-mouth arc while the neck is sharp (replan-11 decision 1).
- Test-only cameras, `_look_along`, `set_view(`, writing `camera.yaw` / `camera.pitch`, `select_entity` or script-side selection in walk or e2e **picks**. The seven replan12 suites are validation suites: they may place a primitive and arm Fillet with `select_entity`, but every press, key and camera move under test is a real event or key tap.
