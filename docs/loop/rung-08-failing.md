# Rung 8 failing — confirm-hex

Test-and-fix on `cursor/rung-08-20261019` head `b1afa64` (product `fed0a88`). Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

One-clean `confirm_all` from row 1 finished 2026-10-22T22:12:07Z at `build/confirm-hex`. Isolated film **12/0**. wrench-t14 **18/22** stays DIAG (T=14).

## Remaining

### Walk 7 A26 / A34 / N4 volume — one R30 crotch

Hex is in-sketch. A21 ring **275.2**, C **1495.7**, A23 boss **5/5** bbox **281.450**. Isolated film on `92de9b9`: neck in band, final **38958**. Walk from row 1 at `fed0a88`:

| | A26 neck | A34 final |
|---|---|---|
| confirm-hex | **42370** vs 42733 (4/5) | **38528** vs 38782 |

Band: 42733×0.005 → [42519, 42947]; 38782×0.005 → [38588, 38976]. Neck is 149 below the floor (half of V_30). Three volume tries already logged; do not loosen.

### Walk 3 fillet r=30 (N8 / A19 / A20 / A22 / N12)

confirm-hex **40/46**. N8/A19: Fillet r=30 applied 9 edges (wanted the lesson set). A20 r=1.5 follow-on. A22 shell. N12 reopen. Sibling neck-fillet rematch (`2bec1b6` / skip over-limit) leaked into rung-3. confirm-r8 saw the same 40/46.

### In-suite film_spanner 12/5 vs isolated 12/0

Unique-HOME `--path game` on `92de9b9`: **12/0**, n=3 C **1494.5** ring **275.2**, bbox **281.450**, `check_rung07` **8/8** vol **38958**.

In-confirm cloned `game/` (after hexkey/lesson2/manifest): **12/5**. After handle trim **n=4** (handle 3998.2 + extra 2257.8 + C **1494.5** + ring **275.2**), R30 `limit 26` at (22.944, 10), features only 3, vol **41673**. Per-suite clone + unique HOME did not kill this flake.

### Godot floor (not product walks 1–2/4–6/8)

`film_manifest_smoke` timeout 900s. `replan16_suites` missing `packaging/ci/suites.d` in the clone (sibling `d1689f4` clones packaging; this confirm started before that). `rung07_boss` neck **41864** vs 42733 (same volume remaining).

## Closed this confirm

Walk 6 sweep **7/7** (no open 3MF). Walk 7 A9 R15, A18 strip, A21 C-present, A23 boss **5/5**. Walk 8 pin **3/3** pipes **5/5** bolted **7/7** final **10/10**. Walks 1–2/4–5 product-green. Kernel **483/0**. Lint **266**. Isolated film **12/0**. Glyphs/J6 stay closed.
