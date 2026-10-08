# sx-038 GUI checklist (rung 1 replan 17)

Status: planned. Plan: [`rung-01-replan-17.md`](rung-01-replan-17.md). Baseline: [`rung-01-replan-16-checklist.md`](rung-01-replan-16-checklist.md) (sx-037, rows A / L / N, rules 1–50), which sx-037 scored 7.5/10 (43 PASS / 17 PARTIAL / 4 FAIL / 0 BLOCKED of 64). This file is the **complete handout**: every sx-037 row (64), restated where #196–#207 changed behaviour, plus five new rows **N22–N26** = **69 rows**, in walk order, in **6 chunks**. Each chunk starts in the app state the previous chunk ended in. Do not skip rows; do not reorder.

**Walk this file only when WP1–WP6 of re-PLAN 17 are merged.** Download the Linux build from the rolling `linux-test-build` prerelease ([`linux-test-build.md`](linux-test-build.md)); `BUILDINFO.txt` `commit=` must be the full sha of `main` after WP6. Do not test an older sha and do not use a box-local export.

Setup: **1280×800 screen**, `DISPLAY` set, Forward+ soft GL is fine. `OUT=/workspace/sx-038/out` (every export / save goes there; read every resolved path back, rule 24). Launch with `SX_INPUT_TRACE=1 <app> 2>&1 | tee $OUT/input-trace.log` (rule 51). Checkers (never `--allow-mirror`, never edit probes):

```bash
python3 tools/check_rung01.py blank  $OUT/blank.3mf          # 5/5
python3 tools/check_rung01.py wrench $OUT/wrench.3mf         # 28/28, flipX=False flipY=False (22 total = slot missing = FAIL)
python3 tools/check_rung01.py thick  $OUT/wrench-t14.3mf 14  # 7/7
python3 tools/check_rung01.py wrench $OUT/wrench-t14.3mf     # DIAG: exactly four by-design fails
python3 tools/check_rung01.py nut    $OUT/nut.3mf            # 7/7
```

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 7/7, headless walk 0 failures (`run_rung01_wrench.gd`, `run_rung01_replan16_walk.gd`, `run_rung01_replan17_walk.gd`), every A / L / N row PASS or classified soft-GL **with evidence** (screenshot + status text + one retry), fillets succeed on the first try from the views the app offers, a real Slot (`Extrude Blind 2.5000 mm`). Any BLOCKED row caps the score below 9.

## Chunks

| Chunk | Rows | Starts in | Ends in |
|---|---|---|---|
| 1 | N22 A1 A2 N7 L1 A3 L5 A4 L6 L10 A5 N12 A5b L8 L11 N17 (16) | Fresh app (window read first), File → New, ground sketch | Part mode, blank (Ø45 head + Ø20 pivot, 10 thick) exported and saved as `blank.sxp`, nothing selected, no menu open |
| 2 | A7 L2 A6 N4 A7b A8 N5 N25 A8b N8a (10) | End of 1 | Jaw sketch open for editing (pencil), Timeline visible, jaw `20` / `45°` committed, no pivot or head circle yet |
| 3 | A9 L4 N1a N21 N26 L12 N24 A17 A9c N1b N20 A9b (12) | End of 2 (sketch open) | Part mode, body cut by the open jaw (`Extrude Up To Surface 10.0000 mm`), `pre-cut.sxp` saved |
| 4 | A16 N6 A11a N10 N18 (5) | End of 3 | Part mode, shaft Slot cut (`Extrude Blind 2.5000 mm`), saved as `wrench-wip.sxp`, Top view |
| 5 | A11b N2 L3 A11c N3 A11d A11e N15 N13 N16 N19 N23 (12) | End of 4 | Part mode, neck R10 + top / bottom / slot-floor R1 applied, Fillet disarmed, nothing selected, Timeline on, document dirty |
| 6 | A12 N11 A13 A13b A13c N9 L7 N8b N14 A10 A10b A14 L9 A15 (14) | End of 5 | nut exported, lints, headless walks and full tier run |

If a chunk fails a row that the next chunk depends on, say which, and re-enter from the last saved `.sxp` (rule 11): after chunk 1 `blank.sxp`, after 3 `pre-cut.sxp`, after 4 `wrench-wip.sxp`. **Recovery that deletes geometry:** use the sketch drag-box (N24: Select tool, drag from empty canvas, then Delete). Ctrl+A also works.

## Re-verify rows (failed or partial in sx-037) — read these first

| Row | sx-037 | Fixed by | Pass now (chunk) |
|---|---|---|---|
| A2 | FAIL chip order | #196 | `Corner` first and highlighted, then `Center`, `Three Point`, `Center Three Point`, `Parallelogram` (1) |
| N7 | FAIL no accent bar | #198 | 3 px accent bar on the armed rail button (1) |
| L12 | FAIL no Δ, thin line, Esc | #206 | Select hover ✕ **with** Δ; thin line selects on the first click; one Esc after a selection is `Selection cleared — Esc again exits the sketch` (3) |
| N2 | FAIL Enter applied | #205 | Enter in strip `R` / panel Radius commits the number only; Fillet stays armed; keys return to the viewport (5) |
| A5 / A9b | PARTIAL huge zoom, red ✕, yellow lines | #197 | After Extrude the whole new body is framed, no red ✕, no consumed sketch lines over the body (1, 3) |
| A7 / A7b / A11a | PARTIAL off-centre face sketch | #199 | Face sketch opens framed on the whole blank; head and pivot inside the canvas (2, 4) |
| A6 / N4 / N14 | PARTIAL face stays selected | #201 | After a sketch exit nothing of the host face stays selected; a pending Up To Surface pick is gone; after a refused Extrude the next Esc is the ladder, the one after `Sketch saved` (2, 6) |
| L10 / L3 / L7 | PARTIAL keys swallowed | #200 | Digits and `.` land in the field; Enter releases the keys; Ctrl+A selects the field text (1, 5, 6) |
| A9 / A11a / A10 / A14 | PARTIAL leaking values, trim trail | #203 | Line Length is not `22.5`, Slot `c-c` is not `5.0`, Extrude Distance after New is not `5`, no red trim trail after release (2–6) |
| A17 | PARTIAL chip click leaks | #202 | A chip / finish-bar / HUD click never adds a canvas point; undo clears suggestion chips (3) |
| A16 | PARTIAL View menu, key 3 / 6 | #204 | Menu-bar View → Orientation lists the seven views; exact orthographic views (4) |
| A13 | PARTIAL preview dropped pivot | #207 | `Preview: distance = 14.0` keeps pivot hole and jaw (6) |
| A11c / A11d / A11e | PARTIAL wording | #205 | `Fillet <n> edges <r> applied — View ▸ Timeline to edit parameters`, no editor opens (5) |
| A8 | PARTIAL previews are lines | WP2 | Jaw preview is the rotated rectangle at every stage; polygon preview vertex sits under the pointer (2, 6) |
| A8b | PARTIAL `sketch 3` | checklist | The jaw sketch is `sketch 3` (sketch 1, extrude 2, then the jaw); `sketch 2` in sx-036 was a checklist error (2) |
| N25 | new | WP2 | DOF chip is `—` on an empty sketch after `Undo: Jaw` (2) |
| N10 / N21 / N26 | PARTIAL | WP1 | Hovered contour fill clearly stronger; glyphs on their vertices; `5` clear of every `H` (3, 4) |
| N16 | PARTIAL needs a 1 px nudge | WP4 | Hint shows 3 s after the key with the pointer **still** (5) |
| N23 | new | WP4 | Timeline never covers a part chip (5) |
| N22 | new | WP4 | Window fills the 1280×800 screen (1) |
| N24 | new | WP3 | Sketch drag-box select works (3) |
| A15 | PARTIAL full tier not re-run | WP5 | `make test-godot` is green and `make test-godot-known-red` lists every known-red suite with its reason (6) |

Dead first clicks (rail Sketch, Jaw click 1, Circle centre, Select on a thin line): WP3 instrumented the press path; rule 51 says how to record one.

## Changed text vs sx-037 (use these strings)

| Where | Now |
|---|---|
| Rect chips | `Corner`, `Center`, `Three Point`, `Center Three Point`, `Parallelogram` in that order |
| Esc in a sketch that holds geometry | Never discards. Selection → `Selection cleared — Esc again exits the sketch`; draw tool → `Tool dropped — Esc again exits the sketch`; pending first point → `First point dropped — Esc again exits the sketch`; last Esc → `Sketch saved` (empty sketch: `Sketch cancelled`) |
| Part mode keys | Ctrl+Z → status begins `Undo`; Ctrl+Shift+Z (or Ctrl+Y) → status begins `Redo` |
| Sketch undo / redo | `Undo: Jaw`, `Undo: Dimension`, `Redo: Jaw` …, `Nothing to undo`; the DOF chip follows (`—` when empty) |
| Select statuses | `Selected body <id8>`, `Selected face <id8>`, `Selected edge <id8>` (first click on an unselected body = body; a click on the already selected body = edge within tolerance, else face); sketch: `Selected 1 sketch entity`, `Selected <n> sketch entities`, `No sketch entities` |
| Fillet apply | `Fillet <n> edges <r> applied — View ▸ Timeline to edit parameters` (r with two decimals, `Fillet 2 edges 10.00 applied …`) |
| Views | keys `1` Front, `2` Right, `3` Top, `4` Back, `6` Left, `7` Iso, `8` Bottom; menu-bar View → Orientation lists the same seven; Top and Bottom are exact and look **through the open jaw**: a click in the jaw slot selects nothing (use the head or shaft) |
| Polygon | Pointer: the pointer sits **on a vertex**; AF = √3 × the pointer distance from the centre (status `Polygon AF <size> — flats horizontal — click to place (or type the size)`). Typed size: AF is the typed number (`Polygon AF 20.0000 — flats horizontal`) |
| Jaw preview | A rotated **rectangle** after click 1 (long axis centre → pointer, width 0.8 × length) and after click 2 (width follows the pointer; never narrower than 3.0 mm across) |
| A5 / A9b | After Extrude the camera frames the new body; no sketch lines remain drawn over it |
| A9b | `Extrude Up To Surface 10.0000 mm`; body 232.5 × 45.0 × 10.0 (±0.3) |
| A13 | `Preview: distance = 14.0`, no `lost on rebuild`, pivot hole and jaw still drawn in the preview |
| N13 | `No view for key 0 — use 1 2 3 4 6 7 8` |
| Export | `Exported 3MF → <path>` |
| Numbers | Strip `R` and panel Radius show the same text, `10 mm`, `1.5 mm`, `2 mm` |
| Shaft lines | `Shaft lines: 2 added`; they are tangent to the Ø20 pivot, i.e. offset 10 mm from the axis, and are not tangent to the Ø45 head (by design) |

## Soft-GL protocol (sx-038 walker)

Rules 1–16 (replan 10), 17–22 (11), 23–30 (12), 31–36 (13), 37–40 (14), 41–44 (15), 45–50 (16) stay. Highlights: read every typed field back before Enter (1); one retry of a dead click, never a third (2); the status line is the truth, screenshots lag one action (8, 36); real rail presses (33); first glyph of a label (27); never move the view to dodge the rail (28); Esc ends an armed pick (29); one Extrude click then read (41); typed export names read back (43). Restated 45–50 and the new 51:

45. **A plain click never prints `Editing sketch`.** `Editing sketch` appears only after the Timeline pencil, a double-click on a Timeline sketch, or rail Sketch → click a sketch / pad. Any other `Editing sketch` is a **product failure** (N15); stop that row, record the full status log, do not click again.
46. **Results hold 2.5 s, then the hint arrives by itself.** After a command result (`Opened …`, `Framed all`, `No view for key 0 …`) keep the pointer **still** on a face (nothing selected): the label reads the result until 2.5 s after the result, and the hover hint (`Face — click selects body first, click again for face · then Pull arrow`) replaces it by 3 s **without any pointer movement** (N16). A hint earlier than 2.5 s, or no hint at 4 s, is a failure. Moving the pointer off the body during the hold must leave the result on the label.
47. **Typed values replace.** First key into a numeric field replaces the whole value (strip `R`, panel Radius, Distance, circle / polygon / slot fields, dimension editor). A field reading `10` after typing `1` `.` `5`, or `1` after typing `10`, is a failure; one retry (rule 1), then record.
48. **Camera rows read the picture twice.** For N18 screenshot the part view immediately before entering the sketch and again after the Extrude result; compare the head and pivot pixel positions (±5 px).
49. **Soft-GL evidence** = screenshot + status text + one retry on a fresh frame. Allowed classes: lag (8), dropped key (1), one ~10 s File-menu stall under llvmpipe (leftover 22), large tilt per small orbit drag (`ORBIT_SPEED` 0.008 rad/px, leftover 23). Anything else is a product row.
50. **Number the contours by size** (rule 42) and read `Contour N of M — W × H mm at (x, y)` for N10.
51. **A dead first click is recorded, not guessed.** With `SX_INPUT_TRACE=1` every left press prints `[input-trace] press (x,y) <disposition>` to `$OUT/input-trace.log` (`sketch-click:<TOOL>`, `sketch-drag:<TOOL>`, `sketch-box:SELECT`, `drop:over-chrome:<name>`, `drop:not-owner:<name>`, `drop:shield`, `drop:dim-label:<i>`, `model-click`). When a click does nothing: copy the last log line into WALK_LOG (that is the evidence), retry once (rule 2), never a third. A dead click whose log line is `sketch-click:<TOOL>` with no entity added, or any `drop:*` on a canvas point, is a **product failure**; a click with no log line at all is a window-focus click (soft-GL).

---

## Chunk 1 — blank (16 rows)

Start: launch (rule 51 env), read the window (N22), File → New (`New — empty part, Top plane (XY). View ▸ Timeline to edit features`), rail **Sketch** on the ground plane. Keep the blank open through A13c (rule 10).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| N22 | WP4 | Before any click: `xdotool search --name SolidExpress` → `xdotool getwindowgeometry <id>`; `xprop -id <id> _NET_WM_STATE` | Window width ≥ 1272 and height ≥ 750 on the 1280×800 screen (usable rect minus decorations, ±8 px), or `_NET_WM_STATE_MAXIMIZED_HORZ` and `_VERT` present. Not ~1072×620. The menu bar, left rail and bottom status row are all inside the screen |
| A1 | #185 | Read the left rail in the new sketch (before drawing) | All **19** rail labels fully visible at 1280×800, last label inside the window, none clipped. The chip row starts right of the rail, covers neither Arc nor Point, ends inside the right edge (re-read in A3 with two circles selected) |
| A2 | #196 | Press **Jaw**, then **Rect** | Jaw: a status starting `Jaw`, no variant chips. Rect: `Rect — click 1 first corner, click 2 the opposite corner`; chips left to right `Corner` (highlighted), `Center`, `Three Point`, `Center Three Point`, `Parallelogram` |
| N7 | #198 | Rail **Jaw**; then rail **Rect**; then rail **Circle** and click one centre | The armed button is lit — accent fill and a 3 px accent bar on its left edge — clearly different from a merely hovered button; only that button is lit. Circle centre click: `Circle — centre set, click the rim or type a radius` |
| L1 | carry | After Jaw press Line, Smart Dim, Trim, Slot, Circle, Select in turn: rail buttons, then keys `L` `D` `T` `C` `S` | Each press prints a sentence that starts with that tool's own name, never the previous tool's. Slot's button is lit. The Radius field is **not** prefilled with another tool's number. Each rail press and each first canvas click lands on the first attempt (rule 51 for any miss) |
| A3 | #182 | Delete the A2/N7 scratch (select, Delete, or Esc to empty). Circle tool: **first click** at the origin; type `10` Enter. Circle: click right of it; type `22.5` Enter. Smart Dim: click centre 1 (`Smart Dim: first pick set …`), plain click centre 2 (no Shift); type `200` Enter | Both first clicks land. Typed digits replace the field (reads `10`, `22.5`, `200`; rule 47). `Circle r=10.0000 (Ø20.0000)`, `Circle r=22.5000 (Ø45.0000)`, `Dimension updated`. Centres level (head centre y = pivot y ±0.05). No stray point markers inside either circle after the Smart Dim picks (T14). Chip row check from A1 with both circles selected |
| L5 | #182 | Press `F`; then HUD **Frame**; then `Shift+F` | `Sketch view fit` (or the HUD's equivalent); **both** circles fully inside the canvas, right of the rail and inside the window each time; the grid covers the whole canvas; no stale disc |
| A4 | carry | **Shaft Lines** | `Shaft lines: 2 added` (offset 10 mm from the axis: tangent to the Ø20 pivot, by design not to the head) |
| L6 | #183 | Read the canvas; zoom out three wheel notches | No red / orange ✕, no live Δ labels. Blue `H` / tangent badges are expected. A **red or orange** H badge or a conflict count is a failure. Squashed circles in a screenshot with equal projected x / y: soft-GL (rule 35) |
| L10 | #200 | Finish bar Distance: type `10` Enter, then `14` Enter, then `10` Enter; read the field right after each Enter and one frame later. Then click the field again, type `1` `.` `5`; Ctrl+A | The field never shows the previous value (rule 47); ends at `10`; `1.5` reads `1.5`; Ctrl+A selects the field text (it does not select sketch entities); a key pressed after Enter goes to the viewport. A one-frame flash seen only in a lagging screenshot is rule 8 |
| A5 | #197 | Set Distance `10`, Blind, New. Click **Extrude** once with the mouse | After two frames: `Extrude Blind 10.0000 mm`. The view frames the whole new body (Ø45 head and Ø20 pivot ends both visible), **no** red ✕, **no** yellow sketch lines over the body. Then File → Export 3MF, type `blank.3mf` in `$OUT` (read the field back); `Exported 3MF → $OUT/blank.3mf`; checker blank **5/5** |
| N12 | #181 | Re-verify the A5 Extrude (rule 41): read the result, then click the **same pixel** once more | One body; Timeline `sketch 1`, `extrude 2` (names are indices, rule 37). The second click changes nothing: feature count equal, no new status, no `jaw_af` / AF chip text anywhere |
| A5b | carry | File → New: the Discard dialog → **Cancel**. Then File → Save As | Cancel keeps the blank. Save As dialog opens pre-filled `untitled.sxp`, name selected |
| L8 | carry | In that dialog do **not** press Ctrl+A; type `blank.sxp`; read the field back; OK | Typing replaced the selected name; `Saved $OUT/blank.sxp` |
| L11 | carry | Open the HUD **View ▼** menu; close; open the menu-bar **View** menu | Both lists are opaque; no button shows through them |
| N17 | #204 | Click the body (selected; the status names the level, `Selected body …` on an unselected body, `Selected face …` when the body was already selected). Open the menu-bar View menu, press **Esc** once; repeat with the HUD View ▼; then press Esc once more with no menu | First Esc: the menu closes, the selection **stays**, the left panel mode is unchanged, no `Selection cleared`. Same for the HUD menu. The third Esc → `Selection cleared`. (A face vs body result is the two-stage pick, by design: the status word says which) |

End of chunk 1: part mode, nothing selected, `blank.sxp` saved, `blank.3mf` exported.

---

## Chunk 2 — face sketch, Esc ladder, jaw (10 rows)

Start: end of chunk 1.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A7 | #199 | Plain-click the top face once, then rail **Sketch**, then click the top face again | The plain click gives a status beginning `Selected ` and **never** `Editing sketch` (rule 45). Rail Sketch: `Select a face or existing sketch (Esc to cancel)`; then `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`; the view frames the **whole blank**: Ø45 head and Ø20 pivot both inside the canvas, right of the rail, without `F` |
| L2 | carry | In this new sketch set the finish bar to **Cut / Up To Surface / `7`**. Keep it | Used by A6 next |
| A6 | #201 | Circle tool, **one** click in the canvas (with Up To Surface still set), Esc, Esc. Exactly two presses | The click lands (`Circle — centre set, click the rim or type a radius`; no face pick, no `Selected`). Esc 1: `First point dropped — Esc again exits the sketch`. Esc 2: `Sketch cancelled` (empty sketch). No `Measure cleared` between. Afterwards **no face is selected** and no `Face: …` pick is pending |
| N4 | #201 | Rail **Sketch** on the top face (read the finish bar: **Blind / New / 20**). Polygon AF `20` at a point (type `20` Enter after the centre click). Circle tool: click the centre, click into the Radius field: (a) Ctrl+A; (b) Esc, Esc. Then part mode: Ctrl+Z | Finish bar reset. (a) the field text is selected; no `Selected … sketch entities`; selection unchanged. (b) Esc 1 `First point dropped — Esc again exits the sketch`; Esc 2 `Sketch saved`; the host face is **not** left selected. Ctrl+Z: status begins `Undo`; the throwaway sketch leaves the Timeline |
| A7b | #199 | Rail Sketch on the top face again | Face sketch opens framed on the whole blank (`Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`); finish bar Blind / New / 20 |
| A8 | WP2 | **Jaw**: click 1 (on the Ø45 head end of the blank), click 2, **click 2 again at the same pixel**, click 3. Then **one click on the first glyph** of the width label `20`, type `20` Enter; then of the angle label `45°`, type `45` Enter | After click 1 the preview is a rotated **rectangle** (4 edges), not one line; after click 2 a rotated rectangle; with the pointer on the axis a thin rectangle (3.0 mm across, never a doubled line). The repeated click 2 prints `Jaw — width is zero — click 3 again for half the width`, no `Jaw committed`, entity count unchanged. Click 3: `Jaw committed — width …, long side …° — click a label to edit it`, non-zero width. Each label opens on the **first** click with its text selected (rule 47); `Dimension updated`; walls at 45°, included angle 90° ±0.05°. Initial labels like `16.9044` / `-32.49°` before editing are fine |
| N5 | carry | Select tool. Ctrl+Z, Ctrl+Shift+Z, Ctrl+Z, Ctrl+Z … until empty, then Ctrl+Shift+Z until the jaw and both dimensions are back | `Undo: Jaw` removes the Jaw (earlier `Undo: Dimension` steps first); `Redo: Jaw` restores it; at the empty end `Nothing to undo`; after the redos `20` and `45°` are shown again with the jaw. Trust statuses and entity count (rule 40) |
| N25 | WP2 | Read the DOF chip (bottom-left status area) at three moments of N5: with the jaw drawn; right after `Undo: Jaw` with the sketch empty; right after `Redo: Jaw` | Empty sketch: `—` (never `3` or any stale number); after the redo the chip equals its text before the undo (a number or `OK`, same as a fresh jaw). No `!` conflict marker |
| A8b | checklist | Select tool, click a jaw line, **Esc**, **Esc**; then in part mode Ctrl+Z, then Ctrl+Shift+Z | Esc 1: `Selection cleared — Esc again exits the sketch` (no `Measure cleared` first). Esc 2: `Sketch saved` — the sketch and jaw are **kept**. Selecting the Select tool reads `Select — click geometry, or a dimension label to edit it`. Part Ctrl+Z: status begins `Undo`, the sketch leaves the Timeline. Ctrl+Shift+Z: status begins `Redo`, **`sketch 3`** is listed again with the jaw (Timeline: `sketch 1`, `extrude 2`, `sketch 3`; the N4 throwaway was removed by its Ctrl+Z, so it consumes no number) |
| N8a | #184 | Take the **N18 screenshot** of the part view (rule 48), then View ▸ **Timeline** on (check N19 / N23 later). Click the **pencil** next to the jaw sketch | `Editing sketch`; no rename field (F2 on the row still renames). Finish bar reads **Blind / New / 20**; the sketch view is centred on the part |

End of chunk 2: jaw sketch open in edit mode.

---

## Chunk 3 — pivot, trim, labels, cut (12 rows)

Start: jaw sketch open (end of chunk 2). The N18 screenshot from N8a is the reference for A9b (rule 48).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A9 | #203 | Press `F`. Circle tool: **first click** on the pivot centre at the origin, 30 px right of the visible rail, view unmoved; type `5` Enter. Circle tool again: redraw the Ø45 head on the head centre, type `22.5` Enter. Draw a **plain Line** (not Centerline) across the head: read the Line Length field before typing. **Power Trim** (`T`): drag from the **outer stub** across the Line | First click lands: `Circle r=5.0000 (Ø10.0000)` (rule 28). The Line Length field is **not** `22.5` (no leak from Circle). Trim: `Trimmed open jaw`; the Line is gone; no pan; **no red trail** left after the mouse is released. A second drag: `Jaw is already open — nothing left to trim here`. If the Line is not across the head the status is `Nothing trimmed — no crossing at that point` (never a bare `Trimmed`); redraw and retry |
| L4 | #186 | Read the jaw labels right after Trim | Exactly one `20` and one `45°`; no `20.0005` / `45.0007°`; no overlapping labels. (Wall 45° ±0.1° is confirmed by wrench 28/28 in chunk 6) |
| N1a | WP1 | Zoom with the wheel until the Ø45 head is **~150 px** across. List every dimension label (text and place) | Exactly `20`, `45°`, `5`, `22.5`. None overlap; none sits on or touches a constraint glyph (gap ≥ 4 px); none is under the menu / rail / chips; the first glyph of `20` and of `45°` is clickable (opens the editor; Esc closes it) |
| N21 | WP1 | Same zoom: read the constraint glyphs around the head and pivot | No pile-up: glyphs are spread (≥ ~60 % of each visible); a click on one glyph selects it (`Constraint selected: …`) |
| N26 | WP1 | Same zoom: for each tangent and coincident badge find the vertex or contact point it belongs to | Every badge is within 40 px of its vertex / contact point; a badge pushed 12 px or more has a thin leader line to its point; none sits off the part (nothing below the shaft's lower edge, none inside empty space between shaft and head); the `5` label has clear space (≥ 4 px) to every `H` badge |
| L12 | #206 | Arm Circle; move over the jaw and shaft lines. Then Select tool and hover with no click; leave the line; press `F`; hover again; Esc. Then click a shaft line (thin) once | Circle armed: **no** ✕, no Δ labels, ever. Select + hover: ✕ **with** Δu / Δv; the ✕ is gone when the pointer leaves the line, after `F`, `Shift+F` or HUD Frame, and after a click on empty canvas. Esc over a ✕ → `Measure cleared`, chips still showing. The shaft-line click selects it **on the first click** (retry rule 51 only for a recorded `drop:`); then the ✕ is gone and the next Esc is `Selection cleared — Esc again exits the sketch` (do not press a second one) |
| N24 | WP3 | Select tool. Draw a throwaway Circle r `3` in empty canvas (≥ 60 px from all geometry); Select tool. (a) Left-to-right drag from empty canvas that **encloses** the circle; (b) press-release on empty canvas; (c) right-to-left drag from empty canvas that crosses only the circle's rim; (d) a left-to-right drag that only **cuts through** the rim; (e) Shift + window drag around the circle after clicking one jaw wall; (f) click empty canvas; (g) window-drag the circle again, press Delete | (a) a **blue** box shows while dragging; status `Selected 1 sketch entity`. (b) selection cleared. (c) a **green** box; `Selected 1 sketch entity`. (d) `No sketch entities` (window needs the whole entity). (e) the circle **and** the wall are selected: `Selected 2 sketch entities`. (f) cleared. (g) `Deleted 1`; the jaw, pivot and head are unchanged (entity count back to the count before the throwaway) and `20` / `45°` labels remain. A drag that **starts on a line** still moves it (no box) — do not do this here |
| A17 | #202 | Read the Line / Centerline chips and the Contours row. Click the Centerline chip with the pointer over the canvas | Chips do not overlap; Contours row only with more than one closed region; the chip click places **no** point or line on the canvas; a Centerline commit reads `Centerline added — construction, not part of the profile` (draw one and delete it); after Ctrl+Z and Ctrl+Shift+Z no phantom line appears and no suggestion chip lingers after the undo |
| A9c | carry | Set the finish bar to **Cut**, **Up To Surface**, pick the opposite face (`Face: z 0.0 mm`), thin / flip off. Then File → Save As `pre-cut.sxp`; OK | `Saved $OUT/pre-cut.sxp`; the sketch, Select tool and profile are still there; the finish bar is exactly as set (Cut / Up To Surface / `Face: z 0.0 mm`) — it is **not** reset |
| N1b | #186 | List the labels again; hover a label while its editor is open | Identical to N1a (no second `45°`, no new `5` / `22.5`). Editor open: no Δ overlay, no ✕ left at an old endpoint |
| N20 | carry | Save As `pre-cut.sxp` again (overwrite); press Ctrl+Z | `Saved …` again; finish bar still Cut / Up To Surface / `Face: z 0.0 mm`; Extrude button enabled; Ctrl+Z status begins `Undo:` (sketch undo kept) — then Ctrl+Shift+Z |
| A9b | #197 | Click **Extrude** once; read the status after two frames | `Extrude Up To Surface 10.0000 mm`; no `breaks the chain`, no open-shell refusal. The view frames the new body; **no** yellow jaw / pivot / head lines remain over the solid. Select the body: size reads 232.5 × 45.0 × 10.0 (±0.3) (if no size readout exists, A12 28/28 is the evidence). A plain click inside the head → `Selected `, never `Editing sketch` (rule 45). **N18 (first read):** the part view equals the screenshot from N8a (head and pivot ±5 px) |

End of chunk 3: part mode, jaw cut, `pre-cut.sxp` saved (re-save with Ctrl+S now so it holds the cut: `Saved …`).

---

## Chunk 4 — views, slot (5 rows)

Start: end of chunk 3.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A16 | #204 | Menu-bar View → Orientation; HUD View list; keys `1` `2` `4` `6` `7` `8`; orbit off Top with the preset's orbit drag; then key `3` | Both lists show Front, Back, Left, Right, Top, Bottom, Isometric; each key shows its view (`Front view`, `Right view`, `Back view`, `Left view`, `Isometric view`, `Bottom view`); key `6` and the HUD Left give the same picture; the drag moves the camera (a large tilt per small drag is leftover 23, soft-GL); `3` → `Top view`, exact top (straight down, orthographic), the part centred, the **open jaw seen through**: a click in the jaw slot selects nothing |
| N6 | carry | Part mode: key `3`; wheel-in three notches with the pointer on the head; wheel-out three; `F`; `Shift+F`; HUD **Frame** | The point under the pointer stays under it (±2 px) through the wheel. `F` → `Framed selection` (body selected) or `Framed all`; the part lands right of the left panel inside the window; HUD Frame gives the same view. End in Top view |
| A11a | #199 #203 | Screenshot the Top view (N18). Rail Sketch on the top face (click the head meat, not the jaw slot). Slot: type radius `5` Enter, click centre 1 at `(18.5, 0)`, read the field label (`c-c`), type `150` Enter | The sketch opens framed on the whole body. Slot lit; status `Slot — …`; stadium preview; label `c-c` after the first centre, the field is **not** prefilled `5.0`; `Slot c-c 150.0000 R5.0000 — typed` (rule 23). Finish bar: Blind / New / 20; the Extrude Distance stays 20 until you set it |
| N10 | WP1 | Draw a throwaway Circle (r 5) in the head so the sketch has two closed regions: the **Contours** chips appear. Hover chip `2`; click chip `1` off, then on; then delete the throwaway (Select, click it, Delete) | Hover: that region gets a clearly **stronger** fill (about 3 × the included region's fill, visible without a zoom tool) with a `2` tag and a double outline; the included region keeps the light fill; a skipped one is outline only. Click: `Contour 1 of 2 — W × H mm at (x, y) — skipped` then `— included` (read the status, rule 50). After Delete: `Deleted 1`, chips gone |
| N18 | carry | Set **Cut**, **Blind**, Distance `2.5`. Click **Extrude** once. Save As `wrench-wip.sxp` | `Extrude Blind 2.5000 mm` (a real Slot). The part view is the **Top view screenshot** from A11a (head and pivot ±5 px; the camera does not jump). `Saved $OUT/wrench-wip.sxp` |

End of chunk 4: part mode, Top view, slot cut, `wrench-wip.sxp` saved.

---

## Chunk 5 — fillets (12 rows)

Start: end of chunk 4. Fillets are picked from keys `3` (Top), `4` (Back), `8` (Bottom), `1`, `7`, with the body selected. Zoom with the wheel or `F`. Click each fillet target **once**; a first click that misses is a failure (leftover 4). In Top view the jaw slot is see-through: click the neck corners and head, never the slot.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A11b | #168 | Select the body (click it). Press the **Fillet** chip (Fillet armed). Key `3`. Click each **neck corner** (the two vertical edges where shaft meets head). Key `4` and click the +Y wall; press on the empty background. Do **not** press Enter yet | Corner click: `Fillet: 1 edge(s) — 10.0 mm vertical …` (not the 32.3 mm arc, and no `0.0 mm line`); the wall click keeps the set (adds an edge only within 14 px, else `No edge near click …`); the background press: `Missed the solid — click a face or edge`, set and panel kept |
| N2 | #205 | Fillet still armed. (a) Strip `R`: ▲ then ▼ then key `3`. (b) Strip `R`: click into it, type `10`, Enter, then keys `3` and `4`. (c) Panel **Radius**: click into it, type `10`, Enter, then key `3` | (a) ▲ `2.5 mm`, ▼ `2 mm` (step 0.5), key `3` → `Top view`. (b)(c) the field reads `10 mm` (no extra digit, never `1` / `100`); **Enter does not apply the fillet** and no fillet editor opens; the field releases the keyboard (key `3` → `Top view`, key `4` → `Back view`); **Fillet is still armed** (strip `R` visible; `Fillet r=10.00 — edit Radius, click edges, Enter`). Rule 47 |
| L3 | #200 | Strip: type `10` Tab. Panel: type `1.5` Tab; then `10` Tab | Strip `R`, panel Radius and the status show the **same** number each time (same text, `10 mm` / `1.5 mm`; the `.` is not dropped); Tab leaves the field and the next key goes to the viewport (key `3` → `Top view`, not `AF 10`). Enter uses the number on screen. End at `10` |
| A11c | #205 | Click one wrong edge; read the status; click it again. Then press **Enter** in the viewport at R10 (the apply of A11b) | Count rises then drops: status ends `— removed 179.8 mm line` (a length and kind). Enter with the two verticals: `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters` (not `Feature created`, not `adjust parameters`; **no** editor opens; Esc afterwards does not undo it) |
| N3 | carry | Note the x of the `Fillet` and `Chamfer` chips with the body selected; then with a face selected; then with Fillet armed | Both x identical (±1 px) in all three states; the bar is fully below the menu row, never touches `Snap`, ends inside the window (wraps if needed); clicking the noted x arms **Fillet** every time |
| A11d | #205 | Fillet, radius `1`. Key `3`, click the **top face** once (inside it, away from edges, ≥ 8 px; not in the jaw slot); Enter. Then key `8`; select the body; **one click on the bottom face, then move the pointer twice**; Enter | Face click: `Fillet: <n> edge(s) — …` with n ≥ 6 and no `0.0 mm line`. Both Enters: `Fillet <n> edges 1.00 applied — View ▸ Timeline to edit parameters` first try; never `No edges selected`; the body does not move and no `Moved body` |
| A11e | #205 | Key `3`; Fillet, radius `1`; **one click on the slot floor** (inside the slot outline, away from the rim); Enter. Then R `1.5` on the same floor: Enter | Click: `Fillet: <n> edge(s) — …` listing the floor's ≈150 mm lines and ≈15.7 mm arcs (not the neck loop `175.4 line, 42.2 line`). Enter: `Fillet <n> edges 1.00 applied …`. R1.5: `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius`. Esc → `Edge pick cancelled`; Fillet no longer armed |
| N15 | carry | Fillet not armed (after the Esc). (a) Click **empty ground** inside the part's sketch footprint; (b) click the **slot floor**; (c) click the **Fillet chip**; (d) Esc | (a)(b) status begins `Selected ` (or the selection simply changes); **never** `Editing sketch`, never a sketch entering edit mode, never a loft status. (c) `Fillet r=…` (armed). (d) `Edge pick cancelled` |
| N13 | carry | Part mode, no field focused (click empty viewport first): press `0`, then `3` | `No view for key 0 — use 1 2 3 4 6 7 8`; the camera did not move; `3` → `Top view` |
| N16 | WP4 | Click empty background so **nothing is selected** (status `Selection cleared` or no selection chips). Press `0`; **at once move the pointer onto a face of the body, then do not touch the mouse** (no 1 px nudge); watch the label for 4 s | The label reads `No view for key 0 — use 1 2 3 4 6 7 8` until 2.5 s (rule 46); between 2.5 s and ~3.5 s it changes **by itself** to the hint `Face — click selects body first, click again for face · then Pull arrow`. Repeat once moving the pointer off the body to empty ground during the hold: the result stays on the label (no stale hint) |
| N19 | carry | View ▸ **Timeline** on (already on from N8a: leave it). Arm Fillet; look at the left Modify panel; click the Radius field and type `2`; Esc | The Timeline does **not** cover the Radius field or any Modify panel control (they do not intersect; both fully inside the window); the click focuses Radius (field reads `2`); Esc → `Edge pick cancelled` |
| N23 | WP4 | Timeline on. Click the body (it is selected: the part chip row shows `Group`, `Similar`, `Hole`, `Hole Wizard`, `Fillet`, `Chamfer` …). Read the left end of the chip row and the Timeline top. Esc (deselect); click the body again | The chip row's left end (`Group` …) is fully visible, not covered by the Timeline; the Timeline sits **below** the chip row (top ≥ chip row bottom + 4 px) while the body is selected, both inside the window; with nothing selected the Timeline returns to the top of the left column; selecting again moves it below again. The chip row does not move (x unchanged ±1 px, N3). End with nothing selected |

End of chunk 5: Fillet disarmed, nothing selected, Timeline on, document dirty (`wrench-wip.sxp` is older).

---

## Chunk 6 — export, thickness, dirty flag, nut, lint (14 rows)

Start: end of chunk 5.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A12 | #188 | File → Export 3MF, type `wrench.3mf` (read back), OK | `Exported 3MF → $OUT/wrench.3mf`; checker wrench **28/28**, `flipX=False flipY=False`; open-shell / mesh warnings: none |
| N11 | #188 | File → Export 3MF, select all in the name field, type `wrench-noext` (no extension), OK | File `$OUT/wrench-noext.3mf` exists and `$OUT/wrench-noext` does not; status `Exported 3MF → …/wrench-noext.3mf`; checker wrench 28/28 on it |
| A13 | #207 | Timeline: double-click the base extrude (first Extrude, Distance 10). Distance field (text selected): type `14`, Enter | `Preview: distance = 14.0` (and the part previews 14); the status never says `lost on rebuild`; the preview still shows the pivot hole, the open jaw and the fillets (not a plain slab) |
| A13b | carry | With the field focused press **Esc**; reopen; type `14` Enter; click empty viewport | Esc: closes the panel; distance returns to 10 (`Edits cancelled`). Empty click: closes the panel and **keeps 14**; never `Editing sketch` |
| A13c | #187 | Export `wrench-t14.3mf`; run `thick … 14`; run the DIAG `wrench` | thick **7/7** incl. both `1mm … fillet at new T` rows. DIAG: prints `DIAG:` and the failures are **exactly** `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge`. Record every fillet row |
| N9 | #187 | (Same files.) Read the DIAG header triangle count and the other fillet rows | `head-shaft R10 fillet ±Y`, `R10 fillet not oversized`, `1mm fillet bottom outer edge` PASS (≈5760 tris; 2438 = fillets lost). No fifth failure |
| L7 | #200 #201 | File → Save As `wrench-t14.sxp` (`Saved …`), Ctrl+S (`Saved …`). (a) Timeline pencil on the slot sketch → `Editing sketch`; press **Exit Sketch** with **no edits** → `Sketch saved`. (b) Fillet, radius `1.5` (type it; Ctrl+A in the field selects the field text), key `3`, click the slot floor, Enter (refused), Esc. (c) File → New | (a) `Sketch saved`, nothing in the Timeline changes. (b) `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius`, then `Edge pick cancelled`; Ctrl+A did not select faces. (c) **No** `Discard unsaved changes?` dialog; `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| N8b | WP4 | File → Open: single-click `blank.sxp` in the list. Open. Keep the pointer **still** on the body | The Open button is enabled after the single click (one retry allowed, rule 2); `Opened $OUT/blank.sxp` stays on the label for 2.5 s, then the hover hint appears with the pointer still (rule 46); the blank is **framed** (whole body inside the canvas, ≥ 40 % of its width), not extremely zoomed in. No Discard dialog (the New document was clean) |
| N14 | #201 | Rail Sketch on the top face. Draw a Circle r `5` and one loose **Line** leaving an open end vertex. Set Cut / Blind / `2.5`; click Extrude. Then Esc, Esc. Then File → New | Refusal reads `Line at (x, y) breaks the chain — delete or trim it`; **no UUID anywhere** in the status; Esc 1 is the ladder (`… — Esc again exits the sketch`), Esc 2 `Sketch saved`; the host face is not left selected. File → New **does** show the Discard dialog (real edit made) — press OK |
| A10 | #203 | New document, Sketch on ground: Circle r `50` (Ø100), Extrude Blind `10` (Distance field is `10` after typing, not `5` or a value left by an earlier tool). Rail Sketch on the top face: Circle r `45` (Ø90), Cut / Blind, Extrude | Exact status `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; the body is unchanged. The Circle Radius field shows its own last value, not `50` carried into a new document |
| A10b | carry | File → New (Discard OK); read the finish bar | `New` / `Blind` / Extrude enabled; Distance is the default (not `5`); `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| A14 | WP2 | Rail Sketch on ground. **Polygon** (across flats), centre click; then L9 below; type `20` Enter; Circle r `5` at the centre; Extrude `7.5`; export `nut.3mf` | `Polygon AF 20.0000 — flats horizontal`; `Circle r=5.0000 (Ø10.0000)`; `Extrude Blind 7.5000 mm`; checker nut **7/7** |
| L9 | WP2 | In A14, after the centre click, move the pointer off-axis in three steps (20°, 70°, 110° from the centre) **before** typing | After each move the preview hexagon has a **vertex under the pointer** (the pointer is on the circumscribed circle) and the flats stay horizontal; the status reads `Polygon AF <size> — flats horizontal — click to place (or type the size)` with `<size>` = √3 × the pointer distance from the centre (4 decimals); before the first move `Polygon — click the centre, then a vertex (or type the size)`. A pointer click commits `Polygon AF <same size> — flats horizontal`. If it freezes: record the hovered control and status, repeat once with a second move (rule 34) |
| A15 | WP5 WP6 | Run `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd`; `… tests/run_rung01_replan16_walk.gd`; `… tests/run_rung01_replan17_walk.gd`; `make test-godot`; `make test-godot-known-red` | lint prints `<N> replan16 scripts are clean` and `<N> replan17 scripts are clean` (N ≥ 5; also `6 replan15 scripts are clean`); `lint_suites: <n> suites ok` with n ≥ 165 (`known-red` counted); wrench walk `0 failures` (≥ 729 checks); replan16 walk `0 failures`, `WALK-SUMMARY stages=8 first_red=none`; replan17 walk `0 failures`, `WALK-SUMMARY stages=8 first_red=none`; `make test-godot` ends `suites: <n> run, 0 failed`; `make test-godot-known-red` prints each known-red suite with its `reason=` and exits 0 |

End of chunk 6: all five checkers run; record every status line and checker table in WALK_LOG.

---

## Row index (69) → origin

A1 A2 A3 A4 A5 A5b A6 A7 A7b A8 A8b A9 A9b A9c A10 A10b A11a A11b A11c A11d A11e A12 A13 A13b A13c A14 A15 A16 A17 — **29 A rows**. L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 — **12 L rows**. N1a N1b N2 N3 N4 N5 N6 N7 N8a N8b N9 N10 N11 N12 N13 N14 N15 N16 N17 N18 N19 N20 N21 — **23 N rows (sx-035 to sx-037)**. New in sx-038: **N22** window fills the screen (WP4), **N23** Timeline vs part chip row (WP4), **N24** sketch drag-box (WP3), **N25** DOF chip after undo (WP2), **N26** glyphs on their vertices (WP1) — **5 rows**. 29 + 12 + 23 + 5 = 69 (28 N rows in all).

## Out of scope

- Soft-GL / llvmpipe / Mesa / Godot renderer; switching Godot off 4.7-stable; screenshot lag; dropped keys; the one File-menu stall; orbit sensitivity; a click that never reaches the app (rule 51: no log line).
- Checker formulas or tolerances; the probe-count "tooling" item.
- Nav preset defaults (`nav_preset` `FUSION`); `docs/plan/*` features other than the STATUS entry; the snadrus fork.
- Test-only cameras, `_look_along`, `set_view(`, writing `camera.yaw` / `camera.pitch`, `select_entity` or script-side selection in the walk or the replan16 / replan17 suites.
