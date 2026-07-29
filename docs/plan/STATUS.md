# solidexpress build status

Updated by agents on every merge. See `docs/plan/implementation-plan.md` for task definitions.

## Operating protocol (current)
- Most implementation work goes to Grok background agents with exclusive, non-overlapping file sets and scratch build dirs; Fable only integrates, reviews, fixes failures, and commits.
- NO actions that require user approval: run only command shapes that auto-approve (sandboxed cmake/ctest builds; allowlisted `make test` and `tools/godot/godot --headless ...`). Subagents must never request elevated permissions — if verification is blocked in the sandbox, report it as pending for the integrator to run.

## Phase 0 — Foundation
- [x] 0.1 Repo layout + CMake superbuild + THIRD_PARTY.md (OCCT 7.9.2 system, godot-cpp master pinned to 4.7-stable API dump, PlaneGCS vendored from FreeCAD + shim headers, miniz, nlohmann/json, Catch2)
- [x] 0.2 sxkernel scaffold: Document, Body, EntityId (UUIDv4), undo/redo CommandStack; commands: AddPrimitive, DeleteBody, TranslateBody, PushPull
- [x] 0.3 Semantic card registry v1: MD generation + parsing, free-text (Aliases/Notes) preserved across regeneration
- [x] 0.4 Tessellation service (OCCT BRepMesh → raw buffers) + ArrayMesh bridge (one surface per face, edge polylines)
- [x] 0.5 Exact B-rep ray picking with stable face UUIDs (kernel + Godot `pick()`)
- [x] 0.6 `.sxp` container (miniz zip: manifest.json + breps + cards), UUID-stable round trip
- [x] 0.7 Headless Godot test runner (`game/tests/run_tests.gd`), `make test` (kernel Catch2 + Godot integration)
- [x] 0.8 Autosave (60 s timer in main.gd, revision-gated, `user://autosave.sxp`); logging via `sx::log`

Test state: `make test` → kernel 24 cases / 5373 assertions PASS; Godot integration 33 checks PASS; Phase 1 shell 33 checks PASS.

## Phase 1 — Drag-and-drop shell
- [x] 1.1 Viewport navigation: OrbitCamera (middle-drag orbit, shift+middle pan, wheel zoom, F frame), grid + axes, Z-up ModelSpace mapping kernel frame to Godot Y-up
- [x] 1.2 Primitive palette (box/cylinder/sphere/cone/torus) with Godot drag-and-drop onto viewport + click-to-insert
- [x] 1.3 Selection: click = body, second click = face; per-face highlight materials; card panel (RichTextLabel) shows semantic card of selection
- [x] 1.4 Move: drag selected body on ground plane (live preview, kernel commit on release)
- [x] 1.5 Push/pull: drag a selected face along its normal (ray-line closest-approach math), planar faces v0
- [x] 1.6 Undo/redo (Ctrl+Z/Y), delete (Del), save/load (Ctrl+S/O) wired; status bar hints
- [x] 1.7 Per-axis move constraints: face stretch arrows + ΔZ leave/approach grip; tap X/Y/Z mid body-drag to lock (full move triad gizmo still not drawn)


Key files: `game/scripts/document_view.gd` (view-model), `viewport_interaction.gd` (input), `orbit_camera.gd`, `palette_button.gd`, `main.gd` (composition root). Tests: `game/tests/run_ui_tests.gd`.

## Phase 2 — Sketching + solver
- [x] 2.1 Sketch model: Point/Line/Circle/Arc entities, 11 constraint types, stable param storage (`sx/sketch.hpp`)
- [x] 2.2 SolverBackend seam (`sx/solver.hpp`) + PlaneGCS backend (DogLeg, diagnostics: dofs/conflicting/redundant) — AI-first backend plugs in here later
- [x] 2.3 Profile→face builder (closed loop chaining of lines/arcs, circle→disk, construction geometry excluded)
- [x] 2.4 Extrude (incl. symmetric) + Revolve commands, undoable, snapshot pattern
- [x] 2.5 SxSketch GDExtension binding (entities, constraints, solve, entity_info snapshots) + `SxDocument.extrude_sketch/revolve_sketch`
- [x] 2.6 Sketch mode UI v1: sketch on ground plane or selected planar face; line-chain/rect/circle tools with live preview; toolbar with extrude distance; Esc cancel (`game/scripts/sketch_mode.gd`) — constraint toolbar + dimension input still TODO
- [x] 2.7 Sketch persistence: sketches embed in features.json inside .sxp (sketch_json.cpp); sketch entity cards still TODO
- [x] SW sketch parity (visual-first): compact left rail + on-canvas chips; Power Trim hover/drag; entity variants (rect/circle/arc), ellipse/slot/point/centerline; Convert/Mirror/Pattern; Smart Dim; sketch blocks + picture underlay; multi-sketch **Path** feature (no free 3D sketch). Howtos: `docs/howto/visual-sketch-tools.md`, `docs/howto/multi-sketch-merge.md`.
- [x] SW-class sketch upgrades (A–F): Midpoint/Symmetric/Fix/Diameter + driven dims; expression dims (`=w/2`) via VariableTable; definition-state / Fully Define / Analyze; associative Convert Entities; kernel Spline + PlaneGCS poles; loft guide rails. Kernel: `test_sketch_sw_upgrades.cpp`. Godot: `run_sketch_fully_defined_tests.gd`, `run_sketch_expr_dim_tests.gd`, `run_convert_entities_tests.gd`.

Test state additions: kernel [sketch]+[extrude] 14 cases; Godot sketch binding 23 checks PASS (parametric re-solve verified).

## Modeling operations (delivered by parallel agents, merged)
- [x] Booleans: BooleanCommand fuse/cut/common with keep_tool option, snapshot undo/redo ([booleans], 5 cases)
- [x] Fillet + chamfer: FilletCommand/ChamferCommand on edge id lists ([dress], 4 cases). Note: chamfer d=2 on 10mm edge removes 0.5·d²·L → volume ≈980
- [x] Interop: STEP/IGES/STL import+export in `sx/interop.hpp` ([interop], 4 cases). Quirks: StlAPI ASCIIMode() true=ASCII; IGES imports often shells not solids

Kernel suite now 51 cases / 5492 assertions.

## Phase 3 — Parametric timeline
- [x] 3.1 FeatureGraph: data-driven features (primitive/sketch/extrude/revolve/boolean/fillet/chamfer) with JSON params, stable output-body ids across regeneration, suppression, dependency protection, failure reporting naming the offending feature; persisted as features.json in .sxp; parametric edit-after-reload verified ([features], 7 cases)
- [x] 3.2 Topological naming service ([naming]): signature matching; face/edge/shell/push-pull/draft feature params store durable UUID refs (legacy map indices still load) — see [decisions.md](decisions.md) ADR-002
- [x] 3.3 Timeline UI (feature list panel, suppress/edit/rollback) + SxDocument graph bindings
- [x] 3.4 Route interactive commands through the graph: palette/sketch/extrude, fillet/chamfer, boolean, mirror/pattern/shell/offset, push-pull, draft via `graph_add_*` (direct commands remain free-body / test fallbacks) — ADR-001

## Modeling operations round 2 (parallel agents, merged)
- [x] Transforms: MirrorBody, LinearPattern, CircularPattern, RotateBody (in-place, ids preserved) ([transform], 5 cases)
- [x] Shell (open-face hollow via MakeThickSolidByJoin) + OffsetBody ([hollow], 3 cases). Note: oversized shell must use thickness ≥ half the box to reliably fail in OCCT
- [x] Measure: min_distance, closest_point (perp foot), face_midpoint, bounding_box, mass_properties (incl. inertia), edge_length, face_area, angle_between_faces ([measure])
- [x] Hover tap-measure: X snaps to corner / edge mid / surface mid; approach shows perpendicular onto near body before X relocates; move magnets include real face mids

Kernel suite: 72 cases / 5678 assertions.

## Phase 3: parametric timeline
- [x] 3.1 Feature history graph (data-driven features, JSON params, embedded sketches), regeneration with stable body ids, .sxp persistence ([features], 8 cases)
- [x] 3.3 Timeline UI: TimelinePanel (rows, suppress, delete, universal JSON param editor), SxDocument graph_* bindings, palette/sketch ops routed through the graph, undoable via whole-graph GraphSnapshotCommand
- [x] 3.2 Topological naming service ([naming], 5 cases): signature matching (geom type, centroid, size, axis; normalized greedy assignment) in `sx::naming`; replace_body_shape remaps ids, regeneration reuses live bodies, cards/aliases survive parametric edits and undo/redo

## Phase 4: modeling ops in the UI
- [x] SxDocument bindings: mirror_body, linear/circular_pattern, rotate_body, shell_body, offset_body, measure_* (distance/bbox/mass/edge/face/angle)
- [x] OpsPanel (context ops on selection): fillet/chamfer all edges, mirror, patterns, offset, shell-from-face, armed two-click boolean + measure flows

Godot suites (as of round 11): integration 97, UI 223, sketch 38, sketch-tools 105, display 72 — all green. Kernel: 6480+ assertions.

## Phase 5: workflow depth
- [x] Sketch select tool + constraint toolbar (H/V/parallel/perpendicular/equal/coincident, driving dims with live PlaneGCS solve)
- [x] Revolve + cut/fuse finish modes via the graph (target = body sketched on; parametric cut depth)
- [x] Editable card aliases/notes in the panel; free text survives rebuilds (naming service)
- [x] Edge selection (pick near edge, highlight, edge card) + single-edge fillet/chamfer
- [x] Fillet/chamfer on timeline bodies recorded as parametric graph features
- [x] File menu: New/Open/Save/Save As (.sxp), STEP import/export, STL export
- [x] Standard views (1/2/3/7) + zoom-to-fit (F)
- [x] Sweep/loft kernel commands ([sweep]); datum planes/axes/points ([datum])
- [x] Mirror/pattern/shell/offset as parametric graph feature types ([featops])
- [x] Sketch arc (3-point) + polygon tools
- [x] Body rename + per-body display color (ops panel, tinted materials, .sxp persistence; rename refreshes face cards)

- [x] Sweep/loft as parametric graph feature types ([featsweep])

- [x] Display modes: shaded / shaded+edges / wireframe (W key cycles)

- [x] Draft/taper kernel command ([draft], BRepOffsetAPI_DraftAngle with undo)

- [x] Sketch corner fillet + entity offset tools ([sketchtools])

- [x] Sketch fillet/offset exposed in sketch mode (SxSketch bindings + fillet_selected/offset_selected)

- [x] Face draft in ops panel (angle spinbox, +Z pull, bbox-bottom neutral plane)

- [x] Section view: clipping plane via discard shader (set_section_plane/clear_section_plane)

- [x] Sketch construction geometry (excluded from profiles, solves normally, JSON-persisted)

- [x] Sweep/loft on the timeline from GDScript (graph_add_sweep/graph_add_loft)

- [x] Hole feature kernel command ([hole]: simple/counterbore/countersink with undo)
- [x] Construction toggle (X) + section view toggle (K) wired into the viewport
- [x] Datums stored on Document, persisted in .sxp (datums.json), bound to GDScript, drawn in viewport (no cards yet — EntityKind lacks datum kinds)

- [x] Hole as parametric graph feature ([feathole]) + ops-panel Hole row (type/diameter/depth)
- [x] Datum EntityKinds + auto-registered semantic cards (survive .sxp load)
- [x] Sketch on selected axis-aligned planar face (outward normal, cut/fuse target kept)

- [x] Variables/equations table ([variables]): "=w*2" expressions in feature params, cycles detected, .sxp-persisted with the graph
- [x] Sketch snapping: endpoint/midpoint/center + H/V axis, preview marker, toggle
- [x] Helix/spiral/polyline wire builders ([curves]) — threads/springs groundwork

- [x] Variables panel beside the timeline (add/edit/delete, undoable, regenerates)
- [x] HelixSweep parametric feature ([feathelix]) — springs, variable-driven
- [x] Live dimension annotations in sketch mode (Label3D, recomputed from solved geometry)

- [x] Timeline reorder ([featorder], dependency-validated) + inline feature rename
- [x] Sketch trim tool ([trim]): lines split/shortened at intersections, circles become arcs
- [x] WorldGizmos: origin triad + XY grid, G toggles (old main.gd grid removed)

- [x] Trim tool in sketch mode (T key), stale dimension labels pruned
- [x] ImportStep timeline base feature ([featimport]): path + index + scale, parametric
- [x] Component instances on Document ([instances]): transform placements, .sxp persisted, cascade on source delete

- [x] Instances end-to-end: GDScript bindings (add/list/remove/set_instance_transform), viewport rendering (lightened source tint), ops-panel placement, cascade cleanup on source delete
- [x] Modeled Thread graph feature ([featthread]): triangular form swept along a helix, cut or fuse on a cylindrical region
- [x] Sketch EXTEND + LINEAR PATTERN tools ([sketchtools])
- [x] AI context export includes variables/datums/instances; File > Export AI Context...; Insert menu for datum planes/axes/points; ortho/perspective toggle (key 5) — run_menu_tests.gd

Round 12 test state: kernel 176 cases / 6571 assertions; Godot: integration 97, UI 240, sketch 38, sketch-tools 105, display 72, menu 15 — all green.

## Phases 13-20 — UX parity plan (current)
See `.cursor` plan "CAD UX parity plan": 13 quick wins (README, zoom-to-cursor, file hygiene, shortcuts overlay, click-to-place fix), 14 layout hygiene (docks, auto-hide panels, collision test), 15 workflow tests + click audit, 16 selection (multi/box select, hide/isolate, context menu), 17 property panels, 18 sketch feel (inference, DOF colors, editable dims), 19 ViewCube + named views, 20 mates/appearances/threads std/drawings/configs.

Round 13 (integrated, committed):
- [x] 13: README + build docs; zoom-to-cursor; unsaved-changes guard + recent files; F1 shortcut overlay (run_help_tests 112); click-then-place with ghost preview + Esc (run_place_tests 20)
- [x] 14: context panels auto-hide when empty (selection card, timeline, variables w/ View-menu override); ops panel height clamp + scroll; 1600x900 window; layout-collision regression suite (run_layout_tests 21) — text/panel overlap checks
- [x] 15: 12-part workflow suite (run_workflow_tests 60): chamfered plate w/ corner holes, L-bracket, shell box, washer, flanged cylinder, funnel loft, bolt blank, spring, pipe elbow, ribbed plate, bearing block, pin+plate instance; gesture counts + gap notes printed per part
- [x] 16.1: multi-select (Ctrl+click bodies/faces/edges, multi-edge fillet, multi-face shell; run_select_tests 24)
- [x] 17.1/17.2: schema-driven PropertyPanel with live preview + OK/Cancel + expressions (16 feature types; run_property_tests 17)
- [x] 18 (partial): H/V + coincident inference, DOF green coloring, editable dimensions (run_infer_tests 18)
- [x] 20.1 (kernel): fixed/plane-coincident/concentric mates + solve, .sxp persisted ([mates]; run_mate_tests 15)
- [x] 20.2: material table (21 materials) w/ density-driven mass_g in measure_mass, .sxp persisted, ops-panel picker + Mass properties readout ([materials])
- [x] 20.3: ISO/UNC thread standards table ([threadstd])
- [x] 20.4: drawings MVP — HLR projections, hidden dashed lines, three-view SVG export via File menu ([drawings])
- [x] 20.5: configurations — named variable-table snapshots, activate regenerates, .sxp persisted, variables-panel switcher ([configurations])

Round 14 (integrated, committed):
- [x] 16.2/16.3: rubber-band box select (window/crossing) + hide/isolate/show-all on H/I keys (run_visibility_tests 25)
- [x] 18 (complete): sketch drag-to-edit — grab endpoints/whole/center/rim with SELECT tool, live kernel commit via new `SxSketch.set_entity_geometry` binding + re-solve so constraints hold during drags, failed solves revert (run_drag_tests 33)
- [x] 19: ViewCube-style ViewWidget (click faces/edges/corners to snap view, animated transitions) + named views on OrbitCamera, mounted top-right (run_viewcube_tests 36)
- [x] 20.1 (complete): AssemblyPanel — instance/mate lists, place/remove, armed two-click mate flow, solve; auto-hides when empty; icon buttons + tooltips (run_assembly_tests 20)
- [x] UI visual language: icon buttons with tooltips everywhere (47 SVG glyphs, run_icon_tests 13)

Round 14 test state: kernel 199 cases / 6955 assertions; Godot (20 suites): integration 97, UI 240, sketch 38, sketch-tools 105, display 72, menu 50, workflow 60, select 24, property 17, infer 18, mate 15, camera 21, help 112, place 20, layout 21, icon 13, visibility 25, viewcube 36, assembly 20, drag 33 — all green.

## Phase 28 — Voice ask bridge (round 19)
- [x] `sx::voice` deterministic interpreter (text → Intent); Catch2 `[voice]` + golden corpus ≥75% hit rate on 127 phrases
- [x] `sxvoice` optional STT stub (whisper.cpp when `SX_BUILD_VOICE=ON` + vendored tree); `SxVoiceStt` GDExtension
- [x] Hold-V `VoiceCapture` overlay (mic pulse, WAV best-effort, headless-safe); Shortcuts "V (hold)"
- [x] `VoiceExecutor` maps intents → constraints / model ops / views / queries / variables; unmatched → `user://voice/unmatched.jsonl`
- [x] Phrase corpus + GBNF: `docs/voice/` (127 phrases, `commands.gbnf`)
- [x] Godot `run_voice_tests` 29 checks

Round 19 test state: kernel 210 cases / 7043 assertions; Godot voice 29 + help 115 — key suites green.

## Usability / how-tos (post voice bridge)
- [x] Place trust: ghost sits on floor; Esc after palette arm; selection kept after commit+release; middle/wheel orbit via `_input` (works over docks)
- [x] Stack-on-face: `insert_primitive` uses floor z; place ray hits body top → stack; three boxes → height 150
- [x] How-tos: `docs/howto/place-and-orbit.md`, `stack-three-blocks.md`, `extrude-s-shape.md`, `horizontal-hole.md` + README links; `run_howto_tests.gd` mirrors goals
- [x] Place suite extended (34 checks)

## File drop / mesh import (in progress → landed)
- [x] OS `files_dropped`: STL → `ImportStl` feature (scale param) + whole-body select + HUD/property Scale; SVG → sketch picture on face/ground; STEP → `ImportStep`; `.sxp` → open
- [x] File menu Import STL; Ctrl+A select-all (sketch entities / faces / imported body as one selection)
- [x] Kernel `[featimport]` STL case; UI `test_graph_import_stl` (269 UI checks)
- [x] Edit menu: Undo/Redo/Cut/Copy/Paste/Paste Special/Select All/Delete; Ctrl+X cut (materialized clipboard); Ctrl+Shift+V paste special; sketch entity clipboard; context-menu clipboard

## Later phases
See friendliness plan (phases 21–27) + AI-first solver upgrade for unmatched voice.

## Phase 21 — Precision placement (friendliness)
- [x] 21.1 Pickable hole placement: **Place hole…** arms a pick; nearby magnets snap
  (corner → edge **Inset**, mid / face mid as-is); far clicks place freely. **Inset** defaults from
  Hole Ø + face thickness + material softness (TPU/thick > steel/thin). **Apply hole** remains face-center
- [x] 21.2 Property panel angles in degrees: revolve `angle` and circular `total_angle` display °,
  convert ↔ kernel radians (JSON storage unchanged)
- [x] 21.3 Pickable pattern / mirror: **Linear…** / **Circular…** / **Mirror…** arm edge/face picks;
  one-click Linear/Circular/Mirror keep +X / +Z / +X-face defaults
- [x] 21.4 Expose helix + thread: `graph_add_helix` / `graph_add_thread` bindings;
  Insert → Helix Spring…; Modify → Thread… on selected body
- [x] 21.5 Graph undo hygiene: `CommandStack::push_executed` so graph edits do not double-regenerate;
  push/pull stores face_point/normal fallback; modifying features no-op when target is suppressed

## Architecture hardening (2026-07-24)
- [x] ADR ledger: [decisions.md](decisions.md) (FeatureGraph SoR, UUID topology refs, non-throwing Godot boundary, opt-in async regen)
- [x] Interactive modeling routes through `graph_add_*` (mirror/pattern/shell/offset/push-pull/draft/dress-up); free-body direct commands remain fallbacks
- [x] Feature apply handlers split under `sxkernel/src/features/`; UI `CommandRegistry` + `SelectionService`; `SxMeasure` / `SxInterop` facades
- [x] CI: `.github/workflows/ci.yml` runs kernel Catch2 on Ubuntu; Godot job stubbed until `tools/godot` is provisioned
- [x] `SxDocument.set_async_regen` / `graph_regenerate_async` / `graph_async_regen_poll` spike (default off)

## Needle-nose pliers gaps (2026-07-28)
- [x] Survey: [workflow-study-needle-nose-pliers.md](../survey/workflow-study-needle-nose-pliers.md)
- [x] P0: `instance_revolute_axis` + MOVE_INSTANCE revolute drag; AssemblyPanel instance↔instance mates
- [x] P1 (partial): Extrude end conditions `blind` / `through_all` / `midplane` (thin + open-profile cut deferred)
- [x] Golden: `game/tests/run_pliers_motion_tests.gd` (jaws+pin, concentric+coincident, drag angle)

## Environment notes
- System deps installed via apt: ninja-build, zip, libocct-*-dev (7.9.2), libeigen3-dev, libboost-dev
- Godot 4.7-stable binary at `tools/godot/godot` (gitignored; re-download from godot-builds if missing)
- Build: `make build` (CMake+Ninja superbuild, ~5 min cold for godot-cpp)
- PlaneGCS builds as `libplanegcs.so` (LGPL dynamic-link compliance); not yet consumed by sxkernel (Phase 2)
- Voice STT: default stub (`SX_BUILD_VOICE=OFF`). Enable with vendored `thirdparty/whisper.cpp` + `ggml-tiny.en.bin` under `tools/whisper/` (gitignored)
