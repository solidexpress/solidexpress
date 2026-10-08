# Sketch on a face (or the ground), leave, reopen

Goal: enter sketch mode via face pick, draw a profile, Exit Sketch to keep a yellow pad, reopen it, then extrude.

## Steps

1. In **Primitives**, click **Sketch**. Status asks you to select a face or existing sketch. Click a flat face (or empty ground for world XY). If a face is already selected, Sketch starts on it immediately.
2. The camera zooms and straightens to an orthographic view looking along the face normal. Orbit is locked; pan and zoom still work. The left rail swaps Primitives for **Exit Sketch** plus compact 2D primaries (Select / Line / Arc / Circle / Rect / Trim / …). Variants and Extrude/Dim controls appear as **on-canvas chips** — see [visual-sketch-tools.md](visual-sketch-tools.md).
3. Draw a closed rectangle with **Rect** (or Line). Other solids that cross the plane stay visible through the clear pad but are not selectable — only sketch geometry and plane intersection points are.
4. With **Select** armed, hover a sketch entity: a measure **✕** sits on it with that entity's length and **Δu / Δv**. Moving onto another entity moves the mark. Moving off the geometry, framing the view (`F`, `Shift+F`, HUD Frame), or changing the selection (including an empty-ground click and deselect) clears the ✕, the Δ labels, and any `0.00` gizmo label. Esc while the mark is showing says `Measure cleared` and leaves the sketch open.
5. Click **Exit Sketch**. The camera returns to the pre-sketch pose. A translucent **yellow pad** appears, extending ~20% past the sketch extents.
6. Click the yellow pad (or Sketch → pick the pad) to reopen. Edit, then Extrude or Exit again. Extrude / Revolve also leave sketch mode and restore the camera.

## What “good” looks like

- Left rail holds Exit Sketch + tools (no floating center toolbar).
- Enter locks orientation; leave restores the previous view.
- Exit commits a Sketch feature (yellow pad); Esc on a new empty/discarded session adds nothing.
- Reopen edits the same sketch feature (no duplicate sketch rows when Extruding after Exit).

Verified by sketch / UI / overhaul Godot tests.
