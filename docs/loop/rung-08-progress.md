# Rung 8 progress

- Round 3: film C-unopened, Shade/Frame IGNORE while placing, A15 godot-log gates — **closed**.
- confirm-r5 godot **262/2**: `replan5_face` Front view (▼ was IGNORE) and `sx037_chipclick` Edges/Section/Zebra/Frame. Scoped IGNORE to Shade/Section/Frame only; View strip stays STOP.
- confirm-r6 godot **262/1**: `film_spanner` `C stayed unopened after trim (n=0)` — premature closed-contour check. Isolation 12/0. Trim now frames + kernel `trim_at` fallback; fail only if the ellipse stays closed.
- confirm-r7 from row 1: godot **262/0**. Walks 1–6 + 8 green (77/44/46/32/36/46 + 48). A15/A25 PASS. Walk 7 **A23** 226.876×37.295 (handle pad). Attempts 1–3 still red (chip re-assert; select_contours+uncheck+chips; area pick). Logged as finding; no fourth attempt.
- Glyphs/J6 stay closed. No PR. No `docs/plan/STATUS.md`. No `.uid`.
