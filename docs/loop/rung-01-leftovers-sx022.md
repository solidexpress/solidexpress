# Rung 1 leftovers from sx-022 (build 850a40c9, main @ fde6d95a): GUI walk FAIL, 5/10

The headless walk passes 163/0 (nut 7/7, wrench 28/28, thick 4/4). A real GUI
walk got nut 2/7 (closed mesh, AF 10.438, AC 12.053, thickness 20.0, bore
Ø 6.089) and never extruded a wrench blank. After the nut, the viewport showed
a 5×5×5 box, status `Inserted box — drag empty space or Alt-drag to orbit`,
and the selection rings plus the lift grip. One Esc left that chrome up. Up To
Surface was not run. The same session's CRITIQUE leftovers that the first
draft of the replan missed are 10–14 below: camera digits during a rubber-band,
the e2e harness shortcuts, variant chips over the finish bar, Exit Sketch, and
the export name field. Root causes, fixes, and acceptance checks are in
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
10. **Camera number keys swallow typed digits while rubber-banding.**
    Real `InputEventKey`s for `1`/`2`/`3`/`5`/`7` hit `OrbitCamera` before
    sketch keys. `_sketch_keys_blocked` is only true when a LineEdit or
    SpinBox is focused, and the dim blank is not focused during the
    rubber-band. `KEY_2` frames the right view and never seeds the blank, so
    a typed `20` loses the `2`. `KEY_5` while the sketch camera is locked
    returns handled and does not toggle projection. A typed length below
    0.5 mm still commits. Separate from leftover 2 (mouse-up pointer commit).
    Owners: WP3 routes digits and `.` to the dim blank before camera nav
    when `has_single_dof_preview()`; WP6 (`orbit_camera.gd` only) stops
    claiming `1`/`2`/`3`/`5`/`7` while `sketch_orientation_locked`; WP2
    rejects the short commit with status `Too short`.
11. **The e2e harness still shortcuts the GUI.** The walk widens the root to
    1920×900, calls `interaction._input` directly, emits `id_pressed` /
    `item_selected`, and assigns `dlg.current_path`. The critique desktop is
    1280×800. WP5 requires that size, `Viewport.push_input` for every pointer
    and key, clicks on popup and OptionButton items (`item_selected.emit`
    only inside `_pick_end`), and a typed FileDialog path. A lint fails the
    shortcuts. Leftover 6 is the gesture gap; this is the harness.
12. **Variant chips overlap the finish bar at 1280×800.** Finish bar is placed
    at `(60, 42)`. Chips are placed from `(rail_x, 80)` shifted up by the
    chip height, so the two rects intersect. WP1 stacks the chip row under
    the finish bar and asserts 1280×800 and 1366×768. WP4 stops passing
    `y = 80`.

## P1

6. **GUI e2e vs operator gap.** The walk types, then presses Enter, and emits
   menu ids. It does not click Extrude on an uncommitted Distance field, does
   not commit a polygon with the canvas click a student uses, and does not
   click File → New with the mouse. Window size and the other harness
   shortcuts are leftover 11.
7. **Dim blank / bore radius feedback.** Status must echo the committed radius
   and diameter, and must not call a pointer distance "AF 20".
13. **Exit Sketch is a cancel mark, and an empty sketch vanishes.** The rail
    button is an icon-only cancel (`label` empty) beside the dim blank.
    `exit_sketch` on an empty new sketch calls `cancel()` and emits
    `Empty sketch discarded` with no confirm. WP4 shows a check and the words
    `Exit Sketch`, and confirms before discarding an empty sketch. WP2
    publishes `is_empty_new_sketch` and the status
    `Empty sketch discarded — nothing was drawn`.
14. **Export name field.** Not leftover 8. `current_dir` / `current_file` on
    open stay as they landed. After the dialog is up, the filename is not
    selected, an absolute path typed into the name field is not split into
    directory plus file, and success status is `Exported 3MF` with no path.
    WP4 selects the whole name on focus, splits an absolute name, and sets
    status to `Exported 3MF → <full path>`.

## P2

8. **Export dialog defaults.** Landed in replan 1 (`current_dir` / `current_file`).
   Not a package in replan 2. Do not reopen. Leftover 14 is the typing and
   the status line, and it does not change these defaults. The e2e still
   exports through the dialog.
9. **Smart Dimension centre-to-flat 10.** Alternate nut path (apothem 10 → AF 20).
   The critique requires typed Across Flats 20, not this path.

## Out of scope / already good

- Kernel blank, jaw, slot, fillets (headless 28/28).
- Closed-mesh 3MF refuse (the GUI nut was manifold).
- First File → New on an empty session.
