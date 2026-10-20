# Rung 8 result — cheap sweep on this branch

**Does not pass the bar.** No `tools/confirm_all.sh`: two cheap-red suites remain, so walks were not re-run from row 1. Tree `ff7a23a` (OCCT 8.0.1, Godot 4.7-stable). Findings: [`rung-08-failing.md`](rung-08-failing.md).

Last full confirm (`b787e32`, `build/confirm-wp11`) is stale for the 15 suites that went green on this sweep. Counts below mix that confirm (walks / check_rung08) with this tree’s cheap recheck (headless remaining).

| Bar | Count |
|---|---|
| Head sha | `ff7a23a` |
| Headless cheap recheck of the old 17 | **15 pass, 2 failed** (`replan20_glyphs`, `replan20_jaw` J6) |
| Headless full 262 | **not re-run** (want 0 failed) |
| Rung 1–6 / 8 walks | last confirm: each walk’s only FAIL was A15-class headless; **not re-run** |
| Rung 7 walk | last confirm 35/46, `check_rung07` **3/8**; film/boss on this tree now bbox 281.450×54.591×10 and **8/8** — walk **not re-run** |
| `check_rung05` | last confirm **10/10** |
| `check_rung06` | last confirm **7/7** |
| `check_rung07` film/boss cheap | **8/8** (want 8/8); walk-7 confirm still 3/8 until re-walked |
| `check_rung08 pin` | last confirm **3/3** |
| `check_rung08 pipes` | last confirm **5/5** |
| `check_rung08 bolted` | last confirm **7/7** |
| `check_rung08` final | last confirm **10/10** |
| Lint | last confirm `lint_suites` 266 ok; not re-run this sweep |
| Critique | **9/10** (walk 8 product on last confirm; overall bar still red) |

## Critique — 9/10 (walk 8 product; overall bar still red)

Judged against UBC ELEC391 Ex 4 stills in `docs/loop/rung-08-frames/`. Named tools in the PDF’s order landed on the last confirm walk: File → **New Assembly** mmgs ([page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png)); Insert Components nut / pipe / wrench ([fig-021-002.png](rung-08-frames/img/fig-021-002.png), [fig-021-003.png](rung-08-frames/img/fig-021-003.png)); Float ([fig-021-004.png](rung-08-frames/img/fig-021-004.png)); Insert → **New Part** + origin **Front** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)); pin R10 / 35 / 55 / R5, revolve 360° barbell ([fig-022-006.png](rung-08-frames/img/fig-022-006.png), [fig-022-007.png](rung-08-frames/img/fig-022-007.png)); instance copy to **2 / 16 / 8 / 1** ([fig-022-008.png](rung-08-frames/img/fig-022-008.png)); Fix one pipe ([fig-023-009.png](rung-08-frames/img/fig-023-009.png)); Concentric inner pipes + Coincident centre flanges, joint Z=260 bbox 225×225×1040 ([fig-023-010.png](rung-08-frames/img/fig-023-010.png), [fig-024-011.png](rung-08-frames/img/fig-024-011.png)); ×8 concentric+coincident at the joint, first hole +Y, pin head −Z at 287.5 ([fig-024-012.png](rung-08-frames/img/fig-024-012.png), [fig-025-013.png](rung-08-frames/img/fig-025-013.png)); wrench Coincident flange Z=250, jaw Coincident AF-20, **Tangent** curve, handle +X ([fig-025-015.png](rung-08-frames/img/fig-025-015.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png), [fig-025-016.png](rung-08-frames/img/fig-025-016.png)). `check_rung08.py final` 10/10. Caps at 8 not used.

Findings that keep it off 10:

1. **Headless 2** on this tree — `replan20_glyphs` / `replan20_jaw` J6 Power Trim: `_trim_open_jaw` returns false, kernel `"Trimmed"`, J6 bbox 189.8×20×10.
2. **Walks not re-confirmed** from row 1 after the handle/cut/fuse fixes. Last confirm walk 7 was 35/46 / checker 3/8; film+boss cheap are now 8/8 with bbox 281.450×54.591×10.
3. **Lock / HLR** — PDF optional Lock mate and Hidden Lines Removed stay out of scope (plan decision 13; VS #12).

Not used as stand-ins: File → New (part) as the assembly; ground-body revolve + Place as the pin; Pattern around joint as the ×8 path; Fastened as the wrench curve; overall-50 pin; outer-flange joint; origin-stacked 3MF; skip bolt-hole Concentric.

## WPs

Shipped WP-L1…L12, WP-S1/S2, WP1–WP10, WP-V0…V8, then walk-row fixes and WP11 `SX_WALK_JOBS=1`. None reverted wholesale. Product follow-ups on this branch: honest fuse/cut, loft ThruSections fallback, sweep max-volume transition, interior-sliver skip, Distance spin pin, disjoint-fuse multibody. Featured films not re-shot.
