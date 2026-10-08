# Rung 1 replan 17 — WP4: chrome — hover hint after the status hold, Timeline vs part chip row, window fills the screen

Status: planned. Plan: [`rung-01-replan-17.md`](rung-01-replan-17.md). Next walk: [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md) (sx-038). Baseline: `main` `1a1cc6ac40303fb747bd2a14d8e8ec98f1d5f705`.

Triage items fixed: **T1** (N16 hover hint appears only after a 1 px nudge), **T8** (Timeline panel covers the left end of the part chip row), **T12** (app window opens ~1072x620, not maximised, on 1280x800). Walk rows unblocked: **N16, N19, N23 (new), N22 (new), N6, N8b, N13**.

Files you may edit: `game/scripts/main.gd` (`_ready` tail, `_on_hover_hint`, `_on_status`, `_apply_chrome_docks`, new helpers placed directly after `_on_hover_hint`), `game/scripts/viewport_interaction.gd` (**only** `_update_hover`, `_layout_selection_strip`, plus two new small functions and one signal placed next to them), new `game/tests/run_rung01_replan17_chrome.gd`, new `packaging/ci/suites.d/rung01_replan17_chrome.suite`, `game/tests/run_rung01_replan16_chrome.gd` (only if a changed Timeline position breaks its C4 assertion).
Do not edit (other WPs): in `viewport_interaction.gd` the `_sketch_input`, `_input`, `_over_chrome`, `_viewport_owns_pointer`, `_draw`, `_on_press`, `_on_release` functions (WP3); `main.gd` `_on_sketch_solve` (WP2), `_on_sketch_rail_tool` / `_on_sketch_rail_toggled` (WP3); `project.godot` (do not change window settings there).

## Rules for every BUILD agent (read first)

- **Repository:** `github.com/solidexpress/solidexpress` only. Never the `snadrus` fork. Do not touch PR #11.
- **Model / start:** grok-4.7, medium effort. `starting_ref` = the full 40-character sha of `main` at launch (the plan was written against `1a1cc6ac40303fb747bd2a14d8e8ec98f1d5f705`; function names below are stable, line numbers are for that sha).
- **One PR per WP, to `main`.** Mark it **ready for review** (not draft). Never merge it yourself. Quick CI must be green: **linux kernel, godot-smoke, website-demos**. **Do not wait for `windows-export` or `macos-kernel`.**
- **Do NOT edit `docs/plan/STATUS.md`** (take `main`'s version on any conflict). Put your notes (what changed, reproduce-first output, skipped items with the reason) in the **PR body**.
- **Reproduce first.** Write the new suite, run it on the starting ref **before** any product edit, paste the real red/green output in the PR body. Green on baseline = keep the suite as a regression net and say the item was already fixed or is soft-GL.
- **Tests are real input.** Setup (placing geometry, entering a sketch, adding entities) may use the document / sketch API and `tests/lib/film_ui.gd`. Every press, key, motion and wheel **under test** is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed with `Viewport.push_input`. Forbidden on a path under test (the e2e lint fails the PR): `select_entity`, `.text =`, `.value =`, `.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =`. Boot at 1280x800 (`FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))`). Templates to copy: `game/tests/run_rung01_sx037_chipclick.gd` (`_boot`, `_x11_click`, `_x11_click_screen`, `_click_uv`, `_push_key`), `run_rung01_sx037_exit.gd`, `run_rung01_l12_measure.gd`.
- **Register a suite** by adding one new file `packaging/ci/suites.d/<name>.suite` (`<name>` = script basename without `run_` and `.gd`). Keys: `script=tests/run_rung01_replan17_<x>.gd`, `tier=ci` (when it runs in <= 60 s measured; say so in the PR) or `tier=full`, optional `timeout=<s>`. **Never edit** `packaging/ci/run_godot_suites.sh`, the Makefile `test-godot` recipe or `tools/lint_rung01_e2e.py` (WP5 is the only exception, and only for the files its own text names). Do not commit `.gd.uid` files.
- **Before opening the PR run, one at a time:** your new suite; `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` (0 failures, >= 729 checks); `tools/godot/godot --headless --path game --script tests/run_rung01_replan16_walk.gd` (0 failures, `WALK-SUMMARY stages=8 first_red=none`); every suite in your "Also run" list. Environment: `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib`, `DISPLAY=:1` for X11 suites; run suites alone. The known-red suites in `AGENTS.md` stay exactly as they are unless WP5 changes their tier.
- **Never** pass `user://` or `res://` into GDExtension C++ (`SxDocument` / kernel I/O); `ProjectSettings.globalize_path(...)` first.
- **Parallel-safe edits.** Other WPs run at the same time on the same files in *different functions*. Edit only the functions your WP names. No reformatting, no moved code, no new top-of-file constants outside your own block, no renames of existing status strings unless your WP says so.
- **No design decisions are left to you.** Every choice is in the `Decisions` section of your WP. If the code on `main` contradicts a stated fact, stop, say so in the PR body, and implement the closest reading of the decision.

## Why (verified on `main` 1a1cc6a)

- **N16.** `main.gd` `_on_status` (~2465) stamps `_status_hold_until = now + STATUS_HOLD_MS (2500)`; `_on_hover_hint` (~2478) returns early while held and **drops** the text. `viewport_interaction.gd` `_update_hover` (~2915) only emits a hint when `key != _last_hover_key`, where `key` includes the hit point rounded to 0.001 mm, and only runs on mouse **motion**. With a still pointer the last emit happened during the hold (dropped); nothing re-emits when the hold ends, so the label keeps the command result until the pointer moves one pixel. Also: with a body selected `_update_hover` returns early (transport-measure path) and emits no hint, and the miss branch emits nothing, so a stale held hint could never be cancelled.
- **T8.** `main.gd` `_apply_chrome_docks` (~1886) puts the Timeline at `(dock_left, ChromeDock.top_inset)` with `dock_left = left_stack right + 8`. `viewport_interaction.gd` `_layout_selection_strip` (~5428) puts the part chip row (`SelectionStrip`: Group / Similar / Hole / Hole Wizard / Fillet / Chamfer ...) at `x = _selection_strip_x_fixed()` = `left_stack right + 8` and `y = _selection_strip_y_fixed()` = `max(top_inset, TopChrome.end.y + 4)`. Same x, same y band: the Timeline (220 wide x up to 200 high) covers the left ~220 px of the chip row. `run_rung01_replan16_chrome.gd` C4 only checks Timeline vs the Modify panel Radius field.
- **T12.** `project.godot` asks for 1600x900 (`window/size/viewport_width/height`); `main.gd` `_ready` (~155) never sizes the window. The window manager in the walk gave ~1072x620 on a 1280x800 screen.

## Decisions (final)

1. **Held hints are deferred, not dropped.** `_on_hover_hint(text)`: empty text clears the pending hint; non-empty text during the hold is stored in `_held_hint` and flushed by **one** `SceneTreeTimer` armed for the remaining hold + 20 ms; at flush time, if a newer status extended the hold, re-arm; otherwise write `status_label.text = _held_hint` and clear it. A new non-hint status never clears `_held_hint` (the pointer is still on the face); a hover **miss** does.
2. **`ViewportInteraction` emits `hover_hint("")` whenever the hover target is cleared** (miss branch, `pointer_over_scrollable_ui` branch, and the selected-body early return when `_last_hover_key != ""`) and resets `_last_hover_key = ""` in those branches. Hint wording is unchanged.
3. **Timeline docks below the part chip row.** When `SelectionStrip` is visible and its rect overlaps the Timeline's x-range, the Timeline top is `strip.end.y + 4`; otherwise `top_inset`. Variables panel keeps docking under the Timeline. The chip row never moves (its x is fixed on purpose, N3). New API: `ViewportInteraction.selection_strip_global_rect() -> Rect2` (`Rect2()` when hidden) and `signal selection_strip_laid_out`, emitted at the end of `_layout_selection_strip` after `_layout_strip_busy` is cleared and only when the rect changed. `main.gd` connects it to `_apply_chrome_docks`.
4. **Window.** At startup (not headless, `SX_TEST_WINDOW` unset) the window is maximised; if after 3 frames it is still smaller than the usable screen rect by more than 8 px in either axis, it is moved to the usable rect's top-left and sized to `usable.size - decorations`. The sizing rule is a pure static function so a headless test can call it. `project.godot` is **not** changed.

## Steps

1. **Hold flush** (`main.gd`, new members next to `_status_hold_until` ~81 are allowed: `var _held_hint := ""`, `var _held_hint_timer: SceneTreeTimer`):
```gdscript
func _on_hover_hint(text: String) -> void:
	if text == "":
		_held_hint = ""
		return
	var now := Time.get_ticks_msec()
	if now < _status_hold_until:
		_held_hint = text
		_arm_hint_flush(_status_hold_until - now)
		return
	_held_hint = ""
	status_label.text = text


func _arm_hint_flush(ms: int) -> void:
	if _held_hint_timer != null:
		return
	_held_hint_timer = get_tree().create_timer(float(ms) / 1000.0 + 0.02)
	_held_hint_timer.timeout.connect(_flush_held_hint)


func _flush_held_hint() -> void:
	_held_hint_timer = null
	if _held_hint == "":
		return
	var now := Time.get_ticks_msec()
	if now < _status_hold_until:
		_arm_hint_flush(_status_hold_until - now)
		return
	status_label.text = _held_hint
	_held_hint = ""
```
2. **`_update_hover`**: in the `pointer_over_scrollable_ui` branch, the `hit.is_empty()` branch and (new) just before the `view.selected_body != ""` early return when `_last_hover_key != ""`, add `hover_hint.emit("")` and `_last_hover_key = ""`.
3. **Strip signal and rect** (`viewport_interaction.gd`): `signal selection_strip_laid_out` next to `signal hover_hint` (line 8), `var _last_strip_rect := Rect2()`, and
```gdscript
func selection_strip_global_rect() -> Rect2:
	if _selection_strip == null or not _selection_strip.visible:
		return Rect2()
	return _selection_strip.get_global_rect()
```
   At the end of `_layout_selection_strip` (after `_layout_strip_busy = false` and the `_strip_layout_again` re-entry), `var r := selection_strip_global_rect(); if r != _last_strip_rect: _last_strip_rect = r; selection_strip_laid_out.emit()`. Also emit when the strip becomes hidden (`visibility_changed` is already wired to `_layout_selection_strip`, which returns early when hidden: emit before that return when `_last_strip_rect != Rect2()` and reset it).
4. **`_apply_chrome_docks`**: compute `var timeline_top := top`; `var strip := interaction.selection_strip_global_rect() if interaction != null else Rect2()`; `if strip.size != Vector2.ZERO and strip.end.x > dock_left and strip.position.x < dock_left + max_w: timeline_top = maxf(top, strip.end.y + 4.0)`; use `timeline_top` for the Timeline `position`, `offset_top`, `offset_bottom`, and for `max_h`; Variables keeps `vtop = timeline.offset_bottom + 4.0`. In `_ready` (after `interaction` exists, i.e. after `_build_ui`) connect `interaction.selection_strip_laid_out.connect(_apply_chrome_docks)` once.
5. **Window** (`main.gd`): at the end of `_ready` call `_fit_window_to_screen()` (a coroutine; do not `await` it from `_ready`).
```gdscript
static func window_fit_rect(usable: Rect2i, win_size: Vector2i, decor: Vector2i) -> Rect2i:
	var want := usable.size - decor
	if win_size.x >= want.x - 8 and win_size.y >= want.y - 8:
		return Rect2i()
	return Rect2i(usable.position, want)


func _fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("SX_TEST_WINDOW") != "":
		return
	var win := get_window()
	if win == null or win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return
	win.mode = Window.MODE_MAXIMIZED
	for _i in 3:
		await get_tree().process_frame
	var id := win.get_window_id()
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(id))
	var decor := DisplayServer.window_get_size_with_decorations(id) - DisplayServer.window_get_size(id)
	var r := Main.window_fit_rect(usable, win.size, decor)
	if r.size != Vector2i.ZERO:
		win.mode = Window.MODE_WINDOWED
		win.position = r.position
		win.size = r.size
```
   (`Main` is the script's `class_name`; if there is none use `preload("res://scripts/main.gd").window_fit_rect`.)
6. **Real-window evidence** (not a CI check): on `DISPLAY=:1` run `tools/godot/godot --path game &`, then `xdotool search --name SolidExpress | head -1 | xargs xdotool getwindowgeometry` and `xprop -id <id> _NET_WM_STATE`; paste both before and after in the PR body.

## Acceptance (exact)

- New suite `run_rung01_replan17_chrome.gd`, `tier=ci`, `N checks, 0 failures` (runs ~6 s because of one real 2.7 s wait):
  - H1 boot 1280x800, New part with a box; nothing selected. Press key `0` (real key event) -> label `No view for key 0 — use 1 2 3 4 6 7 8`. Push **one** motion onto the body and then **no further events**; `await` 1.0 s: label still `No view for key 0 — use 1 2 3 4 6 7 8`; `await` until 3.0 s after the key: label is `Face — click selects body first, click again for face · then Pull arrow` (or the `Body — …` / `Edge — …` hint of the pixel; assert it begins with one of `Face — `, `Body — `, `Edge — `). No second motion was pushed.
  - H2 same, but the pointer leaves the body (motion to empty ground) during the hold: at 3.0 s the label is **still** `No view for key 0 — use 1 2 3 4 6 7 8` (no stale hint).
  - H3 a newer status (`Framed all` via key `F`) during the hold extends it: the hint appears 2.5 s after the **last** status.
  - T1 body selected (real click), Timeline on (`View > Timeline`): `timeline.get_global_rect()` and `interaction.selection_strip_global_rect()` do not intersect, the strip is fully inside the window, the Timeline is fully inside the window, every chip control inside the strip is `is_visible_in_tree()` and not covered by the Timeline rect; deselecting (Esc) puts the Timeline back at `ChromeDock.top_inset`; selecting again moves it below the strip again.
  - T2 the Timeline still does not intersect the Modify panel Radius field (`run_rung01_replan16_chrome.gd` C4 logic) with Fillet armed.
  - W1 `Main.window_fit_rect(Rect2i(0,0,1280,800), Vector2i(1072,620), Vector2i(0,28)) == Rect2i(0,0,1280,772)`; `window_fit_rect(Rect2i(0,0,1280,800), Vector2i(1272,770), Vector2i(0,28)) == Rect2i()`.
- `run_rung01_replan16_chrome.gd`, `run_rung01_replan16_walk.gd`, `run_rung01_replan14_ctxbar.gd`, `run_wrench_chrome_tests.gd` stay green.

## Also run

`run_rung01_replan16_chrome.gd`, `run_rung01_replan15_strings.gd` (status strings), `run_rung01_replan14_ctxbar.gd`, `run_wrench_chrome_tests.gd`, `run_rung01_replan11_chrome.gd`, `run_ui_tests.gd`, `run_rung01_sx036_rail.gd`.

## Rows unblocked

N16 (hint 3 s after the key with a still pointer), N8b (`Opened <path>` holds, then the hint), N13, N19, **N23** (Timeline never covers a chip), **N22** (window fills the screen), N6 (framing right of the left panel inside the real window size).
