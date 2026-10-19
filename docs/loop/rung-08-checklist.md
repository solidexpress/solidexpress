# Rung 8 checklist — pipeline assembly (UBC ELEC391 Exercise 4)

Row list for `tools/walk_rung08.py`. How to build each row: [`rung-08-plan.md`](rung-08-plan.md). Numbers come from `check_rung08.py params` after WP1 (`V_PIN 6938`, pin bbox `20 × 55 × 20`, pipes `225 × 225 × 1040`, final `322.5 × 229.0 × 1040`, min `(−112.5, −112.5, −260)`). Until WP1’s OCCT replica, pin volume ± **1 %**; then 0.5 %. Bbox edges ± 0.2 mm (wrench XY ± 0.5 mm).

**A** action (the tutorial step, named tool). **L** look. **N** negative. Clauses are bridge reads or one checker line. Statuses are `[status-trace]` result lines since the row's mark.

**Frames are mandatory.** Every view, plane, dimension, mate selection, click target and expected on-screen state cites a still in `docs/loop/rung-08-frames/` that was opened for this checklist. Where figures and text disagree, follow the figures (notes in the row). Prep put overall pin **50** (R5 as tail radius); the stills put **55** with both ends R10 and R5 = shank radius — frames win.

Mutants (overall-50 pin, outer-flange joint, Pattern around joint as the ×8 path, Fastened as the wrench curve, origin-stacked 3MF, File → New part as the assembly) are checker mutations, not walk rows.

Reused parts (`nut.sxp`, `pipe.sxp`, `wrench.sxp`) are kernel fixtures from WP2, written into the walk out-dir before A2. Insert of those files is the named click. Do not re-walk rungs 1 or 5 here.

Exactness / spline WPs (WP-L1…L12, WP-S1, WP-S2) are **not walk rows**. Their acceptance is the table at the end of this file. They are not gated on this walk. Rung 7 A28 must still pass after WP-S1 and WP-L6.

## Chunk 1 — New Assembly, insert, float (9)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| N1 | Window first: size ≥ 1272 × 750 or maximized; status bar, File menu, and the rail inside the window | Chrome inside the window | — | `window`; `chrome inside` |
| A1 | File → **New Assembly** (not File → New). Status is an empty-assembly sentence, not the pinned part sentence. `state.units` is `mmgs`. Kind is assembly. Empty of bodies. Origin planes Front / Top / Right exist as datums. No IPS dialog | Empty assembly shop. Origin planes exist | [page-20.jpg](rung-08-frames/page-20.jpg) step 1; [fig-020-001.png](rung-08-frames/img/fig-020-001.png) Assembly icon boxed on the Tutorial tab | `new assembly`; `units mmgs`; `kind assembly`; `no bodies`; `planes` |
| L1 | File shows New and New Assembly as distinct. Insert shows Components… and **New Part**. Assembly panel hidden or empty. Plane names Front, Top, Right visible | Same rail density as rungs 4–7, plus assembly chrome | [fig-020-001.png](rung-08-frames/img/fig-020-001.png); [fig-022-005.png](rung-08-frames/img/fig-022-005.png) Insert Components dropdown with New Part | `new assembly item`; `insert components`; `insert new part`; `plane names` |
| A2 | Insert → Components… Browse, pick **`nut.sxp`**. Drop with a left click. One hex-nut instance. Source body hidden | Nut instance in the viewport. Assembly panel lists it | [page-21.jpg](rung-08-frames/page-21.jpg) step 2; [fig-021-002.png](rung-08-frames/img/fig-021-002.png) Browse; [fig-021-003.png](rung-08-frames/img/fig-021-003.png) HEX NUT | `inserted nut`; `instance 1`; `source hidden` |
| A3 | Insert → Components… pick **`pipe.sxp`**. Drop. One pipe-section instance | Pipe instance. Two instances in the list | [fig-021-003.png](rung-08-frames/img/fig-021-003.png) PIPE SECTION | `inserted pipe`; `instance 2` |
| A4 | Insert → Components… pick **`wrench.sxp`**. Drop. One wrench instance. Multi-file Open of all three in one dialog is allowed and counts as A2–A4 | Three instances: nut, pipe, wrench | [fig-021-003.png](rung-08-frames/img/fig-021-003.png) WRENCH | `inserted wrench`; `instance 3`; `pipes 1`; `nuts 1`; `pins 0`; `wrench 1` |
| L2 | Three components visible, dropped anywhere, not yet mated. Sources hidden. First-inserted instance may show `(f)` | Same as the lesson still before copies | [page-21.jpg](rung-08-frames/page-21.jpg) step 3; [fig-021-003.png](rung-08-frames/img/fig-021-003.png) | `three visible`; `sources hidden`; `not mated` |
| A5 | If any instance is `(f)`, right-click / AssemblyPanel **Float**. Drag each of the three: they move. No instance remains Fixed | All three free. No `(f)` | [fig-021-004.png](rung-08-frames/img/fig-021-004.png) `(f) HEX NUT`, Float boxed | `floated`; `all free`; `drag ok` |
| N2 | Fix one instance, drag it: refused, transform unchanged, still Fixed. Then Float it again so the chunk ends free | Refuse status; instance stuck while Fixed | [fig-021-004.png](rung-08-frames/img/fig-021-004.png) `(f)` means cannot move | `refused`; `still fixed`; `then floated` |

## Chunk 2 — In-context pin (7)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| A6 | Insert Components dropdown → **New Part**. Edit Component is on. Not the 20×20 in-context pad | New empty component. Edit Component banner/toggle on | [page-22.jpg](rung-08-frames/page-22.jpg) step 4; [fig-022-005.png](rung-08-frames/img/fig-022-005.png) New Part boxed | `new part`; `edit component on`; `not incontext pad` |
| A7 | Pick origin **Front** (the assembly principle plane, not Top, not a body face). Sketch. Session is the new-part Front: origin on the pin, normal `+Z`, `x = +X`, `y = +Y` | 2D Front sheet on the new part | [fig-022-005.png](rung-08-frames/img/fig-022-005.png) Front / Top / Right boxed; Front is the walk pick | `datum Front`; `sketch`; `edit component`; `basis` |
| A8 | Sketch the pin outline: vertical **centerline** (revolve axis, sketch +Y); R10 head semicircle, centre on the axis; shank at **R5** from the axis, length **35**; tail R10 semicircle; overall **55**. Entity types are line/arc, not a polyline stand-in. Origin at the tail pole | Profile matches the lesson still. Labels R10 / 35 / 55 / R5 | [fig-022-006.png](rung-08-frames/img/fig-022-006.png) R10, 35, 55, R5; [page-22.jpg](rung-08-frames/page-22.jpg) the same figure | `centerline`; `r10 head`; `shank 35`; `r5 shank`; `overall 55`; `r10 tail` |
| A9 | Revolved Boss/Base **360°** about the centerline. One solid. Bbox 20 × 55 × 20 in the pin part (Y along the axis) | Barbell pin, both ends mushroomed with flat equatorial collars | [fig-022-007.png](rung-08-frames/img/fig-022-007.png); [page-22.jpg](rung-08-frames/page-22.jpg) revolved result | `revolve 360`; `one solid`; `bbox 20 55 20` |
| A10 | Unselect **Edit Component**. Pin is a component instance, not a ground-only body | Edit Component off. Pin listed with the other instances | [page-22.jpg](rung-08-frames/page-22.jpg) “unselect Edit Component to finalize” | `edit component off`; `pin instance` |
| A11 | Export `pin.3mf`. `check_rung08.py pin` PASS: bbox 20 × 55 × 20, min `(−10, 0, −10)`, volume `V_PIN` 6938 within the band, watertight 1 body. Overall 50 fails this row. Save As `pin.sxp` | Pin only, no pipes | [fig-022-007.png](rung-08-frames/img/fig-022-007.png) | `exported`; `pin`; `bbox`; `volume`; `watertight`; `saved` |
| L3 | Pin reads as the lesson still: R10 head, Ø10 shank, R10 tail, overall 55. One of each part now in the assembly (nut, pipe, wrench, pin) | Same as [fig-022-007.png](rung-08-frames/img/fig-022-007.png) plus the three inserts | [fig-022-007.png](rung-08-frames/img/fig-022-007.png); [page-22.jpg](rung-08-frames/page-22.jpg) after step 4 | `pin visible`; `counts 1 1 1 1` |

## Chunk 3 — Copies and Fix (5)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| A12 | Box-select the **pipe** instance until it highlights, Ctrl+C, Ctrl+V. Two pipe instances. Not Pattern around joint, not a body paste | Two pipes, offset from each other, both unfixed | [page-22.jpg](rung-08-frames/page-22.jpg) step 5; [fig-022-008.png](rung-08-frames/img/fig-022-008.png) two pipes | `copy pipe`; `pipes 2`; `instance copy` |
| A13 | Box-select a **nut**, Ctrl+C / Ctrl+V until **16** hex nuts | Sixteen nuts | [fig-022-008.png](rung-08-frames/img/fig-022-008.png) nut cluster; [page-22.jpg](rung-08-frames/page-22.jpg) “16 hex nuts” | `copy nuts`; `nuts 16` |
| A14 | Box-select a **pin**, Ctrl+C / Ctrl+V until **8** pins. Wrench stays 1 | Eight pins, one wrench | [fig-022-008.png](rung-08-frames/img/fig-022-008.png) eight barbell pins, one wrench | `copy pins`; `pins 8`; `wrench 1` |
| L4 | Counts **2** pipes, **16** nuts, **8** pins, **1** wrench. Loose, not yet mated, like the exploded still | Same as the lesson still | [fig-022-008.png](rung-08-frames/img/fig-022-008.png); [page-22.jpg](rung-08-frames/page-22.jpg) step 5 | `counts 2 16 8 1`; `not mated` |
| A15 | Right-click / AssemblyPanel **Fix** on one **PIPE SECTION**. That instance shows `(f)` and refuses drag. The other pipe still floats | One pipe Fixed | [page-23.jpg](rung-08-frames/page-23.jpg) step 6; [fig-023-009.png](rung-08-frames/img/fig-023-009.png) PIPE SECTION\<1\>, Fix boxed | `fix pipe`; `one fixed`; `other free` |

## Chunk 4 — Pipe mates (6)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| N3 | Mate (Concentric) with **one** face then Ok / empty second pick: refused, no mate added, poses unchanged | Refuse status | — (Mate armed at [fig-023-010.png](rung-08-frames/img/fig-023-010.png)) | `refused`; `no mate`; `poses unchanged` |
| A16 | Assembly **Mate**. Pick both **inside** cylindrical faces of the two pipe instances (not the hidden sources). Standard mate **Concentric**, offset **0**, Lock Rotation off. Ok | Pipes share an axis. Unfixed pipe still slides and rotates on that axis | [page-23.jpg](rung-08-frames/page-23.jpg) step 7; [fig-023-010.png](rung-08-frames/img/fig-023-010.png) Mate (1), faces (2)(3), Concentric boxed, Lock Rotation off, green check (4) | `concentric pipes`; `offset 0`; `instance instance`; `lock rotation off` |
| L5 | Drag the unfixed pipe: it moves **along one axis** and rotates about that axis only. The fixed pipe stays | Same as the note under step 7 | [page-24.jpg](rung-08-frames/page-24.jpg) paragraph before step 8; [fig-023-010.png](rung-08-frames/img/fig-023-010.png) | `slides on axis`; `fixed stays` |
| A17 | Mate the two **base / flange** faces (pipe-1 +Z flange **outer** to pipe-2 −Z flange **outer**). Coincident, offset 0. Centre joint at `Z = 260`. Not the empty outer flanges at the far ends | Flange-to-flange. Axial slide gone | [page-24.jpg](rung-08-frames/page-24.jpg) step 8; [fig-024-011.png](rung-08-frames/img/fig-024-011.png) two full pipes joined at one flange pair | `coincident flanges`; `joint z 260`; `centre joint` |
| A18 | Mate **Concentric** on one bolt hole of each pipe (Ø10 cylinders). First hole is the rung-5 **+Y** hole. Pipes fully fixed; no remaining DOF on the unfixed pipe | Holes line up. Drag of the second pipe is refused | [page-24.jpg](rung-08-frames/page-24.jpg) step 8 “mate two of the bolt holes … concentric” | `concentric holes`; `plus y`; `pipes fixed` |
| A19 | Export `pipes.3mf` (instances at transforms). `check_rung08.py pipes` PASS: counts 2 pipes, bbox 225 × 225 × 1040, min `(−112.5, −112.5, −260)`, axes coaxial +Z, joint at Z = 260. Save `pipes.sxp` | Two pipes, centre joint, outers empty. Nuts/pins still loose | [fig-024-011.png](rung-08-frames/img/fig-024-011.png) | `exported`; `pipes`; `bbox`; `coaxial`; `saved` |

## Chunk 5 — Nut/pin ×8 (7)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| A20 | First **pin**: Mate **Concentric**, pin **shank** cylinder to the +Y bolt-hole cylinder of the fixed pipe (offset 0) | Pin axis through `(0, 94)`, still free to slide | [page-24.jpg](rung-08-frames/page-24.jpg) step 9; [fig-024-012.png](rung-08-frames/img/fig-024-012.png) pin through a bore | `pin concentric`; `plus y`; `offset 0` |
| A21 | First **nut**: Concentric nut bore to the same hole; Coincident nut face to pipe-1 flange **back** `Z = 250`. Both mates hold (either order) | Nut seated on the −Z side of the joint, AF 20, bore on the pin | [fig-024-012.png](rung-08-frames/img/fig-024-012.png) hex under the near hemisphere | `nut concentric`; `nut coincident z250`; `solver holds` |
| A22 | Second **nut**: Concentric to the same hole; Coincident to pipe-2 flange back `Z = 270` | Nut on the +Z side of the joint | [fig-024-012.png](rung-08-frames/img/fig-024-012.png) far-side hex + hemisphere | `nut2 coincident z270` |
| A23 | Pin **Coincident**: head equatorial collar (planar annulus) to the first nut’s **outer** face. Head toward −Z. Tail collar sits on the second nut. Overall 55 through the 35 mm grip | One bore done: two nuts, one pin, hemispheres proud of both nuts | [fig-024-012.png](rung-08-frames/img/fig-024-012.png); [fig-025-014.png](rung-08-frames/img/fig-025-014.png) Ø20 head on AF-20 hex | `pin seated`; `head minus z`; `grip 35` |
| L6 | One bore reads as the lesson still. Other 7 holes empty of nuts/pins | Same as [fig-024-012.png](rung-08-frames/img/fig-024-012.png) | [fig-024-012.png](rung-08-frames/img/fig-024-012.png) | `one bore`; `seven empty` |
| A24 | Repeat A20–A23 on the remaining **seven** bores with the named mates (not Pattern around joint, not a bulk script that skips Mate). 8 pins, 16 nuts, all at the centre joint | All 8 bores filled. Outer flanges empty | [page-25.jpg](rung-08-frames/page-25.jpg) step 10; [fig-025-013.png](rung-08-frames/img/fig-025-013.png) eight nuts around the joint | `repeat 8`; `pins 8`; `nuts 16`; `centre only` |
| A25 | Export `bolted.3mf`. `check_rung08.py bolted` PASS: counts 2/16/8, 8 pin axes on PCD 94, nuts at Z=250 and 270, volume `V_BOLTED` 5496311 within the band. Save `bolted.sxp`. Optional Lock **not** clicked | Joint like the lesson still, wrench still loose | [fig-025-013.png](rung-08-frames/img/fig-025-013.png) | `exported`; `bolted`; `holes`; `nuts`; `volume`; `saved` |

## Chunk 6 — Wrench, save, evidence (14)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| A26 | Mate **Coincident**: wrench **bottom** face → pipe-1 flange back (`Z = 250`, cyan in the still). Wrench lies on the flange | Wrench on the joint flange, still free in-plane | [page-25.jpg](rung-08-frames/page-25.jpg) step 11; [fig-025-015.png](rung-08-frames/img/fig-025-015.png) cyan flange, wrench to the right | `wrench coincident flange`; `z 250` |
| A27 | Mate **Coincident**: wrench **top inside jaw flat** → one flat of the **+Y** nut. Jaw opening 20.0 vs nut AF 20.0, zero gap | Jaw against the nut. Handle still free to spin in-plane until A28 | [fig-025-014.png](rung-08-frames/img/fig-025-014.png) cyan jaw inner + cyan nut side; [page-25.jpg](rung-08-frames/page-25.jpg) “top inside surface … one of the sides on the nut” | `jaw coincident`; `plus y nut`; `gap 20` |
| A28 | Mate **Tangent**: **bottom curve** of the wrench head (cylindrical outer) → the corresponding nut side. Handle toward **+X**. Not Fastened, not a second coincident of the opposite jaw | Wrench fully mated to the nut. Handle along +X in the flange plane | [fig-025-016.png](rung-08-frames/img/fig-025-016.png) cyan curve + cyan nut flat; [page-25.jpg](rung-08-frames/page-25.jpg) “bottom curve of the wrench head” | `tangent curve`; `handle plus x`; `not fastened` |
| A29 | Export `assembly.3mf` of **instances at transforms** (hidden sources omitted). `check_rung08.py final`: `bbox` PASS. Min `(−112.5, −112.5, −260)`, max `(210.0, 116.5, 780)`, size `322.5 × 229.0 × 1040`, each edge within tolerance. Counts 2/16/8/1 | Finished pipeline, wrench on the +Y nut | [fig-020-000.png](rung-08-frames/img/fig-020-000.png); [fig-025-013.png](rung-08-frames/img/fig-025-013.png) | `exported`; `bbox`; `counts`; `instances transformed` |
| A30 | Same file: `volume` PASS, `V_bolted + V_WRENCH` within the band (`params` after WP2 fills `V_WRENCH`) | — | — | `volume` |
| A31 | Same file: `inside` PASS at `(70, 0, 125)`, `(70, 0, 520)`, `(0, 94, 260)`, `(0, 102, 246.25)`; `outside` PASS at `(0, 0, 125)`, `(113, 0, 0)`, `(0, 0, −261)`, `(0, 0, 781)`; `coaxial` PASS; `holes` PASS; `nuts` PASS; `wrenchMates` PASS | Pin fills the +Y hole; pipe bore empty; wrench seated | [fig-020-000.png](rung-08-frames/img/fig-020-000.png); [fig-025-014.png](rung-08-frames/img/fig-025-014.png) | `inside`; `outside`; `coaxial`; `holes`; `wrench mates` |
| L7 | Instance list: 2 pipes (one `(f)`), 16 nuts, 8 pins, 1 wrench. Mates include pipe concentric + coincident + hole concentric, per-bore nut/pin mates, three wrench mates. No Lock. Outer flanges empty | — | [fig-023-009.png](rung-08-frames/img/fig-023-009.png) tree shape; [fig-020-000.png](rung-08-frames/img/fig-020-000.png) look | `order`; `one fixed pipe`; `no lock`; `outers empty` |
| A32 | Save As `assembly.sxp`. File exists. Title shows `assembly`. Kind is assembly | — | — | `saved`; `file exists`; `title`; `kind assembly` |
| A33 | `check_rung08.py pipes` on the A19 checkpoint and `bolted` on the A25 checkpoint still PASS (wrench mates did not move the pipes or the ×8) | — | [fig-024-011.png](rung-08-frames/img/fig-024-011.png); [fig-025-013.png](rung-08-frames/img/fig-025-013.png) | `pipes`; `bolted` |
| A34 | Save As `final.sxp`. File exists. Title shows `final` | — | — | `saved`; `file exists`; `title` |
| N4 | File → New Assembly, File → Open `assembly.sxp`. Kind assembly, counts 2/16/8/1, no status error. Re-export: `bbox` and `volume` PASS again | — | — | `reopened`; `kind assembly`; `counts`; `no error`; `bbox`; `volume` |
| A35 | `check_rung08.py final` on the re-export still PASS (same probes as A29–A31) | — | [fig-020-000.png](rung-08-frames/img/fig-020-000.png) | `final`; `bbox`; `volume`; `counts` |
| A36 | `check_rung01.py nut` / `wrench` and `check_rung05.py final` on the WP2 fixture 3MFs still PASS (reused parts did not drift) | — | — | `nut`; `wrench`; `pipe` |
| A37 | Headless evidence, needs `--a15` (without it: `BLOCKED-by-flag`). Kernel, godot suites `0 failed`, lint, `test_check_rung08.py`, registry. Engine noise only as rung 1 R9 allows | — | — | `kernel`; `godot`; `lint`; `unit`; `registry`; `errors` |

Total: 9 + 7 + 5 + 6 + 7 + 14 = **48** (37 A, 7 L, 4 N).

Pass bar: `PASS 48`, no `FAIL`, `PARTIAL`, `BLOCKED`, or `runner-gap`. Every `check-*.txt` has no `FAIL`. The walk's `[ERROR]` list is empty apart from rung 1 R9 engine noise and the refusals in N2 and N3.

Optional Lock ([page-25.jpg](rung-08-frames/page-25.jpg) step 10) is not a row.

## `check_rung08.py` spec

CLI like `check_rung07.py`: `params` | `pin` | `pipes` | `bolted` | `final` plus optional probe names. Exit 0 iff every named probe PASSes. `params` prints `PART` / `VOLUMES` as JSON; the walk reads those, not this file, after WP1.

`pin` takes a part 3MF. `pipes` / `bolted` / `final` take an **assembly** 3MF of instances at transforms (WP9) or the JSON dump WP1 names. A merged-at-identity 3MF of hidden sources must fail `bbox`.

| Stage | Bbox min | Size | Volume | Counts (pipe/nut/pin/wrench) |
|---|---|---|---|---|
| `pin` | `(−10, 0, −10)` | 20 × 55 × 20 | **6938** | — (1 body) |
| `pipes` | `(−112.5, −112.5, −260)` | 225 × 225 × 1040 | 2 × 2704332.648 | 2 / — / — / — |
| `bolted` | same XY, Z 1040 | 225 × 225 × 1040 | **5496311** | 2 / 16 / 8 / — |
| `final` | `(−112.5, −112.5, −260)` | **322.5 × 229.0 × 1040** | `V_BOLTED + V_WRENCH` | 2 / 16 / 8 / 1 |

`final` max `(210.0, 116.5, 780)` (wrench on the +Y nut, handle +X).

Probes: `bbox` (edges ± 0.2 mm; wrench XY ± 0.5), `volume` (1 % until WP1 OCCT replica on `pin`, then 0.5 %; `final` once `V_WRENCH` is set in WP2), `watertight` (`pin` only), `counts`, `coaxial`, `joint`, `holes` (PCD 94, first +Y, radial error ≤ 0.2), `nuts` (faces at Z=250 and 270 ± 0.2), `wrenchMates` (flange / jaw / tangent), `inside` / `outside` (points in the plan).

`PART` millimetres (locked from frames): pin R10 / Ø10×35 / R10, overall **55**; nut AF 20 / T 7.5 / bore Ø10; pipe as `check_rung05.py`; wrench 232.5 × 45 × 10, jaw 20; PCD 94, 8 holes; `PIPE_DZ` 520; joint Z 260.

Mutations that must fail: pin Y 50 as `pin` (`bbox`); outer-flange joint as `pipes` (`bbox` Z 520); counts 1/8/4/1 as `bolted` (`counts`); wrench jaw 25 as `final` (`wrenchMates`); origin-stacked sources as `final` (`bbox`); two bodies as `pin` (`watertight`).

## Exactness / spline WPs (not walk rows)

Andy, 2026-10-19. **Not gated** on `walk_rung08.py`. Headless only. **WP-L1 first.** “Exact” = `BRepAdaptor_Curve::GetType`, radii/centres 1e-6 mm, `BRepGProp` 1e-6 rel, round-trip bit-equal or 1e-12. Mesh `check_rung*.py` (0.2 mm / 0.5 %) does not count. Rungs 1–7 walks stay 77/44/46/32/36/46/46. Unconfirmed cases: the WP’s **first** Catch2/GUT is a probe that confirms the cited bug (records the error size); green probe → drop that claim in the commit.

WP-S1 and WP-L6 are complementary: S1 is BSpline/Bezier Convert (rung-07 finding 1); L6 is ellipse / tilted / associativity / pierce. WP-L7 before WP-S2.

| WP | Size | Cases | Acceptance (headless) | Cheap check |
|---|---|---|---|---|
| **L1** | S | 23 | Box + Ø10 hole: one `GeomAbs_Circle` r = 5 ± 1e-6; volume analytic ± 1e-9 rel; CLI/GUT reads the same | Catch2 + C-py CLI |
| **L2** | L | 1, 11, 20, 24 | (a) line+R150+R20 spine Line/Circle, R150/R20 ± 1e-6, swept torus major 150 ± 1e-6; (b) spline spine `GeomAbs_BSplineCurve`, fit pts ± 1e-6; (c) ellipse spine `GeomAbs_Ellipse`; (d) rib on R20: cylinder R20±t/2, no bend lumps; (e) thread axial flank 60° ± 0.01°; (f) rung 6 walk + `check_rung06` still pass. **Probe first:** SweepFuse chorded-ribbon pick; thread error size | Catch2 WP-L1 probes; C-one rung-6 sweep |
| **L3** | L | 3 | Square–square loft, guide offset 5: guide on surface ± 1e-6 (`BRepExtrema_DistShapeShape`); no circular edges unless profiles are circles; guided volume ≠ unguided | Catch2 |
| **L4** | M | 2 | 40×10 rect, depth 10, 5°: every side 5° ± 1e-6 to extrude dir; Ø6 hole kept as drafted cone; rung 6 Ø30 15° cut volume ± 1e-6 rel, host-face diameter 30 ± 1e-6 | Catch2; C-one `rung06_draft` |
| **L5** | M | 6, 16, 17 | Touching boxes fuse, fuzz 0, volume = sum ± 1e-9 rel; 0.05 fuzz → warning text on the feature; chamfer-mirror: chamfer faces both sides, area ± 1e-6; no test accepts < 99.9999 % of expected volume | Catch2; C-one `rung05_mirror` |
| **S1** | M | r7 finding 1 | Convert in-plane BSpline → sketch Spline matching the edge ± 1e-6; Line/Arc stay Line/Arc; **rung 7 A28 still PASS** | Catch2; C-one `rung07_offset` |
| **L6** | M | 7, 10 | Convert filleted ellipse boss → sketch `ellipse`, radii ± 1e-6; regen after boss edit follows ± 1e-6; Ø45 pierce at 30° on true circle ± 1e-6; A28 still PASS. **Probe first:** `get_edge_lines` seam repeat / centroid bias | Catch2; C-one `rung07_offset` |
| **L7** | M | 8 | 5 zig-zag fit pts: kernel through each ± 1e-9; solver curve vs kernel ± 1e-6 at 100 params; overlay samples on kernel ± 1e-6; save/load fit pts bit-identical. **Before S2** | Catch2 |
| **S2** | L | — | Fit-point and pole handles; end tangent/magnitude; Tangent (and curvature if feasible) to lines/arcs on the L7 curve; optional comb; undo; property point count; save/load | Catch2 + C-one `rung08_spline_edit` |
| **L8** | M | 5, 12, 13, 21, 22 | Mirror arc about vertical and 30°: analytic ± 1e-9 + Symmetric; drag source, copy follows; offset circle Δr relation; 6-copy circular 60° ± 1e-9; thin line-arc-line has a cylinder; voice fix → Fix. **Probe first:** mirror-arc `(−end,−start)` | Catch2; C-one `rung07_mirror` |
| **L9** | S | 4 | Typed 9.525, 12.34, 1.2, 1.25°, 2.54, 51.428571° each `== float(text)` in the kernel. **Probe first:** hidden `dim_value` 0.5-grid on Enter with a selection | C-one `rung08_typed_values` |
| **L10** | M | 14, 15 | `add_line(0.1, 1/3, 123.456789012, 7)` bit-identical `entity_info`; hole Ø6.6 stored 6.6; drag-cancel bit-identical; mirror normal (0, 0.7071067811865476, 0.7071067811865476) unchanged | Catch2 / GUT |
| **L11** | S | 18 | Weak/driving/driven/expression/Fix + every entity type: save→load and snapshot→restore JSON equality; unknown type is a named load error. **Probe:** `BRepTools::Write` digit count | Catch2 |
| **L12** | M | 9, 19 | Print tol default 0.01 mm / 0.1 rad (isolated mesh); Ø3 hole vertices within tol of the cylinder, sagitta ≤ tol; STL vs 3MF vertices ± 1e-9; 1234.5678 reads back; DXF Ø20 disc = one CIRCLE r=10; bulged LWPOLYLINE → lines+arcs ± 1e-9. Fine view 0.02 mm / 0.1 rad | Catch2; C-one rung-5/7 export |

Display-only (with L12): view tessellation today 0.2 mm / 0.35 rad (`tessellate.hpp`); a Ø3 hole draws as an 18-gon. Measure/picking already use the kernel.
