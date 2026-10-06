# Replan 13 WP7 — Save As selects the file name; popups are opaque

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main`). Edit only `game/scripts/main.gd` (the hunks below), `game/scripts/view_hud.gd` (one theme override) and add `game/tests/run_rung01_replan13_chrome.gd`.

Hunks (search by name; line numbers are `0573dea2`): `main.gd` `_show_file_dialog` (~3120), `_focus_export_3mf_filename` (~2958, read-only template), `_apply_ui_theme` (~911), `_style_popup_menu` (~928); `view_hud.gd` `_ready` (the `_views_popup` / `_rename_popup` construction, ~133–150). Replan 12 WP3 owns the `current_file` pre-fill in `_show_file_dialog`; keep it.

## The bugs (sx-033 soft-GL notes, leftovers 8 and 11)

**Leftover 8 — Save As.** Replan 12 WP3 pre-fills the dialog with the current file name (`untitled.sxp`, `blank.sxp`). The walker then typed the new name and it **appended** to the old one (`blank.sxp` + `p`), or the walker's `Ctrl+A` was dropped by the desktop and the same happened. `_show_file_dialog` focuses and selects the name only for `EXPORT_3MF` (`_focus_export_3mf_filename`: `grab_focus` + `select_all` + deferred re-select); Save As gets nothing, so the name field is unfocused (or focused with the caret at the end) and every typed key appends.

**Leftover 11 — View HUD menu is semi-transparent over buttons.** The `View ▼` list (`ViewsPopup`, a `PopupPanel`) and the rename popup use the engine's default `PopupPanel` stylebox; `_apply_ui_theme` sets only font sizes. In the soft-GL screenshots the list is see-through over the Shade/Section/Frame buttons, which made the menu unreadable and one walker click land on the wrong row. The menu-bar `PopupMenu`s (File, Edit, View …) share the same unset theme.

## Decisions (see `rung-01-replan-13.md` 8 and 11)

- **Save As behaves like Export 3MF.** For `FileAction.SAVE_AS` (and `OPEN`) `_show_file_dialog` ends with the same deferred sequence: focus the dialog's filename `LineEdit`, `select_all()`, re-select on the next frame (the soft-GL dialog steals focus once). The shared body is extracted from `_focus_export_3mf_filename` into `_focus_file_name_field(select_all := true)` and both call it; the 3MF-only hooks (`_export_3mf_accept_name`, `text_changed`/`gui_input` watchers) stay on the 3MF path. Typing replaces the pre-filled name with no `Ctrl+A`. A `Ctrl+A` that arrives anyway is harmless (select all again).
- **Read-back stays.** Soft-GL rule 24 (read the resolved path back from `Saved <path>`) is unchanged; this WP removes the append, not the read-back.
- **Opaque popups.** `_apply_ui_theme` sets an opaque `StyleBoxFlat` for `PopupPanel/panel` and `PopupMenu/panel` (`bg_color` alpha 1.0, the existing dark panel colour, 1 px border, 6 px content margin). `view_hud.gd` does not need its own override; add one only if the test shows the window theme does not reach the HUD popups.
- No change to the HUD's `StyleBoxEmpty` shell (`Transparent shell so the RGB sticks float`): only popups become opaque.

## Failing-first test — `game/tests/run_rung01_replan13_chrome.gd` (create)

Template: `run_rung01_replan12_dialog.gd` (3 checks, same dialog) and `run_menu_tests.gd` for the menu popups.

1. Open a document with `current_path = <temp>/blank.sxp` (absolute, via `ProjectSettings.globalize_path`), press File → Save As through the menu; after two frames `file_dialog.visible`, the filename `LineEdit` has focus, `edit.has_selection()`, `edit.get_selected_text() == "blank.sxp"` (red on `0573dea2`).
2. Push the keys `p`, `.`, `s`, `x`, `p` as real `InputEventKey` events into the dialog window; `edit.text == "p.sxp"`: the typed characters replaced the pre-filled name, **not** `blank.sxpp.sxp` (red).
3. The same with an untitled document (`untitled.sxp`).
4. Export 3MF still selects its name (regression row for `_focus_export_3mf_filename`).
5. Open → the dialog does not select a name (no pre-filled file).
6. `get_theme_stylebox("panel", "PopupPanel")` as seen from `view_hud._views_popup`, `view_hud._rename_popup`, `viewport_interaction._orient_popup`, `_dim_edit_popup`, the timeline popups and from `main._view_popup` (`PopupMenu`) is a `StyleBoxFlat` with `bg_color.a == 1.0` (red on baseline for at least the HUD popups). Also assert `Window.transparent == false` and `transparent_bg == false` on each popup.

The popup is not pixel-read headless; the colour assertion in 6 is the check and sx-034 row L11 reads the screenshot.

**Expected red** on `0573dea2`: 1, 2, 3, 6.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_chrome.gd
for t in run_rung01_replan12_dialog run_rung01_replan11_ux run_menu_tests run_rung01_replan9_dirty run_rung01_replan6_export; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
```

Counts equal the whole-suite table of replan 12 (`run_menu_tests` keeps its 2 pre-existing failures).

## Do not

- Switch the dialog to a native dialog or change `access`, filters or `current_dir` logic.
- Change `_on_file_selected`, the Save As sketch re-entry (`_save_current`, replan 12 WP3) or the 3MF accept-name logic.
- Touch renderer / Mesa / llvmpipe settings; soft-GL drops keys and that stays out of scope.
