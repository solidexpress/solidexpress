# CAM pocket

Goal: zig-zag pocket toolpath. **Mode → Cam** replaces Modify. Own G-code post — no CalculiX/Gmsh.

## Steps

1. **Mode → Cam**.
2. Pocket a 20×10 rectangle, step 2 mm, depth 2 mm.
3. Post has G21 and G1.

## What “good” looks like

- ≥ 8 toolpath points.

Film: `cam_pocket`. Kernel: `[wave4][cam]`.
