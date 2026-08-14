# Slider and crank joints

Goal: a joint leaves **one** degree of freedom, and you drag the part to drive it. Joints ride on the same connectors as a Fastened mate — nothing new was added to the face-pair mate.

## Steps

1. Place the frame, and place a second body for the slider.
2. Select the slider → **Place instance of selection**.
3. In Assembly, pick **slider** from the same type list the mates use, then **Add mate**: click a face on the frame, then a face on the instance.
4. Drag the instance along the joint axis. The status line reads the live value in mm (or degrees for a hinge), and the Assembly row shows it.

## What “good” looks like

- One joint row, unit `mm` for a slider and `deg` for a revolute.
- Driving the same value twice lands in the same place, and returning to zero returns the part home — the pose is absolute, not cumulative.
- The joint and its posed value survive save and reload (`joints.json` in the `.sxp`).
- Mechanism check: `crank_slider_x(20, 80, 0)` = 100 mm, and at 90° it is `√(80² − 20²)` ≈ 77.5 mm.

Film: `crank_slider`. Kernel: `[wave1][joints]`.
