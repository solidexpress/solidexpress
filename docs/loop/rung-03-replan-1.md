# Rung 3 replan 1 — fixing walk 1 (24 PASS / 19 FAIL / 3 BLOCKED)

**PLAN only, no product code in this file.** Source: `docs/loop/rung-03-walk1/` (`SUMMARY.txt`,
`WALK_LOG.md`, `check-*.txt`) plus the code on `cursor/rung-03-20261012` as committed through
`65fd601`. One BUILD agent implements the work packages below, in order, in one PR. Each WP is
**items / files / red first / change / acceptance**, same shape as `rung-03-plan.md`. A red WP
check is fixed before the next WP starts (decision 1 of the original plan still applies).

## Reading the walk

`docs/loop/rung-03-walk1/SUMMARY.txt` and `WALK_LOG.md` are the per-row verdicts; the six
`check-<stage>-<stage>.txt` files are `check_rung03.py`'s per-check PASS/FAIL for each exported
stage. Every FAIL and BLOCKED row below is cited by row id; the checker lines are cited by check
name and stage.

## Root-cause map (one table, read top to bottom)

Six independent app bugs explain every FAIL/BLOCKED row and every checker FAIL. Two of those bugs
(WP1, WP2) are large and explain most of the damage because the walk keeps going after a block —
chunks 4–6 run on a body that never got its Ø60 hole, so every stage from `r5` onward is checked
against the wrong solid. Fixing WP1 and WP2 first is why they are ordered before the smaller,
independent bugs.

| Rows / checks hit | Root cause (file : symbol) | WP |
|---|---|---|
| N4, A13, N5, A14 (BLOCKED), L4 (BLOCKED), A15 (BLOCKED); `hole Ø60` FAIL on every stage r5/rounded/final/final-reopen; `wall x`, `wall boss`, `wall corner` FAIL on final; `volume` FAIL on r5/rounded/final/final-reopen; `annulus R1.5` partial FAIL (rounded/final); A19/A20/A22/N12's wrong edge counts and status text | `game/scripts/sketch_offset.gd : SketchOffset._resolve_source` / `._convert_edge` never produces a usable source from a model-edge click on the boss rim, and swallows the real reason (`SketchConvertEdge`'s own status) behind a no-op callback, so the Offset tool always reports the generic "nothing there" | WP1 |
| A17, N6, A18, N7, N8, A19 (edge count); `corner R5 vertical` FAIL ×2 on r5/rounded/final/final-reopen | Fillet's four-vertical-corner pick loses two of the four picks (toggles them back off) instead of adding all four | WP2 |
| A3 (`label 120 (2)`) | `game/scripts/sketch_mode.gd : _dimension_label_pos2` / `_rebuild_dimension_labels` / `dimension_label_screen_rects` under-report a second Smart Dimension that happens to show the same value as the first | WP3 |
| L2 (`view top`) | `game/scripts/orbit_camera.gd : enter_sketch_view` (or the normal it is given) does not aim the camera down −Z for an elevated +Z-normal face sketch | WP4 |
| L7 (`cap colour`) | `game/scripts/document_view.gd : _make_section_shader` paints the section cap through `ALBEDO` (lit) instead of `EMISSION` (flat), so it comes out darker than `SectionPlane.CAP_COLOUR` | WP5 |
| N9 (`field 1`), N11 (`K on`, `button follows`) | `game/scripts/shell_chrome.gd : ShellChrome` never releases focus on its thickness `LineEdit`, and resets a refused value to a hardcoded 5 mm instead of the part's own 1 mm | WP6 |
| L3 (`not covered`) | An Offset-panel control is covered by another chrome control at 1280×800 — host not yet identified | WP7 |
| A26 `kernel` clause reads FAIL with "All tests passed" as its only evidence | **Walk-runner bug**, not an app bug — see "Flagged walk-runner bug" below | WP0 |
| A26 `godot` clause (`10 failed`) | Expected to be exactly the suites WP1–WP6 touch (`run_rung03_offset.gd`, `run_rung03_convert_circle.gd`, `run_rung03_fillet_face.gd`, `run_rung03_origin_anchor.gd`, `run_rung03_section.gd`, `run_rung03_part_check.gd`, plus whichever kernel suite WP1/WP2's Catch2 cases land in); confirm the exact 10 in WP8 | WP8 |

Rows not listed above (N1, A1, A2, L1, N2, A4, A5, A6, A7, A8, N3, A9, A10, A11, A12, A16, L5, A21,
L6, N10, A23, A24, A25, L8, and the `base`/`boss` checker files) are already PASS and are not
touched by any WP; each WP's acceptance step re-confirms they stay PASS.

## Flagged walk-runner bug (app is right, test tooling is wrong) — fix in WP0

`tools/walk/rung3/ui03.py : WalkUI03._kernel_tests` runs `./build/sxkernel/sxkernel_tests` then
`./build/sxvoice/sxvoice_tests`, concatenates their stdout+stderr, and reports
`proc.tail(kernel.stdout, kernel.stderr)` — the **last line only** — as the A26 `kernel` clause's
evidence. `sxkernel_tests` carries every rung 1/2/3 kernel assertion; `sxvoice_tests` is a small,
unrelated speech-to-text suite (`sxvoice/tests/test_voice_stt.cpp`, "8 assertions in 1 test
case" per `sxvoice/CMakeLists.txt:61-65`). When `sxkernel_tests` fails (as it does right now,
because of WP1/WP2's bugs) but `sxvoice_tests` passes afterward, `tail()` shows only
`sxvoice_tests`'s "All tests passed (8 assertions in 1 test case)" line — the exact string in
`SUMMARY.txt`'s A26 row — hiding the real kernel failure completely. The `ok` flag
(`kernel.returncode == 0`) is computed correctly; only the **evidence text** lies. This is a
walk-tooling defect independent of whichever kernel test is actually red; fix it before relying on
A26 for diagnosis in WP8.

**Fix (WP0, do first — it is cheap and every later WP's acceptance step reads A26's kernel
evidence).** In `_kernel_tests`, keep each binary's own `(name, result)` pair; when the combined
`code != 0`, report the **tail of the first binary that itself returned nonzero** (or both tails,
labelled), not `proc.tail` of the blind concatenation.

**Red first.** No new test needed — the current `SUMMARY.txt` A26 line *is* the red: a `FAIL`
clause whose only evidence string contains the word "passed". After the fix, deliberately break
one kernel assertion locally, run `make test-kernel` through the walk's own `headless()` helper (or
just call `_kernel_tests` from a short `python3 -c` snippet), and confirm the evidence now names the
failing assertion, not `sxvoice_tests`'s summary.

**Acceptance.** `_kernel_tests` evidence always comes from a binary that actually failed when
`ok` is `False`; `a26-kernel.log` (already written by `headless()`) stays the full detail backing
it up.

## WP1 — Offset Entities cannot source a click on a model edge (G: N4, A13, N5, A14, L4, A15, and everything the missing Ø60 hole breaks downstream)

**Evidence.** `check-r5-r5.txt`, `check-rounded-rounded.txt`, `check-final-final.txt`,
`check-final-final-reopen.txt` all show `FAIL hole Ø60 got 5 samples off, axis hits 2` and a
`volume` FAIL roughly 155,000 mm³ too high (`r5`: got 526253.6 vs want 370784.6 — almost exactly
the `boss` stage's 528211.3, i.e. the Ø60 cut never happened). `WALK_LOG.md` A13 shows
`profile=[]`, `external=[]`, `dof='—'` after clicking the boss rim with `rail:Offset` armed and
`offset:Reverse` on — no entity, any entity, got created. `check-rounded-rounded.txt`'s
`annulus R1.5` row shows one PASS (`5.627`, outer rim at r=35, filleted) and one FAIL (`5.0`,
r=0 — because the *inner* rim at r=30 does not exist without the cut). A14/L4/A15 are
`BLOCKED-by-A13`/`BLOCKED-by-A14`: once Offset fails, Esc at N5 cancels the whole sketch
(`"esc disarms"` FAIL: `status=Sketch cancelled`), not just the Offset tool.

**Root cause.** `game/scripts/sketch_offset.gd : SketchOffset.click` calls `_resolve_source(ctx,
uv)`, which first tries `ctx.nearest_entity` (nothing — the sketch is empty) and then
`_convert_edge(ctx, uv)`. `_convert_edge` builds a `SketchConvertEdge.Context` with
`status = func(_text): pass` — **a no-op** — and calls `SketchConvertEdge.new(ctx).click(uv)`
(`game/scripts/sketch_convert_edge.gd`). Whatever `SketchConvertEdge.click` actually reports
(`NOT_ON_FACE`, `NOT_SUPPORTED`, or a real external-circle id) is thrown away by that no-op before
`SketchOffset` ever sees it; a legitimate "edge is not on this face" or "edge type not supported"
refusal is indistinguishable, from Offset's side, from "nothing there at all" — so Offset always
reports its own generic `NOTHING` text regardless of what actually went wrong inside Convert.

**Where to actually look (narrowed, not yet proven).** `game/tests/run_rung03_convert_circle.gd`
and `game/tests/run_rung03_offset.gd` already exist, already drive the exact same click-built
boss + rim-click scenario the walk does, and both carry `print()` diagnostics
(`"  host %s"`, `"  host after arm %s edges %d"`, `"  rim status: %s"`, `"  external circles %d"`)
built specifically to show *which* link breaks. They are almost certainly 2 of A26's 10 failing
godot suites. Do not re-derive the bug from a fresh read of `sketch3d.cpp`; run these two suites
first and read their prints — that is strictly cheaper and more precise than guessing. The two
most likely culprits the prints will point at:

1. `game/scripts/sketch_convert_edge.gd : _face_edge_set` / `_resolve_host_face` resolving the
   wrong host face (or an empty edge set) when the sketch's own `host_face_id` is re-derived via
   `ctx.view.faces_matching(body, want, 0.7)` instead of trusting the already-correct
   `host_face_id` passed in — classifying the boss rim as "not on this face" and refusing it.
2. `sxkernel/src/sketch3d.cpp : add_external_edge` → `dispatch_circle` / `project_circle_edge`
   (`sxkernel/src/sketch.cpp:1332`) rejecting the rim for a reason specific to this body (e.g. the
   tessellated edge's parameter span not reading as a full `2π` circle), returning a null id, which
   `SketchConvertEdge.click` turns into `NOT_SUPPORTED` — again swallowed by Offset's no-op status.

**Change.**
1. Stop swallowing Convert's status inside `SketchOffset._convert_edge`: wire its `status`
   callback to something the caller can inspect (at minimum, capture the real reason so Offset's
   own message can distinguish "nothing near the click" from "that edge is not on this face" /
   "that edge type is not supported" — three different user-facing situations collapsed into one
   today).
2. Fix whichever of the two links above the red tests point at, so clicking the boss rim with
   `rail:Offset` armed converts it to an external circle (as Convert alone already should) and then
   runs it through `offset_entities` to the inward profile circle.
3. Re-check `esc_keep_sketch()` (`game/scripts/sketch_mode.gd:5435`): its "just drop the tool"
   branch requires `not sketch.entity_ids().is_empty()`. Once (1)+(2) make Offset actually create
   entities, N5's Esc should land on that branch naturally — confirm it does; do not add a
   special case for Offset here if the existing rule already covers it once entities exist.

**Red first.** `LD_LIBRARY_PATH=/workspace/sx-build/deps/occt/V8_0_1/lib tools/godot/godot
--headless --path game --script tests/run_rung03_convert_circle.gd` and the same for
`run_rung03_offset.gd`. Both are expected red today; their prints name the exact failing step.

**Acceptance.** Both suites green. `tests/run_rung03_convert_circle.gd`'s own checks (external
circle at r=35, root circle refused, z=30 sketch refuses the z=55 rim) and
`run_rung03_offset.gd`'s (distance-0 refused, r=30 profile circle + r=35 external circle + DOF 0,
empty-click refused, Esc disarms *only* Offset) all pass. Do not re-run the full walk here (WP8
does that once); instead hand-trace rows N4/A13/N5/A14/L4/A15 against the fixed suites' assertions
to confirm each row's clause is now satisfiable, and recompute `check_rung03.py r5` /
`rounded` / `final` by hand against the corrected `cut` volume (372702.4) to confirm the
`hole Ø60`, `wall x`, `wall boss`, `wall corner`, `annulus R1.5`, and `volume` checks all have a
path to PASS once chunk 4/5 run on the real cut body.

## WP2 — Fillet loses two of the four vertical-corner picks (G: A17, N6, A18, N7, N8, A19 edge count; `corner R5 vertical` ×2 on r5/rounded/final/final-reopen)

**Evidence.** `WALK_LOG.md` A17: pick 1 → `Fillet: 1 edge(s)`, pick 2 → `Fillet: 2 edge(s)`, pick 3
→ `Fillet: 1 edge(s) ... — removed 30.0 mm vertical` (a **toggle-off**, not an add), pick 4 →
back to `Fillet: 2 edge(s)` (toggle-on of the same one dropped). A18's shift-click on the z=30 face
then reports `Fillet: 7 edge(s)` (2 verticals + 4 outer lines + the root circle), not 9. A19 applies
`Fillet 7 edges 5.00 applied`. `check-r5-r5.txt` shows exactly two of the four `corner R5 vertical`
checks PASS (`got 2.09`) and two FAIL (`got 0.0` — a bare, unfilleted 90° corner). This is
consistent and reproducible: picks 3 and 4 are landing on an **already-selected** edge from picks 1
or 2, not on the two remaining corners.

**Root cause (narrowed, not yet proven).** `game/scripts/fillet_pick.gd : FilletPick.CORNERS`
pairs two corners per view key (`(60,60)→"2"`, `(60,-60)→"2"`, `(-60,60)→"6"`,
`(-60,-60)→"6"`) and `FilletPick.decide` toggles an edge off on a repeat plain click
(`{"first": false, "mod": "plain", "hit": "edge", "action": "toggle_edge"}` —
`game/scripts/fillet_pick.gd:14`). For pick 3/4 to toggle instead of add, the edge resolved for the
third/fourth click must be the *same id* as one already picked. Two candidates, in order of
likelihood:

1. **Walk-runner timing.** `tools/walk/rung3/ui03.py : pick_corner_edges` sends `self.d.key(view)`
   then only `self.d.wait_idle(frames=2)` before resolving and clicking the edge. If the camera's
   view-key transition animates over more than ~2 frames, the click fires mid-transition and the
   simulated screen point can land on an edge that was correct for the *previous* view, not the
   new one — i.e. it is the harness that mis-clicks, and the app's own edge resolution is innocent.
   This is the cheaper hypothesis to falsify: if a longer `wait_idle` makes all four picks land on
   four distinct, correctly-reported "30.0 mm vertical" edges, this was a walk-runner bug, not an
   app bug — **flag it as such and fix `pick_corner_edges`'s settle time, not the app.**
2. **App edge resolution.** `game/scripts/ops_panel.gd : _accumulate_dressup_edge` (consulted via
   `FilletPick.decide`) resolving the clicked screen point to the wrong 3D edge independent of
   camera timing.

**Change.** Run the existing `game/tests/run_rung03_fillet_face.gd` first (it already drives
`FilletPick.CORNERS` + `FilletPick.pick_point_for_corner` through the same screen-click path, see
its `"  corner %s,%s view %s -> %s"` print at line 89) — it is almost certainly already red and
will show, per corner, which edge id actually got hit. If the same id repeats across two different
`(x, y)` targets, compare that against hypothesis 1 (increase `wait_idle` after the view-key press
in both `ui03.py` and the test, or add an explicit camera-settle wait, and see whether the repeat
goes away) before changing any app code. Only touch `ops_panel.gd` / `FilletPick` if the repeat
survives a generous settle wait.

**Red first.** `tools/godot/godot --headless --path game --script tests/run_rung03_fillet_face.gd`
(same `LD_LIBRARY_PATH` as WP1). Read the four `"  corner ..."` print lines.

**Acceptance.** `run_rung03_fillet_face.gd` green, including its
`ctx.view.selected_edges.size() == 4` assertion after all four corner picks, and the shift-click
face pick reaching 9 edges. Hand-check `check_rung03.py`'s `corner R5 vertical` math (±0.083 of
2.071) against all four corners once the fix lands.

## WP3 — A second Smart Dimension with the same displayed value is not exposed as its own label (G: A3 `label 120 (2)`)

**Evidence.** `WALK_LOG.md` A3: `label 120=ok: ['120']` (first dimension, top line) but
`label 120 (2)=FAIL: ['120']` (after the *second* dimension, right line, is applied) — still only
one `"120"` entry. `dof 0=ok` and `lines length=ok: top=120.0 right=120.0` both pass, so the
**solver** genuinely has two separate `distance` constraints (DOF reaches 0, which a single
constraint on a `Center` rect with 2 remaining DOF after the origin anchor cannot do). The gap is
specifically in what the bridge's `state.dims` reports.

**Root cause (narrowed).** The bridge's `_collect_dims` (`game/scripts/automation_bridge.gd:1694`)
is a thin wrapper over `sm.dimension_label_screen_rects()`
(`game/scripts/sketch_mode.gd:8304`), which itself skips any `dimensions[i]` whose
`label_pos` cannot be resolved (`if lp == null: continue`). `_dimension_label_pos2`
(`game/scripts/sketch_mode.gd:7433`) computes that position from the referenced line's `start`/
`end`; for a plain single-line `"distance"` dimension this should not return null for either the
top or the right rectangle line, so the exact failure point is still open — likely either (a) a
timing issue where `_rebuild_dimension_labels` (`:7563`) ran once between the two Smart Dim clicks
and the second dimension's `label_pos` was never (re)computed before the bridge read it, or (b)
`_prune_orphan_dimensions` (`:9788`, called from `_redraw`) treating the second dimension as an
orphan. `_record_dimension` (`:2881`) itself is not the bug: it keys de-duplication on the
constraint's **entity ids**, not its displayed value, so two different lines both measuring 120
correctly get two distinct `dimensions[]` entries — confirmed by reading the function, not
measured, so re-check it is not a dead end before spending time elsewhere.

**Change.** Extend `game/tests/run_rung03_origin_anchor.gd`'s existing `_centre_rect_origin` case
(it already dims both sides to 120 and checks `_driving_sides(sm) == 2`) with two more assertions,
right after both dims are applied: `sm.dimensions.size() == 2` and
`sm.dimension_label_screen_rects().size() == 2`. This isolates "solver has 2 constraints" (already
proven true) from "the label-rendering/registry layer only tracks 1" (the actual bug) in one place,
with print output showing each `dimensions[i]`'s `label_pos`. Fix whichever of
`_rebuild_dimension_labels` / `_prune_orphan_dimensions` / `_dimension_label_pos2` the new
assertion's print output points at so both dimensions always get a position and a label, even when
they display the same text.

**Red first.** The two new `check()` calls in `run_rung03_origin_anchor.gd` fail on `main`/this
branch today (that is exactly what the walk measured); everything else in that suite (which only
checked `_driving_sides` and `_label_has`, not the count) is expected to stay green.

**Acceptance.** `run_rung03_origin_anchor.gd` green with the two new assertions; existing
`rung01`/`rung02` suites that read `dimensions`/labels stay green (this file is read by many
suites — grep for `dimension_label_screen_rects` and `.dimensions` call sites before changing
behaviour, per decision 4 of the original plan: a DOF-pinned rung-1/2 suite changing is the risk to
watch).

## WP4 — Face-sketch "Normal To" camera does not look down −Z for an elevated +Z face (G: L2 `view top`)

**Evidence.** `WALK_LOG.md` L2: `view top=FAIL: look=[0.0, -1.0, 0.0]`. The row expects
`look[2] < -0.9` (looking down the sketch's own +Z normal) after opening the sketch on the
`z = 30` face and pressing `f` to fit. A `look` of `(0, -1, 0)` is a generic Front-style view, not
Top.

**Root cause (narrowed).** `game/scripts/sketch_mode.gd : _enter_camera` →
`_apply_sketch_frame` calls `camera.frame_sketch_rect(plane_normal(), ...)` /
`camera.enter_sketch_view(plane_normal(), ...)`, and `plane_normal()` (`:456`) returns
`plane.normal`, which the bridge separately reports as `(0, 0, 1)` for this exact face
(`A6`'s `normal=ok: [0.0, 0.0, 1.0]` passed). `orbit_camera.gd : enter_sketch_view` (`:1198`)
computes `yaw = atan2(n.x, -n.y); pitch = asin(n.z)`, which for `n = (0,0,1)` gives
`yaw = atan2(0, -0) ; pitch = 90°` — the same values `standard_view_table()`'s `"top"` entry uses
(`:663`), and the **ground** sketch (also normal `(0,0,1)`) is known-good through this exact
formula in rung 1/2. Since the math is identical for both cases, either (a) the camera's `normal`
input at the moment `enter_sketch_view` actually runs for a *face* sketch is not literally
`(0,0,1)` despite the bridge reporting the sketch plane as such — i.e. two different normal values
are in play, one for reporting and one for camera entry — or (b) something after `enter_sketch_view`
(the `view_key="3"` press that happens *before* face selection in `face_sketch()`, or a deferred
`_reassert_camera_if` re-fit) re-applies a different, stale camera pose. Pin this down with a
targeted assertion before touching either file.

**Change.** Add 2–3 lines to `game/tests/run_rung03_convert_circle.gd`'s `_open_z_face` helper (it
already opens exactly this face sketch) — after `check(sm.active, "face sketch is active")`, read
`ctx.main.view.get("camera")` (or however the suite otherwise reads the live `OrbitCamera`) and
assert its look direction is within `1e-2` of `(0, 0, -1)`. Run it red, then trace *why* with a
`print()` of `plane.normal` at the exact call site inside `_apply_sketch_frame` immediately before
`camera.frame_sketch_rect(...)` fires, compared against the camera's `yaw`/`pitch` immediately
after. Fix whichever of (a)/(b) the trace shows: either the normal fed into `enter_sketch_view` is
wrong at that call, or a later camera call undoes it and needs to be skipped/reordered for a locked
sketch (`sketch_orientation_locked`).

**Red first.** The new camera-look assertion in `run_rung03_convert_circle.gd` fails on this
branch today.

**Acceptance.** The new assertion passes; `run_rung03_convert_circle.gd` and
`run_rung03_offset.gd` (both open the same face) stay green; rung 1/2 suites that enter a face
sketch on a side (horizontal-normal) face are unaffected — this bug is specific to a +Z-normal face
at a non-zero height, new to rung 3.

## WP5 — Section cap renders lit instead of flat `CAP_COLOUR` (G: L7 `cap colour`)

**Evidence.** `WALK_LOG.md` L7: `cap colour=FAIL: got=[109, 112, 123] want=(158, 168, 184)`. The
ratio between got and want is a near-uniform ~0.67 across all three channels — the signature of an
unlit flat colour being scaled down by ambient-only lighting, not a wrong colour constant (which
would not scale all channels so evenly) or a wrong sample point (`removed is background` passes,
and `outline inside` passes, so the pixel is landing on the cap, just the wrong shade of it).

**Root cause.** `game/scripts/document_view.gd : _make_section_shader`'s fragment function
(`:273`) is `shader_type spatial` with `render_mode ... diffuse_lambert, specular_schlick_ggx` — a
fully lit material. Its cap branch (`:283-290`) does:
```
if (section_on && back) {
    ALBEDO = cap_colour.rgb;
    METALLIC = 0.05;
    ROUGHNESS = 0.85;
    EMISSION = vec3(0.0);
    return;
}
```
Setting `ALBEDO` still goes through Godot's lighting pass (diffuse + specular against the scene's
ambient/directional lights), so the "flat cap" is actually lit and comes out darker than
`SectionPlane.CAP_COLOUR` — exactly the observed, uniformly-scaled-down colour. `EMISSION` is the
one output that bypasses lighting entirely, and the code explicitly zeroes it.

**Change.** Swap which output carries the colour: `ALBEDO = vec3(0.0); EMISSION = cap_colour.rgb;`
(keep `METALLIC`/`ROUGHNESS` as-is or drop them, since they no longer affect an all-emission
fragment). This is the standard "flat, lighting-independent colour in a Spatial shader" pattern.

**Red first.** `game/tests/run_rung03_section.gd` already asserts this exact pixel
(`_assert_cap_pixels`, `:174-204`, comparing against `SectionPlane.CAP_COLOUR`) and is expected to
already be red for this reason — run it first instead of writing a new test.

**Acceptance.** `run_rung03_section.gd` green (both the on and off pixel assertions);
`run_display_tests.gd` and `run_visual_ux_tests.gd` stay green (decision 9/WP7 of the original plan
required `set_section_plane`'s signature and the `section_normal` uniform to stay pinned — this
change only touches the cap branch's output assignment, not the signature or the clip test above
it).

## WP6 — Shell's thickness field keeps keyboard focus and resets to the wrong value (G: N9 `field 1`, N11 `K on` / `button follows`)

**Evidence.** `WALK_LOG.md` N9: after typing `30` into Shell thickness and being refused, the field
is expected to read something containing `"1"` (this part's real wall thickness, used at A22) but
reads `field='5'`. `WALK_LOG.md` N11: pressing `k` twice, right after A22's shell apply and N10's
fillet-radius refusal, does nothing at all — `on` stays `False` both times, and
`button follows=FAIL: on=False off=False` (the HUD button never changes either).

**Root cause.**
1. `game/scripts/shell_chrome.gd : ShellChrome.SPEC["default_mm"]` is hardcoded to `5.0`
   (`:12`), and `_default_text()` (`:183`) always returns `str(int(SPEC["default_mm"]))`. Every
   refusal branch in `apply_mm` (`:99-104`, `:101-103`) resets `_field.text = _default_text()`,
   i.e. always back to `"5"`, regardless of what the user last successfully applied (`1` for this
   part, per the plan's `PART.WALL = 1.0` and A22's own `Shell 1.0000 mm applied`). The row's
   expectation ("field back to 1") matches the plan's own stated acceptance for N9
   (`rung-03-plan.md`'s checklist row N9: "...field back to 1"), so the fix is to track the last
   *applied* thickness and reset to that (seeded with the SPEC default only before any successful
   apply), not to hunt for a different hardcoded constant.
2. `_on_chip()` (`:126-142`) calls `_field.grab_focus()` when the Shell panel opens, but no code
   path in `shell_chrome.gd` ever calls `_field.release_focus()` or
   `SxUi.release_focus_on_commit(_field)` — on success (`:119`, `_panel.visible = false`) or on
   refusal (`:100`, `:102`). Every comparable panel in this codebase does release focus on
   commit/hide: `ops_panel.gd:114` (`SxUi.release_focus_on_commit(_radius_spin)`) and
   `ops_panel.gd:938,983,1021` (`le.release_focus()`), `property_panel.gd:384,417`,
   `sketch_context_chrome.gd:1403,1426,1564`, and even the Fillet strip's own radius field
   (`viewport_interaction.gd:356`, `SxUi.release_focus_on_commit(_strip_radius)`) — `shell_chrome.gd`
   is the one outlier. `game/scripts/ui_spin.gd : numeric_field_focused` (`:259`) returns true
   whenever the viewport's focus owner is a `LineEdit` (Shell's `_field` is exactly that), and
   `viewport_interaction.gd : _gui_key` (`:5030-5038`) swallows `KEY_K` (among others) outright
   whenever `numeric_field_focused` is true — before the real `KEY_K: toggle_section()` handler at
   `:5186` is ever reached. That is the entire N11 failure: the Shell field is still "focused" by
   Godot's standards from A22 onward, so every later single-letter shortcut, including `K`, is a
   no-op.

**Change.**
1. Add a `_last_mm` (or similar) field to `ShellChrome`, seeded from `SPEC["default_mm"]`, updated
   to the committed value on every successful `apply_mm`; use it (not `_default_text()`) in the
   refusal reset.
2. Call `SxUi.release_focus_on_commit(_field)` (matching the pattern already used for the Fillet
   strip radius and the ops panel fields) when `_field` is created in `build()`, or explicitly
   `_field.release_focus()` at both the success and refusal exits of `apply_mm` — pick whichever
   matches this codebase's existing convention for a `LineEdit` vs. a `SpinBox` (the Fillet strip
   uses a `SpinBox`; `property_panel.gd`'s plain `LineEdit` release pattern at `:417` is the closer
   match here).

**Red first.** No suite currently exercises this sequence in isolation; add a short case to
`game/tests/run_rung03_section.gd` (it already builds a shelled part) or a new, small
`run_rung03_shell_focus.gd`: apply the shell at `1`, confirm it applies, then press `k` and assert
`view.section_enabled` flips. Separately, assert that typing `30` into the thickness field and
being refused leaves the field reading `1`, not `5`.

**Acceptance.** The new case(s) green; `run_rung03_section.gd`'s existing N9/N11-equivalent
behaviour (if any) and `run_sketch_tools_tests.gd` / `run_rung02_*` suites that touch Shell stay
green (Shell is shared machinery across rungs — decision 10 of the original plan: `apply_mm`'s
limit rule itself is unchanged, only the reset value and the focus-release are new).

## WP7 — An Offset-panel control is covered by another control at 1280×800 (G: L3 `not covered`)

**Evidence.** `WALK_LOG.md` L3: `inside=ok: rects=[[137.0, 48.0, 120.0, 31.0], [263.0, 48.0,
110.0, 31.0], [379.0, 48.0, 31.0, 31.0]]` (Distance / Reverse / OK, all inside the window and not
overlapping each other) but `not covered=FAIL: covered=True`. The walk's `covered()` helper
(`tools/walk/rung3/ui03.py:796-810`) flags one of these three rects' *centre* as sitting inside a
different, smaller control that is not `strip:shell` (the one id it already excludes as a known,
accepted overlap).

**Root cause.** Not yet identified — this is the lowest-impact FAIL (one `L` row) and was not
chased down to a symbol in this pass. The leading candidate, given the codebase's history of two
separate Offset affordances, is that the pre-existing chip-based offset control in
`game/scripts/sketch_context_chrome.gd` (the free-circle `chip:Offset` / `DimSpin` path that
`run_rung03_offset.gd`'s `_chip_offset_still_works` case still exercises) remains mounted and
visible at the same screen position as the new `rail:Offset` panel built by
`game/scripts/sketch_offset.gd : SketchOffset.build`/`show_panel`, rather than one hiding while
the other is active.

**Change.** Before writing a fix, run the walk's own diagnostic inline: at the L3 row, print every
`controls` entry's `id` and `rect` (the walk already calls `self.refresh("controls")`; just log the
full list once) to see which control actually overlaps. Then either reposition
`SketchOffset.show_panel`'s panel placement, or make sure whichever legacy chip loses visibility
while `rail:Offset` is armed, following the same "callers ask one layer, no second code path" rule
`sketch_offset.gd`'s own header states.

**Red first.** No kernel/GDScript test exists for this yet; the cheapest red-first signal is
extending `run_rung03_offset.gd`'s existing "inside 1280×800" checks (`:73-83`) with a pairwise
overlap check across all currently-visible controls, mirroring the walk's `covered()` logic.

**Acceptance.** The new overlap check passes in `run_rung03_offset.gd`; L3's three existing clauses
(`inside`, `labels`, `wheel`) stay green.

## WP8 — Integration

Same shape as the original plan's WP9, scoped to this replan:

1. `make build`, `make test`, `make test-tools`; `KEEP_GOING=1 make test-godot` — confirm the
   count drops from `213 run, 10 failed` and identify by name every suite still red; each should
   trace to one of WP1–WP7 above or be a new, separately-triaged regression (do not fold an
   unexplained new red suite into "done").
2. Re-run the six `game/tests/run_rung03_*` suites named in WP1–WP7 individually before the full
   walk — they are far cheaper than the 46-row walk (`WALK_LOG.md` shows the full walk took
   1997.6 s; each isolated suite is seconds) and should already be green from each WP's own
   acceptance step.
3. Full walk `SX_AUTOMATION=1 python3 tools/walk_rung03.py --out $OUT --a15`: every row PASS,
   every `check-*.txt` all PASS. Compare the new `WALK_LOG.md`/`SUMMARY.txt` against this
   document's root-cause map row by row; any row that is still not PASS, or any new FAIL that did
   not appear in walk 1, needs its own root-cause note before this rung is called done.
4. Re-run `walk_rung01.py` (77/77) and `walk_rung02.py --a15` (44/44) on the same build —
   WP3 (dimension labels) and WP6 (focus/shell default) touch shared machinery; confirm neither
   regressed rung 1/2.
5. `tools/test_walk_registry.py`, `tools/lint_rung01_e2e.py`, `tools/lint_suites.py`,
   `tools/test_check_rung03.py`.
6. Paste the six corrected `check_rung03.py` outputs by hand into the PR body, same as the
   original plan's WP9 step 5, plus a short note against each row this replan predicted fixed.

**Acceptance.** `PASS 46`, no `FAIL`/`PARTIAL`/`BLOCKED`/`runner-gap`; `walk_rung01.py` 77/77;
`walk_rung02.py --a15` 44/44; `KEEP_GOING=1 make test-godot` `0 failed`; A26's `kernel` evidence
(now trustworthy per WP0) and `godot` evidence both read clean.

## Design-rule check (Andy's goal — do not re-litigate per WP)

Every fix above stays inside the layer the original plan already named for it: `SketchOffset`
and `SketchConvertEdge` are the one place a model-edge click resolves to a sketch entity (WP1);
`FilletPick.CORNERS`/`.decide` is the one table for edge-pick policy (WP2, assuming the app side
turns out to be the bug at all); `SectionPlane.CAP_COLOUR` stays the one named colour, only its
*lighting treatment* in the shader changes (WP5); `ShellChrome.SPEC` stays the one source of the
Shell default (WP6). No WP adds a second code path alongside an existing table or a new
`if`-branch where a table already dispatches; where a WP's root cause is still open (WP2's
app-vs-walk-timing question, WP7's unidentified overlapping control), the WP's own "red first" step
is designed to answer that question *before* any code changes, not to guess and patch.
