# Replan 14 WP6 — Jaw lights its own rail button and shows no Rect chips; Circle's centre click says so; Slot `c-c` label regression

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` at launch time, **after #151 ("Slot c-c status after typed length") is merged**; if `git log origin/main` does not contain #151 stop and report: row 7 below asserts #151's label and must not be written against code that lacks it). Edit only the files and hunks below and add `game/tests/run_rung01_replan14_railstatus.gd`. Read [`rung-01-replan-14.md`](rung-01-replan-14.md) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (items 10, 11, 12) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

| File | Hunk (search by name; line numbers are `93d31af`) |
|---|---|
| `game/scripts/main.gd` | the rail build, the `JawTool` button (~835); `_sync_sketch_rail_highlight` (~1504); `_on_sketch_tool_changed` (~1518) |
| `game/scripts/sketch_mode.gd` | `variants_for_tool` RECT arm (~1298); new public `is_jaw_armed()` next to `start_jaw_tool` (~1082); `_click_circle` first-click status (~3755). **Not** the `click` Slot arm or `slot_cc_status*` (#151) |
| existing tests | only the assertions named under "Existing suites" |

## The bugs (sx-034 walk-chunk2; leftovers 10, 11, 12)

**Item 10 — pressing Jaw highlights Rect.** Verbatim: "Status correct (`Jaw — click 1 centre, click 2 end of the long side, click 3 half the width`) but the **Rect** rail button is highlighted and the chip row is one chip, `Center Three Point`." A user who pressed Jaw sees Rect lit and a chip named after a Rect variant, and cannot tell which tool is armed (checklist L1: the rail highlights the armed tool).

**Item 11 — Slot length field label.** Verbatim: "After the first centre the field showed `21.31 mm`, then `150.0 mm`, still labelled `Radius r`." #151 relabels it `c-c` and hides the `r` cue. This WP only adds a regression assertion (row 7); it changes no Slot code.

**Item 12 — Circle centre click prints no status.** Verbatim: "Status stays `Circle — click the centre, then the rim (or type a radius)`." After the centre click the status must tell the user what is next.

## Cause (read on `93d31af`; **reproduce first**)

- `main.gd` builds one `ToolButton` per `entry` in a loop with `button_group = rail_group`, `toggle_mode = true` and `set_meta("sx_tool", tool_id)`. After the **Rect** entry it adds `JawTool`: a plain (non-toggle, no group, no `sx_tool` meta) button whose `pressed` calls `sketch_mode.start_jaw_tool`. `start_jaw_tool` sets `_arming_jaw = true`, calls `set_tool(Tool.RECT)` (which sets `_jaw_armed = _arming_jaw and t == RECT` and emits `tool_changed(RECT)`), then `set_tool_variant("center_three_point")`.
- `_on_sketch_tool_changed(RECT)` → `_sync_sketch_rail_highlight(RECT)` lights the button whose `sx_tool == RECT`, i.e. **Rect**. `JawTool` is never lit.
- `variants_for_tool(RECT)` returns `["center_three_point"]` while `_jaw_armed`, which `_on_sketch_tool_changed` shows as one chip row named by `_variant_kind_for(tool)` (the Rect chip set), so the one chip reads `Center Three Point`.
- `_click_circle` (centre variant) appends the first point and calls `_redraw()` with **no** `status.emit`, so the arm sentence from `tool_arm_hint(Tool.CIRCLE)` (`Circle — click the centre, then the rim (or type a radius)`, ~1050) stays on screen. Perimeter / Three Point variants have their own gesture and are not touched.

## Decisions (see `rung-01-replan-14.md` 8, items 9 and 10)

- **`SketchMode.is_jaw_armed() -> bool`** returns `_jaw_armed`. Nothing else reads the private field from outside.
- **Highlight.** `_sync_sketch_rail_highlight(tool)` additionally treats the button named `JawTool` as a rail button: it is pressed (via `set_pressed_no_signal`) **iff** `sketch_mode.is_jaw_armed()`, and every rail button with `sx_tool == RECT` is **not** pressed while Jaw is armed. `JawTool` becomes `toggle_mode = true` and joins `rail_group` (so a later Rect press unpresses it by the group, and Jaw behaves like every other rail tool; `pressed` stays connected to `start_jaw_tool`). Pressing the lit Jaw again must not toggle it off while armed: use `rail_group.allow_unpress = false` semantics (check the existing group; do not change other buttons' behaviour). Keep the node name `JawTool` and its tooltip (`run_rung01_replan8_rail.gd` finds it by name).
- **Order of signals.** `tool_changed` fires inside `set_tool`, before `set_tool_variant`. `_jaw_armed` is already set at that point, so `is_jaw_armed()` is true when `_sync_sketch_rail_highlight` runs. If a chip click (`set_tool_variant("corner")`) drops Jaw (`_jaw_armed = false`, `tool_changed.emit` at ~1093), the highlight returns to Rect through the same sync. Do not add a second code path.
- **No chips for Jaw.** `variants_for_tool(RECT)` returns `[]` while `_jaw_armed` (Jaw has one gesture; a one-chip row is noise and its name belongs to Rect). `_on_sketch_tool_changed` already hides the chip row for an empty list. Rect's own chips (`corner`, `center`, `three_point`, `center_three_point`, `parallelogram`) are unchanged when Jaw is **not** armed, including picking `Center Three Point` from the Rect chips (that is a plain Rect variant, not Jaw: `_jaw_armed` stays false, Rect is lit).
- **`tool_variant` is unchanged.** Jaw still sets `tool_variant = "center_three_point"` (the jaw gesture, status `JAW_HINT`, and many suites read it). Only the **chip list** and the **highlight** change.
- **Circle centre status.** After the first centre click of the **centre** variant, `_click_circle` emits `Circle — centre set, click the rim or type a radius` (new constant `CIRCLE_CENTRE_SET`) and records it as `_last_commit_text` is **not** touched (it is the arm hint, not a commit). The second click's `Circle r=… (Ø…)` is unchanged. Perimeter / Three Point first clicks keep today's (silent) behaviour: out of scope; say so in the PR.
- No other string changes. `JAW_HINT`, `tool_arm_hint`, the `Radius r` / `c-c` strings are not edited here.

## Failing-first test — `game/tests/run_rung01_replan14_railstatus.gd` (create)

Template: `run_rung01_replan12_rail.gd` and `run_rung01_replan13_arm.gd` (boot, `FilmUI.enter_sketch`, find the rail buttons, real presses with `FilmUI.click_control`). 1280×800. Presses on rail buttons and chips and the viewport clicks are real events; reading `pressed`, `sketch_mode.tool` and the status label is fine.

1. Enter a blank sketch. Press the rail **Rect**: `ToolRect.button_pressed`, `JawTool` is not pressed, the chip row shows the five Rect chips (record their labels).
2. Press the rail **Jaw** (real click on `JawTool`): `JawTool.button_pressed == true`; the `ToolRect` button is **not** pressed (red on baseline: Rect pressed, Jaw not); `sketch_mode.tool == RECT`, `tool_variant == "center_three_point"`, `is_jaw_armed()`; status equals `JAW_HINT` byte for byte; the chip row is hidden / empty (red on baseline: one chip `Center Three Point`).
3. Click the lit **Jaw** again: it stays pressed and armed (no unpress).
4. Press the rail **Rect**: `ToolRect` pressed, `JawTool` not, `is_jaw_armed()` false, the five chips are back. Pick the `Center Three Point` chip: `ToolRect` lit, `JawTool` not, `is_jaw_armed()` false (a Rect variant is not Jaw).
5. Press **Jaw**, then press the rail **Line**: only Line is lit; `JawTool` is not; the chip row is Line's own (or hidden, as for Line today). Press **Jaw**, then the rail **Rect**, then the chip `Corner`: Rect lit, `JawTool` not, `is_jaw_armed()` false.
6. **Circle centre.** Press rail **Circle**; status `Circle — click the centre, then the rim (or type a radius)`; real viewport click at a free point: status is exactly `Circle — centre set, click the rim or type a radius` (red on baseline: unchanged arm sentence); a second real click: status starts `Circle r=` and the circle exists (entity count +1). With the **Perimeter** chip, the first click's status is **not** the new sentence (documents the scope).
7. **Item 11 regression.** Press **Slot**, type radius 5 Enter, click the first centre: the sketch entry field's label text is `c-c` and does **not** contain `Radius` or `r` as a bare cue; type 150 Enter: status starts `Slot c-c 150.0000`. (Pins #151. Use the label lookup #151's own test uses, `run_rung01_replan12_slotarm.gd` or the chrome node it reads; reuse its helper, do not add a new probe.)
8. Jaw end to end still works after the change: with Jaw armed, three real clicks create the jaw (the replan 12 jaw suite's setup) and the status after click 3 is the jaw commit text that suite already asserts; `JawTool` is unpressed or Rect-less afterwards exactly as the tool state dictates (record it, assert only that Rect is not lit while `tool` is not RECT).

**Expected red** on `93d31af`: rows 2, 3 (if the toggle is not a plain button), 4's `JawTool` not pressed (green), 6. Rows 1, 7, 8 should be green. Print the observed `ToolRect.button_pressed` / `JawTool.button_pressed` / chip labels for rows 1–5.

## Existing suites (change only these assertions, and list each in the PR)

Grep `center_three_point` and `JawTool` in `game/tests/*.gd`: `run_rung01_replan8_rail.gd` (finds `JawTool`; asserts the variant), `run_rung01_replan9_chip.gd`, `run_rung01_replan10_esc.gd`, `run_rung01_replan12_jaw.gd`, `run_rung01_wrench.gd` (~2345). They read `tool_variant`, which does not change, so most need nothing. Edit an assertion **only** if it asserts the Jaw chip list is `["center_three_point"]` or that Rect is the lit button after Jaw; change it to the new rule and say which line. Do not touch walk rows that merely read `tool_variant`.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_railstatus.gd
for t in run_rung01_replan8_rail run_rung01_replan9_chip run_rung01_replan10_esc run_rung01_replan12_jaw \
         run_rung01_replan12_rail run_rung01_replan13_arm run_rung01_replan12_slotarm run_icon_tests; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
python3 tools/lint_rung01_e2e.py
tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone
```

If a named suite does not exist on `main`, `ls game/tests | rg slot` and use the one that exists. `run_icon_tests` keeps its single pre-existing failure (`AGENTS.md`): the Jaw button already has an icon, do not touch that failure.

## Acceptance

- The new suite is green and was red on the starting ref for rows 2 and 6 (observed values recorded).
- After a Jaw press: Jaw lit, Rect not, no chips; Rect's chip set and behaviour unchanged; `tool_variant`, `JAW_HINT` and the jaw gesture unchanged.
- The Circle centre click says `Circle — centre set, click the rim or type a radius`; every other Circle string byte-identical.
- The Slot field reads `c-c` (regression row green).
- Existing suites green except the documented pre-existing failures; walk and lint unchanged / clean.
- PR body: items 10, 12 fixed, item 11 verified; the per-button table for rows 1–5; the list of edited existing assertions (or "none").

## Do not

- Edit `click`'s Slot arm, `slot_cc_status*`, `_sync_dim_affordance` or any #151 line.
- Rename `JawTool`, change its icon or tooltip, or move it off the rail.
- Change `tool_variant` for Jaw or the Rect chip list when Jaw is not armed.
- Add a new status for Perimeter / Three Point circles.
