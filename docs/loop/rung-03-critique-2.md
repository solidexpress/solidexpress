# Rung 3 critique 2 — walk 2 on `f355557`

**Score: 4 / 10** against SOLIDWORKS *Learn SOLIDWORKS Lesson 1: Parts*
(spec: `docs/loop/rung-03-plan.md`). Not Done (bar is ≥ 9, and a part that
skips Offset Entities, the through cut, the two fillets, the shell, or the
capped section cannot clear 8).

Walk 2 (`docs/loop/rung-03-walk2/`, commit `f355557`): **24 PASS, 19 FAIL,
3 BLOCKED**. Walk 1 (`docs/loop/rung-03-walk1/`): the same counts. Replan 1
WP0–7 (`docs/loop/rung-03-replan-1.md`, commits `d055a09`..`f355557`) did not
move the score. It swapped rows: A3 and L2 became PASS; A16 and N10 became
FAIL. The exported solid after the boss is still the uncut boss.

## What the video gets, and what this build gets

| Video step | Walk 2 | Solid that was checked |
|---|---|---|
| Fully defined 120×120 centre rectangle, blind 30 | PASS (A1–A5). `check-base-base.txt` 3/3 | 432000 mm³, bbox 120×120×30 |
| Ø70 boss, fuse, blind 25 | PASS (A6–A10). `check-boss-boss.txt` 4/4 | 527853 mm³ (want 528211) |
| Offset Entities, 5 mm inward, Ø60 | FAIL (N4, A13). N5 Esc cancels the sketch | no profile circle, no external circle |
| Cut, Through All | BLOCKED (A14, L4, A15) behind A13 | no `cut` export |
| Fillet R5 on 4 verticals + front face (9 edges) | FAIL (A16–A19) | radius stays 2 mm; 2 verticals, then 7 edges; N8 applies that fillet |
| Fillet R1.5 on the boss annulus (2 edges) | FAIL (A20) | field reads `.5`; one 219.9 mm edge; `Fillet edge 0.50 applied` |
| Shell, back face, 1 mm | FAIL (N9, A22, N10) | `Shell failed (shell 8: shell failed)`; timeline has no Shell |
| Section Top, capped, K toggles | state PASS (A23, A24); pixels and K FAIL (L7, N11) | cap sample is the background `[75, 67, 75]`, not `CAP_COLOUR` |

`check-r5-r5.txt` and `check-rounded-rounded.txt` are 3/14 and 3/16. `hole Ø60`
is 5 samples off with 2 axis hits (the hole was never cut). Corner probes are
0 or ~0.83 (a 2 mm fillet or a sharp corner), not 2.071. Volume ~527600 vs
370785. Those checker lines are the missing cut and the wrong fillet, not a
wrong probe table. `base` and `boss` match the video.

## What replan 1 fixed, and what it missed

Fixed, and visible in walk 2: A3's second `120` label (`sketch_mode.gd`
dimension labels), L2's Top look (`orbit_camera.gd` reported in kernel space),
and A26's kernel evidence now names the failing Catch2 line instead of
`sxvoice_tests`'s "All tests passed".

Missed, so the score stayed 24/19/3:

| Rows | Real cause | File : symbol |
|---|---|---|
| N4 `too far`, A13, then N5 / A14 / L4 / A15 | The boss rim is classified as not on the sketch face, so Offset never builds the Ø60 circle. `edges_of_face` drops an edge whose face orientation is the opposite of the one `MapShapes` stored (`TopTools_ShapeMapHasher::IsEqual` is `IsSame`, orientation included). An empty set makes `SketchConvertEdge.click` take the "other edge within 12 mm" branch. | `sxkernel/src/query.cpp : edges_of_face`; `game/scripts/sketch_convert_edge.gd : _face_edge_set`, `click` (`NOT_ON_FACE`) |
| Same, once the rim is actually passed in | `add_external_edge` still returns null for a rim `circle_edge_at` already accepted. Catch2 `test_sketch_external_circle.cpp:127` (`REQUIRE_FALSE(added.is_null())`). The only gate the finder does not apply is `project_circle`'s axis test (and a second span test). | `sxkernel/src/sketch3d.cpp : add_external_edge`, `project_circle` |
| A17, N6, A18, N7, A19 edge count | `click(edge=<id>)` throws the id away and clicks the screen point of the midpoint. In an orthographic side view the near and far verticals (same Y, Z) are one pixel. The ray, or the already-picked twin, toggles a vertical that was selected in the other side view. Picks 1–2 (Right, key 2) stick; picks 3–4 (Left, key 6) go 2 → 1 → 2. Shift+face then reports 7, not 9. | `game/scripts/automation_bridge.gd : _resolve_point`; `game/scripts/document_view.gd : edge_near_point`; `game/scripts/ops_panel.gd : _prefer_selected_dressup_edge`, `_toggle_dressup_edge` |
| A16 radius `2.0`, A20 `.5`, N8 applies r=2 | Digits never become `dressup_radius` (default 2). `1.5` landing as `.5` is the leading `1` (Front view, key 1) going to the viewport because `finish:StripR` is not focused yet. Enter with no numeric focus calls `try_commit_pending` and applies the armed fillet. Walk 1 used Tab and A16/A20's radius clauses passed; WP2's Enter (`ui03.py : arm_fillet`) applies instead of committing. | `game/scripts/viewport_interaction.gd : _gui_key` (Enter + `numeric_field_focused`), `_commit_strip_radius`, strip `focus_entered`; `tools/walk/rung3/ui03.py : arm_fillet` |
| A22 shell failed, N10 `Selected all 18 faces`, N12 no Shell | Downstream of the uncut body and the r=2 / r=0.5 fillets. Walk 1 shelled that same uncut body when the fillets were R5. `ShellChrome.apply_mm` leaves the panel up on failure; `cancel` hides it without dropping focus. | `game/scripts/shell_chrome.gd : apply_mm`, `cancel` |
| N11 K stays off | `KEY_K` is dropped while any `LineEdit` is focused (`_gui_key` returns before `toggle_section`). The thickness field still focused after a hidden shell panel is enough. Mouse `hud:Section` works (A23, A24), which is why only K fails. | `game/scripts/viewport_interaction.gd : _gui_key`; `game/scripts/shell_chrome.gd : cancel` |
| L7 cap `[75, 67, 75]` | That RGB is the background (walk 1's removed half). There is no shell, so `(-59.5, 0, 12)` is not a 1 mm wall. Walk 1, which did shell, read a lit cap `[109, 112, 123]` against `SectionPlane.CAP_COLOUR` `(158, 168, 184)` — albedo through the lighting pass. WP5 moved the colour to `EMISSION` and this walk never got a wall to sample, so the emission change is unproven. | `game/scripts/document_view.gd : _make_section_shader` |
| L3 `covered=True` | WP7 stopped listing an untagged SpinBox line edit (`automation_bridge.gd : _walk_controls`) and the row is still covered. The three offset rects are inside the window and do not overlap each other. `WalkUI03.covered` treats any smaller control whose rect contains the centre as a cover, including the panel's own chrome. | `tools/walk/rung3/ui03.py : covered`; `game/scripts/automation_bridge.gd : _walk_controls` |
| N9 field `'5'` | `ShellChrome.SPEC["default_mm"]` is 5 and `_last_mm` is only updated after a successful shell. N9 runs before any success, so the refusal restores 5. Rung 2 N7 requires that same `'5'`. See test bugs. | `game/scripts/shell_chrome.gd : apply_mm`, `_last_mm` |
| A26 kernel | Real red: `test_sketch_external_circle.cpp:127`. The trailing `Sketcher Redundant solving: 0 redundants` is PlaneGCS stderr from the empty-sketch `solve` on line 125 (`thirdparty/planegcs/GCS.cpp`), not the assertion. | `sxkernel/tests/test_sketch_external_circle.cpp`; `sxkernel/src/sketch3d.cpp : project_circle` |
| A26 godot `29 failed` | Was 10 in walk 1. The extra reds are the replan's own suites plus whatever the radius / shell / convert regressions broke. Not a separate product area. | `game/tests/run_rung03_*.gd` |

N5's "Sketch cancelled" is `sketch_mode.gd : esc_keep_sketch`: Esc drops the whole sketch when it has no entities. Offset created none, so this is the convert failure, not a second Esc policy.

## Test or checker bugs (the app is doing what it was built to do)

- **N9 `field 1` vs rung 2 N7 `field 5`.** Both walks drive the same `ShellChrome` before any successful shell. The shared default is 5 (`shell_chrome.gd : SPEC`). Rung 3's clause asks for 1 because the video's wall is 1 mm, but nothing has written 1 into the field yet. Restoring 1 here would fail rung 2. The app side that *is* real: a refusal must restore the last **legal** thickness, not the refused text. The walk must seed `1` before it types `30`, or the clause must accept the shared default until a 1 mm shell has been applied.
- **L7 `removed is background`.** `rows03_chunk5.py : row_L7` passes only when `sum(removed) < sum(cap)`. Walk 1's background `[75, 67, 75]` fails this as soon as the cap sample is that same background. The cap-colour miss is real; the "removed" fail is the comparison, and in walk 2 it is also downstream of the missing shell.
- **A14, L4, A15 BLOCKED** are the walk's blocker chain behind A13, not extra product bugs.
- **A26's "0 redundants" line** is log noise glued on by `ui03.py : _kernel_failure_tail`. The FAIL bit is a real kernel assertion. Not a false red.
- **Checker rows on `r5` / `rounded` / `final`** measure the solid they were given. They fail because that solid is the boss with a 2 mm fillet, which is what the walk built.

## Not the causes replan 1 named

- Offset does not "swallow Convert" anymore. Walk 2's status is `Convert: edge is not on this face` (`sketch_offset.gd : click` surfaces `_convert_note`). The rim still is not in the face edge set, and the kernel still refuses to project it.
- Fillet corner loss is not a 2-frame camera tween. Number-row views snap (`orbit_camera.gd : apply_standard_view_id`, `animated` defaults false) and WP2 already waits 8 frames. The two side views are orthographic (`standard_view_table`: key 2 yaw 90, key 6 yaw −90), so a screen click cannot tell `(60, y, 15)` from `(-60, y, 15)`.
- Section HUD state is fine (A23, A24). K and the cap pixel are the leftovers, and the cap pixel was not measured on a shelled body.
