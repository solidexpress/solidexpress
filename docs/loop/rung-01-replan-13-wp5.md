# Replan 13 WP5 — `F` / Frame inside a sketch fits the whole sketch (both circles)

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main`). Edit only `game/scripts/orbit_camera.gd` (the framing entry points), one line pair in `game/scripts/sketch_mode.gd` (`_activate_session` / `_leave_camera`: install and remove the fit hook) and add `game/tests/run_rung01_replan13_frame.gd`.

Hunks you own (search by name; line numbers are `0573dea2`): `orbit_camera.gd` `frame_selection_or_all` (~724), `frame_contents` (~758), new `sketch_fit` hook field; `sketch_mode.gd` `_enter_camera` (~471) and `fit_view` (~502) (reuse, do not rewrite), `_leave_camera`. `sketch_mode.gd` is also edited by WP2 (trim) and the spin-outs; your hunks are one assignment each.

## The bug (sx-033 A3)

Leftover 5: in the blank sketch (Ø20 at the origin, Ø45 at the head, 200 apart) after typing the 200 dimension, `F` (or the View HUD `Frame` button, marking-menu "Frame all", double-middle click) frames only the Ø20; the Ø45 is off screen.

## Cause (read on `0573dea2`; **reproduce first**)

Every framing entry point ends in `OrbitCamera.frame_selection_or_all` → `frame_selection()` (needs a **selected body**) → else `frame_contents()` (the union of **visible bodies**). A first sketch has no body yet, so `frame_contents()` takes the `not _has_visible_body()` branch: `pivot = Vector3.ZERO`, `distance = DEFAULT_DISTANCE`. In the orthographic sketch view that recentres on the origin and leaves the orthographic `size` alone, so the Ø20 stays in view and the Ø45 at x=200 does not. `SketchMode.fit_view()` already does the right thing (`sketch_extents(0.2)` + `camera.enter_sketch_view`) but nothing calls it from `F`; `grep fit_view` finds only its definition.

## Decisions (see `rung-01-replan-13.md` 5)

- `OrbitCamera` gets `var sketch_fit: Callable` (invalid by default). `SketchMode` assigns `camera.sketch_fit = fit_view` when a session starts (the same place `_enter_camera` runs) and clears it in `_leave_camera` / `exit_sketch` / cancel. No `SketchMode` reference inside `OrbitCamera`.
- `frame_selection_or_all(force_all)` and `frame_contents()` call `sketch_fit` first when it is valid and return. So `F`, `Home`, `Shift+F`, double-middle, the View HUD `Frame` button and the marking-menu items 20/21 all fit the sketch while a sketch is open. Outside a sketch nothing changes.
- The fit uses the sketch's **extents with radii** (`sketch_extents` already adds circle radii) plus the existing 20% pad, floored by `MIN_SKETCH_VIEW_RADIUS_MM`; the camera stays orthographic and locked to the sketch normal (`enter_sketch_view`).
- When the sketch has **no entities** but a visible body exists (the face-sketch case), the fit is the sketch plane around the support face's extents (`plane_origin`, radius from the support body's projected bbox) — i.e. `_enter_camera`'s existing fallback. Do not frame the whole body in 3D inside a sketch.
- `fit_view` emits `Sketch view fit` (existing). No new status string.

## Failing-first test — `game/tests/run_rung01_replan13_frame.gd` (create)

Template: `run_rung01_replan12_rail.gd` (real viewport 1280×800, `FilmUI.enter_sketch`). Real key taps (`F`) through `Viewport.push_input`; geometry is placed through the sketch API (validation suite).

1. Blank sketch, `sm.sketch.add_circle(0,0,10)` and `add_circle(200,0,22.5)`, then `sm.run_solve()`. Press `F`. Project the **four extreme points** of each circle (`±r` on both axes) with `camera.unproject_position`; every one is inside the viewport rectangle shrunk by a 4 px margin and outside the left rail rectangle (`main.left_stack` global rect) — red on `0573dea2` for the Ø45.
2. The sketch plane is still the view plane: `camera.projection == ORTHOGONAL`, `camera.sketch_orientation_locked` unchanged, camera forward parallel to the plane normal (dot ≥ 0.9999).
3. `Shift+F`, the View HUD button whose text is `Frame` (`view_hud.gd` `_fit_btn`), and marking-menu item 20 and 21 give the same result as `F` (frame size within 1%).
4. After typing the 200 dimension through the real Smart Dim path (centres click, type 200, Enter) press `F` again: same result.
5. With a face sketch on an extruded body (the A7 case): `F` fits the sketch entities when there are any, and fits the support face region when the sketch is empty. The camera never leaves the sketch plane view.
6. Exit Sketch, press `F`: the 3D framing is exactly the pre-change behaviour (the body's AABB; `camera.sketch_fit.is_valid()` is false after `exit_sketch`).

**Expected red** on `0573dea2`: 1, 3, 4 (the Ø45 is out of frame). Record the measured pixel coordinates of the Ø45's extremes.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_frame.gd
for t in run_camera_tests run_rung01_replan2_camera run_viewcube_tests run_rung01_replan11_views run_rung01_replan8_rail; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
```

Record what `run_camera_tests` prints on `main` before your change (`AGENTS.md` lists pre-existing Alt-orbit failures from the `nav_preset` default); after the change the count and the failures must be identical. Do not flip `nav_preset`.

## Do not

- Change `FRAME_PADDING`, the 3D fit math or `_fit_distance_for_world_aabb`.
- Make `F` fit the sketch **and** the bodies together (that re-introduces the off-screen pivot on big parts).
- Touch `enter_sketch_view` / `leave_sketch_view` signatures.
