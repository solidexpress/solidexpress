# Replan 15 WP6 — strings: chain-break status without ids, view key `0`, the `applied` wording, a label click with Jaw armed (leftovers 8, 5, 4, 6)

You are a BUILD agent (grok-4.7, medium effort, standard speed, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only the hunks below and add `game/tests/run_rung01_replan15_strings.gd`. Read [`rung-01-replan-15.md`](rung-01-replan-15.md) (decisions 6, 7, 8, 9, 11, 13) and [`rung-01-leftovers-sx035.md`](rung-01-leftovers-sx035.md) (items 4, 5, 6, 8) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. **Do not merge your own PR**: mark it ready for review and stop; the parent merges.

| File | Hunk (search by name; line numbers are `d534765c`) |
|---|---|
| `game/scripts/sketch_mode.gd` | `_chain_breaker_status` (~3629–3659): the one `return "%s %s at (%.1f, %.1f) breaks the chain" % [breaker_type, breaker_id, …]` line **only** |
| `game/scripts/orbit_camera.gd` | `_is_nav_key` (~232): add `KEY_0` to the `KEY_1 … KEY_8` arm (same guard: not Alt, not `sketch_orientation_locked`); `_handle_nav_key` (~415): one new `KEY_0:` arm placed before `KEY_5` that returns `true` without moving the camera (and returns `false` when `sketch_orientation_locked`, like its neighbours) |
| `game/scripts/viewport_interaction.gd` | `_emit_view_key_status` (~329) **only**: one new `KEY_0:` arm in its `match` |
| `game/tests/run_rung01_replan15_strings.gd` | new |

No other file. Do not touch `_open_profile_point`, `finish_extrude`, `_jaw_no_cap_status`, `_trim_open_jaw` or any #165 hunk in `sketch_mode.gd`; do not touch `click`, `dimension_hit`, `_rebuild_dimension_labels` or the Jaw commit status (#164); do not touch `_apply_dressup`, `_emit_armed_dressup_status` or `_open_last_feature` in `ops_panel.gd` (the `applied` row only pins them); WP5 owns `_ctx_jaw_af` in `viewport_interaction.gd`, WP1 the `strip_le` lambda; do not edit `nav_preset`.

## The four items (sx-035 verbatim, condensed in `rung-01-leftovers-sx035.md`)

| # | Verbatim | Verdict | What this WP does |
|---|---|---|---|
| 8 | "the cut refusal status shows a raw UUID: `Line 77d1a0c0-… breaks the chain`" | real | status without ids (decision 9) |
| 5 | "View key `0` does nothing / no status" | real, tiny | prints `No view for key 0 — use 1 2 3 4 6 7 8` (decision 7) |
| 4 | "Fillet success says `applied`, not `Feature created`" | **no code change**: `applied` is deliberate (replan-12 WP6) | pin it in a headless test and in the checklist (decision 6) |
| 6 | "With Jaw armed a click on the dimension label starts a new Jaw" | **already fixed by #164** (`click` runs `dimension_hit` first) | pin it with a real click right after a real Jaw commit |

## Causes (read from `d534765c`; hypotheses until the gate runs)

- **Item 8.** `_chain_breaker_status` picks the nearest line / arc endpoint to the open vertex and formats `"%s %s at (%.1f, %.1f) breaks the chain" % [breaker_type, breaker_id, pt.x, pt.y]`; `breaker_id` is the sketch entity id (a UUID string). That is the only place the status contains an id. The two other returns (`open profile at (x, y) breaks the chain`, `open profile breaks the chain`) have no id and **keep their exact lowercase text** (`run_rung01_wrench.gd` asserts the absence of `open profile` on the blank extrude; do not capitalise them).
- **Item 5.** `0` is not in `OrbitCamera._is_nav_key`, so `camera.is_nav_event(event, …)` is false and `_emit_view_key_status` never runs (it is called only after `camera.handle_input` claims the event, ~4657 / ~4691). The key falls through silently. The label lists `1 2 3 4 6 7 8` because `5` is the projection toggle (it keeps its own behaviour; it has no view-status line today).
- **Item 4.** `_apply_dressup` builds `"%s %s %.2f applied"` (e.g. `Fillet 6 edges 1.00 applied`) and `_open_last_feature` may append `— View ▸ Timeline to edit parameters` / `— adjust parameters (Esc cancels, deselect keeps)`. `Feature created` is printed for every other feature. The sx-035 checklist said `Feature created`; the app was right.
- **Item 6.** In `SketchMode.click`, #164 moved the `dimension_hit(pos2, …)` first-glyph path in front of every tool arm, so a click on a label glyph with Jaw (or any tool) armed emits `dimension_edit_requested(index)` and the Jaw tool never sees the click. The replan-14 `savelabels` suite proves the label stays at 150 px / after Save As; **no test clicks a label while Jaw is still armed right after a real Jaw commit.**

## Changes

### 1. `_chain_breaker_status` (item 8)

```
if breaker_id != "":
	return "%s at (%.1f, %.1f) breaks the chain — delete or trim it" % [
			breaker_type.capitalize(), pt.x, pt.y]
```

- `breaker_type` is `line` or `arc` at that point (`entity` only when no breaker was found, which goes to the `open profile at …` return below), so the status reads `Line at (187.5, 18.7) breaks the chain — delete or trim it` or `Arc at (…) breaks the chain — delete or trim it`.
- `breaker_id` stays a local variable (still used to pick the nearest endpoint) but is **never** formatted. Do not add the id to any other status, log line, tooltip or dialog; do not change the two `open profile …` returns.

### 2. Key `0` (item 5)

- `OrbitCamera._is_nav_key`: `KEY_0` joins `KEY_1 … KEY_8` (so `is_nav_event` is true in part mode and false while `sketch_orientation_locked`, which is how a digit keeps typing into a sketch dim blank). Everything that already blocks nav keys (`_text_field_has_focus()`, `_sketch_keys_blocked()`, `SxUi.numeric_field_focused`) keeps blocking it, so `0` typed into the Radius / Distance / HUD fields is untouched.
- `OrbitCamera._handle_nav_key`: `KEY_0: return not sketch_orientation_locked` (the camera does not move).
- `ViewportInteraction._emit_view_key_status`: `KEY_0: status.emit("No view for key 0 — use 1 2 3 4 6 7 8")`.
- Ctrl / Meta / Alt + `0` stay un-claimed (the existing early returns and `not k.alt_pressed`). Keypad `0` is unchanged. Do not assign `0` to a view, to reset the camera, or to anything else.

### 3. `applied` (item 4) and the Jaw-armed label click (item 6): tests only

No product edit. If the gate shows either row red, **stop and report** (do not invent a fix; item 6 red would mean #164 regressed, item 4 red would mean `_apply_dressup`'s string changed).

## Reproduce-first gate

Write `run_rung01_replan15_strings.gd` first; run it on the starting ref **before** any product edit; paste the output.

Expected on `d534765c`: **S1 (chain-break) red** (the status contains a UUID: paste the real one); **S2 (key `0`) red** (no status, `status log` unchanged); **S3 (`applied`) green**; **S4 (Jaw-armed label click) green** (net for #164). If S3 / S4 are red, follow the stop rule above.

## The suite (`run_rung01_replan15_strings.gd`, real input, 1280×800, display needed like the walk)

Template: `run_rung01_replan14_savelabels.gd` (label glyph helpers `_label_first_glyph`, `_label_cam`, `_label_screen_center`), `run_rung01_replan14_focuskeys.gd` (`_boot`, `_place_box`, `_arm_fillet_strip`, `_click_at`, `_push_key`), `run_rung01_replan14_trim.gd` (`_x11_click_screen`). Copy the helpers you need; do not edit those files. Setup may use the sketch / document API and `FilmUI`; every key and click under test is a real event pushed through the viewport. **Do not use `FilmUI.click_control`** (it sends no real mouse event: it animates a cue and then calls `button.pressed.emit()`).

| Row | Steps | Assertions |
|---|---|---|
| S1a | box body; face sketch on the top face; three lines of a rectangle (open), Op = Cut, End = Blind, Distance 2; **one real click on Extrude** | status log has an entry that matches `^Line at \(-?\d+\.\d, -?\d+\.\d\) breaks the chain — delete or trim it$`; **no** entry matches `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-`; the sketch stays open; no new feature |
| S1b | an open **arc** chain (arc + line) | entry matches `^Arc at \(…\) breaks the chain — delete or trim it$`; no UUID |
| S1c | a profile whose open vertex has no line / arc endpoint to blame (try an open spline chain; if no setup reaches the `open profile at …` return, delete this row and say so in the PR) | `open profile at (x, y) breaks the chain` unchanged, lowercase; no UUID |
| S1d | closed profile Cut | none of the above appears; the cut commits (`Extrude Blind 2.0000 mm`) |
| S2a | part mode (box placed, nothing focused, sketch inactive); real key `0` | status `No view for key 0 — use 1 2 3 4 6 7 8`; camera yaw / pitch unchanged (±1e-4) |
| S2b | then real key `3` | `Top view` (the view keys still work after `0`) |
| S2c | real key `0` with a numeric field focused (click the HUD / strip field) | **no** status line; the digit appears in the field (`0`) |
| S2d | sketch active (Circle tool, centre placed, rubber-band): real keys `1`, `0` | the dim blank shows `10`, status `Circle r=10` / the existing wording; no `No view for key 0` |
| S2e | Ctrl+`0` and Alt+`0` (real modifier events) | no `No view for key 0` status |
| S3a | box; strip Fillet; key `3`; real click on the top face; radius 1 (strip field, per-key); real Enter in the viewport | status matches `^Fillet \d+ edges? 1\.00 applied` ; **never** contains `Feature created`; one `fillet` feature |
| S3b | same with Chamfer 1 | `^Chamfer … 1\.00 applied`; one `chamfer` feature |
| S3c | an Extrude of a ground rectangle | status `Extrude Blind … mm`; still not `applied` (the strings are different features) |
| S4 | ground sketch; Jaw tool armed (`FilmUI.select_sketch_tool(JAW)`); three real clicks; (the commit status `Jaw committed — width … click a label to edit it` appears); **with Jaw still armed** a real click on the **first glyph** of the width label, then (after Esc closes the editor) on the `45°` label | each click opens the dimension editor (`_dim_edit_popup` visible, the editor line shows `20` / `45`); `sm.sketch.entity_ids().size()` unchanged; status never starts with `Jaw — centre set`; Esc closes the editor; a **fourth** click away from every label with Jaw still armed starts a new Jaw (status `Jaw — centre set …`): the tool really is still armed |

Counts are what the run prints. No `select_entity`, `.text =`, `.value =`, `*.emit`, `_look_along(`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =` on a path under test (reading `camera.yaw` / `pitch` is allowed for assertions).

## Do not

- Do not change `applied` / `Feature created`, the Jaw commit status text, or `Jaw — centre set …`.
- Do not print an entity id anywhere. Do not lowercase / capitalise the `open profile …` statuses.
- Do not give `0` any view, and do not change `5`.
- Do not add a status to keys that already work (`1 2 3 4 6 7 8` statuses stay exactly as they are).
- Do not touch `nav_preset`, `run_rung01_wrench.gd` (WP7 adds the walk's UUID guard and the `applied` assertion).

## Run before the PR

New suite (0 failures; `export DISPLAY=:1`, run alone); `python3 tools/lint_rung01_e2e.py`; `run_rung01_replan14_savelabels.gd`, `run_rung01_replan14_camera.gd`, `run_rung01_replan14_focuskeys.gd`, `run_rung01_replan6_cut.gd`, `run_rung01_replan12_status.gd`, `run_rung01_replan10_cut.gd`, `run_camera_tests.gd` (its pre-existing `nav_preset` Alt-orbit rows stay exactly as before); `run_rung01_wrench.gd` (0 failures, 5/5, 7/7, 28/28, 7/7). PR title: `Rung 1 replan 15 WP6: chain-break status without ids; key 0; applied wording; Jaw-armed label click`. PR body: items 8 and 5 fixed, items 4 and 6 pinned (no product change), the reproduce-first run (paste), the real UUID the baseline printed.
