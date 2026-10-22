# Rung 8 failing — confirm-now

Test-and-fix on `cursor/rung-08-20261019` head `bf67c81` (product `e024beb`). Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

One-clean `confirm_all` from row 1 finished 2026-10-22T10:45:22Z at `build/confirm-now`. Third try this cycle. wrench-t14 **18/22** stays DIAG (T=14).

## Remaining

### film_spanner in-suite mouth unopened (godot 262/1)

Isolated dummy+clean-HOME on this binary: **12/0**, after handle trim n=3 C **1494.5** / **1495.8**, ring **275.2**, handle **3999.2**, bbox **281.450**, `check_rung07` **8/8**.

In-confirm `film_spanner` (suite after hexkey/lesson2/manifest): **4/2**. `C ellipse stayed closed after trim (n=1 #0 area=2159.8)`. Mouth never opened; no C pad, no body.

Different flake from the earlier after-hexkey **12/7** (n=2 C gone, bbox 233.56). This VM hexkey-then-spanner was **12/0**. Shared `game/.godot` or trim/solve nondeterminism. East-x and golden-from-A11 stay reverted.

### Walk 7 A9 R15 undersized

From row 1: **r=13.642**. Three-point arc variant ok, inner ends ok. A10 still opened the mouth. Circle-only C-head arm did not freeze A9 the way east-x (r=20.93, closed ellipse) did, but the 15 mm dim still did not stick. Downstream C area **1404.9** vs **1495.8**.

### Walk 7 A22 one-body / blocked boss

A21 PASS: C + ring present, n=6 (C **1404.9**, handle **3989.0**, ring **275.2**, plus 13.3 + two 4.8 islands). Midplane 10 mm, two pads, z ±5.

A22 FAIL `one body`: fuse reported, still a single `extrude 2` vol **16800.8**, bbox Y **54.64**. A23–A26 blocked (still in a sketch). No boss **5/5**, no neck, no final volume this run.

### Walk 6 sweep boolean + open 3MF

A27 `Sweep along path failed (sweep 6: boolean failed)`. A14/A28/A32–A34/N5 runner-gap: 3MF mesh open **627/183018** edges. L4/L5/A31 follow-on. New vs `c30e61a` / confirm-r7 (those were 46/46). Not a C-head change; do not chase as a fourth confirm.

### Walk 7 A26 / A34 / N4 volume (logged, not re-tried)

Round-4 volume retries reverted. Sweep at `e024beb` was A26 neck **42154** vs 42733 (4/5), A34 **38312** vs 38782. This confirm never reached those rows. Do not loosen bands.

## Closed / not remaining

Walks 1–5 product-green (only A15/A25/A26/A21/A25 godot-floor from film_spanner). Walk 8 **47/48** pin **3/3** pipes **5/5** bolted **7/7** final **10/10**. Walk 7 A10 mouth, A18 strip, A21 C-present. Kernel **482/0**. Lint **266**. Glyphs/J6 stay closed.

Golden-hold walk 7 (`238949b`) **26/36** and confirm-r7 walk 7 **26/46** (east-arm A9 freeze) are not remaining on `e024beb`.
