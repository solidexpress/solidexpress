# Replan 14 WP7 — the timeline pencil edits a sketch; File → Open enables on an existing `.sxp`

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only the files and hunks below and add `game/tests/run_rung01_replan14_polish.gd`. Read [`rung-01-replan-14.md`](rung-01-replan-14.md) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (items 14, 15, and 16 for context) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

| File | Hunk (search by name; line numbers are `93d31af`) |
|---|---|
| `game/scripts/timeline_panel.gd` | the row builder around `edit_btn` (~351), `name_btn.gui_input` (~282, add a right-click and F2 path only), `_begin_rename` (call only), `_edit_sketch_feature` (call only) |
| `game/scripts/main.gd` | `_show_file_dialog` tail (~3262), one new function `_sync_open_button`, one connect line in the file-dialog build block (~517–524) |

No other file. Do not touch `sketch_mode.gd`, `viewport_interaction.gd`, `ops_panel.gd` or any C++.

## The bugs (sx-034 walk-chunk3 / chunk5; leftovers 14, 15)

**Item 14 — the pencil opens Rename on a sketch row.** Verbatim: "Pencil next to `sketch 2` → rename field; re-entry needed a double-click on the name." Users read a pencil on a sketch row as "edit this sketch". Today the pencil (`edit_btn`, tooltip `Rename feature`) always calls `_begin_rename`; Edit Sketch is reachable only by double-clicking the name (`name_btn.gui_input`, `ftype == "sketch"` → `_edit_sketch_feature(fid)`), which the tooltip does not say (`Select feature (click again to rename) · drag to reorder`).

**Item 15 — File → Open: the Open button stays disabled.** Verbatim: "With `blank.sxp` selected or typed the Open button stayed disabled; double-click worked." Expected: Open is enabled when the name field holds an existing `.sxp` in the directory the dialog shows. The critique marked this "reproduce first: may be soft-GL" (the walker's typing through xdotool may not deliver the text-changed event the native `FileDialog` uses to recompute its OK button).

**Item 16 — closed, no code.** The first body is named `extrude 3` by design (`<feature type> <timeline index>`; datum plane + sketch + extrude). WP8 writes this into the sx-035 rules as rule 37. Nothing here.

## Cause (read on `93d31af`; **reproduce first**)

- Item 14: `timeline_panel.gd` ~351: `var edit_btn := UIIcons.button("rename", "", "Rename feature")` then `edit_btn.pressed.connect(func() -> void: _begin_rename(fid, row, name_btn))`. `f["type"]` is available in the same scope (`PropertyPanel.has_schema(str(f["type"]))` follows). `_edit_sketch_feature(fid)` (~387) already does `sm.begin_edit(fid)` + `refresh_sketch_pads` + status `Editing sketch`, and is what the double-click calls.
- Item 15: Godot's `FileDialog` in `FILE_MODE_OPEN_FILE` enables its OK button from its own selection / name-field handler. The repo opens it from `_show_file_dialog(FileAction.OPEN, FILE_MODE_OPEN_FILE, "*.sxp ; SolidExpress")` and then `_focus_file_name_field.call_deferred()`; nothing recomputes the OK button when the name field is edited by a synthetic key stream, and `_file_dialog_name_edit()` (~3047) already finds that `LineEdit`. Candidate causes: (a) the typed text never reaches `text_changed`; (b) the single click on an `ItemList` row selects it but the dialog keeps OK disabled until a second click (Godot behaviour); (c) the name field holds a name with a different case / no extension. **Reproduce first** with real key events into the focused name field and a real click on the `ItemList` row, and print `file_dialog.get_ok_button().disabled` at each step.

## Decisions (see `rung-01-replan-14.md` 8, item 11)

- **Pencil.** On a row whose `f["type"] == "sketch"` the pencil calls `_edit_sketch_feature(fid)`, its tooltip is `Edit sketch`, and its icon stays `rename` **unless** `UIIcons` already has an `edit` / `sketch` glyph used elsewhere in the timeline (then use it and say so). On every other row it still calls `_begin_rename` with tooltip `Rename feature`. The `name_btn` tooltip becomes `Select feature (double-click a sketch to edit it, click again to rename) · drag to reorder` on sketch rows and is unchanged elsewhere.
- **Rename stays reachable on a sketch row** in two ways: **F2** while the row is the selected feature (the timeline panel handles the key only when it has focus or the row's `name_btn` has focus; do not add a global shortcut and do not consume F2 when a text field has focus), and a right-click on the name button that pops a `PopupMenu` with one item `Rename` (id 0) that calls `_begin_rename`. Both exist for **every** row type (harmless on others). Single click then "click again to rename" (the existing second-click behaviour in `_select_feature`) is unchanged.
- **Open enable.** New `main.gd` function `_sync_open_button()`: only when `_file_action == FileAction.OPEN` and the dialog is visible, read `_file_dialog_name_edit()`, strip the text, and if it ends with `.sxp` (case-insensitive) and `FileAccess.file_exists(file_dialog.current_dir.path_join(text))` (or the text is an existing absolute path), set `file_dialog.get_ok_button().disabled = false`; never **disable** the button (Godot owns that direction) and never touch other actions (`INSERT_SXP`, imports, exports, `EXPORT_3MF` with its own button hooks). `_show_file_dialog` connects it **once**: `_file_dialog_name_edit().text_changed.connect(_sync_open_button.unbind(1))` guarded by `is_connected`, in the file-dialog build block after the dialog is added to the tree (the line edit exists then; if it is created lazily, connect inside `_show_file_dialog` before `popup_centered()` instead, with the guard) and calls `_sync_open_button.call_deferred()` after `popup_centered()` so a pre-filled name also enables it. Also connect `file_dialog.dir_selected` / the `ItemList` `item_selected` only if the reproduction shows candidate (b); otherwise leave them.
- **Standing rule:** the path given to `_on_file_selected` is already absolute; do not pass `user://` / `res://` into the kernel (AGENTS.md).
- If the reproduction shows the Open button **is** enabled for a real typed name and real click (the walker's typing is the only failure), keep the suite as a regression net, **do not add `_sync_open_button`**, and the PR classifies item 15 soft-GL with the printed `disabled` values. The timeline change still lands.

## Failing-first test — `game/tests/run_rung01_replan14_polish.gd` (create)

Template: `run_rung01_replan9_dirty.gd` (boot and the open / Discard flow) and the `FilmUI` helpers. 1280×800. Setup (document with a sketch and an extrude; writing a `.sxp` to `/tmp` through `main.save_to` / the existing save path, using `ProjectSettings.globalize_path` only for `user://`, never passing `user://` to the kernel) may use helpers; every click, key and motion under test is a real event.

Timeline:

1. Build a document with a datum plane, a sketch and an extrude. Find the sketch row's pencil (`edit_btn`: the row's second `Button` with the `rename`-icon; give it `name = "RowEdit"` in the code so the test can find it, and add that name to the hunk) and the extrude row's pencil. Click the **sketch** pencil with a real click: `sketch_mode.active` and `sketch_mode.editing_fid` is the sketch's fid; status `Editing sketch`; **no** rename `LineEdit` exists in the row (red on baseline: the rename field opens).
2. Exit the sketch (real Esc / Exit Sketch). Click the **extrude** pencil: the rename `LineEdit` opens (tooltip `Rename feature`); type a name, Enter: the timeline row shows it. (Regression net; green on baseline.)
3. Select the sketch row (real click), press real **F2**: the rename field opens on the sketch row. Esc cancels it. Right-click the sketch name: a popup with `Rename` appears; click it: the field opens.
4. Tooltips: the sketch pencil reads `Edit sketch`; the extrude pencil `Rename feature`.
5. Double-click on the sketch name still edits the sketch (unchanged).

Open:

6. Save the document to `/tmp/sx_polish_blank.sxp`. Open File → Open (real menu click through `FilmUI.activate_menu_id`; if the document is dirty the Discard dialog comes first: click through it with the real button as `run_rung01_replan9_dirty.gd` does). Focus the name field, type `sx_polish_blank.sxp` with real key events, record `get_ok_button().disabled` after **each** character (print the sequence). Expected after the last character: `disabled == false` (red on baseline if the bug reproduces). Then a real click on the Open button opens the file (status mentions the file name; the document's timeline has the same feature count).
7. Reopen the dialog, clear the field, type `nope.sxp` (does not exist): `disabled == true`. Type `sx_polish_blank.txt`: `disabled == true`.
8. A single real click on the `ItemList` row `sx_polish_blank.sxp` (find the row by text; real click at its centre) then a real click on Open opens it. If row 8 needs a second click, print that and apply candidate (b).
9. `Insert` (File → Insert `.sxp`) and the STEP import dialog's OK handling are unchanged: open each, record the OK button state before and after typing a non-matching name; identical to baseline (assert only that the new code did not enable OK for a name that does not exist).

**Expected red** on `93d31af`: rows 1, 3 (F2 / right-click), 4. Rows 6–8 are red only if the item reproduces headlessly; otherwise the PR classifies item 15 as soft-GL and these stay as the regression net. Print the observed `disabled` sequence either way.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_polish.gd
for t in run_rung01_replan9_dirty run_rung01_replan3_fillet run_menu_tests run_icon_tests; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
python3 tools/lint_rung01_e2e.py
tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone
```

Grep `game/tests` for `Rename feature` and `rename` timeline assertions (`rg -n "Rename feature|_begin_rename|edit_btn" game/tests`): change only an assertion that clicks the pencil on a **sketch** row expecting the rename field, and name it in the PR. `run_icon_tests` keeps its single pre-existing failure (`AGENTS.md`).

## Acceptance

- The new suite is green and was red on the starting ref for rows 1, 3, 4 (and 6–8 if item 15 reproduced; otherwise the PR says soft-GL with the printed values).
- The sketch row's pencil edits the sketch; every other row's pencil renames; F2 and the right-click `Rename` rename any row.
- Open is enabled for an existing `.sxp` typed or clicked, never enabled for a missing or non-`.sxp` name; no other dialog action changes.
- Walk and lint unchanged / clean; no `user://` or `res://` path reaches the kernel.
- PR body: items 14, 15 fixed (or 15 classified), item 16 closed by design; the `disabled` sequence for row 6.

## Do not

- Change what double-click does, the second-click rename, drag-and-drop, the suppress checkbox or the move buttons.
- Disable the Open button from our code or touch the export dialogs' OK handling (`EXPORT_3MF` hooks).
- Add global shortcuts, or consume F2 while a text field has focus.
- Rename body features (item 16) or change feature naming in the kernel.
