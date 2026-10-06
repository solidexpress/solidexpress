# Leftovers after sx-032 (main 2606160c / replan-11 WP1–WP11)

Source: `/workspace/sx-032/CRITIQUE.md` — **FAIL 8.5/10**. Walk log: `/workspace/sx-032/WALK_LOG.md` (chunks `gui/walk-chunk1..6.md`). T=14 replay: `/workspace/sx-032/diag/t14_diag.gd` + `diag/t14_diag.log`. Line numbers are from `2606160c`.

Headline: replan 11 fixed A6, the A8 angle, the A9 cutter trap, the A13 slot, A14, A3 and A16 in the real GUI. thick 5/5, nut 7/7 first try, blank 5/5, headless 413/0. What is left:
- The **first-try neck fillet** still fails, through three fillet-selection bugs.
- The **top-face R1 fillet is silently lost at T=14**.
- **Dimension labels need two clicks**.
- **Sketch clicks next to the left rail are swallowed**.
- The **timeline panel can't be dismissed** with Esc or a click away.
- **Save As ejects the open sketch**.
- The wrench is 26/28: one walker slip (slot 150.35) and one checklist gap (slot-floor R1).

## Product (P0)

1. **Dimension label needs a second click (A8, rule 20).**
   - Repro: face sketch, Jaw (3 clicks), Select tool. Single-click the first glyphs of the width label (`15` of `15.2587`).
   - Got: `Sketch selection cleared`, no editor. A click near the label's middle opens `Dim: 15.259` with the text selected. Same on the angle label: a click on `912°` of `133.7912°` misses, a click at the centre opens `Dim: 133.791`.
   - Cause:
     - `sketch_mode.gd` `dimension_hit` (:5213-5241) accepts a click only within **22 px** of the projected label *centre* (`label_pos`), with a 6 mm sketch-space fallback.
     - The labels are `Label3D` with `fixed_size = true`, `pixel_size = 0.004`, `font_size = 28` (`_rebuild_dimension_labels` :5035-5068). On screen that is about 0.004·28·800/(2·tan(fov/2)) ≈ 55–60 px tall at 1280×800, and 200–300 px wide for `133.7912°`. Only the middle two glyphs are inside the hit circle.
     - The overlap nudge (`pos += Vector2(0, 2.5)` while within 2 mm, :5049-5052) works in sketch millimetres, so at normal zoom the labels still overlap on screen (gui/A8-jaw-zoom.png).
   - Need:
     - Hit-test the label's **screen rectangle**: the text width from `label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x`, scaled by the same fixed-size factor, plus ~6 px padding. Store the rect, or the Label3D ref, alongside `label_pos`.
     - Shrink the labels (font 16–18) and nudge them in screen space so they never overlap.
     - Test: a single click at the left-most and right-most glyph of both jaw labels opens the editor (new suite or extend `run_rung01_replan11_dimhit.gd`).
   - Related, minor: no status after the jaw commit, the Select tool press, or a Centerline commit; after Trim the labels bunch inside the head circle.

2. **Sketch clicks next to the left rail are silently dropped (A9 pivot hole).**
   - Repro: jaw face sketch at the zoom where the origin sits at screen ≈ (186, 411), about 40 px right of the rail's visible right edge (x≈145). Circle tool, click on the origin.
   - Got: nothing. No status, no centre point. Two clicks, then one more after a zoom-out. The same click mid-screen (chunk 4) works.
   - Likely cause (verify first):
     - In a sketch, `viewport_interaction._input` (:4417-4425) forwards a mouse event only if `_viewport_owns_pointer(pos)` (:2152-2189) is true. That returns **false** when `gui_get_hovered_control()` is a sibling Control whose global rect contains the point.
     - `main.gd` `left_stack` (VBoxContainer at (8,48), :476-481) holds `card_box` with `custom_minimum_size.x = _CARD_W = 280` (:118, :606) plus `ops_panel` and `sketch_toolbar`. Once the Selection card has been shown (it was, in A6), the stack's rect can stay ≈280 px wide while only the 145 px sketch rail is visible. Every sketch click at x < ~288 inside the stack's height is then swallowed.
     - The grey translucent patch over the origin is the WorldGizmos grid (`world_gizmos.gd` `GRID_HALF := 50`, a 100 mm square). It is visual only, but it draws on top of the solid in face sketches (separate P2).
   - Need:
     - Print `get_viewport().gui_get_hovered_control()` and `main.left_stack.get_global_rect()` at 1280×800 in a face sketch after a face selection.
     - Make the stack (and every hidden or transparent left dock) not cover the canvas: `left_stack.size = left_stack.get_combined_minimum_size()` on every visibility change, and/or `mouse_filter = IGNORE` on the container.
     - When a sketch click is swallowed by chrome, the click must land on a visible control. Never silence.
     - Test: in a face sketch at 1280×800 after a face selection, a Circle click at rail-right-edge + 30 px adds a circle.

3. **The fillet edge pick ignores the camera, so there is no end-on preference (A11b).**
   - Repro: wrench-slot.sxp, Fillet armed, Top view (key 3), click the +Y neck corner.
   - Got: `Fillet: 1 edge(s) — 32.3 mm arc — …` (the head arc), not the 10 mm vertical.
   - Cause: replan-11 decision 2 said `_accumulate_dressup_edge` passes the viewport camera to `edge_near_point`. It does not: `ops_panel.gd:2007` `view.edge_near_point(body, point, 2.5)` and `:2012` `view.edge_near_point(body, point, 12.0)` have no camera argument. `document_view.gd` `edge_near_point` (:1257) therefore takes the 3D-only branch. WP1's screen-space/end-on code (:1270-1290) only runs from `_edge_near_point` (select path).
   - Need: pass `view.get_viewport().get_camera_3d()` (or the interaction camera) in both calls. Test: Top-view click at the projected neck vertex arms `10.0 mm vertical`.

4. **A face-interior click while edges are armed replaces the whole set (A11b).**
   - Repro: arm Fillet, pick the −Y neck vertical (Iso) → `Fillet: 1 edge(s) — 10.0 mm vertical`. Back view (key 4), one click on the +Y side wall near the neck.
   - Got: `Fillet: 4 edge(s) — 10.0 mm vertical, 10.0 mm vertical, 179.8 mm line, 179.8 mm line — …`. That is the side wall's 4 edges: the +Y neck vertical, the 10 mm tangent seam at the Ø20 boss, and the top and bottom long lines. **The −Y edge picked earlier is gone.**
   - Cause: `_accumulate_dressup_edge` (:2007-2010) treats any hit farther than 2.5 mm (3D) from an edge as a face click and calls `_add_dressup_face`, which does `view.selected_edges = arr` (:2076-2091). That is a replace, not a union. 2.5 mm in 3D is a few pixels on a 10 mm wall.
   - Need (decide one):
     - A face click only expands to the face when nothing is armed yet. Otherwise snap to the nearest edge within ~12 px screen distance, or refuse with `No edge near click — click on an edge (a face click fillets the whole face only as the first pick)`.
     - In every case merge (union) instead of replacing.
     - Test: neck −Y armed, then a Back-view wall click keeps the −Y edge.

5. **A press off the solid while Fillet is armed wipes the armed edges and hides the panel (A11b).**
   - Repro: three edges armed (after #4). Click the second 179.8 mm line, seen edge-on from Back, so the press just misses the solid.
   - Got: the panel reverts to the main toolbar, the edge set is gone, and the status is not updated. Enter → `No edges selected — cancelled`.
   - Cause:
     - `viewport_interaction.gd` release path: `if _press_empty: if not _additive_click: view.clear_selection(); status.emit("")…return` (:3376-3384) runs **before** the armed-pick branch `if ops_panel != null and ops_panel.consumes_viewport_pick()` (:3388). The armed branch already has `status.emit("Missed the solid — click a face or edge")` for misses.
     - `clear_selection` → `ops_panel._on_selection_changed("", "")` (:509) → `visible = false`, while `_pending` stays `FILLET_EDGES`.
   - Need:
     - Move the armed-pick check above `_press_empty`. On an empty press while armed, first try a screen-space silhouette edge pick (within ~10 px). Otherwise keep the set and emit `Missed the solid — click a face or edge`.
     - Test: arm two edges, push a click on empty background, then Enter applies the two.

6. **Fillet statuses.**
   - (a) `— removed` lacks the length (A11c). `ops_panel.gd:2027` appends a bare `— removed`. Compute `_edge_length_kind(body, edge)` before erasing and emit `… — removed 179.8 mm line`.
   - (b) `Fillet 2 edges 10.00 applied` is never seen. `_apply_dressup` emits it (:887), then `_open_last_feature` (:891 → :946) → `main.open_feature_params` (:1888-1901) overwrites it with `Feature created — View ▸ Timeline to edit parameters`. Keep the applied text, e.g. `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters`.

7. **The timeline edit panel ignores Esc and an empty-viewport click (A13).**
   - Repro: View → Timeline, click the extrude 3 dimension icon, type 14, Enter (`Preview: distance = 14.0`). Then Esc ×2, or click empty viewport ×2.
   - Got: the panel stays open, the change is neither cancelled nor committed, and no status. Only the panel's Cancel (`Edits cancelled`) or View → Timeline toggle closes it.
   - Cause:
     - Esc outside a sketch is consumed in `viewport_interaction._input` → `cancel_stack()` (:4470, fn :1574). That releases focus and clears the selection but never calls `main.cancel_property_panel()` (main.gd:1937). So `PropertyPanel._unhandled_input` (property_panel.gd:206) never runs. `_gui_key`'s KEY_ESCAPE arm (:3466-3478) does call it, but it is not reached.
     - An empty-viewport press returns from `_press_empty` (:3376-3384) before `_commit_property_panel_on_deselect()` (:3409, fn :3440).
   - Need:
     - In `cancel_stack`, first `if main.cancel_property_panel(): status.emit("Edits cancelled"); return true`.
     - In the `_press_empty` branch, call `_commit_property_panel_on_deselect()` (decision 18: hide without commit; the preview stays).
     - Test: both paths close the panel at 1280×800 with focus in the Distance field (the GUI state). Today's ux suite evidently runs with a different focus or press path.

8. **Face-derived fillets are silently lost on a thickness edit (A13, confirmed headless).**
   - Repro (headless): `LD_LIBRARY_PATH=<occt>/lib tools/godot/godot --headless --path game --script /workspace/sx-032/diag/t14_diag.gd -- out/wrench-fillets.sxp <outdir>`. Load, set `extrude 3` params `distance` 14 with `graph_set_params`, `export_3mf`. In the GUI: timeline Distance 10→14, export.
   - Got:
     - 17 × `[ERROR] fillet soft-skip: missing edge uuid …` per regen, while `graph_regenerate` → `{ "ok": true, "error": "" }`.
     - Body faces 44 → 29. diag-t14.3mf is identical to the GUI wrench-t14.3mf (1725 v / 2438 t).
     - Wrench checker on it: `1mm fillet top outer edge` FAIL, `1mm fillet on jaw top edge` FAIL. Neck R10 and bottom R1 survive.
     - The headless walk shows the same loss: logs/walk.log 549-569, 21 soft-skips after `- timeline: base extrude 10 → 14`.
     - **Clean repro on any VM:** run `run_rung01_wrench.gd` (413/0), then `python3 tools/check_rung01.py wrench /tmp/sx-rung01-wrench-t14.3mf`. Got: 1725 v / 2438 t (the walk's T=10 `/tmp/sx-rung01-wrench.3mf` has 5760 t and is 28/28). `1mm fillet top outer edge` FAIL and `1mm fillet on jaw top edge` FAIL. The `bbox Z` and `grip slot present at z=8.75` FAILs are expected at T=14 and are not part of this defect.
   - Cause:
     - The top-face R1 fillet (fillet 11) stores 15 edge ids plus `edge_cues`, which are absolute midpoints (12 at z=10.0, 3 at z=9.0).
     - When the base extrude changes, those ids are re-minted. `resolve_dressup_edge` (`ops_dress.cpp:296-305`) falls back to `match_edge_cue` (:154-184), which accepts only an edge whose midpoint is within **0.5 mm** of the cue and whose direction is within 0.95. The top edges are now 4 mm higher, so none match.
     - `apply_fillet_chamfer` then soft-skips each one (:325-336). With every edge gone, the fillet is a silent no-op.
     - `remember_dressup_edge_cues` (`features.cpp:2073-2107`) never re-anchors a cue it can't resolve.
     - The UI made this fillet from a face (`ops_panel.gd` `_dressup_from_face = true`, :2090), but the feature does not store the face.
   - Need (decide; give exact code):
     - (a) Store the face selection on face-derived fillets, using the same support-face scheme as replan-11 decision 11 (host feature id + normal + `max`/`min`), and re-expand to that face's edges on regenerate. And/or (b) make cue matching follow the support face: shift the cue along the face normal by the host face's offset change before matching.
     - Regardless: if **all** of a fillet's edges soft-skip, fail the feature with a named error (`fillet N: all K edges lost on rebuild`) and surface it in the status and timeline. Partial skips also get a status.
     - Tests: wrench-fillets-like doc at T=14 keeps the top R1. Add a walk check after the thick edit (`not _inside(thick_mesh, Vector3(-9.9, 0, 13.9))`, top outer fillet present) and decide whether `check_rung01.py thick` gains a `1mm top fillet at new T` row. That would be the one allowed checker change; it is exactly the row that hid this.

9. **Save As closes the active sketch (A9 pre-cut checkpoint).**
   - Repro: trimmed jaw sketch open, File → Save As pre-cut.sxp.
   - Got: `Saved …/pre-cut.sxp`, then part mode with `Face 6 of extrude 3` selected. Extrude says `Extrude: select a closed sketch pad (or enter Sketch and draw a profile)`. Recovery needed File → Open + a double-click on the sketch, which left a stray Line first point.
   - Cause: `main.gd` `_save_current` (:3141-3152) calls `sketch_mode.exit_sketch()` before `view.save` (replan-11 decision 16) and never re-enters.
   - Need: keep the returned fid (`var fid := sketch_mode.exit_sketch()`), save, then `sketch_mode.begin_edit(fid)` (sketch_mode.gd:410) and restore the tool to Select, so the user stays in the sketch with the profile selectable. Test: after Save As the session is active and the finish-bar Extrude works.

## Process (P0)

10. **Checklist and walk gaps that hid or caused failures.**
    - **Slot-floor R1 is not in the GUI checklist.** The headless walk does it (`run_rung01_wrench.gd:404-405`, `_fillet_face(... Vector3(93.5, 0, 7.5), 1.0, "slot floor")`), and the wrench checker requires it (`slot floor 1mm fillet (corner material)`, probe (xm, 4.9, 7.6)).
      - sx-031's GUI file passed that row **without** a slot-floor fillet (same fillet list as sx-032: top 15 edges at z 10/9, bottom 11 at z 0). It passed only because its head sat at y=0.218: the checker's bbox alignment shifted the slot 0.218 mm toward −Y, which put the probe in solid wall.
      - With A3 fixed (y 0.000), the probe now correctly lands in the void.
      - The sx-033 checklist needs an explicit A11e: slot floor R1 (Top view, Fillet, click the slot floor, Enter, read the status).
    - The walk never makes the human fillet clicks: a Top-view corner click, a face-interior click with edges armed, a press just off the silhouette, Esc and click-away on the timeline panel with focus in Distance, Save As inside a sketch.
    - Nothing checks fillets after T=14 (see #8).

## Product (P1/P2)

11. **The slot commit prints no length (A11a walker slip).**
    - wrench-slot.sxp sketch 8: centres x 24.6017 / 174.9483 and a driving centre-distance constraint **150.3465576** (float32 rubber-band length). A typed 150 is stored as 150.0 (sx-031's slot), so no typed 150 reached the tool.
    - **Verdict: walker input error, not a Slot tool or dimension defect.** The checker's 160.338 = 150.347 + 2 × 5 within mesh sampling.
    - The tool gave no feedback that would have caught it: `_add_slot` (sketch_mode.gd ~:3570-3600) emits no status. Add `Slot c-c %.4f R%.4f` (with `— typed` when `_point_from_length`), and the walker reads it back.
12. **Smaller UX (P2):**
    - Fillet is not on the left rail (the curve icon is Sweep); it only appears in the context strip (`viewport_interaction.gd` `_strip_fillet` :345) after a body click.
    - Face selection takes two clicks (body, then face: `document_view.gd` `select_ray` :1125-1135). A shaft click can grab a long edge plus a stray `Δz 2.50` measure.
    - The WorldGizmos 100 mm grid draws over the solid in face sketches.
    - The constraint chip row (2 entities selected) draws over the left rail and runs off the right edge.
    - Circle chips disappear during the preview.
    - The Circle status keeps the Rect hint until the first commit.
    - After Extrude the left panel covers the Sketch button.
    - File → New keeps the previous radius/distance chips.
    - Save As pre-fills the last export name (`blank.3mf`) with the `*.sxp` filter, and joins a typed absolute path that lost its `/` onto the cwd.
    - Red centre markers and DOF `!` after Shaft Lines.
    - A17 Contours row never appeared in the walk, so it is untested in the GUI.

## Environmental

13. Soft-GL dropped keystrokes three times (Save As `/`, radius `2.5`, fillet radius `2.0`). Read-back caught all three. Keep rules 1–22. Add: read back the Slot c-c and radius from the new status before cutting. No driver WP.

## Already green (do not re-break)

- Headless `run_rung01_wrench.gd` **413/0**. Lint `4 replan10` + `11 replan11 scripts are clean`. All replan11 suites green. `make test-kernel` 7900/330.
- GUI rows:
  - A1, A2 (no stale Jaw prompt), A3 head y 0.000, A4, A5 blank 5/5, A5b, A7, A7b.
  - A6 exactly two Esc presses.
  - A8 values take (20, 45°, `Dimension updated`).
  - A8b Esc ladder.
  - A9 Trim with the leftover along-jaw line (`Trimmed open jaw`, then `Jaw is already open — nothing left to trim here`).
  - A9b closed Up To Surface cut.
  - A16 View menu, Back/Left/Bottom keys 4/6/8, orbit off Top.
  - A11a slot cut, A11d face-first R1 top/bottom (`Feature created`, never `No edges selected`).
  - Fillet status lists edge lengths and kinds; re-click removes an edge.
  - A13 Distance pre-selected, slot open at T=14 (thick 5/5).
  - A10 exact 81 % sentence. A10b ×2. A14 nut 7/7 first try, `flats horizontal`.
- Main tip `2606160c` (replan-11 WP1–WP11, #113–#124).

