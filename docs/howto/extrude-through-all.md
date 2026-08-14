# Through-all extrude cut

Goal: cut a pocket through a plate without changing stock thickness.

## Steps

1. Place a plate (box).
2. Sketch a closed pocket on the top face.
3. Extrude with **End = through_all** and **Result = cut**.
4. PropertyPanel **End** enum is the chrome — no extra dock.

## What “good” looks like

- Plate Z extent unchanged.
- Volume drops by the pocket.

Film: `extrude_through_all`.
