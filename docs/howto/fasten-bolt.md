# Fasten a bolt with one mate

Goal: seat a bolt in a hole with a single **Fastened** mate (Onshape-style connectors). Yesterday you needed coincident + concentric.

## Steps

1. Place a plate and a bolt (cylinder).
2. Select the bolt → **Place instance of selection**.
3. In Assembly, choose **fastened**. Click the hole face, then the bolt face.
4. **Solve mates**. The bolt origin locks to the hole connector (all 6 DOF).

## What “good” looks like

- One mate row, type `fastened`.
- Bolt axis and origin coincide with the hole connector (gap ≈ 0 mm).

Film: `fasten_bolt`. Kernel: `[mates]` fastened case.
