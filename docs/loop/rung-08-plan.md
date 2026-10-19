# Rung 8 plan — pipeline assembly (UBC ELEC391 Exercise 4)

**PLAN only, no product code.** One BUILD agent implements this in order, one commit per work package, on the branch it is given. Push that branch. Do not open a PR. Source: *SolidWorks & Tinkerine 3D Printing Tutorial — ELEC391*, UBC ECE Engineering Services, [same PDF as rungs 1 and 5](https://people.ece.ubc.ca/~eng-services/files/tutorials/SolidWorks%20&%203D%20Printing%20Tutorial-R1.pdf), pages 20–25. Everything from the PDF is in [`rung-08-prep.md`](rung-08-prep.md), the stills in [`rung-08-frames/`](rung-08-frames/), and below. Do not re-open the PDF. The row text is [`rung-08-checklist.md`](rung-08-checklist.md); do not restate it.

No visual-survey batch this rung.

Model: `rung-07-plan.md` package shape (goal, files, change, line delta, one cheap check, revert). Part / frame / walk like `rung-03-plan.md` and `rung-07-plan.md`. Same machinery (`tools/walk/` `Rung`, `automation-bridge.md`).

**Frames are mandatory evidence.** Every view, plane, dimension, mate selection, click target and expected on-screen state below cites a file in `docs/loop/rung-08-frames/` that was opened for this plan. Where figures and text disagree, **follow the figures** (called out in Decisions). Where frames and the prep disagree, **follow the frames** and say so.

## Where we are

Baseline: `main` `9a493ca` (rung 7 #280 + bump 0.1.6 #281 + post-rung-7 cleanup #282). This branch is cut from there. Seed `90e9f55` is prep and frames only. The prep grepped `3f2f32a` (rung 7 result + frames, before #281/#282). Cleanup #282 was layering (`WalkUI07` split, tables) + a parked spanner film — it did **not** close any assembly gap (re-grepped on this tree). Rung 1 walk 77/77. Rung 2 44/44. Rung 3 46/46. Rung 4 32/32. Rung 5 36/36. Rung 6 46/46. Rung 7 46/46. Headless 244/0 (`docs/loop/post-rung-07-result.md`). `tools/test_walk_registry.py` freezes those seven row lists.

Rung 8 goal: build the pipeline assembly with the **named tools in the PDF’s order**, by clicking, and end on an assembly that passes `tools/check_rung08.py` at every stage.

Pass bar (all of):

- Component counts **2** pipe sections, **16** hex nuts, **8** pins, **1** wrench ([fig-022-008.png](rung-08-frames/img/fig-022-008.png), [page-22.jpg](rung-08-frames/page-22.jpg) step 5).
- Pipes coaxial on world **+Z**, flange-to-flange at the centre joint, combined bbox **225 × 225 × 1040**, min `(−112.5, −112.5, −260)` ([fig-024-011.png](rung-08-frames/img/fig-024-011.png)).
- Each pin concentric with a bolt hole on PCD radius **94**, first hole **+Y**, seated through the centre joint. Two nuts per pin, coincident on the outer flange-back faces `Z = 250` and `Z = 270`.
- Wrench on a nut: bottom coincident to a flange back, inner jaw flat coincident to a nut flat, head **curve** tangent to the corresponding nut side ([fig-025-015.png](rung-08-frames/img/fig-025-015.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png), [fig-025-016.png](rung-08-frames/img/fig-025-016.png)).
- Pin (in-context revolve): bbox **20 × 55 × 20**, volume **6938** mm³ within **±1 %** until WP1’s OCCT replica; then **0.5 %** like rung 5. Prep’s overall **50** (R5 as tail radius) is a mutant — not a second target (see Pin length).
- With the wrench on the +Y nut, handle toward **+X**: assembly bbox **322.5 × 229.0 × 1040**, min `(−112.5, −112.5, −260)`, max `(210.0, 116.5, 780)`. The 225 Y of the pipes-only box is **not** the final Y (wrench head Ø45 on the r=94 nut overshoots the flange by 4 mm).
- Every checklist row PASS (no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`). Critique ≥ 9 (rule at the end).
- On the same build: rung 1 walk 77/77, rung 2 44/44, rung 3 46/46, rung 4 32/32, rung 5 36/36, rung 6 46/46, rung 7 46/46, `check_rung01/02/03/04/05/06/07/08.py` at their bars, headless `0 failed`.

Whole-plan acceptance is **WP11 only**. Earlier packages run the one cheap check they name. They do not run `make test`, `make test-godot`, `confirm_all.sh`, or a walk without `--dry-run`.

## Frame (decision, not a question)

Same axis map as rungs 3–5 for the reused pipe. Front = XY (normal +Z). Pipe extrude **+Z**. Finished pipe `Z ∈ [−260, +260]`. Assembly world keeps that map: pipe axis = world **+Z**, flange faces are Z-planes, bolt circle in XY. In-context pin is a Front (XY) revolve about a vertical (sketch-Y / world +Y) axis; after mates its axis is parallel to +Z through a bolt hole. Nut sketch is XY, thickness +Z. Wrench (rung 1) sits on a flange face (XY), jaw opening in that plane. Units MMGS.

| Item | Tutorial (frame) | SolidExpress |
|---|---|---|
| New document | **Assembly**, Tutorial tab, Assembly icon boxed ([page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png)) | File → **New Assembly**. File → New (part) is unchanged — rungs 1–7 pin “no second dialog”. |
| Units | MMGS before placing anything; template may be IPS ([page-20.jpg](rung-08-frames/page-20.jpg) step 1) | `state.units = mmgs` already. No IPS trap. Walk still reads `units mmgs`. |
| Insert | Browse → HEX NUT, PIPE SECTION, WRENCH together ([page-21.jpg](rung-08-frames/page-21.jpg), [fig-021-002.png](rung-08-frames/img/fig-021-002.png), [fig-021-003.png](rung-08-frames/img/fig-021-003.png)) | Insert → Components… of three `.sxp` (WP2 fixtures). Multi-file Open in WP3. |
| Drop / float | Left-click drop. Drag to confirm free. `(f)` → right-click **Float** ([page-21.jpg](rung-08-frames/page-21.jpg) step 3, [fig-021-004.png](rung-08-frames/img/fig-021-004.png)) | First insert is auto-Fixed (`insert_sxp` `fix_first`). AssemblyPanel Float. `(f)` prefix on the instance name. |
| In-context pin | Insert Components dropdown → **New Part**. Principle plane (Front / Top / Right boxed equally) ([page-22.jpg](rung-08-frames/page-22.jpg) step 4, [fig-022-005.png](rung-08-frames/img/fig-022-005.png)) | Insert → **New Part**. Pick **Front**. Edit Component on; unselect to finalize. |
| Pin profile | R10 head, 35 shank, overall **55**, R5 from the axis ([fig-022-006.png](rung-08-frames/img/fig-022-006.png)). Revolved 360°, both ends mushroom hemispheres with flat equatorial collars ([fig-022-007.png](rung-08-frames/img/fig-022-007.png)) | Front sketch, axis = vertical construction. Revolve 360°. See Pin length. |
| Copies | Box-select until blue, Ctrl+C / Ctrl+V. Counts **2 / 16 / 1 / 8** ([page-22.jpg](rung-08-frames/page-22.jpg) step 5, [fig-022-008.png](rung-08-frames/img/fig-022-008.png)) | Instance clipboard. Not body copy, not Pattern around joint. |
| Fix ground | Right-click one **PIPE SECTION** → **Fix** ([page-23.jpg](rung-08-frames/page-23.jpg) step 6, [fig-023-009.png](rung-08-frames/img/fig-023-009.png)) | AssemblyPanel lock / `set_instance_fixed`. HAVE. |
| Concentric (pipes) | Mate → both **inside** pipe surfaces. Standard Mate **Concentric** auto-selected. Lock Rotation **off** ([page-23.jpg](rung-08-frames/page-23.jpg) step 7, [fig-023-010.png](rung-08-frames/img/fig-023-010.png) faces 2 and 3, Mate tool 1, green check 4) | Mate, two instance cylindrical faces, Concentric, offset **0**. |
| Coincident (flanges) | Two **base / flange** faces → Coincident ([page-24.jpg](rung-08-frames/page-24.jpg) step 8, [fig-024-011.png](rung-08-frames/img/fig-024-011.png)) | `plane_coincident`, oppose-normals, offset 0. Centre joint, not the empty outer flanges. |
| Concentric (holes) | One bolt hole on each pipe, Concentric, kills remaining rotation ([page-24.jpg](rung-08-frames/page-24.jpg) step 8) | Concentric on two Ø10 hole cylinders. First hole +Y. |
| Nut/pin per bore | Two nuts + one pin per Ø10 hole: Concentric (axes) + Coincident (nut face to flange back). Repeat ×8 ([page-24.jpg](rung-08-frames/page-24.jpg) step 9, [fig-024-012.png](rung-08-frames/img/fig-024-012.png); [page-25.jpg](rung-08-frames/page-25.jpg) step 10, [fig-025-013.png](rung-08-frames/img/fig-025-013.png)) | Same two mate types on each instance. Pin: Concentric shank↔hole + Coincident head-collar↔nut outer. |
| Optional Lock | Standard Mates **Lock** (or Concentric “Lock rotation”) on nuts vs a pipe face. “Possible but not required” ([page-25.jpg](rung-08-frames/page-25.jpg) step 10; checkbox in [fig-023-010.png](rung-08-frames/img/fig-023-010.png)) | Out of scope. Nuts may spin. |
| Wrench, mate 1 | Bottom face of wrench → flange (“pipe section base”), Coincident ([page-25.jpg](rung-08-frames/page-25.jpg) step 11, [fig-025-015.png](rung-08-frames/img/fig-025-015.png) cyan flange) | `plane_coincident`. Walk: pipe-1 +Z flange **back** (`Z = 250`), +Y nut. |
| Wrench, mate 2 | Top **inside jaw flat** → one nut flat, Coincident ([fig-025-014.png](rung-08-frames/img/fig-025-014.png) cyan jaw + cyan nut side) | `plane_coincident`. Jaw 20.0 vs nut AF 20.0, zero gap. |
| Wrench, mate 3 | **Bottom curve** of the wrench head → corresponding nut side ([fig-025-016.png](rung-08-frames/img/fig-025-016.png) cyan cylindrical jaw underside + nut flat) | **Tangent** (cylinder to plane). Not Fastened. |
| Finished look | Two pipes flange-to-flange, 8 pins / 16 nuts at the **centre joint only**, wrench on one nut ([fig-020-000.png](rung-08-frames/img/fig-020-000.png), [fig-025-013.png](rung-08-frames/img/fig-025-013.png)) | Outer flanges empty. |

**Prep vs frames (pin).** Prep locked overall **50** (R10 hemi + Ø10×35 + R5 hemi) and treated the figure’s **55** as a leftover. Opened stills: [fig-022-006.png](rung-08-frames/img/fig-022-006.png) dimensions **55** as the overall; [fig-022-007.png](rung-08-frames/img/fig-022-007.png) is a barbell with **both** ends mushroomed (flat equatorial collar wider than the shank). Pixel measure of the blue profile on fig-022-006 (axis col 211, shank left 152 → 59 px = R5; head leftmost ~94 → ~117 px ≈ R10; tail leftmost ~86 → ~125 px ≈ R10; blue span 633 px / 55 mm = 11.5 px/mm). Tail height is ~10 mm, not 5. **R5 is the shank radius from the axis**, not the tail hemisphere. Both ends are R10 hemispheres. 10 + 35 + 10 = **55**. Prep’s 50 is the mutant.

**Spoken vs frames.** The page text never writes a shank Ø; [fig-022-006.png](rung-08-frames/img/fig-022-006.png) R5 from the axis plus the Ø10 nut/hole already locked in rungs 1 and 5 fix Ø10. “Select any of the principle planes” ([fig-022-005.png](rung-08-frames/img/fig-022-005.png) boxes all three); Front is the rung convention. Lock is optional in the text ([page-25.jpg](rung-08-frames/page-25.jpg) step 10) — not a row.

### Pin length (locked)

In-context sketch, Front, axis = vertical construction (sketch +Y / world +Y), origin at the **tail pole**. Head hemisphere R10 (equator at y = 45, pole at y = 55). Shank Ø10 × 35 (y = 10 … 45). Tail hemisphere R10 (pole at y = 0, equator at y = 10). Revolve 360°.

\[
V_\mathrm{head} = V_\mathrm{tail} = \tfrac{2}{3}\pi 10^3 = 2094.395,\quad
V_\mathrm{shank} = \pi 5^2 35 = 2748.894
\]

\[
V_\mathrm{pin} = 6937.684\ \mathrm{mm}^3
\]

| | min | max | size |
|---|---:|---:|---:|
| X | −10 | 10 | 20 |
| Y | 0 | 55 | 55 |
| Z | −10 | 10 | 20 |

Grip 35 mm = 2 × nut 7.5 + 2 × flange 10, exact. Head collar sits on one nut outer; tail collar on the other ([fig-024-012.png](rung-08-frames/img/fig-024-012.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png) Ø20 sphere on AF-20 hex, corners peek). After mates the pin axis is world +Z through a bolt hole. Head toward −Z (pipe 1): poles at `Z = 232.5` and `Z = 287.5`.

**Mutant `V_50`** (prep: R5 tail hemi, overall 50) = 5105.088, bbox Y 50. Not a target. Mutant extra 5 mm Ø10 shank to fake 55 without the tail shoulder = 5497.787. Mutant ball-end tail (R5 sphere, height 10) is rejected by [fig-022-007.png](rung-08-frames/img/fig-022-007.png)’s flat collar.

### Pass-bar numbers (recomputed)

Locked reused (already in those checkers; not re-litigated):

| Part | Locked | Checker |
|---|---|---|
| Nut | AF **20**, AC **23.094**, thickness **7.5**, bore **Ø10** | `check_rung01.py nut` |
| Wrench | jaw opening **20.0**, bbox **232.5 × 45 × 10**, head at **+X** | `check_rung01.py wrench` |
| Pipe | OD 150, ID 130, wall 10, L0 250, flange Ø225 × 10, 8× Ø10 on PCD radius **94**, first hole **+Y**, R5 flange fillets, bbox **225 × 225 × 520**, min `(−112.5, −112.5, −260)`, volume **2704332.648** mm³ | `check_rung05.py` `PART` |

**Nut volume** (analytic). Hex area \(200\sqrt{3} = 346.410\), bore \(25\pi = 78.540\):

\[
V_\mathrm{nut} = (346.410 - 78.540)\times 7.5 = 2009.028\ \mathrm{mm}^3
\]

**Pipes.** Two copies of the rung-5 solid, flange-to-flange. Pipe 1 at identity. Pipe 2 translated **+520** mm in Z so pipe-1 +Z flange outer (`Z = 260`) is coincident with pipe-2 −Z flange outer (local `Z = −260`). Mating plane `Z = 260`. Outer flanges stay empty ([fig-024-011.png](rung-08-frames/img/fig-024-011.png), [fig-025-013.png](rung-08-frames/img/fig-025-013.png)).

| | min | max | size |
|---|---:|---:|---:|
| X | −112.5 | 112.5 | 225 |
| Y | −112.5 | 112.5 | 225 |
| Z | −260 | 780 | 1040 |

Volume 2 × 2704332.648 = **5 408 665** mm³ of pipe metal (not a single body).

**Bolt axes** (rung 5: first hole +Y, circular 8 / 360°, radius 94), at the joint:

\[
(x,y) = 94\,(\cos\theta_i,\sin\theta_i),\quad \theta_i = 90° + i\cdot 45°
\]

`(0, 94)`, `(−66.468, 66.468)`, `(−94, 0)`, … . Nut faces coincident with `Z = 250` (pipe-1 +Z flange back) and `Z = 270` (pipe-2 −Z flange back). Nuts occupy `Z ∈ [242.5, 250]` and `[270, 277.5]`. Pin head equator at 242.5, tail equator at 277.5 when the head is on the −Z side.

**Wrench.** Bottom on pipe-1 flange back `Z = 250`. Inner jaw on the **+Y** nut. Handle toward **+X** (rungs 3–7 “handle on +X”; [fig-025-015.png](rung-08-frames/img/fig-025-015.png) handle to the right of the cyan flange). Head Ø45 centred on `(0, 94)`: Y ∈ [71.5, 116.5]. Handle 232.5 − 22.5 = 210 mm past the nut along +X: X max **210**. Flange still owns X min −112.5 and Y min −112.5.

| | min | max | size |
|---|---:|---:|---:|
| X | −112.5 | 210.0 | 322.5 |
| Y | −112.5 | 116.5 | 229.0 |
| Z | −260 | 780 | 1040 |

Prep published ~322 × 225 × 1040 with Y frozen at the flange. Recomputed Y is **229.0** (wrench head 94 + 22.5 = 116.5). Pin heads at the joint (`Z ≈ 232.5 … 287.5`) sit inside that Z span. Nuts at r = 94, AC 23.094, stay inside the flange Ø225. The wrench is the only part that grows XY beyond 225.

**Bolted metal** (no wrench):

\[
V_\mathrm{bolted} = 2\times 2704332.648 + 16\times 2009.028 + 8\times 6937.684 = 5\,496\,311
\]

Wrench volume is not in `check_rung01.py`. WP2’s fixture 3MF writes `V_WRENCH` into `PART`; `final` volume is `V_bolted + V_WRENCH`. Until that digit exists, `final` still checks bbox, counts, and wrench-mate probes.

**Tolerance.** Pin analytic (Pappus/hemisphere) error is 0. Treat

\[
V_\mathrm{pin} = 6938\ \mathrm{mm}^3,\quad \mathrm{bbox}\ 20\times 55\times 20
\]

as a **±1 %** band until an OCCT replica of [fig-022-006.png](rung-08-frames/img/fig-022-006.png); then 0.5 % like rung 5. Linear ± **0.2** mm on pin bbox and on pipe/nut/hole probes. Assembly Z 1040 and flange 225 are exact from rung 5. Wrench XY edges ± **0.5** mm (jaw/hex clocking). WP1 copies these into `PART` / `VOLUMES`; after that the walk reads `check_rung08.py params`, not this file.

**Mutants, not targets.** Pin overall 50 / R5 tail hemi (prep). Pin shank Ø8 (falls through) or Ø12 (will not enter). Mating the **outer** empty flanges (bbox Z 520, no centre joint). Nuts on only one side. Wrench jaw 25 (rung 7 hex) instead of 20. Skipping the bolt-hole Concentric (pipes still spin). Merged 3MF of hidden source bodies at the origin (bbox ~ pipe ∪ nut ∪ wrench at 0, not 1040 long). File → New (part) as the assembly document.

Inside (assembled, locked): pipe wall `(70, 0, 125)`, `(70, 0, 520)` (pipe 2), pin shank `(0, 94, 260)`, nut metal `(0, 102, 246.25)` (+Y nut, AF toward +Y, mid-thickness). Outside: pipe bore `(0, 0, 125)`, past flange `(113, 0, 0)`, past ends `(0, 0, −261)`, `(0, 0, 781)`, through a bolt with the pin removed `(0, 94, 255)` is empty of **pipe** (the pin fills it at `bolted`).

## The tutorial, step by step → SolidExpress

Rows are in the checklist. Frame cites there too.

| # | Tutorial | SolidExpress | Rows |
|---|---|---|---|
| 1 | New Assembly, MMGS ([page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png)) | File → New Assembly. Units mmgs. Empty of bodies, origin planes exist. | N1, A1 |
| 2 | Insert Components, Browse, three parts ([page-21.jpg](rung-08-frames/page-21.jpg), [fig-021-003.png](rung-08-frames/img/fig-021-003.png)) | Insert → Components… `nut.sxp`, `pipe.sxp`, `wrench.sxp` (WP2). | A2, A3, A4 |
| 3 | Drop, drag, Float ([fig-021-004.png](rung-08-frames/img/fig-021-004.png)) | Drop. Float the auto-Fixed first. Drag each. | A5, N2, L2 |
| 4 | Insert → New Part, Front, sketch pin, Revolve 360°, unselect Edit Component ([page-22.jpg](rung-08-frames/page-22.jpg), [fig-022-005.png](rung-08-frames/img/fig-022-005.png)–[fig-022-007.png](rung-08-frames/img/fig-022-007.png)) | Insert → New Part. Datum Front. Axis + profile. `finish_revolve(TAU)`. Edit Component off. | A6–A11, L3 |
| 5 | Box-select copy to 2 / 16 / 1 / 8 ([page-22.jpg](rung-08-frames/page-22.jpg) step 5, [fig-022-008.png](rung-08-frames/img/fig-022-008.png)) | Instance Ctrl+C/V. One of each already exists, so +1 pipe, +15 nuts, +7 pins. | A12, A13, A14, L4 |
| 6 | Fix one pipe ([fig-023-009.png](rung-08-frames/img/fig-023-009.png)) | AssemblyPanel Fix. | A15 |
| 7 | Mate Concentric, two inner pipe cylinders ([fig-023-010.png](rung-08-frames/img/fig-023-010.png)) | Mate, instance↔instance, offset 0. Unfixed pipe slides/rotates on +Z. | A16, L5 |
| 8 | Coincident flange bases; Concentric one bolt hole each ([page-24.jpg](rung-08-frames/page-24.jpg), [fig-024-011.png](rung-08-frames/img/fig-024-011.png)) | Two more mates. Pipes fully fixed. | A17, A18, A19 |
| 9 | Per bore: two nuts + one pin, coincident + concentric ([fig-024-012.png](rung-08-frames/img/fig-024-012.png)) | Named mates on the +Y hole first. | A20–A23, L6 |
| 10 | Repeat ×8. Optional Lock unused ([page-25.jpg](rung-08-frames/page-25.jpg), [fig-025-013.png](rung-08-frames/img/fig-025-013.png)) | Same named tools on the remaining seven. | A24, A25 |
| 11 | Wrench: flange coincident, jaw-flat coincident, head-curve to nut ([fig-025-015.png](rung-08-frames/img/fig-025-015.png)–[fig-025-016.png](rung-08-frames/img/fig-025-016.png)) | Coincident, coincident, **Tangent**. | A26–A28 |
| — | save (implied) | Save As `assembly.sxp`, reopen, 3MF of **instances**. | A29–A36, L7, N4, A37 |

Already in the product, no package: File → New MMGS **part**, Insert Components from **one** `.sxp`, Fix/Float, Place instance, Pattern around joint, kernel `plane_coincident` / `concentric` (offset > 0) / `fixed` / `fastened` / `plane_parallel`, Flip alignment, Revolve 360° in a **part**, AssemblyPanel list, explode, instance undo, origin planes, nut/wrench/pipe **part** walks, kernel `add_mate` with `instance_a` set (pliers coincident jaws).

## Gaps → packages

Grep on this tree (`9a493ca` product + seed docs). HAVE = named tool already does this step. PARTIAL = pieces exist, the tutorial step does not. MISSING = no such tool. Cleanup #282 closed **none** of these.

| # | Demand | Mark | Evidence (`file : symbol`) | Package |
|---|---|---|---|---|
| 1 | New Assembly, MMGS | **MISSING** / PARTIAL | `document_view.gd` `new_document` always a part, `units = mmgs`; `main.gd` `_do_new` status `"New — empty part, Top plane (XY)…"`. No `Document::Kind`, no New Assembly menu item. IPS N/A | WP3 |
| 2 | Insert 3 components from files | PARTIAL | `insert_sxp` + Insert → Components… HAVE (`sxp.cpp`, `main.gd` `insert_components_from`). FileDialog `FILE_MODE_OPEN_FILE` — **one** `.sxp` (`main.gd` `_on_insert_menu` id 10). No nut/pipe/wrench `.sxp` in the tree | WP2, WP3 |
| 3 | Drop anywhere, drag, Float | PARTIAL | First insert auto-Fixed (`sxp.cpp` `fix_first`). Float `set_instance_fixed` + AssemblyPanel lock/unlock HAVE. Drag of unfixed instances HAVE (`viewport_interaction.gd` `_drag_instance_id`). No `(f)` in a FeatureManager tree; AssemblyPanel list. Enough if the panel shows `(f)` and Float | WP3 |
| 4 | Insert → New Part, sketch, Revolve 360°, Edit Component | **MISSING** | Insert popup has Components / datums / Thread / Sketch / Hex / Hole — **no New Part** (`main.gd` `insert_popup`). `FeatureType::InContext` is a **20×20 box** (`ops_misc.cpp` `apply_in_context`). Revolve HAVE only as a part feature (`sketch_mode.gd` `finish_revolve`). **First named-tool stop** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)) | WP6 |
| 5 | Box-select copy to 2 / 16 / 1 / 8 | PARTIAL | Edit Copy/Paste of **bodies**; Paste Special → “as instance” (`document_view.gd` `paste_clipboard_as_instances`). AssemblyPanel Place instance (offset 30) and Pattern around joint. Not box-select-a-**component** + Ctrl+C/V | WP5 |
| 6 | Fix one pipe | HAVE | AssemblyPanel `_toggle_fixed`; kernel `set_instance_fixed` | — |
| 7 | Concentric two pipe bores | PARTIAL / **MISSING in UI** | Kernel Concentric on cylinders HAVE (`mates.cpp` `mate_axis`, `GeomAbs_Cylinder` only). `add_mate` **refuses `offset <= 0`** (`document.cpp:521`). UI Offset spin **defaults 0** (`assembly_panel.gd` `_offset_spin`). Armed flow is **“click ground face, then instance face”** (`_arm_mate`); `_instance_for_source` returns `""` when **more than one instance shares a source**. Kernel `instance_a` may be an instance (pliers `plane_coincident` jaws) — the click path never fills it. Click-through of [fig-023-010.png](rung-08-frames/img/fig-023-010.png) cannot land | WP4 |
| 8 | Coincident flange faces + Concentric bolt holes | PARTIAL | `plane_coincident` HAVE. Same UI/source-body limits as 7. Sequential `solve_mates` is one pass of `apply_mate` in insertion order (`mates.cpp:299`) | WP4, WP5 |
| 9 | Nut/pin coincident + concentric per bore | PARTIAL | Same mate types. 16 nuts / 8 pins are many instances of two sources — UI resolver returns `""`. Head/tail hemispheres are **spheres**; Concentric needs cylinders (nut bore and pin **shank**). Pin-head-collar to nut face is `plane_coincident` on the equatorial annulus | WP4, WP5, WP7 |
| 10 | ×8, optional Lock | PARTIAL / MISSING | Repeat is 8× the UI/copy gap. **Lock** mate MISSING (`MateType` has no Lock). Optional, so not a stop if 9 works | WP7 (×8); Lock out of scope |
| 11 | Wrench: flange coincident, jaw-flat coincident, head-curve to nut | PARTIAL / **MISSING** | Plane coincident HAVE for the flange and the jaw flat. Third mate is cylinder **tangent to a plane** ([fig-025-016.png](rung-08-frames/img/fig-025-016.png)) — no `MateType::Tangent` | WP8 |
| 12 | 3MF of the placed assembly | **MISSING** | `collect_mesh` tessellates **bodies at identity**, not instances (`interop.cpp:326`). Hidden insert-source bodies would dump stacked at the origin | WP9 |

**Readiness.** A named-tool click-through of this exercise **stops at step 1** if “New Assembly” must exist as a document type. Granting File → New (part, MMGS) as a stand-in, Insert Components can pull `.sxp` files **if the user has them**; the tree does not. Granting saved nut/wrench/pipe `.sxp`, the user can insert, Float, and Fix.

The **first hard stop on this tree** is **Insert → New Part** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)): the pin cannot be drafted as a component inside the assembly. A workaround (new ground-body sketch + Revolve 360° + Place instance) builds the solid but is not in-context and is not a component until instanced.

A second, independent stop lands the moment two pipes must be mated: **the Mate UI cannot pick instance↔instance**, cannot disambiguate two instances of one source, and Concentric offset 0 is rejected. Kernel `add_mate("concentric", inst_a, face_a, inst_b, face_b, offset>0)` works in tests; the click path does not.

A third stop is the wrench **curve** mate ([fig-025-016.png](rung-08-frames/img/fig-025-016.png)).

**Risks, largest first.**

- **No assembly document / no in-context New Part.** The exercise *is* “drafting parts within assemblies”. Without it the pin is a separate part, and the rung does not prove in-context.
- **Mate UI is ground→instance and unique-source.** This assembly is 27 instances of 4 sources. The click path cannot name “pipe 2’s bore” vs “pipe 1’s bore”. `pick_instance` is an AABB test with no face id (`document_view.gd`).
- **Sequential placer, not a solver.** Three mates to fully fix two pipes, then ~24 nut/pin mates. Later `apply_mate` overwrites instance B’s transform; it does not jointly satisfy the set. Nuts that must sit on *both* a hole axis and a flange plane need two mates on the same instance — the second can break the first.
- **Concentric offset gate (`offset <= 0` rejected) and cylinders-only.** Default UI offset 0 never adds the mate. Spheres (pin heads) cannot concentric.
- **No Lock, no tangent.** Optional Lock is skippable. The wrench’s third click is not.
- **No component box-copy.** Pattern-around-joint is the nearest 8-off tool, and it wants a joint, not a mate.
- **3MF ignores instance transforms.** `check_rung08` cannot be “export assembly.3mf and bbox it” on this exporter.
- **No nut `.sxp` in the walk.** Rung 1 A14 writes `nut.3mf` only.

## Design rules

New behaviour is a row in a table or a value object. `assembly_panel.gd`, `main.gd`, and `viewport_interaction.gd` only call the helper. A new file starts with a two-line header that says what it owns.

Tables: `Document::Kind` Part/Assembly, `MateType::Tangent`, checker `PART` / `STAGES`, walk `Rung`. Concentric offset-0 is a deleted gate, not a new type.

Click-driven UI tests (`.cursor/rules/gdscript-click-driven-tests.mdc`). A new suite is one `packaging/ci/suites.d/<name>.suite` file. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. Never pass `user://` or `res://` into GDExtension.

Do not edit `docs/plan/STATUS.md`. Do not commit `.webm`, `.mp4`, `.avi`, `.mov`, `.vtt`, or golden `.sxp` binaries. The four `known-red` manifests stay known-red. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call.

Every WP **keeps rungs 1–7 green**: walks 77/77, 44/44, 46/46, 32/32, 36/36, 46/46, 46/46 and `check_rung05/06/07` at their bars. Cheap checks include one C-one of a rung-1 assembly or rung-5 suite when the WP touches a shared file (`mates.cpp`, `assembly_panel.gd`, `interop.cpp`, `sxp.cpp`). They do not add walk rows until WP10. No visual-survey restyle.

## Decisions (the BUILD agent does not choose)

1. **File → New (part) is unchanged.** Pinned sentence, no dialog — rungs 1–7 A1 / N1. **File → New Assembly** is a new menu item (under File, next to New). It seeds origin planes, `units = mmgs`, `Document::Kind::Assembly`, no part body. Status `"New — empty assembly…"`. Persisted in `.sxp` so reopen stays an assembly. Do not hijack File → New with a template picker ([fig-020-001.png](rung-08-frames/img/fig-020-001.png) is the Assembly *item*, not a reason to break part New).
2. **Front, pipe axis +Z, first hole +Y.** Same as rung 5. Do not sketch the pin on Top. Do not put the pipeline on +X.
3. **Pin is overall 55, both ends R10, shank Ø10 × 35.** R5 in [fig-022-006.png](rung-08-frames/img/fig-022-006.png) is the shank radius from the axis. Prep’s 50 is the mutant. Origin at the tail pole, axis +Y in the pin part; after mates axis +Z.
4. **Centre joint, not the empty outers.** Coincident the +Z flange of pipe 1 to the −Z flange of pipe 2. Nuts and pins only there ([fig-025-013.png](rung-08-frames/img/fig-025-013.png)).
5. **Wrench on the +Y nut, handle +X, bottom on `Z = 250`.** [fig-020-000.png](rung-08-frames/img/fig-020-000.png) does not pin which of the 8; the walk does. Jaw 20 vs AF 20, zero gap ([fig-025-014.png](rung-08-frames/img/fig-025-014.png)).
6. **Reused parts are kernel fixtures, not a re-walk.** WP2 writes `nut.sxp` / `pipe.sxp` / `wrench.sxp` that pass `check_rung01.py nut`, `check_rung05.py final`, `check_rung01.py wrench`. The rung-8 walk **Inserts** those files (the honest tutorial click) and does **not** run `walk_rung01` / `walk_rung05` as a prerequisite. Rungs 1 and 5 remain the proof those parts can be built by clicking. Do not commit the `.sxp` binaries.
7. **Mate picks are instance↔instance.** Click face on instance A, then face on instance B. Ground (null `instance_a`) stays valid. Two instances of one source are distinguished by the viewport instance pick (ray into source space → source face id + instance id), not `_instance_for_source`.
8. **Concentric offset 0 is a valid axis mate.** Delete the `offset <= 0` gate. Offset 0 is the default and the tutorial value ([fig-023-010.png](rung-08-frames/img/fig-023-010.png) does not type a clearance). Positive offset stays a radial clearance for pliers.
9. **Solver holds every mate.** `solve_mates` jointly satisfies the set. A Gauss-Seidel loop of the existing closed-form `apply_mate` (repeat until instance transforms move < 1e-9, or max ~16) is enough. Nut concentric+coincident must land on the hole axis **and** the flange plane in **either** insertion order. Do not require a new numeric backend.
10. **Component copy is box-select instance + Ctrl+C/V.** Pattern-around-joint stays; it is not the walk path. Copies do not copy mates (the PDF copies then mates).
11. **In-context New Part is a component, not `FeatureType::InContext`.** Insert → New Part creates a new source body + instance, turns **Edit Component** on, and the next origin-plane pick (Front) sketches on that part. Revolve 360° builds the pin as that component’s body. Unselect Edit Component exits. Do not reuse the 20×20 in-context pad.
12. **Wrench mate 3 is Tangent (cylinder to plane).** Fastened over-locks. A second coincident of the opposite jaw flat is a mutant, not the named tool ([fig-025-016.png](rung-08-frames/img/fig-025-016.png) is the curve).
13. **Lock / lock-rotation is out of scope.** PDF: “possible but not required”.
14. **3MF of visible instances at their transforms.** Hidden insert-source bodies are not exported. `check_rung08` consumes that 3MF (and/or the host `.sxp` via a kernel probe). A merged-at-origin 3MF is a fail.
15. **No visual-survey batch.** Colours, glyphs, edges, hover, grid from rungs 6–7 stay.
16. **Auto-close default on** stays for rungs 1–7. The pin profile is a closed revolve contour; auto-close is harmless.
17. **Checkpoints.** Walk may write a chunk-1 snapshot after N2. Named files: `pin.sxp` after A11, `pipes.sxp` after A19, `bolted.sxp` after A25, `assembly.sxp` after A32, `final.sxp` after A34.
18. **Critique.** Checker + walk are necessary, not sufficient. Done = one build follows every PDF step with the named tool, score ≥ 9, checker passes. Caps at 8: File → New (part) as the assembly; ground-body revolve + Place instance as the pin; Pattern around joint as the only ×8 path; Fastened as the wrench curve; overall-50 pin; outer-flange joint; one-file 3MF of hidden sources at the origin; skip bolt-hole Concentric.
19. **Implementation split.** Assembly chrome + insert (WP3) then clickable two-instance mates (WP4) then solver + copy (WP5) then in-context pin (WP6) then ×8 (WP7) then wrench (WP8) then export (WP9). Each WP’s cheap check is green on its own. Do not wait for the walk to prove two pipes concentric.

## BUILD agent rules

- One commit per WP: `Rung 8 WP<n>: <title>`. **Commit and push after every WP and after every fixed walk row, and at least every 30 minutes.** Do not open a PR.
- Walks are **resumable from any row** while fixing (`--from` / checkpoints). A **final FULL clean pass of every walk for all rungs from row 1** is required before calling the rung a pass. Do not declare pass on a restored mid-walk.
- After **3 failed fix attempts** a row is logged as a finding in `docs/loop/rung-08-failing.md` and the agent moves on. A **final sweep** retries every finding once.
- **Test-and-fix** (after the walk exists and is red) runs as a **fresh agent given only** `docs/loop/rung-08-failing.md` (plus the plan/checklist it names). The BUILD agent writes that file when handing off; it starts empty of findings.
- **Revert.** If that WP's cheap check is still red after two honest attempts, `git revert` the commit, write one line in `docs/plan/roadmap.md` §14 naming the check, and continue. Do not loosen a tolerance, drop a `--only`, or edit the tier to get green.
- No new third-party dependency.

Cheap checks (not the full pass):

| Check | Command |
|---|---|
| C-py | the `python3 tools/test_….py` the WP names |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<suite>'` |
| C-dry | `python3 tools/walk_rung08.py --dry-run` plus `python3 tools/test_walk_registry.py` |
| C-r17 | C-one a rung-1 assembly suite or a rung-5/7 suite the WP names when it touches a shared file |

## Work packages

Blocking assembly first (WP3 chrome, WP4 two-instance mates, WP5 solver+copy, WP6 pin, WP7×8, WP8 wrench, WP9 export), walk, then whole-plan acceptance. No visual batch.

### WP1 — Checker `check_rung08.py`

Goal: stages `pin`, `pipes`, `bolted`, `final` with the numbers in the frame table. Unit tests use a stub, not the app. Pin `final` / `pin` volume from an OCCT 8.0.1 replica of the kernel revolve of the locked profile (R10 head + Ø10×35 shank + R10 tail, 360°). If it differs from 6938 by more than 0.2 %, put the OCCT number in `VOLUMES["pin"]` and say so in the commit. Do not widen the band to skip the replica.

Files: new `tools/check_rung08.py`, `tools/test_check_rung08.py`, `tools/implicit_pin.py` (tests only). `Makefile` `test-tools` gains `python3 tools/test_check_rung08.py`. Reuse `tools/solid.py`. `tools/confirm_all.sh` gains `unit_rung08` in the same commit if that file is the natural home; otherwise WP10 adds it with the walk.

Change: `PART` holds `HEAD_R = 10`, `TAIL_R = 10`, `SHANK_R = 5`, `SHANK_L = 35`, `OVERALL = 55`, `NUT_AF = 20`, `NUT_AC = 23.094`, `NUT_T = 7.5`, `NUT_BORE = 10`, `PIPE_OD = 150`, `PIPE_ID = 130`, `FLANGE_D = 225`, `FLANGE_T = 10`, `L0 = 250`, `PCD = 94`, `N_HOLES = 8`, `HOLE_D = 10`, `WRENCH_L = 232.5`, `WRENCH_HEAD = 45`, `WRENCH_T = 10`, `JAW = 20`, `N_PIPE = 2`, `N_NUT = 16`, `N_PIN = 8`, `N_WRENCH = 1`, `PIPE_DZ = 520`, `JOINT_Z = 260`, `NUT_Z_LO = 250`, `NUT_Z_HI = 270`, `V_PIN = 6938`, `V_NUT = 2009.028`, `V_PIPE = 2704332.648`, `V_BOLTED = 5496311`, `V_WRENCH = null` (WP2 fills), bbox min/max per stage as the tables, the inside/outside points above, `VOL_50 = 5105` (prep mutant; documentation only). `TOL = 0.2` mm. Wrench XY `TOL_WRENCH = 0.5`. Volume band **1 %** (`VOLUME_TOL = 0.01`); WP1's OCCT replica tightens pin `VOLUME_TOL` to 0.005. A 50 mm pin, outer-flange joint, and origin-stacked 3MF must still fail.

Because `export_3mf` does not yet apply instance transforms, the checker **accepts** (a) a pin/part 3MF for `pin`, and (b) an **assembly dump**: either a 3MF of instances at transforms (WP9) or a JSON `{instances: [{name, source, translation, rotation}], meshes: {source: path.3mf}}` plus optional host `.sxp`. Do not bbox a merged-at-identity mesh as `pipes` / `bolted` / `final`.

Probes: `Bbox` (per stage), `Volume` (`pin`; `bolted` = sum of instance volumes; `final` once `V_WRENCH` is set), `Watertight` (`pin` only: one closed solid), `Counts` (`pipes` onward: 2 pipes; `bolted`: 2/16/8; `final`: 2/16/8/1), `Coaxial` (`pipes` onward: pipe axes colinear with +Z, radial error ≤ 0.2), `Joint` (mating plane at Z = 260 ± 0.2; combined Z size 1040 ± 0.5), `Holes` (`bolted`/`final`: 8 pin axes through the 8 hole axes, radial error ≤ 0.2; first hole +Y), `Nuts` (each nut face within 0.2 mm of `Z=250` or `Z=270`; 16× AF 20, bore Ø10), `WrenchMates` (`final`: bottom on `Z=250` ± 0.2; inner-jaw gap 20.0 ± 0.2 on a nut AF; jaw-flat coincident ≤ 0.2; curve-to-flat tangent ≤ 0.2), `Inside` / `Outside` (points above). `STAGES`: `pin` (bbox 20×55×20, min `(−10, 0, −10)`, volume `V_PIN`), `pipes` (bbox 225×225×1040, min `(−112.5, −112.5, −260)`), `bolted` (same XY as pipes, Z 1040, volume `V_BOLTED`), `final` (bbox 322.5×229.0×1040, min `(−112.5, −112.5, −260)`, max `(210.0, 116.5, 780)`). `params` prints `PART` and `VOLUMES` as JSON.

`ImplicitPin` (tests only) is the two hemispheres + cylinder. `volume()` returns the table (mutants override).

Expected delta: about +550 lines.

Check: C-py `test_check_rung08.py` is red on the missing module, then green. Mutations that must fail the named check: overall 50 as `pin` (`bbox` Y 50), outer-flange joint as `pipes` (`bbox` Z 520), counts 1/8/4/1 as `bolted` (`counts`), wrench jaw 25 as `final` (`wrenchMates`), two bodies as `pin` (`watertight`), origin-stacked sources as `final` (`bbox` Z ≲ 520). `test_check_rung02/03/04/05/06/07.py` stay green.

Revert: revert the commit if C-py is still red after two attempts.

### WP2 — Kernel fixtures for nut, pipe, wrench `.sxp`

Goal: the walk Inserts real parts, fast. Kernel-build the three reused solids, `save_sxp` to a temp dir, 3MF of each passes the existing checker. Do **not** re-walk rung 1 (77) or rung 5 (36) inside this rung. Honesty is Insert Components of files that match those checkers.

Files: new `game/tests/lib/nut_fixture.gd` (`class_name NutFixture`: polygon AF 20, Ø10 circle, extrude 7.5). Reuse `game/tests/lib/pipe_fixture.gd`. New `game/tests/lib/wrench_fixture.gd` extracted from an existing `_build_wrench` that already reaches `check_rung01.py wrench` (28/28) — the kernel graph ops in `run_rung01_*.gd`, not the 77-row click walk. New `game/tests/run_rung08_parts.gd` + `packaging/ci/suites.d/rung08_parts.suite` (`tier=full`): boot, build three, export 3MF, `save_sxp` under the suite output dir, run the three checkers. Optional `tools/make_rung08_parts.py` CLI the walk calls. `PART["V_WRENCH"]` in `check_rung08.py` filled from the wrench 3MF volume in this commit.

Change: `rung08_parts.suite` exits 0 with `nut.sxp`, `pipe.sxp`, `wrench.sxp` on disk. `check_rung01.py nut` / `wrench` and `check_rung05.py final` exit 0 on the 3MFs. No committed binaries.

Expected delta: about +400 lines (mostly extracted wrench builder).

Check: C-one `--only 'rung08_parts.suite'` passes. Then C-py `test_check_rung08.py` still green with `V_WRENCH` set. C-one a rung-1 wrench suite / `rung05` fixture suite (builders still pass their own tests).

Revert: revert. Do not walk a stub cylinder as the pipe.

### WP3 — New Assembly, Insert (multi-file), Float/Fix

Goal: File → New Assembly, MMGS, Insert the three `.sxp`, drop, Float the auto-Fixed first, drag to confirm free, Fix later. [page-20.jpg](rung-08-frames/page-20.jpg)–[fig-021-004.png](rung-08-frames/img/fig-021-004.png). File → New (part) unchanged.

Files: `sxkernel/include/sx/document.hpp` `enum class Kind { Part, Assembly }` persisted in sxp. `document_view.gd` `new_document(kind := "part")` / `new_assembly()`. `main.gd` File menu item **New Assembly** (not a dialog on New). Insert FileDialog `FILE_MODE_OPEN_FILES` for Components… so three `.sxp` can be chosen together ([fig-021-003.png](rung-08-frames/img/fig-021-003.png)); sequential one-file insert stays. AssemblyPanel instance names show `(f)` when fixed. `automation_bridge.gd` + `docs/loop/automation-bridge.md` (`file:NewAssembly`, `insert:Components` multi-path). Catch2 sxp round-trip of `Kind`. `rung08_insert.suite`.

Change: New Assembly → empty shop, origin planes, `units = mmgs`, kind assembly, no seed box. Insert nut+pipe+wrench (WP2 files or three stub boxes in the cheap check), first instance `(f)`, Float, all three drag. Empty Insert path still refuses. File → New still the pinned part sentence, no dialog.

Expected delta: about +250 lines.

Check: red first, then C-one `rung08_insert.suite` (`tier=ci`): New Assembly, units mmgs, insert two `.sxp`, `(f)` on the first, Float, drag, Fix. Then C-one `insert_component_tests.suite` / `rung01` a New-part suite (File → New still part, one-file insert still works).

Revert: revert. Do not walk File → New (part) as the assembly.

### WP4 — Instance↔instance mate UI + Concentric offset 0

Goal: Mate tool, click a face on instance A then a face on instance B, Concentric offset **0** lands, Coincident of two instance planes lands. Two pipes (or two cylinders) of one source are distinguishable. [fig-023-010.png](rung-08-frames/img/fig-023-010.png), [fig-024-011.png](rung-08-frames/img/fig-024-011.png).

Files: `sxkernel/src/document.cpp` delete `offset <= 0` Concentric gate (offset 0 allowed; still refuse NaN). `mates.cpp` unchanged for a single mate. `assembly_panel.gd` `_arm_mate` / `_resolve_mate_b`: record `(instance, face)` per pick, not ground-then-unique-source. Status `"Mate: click two faces"`. `_instance_for_source` no longer the mate path (may stay for other buttons). `document_view.gd` `pick_instance` returns `{id, point, distance, face}`: transform the ray into the source body and reuse the kernel face pick. `viewport_interaction.gd`: while mate-armed, instance hits go to the panel with face id, and do not start a drag. Offset spin default 0 now succeeds for Concentric. `automation_bridge.gd` `mate:Add` with `instance_a`, `instance_b`, `face_a`, `face_b`. Catch2: two cylinders, `add_mate` concentric offset 0, solve, axes colinear. `rung08_mate.suite`. `run_assembly_tests.gd` ground→instance path still works.

Change: two inserted cylinders (or two WP2 pipes), Mate Concentric, pick both inner faces, offset 0, Ok. Second instance slides on the axis. Then Coincident on two end planes. Empty second pick still refuses. Pliers concentric offset 0.2 still adds.

Expected delta: about +300 lines.

Check: red first, Catch2: concentric offset 0 accepted; offset 0.2 still accepted. Then C-one `rung08_mate.suite` (`tier=ci`): New Assembly, insert two cylinders, Concentric 0, axes colinear ± 0.2, axial slide free; Coincident locks the gap. Then C-one `assembly_tests.suite` (ground→instance coincident still works) and `pliers_motion` / a concentric suite (offset 0.2 jaws unchanged).

Revert: revert. Do not walk typed transforms as the mate.

### WP5 — Multi-mate solver + component copy

Goal: several mates on one instance all hold (nut concentric + coincident, either order). Box-select a component, Ctrl+C / Ctrl+V copies the instance (new instance of the same source, offset ~30 mm, not Fixed, mates not copied) to the 2/16/1/8 counts ([page-22.jpg](rung-08-frames/page-22.jpg) step 5).

Files: `sxkernel/src/mates.cpp` `solve_mates`: loop `apply_mate` until max instance translation/rotation per pass < 1e-9 or 16 passes; return false if the last pass still moves. Catch2: plate with a hole + a nut-like washer; concentric then coincident **and** coincident then concentric both end with axis through the hole and face on the plane. `document_view.gd` / `viewport_interaction.gd`: when instances are selected, Ctrl+C copies instance ids (not bodies); Ctrl+V `add_instance` of each source with a small offset. Box-select of instances (rubber-band already exists for bodies — include instance AABBs). AssemblyPanel may expose Copy; the named path is the keys. `rung08_solver.suite`, `rung08_copy.suite`.

Change: one nut on one bored plate, two mates, both orders, `check_rung08`-style hole/face probes. Select a nut instance, Ctrl+C/V seven times → 8 nuts. Empty copy refuses `"Copy needs a selection"`. Body Ctrl+C/V in a **part** document unchanged (rungs 1–7).

Expected delta: about +280 lines.

Check: red first, Catch2 both mate orders. Then C-one `rung08_solver.suite` (`tier=ci`) and `rung08_copy.suite` (`tier=ci`): copy a nut instance to 8. Then C-one `assembly_tests.suite` (Place instance / Pattern around joint unchanged) and a rung-1 copy/paste body suite if one exists.

Revert: revert. Do not walk a second coincident dim as the only nut seat, and do not walk Pattern around joint as the only ×8 path.

### WP6 — In-context New Part (revolved pin)

Goal: Insert → New Part, pick Front, sketch the locked profile, Revolve 360°, unselect Edit Component. The pin is a **component**, not a ground body. `check_rung08.py pin` exits 0. [page-22.jpg](rung-08-frames/page-22.jpg), [fig-022-005.png](rung-08-frames/img/fig-022-005.png)–[fig-022-007.png](rung-08-frames/img/fig-022-007.png).

Files: Insert popup **New Part** (`main.gd` id next to Components). `document_view.gd` / new `edit_component.gd`: create empty source body + instance, `editing_instance` id, sketches/features apply to that source, instance mesh updates. Banner / toggle **Edit Component** on until clicked off ([page-22.jpg](rung-08-frames/page-22.jpg) “unselect Edit Component”). Origin-plane pick uses assembly Front (`OriginPlanes.BASIS`). Revolve is HAVE (`finish_revolve`). Do not call `apply_in_context`. Catch2 optional if a kernel “component sketch” wrapper appears. `rung08_pin.suite`. `docs/loop/automation-bridge.md` (`insert:NewPart`, `edit:Component`).

Change: New Assembly (or a stub assembly), New Part, Front, centerline + R10 / 35 / R5 / 55 / R10 tail, Revolve 360°, Edit Component off, one instance, export `pin.3mf`, `check_rung08.py pin` 0. Ground-body count of *modelling* bodies is the pin source (hidden or shown while editing) plus any inserts; the placed pin is the instance. A 20×20 in-context pad is a fail.

Expected delta: about +350 lines.

Check: red first, then C-one `rung08_pin.suite` (`tier=full`): the named clicks, bbox 20×55×20, volume within the band, one watertight solid. Then C-one a rung-6 revolve suite (part revolve unchanged) and `film_context_update` / in-context pad (20×20 pad still that feature, unused here).

Revert: revert. Do not walk a ground revolve + Place instance as the only pin.

### WP7 — Nut/pin ×8 land-green (`bolted`)

Goal: the second implementation split lands green: two pipes fully mated (WP4–WP5), 8 pins and 16 nuts on the centre joint. `check_rung08.py pipes` and `bolted` exit 0. Product tools are WP2–WP6 plus HAVE. This WP is the click suite and any glue the red test finds (face filters, copy counts) — not a new modelling verb.

Files: `game/tests/run_rung08_bolted.gd` + `packaging/ci/suites.d/rung08_bolted.suite` (`tier=full`). Reads `SxChecker.run("rung08", ["params"])` so millimetres are not a second table.

Change: the suite clicks the named tools (Insert of WP2 files, New Part pin, copies, Fix, three pipe mates, per-bore concentric+coincident ×8). After the pipe mates, export `pipes.3mf` (or dump), `check_rung08.py pipes` 0. After ×8, `bolted` 0. First hole +Y. Optional Lock not clicked.

Expected delta: about +280 lines of test. Product 0 if green on first try.

Check: C-one `--only 'rung08_bolted.suite'` passes. Then C-one `rung08_mate.suite` (two-instance path unchanged). `check_rung05.py` / `check_rung07.py` are not re-run here (WP11).

Revert: revert the test commit if it stays red after two product-fix attempts in this WP; then park the glue in `roadmap.md` §14. Do not fake the ×8 with Pattern around joint.

### WP8 — Wrench mates (Tangent)

Goal: wrench bottom coincident to flange `Z = 250`, inner jaw flat coincident to the +Y nut flat, **bottom curve** tangent to the corresponding nut side. `check_rung08.py final` exits 0 (bbox / counts / wrenchMates; volume if `V_WRENCH` set). [fig-025-015.png](rung-08-frames/img/fig-025-015.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png), [fig-025-016.png](rung-08-frames/img/fig-025-016.png).

Files: `sxkernel/include/sx/mates.hpp` `MateType::Tangent`. `mates.cpp` `apply_mate`: cylinder axis parallel to plane, distance = radius (touching); plane-plane is Coincident, not this. Flip chooses the side. UI type list gains `tangent`. Catch2: cylinder Ø45 vs a plane, tangent, gap 0. `rung08_wrench.suite`. `to_string` / `mate_type_from_string` / json.

Change: from the bolted assembly (or a stub nut-on-plate + wrench instance), three named mates, Ok. Jaw opening 20.0 ± 0.2 on the nut AF. Handle toward +X. Fastened is a fail for mate 3.

Expected delta: about +180 lines.

Check: red first, Catch2 cylinder-to-plane tangent. Then C-one `rung08_wrench.suite` (`tier=full`): bolted (or stub) + three wrench mates, `check_rung08.py final` 0. Then C-one `rung08_mate.suite` (Concentric / Coincident unchanged).

Revert: revert. Do not walk Fastened or a second jaw coincident as the only curve path.

### WP9 — 3MF of instances + save/reopen

Goal: `export_3mf` tessellates **visible instances at their transforms**, skips hidden insert-source bodies. Save As `assembly.sxp`, File → New Assembly, Open, counts and `final` bbox/volume still pass. [fig-020-000.png](rung-08-frames/img/fig-020-000.png) is the look, not a new tool.

Files: `sxkernel/src/interop.cpp` `collect_mesh`: if the document has instances, tessellate each instance’s source shape transformed by the instance `gp_Trsf`; skip bodies that are hidden *or* that are instance sources when at least one instance exists (the UI already hides them). Part documents with zero instances keep today’s body-at-identity path (rungs 1–7). Catch2 `test_insert_sxp.cpp` / new `test_assembly_export.cpp`: two instanced boxes 100 mm apart, 3MF bbox spans ~100, not stacked. `sxcore` bind unchanged. `rung08_export.suite`. Hidden-body flag: kernel may take an explicit skip list from the UI (`export_3mf` already has no hide set — pass `hidden_bodies` or skip sources with instances).

Change: export `assembly.3mf` from the WP8 solid, `check_rung08.py final` 0 on that 3MF. Reopen `.sxp`, kind is Assembly, 27 instances, re-export passes again. A part 3MF of a wrench (no instances) is unchanged.

Expected delta: about +150 lines.

Check: red first, Catch2 two instances 100 mm apart, 3MF bbox size ≥ 90 in that axis. Then C-one `rung08_export.suite` (`tier=full`). Then C-one a rung-5 / rung-7 export suite (`check_rung05.py final` / `check_rung07.py final` still 0 on part 3MFs).

Revert: revert. Do not walk a JSON-only dump as the only export if the 3MF path is the named File → Export 3MF.

### WP10 — Walk

Goal: `tools/walk_rung08.py` runs the checklist. Registry freezes the row list. Rungs 1–7 stay frozen.

Files: `tools/walk/registry.py` (`RUNG8_ROWS`, `_RUNG_SPEC["rung08"]`, `install`), new `tools/walk/app08.py`, `tools/walk/rung8/ui08.py`, `tools/walk/rung8/rows08_chunk{1,2,3,4}.py`, new `tools/walk_rung08.py` (same CLI as `walk_rung07.py`). `tools/test_walk_registry.py` gains `FROZEN_ROWS_08`. `tools/confirm_all.sh` gains `unit_rung08` (if WP1 did not), walk 8 on display `:28` / port `47328`, and the summary lines (`rung8`, `check-final-final.txt`). `docs/loop/README.md` lists this plan, the checklist, and `walk_rung08.py`. `docs/loop/automation-bridge.md` for new click forms (`file:NewAssembly`, `insert:NewPart`, `mate:Add` instance↔instance, `insert:Components` multi, `export:3mf` instances). `tools/walk/chrome.py` `_HEADLESS` row 8.

Change: each checklist row is a method that calls `ui08` helpers and `self.clause(...)`. Chunks and checkpoints are decision 17. Export rows share one 3MF per stage. A37 is the headless evidence row (needs `--a15`; without the flag it is `BLOCKED-by-flag`), same clause names as rung 7 A37. Walk setup runs WP2’s part writer once into the out dir; Insert clicks those files.

Expected delta: about +900 lines.

Check: C-dry. Registry test green for eight rungs. `walk_rung08.py --rows N1,A1,A2 --dry-run` prints those rows. Do not launch Godot here.

Revert: revert if the registry test is red after two attempts.

### WP11 — The single full pass

Goal: one pass on this VM. Counts only. No product edits unless a count is red, and then only the smallest fix, re-run once.

Change: none expected. Run:

`tools/confirm_all.sh`

That script builds, imports, runs the kernel, the lints, `test_check_rung02/03/04/05/06/07/08.py`, the registry test, the headless suites, and the eight walks. Do not also run `make test` or a second suite pass.

Report, and nothing else: the confirm summary lines (build, kernel, lint, godot suite count, rung1 77, rung2 44, rung3 46, rung4 32, rung5 36, rung6 46, rung7 46, rung8 48, each checker tail including `check_rung05` 10/10, `check_rung06` 7/7, `check_rung07` final N/N, `check_rung08` final N/N).

A **FULL clean pass of every walk from row 1** (no `--from` leftovers) is the pass. If `rung-08-failing.md` still lists findings after the sweep, the rung is not a pass.

Expected delta: 0.

Check: the summary. A walk row that fails is a product bug; fix it and re-run confirm once. Do not re-run confirm before that fix.

Revert: not this WP. A bad fix-up commit reverts on its own.

## Chunks

| Chunk | Rows | Ends |
|---|---|---|
| 1 | N1 A1 L1 A2 A3 A4 L2 A5 N2 | New Assembly, three components inserted, all floating |
| 2 | A6 A7 A8 A9 A10 A11 L3 | in-context pin, `pin.sxp`, `check_rung08 pin` |
| 3 | A12 A13 A14 L4 A15 | counts 2/16/8/1, one pipe Fixed |
| 4 | N3 A16 L5 A17 A18 A19 | pipes mated, `pipes.sxp`, bbox 225×225×1040 |
| 5 | A20 A21 A22 A23 L6 A24 A25 | bolted ×8, `bolted.sxp` |
| 6 | A26 A27 A28 A29 A30 A31 L7 A32 A33 A34 N4 A35 A36 A37 | wrench on, `assembly.sxp`, checker passed, headless evidence |

48 rows: 37 A, 7 L, 4 N. Clause text: [`rung-08-checklist.md`](rung-08-checklist.md).

## Out of scope

- A units dialog, or editing the pinned New (part) sentence. IPS trap (SX is already MMGS).
- Lock mate / Concentric “Lock rotation”. PDF optional.
- FeatureManager tree as a full SW clone; AssemblyPanel with `(f)` is the Fix/Float UI.
- Multi-body part files, subassemblies, Copy with Mates, Advanced/Mechanical mates.
- Threads on the pin or nut. The Ex 1 nut is a hex with a Ø10 bore.
- A demo film. `docs/plan/STATUS.md`. Visual-survey restyle.
- Changing rungs 1–7 walk row lists.
- Committing `.sxp` goldens.
