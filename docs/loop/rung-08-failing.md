# Rung 8 failing — remaining after product sweep

Test-and-fix on `cursor/rung-08-20261019` `ff7a23a`. No `confirm_all` (cheap reds remain). Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

Original 17 from `b787e32` cheap-rechecked after the handle/cut/fuse/loft/sweep/sliver/distance fixes: **15 pass, 2 remain**. Walks not re-run.

## Finding — replan20 glyphs / J6: `_trim_open_jaw` does not fire

Rows: `run_rung01_replan20_glyphs.gd` (144 checks, 2 failed), `run_rung01_replan20_jaw.gd` J6 (219 checks, 6 failed). Isolated, `--jobs 1`.

| Suite | Symptom |
|---|---|
| `run_rung01_replan20_glyphs.gd` | `_press_stub` at UV (185, 12) → kernel `"Trimmed"` not `"Trimmed open jaw"`; second Trim → `"Trimmed"` not `"Jaw is already open — nothing left to trim here"` |
| `run_rung01_replan20_jaw.gd` J6 | Trim stroke at (185, 0) on the regular-line diagonal through Ø45 → `"Trimmed"` (or `"Nothing trimmed"` if tangent walls are skipped). Extrude Up-To-Surface still commits. Final bbox **189.844 × 20.000 × 10.000** vs 232.5 × 45 × 10; checker jaw AF none |

Same family: `_trim_open_jaw` returns false, so `trim_at` falls through to kernel `trim_entity` on the nearest circle/line. Cutter rules (`_cutter_crosses_both_side_interiors` for regular lines) match `13a7386`. Face-sketch J6 has no ellipse; `_profile_has_type("ellipse")` is not the gate.

Tried (3, none cleared J6 / glyphs):

1. Power Trim line preference ellipse-only (`bbe3f83`) — overflow clicks on the C still take the line; jaw circle/arc still wins over walls. Glyphs/J6 unchanged (`"Trimmed"`).
2. `_jaw_long_sides` skip Tangent only when `L > 80` (`4d93646`) so 20 mm walls that picked up Tangent to Ø45 stay walls. Glyphs still `"Trimmed"`; J6 still 189.8 × 20 × 10.
3. Restore `13a7386` skip-all-Tangent. Glyphs still `"Trimmed"`; J6 became `"Nothing trimmed — no crossing at that point"` (worse). Reverted; keep (2).

Do **not** mark these `tier=known-red`. Do **not** loosen the status string or bbox. Next pass: why `_jaw_cutter_for_click` / `near_wall` miss the J6 diagonal at (185, 0) while `replan10_cut` / `replan15_jawstub` / `replan17_walk` open-jaw paths stay green.

Cheap recheck: `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '*replan20_glyphs*'` then `*replan20_jaw*`. Do not overlap a walk.

## Cleared from the previous 17 (do not re-open)

Handle / cut / fuse / loft / sweep / film / distance — cheap green on this tree:

- `run_film_spanner_tests.gd` 12/0, `check_rung07.py final` **8/8**, bbox 281.450×54.591×10, volume 38604.071
- `run_rung01_preview_rebuild.gd`, `replan10_cut`, `replan15_jawstub`, `replan17_walk`, `replan8_cut`, `sx038_regress`
- `run_rung01_replan3_distance.gd` 48/0 (`20.07.5` live spin stays 20)
- `run_rung03_offset.gd`, `run_rung07_boss.gd` (bbox 281.450×54.590×10), `run_rung07_offset.gd`
- `run_sketch_to_3d_ui_tests.gd`, `run_sweep_loft_solid_tests.gd`, `run_ui_tests.gd`, `run_workflow_tests.gd`

Walk 8 product was already 47/47 on `b787e32`. Walk 7 handle-missing bbox 232.6×33 was the same film/boss geometry; those suites are now 8/8 / boss-green. Confirm those walks from row 1 only after glyphs/J6 are green.

## Not findings

- Walk 8 N2 / A7 / A8 / A16 / A17 / A23 / A35 walker bugs (already fixed).
- WP-V1…V8 cheap suites: not in the remaining 2.
- 4 `tier=known-red` suites — listed, not run.
- `run_film_caption_tests.gd` / `run_ui_scroll_tests.gd` stay unregistered.
