# Rung 8 progress

- `c1a98ce` — J6 / glyphs green. Root cause: WP-V3 ViewCube ate the jaw-diagonal Line click (`drop:over-chrome:ViewHud` at 1156,470). ViewHud is now an IGNORE shell; draw tools place through ViewWidget.
- Cheap: `replan20_glyphs` 144/0, `replan20_jaw` 219/0.
- Next: full headless `--jobs 1 --tier full --keep-going`, then `SX_JOBS=1 SX_WALK_JOBS=1 tools/confirm_all.sh` from row 1.
