# Changelog

## 0.1.6 — 2026-10-19

- Combination spanner from "How to Sketch Combination Spanner in Solidworks" (ladder rung 7: angled construction axis, ellipse, 12-point box end from two trimmed hexes, mid-plane extrudes, neck fillets, offset recess mirrored to both faces) is now fully makeable end to end, with all rung 1 through 6 walks still passing.

## 0.1.5 — 2026-10-17

- SolidWorks Revolve & Sweep candlestick (ladder rung 6: revolve, swept boss along an arc path with an ellipse section, drafted cut) is now fully makeable end to end, with all rung 1 through 5 walks still passing.

## 0.1.4 — 2026-10-16

- UBC ELEC391 Exercise 3 flanged pipe (ladder rung 5: shell, flange, circular sketch pattern, feature mirror, re-shell, fillet) is now fully makeable end to end, with all rung 1 through 4 walks still passing.

## 0.1.3 — 2026-10-15

- Pano Central hex key Swept Boss (ladder rung 4) is now fully makeable end to end, with all rung 1, 2, and 3 walks still passing.

## 0.1.2 — 2026-10-14

- Official Learn SOLIDWORKS Lesson 1: Parts (Tutor1, ladder rung 3) is now fully makeable end to end, with all rung 1 and rung 2 walks still passing.
- Test runs are faster: each suite is owned by one parallel runner, and object-model tests run without rendering.

## 0.1.1 — 2026-10-11

- SolidWorks Student Guide Lesson 2 box (ladder rung 2) is now fully makeable: Shell with an open face, upright sketches on side faces, Through All cuts, and references that survive a driving-dimension edit.

## 0.1.0 — 2026-10-10

- Post-rung-1 cleanup: shared test suite and input helpers, table-driven kernel features, menus, work modes, bridge commands and sketch tools, shared sketch geometry, and one shared CAD-engine setup step in CI.
- UBC wrench demo film and video for the website.

## 0.0.13 — 2026-10-10

- UBC wrench tutorial (SolidWorks ladder rung 1) is now fully makeable.
- Jaw angle label, open-jaw cut, and selection/fillet picking fixes at small window sizes.
- Test-only automation bridge for checklist walks (`SX_AUTOMATION=1`).
