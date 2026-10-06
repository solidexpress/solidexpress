# Replan 13 WP3 — the Fillet Radius in the context strip and in the panel are one value

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main`). Edit only `game/scripts/ops_panel.gd`, `game/scripts/viewport_interaction.gd` (strip hunks below) and add `game/tests/run_rung01_replan13_radius.gd`.

Hunks you own (search by name; line numbers are `0573dea2`):

| File | Hunk |
|---|---|
| `ops_panel.gd` | `_radius_spin` (~212, the Modify panel `Radius`), `dressup_radius` / `set_dressup_radius` (~813–820), `arm_or_apply_fillet` / `arm_or_apply_chamfer` and the arm text at ~785, `_apply_dressup` (~865 `value = _radius_spin.value`), new signal `dressup_radius_changed(value)` |
| `viewport_interaction.gd` | `_strip_radius` construction (~359–380), `_on_dressup_armed_changed` (~4668), `_sync_strip_dressup_radius` (~4684) |

## The bug (sx-033 A11b/A11d)

Leftover 3: while Fillet is armed, the selection strip's `R` field (`StripRadius`, the "context bar") shows `1.0` or `0.0` while the Modify panel `Radius` holds `10`. The panel value wins when Enter applies (`_apply_dressup` reads `_radius_spin.value`), so the walker reads one number and gets another.

## Cause (read on `0573dea2`; **reproduce first**)

There are two `SpinBox`es and a one-way sync:

- The strip's `value_changed` pushes into the panel (`ops_panel.set_dressup_radius(v)`); the panel's `_radius_spin` pushes **nowhere**. Typing `10` in the panel (or `radius` changed by the timeline `PropertyPanel` or by a replayed document) leaves the strip at its last value.
- `_sync_strip_dressup_radius` copies the panel value into the strip only on arm/refresh and writes the text itself (`le.text = str(value) + " mm"`) after `set_value_no_signal`, which bypasses the SpinBox's own step formatting (the strip's step is forced to `0.001` while armed, so `10` prints as `10.0` or, with a step of `1`, as `1.0` after a clamp). A text write that races a pending `LineEdit` parse can show the first typed digit (`1`) or a clamped minimum (`0.05` → `0.0`).
- The strip's range (`0.05..100`, step `0.1`, `SxUi.configure_spin`) and the panel's (`0.1..100`, step `0.5`) differ, so a value that is valid in one clamps in the other.

## Decisions (see `rung-01-replan-13.md` 3)

- **One model value** lives on `OpsPanel` (`_radius_spin.value`, read through `dressup_radius()`). The panel's `_radius_spin.value_changed` emits `dressup_radius_changed(v)`; `viewport_interaction` connects it once (in `setup`/`_ready` where it connects `dressup_armed_changed`) and writes the strip with `set_value_no_signal(v)` and **no manual `le.text` write** unless the strip's `LineEdit` does not have focus.
- Both spins share one range and step: `0.05..100`, step `0.001` while armed (the strip already forces it), `0.5` for the arrow buttons otherwise. The panel's minimum becomes `0.05` (the strip's), so `0.1` is no longer a hidden floor.
- While the strip's `LineEdit` has focus, the panel does not write into it (typing never fights the sync). When it loses focus or submits, the strip re-reads the panel value.
- `_apply_dressup` keeps reading the panel value, but it first calls `_commit_strip_radius()` (apply any pending strip text through `SpinBox.apply()` then `set_dressup_radius`), so a value typed in the strip and applied with Enter in the viewport is the value that is used.
- The status line on arm and on apply names the value actually used: `Fillet r=10.00 — N edge(s) selected …` (already the format at ~785); no string changes.
- No change to the Modify panel layout, to `Radius` for chamfer (it is the same widget and the same fix), or to the sketch chrome `Radius` field (that one is the sketch dimension blank).

## Failing-first test — `game/tests/run_rung01_replan13_radius.gd` (create)

Template: `run_rung01_replan12_pick.gd` (box body, `select_entity`, arm Fillet through `ops_panel.arm_or_apply_fillet()`). Validation suite; every key/click under test is a real event.

1. Arm Fillet; set the panel `Radius` to `10` (`ops_panel._radius_spin.value = 10`, plus the same through its LineEdit with a pushed Enter); assert `StripRadius.value == 10`, and `StripRadius.get_line_edit().text` parses to `10` (`"10"`, `"10.0"` or `"10 mm"` all accepted; `"1"`, `"1.0"`, `"0.0"` fail).
2. Type `1.5` in the strip (focus, select all, keys, Enter): panel `Radius` is `1.5` and the pending apply uses `1.5` (watch the `applied` status: `… 1.50 applied`).
3. Esc (`Edge pick cancelled`), re-arm: strip and panel still agree (both `1.5`).
4. Arm Chamfer: strip and panel agree on the chamfer distance; `set_dressup_radius(0.05)` and `(100)` do not make the two diverge (same clamp on both).
5. Change the radius in the panel **while the strip's LineEdit has focus**: the focused text is not overwritten mid-typing; on focus exit the strip shows the panel value.
6. After `Fillet 2 edges 10.00 applied`, the strip and panel still read `10`; the timeline row's `radius` parameter reads `10`.

**Expected red** on `0573dea2`: items 1 and 5 (one-way sync) and likely 4 (different minimum). Record the real strip text you observe (`1.0` / `0.0` is the sx-033 report).

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_radius.gd
for t in run_rung01_replan12_pick run_rung01_replan12_fillet run_rung01_fillet_tests \
         run_rung01_replan11_fillet_ui run_rung01_replan11_fillet_err run_rung01_replan3_fillet; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
```

Every count equals the whole-suite table of replan 12 (pick 27/0, fillet 19/0, `run_rung01_fillet_tests` 30/0, fillet_ui 14/0, fillet_err 8/0, replan3_fillet 60/0).

## Do not

- Change what the Enter key commits, the face-click rule, the Esc ladder or any status string (replan 12 WP6).
- Add a third radius widget or a persistent per-document radius.
- Edit `sketch_context_chrome.gd` (open in #134/#136).
