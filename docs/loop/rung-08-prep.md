# Rung 8 prep — UBC ECE ELEC391 Exercise 4: Pipeline Assembly

Analysis only, against this branch `3f2f32a` (rung 7 result `8a5003b` / PR #280 combination spanner, plus these source frames). `origin/main` `628ca50` does not yet include rung 7. Source: *SolidWorks & Tinkerine 3D Printing Tutorial — ELEC391*, UBC ECE Engineering Services, [same PDF as rungs 1 and 5](https://people.ece.ubc.ca/~eng-services/files/tutorials/SolidWorks%20&%203D%20Printing%20Tutorial-R1.pdf). Exercise 4 is a **written** tutorial on PDF pages 20–25 (the ladder entry said 17–22; the actual pages are 20–25). Text: [`ex4.txt`](rung-08-frames/ex4.txt).

**Frames (this pass).** Full-page 200 dpi renders `page-20.jpg` … `page-25.jpg` in [`docs/loop/rung-08-frames/`](rung-08-frames/) plus embedded figures `img/fig-PPP-NNN.png` and [`index.md`](rung-08-frames/index.md). Every *as shown* value, view, mate and click target below is taken from those stills; the file is cited at the point of use (e.g. [page-22.jpg](rung-08-frames/page-22.jpg), [fig-022-007.png](rung-08-frames/img/fig-022-007.png)). The page text is a procedure; dimensions live in the figures.

**Axis map.** Same as rungs 3–5 for the reused pipe: Front = XY (normal +Z), extrude **+Z**, finished pipe `Z ∈ [−260, +260]`. Assembly world keeps that map: pipe axis = world **+Z**, flange faces are Z-planes, bolt circle in XY. The in-context pin is a Front (XY) revolve; after mates its axis is parallel to +Z through a bolt hole. Nut sketch is XY, thickness +Z. Wrench (rung 1) sits on a flange face (XY), jaw opening in that plane.

**Units.** MMGS. The tutorial warns the assembly template may open IPS and says to switch in the bottom-right corner before beginning ([page-20.jpg](rung-08-frames/page-20.jpg) step 1).

**Reused parts (existing fixtures / walks / checkers).** No committed `.sxp` goldens in the tree. An assembly rung would **re-walk** (or replay the GDScript builders) and save, then `insert_sxp`:

| Part | Source | Walk | Checker | In-tree builder | Walk checkpoint `.sxp` (produced, not committed) |
|---|---|---|---|---|---|
| Hex nut (Ex 1) | UBC Ex 1 | `tools/walk_rung01.py` chunk 6 row **A14** (polygon AF 20, Ø10 circle, extrude 7.5, export `nut.3mf`) | `tools/check_rung01.py nut` | none (`nut_fixture.gd` does not exist) | none named; 3MF only |
| Wrench (Ex 2) | UBC Ex 2 | `tools/walk_rung01.py` (canonical 77 rows) | `tools/check_rung01.py wrench` / `blank` / `thick` | many `run_rung01_*.gd` | `blank.sxp`, `cut.sxp`, `wrench-wip.sxp` (`tools/walk/registry.py` rung01) |
| Pipe section (Ex 3) | UBC Ex 3 | `tools/walk_rung05.py` (36 rows) | `tools/check_rung05.py final` | `game/tests/lib/pipe_fixture.gd` (kernel-built, reads `check_rung05.py params`) | `shelled.sxp`, `cut.sxp`, `reshell.sxp` |

`insert_sxp` deep-copies bodies from an external `.sxp` and places instances (first Fixed). A walk that already wrote `wrench-wip.sxp` / a finished pipe `.sxp` can feed Insert Components. The nut today is only exported as `nut.3mf` in A14 — an assembly walk would also **Save** `nut.sxp` (or rebuild via the A14 sketch and `save_sxp`). Re-walking is the honest path; there is no fixture pack to load.

Locked reused numbers (already in those checkers; not re-litigated here):

| Part | Locked | Checker |
|---|---|---|
| Nut | AF **20**, AC **23.094**, thickness **7.5**, bore **Ø10** | `check_rung01.py nut` |
| Wrench | jaw opening **20.0**, bbox **232.5 × 45 × 10**, pivot hole Ø10 | `check_rung01.py wrench` |
| Pipe | OD 150, ID 130, wall 10, L0 250, flange Ø225 × 10, 8× Ø10 on PCD radius **94**, first hole **+Y**, R5 flange fillets, bbox **225 × 225 × 520**, min `(−112.5, −112.5, −260)`, volume **2704332.648** mm³ | `check_rung05.py` `PART` |

## Locked values (from frames)

| Item | Locked value | Frame |
|---|---|---|
| New document type | **Assembly** (not Part). Tutorial tab, Assembly icon boxed in red | [page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png) |
| Units | **MMGS** before placing anything (template may be IPS) | [page-20.jpg](rung-08-frames/page-20.jpg) step 1 |
| Insert | Browse → three SolidWorks parts: **HEX NUT**, **PIPE SECTION**, **WRENCH** | [page-21.jpg](rung-08-frames/page-21.jpg), [fig-021-002.png](rung-08-frames/img/fig-021-002.png), [fig-021-003.png](rung-08-frames/img/fig-021-003.png) |
| Drop / float | Left-click drop anywhere. Drag to confirm free. `(f)` = Fixed → right-click **Float** | [page-21.jpg](rung-08-frames/page-21.jpg) step 3, [fig-021-004.png](rung-08-frames/img/fig-021-004.png) |
| In-context pin | Insert Components dropdown → **New Part**. Sketch on a principle plane (Front / Top / Right boxed) | [page-22.jpg](rung-08-frames/page-22.jpg) step 4, [fig-022-005.png](rung-08-frames/img/fig-022-005.png) |
| Pin profile | R10 head arc, shank **35**, overall **55**, R5 tail arc. Revolve 360°. Unselect Edit Component | [page-22.jpg](rung-08-frames/page-22.jpg), [fig-022-006.png](rung-08-frames/img/fig-022-006.png), [fig-022-007.png](rung-08-frames/img/fig-022-007.png) |
| Copies | Box-select until blue, Ctrl+C / Ctrl+V. Counts: **2** pipe sections, **16** hex nuts, **1** wrench, **8** pins | [page-22.jpg](rung-08-frames/page-22.jpg) step 5, [fig-022-008.png](rung-08-frames/img/fig-022-008.png) |
| Fix ground | Right-click one **PIPE SECTION** → **Fix** | [page-23.jpg](rung-08-frames/page-23.jpg) step 6, [fig-023-009.png](rung-08-frames/img/fig-023-009.png) |
| Concentric (pipes) | Assembly tab **Mate** → both **inside** pipe surfaces. Standard Mate **Concentric** auto-selected. Lock Rotation off | [page-23.jpg](rung-08-frames/page-23.jpg) step 7, [fig-023-010.png](rung-08-frames/img/fig-023-010.png) |
| Coincident (flanges) | Mate the two **base / flange** faces → Coincident | [page-24.jpg](rung-08-frames/page-24.jpg) step 8, [fig-024-011.png](rung-08-frames/img/fig-024-011.png) |
| Concentric (bolt holes) | One bolt hole on each pipe, Concentric, to kill remaining rotation | [page-24.jpg](rung-08-frames/page-24.jpg) step 8 |
| Nut/pin per bore | Two nuts + one pin per Ø10 hole: Concentric (axes) + Coincident (nut face to flange face). Repeat ×8 | [page-24.jpg](rung-08-frames/page-24.jpg) step 9, [fig-024-012.png](rung-08-frames/img/fig-024-012.png); [page-25.jpg](rung-08-frames/page-25.jpg) step 10, [fig-025-013.png](rung-08-frames/img/fig-025-013.png) |
| Optional Lock | Standard Mates **Lock** (or Concentric “Lock rotation”) on nuts vs a pipe face. “Possible but not required” | [page-25.jpg](rung-08-frames/page-25.jpg) step 10; Lock Rotation checkbox in [fig-023-010.png](rung-08-frames/img/fig-023-010.png) |
| Wrench, mate 1 | Bottom face of wrench → flange (“pipe section base”), Coincident | [page-25.jpg](rung-08-frames/page-25.jpg) step 11, [fig-025-015.png](rung-08-frames/img/fig-025-015.png) cyan flange |
| Wrench, mate 2 | Top **inside jaw flat** → one nut flat, Coincident | [fig-025-014.png](rung-08-frames/img/fig-025-014.png) cyan jaw + cyan nut side |
| Wrench, mate 3 | **Bottom curve** of the wrench head → corresponding nut side (tangent / coincident-to-curve) | [fig-025-016.png](rung-08-frames/img/fig-025-016.png) cyan cylindrical jaw underside + nut flat |
| Finished look | Two pipes flange-to-flange, 8 pins / 16 nuts at the **centre joint only**, wrench on one nut | [fig-020-000.png](rung-08-frames/img/fig-020-000.png), [fig-025-013.png](rung-08-frames/img/fig-025-013.png) |

**Unpinned (reasoned).**

1. **Pin shank diameter.** [fig-022-006.png](rung-08-frames/img/fig-022-006.png) never writes a Ø on the rectangle. R5 is a horizontal radius at the tail, from the axis to the shank wall, so **shank Ø10**. That is also the only value that goes through the rung-1 nut bore Ø10 and the rung-5 flange holes Ø10. Treat R5 as both tail-hemisphere radius and shank radius.
2. **Overall 55 vs 10+35+5 = 50.** Hemispherical head R10 (height 10) + shank 35 + hemispherical tail R5 (height 5) = **50**. The figure’s 55 leaves **5 mm** unaccounted. Best fit that keeps the 35 as the **grip** (2× nut 7.5 + 2× flange 10 = 35, exact): keep hemispheres and accept overall **50**, and treat 55 as a drafting leftover. Alternate that hits 55: R5 as a 180° ball-end (height 10) → overall 55, but [fig-022-007.png](rung-08-frames/img/fig-022-007.png) shows a **flat equatorial collar**, i.e. a hemisphere, not a ball. Checker uses the 50 mm hemisphere stack; 55 is a mutant.
3. **In-context sketch plane.** [fig-022-005.png](rung-08-frames/img/fig-022-005.png) boxes Front / Top / Right equally (“any of the principle planes”). Front is the rung convention.
4. **Which flanges mate.** [fig-024-011.png](rung-08-frames/img/fig-024-011.png) is two full pipe sections (flange at each end) joined **end-to-end** at one flange pair. Outer flanges stay empty. Nuts only at that centre joint ([fig-025-013.png](rung-08-frames/img/fig-025-013.png)).
5. **Which nut gets the wrench.** [fig-020-000.png](rung-08-frames/img/fig-020-000.png) puts the wrench on the centre joint, handle in the flange plane. Unpinned which of the 8; checker may pick the **+Y** hole `(0, 94)` (rung 5 first bolt) or whichever instance the walk mates.
6. **Nut thread.** None. The Ex 1 nut is a hex with a Ø10 bore, not a tapped M10. The pin is a plain revolved pin, not a bolt. No thread feature in this exercise.
7. **Clearance.** Jaw opening 20.0 vs nut AF 20.0 is an exact fit ([fig-025-014.png](rung-08-frames/img/fig-025-014.png)). Pin Ø10 in hole Ø10 is a line fit. The tutorial never adds a gap.

## 1. Demands (source order)

Lesson: new assembly; insert the three earlier parts; in-context revolved pin; copy to 2 / 16 / 1 / 8; Fix one pipe; Concentric + Coincident + bolt-hole Concentric to fully fix the two pipes; nut/pin mates ×8 bores; optional Lock; wrench on a nut.

1. **New Assembly, MMGS.** File → New → Assembly (tutorial template). Switch units to MMGS if the corner still says IPS ([page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png)).
2. **Insert Components, Browse**, pick HEX NUT + PIPE SECTION + WRENCH together ([page-21.jpg](rung-08-frames/page-21.jpg), [fig-021-003.png](rung-08-frames/img/fig-021-003.png)).
3. **Drop** each with a left click. **Drag** to confirm they float. Right-click any `(f)` component → **Float** ([fig-021-004.png](rung-08-frames/img/fig-021-004.png)).
4. **Insert → New Part** (in-context). Pick a principle plane. Sketch the pin outline ([fig-022-006.png](rung-08-frames/img/fig-022-006.png)): axis line; R10 head; 35 shank; 55 overall; R5 tail. **Revolved Boss/Base 360°**. Unselect **Edit Component** ([page-22.jpg](rung-08-frames/page-22.jpg), [fig-022-007.png](rung-08-frames/img/fig-022-007.png)).
5. **Copy** with box-select + Ctrl+C / Ctrl+V until the tree has **2** pipes, **16** nuts, **1** wrench, **8** pins ([page-22.jpg](rung-08-frames/page-22.jpg) step 5, [fig-022-008.png](rung-08-frames/img/fig-022-008.png)). One of each already exists from step 2, so copies are +1 pipe, +15 nuts, +7 pins.
6. **Fix** one pipe section ([fig-023-009.png](rung-08-frames/img/fig-023-009.png)).
7. **Mate → Concentric** on the two pipe **inner** cylinders ([fig-023-010.png](rung-08-frames/img/fig-023-010.png) faces 2 and 3, Mate tool 1, green check 4). Unfixed pipe then slides/rotates on that axis only.
8. **Mate → Coincident** on the two flange **base** faces. Then **Concentric** on one bolt hole from each pipe. Pipes fully fixed ([page-24.jpg](rung-08-frames/page-24.jpg) step 8, [fig-024-011.png](rung-08-frames/img/fig-024-011.png)).
9. **Per bore:** Concentric pin axis to hole axis; Concentric each nut bore to the same axis; Coincident each nut face to the flange back face. One pin, two nuts, pin head on one nut, tail on the other ([fig-024-012.png](rung-08-frames/img/fig-024-012.png)).
10. **Repeat ×8** (16 nuts, 8 pins). Optional **Lock** so nuts cannot spin ([page-25.jpg](rung-08-frames/page-25.jpg) step 10, [fig-025-013.png](rung-08-frames/img/fig-025-013.png)).
11. **Wrench:** Coincident wrench bottom → flange; Coincident inner jaw flat → nut flat; mate the wrench-head **curve** to the opposite nut side ([fig-025-015.png](rung-08-frames/img/fig-025-015.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png), [fig-025-016.png](rung-08-frames/img/fig-025-016.png)). Done ([fig-020-000.png](rung-08-frames/img/fig-020-000.png)).

UI along the way: New Assembly template, units chip, Insert Components browse (multi-file), component drag, Float/Fix in the tree, Insert → New Part / Edit Component, origin-plane sketch, Revolve 360°, box-select copy, Mate PropertyManager (Concentric / Coincident / Lock / Lock Rotation), face picks on instances, Flip Mate Alignment (not used here).

## 2. Gap critique

Grep / read on `3f2f32a` (this branch = rung 7 + frames). HAVE = the named tool does this step. PARTIAL = pieces exist, the tutorial step does not. MISSING = no such tool. Assembly chrome **does** exist (the ladder guess “no assembly mode yet” is stale); it is a **part document with instances**, not a SW-style assembly document.

What exists today (probed, not a new test):

- **Document:** `document_view.gd` `new_document` always seeds an empty **part**, `units = mmgs`, `OriginPlanes.seed`. File → New sentence is “empty part, Top plane (XY)”. No Assembly template, no IPS trap.
- **Instances:** `Document::add_instance`, transform, `fixed` flag. Viewport draws instances as tinted copies of the source mesh (`_refresh_instances`).
- **Insert Components:** `sx::insert_sxp` deep-copies bodies from another `.sxp`, places instances, **Fixes the first** into an empty instance list, records `source_path`. Insert → Components… + AssemblyPanel button. Source bodies auto-hidden (`main.gd` `insert_components_from`). Kernel `[insert_sxp]`, UI `run_insert_component_tests.gd`.
- **Fix / Float:** `set_instance_fixed` upserts/removes a `MateType::Fixed`. AssemblyPanel lock/unlock. `(f)` prefix on the name. Drag refused while Fixed.
- **Mates (kernel):** `Fixed`, `PlaneCoincident`, `PlaneParallel`, `Concentric` (cylindrical faces only), `Fastened` (implicit connectors). Sequential closed-form placer (`mates.hpp`: no iterative solver). `instance_a` may be null (ground) or an instance. Concentric **refuses `offset <= 0`** at `add_mate` (clearance gate); `apply_mate` then ignores offset and only colines axes, leaving axial slide free.
- **Mates (UI):** AssemblyPanel type list `fastened / plane_coincident / plane_parallel / concentric / fixed` plus joints. Armed flow is **“click ground face, then instance face”** (`assembly_panel.gd` `_arm_mate`). `_instance_for_source` returns empty when **more than one instance shares a source body** — exactly this exercise’s 2 pipes / 16 nuts / 8 pins.
- **Copy:** Edit Copy/Paste of **bodies**; Paste Special → “as instance”. AssemblyPanel **Place instance of selection** (offset 30 mm) and **Pattern around joint**. Not box-select-a-component + Ctrl+C/V.
- **In-context:** `FeatureType::InContext` + marking-menu “In-context pad” captures a neighbor snapshot and builds a **20×20 box** (`apply_in_context`). Not Insert → New Part, not sketch-on-assembly-plane, not Edit Component.
- **Revolve 360°:** HAVE in a **part** sketch (`finish_revolve` / `BRepPrimAPI_MakeRevol`). Available inside the assembly document only as a ground-body feature, not as a new component.
- **3MF:** `export_3mf` tessellates **bodies at identity**, not instances at their transforms (`interop.cpp` `collect_mesh`). Hidden insert-source bodies would dump stacked at the origin. Assembly-as-placed cannot be checked with today’s 3MF path.
- **Lock / tangent mates:** no `MateType::Lock`, no cylinder-to-plane tangent. Concentric “Lock rotation” checkbox in SW ([fig-023-010.png](rung-08-frames/img/fig-023-010.png)) has no SX counterpart.

| # | Demand | Mark | What the code does |
|---|---|---|---|
| 1 | New Assembly, MMGS | **MISSING** / PARTIAL | File → New is always a part, already MMGS. No template picker, no IPS. A user can start a part and insert components into it. |
| 2 | Insert 3 components from files | PARTIAL | Insert → Components… browse is **one `.sxp` at a time**, not three SW files in one Open dialog ([fig-021-003.png](rung-08-frames/img/fig-021-003.png)). Works if nut/wrench/pipe were saved as `.sxp`. Those files are **not in the repo**. |
| 3 | Drop anywhere, drag, Float | PARTIAL | First insert is auto-Fixed (SW-like). Float button HAVE. Drop-at-click and free drag HAVE for unfixed instances. No `(f)` in a FeatureManager tree; AssemblyPanel list instead. |
| 4 | Insert → New Part, sketch, Revolve 360°, Edit Component | **MISSING** | No New Part-in-assembly. In-context pad is a neighbor box, not a sketch. Revolve HAVE only as a part feature on a ground body. **First named-tool stop** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)). |
| 5 | Box-select copy to 2 / 16 / 1 / 8 | PARTIAL | Place instance copies one body once. Pattern around joint needs a joint axis (bolt-circle pattern exists as a **how-to**, not as Ctrl+V). Body Ctrl+C/V duplicates solids, not instances. |
| 6 | Fix one pipe | HAVE | AssemblyPanel lock, or `set_instance_fixed`. |
| 7 | Concentric two pipe bores | PARTIAL / **MISSING in UI** | Kernel Concentric on cylinders HAVE (pliers tests, instance↔instance in the API). UI only accepts **ground then instance**, and `_instance_for_source` breaks once two pipes share a source. Default Offset 0 **rejects** the mate (`offset <= 0`). Click-through of [fig-023-010.png](rung-08-frames/img/fig-023-010.png) cannot land. |
| 8 | Coincident flange faces + Concentric bolt holes | PARTIAL | `plane_coincident` HAVE (planar faces, oppose-normals, Flip). Same UI/source-body limits as 7. Bolt-hole Concentric same as 7. Sequential placer: the hole mate can fight the bore mate if apply order is wrong; SW’s solver holds all three. |
| 9 | Nut/pin coincident + concentric per bore | PARTIAL | Same mate types. 16 nuts / 8 pins are many instances of two sources — UI resolver returns `""`. Head/tail hemispheres are **spheres**, not cylinders; Concentric needs `GeomAbs_Cylinder`. Nut bore and pin **shank** are cylinders and can concentric. Pin-head-to-nut-face is plane coincident (nut face) plus the hemisphere just sitting there (no mate on the sphere). |
| 10 | ×8, optional Lock | PARTIAL / MISSING | Repeat is 8× the UI gap. **Lock** mate MISSING. Optional, so not a stop if 9 works. |
| 11 | Wrench: flange coincident, jaw-flat coincident, head-curve to nut | PARTIAL / **MISSING** | Plane coincident HAVE for the flange and the jaw flat (two planes). Jaw opening 20 vs nut 20 AF is a geometry check, not a new tool. Third mate is cylinder/torus **tangent to a plane** ([fig-025-016.png](rung-08-frames/img/fig-025-016.png)) — no such mate. Fastened would over-lock. |

**Readiness.** A named-tool click-through of this exercise **stops at step 1** if “New Assembly” must exist as a document type. Granting File → New (part, MMGS) as a stand-in, Insert Components can pull `.sxp` files **if the user has them**; the tree does not. Granting saved nut/wrench/pipe `.sxp`, the user can insert, Float, and Fix.

The **first hard stop on this tree** is **Insert → New Part** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)): the pin cannot be drafted as a component inside the assembly. A workaround (new ground-body sketch + Revolve 360° + Place instance) builds the solid but is not in-context and is not a component until instanced.

A second, independent stop lands the moment two pipes must be mated: **the Mate UI cannot pick instance↔instance**, and cannot disambiguate two instances of one source. Kernel `add_mate("concentric", inst_a, face_a, inst_b, face_b, offset>0)` works in tests; the click path does not.

A third stop is the wrench **curve** mate ([fig-025-016.png](rung-08-frames/img/fig-025-016.png)).

**Risks, largest first.**

- **No assembly document / no in-context New Part.** The exercise *is* “drafting parts within assemblies”. Without it the pin is a separate part, and the rung does not prove in-context.
- **Mate UI is ground→instance and unique-source.** This assembly is 27 instances of 4 sources. The click path cannot name “pipe 2’s bore” vs “pipe 1’s bore”.
- **Sequential placer, not a solver.** Three mates to fully fix two pipes, then ~24 nut/pin mates. Later `apply_mate` overwrites instance B’s transform; it does not jointly satisfy the set. 8 pins on one rigid pair of pipes may still work if each pin is instance_b and the pipes are already fixed. Nuts that must sit on *both* a hole axis and a flange plane need two mates on the same instance — the second can break the first.
- **Concentric offset gate (`offset <= 0` rejected) and cylinders-only.** Default UI offset 0 never adds the mate. Spheres (pin heads) cannot concentric.
- **No Lock, no tangent.** Optional Lock is skippable. The wrench’s third click is not.
- **No component box-copy.** Pattern-around-joint is the nearest 8-off tool, and it wants a joint, not a mate.
- **3MF ignores instance transforms.** `check_rung08` cannot be “export assembly.3mf and bbox it” on this exporter.
- **No nut `.sxp` in the walk.** A14 writes `nut.3mf` only.

## 3. Checker numbers

Locked assembly from the stills + reused checkers. Pipe axis +Z, pipe 1 at identity (rung 5 frame). Pipe 2 translated **+520** mm in Z so the +Z flange outer of pipe 1 (`Z = 260`) is coincident with the −Z flange outer of pipe 2 (`Z_local = −260`). Mating plane `Z = 260`. Nuts on the **backs** of those flanges (`Z = 250` and `Z = 270`). Pin axes = the 8 bolt axes.

Throwaway Python (not committed); π exact.

**Pin** (reasoned profile, §Unpinned). Axis +Y in its own part; origin at the tail pole. Head hemisphere R10, shank Ø10 × 35, tail hemisphere R5.

\[
V_\mathrm{head} = \tfrac{2}{3}\pi 10^3 = 2094.395,\quad
V_\mathrm{shank} = \pi 5^2 35 = 2748.894,\quad
V_\mathrm{tail} = \tfrac{2}{3}\pi 5^3 = 261.799
\]

\[
V_\mathrm{pin} = 5105.088\ \mathrm{mm}^3
\]

| | min | max | size |
|---|---:|---:|---:|
| X | −10 | 10 | 20 |
| Y | 0 | 50 | 50 |
| Z | −10 | 10 | 20 |

Overall **50** (figure 55 is the unpinned extra). Mutant `V_55` with 5 mm extra Ø10 shank = 5497.787, bbox Y 55. Mutant ball-end tail (R5 sphere, overall 55) = 5366.887.

After mates the pin axis is world +Z, tail toward +Z or −Z depending on which nut is the head. Grip 35 mm exactly fills nut 7.5 + flange 10 + flange 10 + nut 7.5. Head R10 sits on one nut face; tail R5 on the other ([fig-024-012.png](rung-08-frames/img/fig-024-012.png)).

**Pipes.** Two copies of the rung-5 solid, flange-to-flange:

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

`(0, 94)`, `(−66.468, 66.468)`, `(−94, 0)`, … . Each pin axis is the line through that XY at every Z. Nut faces coincident with `Z = 250` (pipe 1 back) and `Z = 270` (pipe 2 back). Nut AF 20, so a nut centred on a hole extends ±10 across-flats in the tangent direction.

**Wrench.** Bottom face on a flange back (`Z = 250` or `270`). Inner jaw flats 20 mm apart, coincident with a nut’s two (or one) flats — **jaw 20.0 vs nut 20 AF**, zero gap ([fig-025-014.png](rung-08-frames/img/fig-025-014.png)). Bbox of the wrench alone is 232.5 × 45 × 10. Placed on the +Y nut with the handle roughly +X (tangential, stills do not pin the angle), the handle runs ~210 mm past the nut: assembly X max ≈ **210**, X min still **−112.5**. Y stays inside ~±116. That is a **placement assumption**; the pass bar should check the three mates, not a frozen handle compass.

**Assembly bbox (pipes + nuts + pins + wrench, wrench assumption above):**

| | min | max | size |
|---|---:|---:|---:|
| X | −112.5 | ~210 | ~322 |
| Y | −112.5 | 112.5 | 225 |
| Z | −260 | 780 | 1040 |

Pin heads at the joint (`Z ≈ 232.5 … 282.5`) sit inside that Z span. Nuts at r = 94, AC 23.094, stay inside the flange Ø225. The wrench is the only part that grows XY beyond 225.

**Tolerance.** Pin analytic (Pappus/hemisphere) error is 0. Length 50 vs figure 55 is the **dominant** pin uncertainty (~10 % of V). Treat

\[
V_\mathrm{pin} = 5.105\times 10^3\ \mathrm{mm}^3,\quad \mathrm{bbox}\ 20\times 50\times 20
\]

as a **±10 %** volume band until an OCCT replica of [fig-022-006.png](rung-08-frames/img/fig-022-006.png); then 0.5 % like rung 5. Linear ± **0.2 mm** on pin bbox and on pipe/nut/hole probes. Assembly Z 1040 and flange 225 are exact from rung 5. Wrench XY envelope is **not** a pass bar until the handle direction is locked by a walk; the jaw/nut coincidence is.

**Pass bar (`check_rung08`).** Same shape as `check_rung05.py` / `check_rung07.py`: `params` JSON, stages, 0.2 mm, volume band. Because `export_3mf` does not apply instance transforms, the checker should consume an **assembly dump** (host `.sxp` via a small kernel probe, or a JSON of instance transforms plus per-body 3MF), not a single merged 3MF of hidden source bodies.

Proposed stages:

| Stage | What | Checks |
|---|---|---|
| `pin` | Revolved pin only | bbox 20×50×20, volume `V_pin` ±10 % then 0.5 %, watertight 1 body, inside `(0, 25, 0)` (shank), outside `(0, −1, 0)`, `(0, 51, 0)`, `(11, 45, 0)` (past head) |
| `pipes` | 2 pipes, 3 mates (concentric bore, coincident flange, concentric hole) | instance count 2; pipe 1 fixed; combined bbox Z size 1040 ± 0.5; axes colinear; one bolt axis shared |
| `bolted` | + 16 nuts + 8 pins | 8 pin axes through the 8 hole axes (radial error ≤ 0.2); each nut face within 0.2 mm of `Z=250` or `Z=270`; 16× AF 20, bore Ø10 |
| `final` | + wrench | wrench bottom on a flange plane; inner-jaw gap 20.0 ± 0.2 on a nut AF; jaw-flat coincident (point-on-plane ≤ 0.2) |

**Mutants, not targets.** Pin shank Ø8 (falls through) or Ø12 (will not enter). Overall 55 with extra shank (tail floats off the nut). Mating the **outer** empty flanges instead of one end of each pipe (bbox Z 520, no centre joint). Nuts on only one side. Wrench jaw 25 (rung 7 hex) instead of 20. Skipping the bolt-hole Concentric (pipes still spin). Merged 3MF of source bodies at the origin (bbox ~ pipe ∪ nut ∪ wrench at 0, not 1040 long).

Inside (assembled, locked): pipe wall `(70, 0, 125)`, `(70, 0, 520)` (pipe 2), nut metal `(0, 94+8, 253.75)` (approx). Outside: pipe bore `(0, 0, 125)`, past flange `(113, 0, 0)`, past ends `(0, 0, −261)`, `(0, 0, 781)`, through a bolt `(0, 94, 255)` (hole, empty of pipe; the pin fills it at `bolted`).

## 4. Ranked gaps

Most blocking for *this* tutorial’s named tools first. Size is a gut order-of-magnitude (S < 1 WP, M ~1–2, L several).

| # | Gap | Size | Subsystem |
|---|---|---|---|
| 1 | Instance↔instance mate UI (not ground-only); disambiguate many instances of one source | L | UI (`assembly_panel.gd` `_arm_mate` / `_instance_for_source`); feature tree |
| 2 | Insert → New Part in the assembly (in-context sketch + Revolve as a **component**, Edit Component) | L | document/data model, UI, feature tree. Today’s `InContext` box is the wrong feature |
| 3 | Mate solver that **holds** several mates on one instance (sequential placer overwrites) | L | assembly solver (`mates.cpp` `solve_mates`). Needed once nuts have both concentric and coincident |
| 4 | Concentric: allow offset 0 (axis mate); default UI 0 must succeed. Sphere/cone later | S–M | kernel `Document::add_mate` gate; UI Offset spin default |
| 5 | Component copy (box-select instance, Ctrl+C/V) to the 2/16/1/8 counts | M | UI / instances. Pattern-around-joint is a cousin, not this |
| 6 | Tangent mate (cylinder/torus to plane) for the wrench-head curve | M | kernel `MateType` + `apply_mate`; UI type list |
| 7 | 3MF (or checker dump) of **instances at transforms**; hide-vs-export | M | 3MF export (`collect_mesh`), tests |
| 8 | New Assembly document type / template (optional if part+instances stay the model) | S–M | document/data model, File → New |
| 9 | Lock mate / lock rotation (optional in the PDF) | S | kernel + UI |
| 10 | `check_rung08.py` + walk + nut `.sxp` save from rung 1 | M | tests |
| 11 | Multi-file Insert browse (three parts in one Open) | S | UI |

Already in the product, no package: File → New MMGS part, Insert Components from one `.sxp`, Fix/Float, Place instance, Pattern around joint, kernel `plane_coincident` / `concentric` / `fixed` / `fastened` / `plane_parallel`, Flip alignment, Revolve 360° in a part, AssemblyPanel list, explode, instance undo, origin planes, nut/wrench/pipe **part** walks.

**Staging for a rung-8 plan** (split into WPs, do not land all of §4 in one BUILD):

1. **WP-A — clickable mates on copies.** Instance↔instance picks; pick an instance (not only a source body); Concentric offset 0. Cheap check: two inserted cylinders, concentric+coincident, second slides then locks. Unblocks steps 7–8.
2. **WP-B — copies.** Instance clipboard or “Place N copies”. Cheap check: 8 instances of one nut.
3. **WP-C — in-context pin.** New Part-in-assembly *or* an explicit “create component from this body” after a ground revolve. Cheap check: revolve R10/35/R5, one instance, `check_rung08 pin`.
4. **WP-D — solver that keeps two mates.** Nut concentric + coincident together. Cheap check: one nut on one bored plate.
5. **WP-E — wrench tangent + check_rung08 final.** Tangent mate (or an accepted two-coincident stand-in if the curve mate is deferred). Walk the PDF order. Nut `.sxp` from rung 1.
6. **WP-F — export / optional Lock / New Assembly chrome.** After the solid assembly exists.

Frame-grab list from this pass is **done**. Remaining uncertainty is the pin 55 vs 50 (stated) and which nut/handle angle the wrench uses, not missing stills.

## Keep or swap

**Keep UBC Ex 4.** Extractable procedure (11 numbered steps, every click target on a page still). Pin dims are in [fig-022-006.png](rung-08-frames/img/fig-022-006.png) (R10 / 35 / 55 / R5); the one unpinned radius is reasoned from the same figure plus the Ø10 bores this ladder already locked. It **reuses** the rung-1 nut, rung-1 wrench, and rung-5 pipe, so a broken jaw or a drifted bolt circle fails here. It is the first assembly rung that **proves the 20.0 jaw fits the 20 AF nut** ([fig-025-014.png](rung-08-frames/img/fig-025-014.png)) — the print-first reason this ladder exists.

The jump from rung 7 is **large** (document model, mate UI, solver, in-context, copies, export). That is scope, not a reason to swap the exercise. Split implementation as §4 staging; do not replace the part.

**Not chosen: SOLIDWORKS “Learn SOLIDWORKS Lesson 2 Assembly” (Tutor2)** [au8Vdnw-XyU](https://www.youtube.com/watch?v=au8Vdnw-XyU). Narrated, official, has dims — a cleaner *first assembly* video. It would **not** reuse the wrench+nut+pipe, so it would not catch rung-1/5 regressions and would not prove the jaw fit. Keep it as the listed alternate if Ex 4 is dropped for size, not as the default.

Other table rows (GrabCAD wrench, needle-nose series, Scoilnet, Cudacountry socket) stay rejected for the reasons already recorded.

---

**Final report**

- **Head:** `3f2f32a` (rung 7 `8a5003b` + Ex 4 frames).
- **Pin:** bbox **20 × 50 × 20** mm, **V = 5105 mm³** (R10 hemi + Ø10×35 + R5 hemi). Figure overall 55 is unpinned; ±10 % until OCCT replica.
- **Assembly bbox:** pipes **225 × 225 × 1040**; with wrench on a flange, XY grows to ~**322 × 225 × 1040** (handle direction assumed).
- **Click-through stops** at **Insert → New Part** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)); the next wall is **instance↔instance Mate** ([fig-023-010.png](rung-08-frames/img/fig-023-010.png)).
- **Top 5 gaps:** (1) instance↔instance mate UI, (2) in-context New Part, (3) multi-mate solver, (4) Concentric offset-0, (5) component copy.
- **Verdict: keep UBC Ex 4.**
