# Rung 8 failing — round 8

Test-and-fix on `cursor/rung-08-20261019`. Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

## Remaining (3 tries, do not loosen bands)

### Walk 7 A26 / A34 / N4 volume — one R30 crotch

Hex is in-sketch (t0181–t0235). A14 `seal_box_end_hexes`, A23 recovery unused, ring **275.2**, boss **5/5** bbox **281.450**. Film on this binary: neck **42841**, final **38954–38967**, in 0.5% of 42733 / 38782. Isolated hexkey→spanner **8/0 + 12/0**.

Walk from row 1 (no `--a15`, no restore):

| try | HEAD | A26 neck | A34 final | notes |
|---|---|---|---|---|
| 1 | `645a18f5` | bbox 251.8 (no ring) | 35609 | A21 bbox-keep extruded a 1390 C-COM island; Fuse dropped xmax 256.5→226.876 |
| 2 | `3b23ccd3` | **42374** vs 42733 | **38531** vs 38782 | ring kept; R30 dv≈548 (replica T-junction) + R20 170 |
| 3 | `fed0a886` | **42370** vs 42733 | **38528** vs 38782 | west-cap drop + map_neck_xy 12 mm; still one crotch. A32 R1 no longer runner-gap |

Band: 42733×0.005 → [42519, 42947]; 38782×0.005 → [38588, 38976]. Neck is 146 below the floor (half of V_30). Kernel C+ellipse R30 dv=**971**; replica with west chord dv=**542**. Walk handle contour is still 202.9×20 (west chord). Film nest west follows the 17° ellipse (t0285 / t0315). Do not loosen.

42 PASS / 3 FAIL / 1 A37 flag (diagnostic had no `--a15`). Boss **5/5**. Final **7/8** (volume only).

## Closed this round

- Hex punch in Sketch1; leftover-hex recovery unused. A21 ring 275.2. FEATURES sketch1…fillet10.
- film_spanner after film_hexkey: per-suite cloned `game/` (incl `.godot`) + unique HOME/XDG/TMPDIR/`MESA_SHADER_CACHE_DIR`. Product C-pad hold. **8/0 + 12/0**.
- automation_bridge `var fid := graph_add_fillet` parse error (walks never bound the port).
- A21 C-COM bbox keep of a 1390 island.

## Not this round

Walk 6 sweep / open 3MF and wrench-t14 **18/22 DIAG** (T=14) are unchanged. No PR.
