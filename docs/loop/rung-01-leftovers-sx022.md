# Rung 1 leftovers from sx-022 (build 850a40c9, main @ fde6d95a): GUI walk FAIL, 5/10

The headless walk passes 163/0 (nut 7/7, wrench 28/28, thick 4/4). A real GUI
walk got nut 2/7 (closed mesh, AF 10.438, AC 12.053, thickness 20.0, bore
Ø 6.089) and never extruded a wrench blank. After the nut, the viewport showed
a 5×5×5 box, status `Inserted box — drag empty space or Alt-drag to orbit`,
and the selection rings plus the lift grip. One Esc left that chrome up. Up To
Surface was not run. Root causes, fixes, and acceptance checks are in
[`rung-01-replan-2.md`](rung-01-replan-2.md). Prior leftovers:
[`rung-01-leftovers-sx020.md`](rung-01-leftovers-sx020.md).

Shots from that session: empty New works; the nut is the wrong size; the
second part is the 5 mm box with the File menu open.

## P0

1. **Finish-bar Distance must accept typed 7.5 (and show it).**
   The nut extruded at the distance default 20.0 after the operator typed 7.5.
2. **Polygon Across Flats / dim blank commits the wrong size.**
   Typed AF 20 became AF 10.438. Typed bore radius 5 became Ø 6.089. The hex
   ratio is exact, so Across Flats was on and the magnitude is the pointer
   distance.
3. **File → New after a part must stay empty (no Insert Box).**
   Status `Inserted box — drag empty space or Alt-drag to orbit` is the
   click-to-place commit. The cube button sits directly under Sketch.
4. **One Esc must drop the selection chrome from any focus.**
   The rings in the shot are the selection rotate grips and the lift grip.
   Headless Esc passes. The GUI, with the File menu open and the box selected,
   kept both.
5. **Up To Surface face pick — re-verify in the GUI.**
   No wrench blank, so the bottom-face pick was not exercised.

## P1

6. **GUI e2e vs operator gap.** The walk types, then presses Enter, and emits
   menu ids. It does not click Extrude on an uncommitted Distance field, does
   not commit a polygon with the canvas click a student uses, and does not
   click File → New with the mouse.
7. **Dim blank / bore radius feedback.** Status must echo the committed radius
   and diameter, and must not call a pointer distance "AF 20".

## P2

8. **Export dialog defaults.** Landed in replan 1 (`current_dir` / `current_file`).
   Not a package in replan 2. The e2e still exports through the dialog.
9. **Smart Dimension centre-to-flat 10.** Alternate nut path (apothem 10 → AF 20).
   The critique requires typed Across Flats 20, not this path.

## Out of scope / already good

- Kernel blank, jaw, slot, fillets (headless 28/28).
- Closed-mesh 3MF refuse (the GUI nut was manifold).
- First File → New on an empty session.
