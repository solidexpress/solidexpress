# Replan 15 WP5 — a click on Extrude extrudes once, and only `Extrude …` answers it (leftovers 7 and 10)

You are a BUILD agent (grok-4.7, medium effort, standard speed, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only the hunks below and add `game/tests/run_rung01_replan15_extrude.gd`. Read [`rung-01-replan-15.md`](rung-01-replan-15.md) (decisions 5, 10, 11, 13) and [`rung-01-leftovers-sx035.md`](rung-01-leftovers-sx035.md) (items 7 and 10) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. **Do not merge your own PR**: mark it ready for review and stop; the parent merges.

| File | Hunk (search by name; line numbers are `d534765c`) |
|---|---|
| `game/scripts/viewport_interaction.gd` | `_ctx_jaw_af` (~5443): one early-return line at the top; new vars `_post_finish_chip_guard_until_msec := 0` and `const POST_FINISH_CHIP_GUARD_MSEC := 600` next to the other strip vars (~96, beside `_strip_jaw_box`); new `func _wire_post_finish_guard() -> void` placed right after `_wire_numeric_focus_release` (~273); **one call line** `_wire_post_finish_guard()` right after the existing `_wire_numeric_focus_release()` call in `_ready` (~251). Nothing else in the file (WP1 owns the `strip_le.text_submitted` lambda, WP6 owns `_emit_view_key_status`) |
| `game/scripts/sketch_context_chrome.gd` | `_emit_finish_requested` (~626) **only if the reproduce gate points there** (see "If the gate says otherwise") |
| `game/scripts/main.gd` | the status block at the end of `_on_sketch_finish` (~1690–1700) **only if the gate points there** |
| `game/tests/run_rung01_replan15_extrude.gd` | new |

Do not change `_sync_strip_jaw_af`, the strip layout or the AF chip captions, tooltips or focus modes; `_ctx_jaw_af`'s two status strings (`jaw_af = %d (config %d)` and its `— regenerate: …` form) stay for a real click; `finish_extrude`, `_extrude_end_label` and the failure sentences stay.

## The defects (sx-035 walk-chunk1 A5, verbatim from the critique)

- **Item 7:** "two mouse presses on the *focused* Extrude finish-bar button changed nothing; Enter extruded. May be soft GL; classify if it reproduces on a headless press path. Expected: a real left click on Extrude commits the Blind extrude and prints `Extrude Blind …`."
- **Item 10:** "After the A5 Extrude Blind 10 the status briefly / oddly read `jaw_af = 10 (config 10)` instead of `Extrude Blind 10.0000 mm` (export still worked). Expected: the user-facing Extrude success names the feature and depth only."

## Causes (read from `d534765c`; hypotheses until the gate runs; one cause may explain both items)

1. **A stray second click lands on an AF chip (shared cause, medium confidence).** `_ctx_jaw_af(10)` is the only code that prints exactly `jaw_af = 10 (config 10)`, and it runs only from the strip's `StripJaw10` chip `pressed` (`_build_selection_strip` ~538). The chip is visible whenever a body is selected (`_sync_strip_jaw_af`: `selected_body != ""`), and `sketch_mode.finished` calls `_refresh_selection_strip()` (`_ready` ~257), so right after a sketch Extrude the new body is selected and the strip (with `AF 10 12 14`) appears. The walker pressed Extrude, the screenshot **lagged** (soft-GL, protocol rule 8) so the sketch still looked open, they pressed the same pixel again: that second press hits whatever the new strip shows there. That explains item 7 ("two presses did nothing": the first one worked; the status line overwritten by the chip's `jaw_af = 10 …` text) **and** item 10 in one stroke. It needs the Extrude pixel to overlap the strip: the gate measures it (see A0).
2. **The first press really did nothing** (low confidence; item 7 only). `_emit_finish_requested` → `_commit_distance_text()` returning `null` emits `distance_rejected` and stops: if the Distance field held an invalid / unparsed number, the press says so in the status, which the walker may have missed. The status text then is `distance_rejected`'s sentence, not `jaw_af`.
3. **The walk never sent a real click to Extrude (new, found while planning; medium-high confidence it matters for item 7).** `run_rung01_wrench.gd` `_press_extrude` uses `FilmUI.click_control`, which only animates a pointer cue (`ctx.chrome.animate_pointer_click`) and then calls `button.pressed.emit()`. So the walk (646 checks green) proves that `pressed` extrudes, **not** that a mouse press on the finish-bar Extrude button reaches it. `run_rung01_replan10_cut.gd` does `_x11_click(chrome.extrude_button())` (real `push_input`) and its cut is accepted, so a plain real click works in that setup; whether it works **for a focused button, right after typing Distance, with the Distance field's focus and the sketch HUD up** is untested. If A1 / A1b below are red, this is the real item-7 bug: some control or the viewport `_input` hook (`_over_chrome`, `_release_numeric_if_press_elsewhere`, `return_viewport_keys`) consumes the press or moves focus between press and release.
4. **Soft-GL**: the click is delivered but the frame shows nothing (rule 8). Then item 7 is classified soft-GL with the normal retry rule and only item 10 is real (cause 1).

## Decision (replan 15, decision 5)

- A press on any `StripJaw*` chip within `POST_FINISH_CHIP_GUARD_MSEC` (600 ms) of `sketch_mode.finished` is **ignored**: `_ctx_jaw_af` returns before touching the document and prints nothing. After the window the chips work exactly as before. The window is not extended by anything (it is a one-shot timestamp), so a deliberate click on `AF 12` a moment later still works.
- The Extrude success status stays `Extrude <End> <depth> mm` from `_on_sketch_finish` (e.g. `Extrude Blind 10.0000 mm`) and is the **last** status printed after a successful Extrude click. A second click at the same pixel prints nothing and creates no second feature.
- If the gate shows that the **first** click does not extrude (cause 2) the WP fixes that instead (see below).

```
const POST_FINISH_CHIP_GUARD_MSEC := 600
var _post_finish_chip_guard_until_msec := 0

func _wire_post_finish_guard() -> void:
	if sketch_mode == null:
		return
	sketch_mode.finished.connect(func(_id: String) -> void:
		_post_finish_chip_guard_until_msec = Time.get_ticks_msec() + POST_FINISH_CHIP_GUARD_MSEC)

func _ctx_jaw_af(size: int) -> void:
	if Time.get_ticks_msec() < _post_finish_chip_guard_until_msec:
		return
	... (unchanged)
```

Connect order does not matter: the guard timestamp is only read by a later press.

## Reproduce-first gate

Write `run_rung01_replan15_extrude.gd` first; run it on the starting ref **before** any product edit; paste the output.

Expected on `d534765c` (hypotheses):

- **A0 (measurement, not an assertion):** after a real Extrude of a ground rectangle at 1280×800, print the screen rect of the Extrude button **before** the click (the finish bar) and the global rects of `StripJaw10` / `StripJaw12` / `StripJaw14` and the other strip buttons **after** it; print `OVERLAP <control name>` for each strip control whose rect contains the Extrude button's centre, else `OVERLAP none`. Paste this line in the PR whatever it says.
- A1 (single real click, no `pressed.emit()` rescue) is probably **green** (the replan-10 cut proves a real click extrudes); **red** would be the cause-3 bug and is the most important result of this gate.
- A2 (second real click at the same pixel, ~2 frames later) is **red** if A0 reports a chip at the pixel: extrude count stays 1 but the status becomes `jaw_af = 10 (config 10)` and `doc.list_variables()` gains `jaw_af`.
- If A0 reports `OVERLAP none`, cause 1 is falsified: say so, and do the work for the cause the evidence selects (below).

## The suite (`run_rung01_replan15_extrude.gd`, real input only, 1280×800, display needed like the walk)

Template: `run_rung01_replan14_trim.gd` (`_boot`, `_x11_click_screen`, `_on_status`, `_status_log`). Setup (allowed): `FilmUI.enter_sketch` on the ground plane, `sm.sketch.add_line` ×4 for a `40 × 20` rectangle, `sm.run_solve()`. Under test (real events through the viewport): per-key typing into the Distance field (`10`), the real mouse clicks on the finish-bar Extrude button, and the strip chip clicks. **Do not use `FilmUI.click_control`** here (it only animates a pointer cue (`ctx.chrome.animate_pointer_click`) and then calls `button.pressed.emit()`: no real mouse event is ever delivered); click `button.get_global_rect().get_center()` with `_x11_click_screen(vp, pos)`.

| Row | Steps | Assertions |
|---|---|---|
| A0 | the measurement above | prints; asserts only that the Extrude button was visible and on screen (`FilmUI.is_on_screen`) before the click |
| A1 | End = Blind, Op = New, Distance `10` typed per key (no Enter); **one real click** on Extrude; wait 2 frames | exactly one new body; one new `extrude` feature; **last status** is `Extrude Blind 10.0000 mm` (log scan: the final entry); no status in the log contains `jaw_af`; `doc.list_variables()` has no `jaw_af`; the bbox is `40 × 20 × 10` (±0.2) |
| A1b | same, but first give the Extrude button keyboard focus (`grab_focus()` in setup), then one real click | same as A1 (the focused-button case from the critique) |
| A2 | **a second real click at the same pixel** immediately after A1 (still inside 600 ms) | extrude feature count still 1; body count still 1; status log has no new entry (or exactly the unchanged last entry); no `jaw_af` variable; `doc.last_graph_error() == ""` |
| A3 | wait 700 ms (`await create_timer(0.7).timeout`), real click on `StripJaw12` | status `jaw_af = 12 (config 12)`; `jaw_af == 12` in `list_variables()` (the chip still works after the window) |
| A4 | a **cut** blind: new ground-plane rectangle on the top face, Op = Cut, Distance `2.5`, one real click | last status `Extrude Blind 2.5000 mm`; no `jaw_af` text |
| A5 | an Up To Surface cut (Op = Cut, End = Up To Surface, Opposite face, one real click) | last status `Extrude Up To Surface 10.0000 mm` (the carried #165 / replan-14 wording, pinned, unchanged) |
| B1 | the Distance field invalid: type `abc` (real keys), one real click on Extrude | status is the existing invalid-distance sentence (log it); **no** feature added; the sketch stays open; no `jaw_af` text (this is cause 2's negative control) |

Counts are what the run prints. No `select_entity`, `.text =`, `.value =`, `*.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =` on a path under test.

## If the gate says otherwise

| Gate | What to do |
|---|---|
| A1 / A1b **red** (the first real click does not extrude, status shows `distance_rejected` or nothing) | cause 2 or 3 is real (print `vp.gui_get_focus_owner()` before the click, and, for every visible `Control` under `ctx.main` whose `get_global_rect()` contains the click point, its path and `mouse_filter`, to tell them apart): for cause 3 fix the control that eats the press or the focus hand-off the evidence names (smallest change, no layout change); for cause 2: fix the narrowest place the evidence names: `_emit_finish_requested` (a focused Extrude button whose `_commit_distance_text()` fails after a focus change: re-read the Distance field text instead of an invalidated cache), or the Extrude button's `pressed` connection in `sketch_context_chrome.gd` if the signal is connected twice or not at all. Report the exact reason; keep the guard only if A2 also needs it |
| A1 green, A2 green (no chip under the pixel, no stray status) | items 7 and 10 do not reproduce headless: classify **soft-GL (lag) + status ordering**, keep the suite, and still add the guard only if you can show a chip under the pixel in some other layout (1024×768). Otherwise add no product code: the PR is test-only and says so |
| A1 green but the last status is not `Extrude Blind 10.0000 mm` (some other string follows) | find the emitter (log the call stack of `status.emit` after `finished`); fix at that emitter, keep `_on_sketch_finish`'s string |

## Do not

- Do not change the Extrude button, the Finish bar layout or the `FinishEnd` / `FinishOp` options, the Distance field, `finish_extrude`, or any success / failure sentence in `sketch_mode.gd` (WP6 owns `_chain_breaker_status`; the Up To Surface wording is pinned).
- Do not ignore **real** AF chip clicks after the 600 ms window; do not guard the chips against anything except the sketch-finish window.
- Do not hide the strip after a finish (the strip is how Fillet / Chamfer are armed right after an Extrude).
- Do not add a timer node, `await`, or per-frame work (a timestamp compare only).

## Run before the PR

New suite (0 failures; `export DISPLAY=:1`, run alone); `python3 tools/lint_rung01_e2e.py`; `run_rung01_replan14_ctxbar.gd`, `run_rung01_replan14_focuskeys.gd`, `run_rung01_replan13_radius.gd`, `run_rung01_replan12_status.gd`, `run_rung01_replan10_cut.gd`; `run_rung01_wrench.gd` (0 failures, 5/5, 7/7, 28/28, 7/7). PR title: `Rung 1 replan 15 WP5: Extrude click extrudes once and says only Extrude`. PR body: items 7 and 10 (fixed / soft-GL / both), the A0 `OVERLAP` line, the reproduce-first run (paste), which cause the evidence supports.
