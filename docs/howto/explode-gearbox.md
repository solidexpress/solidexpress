# Explode a gearbox and put it back

Goal: exploded view is a way of *seeing*. Components travel along their joints (or away from the assembly centre), and collapsing restores the assembled placement exactly. Nothing is re-solved.

## Steps

1. Place a housing and instance a shaft (or any second part).
2. Click **Explode** on the ViewHud — it sits beside Section, and only appears once there are components.
3. Parts separate. The assembled translation is remembered on each instance.
4. Click **Explode** again to collapse.

## What “good” looks like

- The toggle reflects `is_exploded()`.
- Collapse returns every instance to the millimetre it started from.
- The exploded flag survives Save / Open (`.sxp`).

Film: `explode_gearbox`. Kernel: `[explode]`.
