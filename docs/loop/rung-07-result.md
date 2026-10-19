# Rung 7 result — confirm on this branch

**PASS the bar.** `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable), dummy renderer for headless, walks on Xvfb. Confirm ran at `a8aa1c7`. Rung 1 N16 (result/restore timing) and rung 6 A14/A28 (3MF export under seven concurrent walks) failed that pass and PASSed on isolated retries with the same tree.

| Bar | Count |
|---|---|
| Rung 1 walk | 77 rows, PASS 77 |
| Rung 2 walk | 44 rows, PASS 44 |
| Rung 3 walk | 46 rows, PASS 46 |
| Rung 4 walk | 32 rows, PASS 32 |
| Rung 5 walk | 36 rows, PASS 36 |
| Rung 6 walk | 46 rows, PASS 46 |
| Rung 7 walk | 46 rows, PASS 46 |
| `check_rung05` final | 10/10 |
| `check_rung06` final | 7/7, bbox 304.064×220.000×223.971 mm (want 304.1×220×224.0 ± 0.2), volume 1,729,566 mm³ (want 1,730,343 ± 0.5 %) |
| `check_rung07` final | 8/8, bbox 281.450×54.591×10.000 mm (want 281.4×54.6×10.0 ± 0.2), volume 38,748 mm³ (want 38,782 ± 0.5 %) |
| Headless suites | 244 run, 0 failed |
| Checkers (units) | `test_check_rung02/03/04/05/06/07.py` 0, registry 0, lint_suites 0, kernel 0 |

## Critique — 9/10 (pass ≥ 9)

Judged against [How to Sketch Combination Spanner in Solidworks](https://www.youtube.com/watch?v=RZB8m9li098) and the stills in `docs/loop/rung-07-frames/`. Named tools in the video’s order land on the confirm walk: File → New `mmgs`, datum Front sketch ([t0031.jpg](rung-07-frames/t0031.jpg)), construction CL + 17° ([t0068.jpg](rung-07-frames/t0068.jpg)), 3-click ellipse 55 steep × 50 along 17° ([t0100.jpg](rung-07-frames/t0100.jpg), [t0108.jpg](rung-07-frames/t0108.jpg)), Parallel jaw offset 12.50 length 20 with point-on-ellipse ([t0084.jpg](rung-07-frames/t0084.jpg), [t0123.jpg](rung-07-frames/t0123.jpg)), Mirror Entities + Symmetric ([t0135.jpg](rung-07-frames/t0135.jpg)), 3-point R15 ([t0147.jpg](rung-07-frames/t0147.jpg)), Power Trim ellipse → C ([t0156.jpg](rung-07-frames/t0156.jpg)), Ø33 + two AF-25 hexes trimmed to 12-point ([t0192.jpg](rung-07-frames/t0192.jpg), [t0235.jpg](rung-07-frames/t0235.jpg)), centre 240, handle half-width 10 Horizontal then Mirror ([t0264.jpg](rung-07-frames/t0264.jpg), [t0294.jpg](rung-07-frames/t0294.jpg)), Boss Mid Plane 10 then handle Mid Plane 6 ([t0335.jpg](rung-07-frames/t0335.jpg), [t0347.jpg](rung-07-frames/t0347.jpg)), R30 / R20 necks ([t0366.jpg](rung-07-frames/t0366.jpg), [t0380.jpg](rung-07-frames/t0380.jpg)), face Convert + Offset 5 Cut Blind 1 ([t0415.jpg](rung-07-frames/t0415.jpg), [t0430.jpg](rung-07-frames/t0430.jpg)), R3, Feature Mirror about origin Front ([t0483.jpg](rung-07-frames/t0483.jpg)), R1 remaining. Walk 46/46 and `check_rung07.py final` 8/8 (handle on +X, open end on −X, recess both faces, one body). Headless 244/0. Rungs 1–6 at bar.

Findings that keep it off 10:

1. **Convert of neck fillets** — [t0385.jpg](rung-07-frames/t0385.jpg) Convert Entities on the filleted handle outline. OCCT stores those R30/R20 edges as in-plane BSplines; Convert fits circular arcs rather than copying the kernel curve type.
2. **Hidden Lines Removed** — [t0321.jpg](rung-07-frames/t0321.jpg) finished sketch / isometric. W cycle stays Shade / Edges / Wire.
3. **Coincident badges** — [t0084.jpg](rung-07-frames/t0084.jpg) Coincident6 in Existing Relations. Glyphs are hover-only at the vertex (14 px) so they do not cover a hex Vertical pick; SolidWorks keeps them in the PM list.
4. **Material / lettering** — [t0523.jpg](rung-07-frames/t0523.jpg)–[t0540.jpg](rung-07-frames/t0540.jpg) Cast Stainless Steel and “CAD CAM TUTORIAL”. Out of scope.

Not used as stand-ins: polyline / construction-line C; skip elliptical trim; Convert as pierce points or full circles for the fillet arcs; body-mirror or a side-face for origin Front; Fillet3 skipped in the mirror; major along 17°; 90° neck as the target; two bodies; offset 3 mm; one-face recess.

## WPs

Shipped WP1–WP10. None reverted. Caps at 8 not used.
