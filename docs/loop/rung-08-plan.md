# Rung 8 plan — pipeline assembly (UBC ELEC391 Exercise 4)

**PLAN only, no product code.** One BUILD agent implements this in order, one commit per work package, on the branch it is given. Push that branch. Do not open a PR. Source: *SolidWorks & Tinkerine 3D Printing Tutorial — ELEC391*, UBC ECE Engineering Services, [same PDF as rungs 1 and 5](https://people.ece.ubc.ca/~eng-services/files/tutorials/SolidWorks%20&%203D%20Printing%20Tutorial-R1.pdf), pages 20–25. Everything from the PDF is in [`rung-08-prep.md`](rung-08-prep.md), the stills in [`rung-08-frames/`](rung-08-frames/), and below. Do not re-open the PDF. The row text is [`rung-08-checklist.md`](rung-08-checklist.md); do not restate it.

Three tracks: **A** is the pipeline assembly (WP1–WP11). **L/S** is Andy’s 2026-10-19 exactness + spline set (WP-L1…L12, WP-S1, WP-S2). **V** is the visual-survey **second batch** (WP-V1…V8) from [`docs/design/visual-survey.md`](../design/visual-survey.md) (VS#). L/S is **not gated** on the rung-8 walk. **WP-L1 lands first** on this branch: every other L/S acceptance uses its probes. WP-L7 ships with or before WP-S2. WP-S1 and WP-L6 are complementary (splines vs the rest of Convert). V lands **after blocking assembly WPs** if they compete, and **before WP11**. Do not restyle films except where V1/V2 add alpha. Leave the featured film set alone.

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
- Every WP-L* / WP-S* headless acceptance in [`rung-08-checklist.md`](rung-08-checklist.md) § Exactness (kernel curve type / `BRepGProp` / round-trip). Mesh-only `check_rung*.py` (0.2 mm / 0.5 %) does **not** count as exact.

Whole-plan acceptance is **WP11**. It requires tracks A, L/S, and V green. L/S packages run their own cheap checks as they land and **do not wait** for WP10. V packages run the cheap check they name and **do not wait** for the walk; they **must** land before WP11. Earlier packages run the one cheap check they name. They do not run `make test`, `make test-godot`, `confirm_all.sh`, or a walk without `--dry-run`.

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

Every WP **keeps rungs 1–7 green**: walks 77/77, 44/44, 46/46, 32/32, 36/36, 46/46, 46/46 and `check_rung05/06/07` at their bars. Cheap checks include one C-one of a rung-1 assembly or rung-5 suite when the WP touches a shared file (`mates.cpp`, `assembly_panel.gd`, `interop.cpp`, `sxp.cpp`). They do not add walk rows until WP10. L/S and V WPs add **no** walk rows. Visual WPs update tests that pin old colour constants in the **same commit**. They do not restyle `FilmPresentation.FLAT_BG` or `apply_film_look` except where V1/V2 add alpha on the export/screenshot path. Featured films stay.

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
15. **Visual-survey second batch (WP-V1…V8).** Shop / Scenic / Solid… / Transparent + File → Export Image PNG (V1); automation screenshot shares that path (V2); real ViewCube (V3); grey inactive sketches (V4); one accent per primary rail verb (V5); SSAO + body albedo 0.66 (V6); light sketch sheet only if blue is unreadable on charcoal, films stay charcoal (V7); ellipse/arc rung-6 colour grammar tested on the 12-point sketch (V8). Not this round: per-body transparency, HLR/tangent-edge modes, foreshortened radius leaders (VS #12, #15; P6 out of scope).
16. **Auto-close default on** stays for rungs 1–7. The pin profile is a closed revolve contour; auto-close is harmless.
17. **Checkpoints.** Walk may write a chunk-1 snapshot after N2. Named files: `pin.sxp` after A11, `pipes.sxp` after A19, `bolted.sxp` after A25, `assembly.sxp` after A32, `final.sxp` after A34.
18. **Critique.** Checker + walk are necessary, not sufficient. Done = one build follows every PDF step with the named tool, score ≥ 9, checker passes. Caps at 8: File → New (part) as the assembly; ground-body revolve + Place instance as the pin; Pattern around joint as the only ×8 path; Fastened as the wrench curve; overall-50 pin; outer-flange joint; one-file 3MF of hidden sources at the origin; skip bolt-hole Concentric.
19. **Implementation split.** Two tracks. **L/S:** WP-L1 first, then L2–L5, S1, L6, L7, S2, L8–L12 (L7 before or with S2; S1 and L6 are not the same Convert WP). **A:** chrome + insert (WP3) then clickable two-instance mates (WP4) then solver + copy (WP5) then in-context pin (WP6) then ×8 (WP7) then wrench (WP8) then export (WP9). Each WP’s cheap check is green on its own. Do not wait for the walk to prove two pipes concentric. Do not wait for the walk to land L/S.
20. **Exact means kernel, not mesh.** Acceptance for L/S: `BRepAdaptor_Curve::GetType` (and face `GetType`), radii/centres within **1e-6 mm**, volume via `BRepGProp` within **1e-6 relative**, save→load or bridge round-trip equal to the bit (or within 1e-12). WP-L1 is the harness. Unconfirmed audit cases start with a **probe that confirms the cited bug** (records the actual error size); if that probe is green, drop the case from the WP and say so in the commit.
21. **Rungs 1–7 walks stay 77/44/46/32/36/46/46** on every L/S WP. Rung 7 A28 still passes after WP-S1 and WP-L6. Rung 6 walk and `check_rung06` still pass after WP-L2 and WP-L4.

## BUILD agent rules

- One commit per WP: `Rung 8 WP<n>: <title>` or `Rung 8 WP-L<n>: <title>` / `Rung 8 WP-S<n>: <title>` / `Rung 8 WP-V<n>: <title>`. **Commit and push after every WP and after every fixed walk row, and at least every 30 minutes.** Do not open a PR.
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
| C-exact | Catch2 / CLI that calls WP-L1 probes (curve type, `BRepGProp`). Required on every L/S WP after L1 |

## Work packages

**33 WPs.** Track L/S (14) is not gated on the assembly walk. Track A (WP1–WP11) is the pipeline. Track V (8) is the visual-survey second batch. **WP-L1 is first** on this branch. V lands after blocking assembly WPs if they compete, and before WP11.

Source for L/S: Andy, 2026-10-19; audit of `origin/main` `9a493ca` (read-only). Line numbers in the case table are at that commit. WP-S1 is rung-07-result.md finding 1.

### Track L/S — exactness and splines

Unconfirmed (probe before relying on the cited error): hidden `dim_value` 0.5-grid (case 4 / WP-L9); `get_edge_lines` seam-point centroid bias (case 10 / WP-L6); mirror-arc angles from `add_arc` (case 5 / WP-L8); SweepFuse picking the chorded ribbon (case 1 / WP-L2); thread error size (case 20 / WP-L2); `BRepTools::Write` 15 vs 17 digits (WP-L11).

Ranked cases (audit `9a493ca`; line numbers there). Fix mapping:

| # | Converted from → to | WP |
|---|---|---|
| 1 | Path/guide arcs→15° chords, circles→32-gon, ellipses→15° chords, splines→8 samples/fit; exact spine only single line+arc | L2 |
| 2 | Drafted extrude/cut → centroid-scale loft; holes dropped; cut starts 0.05 mm outside | L4 |
| 3 | Loft guides → synthetic circles at t=0.35/0.65 | L3 |
| 4 | Typed values → Godot `Range` `min+k·step` | L9 |
| 5 | Sketch Mirror of an arc → `(−end,−start)`; no Symmetric; ellipse/spline skipped | L8 |
| 6 | Boolean fuzzy retries to 0.1 mm; accept ≥90 % volume or invalid fallback | L5 |
| 7 | Convert ellipse → fitted arc or nothing; tilted circle → diameter line; no re-project | L6 |
| 8 | Four spline curves (solver poles ≠ `PointsToBSpline` ≠ Catmull-Rom ≠ overlay segments) | L7 |
| 9 | STL 0.1 mm / 0.5 rad, 3MF 0.05/0.2, float32, 6 digits | L12 |
| 10 | Display tessellation → pierce/circle-fit/`wp2-anchor` | L6 |
| 11 | Rib → sampled boxes fused | L2 |
| 12 | Offset/pattern: fixed nums, skipped types | L8 |
| 13 | Thin/open cut → first line chain only | L8 |
| 14 | Sketch coords double→float32→double | L10 |
| 15 | Feature params as C++ `float` | L10 (sweep path doubles also L2) |
| 16 | Failed fillet → wedge prism | L5 |
| 17 | Feature mirror skips Shell/Chamfer | L5 |
| 18 | Constraint `weak` not written; unknown types load as Arc | L11 |
| 19 | DXF 0.05 mm chords; import drops LWPOLYLINE/ELLIPSE/SPLINE | L12 |
| 20 | Thread cutter Frenet, not axial plane | L2 |
| 21 | Measured jaw snapped 0.01 mm | L8 |
| 22 | Voice fix/lock → Horizontal | L8 |
| 23 | Checkers judge 3MF mesh 0.2 mm / 0.5 % | L1 |
| 24 | Archimedean spiral → 32 samples/turn (no callers) | L2 |
| r7 f1 | Convert in-plane BSpline → fitted arc | **S1** (not L6) |

#### WP-L1 — Exactness probes for the harness (S)

Goal: cases **23**. A headless kernel/CLI query that lists for a body or sketch: each edge’s curve type, radius/centre/axis, ellipse radii, BSpline degree/poles; each face’s surface type; exact volume/area (`BRepGProp`); feature param values as written. Expose to `tools/` (`sxdrive`) and GUT. Every later L/S acceptance uses this. Mesh-only `check_rung*.py` does not count.

Files: new `sxkernel` query (e.g. `sx::exactness::report(doc, body)` / sketch); Catch2 `test_exactness_probes.cpp`; `sxcore` bind; `tools/` CLI (`python3 tools/sx_exact.py` or an `sxdrive` verb); `tools/test_sx_exact.py`; optional GUT `run_exactness_probes.gd` + `packaging/ci/suites.d/exactness_probes.suite` (`tier=ci`).

Change: a box with a Ø10 hole reports one `GeomAbs_Circle` edge of radius 5, volume equal to the analytic value. Feature params round-trip as written.

Expected delta: about +250 lines.

Check: red first. Catch2: box + Ø10 hole → one `GeomAbs_Circle` radius 5 ± 1e-6, volume within 1e-9 rel of analytic. C-py reads the same through the CLI. Then C-one a rung-5 export suite if the bind touches `SxDocument` (rungs 1–7 walks not launched here).

Revert: revert. Do not let later L/S WPs assert on 3MF mesh instead.

#### WP-L2 — Exact sweep, loft-section, rib and thread paths (L)

Goal: cases **1, 11, 20, 24** (and the sweep side of 15: `graph_add_sweep` path as doubles). One `sketch_exact_wire(sketch, open|closed)` used by Path, Sweep (path and guides), Loft open sections, Rib and Thin. Polyline only if the exact wire fails, and then the feature carries a visible `"approximated path"` warning. `bridge_spline` becomes `GeomAPI_Interpolate` through the control points (exact curve, not Catmull-Rom samples).

**First step (unconfirmed):** Catch2 probe that (a) records whether SweepFuse ever picks the chorded ribbon over an exact spine (case 1), and (b) measures the thread axial-flank / pitch-diameter error size (case 20). If SweepFuse never picks the chorded ribbon, drop that sub-claim and still build the exact wire. If thread error is below 1e-6, still switch to axial-plane sweep so the ISO basic profile is the named path.

Files: `sxkernel/src/features.cpp` `sketch_ordered_polyline` / `sweep_along_polyline` / `sketch_spine_wire`; `features/ops_sweep.cpp`; `features/ops_misc.cpp` rib; thread cutter `features.cpp` ~575–618; `curves.cpp` spiral (no callers — exact law or interpolate to 1e-7). Catch2 `test_exact_spine.cpp`. `rung08_exact_sweep.suite` optional (`tier=full`). WP-L1 probes in every acceptance.

Change: spine/guide is an exact wire (lines, `Geom_TrimmedCurve` arcs, `Geom_Ellipse`, the spline’s BSpline) for all sketches and all path modes.

Expected delta: about +400 lines.

Check: red first, then Catch2 using WP-L1: (a) single-sketch and two-sketch paths (line + R150 arc + R20 arc) → spine edges Line/Circle with R150 and R20 within 1e-6; swept solid contains a toroidal face of major radius 150 ± 1e-6; (b) spline path: spine `GeomAbs_BSplineCurve`, every fit point within 1e-6; (c) ellipse path: `GeomAbs_Ellipse`; (d) rib on an R20 arc profile has a cylindrical face R20 ± t/2 within 1e-6 and no extra faces at the bends; (e) thread: axial section flank angle 60° ± 0.01°; (f) C-one a rung-6 sweep suite — walk 46/46 and `check_rung06` still pass (cheap: C-one `rung06_sweep.suite` / spine suite, not the walk).

Revert: revert. Do not leave polyline as the silent default.

#### WP-L3 — Guided loft that follows the guide (L)

Goal: case **3**. Loft with guides through `BRepOffsetAPI_MakePipeShell` (sections + auxiliary guide) or `GeomFill` surfaces; refuse with a message when OCCT cannot, instead of inventing circular sections at t=0.35/0.65 (`ops_sweep.cpp` 455–523).

Files: `features/ops_sweep.cpp` guided loft. Catch2 `test_guided_loft.cpp`. WP-L1 probes.

Change: square-to-square loft with a straight guide is a guided solid, not circular waists.

Expected delta: about +250 lines.

Check: red first. Catch2: square-to-square loft, straight guide offset 5 mm: every point of the guide lies on the loft surface within 1e-6 (`BRepExtrema_DistShapeShape`); no circular edges unless the profiles are circles; guided-loft volume ≠ unguided volume. Then C-one a rung-6 loft/sweep suite if one exists (unguided loft unchanged).

Revert: revert. Do not keep the synthetic circular sections as a fallback without a refuse.

#### WP-L4 — True draft extrude/cut (M)

Goal: case **2** (and the 0.05 mm cut-start shift at `ops_solid.cpp` 412–425). `BRepFeat_MakeDPrism` / `LocOpe_DPrism` per profile face, inner wires kept. Start the cut on the face.

Files: `features/ops_solid.cpp` drafted extrude/cut. Catch2 `test_draft_dprism.cpp`. WP-L1 probes.

Change: 40×10 rect, depth 10, 5° inward: every side face’s angle to the extrude direction is 5° ± 1e-6. Holes kept as drafted cones. No 0.05 mm cut-start.

Expected delta: about +200 lines.

Check: red first. Catch2: 40×10 × 10 deep, 5° inward, every side 5° ± 1e-6 from face normals; profile with a Ø6 hole keeps a drafted conical hole face; the rung 6 Ø30 15° cut volume unchanged within 1e-6 rel and cut diameter at the host face is 30 ± 1e-6. Then C-one `rung06_draft.suite`.

Revert: revert. Do not keep centroid-scale loft as the draft.

#### WP-L5 — Honest booleans and dress-ups (M)

Goal: cases **6, 16, 17**. Silent fuzz ≤ 1e-6×bbox; any larger fuzz, heal, unify or fallback is written to the feature as a warning with the value used; volume acceptance compares to the expected change, not 90 %; feature mirror replays chamfer/shell or fails with the feature name; fillet wedge fallback only for verified planar vertical walls and labelled.

Files: `features/ops_solid.cpp` 87–180; `ops_sweep.cpp` 126–215; `interop.cpp` 276–300; `ops_dress.cpp` fillet wedge 893–916, 495–660; `ops_transform.cpp` FeatureMirror POLICY Shell/Chamfer. Catch2 `test_honest_boolean.cpp`, `test_fillet_fallback.cpp`, extend `test_rung07_fillet_mirror.cpp` / rung-5 mirror. WP-L1 volume probes.

Change: two boxes touching fuse with zero fuzz, volume = sum. A fuse that needs 0.05 fuzz shows the warning. Mirror of a chamfered body has a chamfer face on both sides. No test anywhere passes with < 99.9999 % of the expected volume.

Expected delta: about +200 lines.

Check: red first. Catch2: fuse volume 1e-9 rel of the sum, zero fuzz; fuzz 0.05 writes warning text on the feature; mirror+chamfer count and area equal within 1e-6 both sides; fillet wedge only when walls are planar and vertical (else refuse + warning). Then C-one `rung05_mirror.suite` (Shell skip becomes replay-or-fail; if replay, `check_rung05` `mirror` volume still at bar).

Revert: revert. Do not keep the 90 % volume accept.

#### WP-S1 — Convert Entities keeps splines (M)

Goal: rung-07-result.md **finding 1**. OCCT stores some model edges as in-plane BSplines; Convert fits circular arcs instead of copying the curve type. Convert must emit a true sketch spline (matching the kernel’s curve, within 1e-6) for BSpline/Bezier edges, and keep arcs and lines as they are. **Not WP-L6** (ellipses, tilted circles, associativity, pierce/anchors).

Files: `sxkernel/src/sketch3d.cpp` projectors; `sketch_convert_edge.gd`. Catch2 `test_convert_spline.cpp`. WP-L1 curve-type probes.

Change: Convert of an in-plane BSpline edge → sketch Spline whose geometry matches the edge (degree/poles or interpolating fit, 1e-6). Line stays Line; Circle/Arc stay Circle/Arc. Rung 7 walk row A28 still PASS (`Convert: external arc` for the R30/R20 handle).

Expected delta: about +150 lines.

Check: red first. Catch2: BSpline edge → sketch entity type Spline, WP-L1 report `GeomAbs_BSplineCurve` (or the sketch spline’s poles) matching the edge within 1e-6. Line/arc Convert unchanged. Then C-one `rung07_offset.suite` (A28 path: Convert of fillet arcs still arcs). Do not launch `walk_rung07` here; WP11 does.

Revert: revert. Do not fit a circular arc to a BSpline as the Convert result.

#### WP-L6 — Convert: exact projection beyond splines, and associativity (M)

Goal: cases **7, 10**. Complementary to WP-S1 (BSpline/Bezier copy stays there). Ellipse edge → sketch ellipse/elliptical arc; tilted circle → projected ellipse; out-of-plane edge → exact projection or refuse (no 2 mm / 0.5 mm tolerance); re-project every external entity on regen (wire `update_projected_*` / `mark_dangling_external` into the regen path, add arc/ellipse updates); jaw/hole anchors and pierce points come from the kernel (`GeomAPI_IntCS`, `BRepAdaptor_Curve::Circle()`), never from `get_edge_lines`.

**First step (unconfirmed):** Catch2 probe that `get_edge_lines` on a circle repeats the seam point and that the vertex-centroid centre is off by ~r/N. If the seam is not repeated, drop the “~0.9 mm on Ø45” claim and still stop using polylines for pierce/anchors.

Files: `sketch3d.cpp` 115–171, 216–279; `sxcore/src/sx_sketch.cpp` 517–529 (`update_projected_*`, no callers today); `sketch_mode.gd` 2305–2376, 3838–3872, 4476, 4550, 3654–3667; `viewport_interaction.gd` 3755–3790. Catch2 `test_convert_ellipse.cpp`, `test_pierce_kernel.cpp`. WP-L1 probes.

Change: filleted ellipse boss Convert → sketch `ellipse` with radii equal to the edge within 1e-6; change the boss and regen: converted entity follows within 1e-6; pierce of a Ø45 cylinder on a plane at 30° lands on the true circle within 1e-6.

Expected delta: about +250 lines.

Check: red first (including the seam-point probe). Then Catch2 acceptance above. C-one `rung07_offset.suite` — A28 still passes. Then C-one a rung-3 convert suite (full-circle Convert unchanged).

Revert: revert. Do not keep 0.5 mm radius-tol arc fitting for ellipses.

#### WP-L7 — One spline definition (M)

Goal: case **8**. Prerequisite for WP-S2 — land **before** S2 (same agent may commit L7 then S2). Kernel builds the spline with `GeomAPI_Interpolate` through the fit points; the solver gets the same curve (poles/knots from the kernel, fit-point constraints); preview, pad overlay and picking sample the kernel curve.

Files: `solver_planegcs.cpp` 140–176; `sketch.cpp` 860–871; `features.cpp` 796–813; `sketch_regions.cpp` 100–110; `sketch_mode.gd` 3739–3760; `sketch_pad_overlay.gd` 372–378. Catch2 `test_spline_interpolate.cpp`. WP-L1 BSpline poles.

Change: one curve. Solver is not a uniform cubic on fit points as poles. Overlay is not Catmull-Rom / straight segments.

Expected delta: about +200 lines.

Check: red first. Catch2: 5 zig-zag fit points → kernel edge passes each fit point within 1e-9; solver-side curve and kernel curve agree within 1e-6 at 100 parameters; displayed polyline vertices lie on the kernel curve within 1e-6; save/load keeps fit points bit-identical. Then C-one a spline sketch suite if one exists (rungs 1–7 have no spline walk rows; still C-one `sketch_parity` if it touches add_spline).

Revert: revert. Do not start WP-S2 on the old four-curve split.

#### WP-S2 — Spline editing on par with SolidWorks/Fusion (L)

Goal: today’s Spline tool (`sketch_mode.gd` `Tool.SPLINE` → `SxSketch::add_spline`) stores fit points only. After WP-L7’s one curve, add: draggable fit-point and control-polygon handles (fit-point vs control-point mode toggle); end tangent direction and magnitude handles, plus curvature continuity at ends; Tangent (and where feasible, curvature / equal-curvature) relations between a spline end and lines and arcs, solved by the sketch solver; optional curvature comb; save/load round-trip; undo; property panel showing the point count.

Files: `sketch_mode.gd` spline tool; overlay; `solver_planegcs.cpp` tangent/curvature constraints (PlaneGCS already in-tree); property panel; `automation_bridge.md` if a new click form appears. Catch2 + `rung08_spline_edit.suite` (`tier=full`). WP-L1 / L7 curve.

Change: a sketched spline can be edited by fit points or poles; end tangent to a line solves on the **same** curve the solid uses; comb is a display option default off; undo restores fit points bit-identically (WP-L10 if the bind is still float32 — land L10 first if this check is red on float noise).

Expected delta: about +400 lines.

Check: red first. Catch2: fit-point drag moves the interpolating curve through the new point within 1e-6; Tangent spline-end to a line, solve, end derivative parallel within 1e-6. Then C-one `rung08_spline_edit.suite`: toggle fit/pole, tangent handle, comb on, property point count, undo, save/load. Then C-one WP-L7’s spline test (still interpolating). Rungs 1–7 unchanged.

Revert: revert. Do not ship handles on the Catmull-Rom preview.

#### WP-L8 — Sketch copies keep type and intent (M)

Goal: cases **5, 12, 13, 21, 22**. Kernel `mirror_entities` (all types, Symmetric relations, correct arc angles), offset with a distance relation (lines Parallel + distance, arcs/circles Concentric + linked radius), linear/circular patterns with spacing/angle relations and all entity types, paste of ellipses/splines, thin/open-cut chain from all entity types, no snapped measured values, voice `"fix"` → Fix (not Horizontal).

**First step (unconfirmed):** Catch2 probe of Mirror of an arc about a vertical axis vs a 30° axis; record whether angles are `(−end, −start)` (wrong except horizontal). If already correct, skip the angle rewrite and still add Symmetric + ellipse/spline/elliptical-arc.

Files: `sketch_mode.gd` 3573–3640 mirror; `sketch_tools.cpp` 677–735 offset, 864–918 linear pattern, 961–1008 circular; `sketch.cpp` 1209–1300 thin / open cut; `sketch_mode.gd` 4419–4424 measured jaw; `voice_executor.gd` 195–198. Catch2 `test_mirror_entities.cpp`, `test_offset_relation.cpp`. Rung 7 Mirror Entities (WP4 of that rung) stays.

Change: copies follow the source. Offset Δr is a relation. Voice fix is Fix.

Expected delta: about +300 lines.

Check: red first (including the mirror-arc probe). Catch2: mirror an arc about a vertical and a 30° axis: centre, radius and endpoints equal the analytic reflection within 1e-9 and a Symmetric relation exists; drag the source and the copy follows; offset a circle by 2, change the source radius by 1: the offset radius changes by 1; 6-copy circular pattern: angles 60° ± 1e-9 after a solve with the seed moved; thin feature on line-arc-line has a cylindrical face. Then C-one `rung07_mirror.suite` (Symmetric still present) and `sketch_parity_tests.suite`.

Revert: revert. Do not walk a second dim as the only offset.

#### WP-L9 — Typed values stay exact (S)

Goal: case **4**. Every value-carrying SpinBox commits the parsed text (step 0 or `custom_arrow_step` only); remove the hidden 0.5-step `dim_value` from the dimension path (`sketch_context_chrome.gd` / `main.gd` as cited).

**First step (unconfirmed):** GUT probe that typing 12.34 with a line selected and pressing Enter actually writes 12.51 (or 40 → 40.01) via the hidden 0.5-step `dim_value`. The audit says this only bites when Enter is pressed with entities selected and no single-DOF preview. If the probe is green, still commit parsed text and set step 0 so it cannot regress; record “case 4 path not hit on this tree”.

Files: `sketch_context_chrome.gd` 188–193, 1184–1189, 346–349, 379–382, 741, 814; `main.gd` 1075–1080, 1444–1450, 2082–2096, 3304; `sketch_offset.gd` 72, 237; `sketch_circular_pattern.gd` 65. GUT `run_rung08_typed_values.gd` + `rung08_typed_values.suite` (`tier=ci`).

Change: typing 9.525 / 12.34 / 1.2 / 1.25° / 2.54 / 51.428571° lands in the kernel as that double.

Expected delta: about +120 lines.

Check: red first (the 12.34 probe). Then C-one `rung08_typed_values.suite`: each typed value `== float(text)` in the kernel constraint/feature param. Then C-one a rung-1 Smart Dim suite (dims still apply).

Revert: revert. Do not leave `dim_value` step 0.5 on the apply path.

#### WP-L10 — Doubles across the Godot boundary (M)

Goal: cases **14, 15**. godot-cpp is single precision (`extension_api.json` `"precision": "single"`); sketch and feature bindings take/return doubles (scalar args or `PackedFloat64Array`), no `float` C++ params; drag cancel restores from a kernel snapshot.

Files: `sxcore/src/sx_sketch.cpp` 183–307; ~32 `set_entity_geometry` calls in `sketch_mode.gd` (incl. drag cancel/fail restore 3048, 3061); paste 8310–8335; `sx_document.cpp` 977–994, 1113–1114, 1140, 1155, 1395–1450, 1833–1890, 1894–1895, 1974, 1999–2000. Catch2 via GDExtension round-trip or GUT. WP-L1 feature-param dump.

Change: `add_line(0.1, 1/3, 123.456789012, 7)` → `entity_info` same doubles bit-for-bit; hole Ø6.6 written as 6.6; drag-then-cancel bit-identical; mirror plane normal `(0, 0.7071067811865476, 0.7071067811865476)` stored unchanged.

Expected delta: about +250 lines.

Check: red first. Catch2/GUT: the four acceptance bullets. Then C-one a sketch drag suite and a hole-wizard suite (Ø still applies). Rungs 1–7 walks not launched here.

Revert: revert. Do not keep `float` feature params.

#### WP-L11 — Save/undo round-trip fidelity (S)

Goal: case **18**. Write/read constraint `weak`; unknown entity or constraint type is a load error naming it.

**First step (unconfirmed):** probe `BRepTools::Write` digit count on a saved `.brep` (15 vs 17). Record it. Not a blocker for `weak`; if 15, note it for WP-L12 / a later file-format WP.

Files: `sketch_json.cpp` 118–131 writer, 27–33, 46–47 reader; `sx_sketch.cpp` 482–503. Catch2 `test_sketch_json_weak.cpp`.

Change: a sketch with weak, driving/driven, expression and Fix-locked constraints and every entity type survives save→load and snapshot→restore with JSON equality; unknown type → load error.

Expected delta: about +80 lines.

Check: red first. Catch2 JSON equality + unknown-type error. Then C-py if a sketch-json fixture exists. Rungs 1–7 save/open still work (C-one a reopen suite).

Revert: revert.

#### WP-L12 — Export/import fidelity (M)

Goal: cases **9, 19**. One print tolerance (default **0.01 mm / 0.1 rad**, user-settable, saved in `print.json`) for STL and 3MF, meshing an **isolated copy**; numbers with 17 significant digits; drawing DXF with ARC/CIRCLE/ELLIPSE/SPLINE; DXF import of LWPOLYLINE/POLYLINE with bulges, ELLIPSE and SPLINE (or a refuse list in the status). Also a **fine** view tessellation setting (0.02 mm / 0.1 rad) — display only; measure and picking already use the kernel (`tessellate.hpp` 36–37 is 0.2 mm / 0.35 rad today).

Files: `interop.cpp` 239–240, 329, 341, 462–465, 609–611; `tessellate.cpp` 68–70; `dxf.cpp` 140–196, 82–86; `drawings.cpp` 29–50. Catch2 `test_export_tolerance.cpp`, `test_dxf_curves.cpp`. WP-L1 cylinder vs mesh vertices.

Change: STL/3MF of a Ø3×10 hole plate: every hole vertex within the set tolerance of the true cylinder, max chord sagitta ≤ tolerance; STL and 3MF vertex sets match within 1e-9; 3MF vertex 1234.5678 reads back as 1234.5678; drawing DXF of a Ø20 disc has one CIRCLE of radius 10 exactly; DXF with a bulged LWPOLYLINE imports as lines+arcs with radii within 1e-9.

Expected delta: about +250 lines.

Check: red first. Catch2 acceptance above. Then C-one a rung-5 / rung-7 export suite (`check_rung05/07` still 0 on their 3MFs at the **mesh** bar — tighter tessellation must not fail the 0.2 mm checkers). Assembly WP9 instance 3MF still applies transforms.

Revert: revert. Do not leave STL at 0.1 mm / 0.5 rad as the only path.

### Track A — pipeline assembly

Blocking assembly: WP3 chrome, WP4 two-instance mates, WP5 solver+copy, WP6 pin, WP7×8, WP8 wrench, WP9 export, walk, then whole-plan acceptance.

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

### Track V — visual-survey second batch

Andy, 2026-10-19 3:23 PM CT. Source: [`docs/design/visual-survey.md`](../design/visual-survey.md) (VS#). **Not walk rows.** Headless / pixel acceptance on each WP. Order after blocking assembly if they compete; **must be done before WP11**. Do not restyle films except V1/V2 alpha. Leave the featured film set alone. Update tests pinning old colour constants in the same commit.

#### WP-V1 — Background removal + File → Export Image (PNG) (M)

Goal: View menu **Shop / Scenic / Solid… / Transparent**. Transparent = alpha 0, grid / origin planes / HUD / corners / captions hidden, KeyLight + IBL kept. File → **Export Image…** (`*.png`). VS §8 “How SX should do it” 1–3; VS #11.

Files: `game/scripts/main.gd` (`show_scenic_bg`, View menu, File menu, `_sync_world_background`); capture helper used by Export Image; `game/tests/run_export_image_tests.gd` + `packaging/ci/suites.d/export_image_tests.suite`; `game/tests/run_menu_tests.gd` File-menu ids.

Change: Shop is today’s flat `#292B33`. Scenic is today’s canyon. Solid is a user colour, lighting unchanged. Transparent sets `Environment.BG_COLOR` alpha 0 and `Viewport.transparent_bg` for the grab (Window.transparent_bg stays false). Exported PNG is RGBA. `Window.transparent_bg` tests in `run_rung01_replan13_chrome.gd` stay.

Expected delta: about +250 lines.

Check: C-one `export_image_tests.suite`. The exported spanner (or open-end blank) PNG has a real alpha channel (PNG colour type 6 / `FORMAT_RGBA8`) and composites on white with no charcoal plate (`FilmPresentation.FLAT_BG` / Shop `(0.16, 0.17, 0.20)`). Menu tests still list File ids.

Revert: revert.

#### WP-V2 — Automation screenshot gains alpha (S)

Goal: `_cmd_screenshot` uses the V1 capture path so site posters and tests share it. VS §8 “SolidExpress today” (`_cmd_screenshot` is RGB).

Files: `game/scripts/automation_bridge.gd` `_cmd_screenshot` / `_viewport_image`; V1 capture helper.

Change: screenshot writes the same PNG Export Image would. Transparent backdrop → alpha. Shop/Scenic/Solid stay opaque RGB(A) with a = 1 on the plate. Films are not re-shot.

Expected delta: about +40 lines.

Check: C-one `export_image_tests.suite` (screenshot command path). PNG from `screenshot` in Transparent is colour type 6 and composites on white with no charcoal plate.

Revert: revert.

#### WP-V3 — Real ViewCube (M)

Goal: replace the 3×3 `ViewWidget` with a **70–90 px** perspective cube: labelled faces, iso corners. Hover `Color(0.35, 0.55, 0.75)`. Matters for Front-plane mirror and two-face recess. VS #10.

Files: `game/scripts/view_widget.gd` (rewrite `_draw` / `zone_at` / `click_zone`); `game/scripts/view_hud.gd` (mount the cube; keep `OriginTriadHud`); `game/scripts/orbit_camera.gd` iso-corner poses if `apply_standard_view_id` needs them (no extra View-menu keys); `game/tests/run_viewcube_tests.gd`.

Change: six faces Front/Back/Left/Right/Top/Bottom; eight corners are isometric octants. Click each face/corner to the matching view. Size 70–90 px. Named-view tests stay.

Expected delta: about +220 lines.

Check: C-one `viewcube_tests.suite`. `run_viewcube_tests.gd` clicks each face and each corner to the correct view (yaw/pitch of that standard / iso pose).

Revert: revert.

#### WP-V4 — Grey inactive sketches, not gold pads (S)

Goal: committed sketches are SW-grey, not gold. The spanner keeps one sketch alive across two extrudes. VS #14 (`t0460` / `t0750`).

Files: `game/scripts/sketch_pad_overlay.gd` `PROFILE_COLOR_CLOSED` → `Color(0.55, 0.58, 0.62)`; pad fill alpha stays ~0.03; `PAD_COLOR_CLOSED` / `EDGE_COLOR_CLOSED` drop the gold; open paths stay cyan (`PATH_COLOR`). Tests that pin the old gold, in the same commit.

Change: inactive closed pads read as thin grey, not yellow slabs. Films are not re-shot.

Expected delta: about +40 lines.

Check: C-one a sketch-to-3D / pad suite that reads `PROFILE_COLOR_CLOSED`. Constant is grey `(0.55, 0.58, 0.62)`, not `(0.98, 0.78, 0.08)`.

Revert: revert.

#### WP-V5 — One accent per primary rail verb (S)

Goal: tint Sketch `#6ab0f3`, Smart Dim `#f0c040`, Trim `#e07050`, Extrude `#7ec27a`, Fillet `#c090e0`. Keep stroke icons. VS #13.

Files: `game/scripts/ui_icons.gd` `get_icon` / `_wrap`; `game/tests/run_icon_tests.gd`.

Change: those five glyphs rasterize with the named stroke; every other glyph stays `STROKE` `#dde2ea`.

Expected delta: about +50 lines.

Check: C-one `icon_tests.suite`. Pixel (or SVG stroke) pins for the five accents; other glyphs still `#dde2ea`.

Revert: revert.

#### WP-V6 — SSAO + body albedo 0.66 (S)

Goal: display-only. Shop `Environment.ssao_enabled = true` (radius ~0.02–0.05, intensity 0.6). `BODY_COLOR` → `Color(0.66, 0.67, 0.70)`. Shader default `vec4` matches. SSR stays Scenic-only. No glow. VS #7, #9; VS “Recommended first batch” hold note. So the 1 mm recess reads.

Files: `game/scripts/main.gd` `_make_canyon_environment`; `game/scripts/document_view.gd` `BODY_COLOR` + shader default; `game/tests/run_display_tests.gd` pixel / constant pins. Film look stays.

Expected delta: about +60 lines.

Check: C-one `display_tests.suite`. Pins `BODY_COLOR` `(0.66, 0.67, 0.70)` and `ssao_enabled`. Film `apply_film_look` albedo unchanged.

Revert: revert.

#### WP-V7 — Light sketch sheet only if blue is unreadable (S)

Goal: VS #2 light sheet **only if** rung 6’s blue entities are hard to read on charcoal. Films stay charcoal. VS “Recommended first batch” (#2 hold); P6 decision 13.

Files: `game/scripts/main.gd` `_sync_world_background` only if the readability probe fails; otherwise **skip the sheet** and pin charcoal. `game/tests/lib/film_presentation.gd` `FLAT_BG`; a small suite that records the decision.

Change: if `COLOR_ENTITY` `(0.25, 0.55, 1.0)` stays readable on Shop charcoal, do **not** switch the sketch sheet to `#F4F5F9`. Films stay `FLAT_BG` charcoal either way.

Expected delta: about +40 lines.

Check: C-one the V7 suite. `FLAT_BG` is charcoal. `COLOR_ENTITY` is the rung-6 blue. If the WP skips the sheet, the test says so and Shop during sketch is still charcoal.

Revert: revert (or empty skip-commit if the probe says skip — still a commit that lands the test).

#### WP-V8 — Ellipse/arc colour grammar on the 12-point sketch (S)

Goal: ellipse/arc entities use the rung-6 colour grammar, and the box-end star reads as blue → black (near-white on charcoal) when fully defined. VS #1 (shipped in P6 WP9); **test it** on the 12-point sketch.

Files: `game/scripts/sketch_mode.gd` `COLOR_ENTITY` / `COLOR_CONSTRAINED` (no restyle unless a type bypasses `_entity_draw_color`); `game/tests/run_sketch_color_grammar_tests.gd` (or extend an existing sketch suite) + suite manifest.

Change: none expected to the constants. Draw a 12-point / ellipse+arc sketch; unconstrained entities are `COLOR_ENTITY`; when `last_dofs == 0` they are `COLOR_CONSTRAINED`.

Expected delta: about +80 lines.

Check: C-one that suite. Ellipse, arc, and star edges share the grammar.

Revert: revert.

### WP11 — The single full pass

Goal: one pass on this VM. Counts only. No product edits unless a count is red, and then only the smallest fix, re-run once.

Change: none expected. Run:

`tools/confirm_all.sh`

That script builds, imports, runs the kernel (including WP-L1…L12 / S1 / S2 Catch2), the lints, `test_check_rung02/03/04/05/06/07/08.py`, the registry test, the headless suites (including every `rung08_*.suite` and exactness/spline suites), and the eight walks. Do not also run `make test` or a second suite pass.

Report, and nothing else: the confirm summary lines (build, kernel, lint, godot suite count, rung1 77, rung2 44, rung3 46, rung4 32, rung5 36, rung6 46, rung7 46, rung8 48, each checker tail including `check_rung05` 10/10, `check_rung06` 7/7, `check_rung07` final N/N, `check_rung08` final N/N) plus L/S: WP-L1 CLI, exact spine/loft/draft/boolean/convert/spline/typed/doubles/json/export tests `0 failed`.

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
- Threads on the pin or nut. The Ex 1 nut is a hex with a Ø10 bore. (WP-L2 thread-cutter exactness is the kernel path, not an assembly thread feature.)
- A demo film. `docs/plan/STATUS.md`. Per-body transparency, HLR/tangent-edge modes, foreshortened radius leaders (VS #12, #15). Re-shooting the featured film set.
- Changing rungs 1–7 walk row lists.
- Committing `.sxp` goldens.
- Replacing mesh `check_rung*.py` bars (0.2 mm / 0.5 %) with exact probes — L/S tests sit **beside** those checkers, they do not loosen or replace them.
