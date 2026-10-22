# Rung 8 result — confirm-r8

**Does not pass the bar.** One-clean `SX_JOBS=1 SX_WALK_JOBS=1 tools/confirm_all.sh` from row 1 (`--a15`, no restores) at `build/confirm-r8`. Build 2026-10-22T19:21:33Z, godot 20:55:20Z, walks end 22:52:29Z. Product `fed0a886` (3rd A26 try) plus isolation `d1689f47` / kernel_cut `d6285e72`. Tree at finish `e7d8d814`. Isolated hexkey→spanner on `92de9b9` was **8/0 + 12/0**. No PR.

| Bar | Count |
|---|---|
| Head sha | `e7d8d814` / product `fed0a886` |
| Walk 1 | **76/77** (A15 godot-floor only) |
| Walk 2 | **43/44** (A25 godot-floor) |
| Walk 3 | **40/46** (N8/A19 fillet r=30 applied 9 edges; A20 r=1.5; A22 shell; N12; A26 floor) |
| Walk 4 | **31/32** (A21 godot-floor) |
| Walk 5 | **35/36** (A25 godot-floor) |
| Walk 6 | **45/46** (A36 godot-floor). Sweep **4/4**, final **7/7** |
| Walk 7 | **42/46**. A14 hex sealed, A18 strip, A21 C **1495.7** ring **275.2**, A23 boss **5/5** bbox **281.450**. A26 neck **42370** (4/5). A34 vol **38528**. N4. A37 floor |
| Walk 8 | **47/48** (A37 godot-floor) |
| `check_rung05` | **10/10** (walk 5 final) |
| `check_rung06` | **7/7** (walk 6 final) |
| `check_rung07` | boss **5/5**, neck **4/5**, final **7/8** (volume) |
| `check_rung08` | pin **3/3**, pipes **5/5**, bolted **7/7**, final **10/10** |
| Other checkers | wrench **28/28**, wrench-t14 **18/22 DIAG** (T=14), nut **7/7** |
| Headless | **262/2** (`film_spanner` **12/3** recess 42816, C held n=3 ring 275 R30 dv 972; `rung07_boss` Fillet R30 / neck **41864**). Isolated unique-HOME film **12/0** C **1494.5** `check_rung07` **8/8** vol **38958** |
| Kernel | **483/0** (11370 assertions) |
| Lint | **266** (e2e clean) |
| Critique | **9/10** |

## C-pad / volume (one line)

Walk-7 A21 C **1495.7** ring **275.2** and in-suite film C n=3 held after hexkey; film failed on recess Blind Cut (no extrude 7; kernel_cut landed after that suite). Neck/final sit one R30 crotch low (**42370** / **38528**) — 3 tries, do not loosen.

## Critique — 9/10 (pass ≥ 9)

Judged against [How to Sketch Combination Spanner in Solidworks](https://www.youtube.com/watch?v=RZB8m9li098) and stills `docs/loop/rung-07-frames/` t0181–t0516. Named tools in the video’s order land on this confirm walk: File → New `mmgs`, datum Front, construction CL + 17° ([t0068.jpg](rung-07-frames/t0068.jpg)), 3-click ellipse 55 steep × 50 along 17° ([t0100.jpg](rung-07-frames/t0100.jpg)), Parallel jaw offset 12.50 length 20 ([t0123.jpg](rung-07-frames/t0123.jpg)), Mirror + Symmetric ([t0135.jpg](rung-07-frames/t0135.jpg)), 3-point R15 ([t0147.jpg](rung-07-frames/t0147.jpg)), Power Trim ellipse → C ([t0156.jpg](rung-07-frames/t0156.jpg)), Ø33 + two AF-25 hexes ([t0181.jpg](rung-07-frames/t0181.jpg), [t0192.jpg](rung-07-frames/t0192.jpg), [t0208.jpg](rung-07-frames/t0208.jpg)) nest-punched to A_RING **275.172**, centre 240, handle half-width 10 Horizontal then Mirror, west seat on the remaining elliptical arc ([t0285.jpg](rung-07-frames/t0285.jpg), [t0315.jpg](rung-07-frames/t0315.jpg)), Boss Mid Plane 10 then handle Mid Plane 6 ([t0335.jpg](rung-07-frames/t0335.jpg), [t0347.jpg](rung-07-frames/t0347.jpg)), R30 / R20 necks ([t0366.jpg](rung-07-frames/t0366.jpg), [t0380.jpg](rung-07-frames/t0380.jpg)), Convert/offset recess Cut Blind 1 ([t0385.jpg](rung-07-frames/t0385.jpg), [t0415.jpg](rung-07-frames/t0415.jpg), [t0430.jpg](rung-07-frames/t0430.jpg)), R3, Feature Mirror Front ([t0483.jpg](rung-07-frames/t0483.jpg)), R1 remaining ([t0498.jpg](rung-07-frames/t0498.jpg), [t0516.jpg](rung-07-frames/t0516.jpg)). FEATURES `sketch 1 … fillet 10`. Bbox **281.450×54.590×10**. Isolated film **8/8** in 0.5%. Caps at 8 not used: no Box/Hole/polyline-C stand-in.

Findings that keep it off 10:

1. **One R30 crotch** — [t0366.jpg](rung-07-frames/t0366.jpg) both open-end 6 mm Z-edges. Walk A26 **42370** vs 42733 (dv≈548 vs film 972). Replica west-chord vs 17° ellipse at [t0285.jpg](rung-07-frames/t0285.jpg). Three tries; do not loosen.
2. **Hex wires** — [t0235.jpg](rung-07-frames/t0235.jpg) trimmed 12-point in Sketch1. We leave two closed AF-25 polygons; kernel overlapping-hex punch is the same ring **275.2**.
3. **Convert of neck fillets** — [t0385.jpg](rung-07-frames/t0385.jpg) Convert on the filleted handle. OCCT stores some edges as in-plane BSplines; film racetrack is recovery when Convert fails.
4. **C-head R1** — [t0498.jpg](rung-07-frames/t0498.jpg) outer C then remaining. Walk/film `fillet_remaining` is box-end 12-point rims only (C-head 10 mm Z-edge pulled xmin).
5. **Hidden Lines Removed** — [t0321.jpg](rung-07-frames/t0321.jpg). W cycle stays Shade / Edges / Wire.

Not used as stand-ins: leftover-hex sketch 4 / extrude 5; polyline C; skip elliptical trim; body-mirror for origin Front; major along 17°.
