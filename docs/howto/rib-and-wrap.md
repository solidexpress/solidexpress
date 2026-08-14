# Rib follows a sketch

Goal: a rib is swept from an **open** sketch profile, so it grows and turns with the profile instead of being a fixed block. Marking menu **Rib** (S) — no OpsPanel row.

## Steps

1. Place a plate.
2. **Sketch** on it and draw an open two-leg profile with the line tool. Leave sketch mode (an open profile has nothing to extrude).
3. Select the plate → **S** → **Rib**.

## What “good” looks like

- Timeline row type `rib`, still one solid.
- Volume rises by roughly profile length × thickness × height, so a second leg adds more than the first alone.

Film: `rib_and_wrap`. Kernel: `[tier0][rib]`, `[wave1][rib]`.
