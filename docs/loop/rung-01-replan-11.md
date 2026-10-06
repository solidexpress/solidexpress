# Rung 1 replan 11 — fillet picking, trim cutter, Esc/dim labels, slot follows face

Status: plan only. No product code in this change.

Baseline: `main` at `b3161bba1101e77a124744dbb3a4aff8e9bf6bf3` (replan-10 WP1–WP5, #108–#112). Replan 10 is [`rung-01-replan-10.md`](rung-01-replan-10.md). The sx-031 critique of that build scored **8.5/10** and failed rung 1. Leftovers, verbatim: [`rung-01-leftovers-sx031.md`](rung-01-leftovers-sx031.md). Do not re-critique sha256 `656a40bd`.

BUILD agents are grok-4.6 high. Each work package has its own prompt. Launch a BUILD agent with that file alone:

| WP | Prompt |
|---|---|
| WP1 | [`rung-01-replan-11-wp1.md`](rung-01-replan-11-wp1.md) |
| WP2 | [`rung-01-replan-11-wp2.md`](rung-01-replan-11-wp2.md) |
| WP3 | [`rung-01-replan-11-wp3.md`](rung-01-replan-11-wp3.md) |
| WP4 | [`rung-01-replan-11-wp4.md`](rung-01-replan-11-wp4.md) |
| WP5 | [`rung-01-replan-11-wp5.md`](rung-01-replan-11-wp5.md) |
| WP6 | [`rung-01-replan-11-wp6.md`](rung-01-replan-11-wp6.md) |
| WP7 | [`rung-01-replan-11-wp7.md`](rung-01-replan-11-wp7.md) |
| WP8 | [`rung-01-replan-11-wp8.md`](rung-01-replan-11-wp8.md) |
| WP9 | [`rung-01-replan-11-wp9.md`](rung-01-replan-11-wp9.md) |
| WP10 | [`rung-01-replan-11-wp10.md`](rung-01-replan-11-wp10.md) |
| WP11 | [`rung-01-replan-11-wp11.md`](rung-01-replan-11-wp11.md) |

The prompts are the implementation. This file is the decisions, the merge order, the suite table, and the sx-032 checklist. Do not redesign anything a prompt already specifies.

Godot stays `tools/godot/godot` (4.7-stable). Do not switch the pin to 4.7.1. Set `LD_LIBRARY_PATH=<occt prefix>/lib` (the pin is `/opt/occt-8.0.1/lib`) before every Godot command. The first Godot run on a fresh checkout bakes `game/.godot`; run `tools/godot/godot --headless --path game --import` once first. Do not commit `.gd.uid` files.

Line numbers below and in the prompts were read on `b3161bba`. `git apply` is not required; each prompt says which function to edit. After another WP has landed, search for the function name rather than trusting a shifted line number.

The red and green counts in each prompt are the `check()` calls written there. This plan was written by reading that baseline. BUILD runs the commands and treats a mismatch as a product failure.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and the first try works. sx-031 passed every checker on GUI files, but only after careful picks and one manual delete. This plan removes those traps:

- A click at a neck corner from Top or Iso picks the vertical neck edge. Back, Left and Bottom views exist, the View menu opens, and a vertical orbit drag off Top view moves the camera.
- Re-clicking a fillet edge removes it. A refused fillet names the limit or the faulty edge and says to fillet the R10 neck first. A face selected first, then Fillet and Enter, fillets that face's edges.
- Power Trim ignores a leftover along-jaw construction line when a real cross-jaw cutter is present, and the refusal names the line.
- Esc after a Circle, Line, Rect or Polygon first point takes exactly two presses.
- One click on any driving dimension label, including an angle, opens the editor with the value selected. Typing 45 on the jaw angle yields walls at 45° and a perpendicular floor.
- The Centerline chip does not sit on the Contours row.
- A typed across-flats polygon is flats-horizontal whatever the pointer is doing.
- A thickness edit moves sketches that were drawn on a face, so the grip slot stays open from the new top. Thick mode is **5/5**.
- The headless walk picks from the same view keys and buttons a person can press. No `_look_along`.

**Pass bar.** Score ≥ 9. nut 7/7, blank 5/5, wrench 28/28, thick **5/5** on files exported from the GUI. Walk 0 failures. `run_rung01_wrench.gd` 0 failures. The part was made in the real GUI with no script-side shortcut. **First-try fillets from the views the app offers.**

Checker commands (thick gained one row; the other three are unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf          # 5/5
python3 tools/check_rung01.py nut    nut.3mf            # 7/7
python3 tools/check_rung01.py wrench wrench.3mf         # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14  # 5/5
```

Do not pass `--allow-mirror`. Exit code 0 is the pass. Do not change any other checker formula.

## What stayed green (do not redo)

Power Trim reaches `Trimmed open jaw`, then `Jaw is already open — nothing left to trim here`. The Up To Surface jaw cut is closed (fuzzy boolean). An open shell is refused by name. The Esc ladder keeps a sketch that holds geometry (`Selection cleared — …`, `Tool dropped — …`). File → New resets Op/End. A10 stays the exact sentence `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.` Headless on this tip: `run_rung01_wrench.gd` **404/0**; replan10 cut 114/0, esc 25/0, new 19/0, trim 38/0; lint `4 replan10 scripts are clean`.

## Decisions (nothing left open)

1. **Fillet order is (b), status only.** DIAG §3B measured OCCT `NbFaultyContours = 1` on the head arc from the +Y jaw mouth to the sharp neck, at every radius from 0.25 to 2. Two-pass `MakeFillet` and edge-by-edge sequential retries fail, including on an idealised 45° jaw. Do not add a kernel blend strategy. When `last_graph_error()` contains `fillet failed` and does not contain `limit `, the status is `Fillet could not be built on <n> edge(s) (<faulty edge>) — fillet the R10 neck first, or pick fewer edges`. That sentence is the offer. The walk fillets the two vertical neck edges at R10 from Front (key `1`) or Top (key `3`) before either face R1. No second fillet is committed automatically.

2. **End-on pick.** `edge_near_point` keeps the 2.5 mm 3D gate. When a `Camera3D` is passed, the winner among edges inside that gate is the one whose screen polyline is closest to the unprojected hit. If two screen distances are within 8 px, the edge whose direction is more parallel to the camera ray wins (the end-on edge). A click on the neck corner from Top therefore picks the vertical 10 mm edge, not the long top edge. Callers that pick for the user (`select_ray`, `_accumulate_dressup_edge`) pass the viewport camera. A null camera keeps today's 3D-only behaviour so old call sites still compile.

3. **Views.** Keys `4` Back (yaw 180°, pitch 0), `6` Left (yaw −90°, pitch 0), `8` Bottom (yaw 0, pitch −89°). Same angles as `ViewWidget.angles_for` and `VoiceExecutor._do_view`. Keys `1` `2` `3` `7` `5` are unchanged. The word `View` becomes a button, the chevron button is named `ViewsDrop` with text `▼` and a 28×28 hit rect, and the popup rect is shifted by the window's screen position. Space's orientation list grows the same three entries.

4. **Orbit off Top is a clamp bug.** Top sets pitch to `MAX_PITCH` (89°). `_orbit_by` adds `dy * ORBIT_SPEED` and clamps, so a drag that increases pitch does nothing. When the requested pitch passes ±89°, add π to yaw and fold the excess back inside the range (orbit through the pole). Same fold on the two-finger pan-gesture orbit (`orbit_camera.gd` around line 289). Fusion middle-drag stays pan; this fix is the orbit path only.

5. **Trim cutter.** A construction line qualifies when its segment crosses both long jaw sides (the two longest non-construction lines within 2° of `_longest_profile_dir`) and its direction is not within 2° of that jaw direction. The click picks the nearest qualifier. If none qualify, fall back to `_nearest_construction_line(pos, 40)`. The refusal when the chosen line is within 2° of the jaw, or when it does not produce two walls, is exactly: `Trim failed — the construction line nearest your click runs along the jaw (from %.1f,%.1f to %.1f,%.1f); draw a centreline across the jaw or delete the along-jaw line`. The existing `Trimmed open jaw` and `Jaw is already open — nothing left to trim here` sentences stay.

6. **Construction toggle replace-first is jaw-scoped.** `toggle_construction_selected` (Construction chip and the X key, which already call it) deletes other cutters only when it is turning a line **on**, a jaw exists (two long sides), and the toggled line crosses both long sides or lies within 2° of the jaw with its midpoint inside the jaw AABB expanded by 2 mm. Only other non-datum construction lines that pass that same test are removed. Datum lines in `_angle_datum_lines` stay. Status: `Removed %d jaw construction line(s) — one cutter at a time`. The Centerline **tool** still calls `_delete_other_non_datum_construction_lines` (replan 10, green). Do not call that unrestricted helper from the toggle.

7. **Esc.** In `_sketch_input`'s `KEY_ESCAPE` arm, the `has_pending_draw_point()` rung moves above `measure_overlay.has_anchor()`. That same press calls `measure_overlay.clear_pair()` when an anchor exists, then `cancel_pending_draw()`, then emits `First point dropped — Esc again exits the sketch`. The next press is the existing ladder (selection, tool, then exit). Circle, Line, Rect and Polygon all set `has_pending_draw_point` at one point. Do not remove the measure-anchor rung; it still runs when there is no pending draw point.

8. **Dimension hit.** Store the label position actually drawn, including the overlap nudge, on the dimension dictionary as `label_pos`. `dimension_hit` tests that stored point, not a freshly computed one. An angle label is placed at the intersection of its two lines plus 8 mm along the bisector, not at `_closest_endpoints` (the jaw angle's datum +X and the wall do not share an endpoint, so the old anchor misses the glyphs). Also accept a click within 22 screen pixels of the projected label. `_show_dim_edit` pops the editor in screen coordinates (`window.position` added) and selects the line text. One Select click is enough. Typing `45` and Enter still goes through `set_dimension_value` (values greater than π are degrees).

9. **The 89.71° floor is the trim snap, not a missing constraint.** Trim writes the floor along the cutter (`_snap_jaw_hits_through_centre`) and then adds `perpendicular` (`sketch_mode.gd` 2518). The sx-031 floor sat at exactly 135° while the walls sat at 45.2868°, so the included angle was 89.71° even though constraint `99475fbe` existed: the solver started from a floor locked to the cutter and did not reach 90°. After the two wall hits are known, rewrite the floor so it passes through the cap centre and is perpendicular to wall 0, then add the constraint and solve. Editing the angle to 45° then leaves the floor perpendicular. Do not change PlaneGCS.

10. **Polygon.** In `across_flats`, snap `start_angle` to the nearest multiple of 30°. When the second point came from a typed length (`_length_override` consumed in `click`), `start_angle` is 0 (vertices on ±X, flats at y = ±AF/2). Status: `Polygon AF %.4f — flats horizontal`. The preview uses the same snap. A centre click plus typed AF 20 is 7/7 with the pointer anywhere.

11. **Sketch support face.** Chosen selector: feature id of the body (`feature_of_body`) plus unit normal plus `"max"` or `"min"`. Stored on the sketch feature's params (they already round-trip in `timeline[].params`) as `support_host`, `support_normal` `[x,y,z]`, `support_side`. On `FeatureType::Sketch` apply, if those keys exist, find the planar face of the host feature's `output_body` with the same normal (dot ≥ 0.999, face orientation applied) and the max or min plane offset along that normal, and set the sketch plane origin to `normal * offset` (part origin projected onto that plane). `x_dir` and `y_dir` stay. Documents without the keys keep the absolute plane. `Sketch::set_plane` is new and does not clear entities. GDScript writes the keys with the existing `graph_set_params_no_regen` after `graph_add_sketch`, merging into the current params object (`set_params` replaces the whole object). Ground sketches and `begin_on_plane` write no keys. `_start_sketch_on_face` records the side from face bboxes before `begin`.

12. **Thick checker.** One new row, not three. It passes only when all three probes pass: open at `(slot x-centre, 0, T−1.25)`, floor at `T−2.5` within 0.2, and `(x-centre, 0, T−0.5)` outside. Slot x-centre is the median open sample on `y=0`, `z=T−1.25`, x in `[60, 130)`, same search the wrench row uses at z=8.75. thick 4/4 becomes 5/5. This is the only checker change.

13. **Smart Dim centre distance infers horizontal: yes.** When the second circle centre is within 2° of the X axis from the first (`abs(dy) <= tan(2°) * abs(dx)`), add a construction line through the two centres, coincident at each centre, and `horizontal`, then the existing distance. Both constraints stay. A 200 mm centre distance drawn almost along +X no longer leaves the head at y = 0.218.

14. **Body click does not arm Fillet.** Verified: `_on_picked` calls `_accumulate_dressup_edge` only when `_pending` is already `FILLET_EDGES` or `CHAMFER_EDGES`. No selection handler calls `_arm_dressup`. WP3 adds the same guard inside `_accumulate_dressup_edge` and a test that two body clicks leave `_pending == NONE`. Do not change `_fillet_all` / `_round_targets`: the Modify-card Fillet button still fillets every edge when the card is pressed with only a body selected. That button is the Fillet tool. A stray viewport click is not.

15. **False `Sketch on ground (XY)`.** `_start_sketch_on_face` currently seeds that sentence and calls `begin` even when the face plane was not accepted. If `face_id` is set and the plane is not ok, do not call `begin`; emit the derive message and return. The cancel path (`sketch_mode.cancelled` → `_on_sketch_session_ended`) then emits `Sketch cancelled`, so Sketch → Esc cannot leave the ground sentence up with the chrome hidden. WP9 owns `_start_sketch_on_face`. WP10 owns the cancel status.

16. **Save commits the open sketch.** `_save_current` calls `sketch_mode.exit_sketch()` when a session is active, before `view.save`. Open calls `sketch_mode.cancel()` first so a sketch session does not survive onto the loaded document. Delete of sketch entities emits `Deleted %d` after `delete_selected_entities` returns (the selection-cleared status is overwritten). Rect's `set_tool` emits `Rect — click 1 first corner, click 2 the opposite corner` after the variant reset; Jaw's `set_tool_variant` still overwrites that with `JAW_HINT`.

17. **Strip R.** After `set_value_no_signal`, set `_strip_radius.get_line_edit().text` to the same number with suffix `mm`, and `caret_column` to the end. Enter in the strip already calls `apply()`, which was re-parsing the stale `0.0`.

18. **Timeline extrude panel.** `PropertyPanel.open` focuses the Distance line and selects all of its text (the helper `focus_schema_key("distance")` already exists). Esc while the panel is visible calls `cancel_edits` and hides it, from `PropertyPanel._unhandled_input`, so it does not depend on which viewport ladder runs. A click that is not inside the panel's global rect hides the panel without committing (today's deselect path calls `commit()`). The Distance field stays pre-selected via the existing deferred `select_all`.

## Work packages

| WP | What | Files (exclusive hunks) | Test | Depends on |
|---|---|---|---|---|
| WP1 | End-on edge pick, View menu, Back/Left/Bottom, orbit through the pole | `document_view.gd`, `view_hud.gd`, `orbit_camera.gd`, `shortcuts.gd`, `command_registry.gd`, `main.gd` `_on_default_view` only, `viewport_interaction.gd` `_rebuild_orient_popup` + `_on_orient_id` only | `run_rung01_replan11_views.gd` | none |
| WP2 | Kernel fillet errors name the limit edge and the faulty contour | `sxkernel/src/features/ops_dress.cpp` only | `run_rung01_replan11_fillet_err.gd` | none. `make build` then `make test-kernel` |
| WP3 | Re-click deselect, edge list in the status, face-first commit, refusal text from `last_graph_error` | `ops_panel.gd` only | `run_rung01_replan11_fillet_ui.gd` | WP2 merged first (the test reads real kernel strings) |
| WP4 | Trim cutter chooser, named refusal, jaw-scoped construction replace | `sketch_mode.gd` `_jaw_long_sides`, `_segment_intersect`, `_construction_crosses_jaw`, `_trim_open_jaw` cutter pick and the walls!=2 refusal, `toggle_construction_selected` | `run_rung01_replan11_trim.gd` | none |
| WP5 | Esc drops a pending draw point before the measure anchor | `viewport_interaction.gd` `KEY_ESCAPE` arm only | `run_rung01_replan11_esc.gd` plus the three existing Esc/dim suites | none. Rebase if WP1 landed (different functions) |
| WP6 | Single-click dimension labels including angle; floor written perpendicular before solve | `sketch_mode.gd` `_dimension_label_pos2`, `_rebuild_dimension_labels`, `dimension_hit`, `_trim_open_jaw` from `_snap_jaw_hits_through_centre` down to `run_solve`; `viewport_interaction.gd` `_show_dim_edit` only | `run_rung01_replan11_dim.gd` | Rebase on WP4 (WP4 stops before the snap call) |
| WP7 | Centerline chips stack under Contours | `sketch_context_chrome.gd` only | `run_rung01_replan11_chrome.gd` | none |
| WP8 | Across-flats snap, typed AF at angle 0 | `sketch_mode.gd` the `_length_override` block in `click`, the `Tool.POLYGON` block, and the polygon preview in `_update_preview` | `run_rung01_replan11_poly.gd` | Rebase on WP4 and WP6 |
| WP9 | Sketch plane follows the support face; thick row; face sketch does not fall through to ground | `sxkernel/include/sx/sketch.hpp`, `sxkernel/src/sketch.cpp`, `sxkernel/src/features.cpp`, `sketch_mode.gd` support fields + `begin` + `begin_edit` clear + `_ensure_sketch_feature` + the `graph_add_sketch` arm of `exit_sketch`, `main.gd` `_start_sketch_on_face` only, `tools/check_rung01.py` thick branch | `run_rung01_replan11_slot.gd` | Rebase on WP4, WP6, WP8. `make build`. Second and last C++ WP |
| WP10 | Strip R, timeline panel, cancel status, open/save sketch, Delete N, Rect prompt, Smart Dim horizontal | listed in the prompt; no fillet kernel, no checker | `run_rung01_replan11_ux.gd` | Rebase on WP1, WP5, WP6, WP9 |
| WP11 | Walk uses real view keys; human-trap steps; lint and Makefile | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | the walk, the lint | All of WP1–WP10 merged |

Parallel waves:

- Wave A, together: WP1, WP2, WP4, WP5, WP7.
- Wave B, after the wave-A owner of each file has a PR up to rebase onto: WP3 (after WP2), WP6 (after WP4), WP8 (after WP4; again after WP6 if both touched `sketch_mode.gd`).
- Wave C: WP9 after the sketch_mode WPs (WP4, WP6, WP8). WP10 after WP1, WP5, WP6, WP9.
- WP11 last. If any of WP1–WP10 is not merged, WP11 does not start.

`sketch_mode.gd` hunks, in merge order: WP4 (cutter and toggle), WP6 (label positions, dimension hit, floor rewrite), WP8 (polygon block and preview), WP9 (fields near line 85, `begin`, `begin_edit`, `_ensure_sketch_feature`, `exit_sketch`'s `graph_add_sketch` arm). They do not share lines. WP10's sketch hunks are `set_tool` and `_smart_dim_between`, also disjoint, and merge after WP9.

`viewport_interaction.gd` hunks: WP1 orientation popup, WP5 Esc arm, WP6 `_show_dim_edit`, WP10 `_sync_strip_dressup_radius` and the Delete key arm. Disjoint. Merge WP10 last.

`main.gd` hunks: WP1 `_on_default_view`, WP9 `_start_sketch_on_face`, WP10 cancel connect, `_open_document`, `_save_current`. Disjoint.

C++ files: WP2 touches only `sxkernel/src/features/ops_dress.cpp`. WP9 touches `sxkernel/include/sx/sketch.hpp`, `sxkernel/src/sketch.cpp`, `sxkernel/src/features.cpp`. No other C++ file. No `sxcore` API is added; support params go through `graph_set_params_no_regen`. After WP2 and after WP9, `make build` then `make test-kernel` must still print `All tests passed`. The assertion count may stay 7900 (neither WP adds a Catch2 case). Do not regress it.

PR titles:

- `Rung 1 replan 11 WP1: end-on fillet pick and Back/Left/Bottom views`
- `Rung 1 replan 11 WP2: fillet errors name the edge`
- `Rung 1 replan 11 WP3: fillet deselect, face-first, refusal text`
- `Rung 1 replan 11 WP4: trim cutter crosses the jaw`
- `Rung 1 replan 11 WP5: Esc drops the first point first`
- `Rung 1 replan 11 WP6: one click edits an angle label`
- `Rung 1 replan 11 WP7: Centerline chips clear the Contours row`
- `Rung 1 replan 11 WP8: typed hex flats stay horizontal`
- `Rung 1 replan 11 WP9: slot sketch follows the face`
- `Rung 1 replan 11 WP10: strip, timeline, save, and dim UX`
- `Rung 1 replan 11 WP11: walk, lint and Makefile`

## Whole-suite check (WP11, and after every WP that touches a suite)

Run every `game/tests/run_*.gd` with `timeout 120` (do not use `make test-godot` alone; it stops at the first failure). On `b3161bba` the replan-10 suites are the floor: wrench **404/0**, cut **114/0**, esc **25/0**, new **19/0**, trim **38/0**. These suites were not clean before replan 10 and must stay at the same counts unless a prompt names the delta:

| Suite | Required count |
|---|---|
| `run_assembly_tests` | 87 checks, 4 failures |
| `run_film_caption_tests` | exit 0, no summary line |
| `run_film_manifest_smoke` | no summary; may hit `timeout 120` (exit 124). Do not "fix" it |
| `run_howto_tests` | 91 checks, 2 failures |
| `run_icon_tests` | 13 checks, 2 failures |
| `run_insert_component_tests` | 42 checks, 2 failures |
| `run_menu_tests` | 55 checks, 2 failures |
| `run_place_tests` | 110 checks, 1 failure |
| `run_property_tests` | 17 checks, 1 failure |
| `run_rung01_replan3_input` | 110 checks, 1 failure |
| `run_rung01_replan3_shell` | 43 checks, 6 failures |
| `run_rung01_replan_shell` | 34 checks, 1 failure |
| `run_rung01_sketch_tests` | 70 checks, 7 failures |
| `run_sketch_to_3d_ui_tests` | 47 checks, 2 failures |
| `run_sketch_tools_tests` | 141 checks, 13 failures |
| `run_ui_button_coverage_tests` | 35 buttons probed, 33 work, 2 broken; 36 checks, 3 failures |
| `run_visual_ux_tests` | 86 checks, 1 failure on `b3161bba` because `_views_drop_btn.text` is `""` and the test wants `▼`. After WP1 that check passes. If it was the only failure, the suite becomes **86 checks, 0 failures**. If a second failure remains, report it; do not edit the test to hide it |

Every other existing suite must print `0 failures`. Known pre-existing mismatches (nav preset `FUSION` vs tests that assume `SOLIDEXPRESS`, plus one `run_infer_tests` DOF-chip failure and the icon failure above) stay as they are. Do not flip `nav_preset`.

Deltas this plan requires:

| Suite | On `b3161bba` | After the WP |
|---|---|---|
| `run_rung01_replan11_views.gd` | file absent | WP1: `18 checks, 0 failures` |
| `run_rung01_replan11_fillet_err.gd` | file absent | WP2: `8 checks, 0 failures` |
| `run_rung01_replan11_fillet_ui.gd` | file absent | WP3 (needs WP2): `14 checks, 0 failures` |
| `run_rung01_replan11_trim.gd` | file absent | WP4: `12 checks, 0 failures` |
| `run_rung01_replan11_esc.gd` | file absent | WP5: `10 checks, 0 failures` |
| `run_rung01_replan11_dim.gd` | file absent | WP6: `11 checks, 0 failures` |
| `run_rung01_replan11_chrome.gd` | file absent | WP7: `6 checks, 0 failures` |
| `run_rung01_replan11_poly.gd` | file absent | WP8: `8 checks, 0 failures` |
| `run_rung01_replan11_slot.gd` | file absent | WP9: `9 checks, 0 failures` |
| `run_rung01_replan11_ux.gd` | file absent | WP10: `12 checks, 0 failures` |
| `run_rung01_wrench.gd` | 404 checks, 0 failures | WP11: `413 checks, 0 failures` (404 plus the 9 `check()` calls that prompt adds) |
| `run_rung01_replan10_esc.gd` | 25/0 | still 25/0 (WP5). Update only if a row required `Measure cleared` while a draw point was pending; the prompt says which row |
| `run_rung01_replan8_esc.gd` | its current 0-failure count | unchanged |
| `run_rung01_replan9_dim.gd` | its current 0-failure count | unchanged |
| `make test-kernel` | `All tests passed (7900 assertions in 330 test cases)` | same sentence after WP2 and after WP9 |

Each new test's prompt lists the red failures on unmodified `b3161bba` (commit the test, run it, then apply the product change). The green line is `N checks, 0 failures` with the N in the table.

## sx-032 GUI checklist

Walk order, same as replan 10, with the new rows inserted where the handout already is: A1, A2, A3, A4, A5, A5b, A7, A6, A7b, A8, A8b, A9 (includes A17), A9b, A16, A11a, A11b, A11c, A11d, A12, A13, then scratch A10, A10b, A14, then A15. Keep the blank open through A13. A10 and A14 start a new document.

| Row | WP | Action | Pass looks like |
|---|---|---|---|
| A1 | carry | Read the left rail in a new sketch | All 18 labels, same as sx-031 |
| A2 | WP10 | Press Jaw, then Rect | Jaw status, then `Rect — click 1 first corner, click 2 the opposite corner`. Chips: Center Three Point, then Corner |
| A3 | WP10 | Ø20 at the origin, Ø45 to the right, Smart Dim the two centres along +X, type 200 | `Dimension updated`. Head centre y within 0.05 of the pivot y (horizontal inferred). No Shift |
| A4 | carry | Shaft Lines | `Shaft lines: 2 added` |
| A5 | carry | Extrude 10, export | blank **5/5** |
| A5b | carry | Discard Cancel, then Save As `blank.sxp` | Cancel keeps the blank |
| A7 | WP9 | Sketch on the top face | `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`. Not the ground sentence |
| A6 | WP5 | Circle tool, one click, Esc, Esc | First status `First point dropped — Esc again exits the sketch`. Second exits. Not `Measure cleared`. Exactly two presses |
| A7b | carry | Sketch on the top face again | Face sketch opens |
| A8 | WP6 | Jaw, width 20. Single-click the width label and the angle label. Type 45 on the angle | Each label opens on the first click, text selected. `Dimension updated`. Walls at 45°. Floor perpendicular to the walls (included angle 90° ± 0.05°) |
| A8b | carry | Select a jaw line, Esc ladder | `Selection cleared — …` then the sketch is still there. Do not regress |
| A9 | WP4 | Pivot hole, redraw Ø45. Line along the jaw, X so it is construction. Then the cross-jaw cutter (Line + X, or the Centerline tool). Power Trim on the shaft side | `Trimmed open jaw`, then a second click `Jaw is already open — nothing left to trim here`. X on a jaw line may print `Removed N jaw construction line(s)` and drop the along-jaw line; the Centerline tool still drops every other non-datum construction line. Either way Trim succeeds. The case with both lines still present is `run_rung01_replan11_trim.gd`, not a script shortcut in the walk |
| A17 | WP7 | While drawing those lines, read the Line/Centerline chips and the Contours row | Their rectangles do not overlap. Clicking Centerline does not toggle Contour 1 |
| A9b | carry | Cut, Up To Surface, opposite face | Closed jaw cut. Same as sx-031 |
| A16 | WP1 | Open View (the word or the chevron). Press `4`, `6`, `8`, and orbit off Top | Menu shows Back, Left, Bottom and the camera moves. A downward orbit drag from Top changes the view |
| A11a | carry | Slot R5, 150 centre to centre, cut blind 2.5 | Slot from the top |
| A11b | WP1+WP3 | Fillet armed. Key `3` (Top) or `7` (Iso). Click each neck corner. Status lists `10.0 mm vertical` twice. Enter at radius 10 | `Fillet 2 edges 10.00 applied`. Not `too large` |
| A11c | WP3 | Add one wrong edge, read the status, click it again | The status count drops by one and names the removed length. Enter on the two verticals still applies |
| A11d | WP3 | Select the top face first, then Fillet, then Enter at radius 1, **before** the neck fillet, on a copy is not required: do this only on a second attempt after the neck exists, and also once on a fresh body to read the refusal | With the neck already filleted, the face applies. On a sharp neck the status contains `fillet the R10 neck first` and names the arc. Never `No edges selected — cancelled` while a face is selected |
| A12 | carry | Export `wrench.3mf` | wrench **28/28**, `flipX=False flipY=False` |
| A13 | WP9+WP10 | Timeline, first extrude, Distance 14 (text is already selected; Esc closes the panel; a click on empty viewport closes it). Export | thick **5/5**. The new row is `grip slot open from the top`. Slot floor near 11.5, not 14 |
| A10 | carry | Ø100 extruded, Ø90 cut on the face | Exact `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.` |
| A10b | carry | File → New, read the finish bar | New / Blind / Extrude enabled |
| A14 | WP8 | Polygon, centre click, type AF 20 with the pointer off the X axis. Hole radius 5. Extrude 7.5 | nut **7/7**. Status contains `flats horizontal` |
| A15 | WP11 | lint and `run_rung01_wrench.gd` | lint prints `N replan11 scripts are clean` with N equal to the number of `run_rung01_replan11_*.gd` files (10). Walk `0 failures` |

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 5/5, walk 0 failures, first-try fillets from Front, Top or Iso.

## Soft-GL protocol (sx-032 walker)

Rules 1–16 of replan 10 still apply. Add:

17. **View keys, not a hidden camera.** Neck fillets are picked from key `1` (Front), `3` (Top) or `7` (Iso), or from the View menu entries including Back (`4`), Left (`6`) and Bottom (`8`). Zoom with the wheel or Frame (`F`). If a Top-view corner click selects a long edge, the status names its length; click that edge again to remove it, then click the corner once more. Do not orbit with a test helper.
18. **Fillet refusal is specific.** `exceeds the … mm limit` means remove the named edge or lower the radius. `fillet the R10 neck first` means do the two vertical neck edges at R10, then the faces at R1. A bare `too large for selected edge(s)` is a product failure.
19. **Trim with the leftover line still there.** Draw the along-jaw construction line and leave it. The cross-jaw line is the cutter. If the status names the along-jaw line, delete that one line and click Trim again; record it. Silence or a refusal that does not name a line fails A9.
20. **Dimension labels are one click.** Select tool, one click on the glyphs, read the field, type, Enter. A double-click is not required. If the first click does nothing, repeat once (rule 2) and then fail the row.
21. **Polygon pointer.** After the centre click, move the pointer off-axis on purpose, then type `20` in the AF field. The nut checker is the pass, not the picture.
22. **Thickness.** The slot must be open at the new top. thick 4/5 with the slot row failing is a product failure even if the old four rows pass.

No driver WP. Soft-GL was quiet in sx-031. Do not change llvmpipe, Mesa, or the Godot renderer.

## Out of scope

- Soft-GL / llvmpipe / Mesa.
- Checker formulas other than the one thick row in WP9.
- Wave features and `docs/plan/*`.
- The snadrus fork. PR #11.
- Replan-10 Trim success path, cut closure, Esc-keep-sketch ladder, New-reset, and the 81 % sentence.
- A kernel blend that fillets the jaw-mouth arc while the neck is sharp.
- `_look_along`, `set_view(`, and writing `camera.yaw` / `camera.pitch` from the walk, except the existing `_zoom` helper (sketch framing only; the fillet, face, and body-select helpers must not call it). `select_entity(` stays forbidden in the walk and in click-driven replan11 tests. `run_rung01_replan11_fillet_ui.gd` and `run_rung01_replan11_fillet_err.gd` are validation scripts and may call `select_entity` and `insert_primitive`. The lint exempts only those two files from the `select_entity(` needle.
