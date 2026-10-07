# Replan 15 WP4 — Export 3MF keeps the `.3mf` the user typed (leftover 3)

You are a BUILD agent (grok-4.7, medium effort, standard speed, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only the hunks below and add `game/tests/run_rung01_replan15_export.gd`. Read [`rung-01-replan-15.md`](rung-01-replan-15.md) (decisions 4, 11, 13) and [`rung-01-leftovers-sx035.md`](rung-01-leftovers-sx035.md) (item 3) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. **Do not merge your own PR**: mark it ready for review and stop; the parent merges.

| File | Hunk (search by name; line numbers are `d534765c`) |
|---|---|
| `game/scripts/main.gd` | the `FileAction.EXPORT_3MF:` arm of `_on_file_selected` (~3510–3535): one new line applying `_with_3mf_extension` to the resolved `path` (after the bare / absolute resolution, before `file_dialog.current_dir` / `current_file` are written back and before `view.doc.export_3mf(path)`); new `func _with_3mf_extension(path: String) -> String` placed right after `_resolve_export_3mf_path` (~3045–3060) |
| `game/tests/run_rung01_replan15_export.gd` | new |

No other file. Do not touch `_export_3mf_is_bare_name`, `_glued_absolute_export_path`, `_resolve_export_3mf_path`, `_export_3mf_dialog_dir`, `_snapshot_export_3mf_path_dir`, `_on_file_dialog_ok_pressed`, `_focus_export_3mf_filename`, `_on_export_3mf_name_changed`, `_on_export_3mf_path_changed`, `_export_3mf_filename()`, the File-menu item, or the Save As / SVG / DXF / PDF arms. Do not touch `run_rung01_wrench.gd` (`_export_via_dialog`, `_type_export_name`, `_export_bare_via_playground` stay as they are; WP7 owns that file).

## The defect (sx-035 leftover 3, verbatim)

> "File → Export 3MF filename truncates: typed `wrench.3mf`, saved as `wrench.3`."

## Causes (read from `d534765c`; hypotheses until the gate runs)

1. **`EXPORT_3MF` is the one export arm that never normalises the extension.** Save As does `if not path.ends_with(".sxp"): path += ".sxp"`; Context / Drawing / DXF / PDF do the same; `EXPORT_3MF` passes whatever the typed text resolved to straight to `view.doc.export_3mf(path)` (`SxDocument::export_3mf` does not append anything). Whatever reaches `_resolve_export_3mf_path` is the file name. (High confidence it is missing; the sx-035 symptom needs one more ingredient, below.)
2. **The text that arrives is already `wrench.3`.** The walk types the whole path per key and is green at `d534765c` (`B13` `export_via_dialog`), so a full name round-trips. The likely ingredient is a dropped key from the X11 test harness (the walker's soft-GL rule 1: keys that never arrived; the name field would then show `wrench.3` before OK), possibly combined with Godot's `FileDialog` save-mode extension logic completing a *known filter extension* only when the typed name has none. The kept text is read from `_export_3mf_accept_name` (`_on_export_3mf_name_changed`, snapshotted again in `_on_file_dialog_ok_pressed`), so whatever the field holds at OK is the name.
3. **The status names whatever was written** (`Exported 3MF → <path>`), so a truncated file reads as a success: no diagnostic.

Whichever is true, the app can end the guessing: **a path the user typed with an unfinished extension is completed, and a name with none gets `.3mf`**. That is decision 4. If the gate shows hypothesis 2's key-drop is real (the field shows `wrench.3`), the normaliser also fixes the observable symptom for the user; the PR says which of H1 (harness dropped keys), H2 (Godot filter logic), H3 (neither: a path-resolve bug) the evidence supports.

## Decision (replan 15, decision 4)

```
## The exported file always ends in .3mf: unchanged if it already does
## (case-insensitive); a partly typed "3mf" extension (".3", ".3m") is
## completed; anything else gets ".3mf" appended (the Save As rule).
func _with_3mf_extension(path: String) -> String:
	var p := path.strip_edges()
	if p == "":
		return p
	var lower := p.to_lower()
	if lower.ends_with(".3mf"):
		return p
	var dot := p.rfind(".")
	var slash := maxi(p.rfind("/"), p.rfind("\\"))
	if dot > slash and dot < p.length() - 1:
		var ext := lower.substr(dot + 1)
		if "3mf".begins_with(ext):
			return p.substr(0, dot) + ".3mf"
	if p.ends_with("."):
		return p + "3mf"
	return p + ".3mf"
```

Rules, so the function is testable by table (put them in the suite as a pure-function block):

| input | output |
|---|---|
| `/tmp/a/wrench.3mf` | unchanged |
| `/tmp/a/Wrench.3MF` | unchanged |
| `/tmp/a/wrench.3` | `/tmp/a/wrench.3mf` |
| `/tmp/a/wrench.3m` | `/tmp/a/wrench.3mf` |
| `/tmp/a/wrench` | `/tmp/a/wrench.3mf` |
| `/tmp/a/wrench.` | `/tmp/a/wrench.3mf` |
| `/tmp/a/my.part.v2` | `/tmp/a/my.part.v2.3mf` (a different extension is kept; `.3mf` appended) |
| `/tmp/a.b/wrench` | `/tmp/a.b/wrench.3mf` (a dot in a directory is not an extension) |
| `C:\tmp\wrench.3` | `C:\tmp\wrench.3mf` |
| `` (empty) | `` (unchanged; the existing failure path reports it) |

Apply it **once**, in the `EXPORT_3MF` arm, to the final `path` (both branches: the bare-name join and `_resolve_export_3mf_path`), before the dialog write-back and the export. `Exported 3MF → ` + the normalised path is the status (it already prints `path`). Keep every other line of the arm.

## Reproduce-first gate

Write `run_rung01_replan15_export.gd` first; run it on the starting ref **before** any product edit; paste the output.

Expected on `d534765c`:

- the pure-function block cannot call `_with_3mf_extension` (missing): `main.has_method("_with_3mf_extension")` false (red);
- the **truncated** and **bare** rows (below) are red: the file written is `wrench.3` / `wrench` (the test reads the directory listing and the status path);
- the **full-name** row (typed `wrench.3mf`, per-key) is probably green on baseline. If it is the only row the sx-035 symptom maps to and it is green, the PR states: *leftover 3 is soft-GL (dropped key) on the tester's side, plus the normaliser as the defence*; keep the normaliser and the suite.

## The suite (`run_rung01_replan15_export.gd`, real input, 1280×800, display needed like the walk)

Boot with `FilmUI` as the walk does. Setup (allowed): place a box (`FilmUI.place_primitive`) so `export_3mf` has a body. Copy `_click_menu_item`, `_x11_click_embedded`, `_x11_type`, `_dialog_name_edit`, `_probe_*` helpers you need from `run_rung01_wrench.gd` (copy verbatim, do not edit that file). Every export is File menu → Export 3MF (real click), name typed per key through real `InputEventKey`s into the dialog's name field, OK pressed with a real click.

| Row | Typed in the name field (after select-all) | Assertions |
|---|---|---|
| T1 | `/tmp/sx-replan15/wrench.3mf` | file `/tmp/sx-replan15/wrench.3mf` exists; **no** `wrench.3` or `wrench` sibling; status `Exported 3MF → /tmp/sx-replan15/wrench.3mf` |
| T2 | `/tmp/sx-replan15/trunc.3` (the observed truncation: type only up to `.3`, then OK) | file `trunc.3mf` exists; no `trunc.3`; status names `trunc.3mf` |
| T3 | `/tmp/sx-replan15/noext` | file `noext.3mf` exists; no `noext` file |
| T4 | bare `bare.3mf` after typing the folder in the Path field (the walk's bare flow) | `…/bare.3mf` in the browsed folder; not in `HOME` |
| T5 | bare `barenoext` | `…/barenoext.3mf` in the browsed folder |
| T6 | uppercase `/tmp/sx-replan15/Upper.3MF` | the file is written as typed (no `.3MF.3mf`) |
| T7 | `/tmp/sx-replan15/two.part.3mf` | `two.part.3mf`, not `two.3mf` |
| T8 | export a second time: the dialog suggests a `.3mf` name (`current_file` ends with `.3mf`) and the previous directory | `file_dialog.current_file.ends_with(".3mf")` |
| P1 | pure `main._with_3mf_extension` table above | every row |

Each row removes its output files first and lists `/tmp/sx-replan15/` afterwards (`DirAccess.get_files_at`) so a stray file fails the row. Counts are what the run prints. `user://` / `res://` are never passed to the exporter (`_resolve_export_3mf_path` already globalises).

## Do not

- Do not change how the typed text is read (`_export_3mf_accept_name`, the path snapshot, the dialog write-back) or the dialog suggestion (`_export_3mf_filename()`).
- Do not add a rename / "Save as" prompt or extra dialog; do not change the success or failure status wording other than the path it already prints.
- Do not edit `view.doc.export_3mf` / `SxDocument` (C++).
- Do not rewrite a user-typed non-`3mf` extension that is *not* a prefix of `3mf` (it is kept and `.3mf` appended).

## Run before the PR

New suite (0 failures; `export DISPLAY=:1`, run alone); `python3 tools/lint_rung01_e2e.py`; `run_rung01_replan10_cut.gd`; `run_rung01_replan2_shell.gd`; `run_rung01_replan3_shell.gd`; `run_rung01_replan3_input.gd`; `run_rung01_replan13_chrome.gd`; `run_rung01_wrench.gd` (0 failures, nut 7/7, wrench 28/28, thick 7/7, blank 5/5: its `_export_via_dialog` rows are the net for typed full paths and for the bare flow). PR title: `Rung 1 replan 15 WP4: Export 3MF keeps the .3mf extension`. PR body: leftover 3 (which of H1 / H2 / H3 the gate supports), the reproduce-first run (paste), the `_with_3mf_extension` table results.
