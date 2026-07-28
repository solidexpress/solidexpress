# Visual sketch tools (SolidWorks-class, planar)

Goal: use the compact left rail and on-canvas chips to draw, modify, and constrain sketches without a free 3D sketch mode.

## Left rail (primaries)

In sketch mode the left rail shows: **Exit Sketch**, Select, Line, Arc, Circle, Rect, Polygon, Ellipse, Slot, Spline, Point, Trim, Extend, Smart Dim, Convert, Mirror, Pattern — plus Snap / Infer / Auto-close and DOF readout.

Snap (default on) magnets to endpoints, midpoints, centers, H/V, and **perpendicular** to the previous segment (or nearby lines). Infer (default on) adds H / V / ⊥ / coincident while drawing. **Line** is a multi-segment chain: keep clicking corners; finish with **Done**, **Esc**, right-click, or double-click. Auto-close (default on) then adds a closing segment back to the first point; uncheck it for open rails.

Variants and numeric options appear **on-canvas** (floating chips), not as permanent rail spinboxes.

## On-canvas chips

1. Arm **Rect / Circle / Arc / Pattern** — a variant strip appears (corner/center/3-pt; center/perimeter; center/tangent/3-pt; linear/circular).
2. Select one or more entities — action chips: Construction, Delete, Fillet, Chamfer, Offset, Pattern, Mirror, Block, Split, and common relations.
3. Finish strip (top-left while sketching): Dim value (live rubber-band distance while drawing — type to lock length/radius, Enter commits), Extrude distance/op, Extrude / Revolve.

## Power Trim

- Tool **Trim** (T): hover highlights the nearest segment in red; click trims it.
- Drag across entities to cut each one the cursor crosses (SW-like Power Trim).

## Derived geometry

- **Convert**: with body edges selected, projects them onto the sketch plane as **associative** external lines/circles (`projected_from` edge id). On regen, geometry updates from the live edge; dangling edges become construction. Without an edge selection, Convert still turns pierce / plane-intersection points into sketch points.
- **Mirror**: select geometry plus one axis line, then Mirror.
- **Pattern**: linear (kernel) or circular (rotated copies) via variant chips.
- **Smart Dim** (D): click a line for length, circle/arc for radius, or two points for distance. Edit a label to type a number or `=w/2` (variables). **Alt+click** a dim label toggles driving vs driven (reference).
- **Relations**: selection chips include midpoint, symmetric, fix, diameter, plus Fully Define / Analyze.
- **Typed length while drawing**: after the first click of a line / center-circle / polygon / slot / center-arc, the finish-strip mm blank tracks the rubber-band. Type a number (or click the blank) to lock distance; mouse still steers direction; **Enter** places the point. Esc unlocks.
- **Spline**: commits a true kernel spline entity (fit points → B-spline profile/path), not densified lines.

## Blocks & picture

- Selection → **Block** names the current selection for reuse; `place_block` offsets a copy.
- `set_sketch_picture(texture)` draws a translucent underlay on the plane for tracing.

## 3D paths without 3D sketch

See [multi-sketch-merge.md](multi-sketch-merge.md): Ctrl+click yellow pads → Merge sketches… → Path feature → Sweep along path.
