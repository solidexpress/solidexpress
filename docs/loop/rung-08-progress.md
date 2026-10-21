# Rung 8 progress

- Round 3: film C-unopened, Shade/Frame IGNORE while placing, A15 godot-log gates — **closed**.
- confirm-r5 godot **262/2**: `replan5_face` Front view (▼ was IGNORE) and `sx037_chipclick` Edges/Section/Zebra/Frame. Scoped IGNORE to Shade/Section/Frame only; View strip stays STOP.
- confirm-r6 godot **262/1**: `film_spanner` `C stayed unopened after trim (n=0)` — premature closed-contour check. Isolation 12/0. Trim now frames + kernel `trim_at` fallback; fail only if the ellipse stays closed.
- confirm-r7 from row 1: godot **262/0**. Walks 1–6 + 8 green (77/44/46/32/36/46 + 48). A15/A25 PASS. Walk 7 **A23** 226.876×37.295 (handle pad). Attempts 1–3 still red (chip re-assert; select_contours+uncheck+chips; area pick). Logged as finding; no fourth attempt.
- Glyphs/J6 stay closed. No PR. No `docs/plan/STATUS.md`. No `.uid`.
- Round 4: walk 7 A23 root cause — overlapping AF hexes inside Ø33 do not punch (MakeFace overlapping holes leaves a full disc; leftover opens force planar split into extra pads). Product: boolean-cut nested holes; keep nest when a contour has inner wires. Kernel tests added; OCCT install then `sxkernel_tests`.
- Round 4: nest_plus_split of leftover hex cells fragmented the C (film 7/12). Restore nest punch of the 12-point; drop ~6.5 mm² star-tip slivers inside Ø33; skip split cells whose COM is in a holed outer. Kernel **469/0**. `rung07_boss` bbox 281.450×54.590. film_spanner bbox 281.45 (volume 38399 vs 38782). wrench-t14 18/22 is by-design DIAG (T=14), not a regression.
- Round 4: A14 click-trim opens the 30° hex into 12 stubs and leaves the AF hex unclosed, so nest never sees hole wires (Ø33 reads ~823). Recover the two hexes from vertices on the common circumradius and punch only the circle pad (A_RING 275). Kernel **471/0**.
