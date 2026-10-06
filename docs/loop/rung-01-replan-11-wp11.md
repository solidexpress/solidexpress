# Replan 11 WP11 — the walk uses the views a person can reach

You are a BUILD agent. Implement only this WP. Start only after WP1 through WP10 are merged. No product code. No checker formula. No C++.

Files:

- `game/tests/run_rung01_wrench.gd`
- `tools/lint_rung01_e2e.py`
- `Makefile` (`test-godot` only)

## Walk

Delete `func _look_along` (line 1848) and every call. The calls are at lines 638, 658, 661, 694, 712, and 1785. Do not replace them with assignments to `camera.yaw`, `camera.pitch`, `camera.basis`, or `set_view(`.

Add this helper next to `_zoom`. It presses a real view key. WP1 added keys `4`, `6`, and `8`.

```gdscript
func _view_key(ctx: FilmContext, code: int) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	cam.sketch_orientation_locked = false
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	cam.handle_input(ev, true)
	await process_frame
	await process_frame
```

`handle_input` on those keys calls `apply_standard_view`, which frames the part. That is the F-key framing a person gets from `1` / `2` / `3` / `4` / `6` / `7` / `8`. `_view_key` itself contains no `check()` call.

Replace each former `_look_along` by the key a person would press, then the existing `_click_model` / `_x11_click_screen`:

| Old call | Key | Why |
|---|---|---|
| `_ensure_body_selected`, from `(0, 1, 0)` | `KEY_4` Back | Side view, so a top-down click does not reopen the sketch pad |
| `_fillet_neck`, from `±Y` | `KEY_1` Front, once, before the loop | Both vertical neck edges are silhouettes. Click each edge **midpoint** from `_neck_click_points`. Delete the tighter second look (the old lines 660–662) |
| `_fillet_face` when `from_side` is `+Z` | `KEY_3` Top | Top face and slot floor |
| `_fillet_face` when `from_side` is `-Z` | `KEY_8` Bottom | Bottom face |
| `_refuse_slot_floor`, from `+Z` | `KEY_3` Top | |
| `_sketch_on_top`, from `+Z` | `KEY_3` Top | Keep the Esc that is already there |

Do not call `_zoom` from `_fillet_neck`, `_fillet_face`, `_refuse_slot_floor`, `_ensure_body_selected`, or `_sketch_on_top`. `_zoom` and `_zoom_uv` stay for sketch framing. They are the only functions in this file allowed to assign `.yaw` or `.pitch`.

### Human traps

Add these `check()` calls and no others. The banner total becomes **413**.

1. Nut polygon. The hover before the typed AF is `Vector2(8, 0)`. Change it to `Vector2(8, 3)` (about 20°, not a multiple of 30°). Add one check: the status contains `flats horizontal`. The existing `Polygon AF 20` check stays. The nut checker stays 7/7.

2. Jaw floor. In `_edit_rect_labels`, after the angle is 45, one check: a wall direction and the floor direction have absolute dot product `<= sin(deg_to_rad(0.05))`. Name it `jaw floor is perpendicular to the wall`. Use entity endpoints. Do not call `select_entity`.

3. Esc, in the face sketch, immediately after the first `_sketch_on_top` and before the hole. Select Circle, one click, Esc. Check the status contains `First point dropped — Esc again exits the sketch`. Esc again. Check `sketch_mode.active` is false. Call `_sketch_on_top` again so the hole, the jaw, and the trim still run. Two checks.

4. Neck. After the two Front-view midpoint clicks and before `_commit_fillet`: check the status contains `mm vertical`. Click the first neck midpoint again. Check the status contains `removed`. Click that midpoint once more so the edge is selected again, then the existing commit checks run. Two checks.

5. Top-face fillet. After the Top-view click selects the face edges and before commit: check the status does not contain `No edges selected`. One check.

6. After the timeline Distance edit to 14 and before the thick export: reload the body mesh and check it is not inside at `(93.5, 0, 12.75)`. One check. Name it `thick slot is open at z=12.75`.

7. In `_checker`, when `args[0] == "thick"`, one more check: the captured output contains `5/5`. Name it `thick checker prints 5/5`. Nut and wrench checker calls do not gain this check.

413 = 404 existing checks plus these 9. Do not delete an existing `check()`. If the green line is not `413 checks, 0 failures`, a check was added or dropped and the WP is not done.

The along-jaw construction line in the existing B2.10 sequence is drawn with the Centerline tool, which still deletes the previous construction line. Leave that sequence. `Trimmed open jaw` stays. Both-lines-present is `run_rung01_replan11_trim.gd`, not a new shortcut here.

Update the file's first comment so it says the 3D picks use view keys `1` `3` `4` `8`, not `_look_along`.

## Lint

`tools/lint_rung01_e2e.py`. Keep every existing walk and replan3–10 check.

Add `_lint_replan11` and call it from `main()` next to `_lint_replan10`.

Camera needles, applied to the walk and to every `game/tests/run_rung01_replan11_*.gd`:

```python
REPLAN11_CAMERA = ("_look_along", "set_view(", ".yaw =", ".pitch =", ".basis =")
```

Validation scripts. They may call `select_entity`, `trim_at`, `insert_primitive`, and `graph_set_params`. Apply only `REPLAN11_CAMERA` to these files:

- `run_rung01_replan11_fillet_ui.gd`
- `run_rung01_replan11_fillet_err.gd`
- `run_rung01_replan11_trim.gd`
- `run_rung01_replan11_slot.gd`
- `run_rung01_replan11_dim.gd`
- `run_rung01_replan11_poly.gd`
- `run_rung01_replan11_ux.gd`

Every other `run_rung01_replan11_*.gd` (views, esc, chrome) gets `REPLAN11_CAMERA` plus `REPLAN7_FORBIDDEN`, the text-assignment lint, the press/release lint, and the `current_dir` lint. Do not run `_lint_dimension_label_pos2` on replan11 files: WP6's dim test is allowed to mention that helper.

Walk, in addition to the current walk lints:

- `_look_along` anywhere is an error.
- `.yaw =` and `.pitch =` are errors outside `func _zoom` and `func _zoom_uv`. Implement that by scanning `_functions` and skipping those two bodies.
- `set_view(` stays an error on every line, including inside `_zoom`.
- `.basis =` is an error everywhere.
- The source of `_fillet_neck`, `_fillet_face`, `_refuse_slot_floor`, `_ensure_body_selected`, and `_sketch_on_top` must not contain `_zoom(`.

There are 10 replan11 scripts. If the glob is not 10 files, fail with `expected 10 run_rung01_replan11_*.gd`. On success print, after the replan10 line:

```
lint_rung01_e2e: 10 replan11 scripts are clean
```

Do not change the replan10 sentence `4 replan10 scripts are clean`.

## Makefile

In the `test-godot` recipe, after the replan10 loop (line 139), add the same loop for `game/tests/run_rung01_replan11_*.gd`.

## Commands

```
python3 tools/lint_rung01_e2e.py
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd
```

Lint stdout includes `lint_rung01_e2e: 10 replan11 scripts are clean` and `4 replan10 scripts are clean`. The walk prints `413 checks, 0 failures`. The thick checker section of that log contains `5/5`.

Then every `game/tests/run_*.gd` with `timeout 120`. Do not use `make test-godot` alone; it stops at the first failure. Counts that must stay:

| Suite | Count |
|---|---|
| `run_rung01_replan10_cut.gd` | 114 checks, 0 failures |
| `run_rung01_replan10_esc.gd` | 25 checks, 0 failures |
| `run_rung01_replan10_new.gd` | 19 checks, 0 failures |
| `run_rung01_replan10_trim.gd` | 38 checks, 0 failures |
| `run_rung01_replan11_views.gd` | 18 checks, 0 failures |
| `run_rung01_replan11_fillet_err.gd` | 8 checks, 0 failures |
| `run_rung01_replan11_fillet_ui.gd` | 14 checks, 0 failures |
| `run_rung01_replan11_trim.gd` | 12 checks, 0 failures |
| `run_rung01_replan11_esc.gd` | 10 checks, 0 failures |
| `run_rung01_replan11_dim.gd` | 11 checks, 0 failures |
| `run_rung01_replan11_chrome.gd` | 6 checks, 0 failures |
| `run_rung01_replan11_poly.gd` | 8 checks, 0 failures |
| `run_rung01_replan11_slot.gd` | 9 checks, 0 failures |
| `run_rung01_replan11_ux.gd` | 12 checks, 0 failures |
| `run_rung01_sketch_tests.gd` | 70 checks, 7 failures |
| `run_visual_ux_tests.gd` | 86 checks, 0 failures if the chevron was the only failure; otherwise report the leftover |
| `run_assembly_tests.gd` | 87 checks, 4 failures |
| `run_howto_tests.gd` | 91 checks, 2 failures |
| `run_icon_tests.gd` | 13 checks, 2 failures |
| `run_insert_component_tests.gd` | 42 checks, 2 failures |
| `run_menu_tests.gd` | 55 checks, 2 failures |
| `run_place_tests.gd` | 110 checks, 1 failure |
| `run_property_tests.gd` | 17 checks, 1 failure |
| `run_rung01_replan3_input.gd` | 110 checks, 1 failure |
| `run_rung01_replan3_shell.gd` | 43 checks, 6 failures |
| `run_rung01_replan_shell.gd` | 34 checks, 1 failure |
| `run_sketch_to_3d_ui_tests.gd` | 47 checks, 2 failures |
| `run_sketch_tools_tests.gd` | 141 checks, 13 failures |
| `run_ui_button_coverage_tests.gd` | 36 checks, 3 failures |

Every other existing suite prints `0 failures`. `run_film_caption_tests` exits 0 with no summary line. `run_film_manifest_smoke` may hit `timeout 120` (exit 124). Do not flip `nav_preset`.

Red before this WP: the walk still contains `_look_along`, and the lint script does not mention `replan11`. After the lint edit and before the walk edit, `python3 tools/lint_rung01_e2e.py` fails on `_look_along`. Green is the two commands above.

Do not commit `.gd.uid`.

## Do not

- Put `select_entity(` in the walk to make a fillet pick succeed.
- Exempt the walk from `_look_along`.
- Apply `select_entity(` as a hard error to `run_rung01_replan11_fillet_ui.gd` or `run_rung01_replan11_fillet_err.gd`.
- Change `tools/check_rung01.py`.
