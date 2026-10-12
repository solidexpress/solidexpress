# Rung 3 plan — SOLIDWORKS "Lesson 1: Parts" (boss, offset cut, fillets, shell, section)

**PLAN only, no product code.** One BUILD agent (Cursor CLI, grok-4.7 medium) implements this in one PR, in the order of the work packages below. Source: SOLIDWORKS' official video *Tutorial – Learn SOLIDWORKS Lesson 1: Parts* (https://www.youtube.com/watch?v=dQMS8KuDGoM). Everything the BUILD agent needs from the video is in "The video, step by step"; it does not re-watch it.

Model: `rung-02-plan.md`. Same machinery (`tools/walk/` `Rung` descriptor, `automation-bridge.md`, the `Solid` / `Probe` / `STAGES` checker layering), same verdict rules (R1–R10 of `rung-01-replan-21.md`, plus the rung-2 additions), a new part, a new checker, a new walk. History: `git log -- docs/loop`.

## Where we are

Baseline: `main` `58eb22f`. Rung 1 (wrench) walk: 77/77. Rung 2 (box) walk: 44/44. `tools/test_walk_registry.py` freezes both row lists and must stay green.

Rung 3 goal: build the part with the **named tools in the video's order**, by clicking, through the automation bridge, and end with a part that passes `tools/check_rung03.py` at every stage and every row of the checklist below.

Pass bar (all of): bbox 120 × 120 × 55, footprint centred on the origin; Ø70 boss 25 above a 30 mm base; Ø60 hole through base and boss; R5 on the four vertical corners, the front outer edges and the boss root; R1.5 on both rims of the front annulus; 1.0 mm walls with the back open; every checklist row PASS (no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`); the section view shows the cut (capped) on the Top plane; critique score ≥ 9 (rule at the end).

Whole-plan acceptance: the rung 3 walk all-pass at 1280 × 800, **plus** the rung 1 walk 77/77 and the rung 2 walk 44/44 (`SX_AUTOMATION=1 python3 tools/walk_rung01.py` / `walk_rung02.py --a15`), every checker (`check_rung01/02/03.py`) at its bar, headless suites `0 failed` (`KEEP_GOING=1 make test-godot`, `make test-kernel`, `make test-tools`).

## Depth: 30 (video), not 50 (Student Guide) — recorded decision

The SOLIDWORKS *Student's Guide* Lesson 1 text gives a base depth of **50**. The narrated video says "enter **30** for depth". This rung follows the **video**; the guide's 50 is not used anywhere. The checker's `PART` table is the only place the number lives (`H0 = 30`), and one mutation test builds a 50 mm base and expects `bbox` to fail, so the wrong source cannot pass unnoticed. Every other video number is the same as the guide's.

## The part and the frame (decision, not a question)

Same frame as rung 2: one sketch datum, the XY ground plane; extrusion runs along **+Z**; SOLIDWORKS axes equal SolidExpress axes.

| Item | Video | SolidExpress |
|---|---|---|
| Sketch plane | Front plane, Center Rectangle from the origin | ground sketch (key `3`, Top view), rail `Rect` + variant `Center`, centre at `(0,0)` |
| Dimensions | 120 and 120, "the black sketch is fully defined" | Smart Dim two sides → `120`, `120`; DOF chip `0` |
| Base | Extruded Boss, Blind (default), 30 | Extrude Blind 30 along +Z: `X −60..60, Y −60..60, Z 0..30` |
| "Front face" | the face you look at | the **+Z face** (`z = 30`); "Normal To" = View key `3` (Top); trimetric = key `7` |
| Boss | sketch on the front face, circle at the origin, Ø70, depth 25 | face sketch plane `+Z @ (0,0,30)`, Circle at `(0,0)`, Smart Dim `Ø70`, Extrude **Fuse** Blind 25: `Z 30..55` |
| Cut sketch | front circular face (boss top) as sketch plane | face sketch plane `+Z @ (0,0,55)` |
| Offset Entities | distance 5, Reverse Direction, pick the face → circle 5 mm inside | `rail:Offset`, distance 5, Reverse, pick the boss rim → Ø60 circle, concentric |
| Cut | End condition Through All | Extrude Op `Cut`, End `Through All` (hole `r = 30`, `z 0..55`) |
| Fillet 1 | R5, the four small corner edges, then the front face | R5: four vertical corner edges + the face `z = 30` (its 4 outer edges **and** the concave root circle `r = 35`): 9 edges, **one** feature |
| Fillet 2 | R1.5, the front narrow circular face | R1.5: face `z = 55` (annulus `r 30..35`): 2 circular edges |
| Shell | back face removed, 1 mm | Bottom view (key `8`), face `z = 0`, Shell 1 |
| Section | Section View, Top plane, OK; click again to return | HUD `Section` → plane `Top` (`y = 0`, normal +Y); click again to return |

Why fillet before shell: R5 on a 1 mm skin cannot be built (a fillet bigger than the wall); the shell offsets the already-rounded outside, so every radius shrinks by exactly the wall (R5 → R4 inside, R1.5 → R0.5, the concave R5 root → R6). Row N10 shows the refusal.

Face and plane names used below: front = `z = 30`, boss top = `z = 55`, back = `z = 0`.

Derived numbers (all in the checker's `PART` / `VOLUMES` tables; the plan and the walk read them from there). Analytic profile integration agrees with a standalone OCCT 8.0.1 replica of the kernel's calls (box ∪ cylinder, cylinder cut, `MakeFillet`, `MakeThickSolidByJoin(-1, 1e-3)`), measured on the BUILD VM. Every ray / hit table in the checker spec below was also cast against that OCCT final shape (`IntCurvesFace_ShapeIntersector`) and matches to 0.001 mm (walls `−60,−59,−31,−30,30,31,59,60`; plates `29,30` and `54,55`; corner diagonal `11.071, 12.071`; fillet probes `2.071`, `7.929`, `5.621`; `z = 27.18` on the rim ray):

| Stage | Meaning | Volume (analytic) | OCCT 8.0.1 |
|---|---|---|---|
| `base` | 120 × 120 × 30 | 432000.0 | 432000 |
| `boss` | + Ø70 × 25 | 528211.3 | 528211 |
| `cut` | − Ø60 × 55 | 372702.4 | 372702 |
| `r5` | R5 on 9 edges | 370784.6 | 370785 |
| `rounded` | + R1.5 on 2 edges | 370587.4 | 370587 |
| `final` | shell 1, back open | 39311.0 | 39311.7 |

## The video, step by step → SolidExpress

Rows named in the last column are in the checklist below.

| # | Video step | SolidExpress UI | Rows |
|---|---|---|---|
| 1 | New part; save as `tutor1` | File → New (empty part); Save As | A1, A5 |
| 2 | Extruded Boss Base, Front plane | ground sketch (`sketch_ground`, Top view) | A1 |
| 3 | Center Rectangle: click the origin, drag out | `rail:Rect` + `variant:Center`: click `(0,0)`, click `(60,60)` | A2 |
| 4 | Smart Dimension the horizontal line 120, the vertical line 120; "fully defined" | rail `Smart Dim`; two lines; DOF chip `0` | A3 |
| 5 | Exit Sketch; Blind, depth 30, OK | Extrude `finish:Op` New (first body), `finish:Distance` 30, `finish:Extrude` | A4 |
| 6 | Extruded Boss Base; click the front face as the sketch plane; Normal To | select the `z = 30` face, key `3`, Sketch chip | A6 |
| 7 | Circle: click the origin, drag out; Smart Dimension circumference → 70 | `rail:Circle` at `(0,0)`; Smart Dim the rim → `Ø70`; DOF `0` | A7, A8 |
| 8 | Exit Sketch; trimetric; depth 25; OK | Exit Sketch, key `7`, Extrude Op **Fuse**, `25` | A9 |
| 9 | Extruded Cut; click the front circular face as the sketch plane | select the `z = 55` face, Sketch chip | A11 |
| 10 | Offset Entities: distance 5, Reverse Direction, select the front circular face → circle 5 mm inside; OK | `rail:Offset`, `offset:Distance` 5, `offset:Reverse`, click the rim, `offset:Ok` | A12–A14 |
| 11 | Exit Sketch; End condition Through All; OK | Exit Sketch; Extrude Op `Cut`, End `Through All` | A15 |
| 12 | Fillet R5, Full preview; four small corner edges (hidden edges too); the front face; OK | Fillet armed, Radius `5`, four vertical edges, Shift+click the `z = 30` face, Enter | A16–A19 |
| 13 | Fillet R1.5; the front narrow circular face; OK | Fillet armed, `1.5`, click the `z = 55` face, Enter | A20 |
| 14 | Rotate with the middle button; back face; Shell, thickness 1, Show preview; OK | Bottom view key `8`, `face_normal=[0,0,-1]`, `strip:shell`, `finish:Thickness` `1`, Enter | A21–A22 |
| 15 | Trimetric; Section View; Top plane; OK; click Section View again to return | key `7`; `hud:Section` → `popup:Top`; `hud:Section` again | A23, A24 |
| 16 | Save | File → Save | A25 |

## What exists today (measured on `58eb22f` through the bridge, by clicking)

Probes M1–M14 were run on a fresh app with `SX_AUTOMATION=1`. M15 is a standalone OCCT replica (kernel truth).

| # | Probe | Result |
|---|---|---|
| M1 | `Rect` + `Center` at `(0,0)` → `(60,60)`; Smart Dim top line `120`, right line `120` | rect is `±60`; DOF **2** after both dims (4 → 3 → 2): the centre is free, so the sketch is **not** fully defined |
| M2 | Extrude Blind 30 | works: `Extrude Blind 30.0000 mm`, `V = 432000.0`, bbox `−60..60 × −60..60 × 0..30` |
| M3 | select the `z = 30` face, key `3`, Sketch chip | opens upright: plane `+Z @ (0,0,30)`, `x = +X`, `y = +Y` |
| M4 | `Circle` at `(0,0)` rim `(35,0)`, Smart Dim rim `70` | `Ø70`, DOF **2** (centre not pinned, as M1) |
| M5 | Extrude Blind 25 with the default Op | default Op is `New`; with Op **`Fuse`**: one body, `V = 528211.3`, bbox max `z = 55` |
| M6 | boss-top sketch (plane `+Z @ (0,0,55)`), `rail:Convert`, click the rim at three points | `Convert: edge is not on this face` each time; no external entity. Cause to confirm in WP4: with two `+Z` faces on the body `sketch_convert_edge.gd : _face_edge_set` falls back to `faces_matching(...)` and keeps the **first** best dot (strict `>`), which is the `z = 30` face |
| M7 | select the rim circle, `chip:Offset` | a free circle `r = 35.01` appears (`DimSpin` minimum `0.01`, outward only, no Reverse); DOF 3; no `rail:Offset` exists |
| M8 | Circle `r = 30` on the boss top, Smart Dim `60`, Extrude Cut Through All | works: `V = 372702.4`, bbox unchanged `120 × 120 × 55` |
| M9 | Fillet armed, first pick = click on the `z = 30` face | the whole loop is taken: `Fillet: 5 edge(s)` (4 × `120.0 mm line` + the `219.9 mm` root circle); the face first-pick path works today |
| M10 | Fillet armed, first pick = click on the `z = 55` annulus; Radius `1.5`; Enter | `Fillet 2 edges 1.50 applied`, `V = 372505.2` on the unfilleted body (= `372702.4 − 197.2`, the same delta the full part needs) |
| M11 | Fillet armed with edges picked; plain click **and** Shift+click on the `z = 30` face | both refused: `No edge near click — click on an edge (a face click fillets the whole face only as the first pick)` (`ops_panel.gd : _accumulate_dressup_edge`) |
| M12 | pick the four vertical edges after the boss exists, Iso (key `7`) | three resolve; the fourth `(60,60)` lands on the Ø70 rim (`219.9 mm line`), so the corner-to-view table of rung 2 does not carry over; a set that includes the `z = 55` rim at R5 is refused: `Fillet could not be built on 7 edge(s) (219.911 mm arc …)` (correct refusal) |
| M13 | `click(face_normal=[0,0,-1])` on the back face; `click(face=<z=30 id>)` | the back click selected an **edge** (`Selected edge …`); the `z = 30` click selected a **different face id**: `automation_bridge.gd : _resolve_face_query` clicks `centre = view.doc.face_midpoint(fid)` (`measure.cpp : face_midpoint`, UV-bounds midpoint), which lies off an annular face (centre of the front face, back face, boss annulus). `_find_face_by_normal` also keeps the face furthest along the normal, so the `z = 30` face cannot be named by normal |
| M14 | Shell: Bottom view (key `8`), body selected, click `(50,0,0)` on the back face, `strip:shell`, `1` | works on the cut body: `Shell 1.0000 mm applied`; face clicks on an **unselected** body select the body first (two-step), a walk rule not a gap |
| M15 | OCCT 8.0.1 replica: fuse, cut, `MakeFillet` R5 on the 9 edges (4 vertical, 4 front outer, root circle), R1.5 on the 2 rims, `MakeThickSolidByJoin(shape, {z=0 face}, -1, 1e-3)` | every step valid; volumes in the table above; shell bbox `120 × 120 × 55`; `GeomAbs_Arc` and `GeomAbs_Intersection` joins give the same volume, so `ops_dress.cpp : apply_shell` needs no change unless WP6's red test shows otherwise |
| M16 | Section: `K`; HUD | `viewport_interaction.gd : toggle_section` sets `set_section_plane(AABB centre, +X)`; no status text, no id on `view_hud.gd : _section_btn`, no section field in `state`, no plane choice; `document_view.gd : _make_section_shader` discards the half-space and renders the interior as darker back faces (no cap) |

Not measured, on purpose (the red tests decide): the combined 9-edge fillet **through the app** (M15 proves the kernel can), the Shell on the filleted body through the app, and `ops_dress.cpp : min_departure_length` on the concave root circle.

## Gap analysis

| # | Gap | Evidence | Root cause (file : symbol) | WP |
|---|---|---|---|---|
| G1 | A centre rectangle / circle drawn at the origin is not anchored: sketch never reaches DOF 0 | M1, M4 | `sketch_mode.gd : _click_rect` (variant `center`) → `_infer_rect` → `_pin_rect_corner_at_origin` pins only a **corner**; `_click_circle` never pins; `_pin_circle_at_sketch_origin` runs only from `_apply_centre_distance_dim` | WP2 |
| G2 | The bridge cannot name annular faces (front, back, boss top) | M13 | `automation_bridge.gd : _resolve_face_query`, `_find_face_by_normal`, `state.faces` record `centre` from `measure.cpp : face_midpoint` | WP3 |
| G3 | Convert refuses the boss rim, and cannot take a circle at all | M6 | `sketch_convert_edge.gd : _face_edge_set` (first-best-dot host fallback); `sxkernel/src/sketch3d.cpp : add_external_edge` returns `{}` unless `GeomAbs_Line`; `SxDocument::sketch_add_external_edge` is lines-only although `Sketch::project_circle_edge` exists | WP4 |
| G4 | No Offset Entities tool: the chip only grows a free circle outward by ≥ 0.01, with no Reverse, from sketch entities only | M7 | `sketch_context_chrome.gd : DimSpin` (`min_value 0.01`); `sketch_tools.cpp : offset_entities` (if/else over Line and Circle, circle gets no constraint); no rail entry | WP5 |
| G5 | The front face cannot be added to an edge set; the fourth corner edge is not reachable in the rung-2 view table | M11, M12 | `ops_panel.gd : _accumulate_dressup_edge` / `_add_dressup_face` (face only as first pick; pinned by `run_rung01_replan12_pick.gd`) | WP6 |
| G6 | Fillet on 9 edges (incl. the concave root) and Shell 1 on the result are unproven through the app | M15 (kernel ok) | `ops_dress.cpp : apply_fillet_chamfer`, `apply_shell` | WP6 |
| G7 | Section view has no plane choice, no cap, no id, no state | M16 | `viewport_interaction.gd : toggle_section`, `document_view.gd : set_section_plane / _make_section_shader`, `view_hud.gd : _section_btn` | WP7 |
| G8 | The walk machinery has two rungs registered by hand | `registry.py` (`_RUNG_SPEC`, `RUNG2_ROWS`, `install()`), `tools/walk_rung02.py`, `app02.py` | `tools/walk/` | WP8 |
| G9 | The checker has no rung-3 probes and `Solid` / `TriMesh` live inside `check_rung02.py` | — | `tools/check_rung02.py` | WP1 |

Verified **not** gaps: Extrude Blind (M2), Fuse onto a body (M5), Through All cut from a face (M8), face-first fillet of a whole face (M9, M10), Shell chip reachable at 1280 × 800 (rung 2 L4, M14), upright face sketches (M3), dimension label editing.

## Design rules (Andy's goal: layers and data, not piles of conditionals)

Each WP names the layer it adds; the BUILD agent does not add an `if` branch where one of these exists. Code must be readable from its own file header and neighbours, without the chat.

1. **Value objects at the boundaries.** An origin anchor is an `OriginAnchor` rule; a section is a `SectionPlane` (`name`, `point_rule`, `normal`, `view_key`); a fillet pick is a `PickAction` chosen by a policy table; a projected edge is made by a `Projector` keyed by curve type. No scattered `centre/normal/tol` triples.
2. **Tables for dispatch.** `OriginAnchor.RULES` (`rect.center`, `circle.center`), `SketchConvertEdge.PROJECTORS` (`Line`, `Circle`), `SketchOffset.BUILDERS` and kernel `OFFSETTERS` (`Line`, `Circle`), `FilletPick.POLICY` (`(first pick?, modifier, hit kind) → action`), `SectionPlane.PRESETS` (`Front`, `Top`, `Right`), checker `STAGES`, walk `Rung`. A new case is one row.
3. **Geometry behind a protocol.** The checker talks to a `Solid` (`bbox`, `volume`, `inside(p)`, `hits(origin, direction)`); `TriMesh` implements it from a 3MF, `ImplicitPart03` analytically for unit tests (tests only).
4. **Hotspots stay thin.** `sketch_mode.gd`, `viewport_interaction.gd`, `ops_panel.gd`, `automation_bridge.gd` only call helpers (`landing-protocol.md`): new behaviour lives in `sketch_origin_anchor.gd`, `sketch_offset.gd`, `fillet_pick.gd`, `section_plane.gd`, `face_pick.gd`. Each new file starts with a two-line header of what it owns.
5. **One resolution rule per concept.** "A point guaranteed on this face" is one function (`face_pick_point`), used by the bridge, by Convert and by the walk; nobody recomputes UV midpoints.
6. **Click-driven tests.** UI and film tests click; no private-API fallback (`.cursor/rules/gdscript-click-driven-tests.mdc`). Validation tests (`rung03_part_check`) may call the kernel.
7. **Never** pass `user://` or `res://` into GDExtension C++ (AGENTS.md); always `ProjectSettings.globalize_path` first.

## Decisions (final — the BUILD agent does not choose)

1. **Scope and shape.** Nine WPs, sequential, one agent, one PR, then integration. Every WP's step 1 is a **failing** test (red output goes in the PR body), then the change. A red WP check is fixed before the next WP starts.
2. **The runner is the walker.** `SX_AUTOMATION=1 python3 tools/walk_rung03.py --out $OUT --a15` against a local Linux build (`BUILDINFO.txt` `commit=` equals the sha under test). No screenshot is evidence except the named `pixels` clauses. Report must show every row PASS.
3. **Frame, depth and volumes** are the tables above; the checker's `PART` table is the only place the numbers live (`check_rung03.py params`). Depth 30, never 50.
4. **Origin anchoring.** A `Center` rectangle or a centre-drawn circle whose centre is within `ORIGIN_PIN_TOL` (0.5 mm) of the sketch origin is anchored there at draw time, guarded by `infer_enabled` exactly like the corner pin. Mechanism: the one the Jaw already uses (`_origin_anchor_point`, `_add_centre_rect_dimensions`: construction diagonal whose midpoint is coincident to the anchor; circle: centre-only `fix` / coincident, as `_pin_circle_at_sketch_origin`). Acceptance is DOF `0` and no extra profile loop. If a rung-1 suite's pinned DOF changes, the rule gets a per-tool opt-in column in the table, not a condition.
5. **Boss Op.** The walk selects Op `Fuse` explicitly (`finish:Op`). The default stays `New` (rung 1 and 2 depend on it); changing defaults is out of scope.
6. **Offset.** `rail:Offset` is a new tool beside `Convert`; the selection chip `chip:Offset` keeps working through the same kernel table. The offset result is a normal profile circle (not construction) with `Concentric` to the source and a driving `Radius = r − d` (Reverse = inward); the source is the external construction circle from Convert. It is **not** associative (nothing re-syncs externals; `update_projected_*` have no caller outside `sketch.cpp`); associativity is out of scope. Distance ≤ 0, or inward distance ≥ radius, is refused with a status and no entity.
7. **Fillet picking.** Video order (edges, then the face) is supported by **Shift+click on a face while Fillet is armed** (matches `_additive_click = shift or ctrl` in `viewport_interaction.gd`). Plain face click keeps today's behaviour, pinned by `run_rung01_replan12_pick.gd` (first pick takes the face; later plain clicks snap to an edge or are refused). The policy is the `FilletPick.POLICY` table.
8. **Face addressing in the bridge.** `state.faces` gains `pick` (a world point guaranteed on the face) and `plane` (`n·pick`); `click(face=…)` and `click(face_normal=…)` aim at `pick`; `click(face_normal=[…], plane=<mm>)` disambiguates parallel faces (`z = 30` vs `z = 55`). Without `plane` the old rule (furthest along the normal) holds, so rung 1 and 2 rows are unchanged.
9. **Section.** `SectionPlane` presets: `Front` = plane `z = 0` normal `+Z`, `Top` = plane `y = 0` normal `+Y`, `Right` = plane `x = 0` normal `+X` (SOLIDWORKS names, our axes). The kept half is the one **away** from the camera at toggle time, so the cut faces the viewer. `K` with no plane chosen keeps today's behaviour (`+X` through the AABB centre). The cap is flat `SectionPlane.CAP_COLOUR`, painted by the shader on back-facing fragments while clipped; if the `pixels` clause fails on a thin wall the BUILD agent may use a stencil cap instead, the clause is the contract. The bridge exposes `state.section = {on, plane, point, normal}` and id `hud:Section`; plane choice goes through `popup:Front|Top|Right`.
10. **Shell stays as built.** `shell_chrome.gd`'s rule (`apply_mm` refuses `mm ≥ 0.5 · min_extent`, here 27.5) and `apply_shell` are unchanged unless WP6's kernel red test fails; then switch the join and re-test.
11. **Status wording.** Rows judge `[status-trace] … kind=result text=…` lines since the row's mark. Already measured: `Extrude Blind 30.0000 mm`, `Extrude Blind 25.0000 mm`, `Extrude Through All …`, `Fillet: n edge(s) — …`, `Fillet 2 edges 1.50 applied`, `Shell 1.0000 mm applied`, `Selected face …`. For `Convert: external circle`, the Offset texts, `Fillet 9 edges 5.00 applied`, the Section texts and every refusal, the BUILD agent measures on its own build in the WP that adds it, pins it in the row's clause, and lists it in the PR body.
12. **Checkpoints.** `base.sxp` (A5), `boss.sxp` (A10), `cut.sxp` (A15), `rounded.sxp` (A20), `final.sxp` (A25). `--from <row> --checkpoint` reloads the previous chunk's file. (The video's `tutor1` name is not used.)
13. **Critique score.** Same rule as rung 2: the checker and the walk are necessary, not sufficient; the rung is Done when one build, in one critique, follows every video step with the named tool, scores ≥ 9 and the checker passes. A substitute tool (Box primitive for Rect + Extrude, a Hole feature for circle + Cut, typing `R30` instead of Offset Entities, a hand-built kernel sketch) caps the critique at 8.
14. **PR rules.** `github.com/solidexpress/solidexpress`; from `main`; ready (not draft); never self-merge; quick CI green (linux kernel, godot-smoke, website-demos); **do not edit `docs/plan/STATUS.md`**; new headless tests follow the click-driven rule and are registered by one `packaging/ci/suites.d/<name>.suite` file each (never edit `run_godot_suites.sh` or the Makefile recipe); `Makefile` `test-tools` gains `python3 tools/test_check_rung03.py`; never commit `.webm`, `.mp4`, `.avi`, `.mov`, `.vtt`; PR body lists each WP's red output, every pinned status text, suite counts, the walk report head and the three checker runs.

## Work packages

Sequential. Each: **items**, **files**, **red first**, **change**, **acceptance**. Suites `rung03_<name>`, `script=tests/run_rung03_<name>.gd`, `tier=full` unless noted, `timeout=180`; kernel tests are Catch2 in `sxkernel/tests/` (add to its CMake list).

### WP1 — Checker and shared geometry primitives (G9)

**Files.** New `tools/solid.py` (`Solid` protocol, `TriMesh`, `Probe` base, moved out of `check_rung02.py`), new `tools/check_rung03.py`, new `tools/implicit_part03.py` (tests only), new `tools/test_check_rung03.py`, `tools/check_rung02.py` imports from `solid`, `Makefile` `test-tools`.

**Red first.** `python3 tools/test_check_rung03.py` fails on the missing module; `python3 tools/test_check_rung02.py` stays green before and after the move.

**Change.** Implement "Spec: `tools/check_rung03.py`" below, including `STAGES`, `PART`, `VOLUMES`, the probes and the mutation tests.

**Acceptance.** `make test-tools` green; every mutation in the spec is rejected with the named check failing; `check_rung02.py` output byte-identical on its fixtures; `check_rung03.py params` prints JSON.

### WP2 — Centre shapes at the origin are anchored: `OriginAnchor` (G1)

**Files.** New `game/scripts/sketch_origin_anchor.gd` (`class_name SketchOriginAnchor`: `RULES` table, `static func apply(sketch, entity_ids, tool_key, centre: Vector2)`), `sketch_mode.gd` (`_click_rect` centre variant and `_click_circle` centre branch call it; `_pin_circle_at_sketch_origin` becomes one rule's implementation, not a second code path).

**Red first.** `tests/run_rung03_origin_anchor.gd` (`tier=ci`): click-built `Center` rect from `(0,0)` → `(60,60)`, Smart Dim `120`, `120` → DOF chip `0` (red on `main`: `2`); centre circle at `(0,0)`, Smart Dim `Ø70` → DOF `0` (red: `2`); a `Center` rect centred at `(30,0)` and a circle at `(10,0)` stay unanchored (DOF unchanged from `main`: 2 after the dims); `Corner` rect `(0,0)`–`(100,65)` still DOF `0` after its two dims (rung 2 A3).

**Change.** The rule table and its two rows (decision 4).

**Acceptance.** Test green; every `run_rung01_*` suite and the rung-2 suites green (the DOF-pinned ones are the risk, see decision 4); `Infer` off draws unanchored shapes as before.

### WP3 — Bridge: faces by identity (G2)

**Files.** New `sxkernel/src/measure.cpp : face_pick_point` (reuse the `face_interior_point` idea of `ops_dress.cpp`, one shared helper), `sxcore/src/sx_document.{hpp,cpp}` binding `SxDocument.face_pick_point(face_id) -> Vector3`, new `game/scripts/face_pick.gd` (`FacePick`: pick point, plane offset, normal match), `automation_bridge.gd` (`_resolve_face_query`, `_find_face_by_normal`, `state.faces` records `pick`, `plane`), `docs/loop/automation-bridge.md`, `tests/run_automation_bridge_tests.gd` (extend).

**Red first.** Kernel Catch2 `test_face_pick_point.cpp`: on the finished Ø60-cut part every planar face's `pick` lies on the face (`BRepClass_FaceClassifier` `TopAbs_IN`), including the front, back and boss-top annuli. Bridge test on a click-built boss + cut part: `click(face=<z=30 id>)` returns that same id (red: M13); `click(face_normal=[0,0,1], plane=30)` selects `z = 30`, `plane=55` selects `z = 55`; `face_normal=[0,0,1]` alone still selects `z = 55`; after key `8`, `face_normal=[0,0,-1]` selects the back face with the body already selected.

**Acceptance.** Bridge suite green with the new checks; the id/selector table in `automation-bridge.md` lists `plane=`, `state.faces[].pick`, `state.faces[].plane`; rung 1 and 2 rows (which pass `face_normal` alone) unchanged.

### WP4 — Convert takes circles, and finds the right host face (G3)

**Files.** `sxkernel/src/sketch3d.cpp : add_external_edge` becomes a dispatch over `PROJECTORS` keyed by `GeomAbs_CurveType` (Line: existing, Circle: `Sketch::project_circle_edge`, full circles in a parallel plane only; arcs refused), `sxcore` binding (`sketch_add_external_edge` returns the new id for either), `game/scripts/sketch_convert_edge.gd` (`PROJECTORS` status table `{Line: "Convert: external line", Circle: "Convert: external circle"}`; `_face_edge_set` chooses the host by **plane**: of the faces matching the normal, the one whose plane passes through the sketch origin, not the first best dot; unsupported types: `Convert: edge type not supported (line or circle)`, replacing `NOT_LINE`, which no test pins).

**Red first.** Catch2 `test_sketch_external_circle.cpp`: a body with a boss, sketch on the `z = 55` face, `add_external_edge(rim)` → one external circle `r = 35`, centre `(0,0)`, `projected_from` set, DOF contribution 0. `tests/run_rung03_convert_circle.gd` (`tier=ci`): click-built boss part, face sketch on `z = 55`, `rail:Convert`, click the rim → `Convert: external circle`, the sketch lists one external circle; a click on the `z = 30` circle (root) → `Convert: edge is not on this face`, no entity; the same on the `z = 30` face sketch refuses the `z = 55` rim.

**Acceptance.** Both green; rung 2's `run_rung02_face_edges` and the kernel `test_sketch*` unchanged and green; an external circle regenerates its geometry from the body (same path as external lines) and is marked dangling, not crashing, if the edge disappears.

### WP5 — Offset Entities tool (G4)

**Files.** New `game/scripts/sketch_offset.gd` (`class_name SketchOffset`: tool state, panel, `BUILDERS` table `{circle: …, line: …}`), rail entry `rail:Offset` (ids `offset:Distance`, `offset:Reverse`, `offset:Ok`), `sketch_mode.gd` and `sketch_context_chrome.gd` only wire it; `sxkernel/src/sketch_tools.cpp : offset_entities` becomes a table `OFFSETTERS` keyed by entity type (Line: existing; Circle: new circle + `Concentric` to the source + driving `Radius = r + signed distance`; Arc stays skipped); the tool accepts a sketch entity **or** a model edge of the sketch face (it goes through `SketchConvertEdge` first, so the source becomes the external construction circle).

**Red first.** Catch2 (extend `test_sketch_tools.cpp`): `offset_entities(sk, {circle r=35}, -5)` returns a circle `r = 30` with a `Concentric` and a `Radius` constraint (red on `main`: a free circle, 3 DOF); `+5` gives `r = 40`; `-35` and `-40` are refused. `tests/run_rung03_offset.gd` (`tier=ci`): click-built boss part, sketch on `z = 55`, `rail:Offset`, distance `5`, Reverse on, click the rim, OK → one profile circle `r = 30` at `(0,0)`, one external circle `r = 35`, DOF `0`; distance `0` refused; click in empty space refused; Esc disarms; the existing chip path (`chip:Offset`, `0.01`) still produces its circle.

**Acceptance.** Both green; `run_sketch_tools_tests.gd` (pins the old chip behaviour) green; the controls are inside the window at 1280 × 800 (rect check) and have visible labels.

### WP6 — Fillet by face in any order; Shell on the filleted body (G5, G6)

**Files.** New `game/scripts/fillet_pick.gd` (`class_name FilletPick`: `POLICY` table `(first_pick, modifier, hit_kind) → PickAction`, the reachable-edge helper), `ops_panel.gd : _accumulate_dressup_edge` / `_add_dressup_face` call it instead of branching; `sxkernel/src/features/ops_dress.cpp` only if the kernel red test fails (`min_departure_length` on the concave root circle; shell join).

**Red first.** Catch2 `test_rung03_part.cpp`: build the whole part through the feature pipeline (centre rect sketch → extrude 30 → circle sketch on the face → extrude Fuse 25 → sketch on the boss → circle `r = 30` → cut through all → `FilletCommand` with the 9 edges R5 → `FilletCommand` with the 2 rims R1.5 → `ApplyShell` 1 on the `z = 0` face); expect each volume of the table within 0.05 %, `final` within 0.2 %, valid solids. `tests/run_rung03_fillet_face.gd` (`tier=ci`): click-built part to the cut; Fillet armed R5; four vertical edges, then Shift+click the `z = 30` face → `Fillet: 9 edge(s)`; plain click on the face → still refused with the pinned message; Enter → `Fillet 9 edges 5.00 applied`, one feature; the corner table `corner → view` is asserted so all four verticals are reachable (M12). The same with the face first. `run_rung01_replan12_pick.gd` is not edited and stays green.

**Acceptance.** Both green; volumes as the table; `test_dress.cpp` and rung-1/2 fillet suites unchanged and green; Shell `1` on the `z = 0` face of the filleted body in the click test: `Shell 1.0000 mm applied`, bbox unchanged, `V = 39311 ± 0.2 %`.

### WP7 — Section view: `SectionPlane`, HUD id, cap, state (G7)

**Files.** New `game/scripts/section_plane.gd` (`class_name SectionPlane`: `PRESETS`, `CAP_COLOUR`, `kept_side(camera_pos)`), `viewport_interaction.gd : toggle_section` delegates, `document_view.gd` (`set_section_plane(point, normal)` signature unchanged — `run_display_tests.gd` pins it and the `section_normal` uniform; cap paint added in `_make_section_shader`), `view_hud.gd : _section_btn` gets id `hud:Section` and a plane popup (`popup:Front|Top|Right`), `automation_bridge.gd` (`state.section`), `docs/loop/automation-bridge.md`.

**Red first.** `tests/run_rung03_section.gd` (`tier=ci`): click-built part; `hud:Section` → `popup:Top` → `state.section == {on: true, plane: "Top", normal: ±(0,1,0)}` and the kept half is the one away from the camera; the HUD button reads pressed; `pixels` at the projected cut-plane point of a wall (`(−59.5, 0, 12)` on the finished part, or the base wall on a part without shell) equals `CAP_COLOUR ± 6` and at a point of the removed half equals the background; second click → `on: false` and the first pixel is the normal shading again; `K` flips it too; with no bodies the button refuses with a status. `run_display_tests.gd` green unchanged.

**Acceptance.** Test green; `run_display_tests.gd`, `run_visual_ux_tests.gd`, `run_sketch_tools_tests.gd` unchanged and green; `K` with no plane chosen keeps `+X` through the AABB centre.

### WP8 — Walk machinery: `rung03` rows (G8)

**Files.** `tools/walk/registry.py` (`RUNG3_ROWS`, `_RUNG_SPEC["rung03"]`, `registry.RUNG3`, `install()`), new `tools/walk/app03.py` (`WalkApp03(Rows03Chunk1..6, WalkUI03, WalkGestures)`), new `tools/walk/rung3/ui03.py` (helpers: `centre_rect`, `face_sketch`, `offset_rim`, `pick_corner_edges`, `shift_click_face`, `shell_back`, `open_section`, `pixel_is`, `export_and_check`), new `tools/walk/rung3/rows03_chunk{1..6}.py`, new `tools/walk_rung03.py` (same CLI as `walk_rung02.py`), `tools/test_walk_registry.py` (adds `FROZEN_ROWS_03` and `FROZEN_CHUNKS_03`; rungs 1 and 2 frozen as is), `docs/loop/automation-bridge.md`, `docs/loop/README.md`.

**Red first.** `python3 tools/test_walk_registry.py` with the rung-3 row list added fails (no rows); rungs 1 and 2 assertions green before and after.

**Change.** Implement the rows of "The checklist", each as a method that only calls `ui03` helpers and `self.clause(...)`; no row carries pixel literals; body guard `S0` is a clause group on every export row: one body, name starts `extrude` (the body keeps its first feature's name; pin from the build), bbox `120 × 120 × H` with `H = 30` after chunk 1 and `55` after chunk 2.

**Acceptance.** `test_walk_registry.py` green for all three rungs; `walk_rung03.py --rows N1,A1,A2,L1,A3 --dry-run` smoke; `walk_rung03.py --rows A1,A2,L1,A3,N2,A4,A5` passes on a build with WP2.

### WP9 — Integration (same PR)

1. `make build`, `make test`, `make test-tools`; `KEEP_GOING=1 make test-godot` `0 failed`.
2. Validation suite `tests/run_rung03_part_check.gd` (`tier=full`; kernel-built part, per stage: export 3MF to a `ProjectSettings.globalize_path` path, `SxChecker.run("rung03", [stage, file])`, expect exit 0 for all six stages).
3. Full walk `SX_AUTOMATION=1 python3 tools/walk_rung03.py --out $OUT --a15`: every row PASS, `check-*.txt` all PASS.
4. Re-run the other rungs: `walk_rung01.py` 77/77 and `walk_rung02.py --a15` 44/44 on the same build; `tools/test_walk_registry.py`, `tools/lint_rung01_e2e.py`, `tools/lint_suites.py`.
5. Paste the six `check_rung03.py` outputs by hand. PR body: red outputs, pinned status texts, suite counts, walk report head.

## Runner rules (rung 3; rung 1's R1–R10 and rung 2's additions apply unchanged, these are the additions)

1. **A row passes by clauses.** Every clause is a bridge read (`state`, `bodies`, `timeline`, `trace`, `pixels`) or a `check_rung03.py` line; no vacuous clause.
2. **Export rows** (A4, A9, A15, A19, A20, A22) assert S0 first, then run the checker stage for that row, then record `check-<stage>-<file>.txt`.
3. **Face picking.** Select the body first (a face click on an unselected body selects the body, M14), then `face_normal=[…]` with `plane=` for parallel faces; the view first (`3` for front and boss top, `8` for the back). Never a literal pixel; never `face=<id>` right after a camera move.
4. **Edge picking** by `edge=<id>` + `along=0.5` through the `corner → view` table pinned by WP6; after each pick the row asserts the status names one more `30.0 mm vertical`, so a pick that landed on the Ø70 rim (M12) is a failing clause, not a silent miss.
5. **Pixel clauses** project a model point (`project(model=…)`), read `pixels`, and compare to `CAP_COLOUR` or to the normal shading; a thin-wall point is chosen from the table in WP7, never a screen literal.
6. **Dimension edits** go through the drawn label (`dim=`, `edit_dim`); Enter commits; the row asserts the label text and `DOF 0` after.
7. **Checkpoints** after A5, A10, A15, A20, A25.
8. **A26** (headless evidence) runs `make test-godot` and `make test-kernel` with `--a15`; without the flag it is `BLOCKED-by-flag`.

## Chunks

| Chunk | Rows | Starts in | Ends in |
|---|---|---|---|
| 1 | N1 A1 A2 L1 A3 N2 A4 A5 | fresh app | part mode, one body `120 × 120 × 30`, `base.sxp` saved, nothing selected, no menu open |
| 2 | A6 L2 A7 A8 N3 A9 A10 | end of 1 | one body `120 × 120 × 55`, `boss.sxp`, nothing selected |
| 3 | A11 A12 L3 N4 A13 N5 A14 L4 A15 | end of 2 | one body with the Ø60 hole, `cut.sxp`, nothing selected |
| 4 | A16 L5 A17 N6 A18 N7 N8 A19 A20 | end of 3 | `fillet` ×2 on one body, `rounded.sxp`, Fillet disarmed |
| 5 | A21 L6 N9 A22 N10 A23 L7 A24 N11 | end of 4 | one shelled body, section off, nothing selected |
| 6 | A25 N12 L8 A26 | end of 5 | `final.sxp` saved and reopened, headless evidence |

## The checklist

Row prefixes: **A** action (the video step done with the named tool), **L** look / legibility (read from rects, labels, traces and `pixels`; no pixel literals), **N** negative / edge case. "Clauses" are the names in `walk_report.json`. Statuses are read from `[status-trace]` result lines.

### Chunk 1 — base (8 rows)

| Row | Does | Clauses |
|---|---|---|
| N1 | Window read first: size ≥ 1272 × 750 or maximized; status bar, File menu, rail inside the window | `window`; `chrome inside` |
| A1 | File → New; empty part; ground sketch opened (Top view) | `new`; `sketch`; `Snap Infer`; `dof glyph` |
| A2 | `rail:Rect` armed, `variant:Center`; click `(0,0)` then `(60,60)`; four lines; centre of the four lines is the origin | `rect armed`; `centre variant`; `four lines`; `centred on origin`; `bbox sketch 120 × 120` |
| L1 | Rail labels `Rect`, `Smart Dim`, `Circle`, `Convert`, `Offset`, `Select` present, none clipped; `Center` variant button visible | `labels`; `variant visible` |
| A3 | Smart Dim top line `120`, right line `120`; labels read `120`, `120`; DOF chip `0` (video: "the black sketch is fully defined") | `label 120`; `label 120 (2)`; `dof 0`; `lines length` |
| N2 | Smart Dim then type `0`: refused (status), dimension unchanged; `-5` refused; Esc clears the editor | `zero refused`; `negative refused`; `unchanged`; `esc` |
| A4 | Extrude: `finish:Op` New, `finish:Distance` `30`, `finish:Extrude`; `Extrude Blind 30.0000 mm`; one body; S0; export `base.3mf`; `check_rung03.py base` PASS | `extrude`; `status`; `one body`; `S0`; `exported`; `base` |
| A5 | Save As `base.sxp` into `$OUT`; dialog gone; file exists; title shows `base` | `saved`; `file exists`; `title` |

### Chunk 2 — boss (7 rows)

| Row | Does | Clauses |
|---|---|---|
| A6 | Select the body, key `3`, click the `z = 30` face (`face_normal=[0,0,1]`, `plane=30`); selection `Face` (id equals the `z = 30` record); Sketch chip; sketch active; plane normal `+Z`, origin `(0,0,30)`, basis `x = +X`, `y = +Y` | `face selected`; `is z30`; `sketch on face`; `normal`; `origin`; `basis` |
| L2 | Face sketch framed (Sketch view fit trace); the face outline is inside the viewport; Top view kept ("Normal To") | `framed`; `outline inside`; `view top` |
| A7 | `rail:Circle`: click `(0,0)`, drag to `(35,0)`; one circle, centre `(0,0)` | `circle`; `one circle`; `centre origin` |
| A8 | Smart Dim the rim, label, `70`: label `Ø70`; DOF chip `0` | `label Ø70`; `diameter 70`; `dof 0` |
| N3 | Smart Dim on the circle, type `0`: refused, circle unchanged (`r = 35`); Esc | `zero refused`; `unchanged`; `esc` |
| A9 | Exit Sketch; key `7` (trimetric); Extrude `finish:Op` **Fuse**, `finish:Distance` `25`, OK; `Extrude Blind 25.0000 mm`; one body (no second body); S0; export `boss.3mf`; `check_rung03.py boss` PASS | `exit`; `trimetric`; `op fuse`; `status`; `one body`; `S0`; `boss` |
| A10 | Save As `boss.sxp` | `saved`; `file exists` |

### Chunk 3 — Offset cut (9 rows)

| Row | Does | Clauses |
|---|---|---|
| A11 | Key `3`, `face_normal=[0,0,1]` (furthest, `z = 55`); selection `Face` (the boss top); Sketch chip; plane `+Z @ (0,0,55)` | `face selected`; `is z55`; `sketch on face`; `origin` |
| A12 | `rail:Offset` armed (lit); the panel shows `offset:Distance`, `offset:Reverse`, `offset:Ok`; status names the tool | `armed`; `fields present`; `status` |
| L3 | The three Offset controls are inside the window at 1280 × 800, have visible labels, none covered (rect test); wheel over the panel does not move the model | `inside`; `labels`; `not covered`; `wheel` |
| N4 | Distance `0` then click the rim: refused (status), no entity; distance `40` with Reverse on: refused (inward ≥ radius), no entity; field back to `5` | `zero refused`; `too far refused`; `no entity`; `field 5` |
| A13 | Distance `5`, `offset:Reverse` on, click the rim: status; one new **profile** circle `r = 30.00 ± 0.01`, centre `(0,0)`; the source rim exists as one **external** circle `r = 35`; DOF chip `0` | `status`; `circle r 30`; `external r 35`; `concentric`; `dof 0` |
| N5 | Click in empty space with `rail:Offset` armed: refused with a status, entities unchanged; Esc disarms (one Esc, Offset unlit) | `refused`; `unchanged`; `esc disarms` |
| A14 | `offset:Ok`: panel closed; sketch still active; entity list unchanged (one profile circle, one external) | `ok`; `panel closed`; `entities` |
| L4 | The external circle is drawn as a reference (dashed / construction flag), the profile circle is solid; both labels (`Ø60` or the offset glyph) visible, not overlapping | `external style`; `labels visible`; `no overlap` |
| A15 | Exit Sketch; Extrude `finish:Op` Cut, `finish:End` Through All, OK; status; one body; S0 (bbox still `120 × 120 × 55`); export `cut.3mf`; `check_rung03.py cut` PASS (Ø60 through base and boss) | `exit`; `op cut`; `end through all`; `status`; `one body`; `S0`; `cut` |

### Chunk 4 — fillets (9 rows)

| Row | Does | Clauses |
|---|---|---|
| A16 | Select the body, arm Fillet (`chip:Fillet`), `finish:StripR` `5`, Tab; Fillet armed, status names the radius | `armed`; `radius 5`; `status` |
| L5 | The Fillet chip and the Radius field are inside the window; the chip's y does not move when one edge is selected | `chip inside`; `chip y stable` |
| A17 | Pick the four vertical corner edges by the `corner → view` table; after each, status `Fillet: n edge(s)` with n = 1..4 and each added item is `30.0 mm vertical` | `pick 1`; `pick 2`; `pick 3`; `pick 4`; `all vertical` |
| N6 | Pick the same edge twice: the count drops by one (toggle), pick again: back to 4 | `toggled off`; `restored 4` |
| A18 | View `3`; Shift held; click the `z = 30` face (`face_normal=[0,0,1]`, `plane=30`); Shift released: status `Fillet: 9 edge(s)` (4 vertical + 4 outer lines + the root circle) | `shift held`; `nine edges`; `root circle included`; `no stray rim` |
| N7 | Plain click on the face with edges armed: refused with the pinned message, the count stays 9 | `refused`; `message pinned`; `count 9` |
| N8 | Radius `30`, Enter: refused (limit status), timeline unchanged, picks kept; Radius back to `5` | `refused`; `timeline unchanged`; `picks kept`; `radius 5` |
| A19 | Enter: `Fillet 9 edges 5.00 applied`; exactly **one** new feature with 9 edges; disarmed; S0; export `r5.3mf`; `check_rung03.py r5` PASS | `applied`; `one feature`; `nine edges`; `disarmed`; `S0`; `r5` |
| A20 | Select the body, `chip:Fillet`, `finish:StripR` `1.5`; click the `z = 55` face (first pick: `Fillet: 2 edge(s)`); Enter: `Fillet 2 edges 1.50 applied`; one more feature; S0; export `rounded.3mf`; `check_rung03.py rounded` PASS; save `rounded.sxp` | `armed 1.5`; `two edges`; `applied`; `one feature`; `S0`; `rounded`; `saved` |

### Chunk 5 — shell and section (9 rows)

| Row | Does | Clauses |
|---|---|---|
| A21 | Key `8` (Bottom); select the body; `face_normal=[0,0,-1]`; selection `Face` (the back face, `z = 0`, not an edge); `strip:shell` chip appears | `bottom view`; `face selected`; `is back`; `chip present` |
| L6 | The Shell chip is inside the window, has a visible label, is not covered; wheel over it does not move the model | `inside`; `label`; `not covered`; `wheel` |
| N9 | Shell, thickness `30`: refused (limit status), no feature added, body unchanged; field back to `1` | `refused`; `unchanged`; `field 1` |
| A22 | `finish:Thickness` `1`, Enter: `Shell 1.0000 mm applied`; one new `Shell` feature **after both fillets** (timeline order `… fillet, fillet, Shell`); bbox unchanged `120 × 120 × 55`; S0; export `final.3mf`; `check_rung03.py final` PASS (walls 1.0 ± 0.1, open back, volume `39311` ± 1.5 %) | `panel`; `thickness 1`; `status`; `order`; `bbox`; `S0`; `final` |
| N10 | After the shell, arm Fillet R5 and pick a rim edge of the open back, Enter: refused (the rim face is 1 mm wide, R5 cannot fit; `Fillet could not be built …` or the limit status, pinned from the build); no feature added; Esc | `refused`; `status pinned`; `no feature`; `esc` |
| A23 | Key `7`; click `hud:Section` → `popup:Top`: `state.section` `{on: true, plane: "Top"}`, normal `±(0,1,0)` away-from-camera half kept; the HUD button reads pressed; status names the plane | `section on`; `plane Top`; `kept side`; `button pressed`; `status` |
| L7 | The cut is capped: `pixels` at the projected wall point `(−59.5, 0, 12)` equal `CAP_COLOUR ± 6`; at a point of the removed half equal the background; the part outline stays inside the viewport | `cap colour`; `removed is background`; `outline inside` |
| A24 | Click `hud:Section` again: `state.section.on` false, button released, the wall pixel is the normal shading again (video: "click Section View to return to the full view") | `section off`; `button released`; `shading back` |
| N11 | `K` turns the section on and off with the last plane (`Top`); the HUD button follows each toggle | `K on`; `K off`; `button follows`; `plane kept` |

### Chunk 6 — save, reopen, evidence (4 rows)

| Row | Does | Clauses |
|---|---|---|
| A25 | Save As `final.sxp`; file exists | `saved`; `file exists` |
| N12 | File → New, File → Open `final.sxp`: timeline order identical, one body, bbox `120 × 120 × 55`, no status error, section off; `check_rung03.py final` PASS on a re-export | `reopened`; `order`; `bbox`; `no error`; `section off`; `final` |
| L8 | Timeline rows legible: every label inside its row, feature names distinct (`sketch 1 … Shell`), none truncated | `rows`; `names distinct`; `not truncated` |
| A26 | Headless and lint evidence (needs `--a15`): `make test-kernel`, `make test-godot` (`KEEP_GOING=1`) `0 failed`; `tools/lint_suites.py`; `tools/test_check_rung03.py`; the registry test; engine noise per R9 of rung 1 | `kernel`; `godot`; `lint`; `unit`; `registry`; `errors` |

Total rows: 8 + 7 + 9 + 9 + 9 + 4 = **46** (26 A, 8 L, 12 N).

### Pass bar for the walk

`PASS 46`, no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`; every `check-*.txt` has no `FAIL`; the `[ERROR]` list of the walk is empty apart from rung 1's R9 engine noise and the intended refusals of N2, N3, N4, N5, N8, N9 and N10.

## Spec: `tools/check_rung03.py`

Like `check_rung02.py`: `python3 tools/check_rung03.py <stage> <file.3mf>`; prints one `PASS` / `FAIL` line per check; exit 1 if any fails. Plus `python3 tools/check_rung03.py params` printing `PART` and `VOLUMES` as JSON (the walk reads its numbers from there). Tolerance `TOL = 0.2` mm; volume tolerance 0.5 % for solids, **1.5 %** for `final` (3MF tessellation of a 1 mm skin; the BUILD agent measures the real error on the six exports, pins the tolerance in the table, and a wall 1.2 / 0.8 mutant must still fail).

### Layers

- `tools/geom.py` (rung 2): `load_3mf`, `tri_arrays`, `ray_hits`, `first_hit`, `inside`, `manifold_report`, `R`. `tools/solid.py` (WP1): `Solid` protocol (`bbox() -> (min, max)`, `volume() -> float`, `inside(p) -> bool`, `hits(origin, direction) -> list[float]`, sorted ray parameters, unit direction), `TriMesh(Solid)`, `Probe` (`run(solid) -> list[R]`).
- `PART` (one table): `SIDE = 120`, `H0 = 30`, `BOSS_D = 70`, `BOSS_H = 25`, `TOP = H0 + BOSS_H = 55`, `HOLE_D = 60`, `OFFSET = 5`, `R_BIG = 5`, `R_SMALL = 1.5`, `WALL = 1.0`, `OPEN = "-Z"`, footprint centred on the origin. `VOLUMES` = the table above.
- Probes (small, named, reusable): `Bbox(size, min_corner)`, `Volume(stage)`, `Watertight`, `Boss(r, top)`, `Hole(r)`, `Corner(point, u, R)`, `Wall(origin, direction, pairs)`, `OpenBack`.
- `STAGES = {"base": [Bbox(120,120,30), Volume, Watertight], "boss": [Bbox(120,120,55), Boss, Volume, Watertight], "cut": [Bbox55, Boss, Hole, Volume, Watertight], "r5": [Bbox55, Boss, Hole, Corner×4 vertical, Corner×4 front outer, Corner root, Volume, Watertight], "rounded": [… + Corner×2 annulus, Volume, Watertight], "final": [… + Wall×…, OpenBack, Volume(1.5 %), Watertight]}`. A new stage is a new list; the CLI only looks up the table.

### Checks (derived numbers; `u` = unit direction, `R(√2−1)` = 0.4142·R)

| Check | Probe | PASS when |
|---|---|---|
| `bbox` | bbox of all vertices | `120 × 120 × H` (`H` = 30 in `base`, 55 otherwise) within `TOL` each; min corner `(−60, −60, 0)` within `TOL` (catches an un-centred rectangle) |
| `watertight` | `manifold_report` | closed, no open edges, no non-manifold edges, one component (the hole and the shell do not split the part) |
| `boss` | `inside((±34.8, 0, 45))`, `((±35.2, 0, 45))`; ray `−Z` from `(32.5, 0, 70)` | radius `35 ± 0.2`; first hit `z = 55 ± 0.2` (`boss` and later stages; front level: ray `−Z` from `(45, 0, 70)` first hits `z = 30 ± 0.2`) |
| `hole Ø60` | `inside((29.8, 0, z))` False and `inside((30.2, 0, z))` True for `z ∈ {2, 15, 28, 42, 53}` (the second is True because material or the 1 mm tube is there); ray `+Z` along the axis from `(0, 0, −10)` | diameter `60 ± 0.4`, **no hits** on the axis (through base and boss) |
| `corner R5 vertical` (×4) | at the sharp corners `(±60, ±60)`, `z = 15`: `u = (±1, ±1, 0)/√2`; ray from `corner + 3u` along `−u`; `t − 3` (starting outside keeps the probe valid after the shell) | `2.071 ± 0.083` (`R(√2−1)` with `R = 5 ± 0.2`); R4 mutant gives 1.657, R6 gives 2.485 |
| `edge R5 front` (×4) | at `(±60, 0, 30)` and `(0, ±60, 30)`: ray from `corner + 3u` along `−u`, `u = (±1, 0, 1)/√2` (and the `y` pairs); `t − 3` | `2.071 ± 0.083` |
| `root R5` | corner `(35, 0, 30)` (concave), `u = (1, 0, 1)/√2`; ray from `corner + 10u` along `−u`; first hit `t` | `10 − 2.071 = 7.929 ± 0.083` (sharp root, R0, gives `t = 10`; the mutant must fail) |
| `annulus R1.5` (×2) | outer rim `(35, 0, 55)` with `u = (1, 0, 1)/√2`; inner rim `(30, 0, 55)` with `u = (−1, 0, 1)/√2`; ray from `corner + 5u` along `−u` | `t = 5 + 0.621 = 5.621 ± 0.06` each (`R = 1.5 ± 0.15`; missing fillet gives 5.0) |
| `wall x` (×4) | ray `+X` at `(y = 0, z = 15)` from `x = −70`: hits `−60, −59, −31, −30, 30, 31, 59, 60`; ray `+Y` at `(x = 45, z = 15)` from `y = −70`: hits `−60, −59, 59, 60` | consecutive pairs: each thickness `1.0 ± 0.1` (outer walls, hole tube) |
| `wall boss` | ray `+X` at `(y = 0, z = 45)` from `x = −70` | hits `−35, −34, −31, −30, 30, 31, 34, 35` (pairs `1.0 ± 0.1`) |
| `wall corner` | diagonal from `(50, 50, 15)` along `(1, 1, 0)/√2` | hits at `t = 11.071` and `12.071`: thickness `1.0 ± 0.1` (the R4 / R5 concentric corner) |
| `plates` | ray `+Z` at `(45, 0)` from `z = −10`; ray `+Z` at `(32.5, 0)` from `z = −10` | hits `29, 30` and `54, 55`: thickness `1.0 ± 0.1`; **no hit below** `z = 29` / `54` (the back is open) |
| `open back` | `inside((45, 0, 15))` False; ray `+Z` from `(45, 0, −10)`: first hit `z = 29 ± 0.2` | True/False as stated; the 1 mm rim exists but the back plane does not: ray `+Z` from `(−59.5, 0, −10)` first hits `z = 0 ± 0.2` and leaves the wall at `z = 27.18 ± 0.3` (inside the front fillet) |
| `volume` | signed mesh volume | stage value within tolerance: `base 432000.0`, `boss 528211.3`, `cut 372702.4`, `r5 370784.6`, `rounded 370587.4`, `final 39311.0` (1.5 %) |

A mesh whose `watertight` fails prints that line and the later geometry lines still run (one bad check does not hide the others). `usage` errors (unknown stage, missing file) print `FAIL usage`.

### Unit tests: `tools/test_check_rung03.py`

Plain `unittest`, no kernel, no app. The test-only `ImplicitPart03(params)` is analytic: `outer(p)` = rounded base (`distance to the core [−55,55]² × (−∞,25] ≤ 5`, `0 ≤ z ≤ 30`) ∪ boss (`ρ ≤ 35`, `z ∈ [30, 55]`, top rims rounded 1.5) ∪ root fillet (`ρ ∈ [35, 40]`, `z ∈ [30, 35]`, outside the circle of radius 5 about `(ρ = 40, z = 35)`), minus the hole `ρ < 30`; `cavity(p)` = the same recipe with radii `R − WALL` (corners 4, front edge 4, rims 0.5), the root arc radius `5 + WALL = 6`, tube `ρ ≥ 31`, boss wall `ρ ≤ 34`, plate `z ≤ 29` / `54`, open below; material = `outer ∧ ¬cavity`. `hits` steps 0.01 mm and bisects. `volume()` of the correct part is checked against `VOLUMES` by the probe tests through a stub `Solid`, not by gridding. Cases:

1. Every stage passes on its correct `ImplicitPart03`, built from the `PART` table.
2. **Mutations fail with the named check**: base depth 50 (`bbox`, the wrong-source guard), rectangle not centred (`bbox`), boss Ø60 or Ø80 (`boss`), boss height 20 (`bbox`), hole Ø50 or Ø70 (`hole Ø60`), blind hole (`hole Ø60`), R4 / R6 vertical corners (`corner R5 vertical`), no root fillet (`root R5`), R1.5 missing on one rim (`annulus R1.5`), wall 1.5 and 0.5 and one side 2 (`wall x`), back closed (`open back`, `plates`), shell thicker only at the corner (`wall corner`), a duplicated body (`watertight`), a flipped triangle (`watertight`), a stage file checked as the next stage (`bbox`).
3. `Volume` perturbed by ±1 % passes at 1.5 % for `final`, ±2 % fails; ±0.4 % passes and ±0.7 % fails for the solid stages.
4. `params` prints JSON with the keys the walk reads.
5. `check_rung01.py` and `check_rung02.py` keep passing their own tests after the move to `solid.py`.

Real meshes are checked by the walk's exports and by the WP9 validation suite `rung03_part_check`, so the analytic model and OCCT cannot drift apart unnoticed.

## Out of scope / deferred

Written down here so it is not repeated in chat.

- **Associative offsets.** The offset circle is driven by a stored radius, not re-projected when the boss diameter changes (no walk row resizes). Owner when needed: `docs/plan/roadmap.md`.
- **Real datum planes.** Front / Top / Right are only `SectionPlane` presets and the frame decision; sketching on them is not built.
- **Hidden-edge pick-through** (video: "hidden edges can also be selected"): picks go through the `corner → view` table.
- **Fillet Full preview** and the callout UI; Shell Show preview.
- **Changing the default Extrude Op** on a face sketch to Fuse.
- **Section: stencil cap for non-convex stacks, saved section state, multiple planes, section of assemblies.**
- **Rung 3 demo film** (like the Lesson 2 box film) is a follow-up after the walk is green.
- **`docs/plan/STATUS.md`** is not edited by this plan or by its BUILD PR.
