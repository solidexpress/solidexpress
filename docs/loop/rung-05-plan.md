# Rung 5 plan — UBC ELEC391 Exercise 3: Pipe Section

**PLAN only, no product code.** One BUILD agent implements this in order, one commit per work package, on the branch it is given. Push that branch. Do not open a PR. Source: *SolidWorks & Tinkerine 3D Printing Tutorial — ELEC391*, Exercise 3 (same PDF as rung 1). Printed pp. 12–16 = PDF file pp. 14–18. Local: `/workspace/sx-loop/rung-01-ubc-wrench/ubc.pdf`, text `ubc.txt`, step-1 figure `img3/e-001.png`. Do not re-read the PDF. The walk rows are in "The checklist" below.

Model: `rung-04-plan.md` package shape (goal, files, change, line delta, one cheap check, revert). Part / frame / walk like `rung-03-plan.md`. Same machinery (`tools/walk/` `Rung`, `automation-bridge.md`).

## Where we are

Baseline: `main` `66a9ac0` (post-rung-4 cleanup: region pick, click budget, hexkey film). Rung 1 walk 77/77. Rung 2 44/44. Rung 3 46/46. Rung 4 32/32. `tools/test_walk_registry.py` freezes those four row lists.

Rung 5 goal: build the pipe section with the **named tools in the PDF's order**, by clicking, and end on a solid that passes `tools/check_rung05.py` at every stage.

Pass bar (all of):

- One solid. Bbox **225 × 225 × 520** mm, min corner `(−112.5, −112.5, −260)`.
- Volume **2704333** mm³ within 0.5 % (analytic; WP1's OCCT replica may replace the digit, not the band). Walls **10.0 ± 0.2**. Both ends open. Eight Ø10 holes per flange on a **94** mm pitch radius, first hole on **+Y**.
- The **mirror** stage is not yet hollow on −Z: a point `(0, 0, −125)` is **inside** the solid. After re-shell it is empty. Original-half walls at `z = +125` stay 10, never 20.
- Every checklist row PASS (no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`). Critique ≥ 9 (rule at the end).
- On the same build: rung 1 walk 77/77, rung 2 44/44, rung 3 46/46, rung 4 32/32, `check_rung01/02/03/04/05.py` at their bars, headless `0 failed`.

Whole-plan acceptance is **WP9 only**. Earlier packages run the one cheap check they name. They do not run `make test`, `make test-godot`, `confirm_all.sh`, or a walk without `--dry-run`.

The critic may scale a print ×0.25. The walk and the checker stay full size.

## Frame (decision, not a question)

Same axis map as rungs 3–4. Front = XY, extrude **+Z**. UBC Ex 1's Top Plane is this ground sketch; Ex 3 step 1 does not name a plane. Click datum **Front**, Sketch.

| Item | PDF | SolidExpress |
|---|---|---|
| Units | MMGS | Already `state.units = mmgs`. Pinned New sentence unchanged. |
| Cylinder | Ø150 circle, extrude **250** (`img3/e-001.png`) | Front sketch, Circle at origin, Smart Dim `Ø150`, Extrude Blind 250. `X,Y ±75`, `Z 0..250`. |
| Shell 1 | Shell 10, **both** circular end faces | Shift+click both planar ends, `strip:shell`, Thickness `10`. Open tube, ID 130. |
| Flange | circular sketch on **one** end, Ø225, extrude 10 | Face `z = 250`, Circle Ø225 at origin, Extrude Op **Fuse**, Blind 10. Caps the tube. `Z 0..260`. |
| Bore + holes | Ø130 on the flange face; Ø10 at **94** from centre, top; Circular Sketch Pattern **8 / 360°**; cut through the **base** | Face `z = 260`. Ø130 at origin. Ø10 at `(0, 94)`, Vertical to origin, distance 94. Pattern the Ø10. Extrude Cut **Blind 10** (the flange thickness). |
| Mirror | Mirror Face = the face **without** the base. Features to Mirror = all **4** (Boss-Extrude1, Shell, Boss-Extrude3, Cut-Extrude2) | `mirror:Features`, plane = `z = 0` face, those four timeline features, `mirror:Ok`. One body. Length 520. **Shell does not carry** (PDF lesson). |
| Re-shell | "shell the mirrored section again" | Second Shell 10 on the solid (−Z) half's end face(s). Original +Z walls stay 10. |
| Fillets | 5 mm on the **inside and outside diameter** of the base, both ends (applied after mirror) | Fillet R5, each flange's **outer face** (annulus): ID Ø130 + OD Ø225. Four circular edges, one feature (Shift+click the second face). |

Figure dimension **24** on p. 17 is clearance `94 − 5 − 65`, not a driving dim. Driving is **94** from centre, as the text says.

Spine of the finished tube: `z = −250 .. +250`, OD 150, ID 130. Flanges occupy `z = 250..260` and `z = −260..−250`.

| | min | max | size |
|---|---:|---:|---:|
| X | −112.5 | 112.5 | 225 |
| Y | −112.5 | 112.5 | 225 |
| Z | −260 | 260 | 520 |

Derived volumes (π exact; WP1 copies into `PART` / `VOLUMES`; OCCT replica may retune `final` after fillets):

| Stage | Meaning | Volume mm³ |
|---|---|---:|
| `cyl` | Ø150 × 250 solid | 4417864.669 |
| `shelled` | wall 10, both ends open | 1099557.429 |
| `flange` | + Ø225 × 10 disk (caps the +Z end) | 1497165.249 |
| `cut` | − Ø130 × 10 cap − 8×Ø10 × 10 | 1358149.774 |
| `mirror` | + solid −Z cylinder + mirrored flange-with-holes | 6034606.788 |
| `reshell` | both halves hollow, no fillets | 2716299.548 |
| `final` | R5 on 4 flange-face circular edges | 2704332.648 |

Mutants, not targets: body-mirror (shell carries) makes `mirror` volume ≈ `reshell`; Through All on the cut, then feature-mirroring that cut, hollows the −Z half (`(0,0,−125)` empty) and volume ≈ 4935049.

First bolt at world `(0, 94, 260)`; the other seven at 45° on radius 94. After mirror, the −Z flange has the same pattern at `z = −260`.

Inside (final): `(70, 0, 125)`, `(70, 0, −125)`, `(80, 0, 255)`, `(80, 0, −255)`. Outside: `(0, 0, 125)` (bore), `(80, 0, 125)` (beyond OD), `(94, 0, 255)` (bolt), `(113, 0, 0)`, `(0, 0, 261)`, `(0, 0, −261)`.

These constants are copied into the checker's `PART` table in WP1. After that the walk reads `check_rung05.py params`, not this file.

## The PDF, step by step → SolidExpress

| # | PDF | SolidExpress | Rows |
|---|---|---|---|
| 1 | New part; sketch and extrude Ø150 × 250 | File → New. Front, Sketch. Circle origin, Ø150. Extrude Blind 250. | N1, A1–A4 |
| 2 | Shell 10, both circular faces | Both planar ends, `strip:shell`, 10. | A5, N2, A6, A7 |
| 3 | Circular sketch on one end, Ø225, extrude 10 | Face `z = 250`, Circle Ø225, Fuse Blind 10. | A8, A9 |
| 4a | Sketch on the base: Ø130 | Face `z = 260`, Circle Ø130 at origin. | A10, A11 |
| 4b | Ø10 at the top, 94 from centre | Circle at `(0, 94)`, Ø10, distance 94, Vertical. | A12, L2 |
| 4c | Circular Sketch Pattern, 8 instances, 360°, entity = the Ø10 | `rail:Pattern` variant `circular`. Count 8, angle 360, centre = origin, entity = the Ø10. | A13, L3, N3 |
| 4d | Extrude Cut through the depth of the **base** | Cut Blind **10**. | A14, A15, A16 |
| 5 | Mirror: face without the base; all 4 features | `mirror:Features`, plane `z = 0`, four features, Ok. One body, −Z half solid. | N4, A17, A18, L4 |
| 5b | Re-shell the mirrored half | Shell 10 on the −Z end face(s). | A19–A21 |
| 6 | 5 mm fillets, ID and OD of the base | Fillet R5, both flange outer faces. | A22, N5, A23 |
| — | save (implied) | Save As `final.sxp`, reopen. | A24, N6, A25 |

Already in the product, no package: File → New MMGS, Front sketch, Circle at origin (`SketchOriginAnchor` `circle.center`), Smart Dim diameter, centre-to-centre distance, two-point Vertical, Extrude Blind / Fuse / Cut, face sketch, additive face select, Fillet-by-face (rung 3), Exit Sketch, Save / Open.

## Gaps → packages

Grep on `66a9ac0`. HAVE = named tool already does this step. PARTIAL = pieces exist, the PDF step does not. MISSING = no such tool.

| PDF | Mark | Evidence (`file : symbol`) | Package |
|---|---|---|---|
| 1 Cylinder Ø150 × 250 | HAVE | `SketchOriginAnchor.RULES` `circle.center`; Extrude Blind (rungs 1–3) | — |
| 2 Shell 10, **two** faces, via `strip:shell` | PARTIAL | Kernel loops `params["faces"]` (`ops_dress.cpp : apply_shell`). `ShellChrome._selected_faces` reads `selected_faces`. Chip gated on **one** planar face (`_planar_face_selected`). `run_select_tests.gd` two-face shell calls `ops_panel._shell()`, not the chip. Unproven on a cylinder. | WP3 |
| 3 Flange Ø225 Fuse 10 | HAVE | Face sketch + `finish:Op` Fuse (rung 3 boss) | — |
| 4a Ø130 on flange | HAVE | Circle + origin pin on a +Z face | — |
| 4b Ø10 at 94, top | HAVE | Centre-distance dim (`_apply_centre_distance_dim`); Vertical two-point (rung 4 WP3) | — |
| 4c Circular Sketch Pattern 8 / 360° about origin | MISSING | `sketch_mode.gd : pattern_selected` — "Approximate circular pattern as rotated copies about **selection centroid**"; `_pattern_count := 3` hardcoded, no count/angle chrome. `sketch_tools.cpp : pattern_entities` is **linear only** (`dx, dy`). Body `apply_circular_pattern` copies bodies, not sketch entities. | WP2 |
| 4d Cut through the **base** (Blind 10) | HAVE | Extrude Cut Blind. (Through All on this sketch would hollow the mirrored half when replayed — forbidden, decision 3.) | — |
| 5 Feature Mirror, 4 features, about a face, one body | PARTIAL | Kernel feature-mode exists (`apply_feature_mirror` / `source_feature_ids`). **Shell** → `fail("feature mirror unsupported type")` and **aborts the whole mirror**. `op == "new"` **creates a second body**. UI `_mirror_source_feature_id` returns **one** fid; `TimelinePanel._selected_fid` is singular. `Mirror…` picks a plane then `_do_mirror` (body or that one feature). | WP4, WP5 |
| 5b Re-shell the solid half; original walls stay 10 | MISSING | No test. `MakeThickSolidByJoin` on the fused body would re-offset the already-open +Z half (20 mm walls — a checker fail). | WP6 |
| 6 R5 on flange ID and OD, both ends | PARTIAL | Face-fillet of an annulus is rung 3 A20 (2 circular edges). Unproven on this pair of flanges as **one** 4-edge feature. | WP7 |
| Checker / walk | MISSING | no `check_rung05.py`; registry has four rungs | WP1, WP8 |

Verified **not** gaps: MMGS New, Front ground sketch, origin circle, Smart Dim Ø, Fuse onto a face, Cut Blind, multi-contour cut (empty selection = all regions, `SketchRegions`), Shift+click faces (`_additive_click`), Fillet R5 on circular edges (rung 3), two-point Vertical, centre-to-centre 94.

## Design rules

New behaviour is a row in a table or a value object. `sketch_mode.gd`, `ops_panel.gd`, and `main.gd` only call the helper. A new file starts with a two-line header that says what it owns.

Tables: `SketchCircularPattern.SPEC` (count, angle, centre rule, entity kinds), `FeatureMirror.POLICY` (`(source type, op) → replay`: fuse New, skip Shell, replay Cut/Fuse), checker `PART` / `STAGES`, walk `Rung`. Timeline multi-select is a list on `TimelinePanel`, not a second `_selected_fid`.

Click-driven UI tests (`.cursor/rules/gdscript-click-driven-tests.mdc`). A new suite is one `packaging/ci/suites.d/<name>.suite` file. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. Never pass `user://` or `res://` into GDExtension.

Do not edit `docs/plan/STATUS.md`. Do not commit `.webm`, `.mp4`, `.avi`, `.mov`, `.vtt`. The four `known-red` manifests stay known-red. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call.

## Decisions (the BUILD agent does not choose)

1. **Front, +Z, flange at +Z, mirror at z = 0.** Cylinder `z = 0..250`. Flange `z = 250..260`. Mirror plane the `z = 0` face, normal ±Z. Mirrored half `z = 0..−260`. Do not sketch on Top (XZ) or extrude along Y.
2. **94 is centre-to-centre.** First hole centre `(0, 94)` in the flange sketch (world +Y). Equal spacing 45°. The figure's 24 is not typed.
3. **Cut is Blind 10, not Through All.** "Through the entire depth of the **base**" is the 10 mm flange. Through All, mirrored, bores Ø130 through the solid −Z cylinder and the `mirror` inside-probe fails. Status of the cut is the existing Blind sentence with 10.
4. **Instances = 8 includes the seed.** Pattern adds 7 copies. Count 1 or 0 refuses and adds nothing. Total angle 360. Centre is the sketch origin (the Ø130 centre), **not** the selection centroid. Equal radius / equal diameter so the copies follow a driving 94 and Ø10.
5. **Four features in the Mirror collector, including Shell.** The PDF selects Shell. Kernel **skips** Shell (no fail of the whole mirror) and records that skip. Result: −Z half solid. Do not implement shell-replay. Do not body-mirror this part.
6. **New extrude, feature-mirrored, fuses onto the target body.** `op == "new"` in `apply_feature_mirror` becomes a Fuse onto the body that owns the mirror face when that target is set. One body. Today's body-mode Mirror (no `source_feature_ids`) still makes a second body (`run_mirror_feature_tests.gd` `test_body_mirror_still_works`).
7. **Re-shell must not thicken the +Z walls.** Contract: wall at `z = +125` stays `10.0 ± 0.2` after the second Shell; `(0, 0, −125)` becomes empty; wall at `z = −125` is `10.0 ± 0.2`. If `MakeThickSolidByJoin` on the whole body fails that, split the solid −Z piece, shell it, fuse back — still one `Shell` feature from the user's click. A Ø130 cut as a stand-in is a critique 8.
8. **Fillet: outer-face ID and OD of each flange.** Four circular edges at `z = ±260`. Not the pipe-to-flange Ø150 junction (the PDF says diameter **of the base**). Face-first Fillet on each annulus (Shift+click the second) is the named pick. One feature.
9. **Two-face Shell uses the chip.** `strip:shell` + `finish:Thickness` `10` + `finish:Ok`. Shift+click the second planar end before the chip. `ops_panel._shell()` is not the walk path.
10. **Critique.** Checker + walk are necessary, not sufficient. Done = one build follows every PDF step with the named tool, score ≥ 9, checker passes. Caps at 8: body-mirror; eight hand-drawn circles; Through All cut; a Hole feature for the bolt circle; a linear pattern; skipping re-shell because the cut already hollowed −Z.
11. **Checkpoints.** `shelled.sxp` after A7, `cut.sxp` after A16, `reshell.sxp` after A21, `final.sxp` after A24.

## BUILD agent rules

- One commit per WP: `Rung 5 WP<n>: <title>`. Push after each commit. Do not open a PR.
- **Revert.** If that WP's cheap check is still red after two honest attempts, `git revert` the commit, write one line in `docs/plan/roadmap.md` §9 naming the check, and continue. Do not loosen a tolerance, drop a `--only`, or edit the tier to get green.
- No new third-party dependency.

Cheap checks (not the full pass):

| Check | Command |
|---|---|
| C-py | the `python3 tools/test_….py` the WP names |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<suite>'` |
| C-dry | `python3 tools/walk_rung05.py --dry-run` plus `python3 tools/test_walk_registry.py` |

## Work packages

### WP1 — Checker `check_rung05.py`

Goal: stages in the volume table, one `PART`, unit tests on a stub, not the app.

Files: new `tools/check_rung05.py`, `tools/test_check_rung05.py`, `tools/implicit_pipe.py` (tests only). `Makefile` `test-tools` gains `python3 tools/test_check_rung05.py`. Reuse `tools/solid.py`.

Change: `PART` holds `OD = 150`, `ID = 130`, `WALL = 10`, `L0 = 250`, `FLANGE_D = 225`, `FLANGE_T = 10`, `HOLE_D = 10`, `PCD = 94`, `N_HOLES = 8`, `FILLET = 5`, bbox min/max as the table, inside/outside points above, `VOLUMES` as the table. `TOL = 0.2` mm. Volume band 0.5 % (1.5 % only if the OCCT `final` tessellation needs it; a wall 12 / 8 mutant must still fail). Probes: `Bbox`, `Volume`, `Watertight`, `Wall` (ray +X at `z = ±125`: hits `±75, ±65`), `OpenEnds`, `Flange` (xy extent 225 at `|z| > 250`), `BoltRing` (empty at the 8 centres on each flange), `SolidHalf` (`mirror` only: `inside((0,0,−125))` True), `HollowBoth` (`final`/`reshell`: that point False). `STAGES`: `cyl`, `shelled`, `flange`, `cut`, `mirror`, `reshell`, `final`. `params` prints `PART` and `VOLUMES` as JSON.

`ImplicitPipe` (tests only) is analytic CSG of those cylinders and holes plus the four R5 rim fillets. `volume()` returns the table (mutants override).

Pin `final` volume from an OCCT 8.0.1 replica of the kernel calls (cylinder, `MakeThickSolidByJoin` both ends, fuse disk, cut, mirrored fuse, second shell, `MakeFillet` 4 edges). If it differs from 2704332.648 by more than 0.2 %, put the OCCT number in `VOLUMES["final"]` and say so in the commit. Do not widen the band to skip the replica.

Expected delta: about +500 lines.

Check: C-py `test_check_rung05.py` is red on the missing module, then green. Mutations that must fail the named check: length 250 after mirror (`bbox`), flange Ø200 (`flange`), 6 holes (`boltRing`), Through All hollow −Z at `mirror` (`solidHalf`), original wall 20 after reshell (`wall`), body-mirror volume at `mirror` (`volume`), a second body (`watertight`). `test_check_rung02/03/04.py` stay green.

Revert: revert the commit if C-py is still red after two attempts.

### WP2 — Circular Sketch Pattern

Goal: 8 instances of a selected circle about the sketch origin, 360°, including the seed. Not about the centroid. Not a body pattern.

Files: new `game/scripts/sketch_circular_pattern.gd` (`class_name SketchCircularPattern`, `SPEC` table: default count 8, angle 360, centre `origin`). `sxkernel/src/sketch_tools.cpp` new `circular_pattern_entities(sketch, ids, cx, cy, count, total_angle)` — copies with Equal radius and Equal to the seed, centres on a construction circle through the seed centre (that circle is construction, not a profile). `sketch_mode.gd` `pattern_selected` variant `circular` calls it; drop the centroid comment. Rail already has variant `circular` (`sketch_tool_spec.gd`). Panel fields `pattern:Count`, `pattern:Angle`, `pattern:Ok` (centre defaults to origin; a click on a point or circle centre overrides). `docs/loop/automation-bridge.md` those ids. Linear `pattern_entities` and body `circular_pattern` are untouched.

Change: Count is total instances. Seed stays. Copies are real circles (profile). Construction layout circle must not enter `profile_face`. Count < 2, angle 0, or empty selection: status, nothing added.

Expected delta: about +280 lines.

Check: red first, then C-one `rung05_csp.suite` (`tier=ci`): face or ground sketch, Ø10 at `(0, 94)`, Count 8, Angle 360, Ok → 8 circles, centres on radius 94 ± 0.2, one at `(0, 94)`, one at `(94, 0)`, seed still there, construction circle not in the profile, DOF of the copies follows the seed (edit Ø10 or 94, copies follow). Count 1 refuses. Centroid of a circle at `(0, 94)` is not the pattern centre (a miss would pile copies around `(0, 94)`). Then C-one `sketch_parity_tests.suite` (linear pattern still copies by `dx, dy`).

Revert: revert. Do not satisfy A13 with seven hand clicks.

### WP3 — Shell two planar ends through the chip

Goal: on the Ø150 × 250 cylinder, Shift+click both ends, `strip:shell`, 10, open tube. Chip path, not `ops_panel._shell()`.

Files: `game/scripts/shell_chrome.gd` only if the red test fails (chip must stay visible with two planar faces in `selected_faces`; apply must pass both ids). Catch2 next to `test_shell_filleted.cpp` or new `test_rung05_shell.cpp`: cylinder, two end faces, thickness 10, volume `1099557` ± 0.5 %, both ends open.

Expected delta: about +80 lines (mostly the suite). Product delta 0 if the chip already applies two faces.

Check: red first, then C-one `rung05_shell.suite` (`tier=ci`): click-build the cylinder (Front, Ø150, Blind 250), Shift+click the `z = 250` and `z = 0` faces (`face_normal` + `plane=`), `strip:shell`, `finish:Thickness` `10`, Ok, status the Shell sentence, one body, export, `check_rung05.py shelled` exits 0. Thickness `80` refused (`_LIMIT`, half of 150), no feature. Then C-one `rung02` shell suite / `select_tests.suite`.

Revert: revert. Do not teach the walk to call `_shell()`.

### WP4 — Feature Mirror kernel: fuse New, skip Shell, one body

Goal: the four PDF features, mirrored about `z = 0`, one body, −Z half solid.

Files: `sxkernel/src/features/ops_transform.cpp` `apply_feature_mirror`. New `FeatureMirror` policy in `ops_transform.cpp` (or `feature_mirror.cpp`): `New` → Fuse onto the target body; `Fuse`/`Cut` → existing replay; `Shell`/`Fillet`/`Chamfer` → skip (continue), do not `fail`. `sxkernel/tests/test_features_mirror.cpp` keeps the one-cut case and the body-mode second-body case.

Change: when `target` is set, `op == "new"` fuses the mirrored tool into that body (no `output_body` for that source). Shell in `source_feature_ids` is a skip, not an error. Unknown types still fail.

Expected delta: about +220 lines.

Check: red first, Catch2 `test_rung05_mirror.cpp`: build cyl → shell both ends → fuse Ø225 × 10 at +Z → cut Blind 10 (Ø130 + 8×Ø10) → `Mirror` with `source_feature_ids` = those four, plane `z = 0`, normal +Z. Expect one body, bbox 225 × 225 × 520 ± 0.2, volume `6034606` ± 0.5 %, `(0,0,−125)` inside, `(0,0,125)` empty, 8 holes on each flange. A fifth test: Shell-only in the list → no-op, original unchanged. `test_features_mirror.cpp` body-mode still two bodies.

Revert: revert. Do not pass this WP by body-mirroring and deleting the extra body.

### WP5 — Mirror command: face + feature list

Goal: the PDF click path. Plane = a planar face. Features = Shift+click timeline rows. Ok. Body-mode one-click Mirror stays for rungs that use it.

Files: new `game/scripts/mirror_features.gd` (`class_name MirrorFeatures`: arm `mirror:Features`, pick `mirror:Plane`, collect `mirror:Add` / Shift+click `timeline:row:…`, ok `mirror:Ok`). `ops_panel.gd` `_arm_mirror` / `_resolve_mirror_pick` / `_do_mirror` call it when the collector is non-empty; empty collector keeps today's body/one-feature path. `timeline_panel.gd`: Shift+click adds to a `selected_feature_ids` list (plain click still one). `automation_bridge.gd`, `docs/loop/automation-bridge.md`.

Expected delta: about +220 lines.

Check: red first, then C-one `rung05_mirror.suite` (`tier=full`): the WP4 part built by clicks through WP2–WP3 tools, `mirror:Features`, click `z = 0` face, Shift+click the four feature rows, Ok, one body, `check_rung05.py mirror` exits 0. `mirror:Ok` with a plane and **zero** features: refused, no second body (N4). One-click `Mirror` on a box (no collector) still body-mirrors (`run_mirror_feature_tests` behaviour via a small click test or the existing suite green).

Revert: revert. Do not walk a body-mirror.

### WP6 — Re-shell the mirrored half

Goal: second Shell 10, −Z half hollow, +Z walls still 10.

Files: `sxkernel/src/features/ops_dress.cpp` `apply_shell` only if the red test fails the wall contract (decision 7). `shell_chrome.gd` unchanged unless the −Z flange outer face is non-planar (it is planar annulus). Catch2 in `test_rung05_mirror.cpp` continues: after WP4's mirror, Shell 10 removing the `z = −260` face (and the `z = 0` plug face if it exists); expect `reshell` volume and walls.

Expected delta: about +150 lines.

Check: red first, then C-one `rung05_reshell.suite` (`tier=full`): the mirrored part, Bottom view, `face_normal=[0,0,−1]`, `plane=−260`, `strip:shell`, 10, Ok, `check_rung05.py reshell` exits 0, and `check_rung05.py` wall at `z = +125` still 10. Then C-one `rung03_part_check.suite` / rung 2 shell (1 mm and 5 mm one-face shells stay).

Revert: revert. Do not cut a Ø130 cylinder.

### WP7 — Fillet R5 on both flange faces

Goal: one Fillet, four circular edges, the final volume.

Files: none expected in product (`FilletPick.POLICY` already Shift+face-adds). New `tests/run_rung05_fillet.gd` only, unless the red test shows the annulus at `z = ±260` is not addressable (`plane=`).

Expected delta: about +120 lines of test. Product 0 if green on first try.

Check: red first, then C-one `rung05_fillet.suite` (`tier=full`): from the reshelled part, Fillet R5, click `z = 260` face (2 edges), Shift+click `z = −260` face (4 edges), Enter, `check_rung05.py final` exits 0. Radius `30` refused, timeline unchanged. Then C-one `rung03_fillet_face.suite` and `run_rung01_replan12_pick.gd`.

Revert: revert the test commit if it stays red after two product-fix attempts; then the walk's A22 is blocked. Do not fillet the Ø150 pipe junction to chase volume.

### WP8 — Walk

Goal: `tools/walk_rung05.py` runs the checklist. Registry freezes the row list. Rungs 1–4 stay frozen.

Files: `tools/walk/registry.py` (`RUNG5_ROWS`, `_RUNG_SPEC["rung05"]`, `install`), new `tools/walk/app05.py`, `tools/walk/rung5/ui05.py`, `tools/walk/rung5/rows05_chunk{1,2,3,4}.py`, new `tools/walk_rung05.py` (same CLI as `walk_rung04.py`). `tools/test_walk_registry.py` gains `FROZEN_ROWS_05`. `tools/confirm_all.sh` gains `unit_rung05`, walk 5 on display `:25` / port `47325`, and the summary lines (`rung5`, `check-final-final.txt`). `docs/loop/README.md` lists this plan and `walk_rung05.py`. `docs/loop/automation-bridge.md` for new click forms.

Change: each checklist row is a method that calls `ui05` helpers and `self.clause(...)`. Chunks and checkpoints are decision 11. Export rows share one 3MF per stage. A25 is the headless evidence row (needs `--a15`; without the flag it is `BLOCKED-by-flag`), same clause names as rung 4 A21.

Expected delta: about +750 lines.

Check: C-dry. Registry test green for five rungs. `walk_rung05.py --rows N1,A1,A2 --dry-run` prints those rows. Do not launch Godot here.

Revert: revert if the registry test is red after two attempts.

### WP9 — The single full pass

Goal: one pass on this VM. Counts only. No product edits unless a count is red, and then only the smallest fix, re-run once.

Change: none expected. Run:

`tools/confirm_all.sh`

That script builds, imports, runs the kernel, the lints, `test_check_rung02/03/04/05.py`, the registry test, the headless suites, and the five walks. Do not also run `make test` or a second suite pass.

Report, and nothing else: the confirm summary lines (build, kernel, lint, godot suite count, rung1 77, rung2 44, rung3 46, rung4 32, rung5 36, each checker tail).

Expected delta: 0.

Check: the summary. A walk row that fails is a product bug; fix it and re-run confirm once. Do not re-run confirm before that fix.

Revert: not this WP. A bad fix-up commit reverts on its own.

## Chunks

| Chunk | Rows | Ends |
|---|---|---|
| 1 | N1 A1 A2 L1 A3 A4 A5 N2 A6 A7 | open tube, `shelled.sxp`, no flange |
| 2 | A8 A9 A10 A11 A12 L2 A13 L3 N3 A14 A15 A16 | +Z flange with bore and 8 holes, `cut.sxp`, length 260 |
| 3 | N4 A17 A18 L4 A19 A20 A21 | length 520, both halves hollow, `reshell.sxp` |
| 4 | A22 N5 A23 L5 A24 N6 A25 | `final.sxp`, checker passed, headless evidence |

36 rows: 25 A, 5 L, 6 N.

## The checklist

**A** action (the PDF step, named tool). **L** look. **N** negative. Clauses are bridge reads or one checker line. Statuses are `[status-trace]` result lines since the row's mark. Numbers from `check_rung05.py params` after WP1.

### Chunk 1 — cylinder and first shell (10)

| Row | Does | Clauses |
|---|---|---|
| N1 | Window first: size ≥ 1272 × 750 or maximized; status bar, File menu, rail inside the window | `window`; `chrome inside` |
| A1 | File → New. Pinned New sentence. `state.units` is `mmgs`. | `new`; `units mmgs` |
| A2 | Datum Front, Sketch. Circle at origin, Smart Dim `Ø150`. One circle, centre origin, DOF 0. | `datum Front`; `sketch`; `diameter 150`; `centre origin`; `dof 0` |
| L1 | Rail labels Circle, Smart Dim, Pattern visible, none clipped. Plane names Front, Top, Right visible. | `rail labels`; `plane names`; `not clipped` |
| A3 | Exit Sketch. Extrude Op New, Distance 250, Ok. Status Blind 250. One body. | `exit`; `extrude`; `status`; `one body` |
| A4 | Export `cyl.3mf`. `check_rung05.py cyl` PASS. Bbox 150 × 150 × 250, min `(−75, −75, 0)`. | `exported`; `cyl` |
| A5 | Select the body. Shift+click `z = 250` and `z = 0` (`face_normal` ±Z, `plane=`). `strip:shell`, Thickness 10, Ok. Status the Shell 10 sentence. Two faces in the feature. | `two faces`; `thickness 10`; `status`; `one feature` |
| N2 | Shell thickness `80`: refused (limit), no second feature, field back to 10. | `refused`; `unchanged`; `field 10` |
| A6 | Export `shelled.3mf`. `check_rung05.py shelled` PASS (walls 10, both ends open, volume). | `exported`; `shelled` |
| A7 | Save As `shelled.sxp`. File exists. Title shows `shelled`. | `saved`; `file exists`; `title` |

### Chunk 2 — flange, pattern, cut (12)

| Row | Does | Clauses |
|---|---|---|
| A8 | Key 3. `face_normal=[0,0,1]`, `plane=250`. Face selected (annulus). Sketch chip. Plane `+Z @ (0,0,250)`. | `face selected`; `is z250`; `sketch on face`; `origin` |
| A9 | Circle at origin, Smart Dim `Ø225`. Exit. Extrude Op **Fuse**, 10, Ok. One body. Bbox max `z = 260`. | `diameter 225`; `op fuse`; `one body`; `z 260` |
| A10 | `face_normal=[0,0,1]` (furthest, `z = 260`). Sketch chip. Plane `+Z @ (0,0,260)`. | `face selected`; `is z260`; `sketch on face` |
| A11 | Circle at origin, Smart Dim `Ø130`. Centre origin. | `diameter 130`; `centre origin` |
| A12 | Circle at `(0, 94)`, Smart Dim `Ø10`, distance to the Ø130 centre `94`. Vertical on the two centres. First hole on +Y. | `diameter 10`; `distance 94`; `vertical`; `on +Y` |
| L2 | Labels `Ø130`, `Ø10`, `94` visible, not piled on the origin. | `labels visible`; `no overlap` |
| A13 | `rail:Pattern`, variant `circular`. Count 8, Angle 360. Entity = the Ø10 (already selected). Ok. Eight profile circles, radius 5, centres on r = 94. | `variant circular`; `count 8`; `eight circles`; `pitch 94` |
| L3 | Eight holes drawn around the flange, equal spacing, first at the top. Construction layout circle is reference, not a fat profile ring. | `eight visible`; `top hole`; `layout construction` |
| N3 | Count `1` then Ok: refused, still one Ø10 plus the Ø130. Esc disarms. Count back to 8. | `refused`; `no extra`; `esc`; `field 8` |
| A14 | Exit Sketch. Extrude Op Cut, End Blind, Distance 10, Ok. Status Blind 10. One body. Length still 260. | `exit`; `op cut`; `blind 10`; `one body`; `length 260` |
| A15 | Export `cut.3mf`. `check_rung05.py cut` PASS (flange, bore, 8 bolts, still open at `z = 0`). | `exported`; `cut` |
| A16 | Save As `cut.sxp`. | `saved`; `file exists` |

### Chunk 3 — mirror and re-shell (7)

| Row | Does | Clauses |
|---|---|---|
| N4 | `mirror:Features`, pick the `z = 0` face, Ok with **zero** features in the collector: refused, still one body, length 260, timeline unchanged. | `refused`; `one body`; `timeline unchanged` |
| A17 | `mirror:Features`, plane = `z = 0` face, Shift+click the four features (cylinder extrude, shell, flange extrude, cut), `mirror:Ok`. Status names Mirror. One body. Not the one-click body Mirror. | `plane z0`; `four features`; `status`; `one body`; `not body mode` |
| A18 | Export `mirror.3mf`. `check_rung05.py mirror` PASS: bbox 225 × 225 × 520, min `z = −260`, `(0,0,−125)` **inside**, `(0,0,125)` empty, 8 holes both flanges. | `exported`; `mirror`; `solid half`; `bbox` |
| L4 | Timeline: sketches / extrude / shell / extrude / cut / **mirror**. Names distinct, none truncated. One body. | `order`; `names distinct`; `one body` |
| A19 | Key 8. `face_normal=[0,0,−1]`, `plane=−260`. `strip:shell`, 10, Ok. Status Shell 10. A second Shell feature **after** the mirror. | `face selected`; `thickness 10`; `status`; `order` |
| A20 | Export `reshell.3mf`. `check_rung05.py reshell` PASS: both halves hollow, walls 10 at `z = ±125`, volume. | `exported`; `reshell`; `walls 10` |
| A21 | Save As `reshell.sxp`. | `saved`; `file exists` |

### Chunk 4 — fillets, save, evidence (7)

| Row | Does | Clauses |
|---|---|---|
| A22 | Select the body, Fillet R5. Click `z = 260` face: 2 edges. Shift+click `z = −260` face: 4 edges. Enter. Status 4 edges 5.00. One new feature. | `armed 5`; `two edges`; `four edges`; `applied`; `one feature` |
| N5 | Radius `30`, Enter: refused, timeline unchanged, picks kept; radius back to 5. | `refused`; `timeline unchanged`; `radius 5` |
| A23 | Export `final.3mf`. `check_rung05.py final` PASS: bbox, volume, walls, bolts, open ends, watertight. | `exported`; `final`; `bbox`; `volume`; `watertight` |
| L5 | Timeline order `… mirror, Shell, fillet`. Names distinct. Both flanges show a rounded ID and OD, not a Ø150 pipe-junction-only fillet. | `order`; `names distinct`; `both rims` |
| A24 | Save As `final.sxp`. File exists. Title shows `final`. | `saved`; `file exists`; `title` |
| N6 | File → New, File → Open `final.sxp`. One body, no status error, length 520. Re-export: `final` PASS. | `reopened`; `one body`; `no error`; `final` |
| A25 | Headless evidence, needs `--a15` (without it: `BLOCKED-by-flag`). Kernel, godot suites `0 failed`, lint, `test_check_rung05.py`, registry. Engine noise only as rung 1 R9 allows. | `kernel`; `godot`; `lint`; `unit`; `registry`; `errors` |

Pass bar for the walk: `PASS 36`, no `FAIL`, `PARTIAL`, `BLOCKED`, or `runner-gap`. Every `check-*.txt` has no `FAIL`. The walk's `[ERROR]` list is empty apart from rung 1 R9 engine noise and the refusals in N2, N3, N4, and N5.

## Out of scope

- A units dialog, or editing the pinned New sentence.
- Through All on the flange cut. Body-mirror of this part. Mirroring Shell for real (the PDF lesson is that it does not carry).
- Fillet of the Ø150 pipe-to-flange junction. Full-round (both rims of the 10 mm disk).
- Circular **body** pattern as a stand-in for Circular **Sketch** Pattern.
- Assemblies (rung 8 / Ex 4). Scale ×0.25 in the walk.
- A demo film. `docs/plan/STATUS.md`. Associative sketches.
