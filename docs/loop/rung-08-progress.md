# Rung 8 progress

- `c1a98ce` — J6 / glyphs green. ViewHud IGNORE shell; draw tools place through ViewWidget.
- Cheap: `run_rung08_typed_values.gd` 13/0, `run_rung01_replan12_fillet.gd` 19/0, `run_rung07_offset.gd` 17/0.
- Product: offset pull prefers LineEdit; `_on_distance` syncs leftover text. Pocket cut 1e-4 is silent (not a large-fuzz graph warning).
- Next: full headless `--jobs 1 --tier full --keep-going`, then `SX_JOBS=1 SX_WALK_JOBS=1 tools/confirm_all.sh` from row 1.
