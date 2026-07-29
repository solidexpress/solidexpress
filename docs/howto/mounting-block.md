# Mounting block with centered through-hole

Goal: place a **100 × 60 × 30 mm** box and drill a **Ø20 mm** hole through its center — the canonical SolidWorks beginner “brick with a hole,” done the SolidExpress way.

SolidWorks needs ~**32** gestures (sketch rectangle → extrude → sketch circle → cut Through All). Prefer **Apply hole** here (face center). Use **Place hole…** when the hole is off-center.

See the click-count study: [workflow-study-mounting-block.md](../survey/workflow-study-mounting-block.md).

## Click path (~9–10 gestures)

1. Click **Box** in the Primitives palette.
2. In the place HUD, set size **100 × 60 × 30** (three fields).
3. Click the ground to place.
4. Click the **top face** (body, then face).
5. Set **Hole Ø** to **20** (Depth stays **0** = through).
6. Click **Apply hole** on the Modify panel — or **Hole** on the selection strip.

## Keyboard path (~7–8 gestures)

1. Click **Box**, type the three size values, click the ground to place (same as click path for place).
2. Click the top face.
3. Focus **Hole Ø**, type `20`, Enter. Leave **Depth (0=thru)** at **0**.
4. Press **`O`** — Apply hole at face center.

**`Shift+O`** arms **Place hole…** (then click the face). Selection strip **Hole** and RMB **Apply hole (center)** match **`O`**.

## Gesture comparison

| Path | Gestures | Notes |
|---|---|---|
| SolidWorks (efficient) | ~32 | Rect + dims + extrude + circle + cut Through All |
| SolidExpress **click** | ≤ 10 | Box + size + place + face + Ø + Apply hole |
| SolidExpress **keyboard** | ≤ 8 | Same place; type Ø; **`O`** instead of the button |

## What “good” looks like

- One body in the document.
- Volume ≈ `100×60×30 − π·10²·30` (~180 000 − 9425 ≈ **170 575 mm³**).
- Looking from above: a circular opening; from the side: see through.

Verified by `run_howto_tests.gd` / `howto_mounting_block` and `run_workflow_tests.gd` / `workflow_mounting_block` (click vs keyboard ceilings).
