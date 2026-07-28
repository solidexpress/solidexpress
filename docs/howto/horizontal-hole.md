# Cut a horizontal hole through a box

Goal: place a box and a cylinder, tip the cylinder on its side, lengthen it, slide it through the box, and **Subtract** so the box keeps a clean horizontal hole.

For a **vertical drilled hole at a chosen point** (Ø, depth, counterbore/countersink): select a face → set Hole Ø / Depth → **Place hole…** → click the face. Clicks near a **corner** snap then inset by **Inset** (auto from Ø, face thickness, and material softness — softer/thicker stock and larger Ø push farther in). Clicks near an edge/face mid snap there; farther clicks place freely. **Apply hole** still drills at face center in one click.

## Steps

1. Click **Box** in the left **Primitives** palette, optionally set size in the bottom bar (a **20×20×20** cube is easy to see), then click the ground to place it.
2. Click empty space to clear selection (Primitives return). Click **Cylinder**. Place it beside the box — for example with diameter **8** and height **10**, offset in X so the solids do not already overlap.
3. Click the cylinder to select it. Grab a **rotate arc** (the ring tick that turns about **Y**, green) and rotate **90°**. After the drag, type `90` in the Δ° field and press **Enter** if you need an exact right angle. The cylinder should lie on its side (axis horizontal).
4. **Lengthen** the cylinder with either:
   - the blue **stretch** chevron on a **flat end** (axis direction — grows length; the cylinder stays horizontal), or
   - select a flat end face and drag the orange **Pull** arrow outward
   until the solid is longer than the box (e.g. ~35 mm). Side (radial) stretch chevrons change diameter only — they must not tip the solid upright.
5. Drag the cylinder body so it **pushes through** the box: the tool should stick out both sides with its axis roughly through the box center. Tap **X** / **Y** / **Z** while dragging to lock an axis if the solid drifts.
6. Multi-select for the boolean: click the **cylinder**, then **Shift-click** the **box** (the box must be primary — last selected — so it keeps the result). On the thin top strip, click **Subtract**. The cylinder disappears; the box remains with a **horizontal** hole. A **Boolean** feature appears on the timeline — moving / editing the solid regenerates the cut (the tool does not come back as a separate body).

## Tips

- Middle-drag / Alt-drag to orbit and confirm the hole goes side-to-side, not up through the top.
- If Subtract leaves the wrong body or no hole, undo (**Ctrl+Z**) and re-select so the **box** is last.
## What “good” looks like

- One body left in the document after Subtract.
- Looking from the side, you can see all the way through; from the top, a circular opening.
- Removed volume ≈ π · r² · (box width along the hole axis).

Verified by `run_howto_tests.gd` / `howto_horizontal_hole`.
