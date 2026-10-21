# Rung 8 progress

- Round 3: film C-unopened, Shade/Frame IGNORE while placing, A15 godot-log gates.
- confirm-r5 godot **262/2**: `replan5_face` Front view (▼ was IGNORE) and `sx037_chipclick` Edges/Section/Zebra/Frame. Scoped IGNORE to Shade/Section/Frame only; View strip stays STOP.
- confirm-r6 godot **262/1**: `film_spanner` `C stayed unopened after trim (n=0)` — premature closed-contour check. Isolation 12/0. Trim now frames + kernel `trim_at` fallback; fail only if the ellipse stays closed.
- confirm-r7 godot **262/0** (film_spanner 12/0, bbox 281.450×54.591×10 under `--jobs 4`). Walks 1–6 green. Walk 7 **A23** FAIL bbox 226.876×37.295×10 (handle pad, C/ring out) — contour status notes mixed sentences so `set_contours({c,ring})` kept the handle. Attempt 1: parse last Contour sentence; keep chip pick across `refresh_contours`.
- Glyphs/J6 stay closed. No PR. No `docs/plan/STATUS.md`. No `.uid`.
