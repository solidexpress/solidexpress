# Rung 2 plan — the SolidWorks "box" (Lesson 2, Basic Functionality)

**PLAN only, no product code.** One BUILD agent (grok, medium effort) implements this in one PR, in the order of the work packages below. Source: SolidWorks *Student's Guide to Learning SolidWorks Software*, Lesson 2 "Active Learning Exercises — Creating a Basic Part" (PDF pp. 17–24). Everything the BUILD agent needs from the PDF is in "The PDF, step by step"; it does not re-read the PDF.

Model: rung 1 (`rung-01-plan.md`, `rung-01-replan-21.md`, `tools/check_rung01.py`, `tools/walk/`, `automation-bridge.md`). Same machinery, same verdict rules (R1–R10 there), a new part, a new checker, a new walk.

## Where we are

Baseline: `main` `a79c809` (v0.1.0). Rung 1 is done and its 77-row walk is green; `tools/test_walk_registry.py` freezes its row list, and it must stay green.

Rung 2 goal: build the box with the **named tools in the PDF's order**, by clicking, through the automation bridge, and end with a part that passes `tools/check_rung02.py` at both widths (60 and 65) and every row of the checklist below.

Pass bar (all of): bbox 100 × 60 × 50; wall 5.0 ± 0.2; open top; Ø10 hole through both side walls at the specified place; the 65 → 60 edit (and 60 → 65 → 60 on the finished part) regenerates fillet, shell and cut; every checklist row PASS, no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`; critique score ≥ 9 (rule at the end).

## The part and the frame (decision, not a question)

PDF: Front plane, rectangle 100 × 65 corner at the sketch origin, edit 65 → 60, Extruded Boss Blind 50, Fillet R10 on "the four corner edges" as one feature, Shell 5 removing the top face, Extruded Cut Ø10 on the right-hand face, Through All.

SolidExpress has one sketch datum: the XY ground plane (no Front/Right planes; deferred, see the end). So the part is built **axis-for-axis as the PDF**: sketch on XY, extrude along +Z.

| Item | PDF | SolidExpress |
|---|---|---|
| Sketch | Front plane, rectangle from the origin | ground sketch, rectangle from the origin `(0,0)` to `(100, W)`, `W` = 65 then 60 |
| Base | Extrude Blind 50 | Extrude Blind 50 along +Z: bbox `X 0..100, Y 0..W, Z 0..50` |
| Fillet | four corner edges, R10, one feature | the four edges along Z (the corners of the sketched rectangle, perpendicular to the +Z cap) |
| Shell | 5, remove the top face | 5, remove the **+Z face** (the open top, `z = 50`) |
| Cut plane | right-hand face | the face with normal **+X** (`x = 100`), opened with the **Right** view (key `2`) |
| Hole | "Ø10; horizontal 25 from the left-most vertical edge; vertical 40 from the bottom-most horizontal edge" | Right view: screen right = world **+Y**, screen up = world **+Z**; centre = **25 from the face's left edge (`y = 10`, the tangent edge of the fillet), 40 from its bottom edge (`z = 0`)**, i.e. world `y = 35, z = 40` |
| End condition | Through All | Through All (both walls) |

Why `y = 35`: after the R10 corner fillets the `x = 100` face is flat for `y ∈ [10, W−10]`; its left boundary edge is at `y = 10`. The hole `y ∈ [30, 40]`, `z ∈ [35, 45]` lies wholly on the flat of both walls and above the 5 mm floor, so the cut is two clean cylinders for every `W ∈ {60, 65}`. The left edge and the bottom edge do not move when `W` changes, so the hole is the same at both widths; the cut must still **regenerate** because its sketch is attached to a face whose centre and size changed. The checker keeps these numbers in one table (`PART` in `check_rung02.py`).

Volumes (derived, used by the checker): `rounded(W) = 50·(100W − (4−π)·100)`; `inner(W) = 45·(90(W−10) − (4−π)·25)`; `no_hole(W) = rounded − inner`; `hole = 2 · 5 · π · 25 = 785.4`.

| W | block | rounded | no hole | **final** |
|---|---|---|---|---|
| 60 | 300000.0 | 295708.0 | 94173.7 | **93388.3** |
| 65 | 325000.0 | 320708.0 | 98923.7 | **98138.3** |

## The PDF, step by step → SolidExpress

Rows named in the last column are in the checklist below.

| # | PDF step | SolidExpress UI | Rows |
|---|---|---|---|
| 1 | New part (Tutorial tab → Part → OK) | File → New (empty part, `New —` status) | A1 |
| 2 | Select Front plane, Sketch | ground sketch (`sketch_ground`, Top view) | A1 |
| 3 | Corner Rectangle: click origin, move up/right, click | rail `Rect`: click `(0,0)`, click `(100, 65)` | A2 |
| 4 | Smart Dimension: top line → 100; right edge → 65; "fully defined" | rail `Smart Dim`: click top line, label, type `100`; right edge, type `65`; DOF chip `0` | A3 |
| 5 | Double-click 65, Modify → 60, OK | double-click the `65` label → editor → `60` Enter; sketch re-solves | A4 |
| 6 | Extruded Boss/Base, End Condition Blind, depth 50, OK | Extrude: `finish:Op` `Extrude`, `finish:Distance` `50`, `finish:Extrude`; feature `Extrude Blind 50.0000 mm` | A5 |
| 7 | Save as `box` | File → Save As, `box.sxp` | A6 |
| 8 | Fillet; radius 10; Full preview; click four corner edges; OK; **one** feature | Fillet armed, `10` in Radius, click the four Z edges (`Fillet: n edge(s)`), Enter | A7–A9 |
| 9 | Shell; thickness 5; click top face; OK | select the +Z face, Shell chip (`strip:shell`), thickness `5`, OK; feature `Shell 5.0000 mm` | A10–A11 |
| 10 | Click the right-hand face; **Right** view; Sketch | select the +X face, key `2`, Sketch chip | A13–A14 |
| 11 | Circle: click centre, drag, click | rail `Circle` on the face sketch | A15 |
| 12 | Smart Dimension: circumference → Ø10; circumference + left-most vertical edge → 25; circumference + bottom-most horizontal edge → 40 | rail `Convert` on the two face edges (external construction lines), then Smart Dim circle → `Ø10`, circle centre ↔ left edge `25`, circle centre ↔ bottom edge `40`; DOF `0` | A16–A19 |
| 13 | Extruded Cut; Through All; OK | Exit Sketch (keeps the part editable), Extrude with Op `Cut`, End `Through All`, OK | A20–A21 |
| 14 | (implicit in the brief) edit 65 → 60 must regenerate downstream | on the finished part: pencil on `sketch 1`, `60 → 65`, exit; export; `65 → 60`, exit; export | A22–A25 |

## What exists today (measured on v0.1.0 through the bridge)

Probes P1–P8 were run on a fresh app at `a79c809` with `SX_AUTOMATION=1`, by clicking.

| # | Probe | Result |
|---|---|---|
| P1 | rect 100 × 65 at the origin, dims by Smart Dim, edit label 65 → 60, extrude Blind 50 | works; bbox `100 × 60 × 50` |
| P2 | Fillet armed, R10, four Z edges picked, Enter | works; **one** feature with 4 edges (`Fillet: 4 edge(s)`) |
| P3 | face sketch on the `x = 100` face after Right view | opens, but the sketch plane is **upside down / mirrored**: sketch `+y` is world `−Z`, sketch `+x` is world `−Y`; the view is the Right view, so every drawn thing and every dimension direction is rotated 180° against the user's screen |
| P4 | Extrude Cut Through All from a side face | works; both walls cut on a plain box |
| P5 | double-click a drawn dimension, type, Enter | works (`edit_dim`, rung 1) |
| P6 | Shell | the only entry is an icon-only button in the face ops panel (`ops_panel._build_face_ops`): no `sx_auto` id, off-screen at 1280 × 800, a wheel scroll over the panel scrolls the model; unreachable by the bridge and by a user at the standard window |
| P7 | `click(face=<id>)` after the camera changed | selects a neighbouring fillet face: `automation_bridge._faces_cached` is keyed by the document revision only, so screen positions are stale after a camera move |
| P8 | face edges in a face sketch | `Convert` exposes only the pierce point; there is no way to get a face boundary edge into the sketch, so the circle cannot be dimensioned to the face edges. The kernel has the pieces (`external`, `projected_from`, `project_line_edge`, `mark_dangling_external`); no UI uses them |

Not measured, on purpose (the first red tests of WP3 and WP4 decide): whether Shell succeeds on the filleted body, and whether fillet and shell survive `65 → 60`.

## Gap analysis

| # | Gap | Evidence | Root cause (file : symbol) | WP |
|---|---|---|---|---|
| G1 | Face sketches on a side face are upside down | P3 | `game/scripts/sketch_mode.gd : _setup_plane` builds `x = n.cross(Vector3(0,0,1))`, `plane_y = n.cross(plane_x)`; for every side face `plane_y` is `−Z` | WP2 |
| G2 | A fillet or shell does not survive a resize of the sketch it sits on | code read: `ops_dress.cpp : match_edge_cue` accepts an edge only within **0.5 mm** of its remembered position; the four corner edges move 5 mm on `65 → 60`, so they are reported lost (soft-skip); `apply_shell` resolves its face by `resolve_topo_shape` only, with no cue fallback | `sxkernel/src/features/ops_dress.cpp`, `features.cpp : remember_dressup_edge_cues`, `naming.cpp` | WP3 |
| G3 | Shell is not reachable | P6 | `ops_panel.gd : _build_face_ops` | WP4 |
| G4 | Shell on a filleted body is unproven | not measured | `ops_dress.cpp : apply_shell` (`MakeThickSolidByJoin`) | WP4 |
| G5 | A face sketch cannot reference the face's edges | P8 | `sketch3d.cpp : convert_edges_to_sketch` is pierce-point only; no UI for `project_line_edge` | WP5 |
| G6 | Smart Dim of a circle centre against an external line must make a point-line `Distance` | not measured (the PlaneGCS `Distance` point-line exists; `_smart_dim_between` and `_add_angle_to_horizontal` add helper entities for angles) | `sketch_mode.gd : _click_smart_dim`, `_smart_dim_between` | WP5 |
| G7 | The bridge cannot address the faces and chips this walk needs | P6, P7 | `automation_bridge.gd : _faces_cached/_build_faces` (key), missing ids (`strip:shell`, `rail:Convert`) | WP6 |
| G8 | The walk machinery is rung-1-specific | `registry.py` has one global row list and `CANONICAL_ROWS`; `harness.checker()` hard-codes `check_rung01.py`; `gate()` is an if-chain | `tools/walk/` | WP7 |
| G9 | The checker has no hole, wall, fillet, open-top probes and `check_rung01.py` owns the mesh primitives | — | `tools/check_rung01.py` | WP1 |

Verified **not** gaps: Extrude Blind (P1), a single multi-edge Fillet (P2), Extrude Cut Through All (P4), dimension label editing (P5), Smart Dim of a plain line (rung 1 A3), the timeline pencil / sketch edit (rung 1 A8b).

## Design rules (Andy's goal: layers and data, not piles of conditionals)

Each WP names the layer it adds; the BUILD agent does not add an `if` branch where one of these exists.

1. **Value objects at the boundaries.** A coordinate frame is a `PlaneBasis` (origin, `x`, `y`, `normal`), built in one function from a face normal and used by `SketchMode`; no code recomputes cross products. A reference to a piece of topology is a `TopoCue` (below), not scattered `centre/dir/tol` triples.
2. **One resolution chain.** Resolving a stored reference to topology is one ordered list of strategies behind one function (`resolve(cue, shape) -> Resolved | Lost`): stable id, absolute cue, relative cue. Fillet, chamfer and shell all call it. A new strategy is one list entry.
3. **Tables for dispatch.** The checker's stages are a table `STAGES = {"base": Part(...), ...}`; the walk's rows are described by a `Rung` descriptor (rows, chunks, checkpoints, checker, expectations); the row preconditions are a table of named predicates. No `if rung == 2`.
4. **Geometry behind a protocol.** The checker talks to a `Solid` (`bbox`, `volume`, `inside(p)`, `hits(origin, dir)`); `TriMesh` implements it from a 3MF, `ImplicitPart` implements it analytically for the unit tests. No probe knows which one it has.
5. **Hotspots stay thin.** `sketch_mode.gd` and `viewport_interaction.gd` only call helper scripts (`landing-protocol.md`): new behaviour lives in `plane_basis.gd`, `sketch_edge_refs.gd`, `shell_chrome.gd`. Each file starts with a header comment of what it owns in two lines.
6. **Click-driven tests.** UI and film tests click; no private-API fallback (`.cursor/rules/gdscript-click-driven-tests.mdc`).
7. **Never** pass `user://` or `res://` into GDExtension C++ (AGENTS.md).

## Decisions (final — the BUILD agent does not choose)

1. **Scope and shape.** Eight WPs, sequential, one grok agent, one PR, then an integration step. Every WP's step 1 is a **failing** test (red output goes in the PR body), then the change. A red WP check is fixed before the next WP starts.
2. **The runner is the walker.** The rung-2 walk is `python3 tools/walk_rung02.py --out $OUT` against a local Linux build (`BUILDINFO.txt` `commit=` equals the sha under test). No screenshot is evidence. Report must show every row PASS.
3. **Frame, hole, volumes** are the tables above; the checker's `PART` table is the only place the numbers live; the plan and the walk read them from it (`check_rung02.py params`).
4. **Fillet picking** by bridge `edge=<id>` through a helper `pick_corner_edges(view_for_corner)` driven by a table `corner → view key` (Iso for the three visible corners, Back or Left for the hidden one). If a hidden-edge pick is refused by design, the table uses the view that shows the edge; the row asserts `Fillet: 4 edge(s)` after the fourth pick.
5. **Hole references.** The face sketch gets the two boundary edges as **external construction lines** via `Convert` (kernel `project_line_edge`), and the circle centre is dimensioned to each with point-line `Distance`. Both dims are driving; DOF must read `0` after Ø10 + 25 + 40.
6. **Regen contract.** After any dimension edit of `sketch 1` the document regenerates; `fillet`, `shell`, `sketch 2` (cut sketch) and the cut each resolve their references through `TopoCue`; a lost reference is an error status (and a failing row), never a silent soft-skip, **for the objects this part uses**. Rung 1's soft-skip behaviour for its own fillets is not changed (WP3 keeps `warn`, not `error`, for the unrelated lost-edge case).
7. **Status wording.** Rows judge `[status-trace] … kind=result text=…` lines since the row's mark. Texts already measured: `Fillet: n edge(s) — …`, `Fillet 4 edges 10.00 applied`. For every other text (Shell, Convert, Through All, regen) the BUILD agent measures the text on its own build in the WP that adds it, pins it in the row's clause, and lists it in the PR body.
8. **Checkpoints.** `box.sxp` (after A6), `rounded.sxp` (after A9), `shelled.sxp` (after A12), `final.sxp` (after A21). `--from <row> --checkpoint` reloads the previous chunk's file.
9. **Critique score.** Same rule as rung 1: the checker and the walk are necessary, not sufficient; the rung is Done when one build, in one critique, follows every PDF step with the named tool, scores ≥ 9 and the checker passes. A hand-built kernel sketch or a substitute tool (Box primitive instead of Rect + Extrude, a Hole feature instead of circle + Cut) caps the critique at 8.
10. **PR rules.** `github.com/solidexpress/solidexpress`; from `main`; ready (not draft); never self-merge; quick CI green (linux kernel, godot-smoke, website-demos); **do not edit `docs/plan/STATUS.md`**; new headless tests follow the click-driven rule and are registered by one `packaging/ci/suites.d/<name>.suite` file each (never edit `run_godot_suites.sh` or the Makefile recipe); `Makefile` `test-tools` gains `python3 tools/test_check_rung02.py`; PR body lists each WP's red output, every pinned status text, suite counts and the walk report head.

## Work packages

Sequential. Each: **items**, **files**, **red first**, **change**, **acceptance**. Suite names `rung02_<name>`, `script=tests/run_rung02_<name>.gd`, `tier=full` unless noted, `timeout=180`; kernel tests are Catch2 in `sxkernel/tests/` (add to its CMake list).

### WP1 — The checker and shared geometry primitives (G9)

**Files.** New `tools/geom.py` (moved from `check_rung01.py`: `load_3mf`, `tri_arrays`, `ray_hits`, `inside`, `first_hit`, `manifold_report`, and the `R` row printer), new `tools/check_rung02.py`, new `tools/test_check_rung02.py`; `tools/check_rung01.py` imports from `geom` (no behaviour change); `Makefile` `test-tools`.

**Red first.** `python3 tools/test_check_rung02.py` fails on the missing module; `python3 tools/test_check_rung01.py` stays green before and after the move.

**Change.** Implement the spec in "Spec: `tools/check_rung02.py`" below, including the `Solid` protocol, `TriMesh`, `ImplicitPart`, the `STAGES` table and the mutation tests.

**Acceptance.** `make test-tools` green; every mutation in the spec is rejected with the named row failing; `check_rung01.py` output byte-identical on its existing fixtures.

### WP2 — Face sketches are upright: `PlaneBasis` (G1)

**Files.** New `game/scripts/plane_basis.gd` (`class_name PlaneBasis`, `static func for_face(normal: Vector3, origin: Vector3) -> PlaneBasis`), `sketch_mode.gd` (`_setup_plane` calls it, loses its cross products), `main.gd` only if it recomputes a basis (`_start_sketch_on_face`).

**Rule.** If the face normal `n` is parallel to Z, keep today's basis (rung 1's face sketches on the blank's top and bottom faces must not change). Otherwise `y = Z − (Z·n) n` normalised (screen up is world up), `x = y × n` (so `x × y = n`, right-handed), the origin is the face origin as today. For `n = +X`: `x = +Y`, `y = +Z`, which is exactly the Right view (key `2`): screen right is `+Y`, screen up is `+Z`.

**Red first.** `tests/run_rung02_plane_basis.gd` (`tier=ci`): builds the box through clicks (rect, extrude), selects the `x = 100` face, key `2`, Sketch chip; asserts `sketch.plane.x == (0,1,0)`, `sketch.plane.y == (0,0,1)`, a click at the screen position of world `(100, 20, 30)` records the sketch point `(20, 30)` up to the origin offset; the same for faces `−X`, `+Y`, `−Y`; and that a `+Z` and a `−Z` face keep today's basis (`x`, `y` equal to the values pinned from `main` in the test). Red on `main`.

**Acceptance.** Test green; rung 1's `run_rung01_*` suites and the chunk-2 row `A7` expectations (face sketch on the blank's top face) unchanged; the sketch grid and dimension labels read upright in Right view.

### WP3 — References survive a resize: `TopoCue` (G2)

**Files.** New `sxkernel/src/features/topo_cue.{h,cpp}`; `ops_dress.cpp` (`match_edge_cue`, `resolve_dressup_edges`, `apply_shell` call `resolve`); `features.cpp` (`remember_dressup_edge_cues`, `cue_still_names` build `TopoCue`); `naming.cpp` only if the red test shows it must; `sketch.cpp` / feature face attachment for the cut sketch if its red test shows it.

**Design.** `struct TopoCue { Vec3 point; Vec3 dir; Vec3 size; Vec3 frac; double tol; }` — `point` absolute, `frac` the same point as a fraction of the **input shape's** bounding box (so a resize that scales the body keeps the fraction), `dir` edge tangent or face normal, `size` the face extent. `resolve(const TopoCue&, const ShapeIndex&) -> Resolution` tries, in order: stable id (existing), absolute cue within 0.5 mm (existing), **relative cue**: the unique entity of the same kind whose `dir` matches (|dot| ≥ 0.999) and whose fraction point is nearest, accepted only when it is unique within `0.02 · bbox diagonal`; otherwise `Lost` (named). The list is a `std::array<Strategy, 3>`; nothing else in the call sites knows the order. Faces use the same chain, with `size` as a tie-breaker.

**Red first.** `sxkernel/tests/test_regen_resize.cpp` (Catch2): sketch rect `100 × 65`, extrude 50, fillet the 4 Z edges R10, shell 5 on the +Z face, then set the rect dimension to 60 and regenerate; expect no lost cue, `volume(no_hole, W=60) = 94173.7 ± 0.5 %`, and wall probes via `TopoDS` section (or the 3MF tessellation) at 5.0 ± 0.1. Also `65 → 60 → 65`. If the shell step cannot be built (G4), the test stops at the fillet and WP4 adds the rest.

**Acceptance.** Test green; `test_dress.cpp`, `test_features*.cpp` unchanged; rung-1 fillet behaviour unchanged (rung 1's soft-skip `warn` tests stay as they are); a lost reference on this part is an error naming the feature and the cue.

### WP4 — Shell reachable and faithful (G3, G4)

**Files.** New `game/scripts/shell_chrome.gd` (builds the Shell entry from data: id, label, thickness field); `ops_panel.gd` / the selection strip add the entry; `ops_dress.cpp : apply_shell` only if the red test fails.

**Design.** Selecting a planar face shows a Shell chip in the selection strip, id `strip:shell` (like `StripFillet`), reachable at 1280 × 800 and by the bridge. Click → Shell panel with a thickness field `finish:Thickness` (default 5), `finish:Ok`; Enter in the field applies. The feature is `Shell <t> mm` in the timeline and its thickness is editable from the timeline (double-click) like other features.

**Red first.** (a) Catch2 `test_shell_filleted.cpp`: shell a filleted box with the open face, expect a valid solid and `no_hole(60) = 94173.7 ± 0.5 %`; if red, switch the join to `GeomAbs_Arc` and re-test. (b) `tests/run_rung02_shell_chip.gd` (`tier=ci`): click-built box, select the top face, find `strip:shell` by id, click, type `5`, Enter; assert timeline `Shell`, bbox unchanged, volume `94173.7` ± 0.5 % (the box minus `inner(60) = 201534.3`), and the `Shell` chip absent with nothing selected.

**Acceptance.** Both green; the chip is inside the window at 1280 × 800 (rect check); shell with no face selected shows a hint and adds nothing; thickness ≥ half the smaller extent is refused with a status and no feature.

### WP5 — Face edges in a face sketch; point-line dims (G5, G6)

**Files.** New `game/scripts/sketch_edge_refs.gd` (arm Convert, pick a face boundary edge → external construction line via the kernel), `sketch3d.cpp` / `sketch.cpp` binding for `project_line_edge` (expose `SxDocument.sketch_add_external_edge(sketch_id, edge_id)` if it is not exposed yet), `sketch_mode.gd` (`_click_smart_dim` / `_smart_dim_between` through a table-driven `SmartDimIntent` resolver: `(kind_a, kind_b) → constraint`, with `(circle, external_line) → Distance(centre, line)`).

**Design.** In a face sketch, `rail:Convert` armed + a click on an edge of the sketch face adds one external line, drawn as construction (dashed, not part of a profile: `sketch.cpp` already skips `construction` entities). `SmartDimIntent` is a pure function over `(entity types)` returning `{constraint_type, refs, label_anchor}`; the existing line and angle cases move into the same table (no new `if`), covered by their rung-1 tests.

**Red first.** `tests/run_rung02_face_edges.gd` (`tier=ci`): box via clicks, `x = 100` face, Right view, Sketch, `rail:Convert`, click the left edge (screen position from `project(model=[100,10,25])`) and the bottom edge (`project(model=[100,30,0])`) → two external lines; Circle; Smart Dim Ø10, circle ↔ left edge `25`, circle ↔ bottom edge `40` (each by clicking the label and typing); assert the DOF chip `0`, circle centre `(35, 40)` in world `(100, 35, 40)` ± 0.01, and no helper entity left over besides the two external lines. Red on `main` (no Convert for edges).

**Acceptance.** Green; DOF `0` and a drawn label per dimension; `Esc` leaves Convert armed state clean (one Esc disarms, rung 1's Esc ladder unchanged: `run_rung01_*` green); an edge not on the sketch face is refused with a status.

### WP6 — Bridge: faces by identity, ids for the new chrome (G7)

**Files.** `game/scripts/automation_bridge.gd` (`_faces_cached` key = `(revision, camera transform hash)`; `faces` records add `normal`, `centre`, `area`, `screen`), `docs/loop/automation-bridge.md` (selectors `face_normal=[x,y,z]` and the new ids), `tests/run_automation_bridge_tests.gd` (extend).

**Red first.** Bridge test: select face by id, move the camera (key `2`), select again by id: the second pick must report the same `normal`; red on `main` (P7). Another: `click(face_normal=[1,0,0])` on the box selects the `x = 100` face.

**Acceptance.** Bridge suite green with the new checks; the id table in the doc lists `strip:shell`, `rail:Convert`, `finish:Thickness`, `finish:Ok`, `finish:Op`, `finish:End`.

### WP7 — Walk machinery: `Rung` descriptor and the rung-2 rows (G8)

**Files.** New `tools/walk/rung.py` (`@dataclass(frozen=True) Rung(name, checker, chunks: dict[int, list[str]], checkpoints: dict[int, str], expectations: dict[str, Expect])`), `tools/walk/expect.py` (table `CHECKS: dict[str, Callable[[State, Any], str | None]]`, one entry per expectation key: `mode`, `sketch`, `bodies`, `bbox`, `timeline`, `finish_bar`; `gate()` is a loop over it), `tools/walk/registry.py` (rows register against a `Rung`, rung 1 registers as `RUNG1` with an identical frozen row list), `tools/walk/harness.py` (`checker()` uses `self.rung.checker`), new `tools/walk/rows02_chunk{1..5}.py`, new `tools/walk/ui02.py` (helpers: `pick_corner_edges`, `open_face_sketch`, `convert_edge`, `dim_between`, `export_and_check`), new `tools/walk_rung02.py` (same CLI as `walk_rung01.py`), `tools/test_walk_registry.py` (rung 1 list frozen as is; adds rung 2's list and chunk table), `docs/loop/automation-bridge.md`, `docs/loop/README.md`.

**Red first.** `python3 tools/test_walk_registry.py` with the rung-2 row list added to the test fails (no rows); rung 1's assertions green before and after.

**Change.** Implement the rows in the "Rows" tables, each as a method that only calls `ui02` helpers and `self.clause(...)`; no row carries pixel literals (rule 4 of rung 1); body guard `S0` is a clause group attached to every export row: exactly one body, name starts `extrude` / `fillet` / `shell` / `cut`, bbox `100 × W × 50` ± 0.1.

**Acceptance.** `test_walk_registry.py` green for both rungs; rung 1's full walk is not re-run by this WP (the registry test and a `--rows N22 --dry-run` smoke are enough); `walk_rung02.py --rows A1,A2,A3,A4,A5` passes on a build that has WP2 (rows before the fillet need nothing else).

### WP8 — Integration (same PR)

1. Rebuild (`make build`), `make test` (kernel and headless), `make test-tools`.
2. Full walk: `SX_AUTOMATION=1 python3 tools/walk_rung02.py --out $OUT --a15` on a local Linux build. Every row PASS; `check-*.txt` all PASS.
3. Run `check_rung02.py final` on the exported `final-60.3mf` and `check_rung02.py final --width 65` on `final-65.3mf` by hand and paste both outputs.
4. Re-run the rung-1 gate that is cheap: `python3 tools/test_walk_registry.py`, `tools/lint_rung01_e2e.py`, `tools/lint_suites.py`.
5. PR body: red outputs, pinned status texts, suite counts, walk report head, `check_rung02.py` outputs.

## Runner rules (rung 2; rung 1's R1–R10 apply unchanged, these are the additions)

1. **A row passes by clauses.** Every clause is a bridge read (`state`, `bodies`, `timeline`, `trace`) or a `check_rung02.py` line; no vacuous clause (a clause that can only pass is a runner defect).
2. **Export rows** (A5, A9, A12, A21, A23, A24) assert S0 first, then run the checker stage for that row, then record `check-<stage>-<file>.txt`.
3. **Face picking** by `face_normal=` or by `project(model=…)` + `click(screen=…)`; never a literal pixel and never `face=<id>` right after a camera move (P7; WP6 fixes the cause, the rule remains).
4. **Edge picking** by `edge=<id>` + `along=0.5`; for end-on edges the helper uses the view from the corner table.
5. **Regen rows** (A22–A25) read `status_since(mark)` and assert no `[ERROR]` line, no `soft-skip`, no `regenerate stopped`, and that the timeline keeps exactly `sketch 1, extrude 1, fillet, shell, sketch 2, extrude 2` (names pinned from the build) in that order.
6. **Dimension edits** go through the drawn label (`dim=` selector, `edit_dim`); the typed value commits with Enter; the row asserts the label text and `DOF 0` after.
7. **Checkpoints** after A6, A9, A12, A21 (`box.sxp`, `rounded.sxp`, `shelled.sxp`, `final.sxp`).
8. **A25** (headless evidence) runs `make test-godot` and `make test-kernel` with `--a15`; without the flag it is `BLOCKED-by-flag`.

## Chunks

| Chunk | Rows | Starts in | Ends in |
|---|---|---|---|
| 1 | N1 A1 A2 L1 A3 N2 A4 L2 N3 A5 A6 | fresh app | part mode, one body `100 × 60 × 50`, `box.sxp` saved, nothing selected, no menu open |
| 2 | A7 L3 A8 N4 N5 A9 | end of 1 | one `Fillet` feature with 4 edges, `rounded.sxp`, nothing selected |
| 3 | A10 L4 N6 N7 A11 A12 | end of 2 | one body, open top, wall 5, `shelled.sxp` |
| 4 | A13 A14 L5 A15 A16 N8 A17 A18 A19 L6 N9 A20 N10 A21 | end of 3 | part mode, hole cut, `final.sxp`, one body |
| 5 | A22 A23 N11 A24 N12 L7 A25 | end of 4 | `60` again, final exported, headless evidence |

## The checklist

Row prefixes: **A** action (the PDF step done with the named tool), **L** look / legibility (read from rects, labels and traces; no pixel literals), **N** negative / edge case. **Rows** = the stable id the runner reports. Every row is PASS or the walk is not green. "Clauses" are the names in `walk_report.json`. Statuses are read from `[status-trace]` result lines.

### Chunk 1 — base (11 rows)

| Row | Does | Clauses |
|---|---|---|
| N1 | Window read first: size ≥ 1272 × 750 or maximized; status bar, File menu, rail inside the window | `window`; `chrome inside` |
| A1 | File → New; empty part (`New —`); ground sketch opened (Sketch indicator in the status; Top view) | `new`; `sketch`; `Snap Infer`; `dof glyph` |
| A2 | `rail:Rect` armed (lit); click `(0,0)` then `(100, 65)`; four lines; first corner is at the origin (0,0); status after the 2nd click | `rect armed`; `four lines`; `origin corner`; `status`; `bbox sketch 100 × 65` |
| L1 | Rail labels `Rect`, `Smart Dim`, `Circle`, `Convert`, `Select` present, none clipped by the window; keys `r`, `d`, `c`, `s` (as rung 1) arm the same tools | `labels`; `keys` |
| A3 | Smart Dim: click the top line, label, type `100` Enter; click the right line, label, `65` Enter; the drawn labels read `100` and `65`; DOF chip `0` (fully defined, the PDF's "black") | `label 100`; `label 65`; `dof 0`; `lines length` |
| N2 | Smart Dim then type `0` on a line: refused (status), dimension unchanged; type `-5`: refused; `Esc` clears the editor | `zero refused`; `negative refused`; `unchanged`; `esc` |
| A4 | Double-click the `65` label, type `60`, Enter: label `60`, sketch height 60 (bbox sketch `100 × 60`), DOF `0`; one `Edit dimension` undo step | `editor open`; `label 60`; `bbox 100 × 60`; `dof 0`; `undo step` |
| L2 | Both labels are visible, not occluded, and do not overlap each other (rect test from `state.dims`) | `visible`; `not occluded`; `no overlap` |
| N3 | Extrude armed with Distance `0`: refused with a status, the sketch stays open, no feature | `zero refused`; `sketch kept`; `no feature` |
| A5 | Extrude: `finish:Op` Extrude, `finish:Distance` `50`, `finish:Extrude`; `Extrude Blind 50.0000 mm`; one body; S0; export `base.3mf`; `check_rung02.py base` PASS | `extrude`; `status`; `one body`; `S0`; `exported`; `base` |
| A6 | Save As `box.sxp` into `$OUT`; dialog gone; file exists; title shows `box` | `saved`; `file exists`; `title` |

### Chunk 2 — fillet (6 rows)

| Row | Does | Clauses |
|---|---|---|
| A7 | Select the body (click), arm Fillet (`StripFillet` chip or the rail), Radius field `10`; Fillet armed, status names the radius | `armed`; `radius 10`; `status` |
| L3 | The fillet chip and the Radius field are inside the window; the chip's y does not move when one edge is selected (rung 1 N12 rule) | `chip inside`; `chip y stable` |
| A8 | Pick the four Z edges one by one (`pick_corner_edges`); after each, status `Fillet: n edge(s)` with n = 1, 2, 3, 4 | `pick 1`; `pick 2`; `pick 3`; `pick 4`; `four edges one pick each` |
| N4 | Pick the same edge twice: the count does not grow (toggle off or no-op, as the build does; pinned); then restore to 4 | `no double count`; `restored 4` |
| N5 | With the four edges picked, Radius `30`, Enter: refused with the limit status, timeline unchanged, edges still picked; Radius back to `10` | `refused`; `timeline unchanged`; `picks kept`; `radius 10` |
| A9 | Enter: `Fillet 4 edges 10.00 applied`; exactly **one** new feature, with 4 edges; Fillet disarmed; S0; export `rounded.3mf`; `check_rung02.py rounded` PASS; save `rounded.sxp` | `applied`; `one feature`; `four edges`; `disarmed`; `S0`; `rounded`; `saved` |

### Chunk 3 — shell (6 rows)

| Row | Does | Clauses |
|---|---|---|
| A10 | Click the top (+Z) face (`face_normal=[0,0,1]`); selection reads `Face`; the `strip:shell` chip appears | `face selected`; `chip present` |
| L4 | The Shell chip is inside the window at 1280 × 800, has a visible label, is not covered by another control (rect test); wheel over it does not move the model | `inside`; `label`; `not covered`; `wheel` |
| N6 | With **no** face selected, no Shell chip; select a **side** face (+X): Shell chip is offered (any planar face) but with `Esc` nothing is added | `no chip`; `esc nothing added` |
| N7 | Select the top face again, Shell, thickness `30`: refused (limit status), no feature added, body unchanged; field back to `5` | `refused`; `unchanged`; `field 5` |
| A11 | Click Shell; thickness field `5`; Enter; status `Shell … applied`; one new `Shell` feature; bbox unchanged `100 × 60 × 50` | `panel`; `thickness 5`; `status`; `feature`; `bbox` |
| A12 | S0; export `shelled.3mf`; `check_rung02.py shell` PASS (wall 5.0 ± 0.2, open top, volume `94173.7` ± 0.5 %); save `shelled.sxp` | `S0`; `shell`; `saved` |

### Chunk 4 — hole (14 rows)

| Row | Does | Clauses |
|---|---|---|
| A13 | Click the right-hand face (`face_normal=[1,0,0]`); selection `Face`; key `2` (Right view); camera looks along `−X` | `face selected`; `right view`; `camera dir` |
| A14 | Sketch chip on the face (`_start_sketch_on_face`); sketch active; plane normal `+X`; **upright basis**: sketch `x = +Y`, `y = +Z` (read from `state.sketch.plane`) | `sketch on face`; `normal`; `basis x`; `basis y` |
| L5 | Face sketch is framed (Sketch view fit trace); the face outline is visible inside the viewport; the Right-view camera is unchanged by the sketch start | `framed`; `outline inside`; `camera kept` |
| A15 | `rail:Circle`: click a point near `(35, 40)` and drag out; one circle | `circle`; `one circle` |
| A16 | `rail:Convert`: click the left edge of the face (`y = 10`), then the bottom edge (`z = 0`): two external construction lines; status each time | `left edge`; `bottom edge`; `two externals`; `construction` |
| N8 | Convert on an edge that is **not** on the sketch face (the body's opposite side, through `project`) is refused with a status, no external added; Esc disarms | `refused`; `no new external`; `esc` |
| A17 | Smart Dim the circle: label `Ø`, type `10`, Enter: diameter label `Ø10` | `label`; `diameter 10` |
| A18 | Smart Dim circle then left external line, label, `25`: label `25`; circle centre world `y = 35` ± 0.01 | `label 25`; `centre y 35` |
| A19 | Smart Dim circle then bottom external line, label, `40`: label `40`; centre world `z = 40` ± 0.01; DOF chip `0` | `label 40`; `centre z 40`; `dof 0` |
| L6 | The three labels `Ø10`, `25`, `40` are visible, un-occluded, non-overlapping, and each sits outside the face outline (rect tests) | `visible`; `not occluded`; `no overlap`; `outside outline` |
| N9 | Edit the `25` label to `26` then back to `25`: centre moves and returns; DOF stays `0`; undo steps are balanced | `moved 36`; `back 35`; `dof 0`; `undo balanced` |
| A20 | Exit Sketch (finish bar / key); part mode; timeline `sketch 2` (name pinned); sketch not editing | `exit`; `part mode`; `timeline` |
| N10 | Extrude armed on the exited sketch with End `Blind`, depth `3`: status shows `Blind`, nothing is applied; switch End back to `Through All` | `blind selected`; `nothing applied`; `end through all` |
| A21 | Extrude with `finish:Op` Cut, `finish:End` Through All; status; one new feature; one body; S0; export `final-60.3mf`; `check_rung02.py final` PASS; save `final.sxp` | `op cut`; `end through all`; `applied`; `feature`; `one body`; `S0`; `final`; `saved` |

### Chunk 5 — regeneration (7 rows)

| Row | Does | Clauses |
|---|---|---|
| A22 | Timeline: click `timeline:pencil:sketch 1`; the rectangle sketch opens for editing; the downstream rows are greyed (rollback) and the 3D body shows `sketch 1`'s extrude only or the rollback state (pinned) | `editing sketch 1`; `rollback shown` |
| A23 | Double-click the `60` label, type `65`, Enter, Exit Sketch: status regenerate ok; no `soft-skip`, no `regenerate stopped`, no `[ERROR]`; timeline order unchanged; bbox `100 × 65 × 50`; S0; export `final-65.3mf`; `check_rung02.py final --width 65` PASS (corner radius 10, wall 5, open top, hole at `y = 35, z = 40`) | `edited`; `regen ok`; `no soft-skip`; `order`; `bbox`; `S0`; `final 65` |
| N11 | Immediately after A23: Ctrl+Z restores `60` (bbox `100 × 60 × 50`, final-60 checker PASS on a re-export), Ctrl+Shift+Z returns to `65`; no stray bodies | `undo to 60`; `final 60`; `redo to 65`; `one body` |
| A24 | Pencil, `65 → 60`, Exit: bbox `100 × 60 × 50`; export `final-60b.3mf`; `check_rung02.py final` PASS; the file is equivalent to A21's (volume within 0.1 %) | `edited`; `regen ok`; `bbox`; `S0`; `final 60`; `same as A21` |
| N12 | Save `final.sxp`, File → New, File → Open it: timeline order and the `60` label identical; the document regenerates without any status error; `check_rung02.py final` PASS on a re-export | `reopened`; `order`; `no error`; `final 60` |
| L7 | Timeline rows are legible: every row label is fully inside its row, the six feature names are distinct, none is truncated | `rows`; `names distinct`; `not truncated` |
| A25 | Headless and lint evidence (needs `--a15`): `make test-kernel`, `make test-godot` (`KEEP_GOING=1`) `0 failed`; `tools/lint_suites.py`; `tools/test_check_rung02.py`; rung 1's `test_walk_registry.py`; engine noise per R9 of rung 1 | `kernel`; `godot`; `lint`; `unit`; `registry`; `errors` |

Total rows: 11 + 6 + 6 + 14 + 7 = **44** (25 A, 7 L, 12 N).

### Pass bar for the walk

`PASS 44`, no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`; every `check-*.txt` has no `FAIL`; the `[ERROR]` list of the walk is empty apart from rung 1's R9 engine noise and the intended refusals of N2, N3, N5 and N7 (limit / zero statuses).

## Spec: `tools/check_rung02.py`

Like `check_rung01.py`: `python3 tools/check_rung02.py <stage> <file.3mf> [--width W]`; prints one `PASS`/`FAIL` line per check; exit 1 if any fails. Plus `python3 tools/check_rung02.py params` printing the `PART` table as JSON (the walk reads its numbers from there). Tolerance `TOL = 0.2` mm; volume tolerance 0.5 % (3MF tessellation of arcs).

### Layers

- `tools/geom.py` (WP1, moved from rung 1): `load_3mf`, `tri_arrays`, `ray_hits`, `first_hit`, `inside`, `manifold_report`, `R`.
- `Solid` protocol: `bbox() -> (min, max)`, `volume() -> float`, `inside(p) -> bool`, `hits(origin, direction) -> list[float]` (sorted ray parameters, unit direction). `TriMesh(Solid)` wraps `geom` and the 3MF; `ImplicitPart(Solid)` (tests only) is `rounded_box(W, R) − inner_box − cylinders` with `inside` analytic and `hits` found by stepping 0.01 mm and bisecting.
- `PART` (one table): `X = 100`, `H = 50` (Z), `R = 10`, `WALL = 5`, `HOLE_D = 10`, `HOLE = (y = 35, z = 40)`, `OPEN = "+Z"`; `W` is a parameter (default 60).
- `Probe` objects (small, named, reusable): `Bbox`, `Volume(expected)`, `Wall(axis, at)` (thickness along a ray), `OpenTop`, `Corner(R)`, `Hole(y, z, d)`, `Watertight`. Each is `Probe.run(solid, W) -> list[R]`.
- `STAGES = {"base": [Bbox_block, Volume_block, Watertight], "rounded": [Bbox_block, Corner(10), Volume_rounded, Watertight], "shell": [Bbox_block, Corner(10), Wall×5, OpenTop, Volume_no_hole, Watertight], "final": [Bbox_block, Corner(10), Wall×5, OpenTop, Hole, Volume_final, Watertight]}`. A new stage is a new list; the CLI only looks up the table.

### Checks (tolerances; `W` = `--width`, default 60)

| Check | Probe | PASS when |
|---|---|---|
| `bbox` | bbox of all vertices | `100 × W × 50` within `TOL` each; min corner `(0, 0, 0)` within `TOL` |
| `watertight` | `manifold_report` | closed, no open edges, no non-manifold edges, one component (the hole and the shell do not split the part) |
| `corner R10` (×4) | from each outer corner ray along the diagonal toward the part centre at `z = 25`: `first_hit` entry; distance from the sharp corner to the surface | `4.142 ± 0.083` (= `R(√2−1)`, `R = 10 ± 0.2`); the R5 mutation gives 2.071, R15 gives 6.213 |
| `wall x`, `wall y` (×4) | ray along `+X` at `(y = 20, z = 25)` and along `+Y` at `(x = 50, z = 25)` from both outside directions; thickness = second hit − first hit | `5.0 ± 0.2` (shell stage and final; the hole at `y ∈ [30, 40]` is not on these rays, `y = 20` is clear of it at `W = 60` and `65`) |
| `floor` | ray `+Z` from below at `(50, W/2)` | thickness `5.0 ± 0.2` |
| `open top` | ray `−Z` from above at `(50, W/2, 60)`: first hit | `z = 5 ± 0.2` (the inner floor), and `inside((50, W/2, 48)) = False`; rim: a ray `−Z` from above at `(2.5, 20)` first hits `z = 50 ± 0.2` |
| `hole axis` | ray along `+X` at `(y = 35, z = 40)` from `x = −10` | **no hits** between `x = 0` and `x = 100` (through both walls) |
| `hole Ø10` | `inside` at `(2.5, 35 ± 4.8, 40)` is False, at `(2.5, 35 ± 5.2, 40)` True, same for `z = 40 ± 4.8 / 5.2`, and at `x = 97.5` | diameter `10.0 ± 0.4` (radius `± 0.2`) on both walls |
| `hole only in x walls` | `inside` at `(50, 2.5, 40)` and `(50, W − 2.5, 40)` | True (the y walls are intact) |
| `volume` | signed mesh volume | stage value for `W` within 0.5 %: base `100·W·50`; rounded `rounded(W)`; shell `no_hole(W)`; final `final(W)` (table above) |
| `W` | the `--width` flag | `60` or `65` only; other values print `FAIL usage` |

A mesh whose `watertight` fails prints that line and the later geometry lines still run (one bad check does not hide the others).

### Unit tests: `tools/test_check_rung02.py`

Plain `unittest` (like `test_check_rung01.py`), no kernel, no app. Correct parts come from `ImplicitPart` and from a small 3MF writer (`mesh_from_implicit`, marching on a 0.25 mm grid is too coarse for the 0.2 tolerances, so the writer extrudes the analytic cross-section: rounded outline polygon with 32 segments per arc; the hole is a 64-gon prism). Cases:

1. `final` passes at `W = 60` and `W = 65` on the correct part, `shell`, `rounded` and `base` stages pass on theirs.
2. **Mutations fail with the named check** (and only plausible others): R5 corners (`corner`), R15 corners, wall 3 and wall 7 (`wall`), wall 5 on three sides and 4 on one, closed top (`open top`), hole Ø8 and Ø12 (`hole Ø10`), hole on one wall only (`hole axis`), hole moved 3 mm in `y` and in `z` (`hole axis`), hole in a y wall instead of an x wall, no hole in `final` (`hole axis`, `volume`), a `W = 65` part checked as `W = 60` (`bbox`), a duplicated body (`watertight`: two components), a flipped triangle (`watertight`), `final` file checked as `base`.
3. `params` prints JSON with the keys the walk reads.
4. `check_rung01.py` keeps passing its own tests after the move to `geom.py`.

## Out of scope / deferred

Written down here so it is not repeated in chat.

- **Front/Right/Top datum planes** (a Front-plane sketch, a Right-plane sketch). Needed by later rungs; the frame decision above avoids them. Owner when needed: `docs/plan/roadmap.md`.
- **Silhouette edges** (the PDF's "left-most vertical edge" is the visible silhouette in the PDF's view; here it is the face's own tangent edge). A true silhouette projection (HLR) is not built.
- **Hidden-line display** toggle (PDF "Hidden Lines Visible"): not needed, edges are picked by id.
- **Hole located from an edge that moves** (dimension to the `y = W − 10` edge): the cue chain would regenerate it, but the walk does not cover it; a future row once an edge-follow row is wanted.
- **Mid-plane / Both-sides cut**, **Hole Wizard**, **Fillet Full preview** and the callout UI.
- **Rung 1 soft-skip policy** is not changed.
- **`docs/plan/STATUS.md`** is not edited by this plan or by its BUILD PR.
