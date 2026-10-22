# Rung 8 failing — confirm-r8 (round 8)

Test-and-fix on `cursor/rung-08-20261019` head `e7d8d814` (product `fed0a886`). Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

One-clean `SX_JOBS=1 SX_WALK_JOBS=1 tools/confirm_all.sh` from row 1 finished 2026-10-22T22:52:29Z at `build/confirm-r8`. Isolated film **12/0**. wrench-t14 **18/22** stays DIAG (T=14). Sibling confirm-hex **262/4** / walk7 **42/46** at 22:12Z.

## Remaining (3 tries, do not loosen bands)

### Walk 7 A26 / A34 / N4 volume — one R30 crotch

Hex is in-sketch (t0181–t0235). A14 `seal_box_end_hexes`, A23 recovery unused, ring **275.2**, boss **5/5** bbox **281.450**. Isolated film: neck **42841**, final **38954–38967**, in 0.5% of 42733 / 38782.

Walk from row 1 (`--a15`, no restore):

| try | HEAD | A26 neck | A34 final | notes |
|---|---|---|---|---|
| 1 | `645a18f5` | bbox 251.8 (no ring) | 35609 | A21 bbox-keep extruded a 1390 C-COM island; Fuse dropped xmax 256.5→226.876 |
| 2 | `3b23ccd3` | **42374** vs 42733 | **38531** vs 38782 | ring kept; R30 dv≈548 (replica T-junction) + R20 170 |
| 3 | `fed0a886` | **42370** vs 42733 | **38528** vs 38782 | west-cap drop + map_neck_xy 12 mm; still one crotch. A32 R1 no longer runner-gap |
| confirm-r8 | same product | **42370** | **38528** | A21 C **1495.7** ring **275.2**; A37 floor |

Band: 42733×0.005 → [42519, 42947]; 38782×0.005 → [38588, 38976]. Neck is 149 below the floor (half of V_30). Kernel C+ellipse R30 dv=**971**; replica with west chord dv=**542**. Walk handle contour is still 202.9×20 (west chord). Film nest west follows the 17° ellipse (t0285 / t0315). Do not loosen.

42 PASS / 3 FAIL / 1 A37 flag. Boss **5/5**. Final **7/8** (volume only).

### Walk 3 fillet r=30 (N8 / A19 / A20 / A22 / N12)

confirm-r8 **40/46**. N8/A19: Fillet r=30 applied 9 edges (wanted refuse). A20 r=1.5 follow-on. A22 shell. N12 reopen. Neck-fillet rematch (`2bec1b6` / map_neck_xy 12 mm) leaked into rung-3. confirm-hex saw the same 40/46. Not 3-tried this round (side-effect of walk-7 R30). Checkers: r5 **4/14**, rounded **6/16**, final **15/29**.

### In-suite film_spanner 12/3 vs isolated 12/0 — recess, not C-pad

Unique-HOME `--path game` on `92de9b9`: **12/0**, n=3 C **1494.5** ring **275.2**, bbox **281.450**, `check_rung07` **8/8** vol **38958**.

In-confirm cloned `game/` (after hexkey; packaging symlink so manifest smoke does not re-run owned films): **12/3**. After handle trim **n=3** C **1495.8** ring **275.2** handle **3998.2**. R30 dv **972**, neck **42841**. Racetrack Blind Cut removed nothing (`sketch 6, sketch 7, fillet 8`; vol **42816**; recessBoth in). C-pad hold worked. `kernel_cut` (`d6285e72`) landed after that suite.

`rung07_boss` Fillet R30 `limit 26` at (22.944, 10); neck **41864** (4/5). Suite still uses leftover 12-point cut (reopen ring 855.3).

## Closed this round

- Hex punch in Sketch1; leftover-hex recovery unused. A21 ring 275.2. FEATURES sketch1…fillet10.
- Per-suite cloned `game/` (incl `.godot`) + unique HOME/XDG/TMPDIR/`MESA_SHADER_CACHE_DIR`; `packaging/` symlink so `_suite_owns` sees `film_*_tests.suite`. Isolated hexkey→spanner **8/0 + 12/0**.
- automation_bridge `var fid := graph_add_fillet` parse error.
- A21 C-COM bbox keep of a 1390 island (area-first keep).
- Walk 6 sweep **7/7** (no open 3MF). Walk 8 pin **3/3** pipes **5/5** bolted **7/7** final **10/10**. Walks 1–2/4–5 product-green. Kernel **483/0**. Lint **266**.

## Not this round

wrench-t14 **18/22 DIAG** (T=14). No PR. No fourth confirm_all.
