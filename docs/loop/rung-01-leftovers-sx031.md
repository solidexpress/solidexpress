# Leftovers after sx-031 (b3161bba / replan-10 WP1–WP5)

Source: `/workspace/sx-031/CRITIQUE.md` — **FAIL 8.5/10**. Walk log: `/workspace/sx-031/WALK_LOG.md`. Fillet diagnosis: `/workspace/sx-031/DIAG-fillets.md` (+ `diag/`).

Headline: for the first time **every checker passes on GUI-made files** (blank 5/5, wrench 28/28, thick 4/4, nut 7/7). But they only pass after careful, non-obvious picks and one manual workaround. The walk still has failures a normal user hits (A6, A8 angle, A9 cutter trap, A11b first-try fillets, A13 buried slot).

## Product (P0)

1. **Fillet edge picking from views a user can reach.**
   - From Top view (or any click that lands on the top face), the end-on vertical neck edge can't be picked. `document_view.gd:1255 edge_near_point` uses 3D distance to the hit point, so a long top edge always wins (DIAG §3D, pick_sim).
   - There are no Back/Left/Bottom views. The View ↓ dropdown (`view_hud.gd`) never opened. A vertical orbit from Top does nothing.
   - Need: an end-on/vertical preference (screen-space pick, or a tie-break toward the edge most parallel to the view ray), and/or working view buttons including Back/Left/Bottom.
2. **Wrong edges can't be removed.**
   - Re-clicking a selected edge does nothing (`ops_panel.gd:1967-1968`); it must toggle it off.
   - A refused commit keeps the same set armed (`ops_panel.gd:889-893`) with no hint which edge is bad.
3. **Misleading refusal text.**
   - `ops_panel.gd:886-888` prints `r=… too large for selected edge(s)` for ANY `graph_add_fillet` failure.
   - Build the text from `view.doc.last_graph_error()`: on `limit X`, name the limit and the edge that set it; on `fillet failed`, give the faulty contour or edge.
   - Kernel `sxkernel/src/features/ops_dress.cpp` :304/:311/:319 should name the edge (length, kind, midpoint). Use `BRepFilletAPI_MakeFillet::NbFaultyContours/FaultyContour` in `build_fillet`.
4. **Face selected first, then Fillet/Enter → `No edges selected — cancelled`.** `_commit_armed_dressup` (`ops_panel.gd:834-839`) ignores `view.selected_face`. Face-first then Fillet must expand to the face's edges, as Fillet-first then face click does (`_add_dressup_face`).
5. **Trim cutter choice with several construction lines.**
   - `_trim_open_jaw` uses `_nearest_construction_line(pos2, 40.0)` (`sketch_mode.gd:2390`, fn :2152). A leftover along-jaw construction line is nearer to the handout click, so the result is `Trim failed — centreline does not cross two jaw sides` (:2460).
   - Prefer the construction line that crosses both long jaw sides and is not parallel to them. Fall back to the nearest one only when none qualifies.
   - Line + Construction toggle (`toggle_construction_selected`, Construction chip, X key) must follow the same "replace previous cutter" rule as the Centerline tool (`_delete_other_non_datum_construction_lines`, :2920 / :3071), and say so in the status.
   - The refusal must name the line it used and the fix.
6. **A6 Esc after a Circle first point.** The ladder in `viewport_interaction.gd:2647-2668` checks `measure_overlay.has_anchor()` before `sketch_mode.has_pending_draw_point()`. The Circle centre click sets both, so the first Esc says `Measure cleared` and exiting takes 3 presses. A pending draw point must drop first, clearing the measure anchor at the same time, with status `First point dropped — Esc again exits the sketch`.
7. **Dimension labels: single click must open the editor, including angle labels.**
   - Width 20 only opened on a double-click with Select. A single click did nothing.
   - The angle label `45.286°` never opened (2 double-click tries), so the handout 45° can't be set.
   - Editor: `viewport_interaction.gd:501` (`Dim:` popup) plus the label hit-test.
8. **Grip slot and dependent sketch-on-face features don't follow the face on a thickness edit.**
   - A sketch on a face stores an absolute plane origin (`sketch_mode.gd:~262-285`, `Sketch on face (plane +Z @ origin …)`). After timeline Distance 10→14 the slot cut stays at z 7.5–10, a closed buried void. The wrench checker on `wrench2-t14.3mf` gives `grip slot floor z` 14.0.
   - Persist the support face reference and re-derive the plane on regenerate.
   - **NEW checker row in `tools/check_rung01.py` thick mode:** the grip slot is open from the top at the new T (open at z = T−1.25, floor at T−2.5 ±0.2, and the probe at z = T−0.5 above the slot centre is outside). thick becomes 5/5.

## Product (P1)

9. **The Centerline chip overlaps the `Contours 1 2` row.** The first press was dead and a retry toggled Contour 1 off (gui/2b-A9-centerline-chip-overlap.webp). Rows: Line/Centerline chips from `sketch_context_chrome.gd:~1250`, Contours row `:1149-1170`. Lay them out without overlap.
10. **Polygon orientation follows the pointer** (`sketch_mode.gd:3104 start_angle := (vertex - c).angle()`). The first nut came out rotated (6/7). Across-flats mode should default to flats horizontal (snap `start_angle` to the nearest multiple of 30°, or fix it at 0 when the AF is typed), and the status should say so.
11. **Fillet status should list the picked edges** (`ops_panel.gd:1981`), e.g. `Fillet: 2 edge(s) — 10.0 mm vertical, 179.8 mm line`.
12. **Fillet order dependency.** Face-wide R1 can't build while the neck corners are sharp (OCCT faulty contour: the head arc from the +Y jaw mouth to the neck; DIAG §3B; not fixable by 2-pass or sequential). At minimum the refusal says `fillet the R10 neck first`. Optionally try the neck-first order automatically.

## Product (P2 / UX)

13. The fillet strip `R` field shows a stale `0.0`. The text does not refresh after `set_value_no_signal` (`viewport_interaction.gd:4676`); also set the LineEdit text.
14. Clicking the body auto-arms Fillet (unexpected; the first clicks pick stray edges or faces).
15. A vertical orbit drag from Top view does nothing.
16. The timeline extrude panel: Esc doesn't close it, a background click doesn't either, and the Distance text isn't pre-selected.
17. A false `Sketch on ground (XY)` status after Sketch → Esc, with no sketch chrome (`main.gd:1359/1377`).
18. Opening a .sxp while a sketch is active leaves sketch mode and overlay on.
19. Save/Save As drops the active sketch (pre-cut.sxp had no jaw sketch).
20. Deleting a sketch line reports `Sketch selection cleared` instead of `Deleted 1`.
21. The jaw floor sits 89.71° to the walls despite a `perpendicular` constraint (`99475fbe`).
22. The Smart Dim centre distance 200 leaves the head at y = 0.218 (distance, not horizontal). Optional: infer horizontal when the second centre is within a few degrees of the X axis.
23. Rect press leaves the Jaw prompt on the status line.

## Process (P0)

24. **The walk/e2e scripts must pick from views a user can reach.**
    - `run_rung01_wrench.gd` fillets the neck through the test-only `_look_along(±Y)` camera (`:638-712`, fn `:1848`). Replace it with the UI view buttons or keys (Front `1`, Right `2`, Top `3`, Iso `7`, plus any new Back/Left/Bottom), then click.
    - Add walk steps that hit the human traps: a leftover Line+Construction along-jaw line before Trim; a face-first fillet; a deselect re-click; Esc after a Circle first point; a single-click angle label edit to 45; the thickness edit with the slot check.

## Environmental

25. Soft-GL was quiet this round (fields took on the first try). Keep the walker protocol. No driver WP.

## Already green (do not re-break)

- Headless `run_rung01_wrench.gd` **404/0**; lint `4 replan10 scripts are clean`; replan10 cut 114/0, esc 25/0, new 19/0, trim 38/0.
- GUI: A1–A5b, A7, A8b Esc ladder, A9 Trim statuses (`Trimmed open jaw`, `Jaw is already open …`), A9b closed Up To Surface cut, A10 exact 81 %, A10b finish-bar reset, A11a slot.
- Checkers on GUI files: blank 5/5, wrench 28/28 (careful picks), thick 4/4, nut 7/7 (aligned pointer).
- Main tip `b3161bba` (replan-10 WP1–WP5 #108–#112).
