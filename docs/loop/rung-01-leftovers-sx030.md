# Leftovers after sx-030 (a2ff49b4 / replan-9 WP1–WP4)

Source: `/workspace/sx-030/CRITIQUE.md` — FAIL 8/10.

## Product (P0)

1. **Jaw Power Trim never reaches `Trimmed open jaw` in the GUI.** Handout path (hole Ø10, redrawn Ø45 head circle, Jaw center-three-point width 20, along-jaw centreline + offset perpendicular cutter, Trim) always reports `Trim failed`. Headless `run_rung01_wrench.gd` still gets `Trimmed open jaw`. Fix Trim so the human path matches headless, or refuse with a precise reason naming the blocking entity.
2. **Cut Up To Surface / Opposite face can leave an open shell with no refusal.** First A9 attempt Extruded with Face z 0.0 mm and no error; 3MF then failed with `3MF mesh is open (1036/2072 edges not shared twice)`. Refuse the cut (or roll it back) when the result would be non-manifold / open; never leave a silent open body.

## Product (P1 / P2)

3. **Esc while clearing a Jaw selection can discard the whole face sketch** with no warning (A8). Selection clear / tool drop should not delete the sketch.
4. **Extrude Op and End persist across File→New** (A10/A14 inherited Cut / Up To Surface). Reset finish defaults on New (or on empty document).
5. **A10 81% refuse** — refusal text exists but GUI still needs a clean Ø100+Ø90 walk; soft-GL radius drops made this round's attempt 82% on wrong sizes.

## Environmental / process (no BUILD unless newly GPU-repro)

6. Soft-GL: first-char drops in dim fields, lost first tool clicks, stale viewport, intermittent clipboard empty. Keep walker soft-GL protocol; no Mesa/driver WP.
7. Walker: recover from `blank.sxp` after a bad cut; do not File→New before wrench exports.

## Untested this round (blocked on A9)

A11 slot 2.5 + fillets, A12 wrench 28/28, A13 thick 4/4.

## Already green (do not re-break)

- Headless `run_rung01_wrench.gd` **399/0**; lint `3 replan9 scripts are clean`
- GUI A1–A8, A5b Discard, A14 nut **7/7**, blank **5/5**
- Replan-9 WP1 chip highlight, WP2 Smart Dim keep-pick, WP3 autosave dirty, WP4 walk asserts — all verified in GUI where applicable
- Main tip `a2ff49b4` (WP1–WP4 #103–#106)
