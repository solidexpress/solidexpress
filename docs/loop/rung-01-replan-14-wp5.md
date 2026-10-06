# Replan 14 WP5 — `F` frames in part mode and says so; wheel zoom keeps the point under the cursor

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` at launch time, **after WP2 is merged**; if `git log origin/main` has no WP2 merge ("numeric fields give focus back") stop and report: the first measurement must run without a stale field focus). Edit only the files and hunks below and add `game/tests/run_rung01_replan14_camera.gd`. Read [`rung-01-replan-14.md`](rung-01-replan-14.md) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (items 8, 9) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

| File | Hunk (search by name; line numbers are `305dcbff`) |
|---|---|
| `game/scripts/orbit_camera.gd` | `zoom_at` (~238), `_nudge_pivot_on_zoom_out` (~873), `frame_selection_or_all` (~733), new `signal framed(what: String)` |
| `game/scripts/main.gd` | the `view_hud.fit_requested` handler (~722) and one `camera.framed.connect(_on_status)` line |
| `game/scripts/viewport_interaction.gd` | the marking-menu Frame items (`20` / `21`, ~5177–5181) only; **not** the `block_nav` lines (WP2 owns them) |

## The bugs (sx-034 walk-chunk2/3/4; leftovers 8 and 9)

**Item 8 — part-mode `F` does nothing.** In part mode (Top view, zoomed on one end) `F` gave no camera change and no status (walk-chunk4 A11a: "`F` showed no visible change/status"). The HUD `Frame` button works and prints `Framed selection` / `Framed all` (`main.gd` `fit_requested`). (Sketch-mode `F` printed `Sketch view fit` without framing the part in chunk 2; #149 reworked the sketch path: re-check it on `main` and fix it only if it still fails, i.e. `F` in a face sketch must keep the origin and the sketch right of the rail.)

**Item 9 — wheel zoom is not anchored at the cursor.** "wheel zoom-out appeared to push content away from the cursor"; "Wheel zoom toward the head barely zoomed"; "Wheel zoom-out recentred view so the slot's far end is off-screen". Expected: the model point under the pointer stays under it (±2 px) across wheel notches, ortho and perspective, sketch and part.

## Cause (read on `305dcbff`; **reproduce first**)

- Item 8: `OrbitCamera._handle_nav_key` already calls `frame_selection_or_all(shift)` for `KEY_F`, which frames the selected body or all bodies, so a silent no-op has three candidates: (a) the event never reaches the camera (`block_nav = _text_field_has_focus() or _sketch_keys_blocked()` after a spinner click leaves a field focused: item 2, fixed by WP2); (b) `sketch_fit` is still a valid `Callable` (set by `SketchMode._enter_camera`, cleared in `_leave_camera`) after a path that ends the session without `_leave_camera`, so `F` calls the dead sketch's `fit_view()` (which returns because `not active`) instead of framing the part; (c) `frame_selection()` frames the selected body's AABB and the result is the same view (the body already fills it). In every case **no status is printed**: the HUD button prints its own text in `main.gd`, the key path prints nothing.
- Item 9: `zoom_at(screen_pos, factor)` shifts the pivot by `(1 − factor) · plane_delta` so the anchor stays put, then `distance` is clamped, and on zoom-out `_nudge_pivot_on_zoom_out(factor)` **lerps the pivot toward the content centre** (and caps `distance` at `ZOOM_OUT_MAX_FIT_MULT × fit`). Both the lerp and a clamp applied after the pivot shift move the anchor, which is the observed "pushes content away / recentres". The per-notch step (0.94, 0.88 with Ctrl) is deliberate ("milder than the old 0.9"); "barely zoomed" is recorded in the PR but the step is **not** changed.

## Decisions (see `rung-01-replan-14.md` 8)

- **One announcement.** `OrbitCamera` gains `signal framed(what: String)`. `frame_selection_or_all` emits `framed("Framed selection")` when it framed the selection and `framed("Framed all")` otherwise (the strings are the HUD's, byte-identical). `main.gd` connects `camera.framed` to `_on_status` and the `fit_requested` handler stops printing its own status (it only calls `frame_selection_or_all(false)`), so the key `F`, `Shift+F`, `Home`, double-middle-click, the HUD button and the marking menu all say the same thing exactly once. In a sketch the sketch's own `Sketch view fit` stays and `framed` is not emitted.
- **`sketch_fit` cannot outlive its session.** `frame_selection_or_all` / `frame_contents` call `sketch_fit` only when it is valid **and** its target reports an active session (`sketch_fit.get_object()` has `active == true`, or the camera's `sketch_orientation_locked` is true); otherwise they clear it and frame the part. (If the reproduction shows candidate (a) only, this stays as a defensive guard with its own test row.)
- **Framed content lands in the free viewport.** Part-mode framing uses the same free rect as the sketch fit (`sketch_fit_canvas_rect`: right of `ChromeDock.rail_right` / `LeftStack`, below the top inset, above the bottom inset). If `_frame_world_aabb` already respects it the test pins it; if it frames to the full window (content under the left panel) fix it there. Do not change the sketch fit.
- **Zoom is anchored, always.** `zoom_at` computes the new distance first (clamped to `[MIN_DISTANCE, min(MAX_DISTANCE, ZOOM_OUT_MAX_FIT_MULT × fit)]`), derives the effective factor `eff = new_distance / old_distance`, and shifts the pivot by `(1 − eff) · plane_delta`. `_nudge_pivot_on_zoom_out` no longer moves the pivot while any visible body's projected AABB intersects the viewport; it may still pull the pivot toward the content when **all** of it is off-screen (the stray-scene safety net it was written for). Perspective and orthographic both use the same rule (ortho `size` follows `distance` as today).
- No new status strings other than the two `framed` texts (already existing); no change to nav presets, key bindings or the sketch camera lock.

## Failing-first test — `game/tests/run_rung01_replan14_camera.gd` (create)

Template: `run_rung01_replan13_frame.gd` (`_boot`, `_push_key`, projected-extent helpers) and `run_rung01_replan13_trim.gd`. 1280×800. Setup (placing the wrench-like body, `FilmUI.enter_sketch`) may use helpers; every key, wheel and motion is a real event. Wheel events: `InputEventMouseButton` with `button_index = MOUSE_BUTTON_WHEEL_UP/DOWN`, `pressed = true`, `factor = 1.0`, the pointer position set, sent through `Viewport.push_input` after a real `InputEventMouseMotion` to that position.

Part mode:

1. Place a body ~240 × 45 × 10 (box or the replan 13 wrench setup), key `3` (real), zoom in on one end with real wheel notches over it (pointer on that end). Press real `KEY_F` with **no** body selected: `framed` / status `Framed all`; the body's projected AABB (eight corners through `camera.unproject_position`) lies inside the free rect and fills ≥ 60 % of its larger dimension. (Red on baseline: no status; possibly no change.)
2. Select the body (real click), zoom in again, `F`: status `Framed selection`, same containment. `Shift+F`: `Framed all`.
3. The HUD `Frame` button gives the same camera pose (within 1e-3) and the status appears **once** (count entries in the status log).
4. `F` after `Esc` ends a sketch (session end via Exit Sketch, via Esc, via Save As re-entry): the part is framed, not a stale sketch fit; `sketch_fit` is invalid after the session ends.
5. `F` with a Fillet strip field focused after a spinner click and a commit frames (this row is WP2's regression through the camera; green after WP2).

Zoom anchor (item 9): for each of {perspective, orthogonal} × {part Top view, blank sketch}:

6. Pick a pointer position `P` over the body (or over a sketch circle), compute the world point under it `W = ray(P) ∩ (plane through the pivot, normal = view axis)` **before**. Send 3 real wheel-up notches at `P`, then 3 wheel-down notches at `P`. After **each** notch recompute `camera.unproject_position(W)`: it equals `P` within 2 px (red on baseline on zoom-out: the nudge). After the 3 up + 3 down the distance equals the starting distance within 1e-3 and the pivot within 1e-3 of the start (a symmetric round trip).
7. Zoom out 12 notches from the fit distance with the pointer on the body: the anchor still holds ±2 px every notch **while the body is on screen**; the distance never exceeds `ZOOM_OUT_MAX_FIT_MULT × fit`.
8. With the whole body scrolled off-screen (pan it away with real Shift+wheel notches), a zoom-out may recentre toward the content (safety net): assert the body returns to the viewport within 6 notches; this row documents the retained behaviour.

**Expected red** on `305dcbff`: row 1–2 (no status; framing maybe), row 6 / 7 on the zoom-out notches. Row 1's `F` may be green once WP2 is merged: then the PR says item 8 was the stale focus and keeps the status rows. Record the pivot / distance / unprojected-point numbers you observe per notch.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_camera.gd
for t in run_rung01_replan13_frame run_rung01_replan2_camera run_camera_tests \
         run_rung01_replan12_rail run_menu_tests; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
python3 tools/lint_rung01_e2e.py
tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone
```

`run_camera_tests` keeps its pre-existing Alt-orbit failures (`nav_preset` mismatch in `AGENTS.md`); do not flip `nav_preset`. Replan 13's frame suite (68 checks) must stay green. If a camera suite asserts the recentring on zoom-out, change only that assertion to the new rule and say so.

## Acceptance

- The new suite is green and was red on the starting ref (or the PR says `F` was already framing and classifies the remaining red rows).
- `F` / `Shift+F` / HUD `Frame` / marking menu all frame the same way and print `Framed selection` or `Framed all` exactly once.
- Wheel zoom keeps the point under the pointer within 2 px, both projections, part and sketch, in and out.
- `run_rung01_replan13_frame.gd`, walk and lint unchanged / clean.
- PR body: items 8, 9 fixed / skipped with the classification evidence; the per-notch table.

## Do not

- Change the sketch fit (`fit_view`, `sketch_fit_canvas_rect`) or #149's behaviour; change the notch step; touch nav presets or key bindings.
- Add test-only cameras or write `camera.yaw` / `.pitch` / `.distance` in the suite to place a view (use real keys and wheel; reading them is fine).
- Edit the `block_nav` lines or any focus code (WP2).
