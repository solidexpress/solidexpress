# Extrude a block letter A

Goal: sketch a closed capital **A** with a triangular counter (hole) and extrude it into a solid.

## Steps

1. Click **Sketch** in the palette (or start a sketch on the ground plane). The sketch toolbar shows labeled tools: **Select**, **Line**, **Rect**, **Circle**.
2. Click **Line** (or press **L**). With **Snap** on, draw the outer silhouette by clicking these plane coordinates (mm), then **Done** (or Esc / right-click) to end the chain:

   `(0,0) → (12,0) → (18,22) → (32,22) → (38,0) → (50,0) → (30,55) → (20,55) → (0,0)`

3. Still in **Line**, draw the inner triangular counter and **Done** (or Esc) to end:

   `(20,28) → (30,28) → (25,42) → (20,28)`

4. Press **Extrude** on the sketch toolbar with distance **10**. Operation **New** creates one body with a hole through the A.

5. Orbit to inspect — you should see a thick letter A pad with a triangular opening above the crossbar.

## Tips

- Both loops must be **closed** (last point meets the first). Snap helps land on endpoints.
- Toolbar clicks never draw under the bar — only clicks in the viewport place points.
- Related: [extrude-s-shape.md](extrude-s-shape.md) for a single-loop channel sketch.

## What “good” looks like

- One body in the document after extrude.
- Volume is positive and clearly less than a solid A without the counter (thousands of mm³ at 10 mm depth).

Verified by `run_howto_tests.gd` / `howto_extrude_letter_a`.
