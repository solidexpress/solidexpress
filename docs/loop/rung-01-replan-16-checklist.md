# sx-037 GUI checklist (rung 1 replan 16)

Status: planned. Plan: [`rung-01-replan-16.md`](rung-01-replan-16.md). Baseline: [`rung-01-replan-15.md`](rung-01-replan-15.md) "sx-036 GUI checklist" on top of replan 14 / 13 / 12 / 11 / 10 (rows A / L / N, rules 1–44). This file is the **complete handout**: every row of the sx-036 walk (57) plus the seven new rows N15–N21 = **64 rows**, in the order they happen, in **6 chunks**. Each chunk starts in the app state the previous chunk ended in. Do not skip rows; do not reorder.

**Walk this file only when WP1–WP6 are merged.** Download the Linux build from the rolling `linux-test-build` prerelease ([`linux-test-build.md`](linux-test-build.md)); `BUILDINFO.txt` `commit=` must be the full sha of `main` after WP6. Do not test an older sha and do not use a box-local export.

Setup: 1280×800 window, `DISPLAY` set, Forward+ soft GL is fine. `OUT=/workspace/sx-037/out` (every export / save goes there; read every resolved path back, rule 24). Checkers (never `--allow-mirror`, never edit probes):

```bash
python3 tools/check_rung01.py blank  $OUT/blank.3mf          # 5/5
python3 tools/check_rung01.py wrench $OUT/wrench.3mf         # 28/28, flipX=False flipY=False (22 total = slot missing = FAIL)
python3 tools/check_rung01.py thick  $OUT/wrench-t14.3mf 14  # 7/7
python3 tools/check_rung01.py wrench $OUT/wrench-t14.3mf     # DIAG: exactly four by-design fails
python3 tools/check_rung01.py nut    $OUT/nut.3mf            # 7/7
```

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 7/7, headless walk 0 failures (`run_rung01_wrench.gd` and `run_rung01_replan16_walk.gd`), every A / L / N row PASS or classified soft-GL **with evidence** (screenshot + status text + one retry), fillets succeed on the first try from the views the app offers, a real Slot (`Extrude Blind 2.5000 mm`). Sx-036 scored 7/10 (41 PASS / 11 FAIL / 4 PARTIAL / 1 BLOCKED of 57). Any BLOCKED row caps the score below 9.

## Chunks

| Chunk | Rows | Starts in | Ends in |
|---|---|---|---|
| 1 | A1 A2 N7 L1 A3 L5 A4 L6 L10 A5 N12 A5b L8 L11 N17 (15) | Fresh app, File → New, ground sketch | Part mode, blank (Ø45 head + Ø20 pivot, 10 thick) exported and saved as `blank.sxp`, nothing selected, no menu open |
| 2 | A7 L2 A6 N4 A7b A8 N5 A8b N8a (9) | End of 1 | Jaw sketch open for editing (pencil), Timeline visible, jaw `20` / `45°` committed, no pivot or head circle yet |
| 3 | A9 L4 N1a N21 L12 A17 A9c N1b N20 A9b (10) | End of 2 (sketch open) | Part mode, body cut by the open jaw (`Extrude Up To Surface 10.0000 mm`), `pre-cut.sxp` saved |
| 4 | A16 N6 A11a N18 N10 (5) | End of 3 | Part mode, shaft Slot cut (`Extrude Blind 2.5000 mm`), saved as `wrench-wip.sxp`, Top view |
| 5 | A11b N2 L3 A11c N3 A11d A11e N15 N13 N16 N19 (11) | End of 4 | Part mode, neck R10 + top / bottom / slot-floor R1 applied, Fillet disarmed, Timeline on, document dirty |
| 6 | A12 N11 A13 A13b A13c N9 L7 N8b N14 A10 A10b A14 L9 A15 (14) | End of 5 | nut exported, lint and walk run |

If a chunk fails a row that the next chunk depends on, say which, and re-enter from the last saved `.sxp` (rule 11): after chunk 1 `blank.sxp`, after 3 `pre-cut.sxp`, after 4 `wrench-wip.sxp`.

## Re-verify rows (failed or knocked-on in sx-036) — read these first

| Row | Was | Pass now |
|---|---|---|
| N11 | BLOCKED: open mesh | A name typed **without** an extension ends in `.3mf`: file `wrench-noext.3mf` exists, `wrench-noext` does not, status `Exported 3MF → …/wrench-noext.3mf`; checker 28/28 on it (chunk 6) |
| N12 second click | not walked | One Extrude click → `Extrude Blind 10.0000 mm` and only that; a second click at the same pixel changes nothing: feature count equal, no `jaw_af` chip text (chunk 1) |
| N2 ▲ / ▼ | expected `3.0` | Arrow step is 0.5: strip `R` 2 → ▲ reads `2.5 mm` → ▼ reads `2 mm` (chunk 5) |
| N1a `22.5` | label missing | `22.5` (head radius) and `5` (pivot) are recorded **by Trim**, so they exist only after a successful `Trimmed open jaw`. After Trim the list is exactly `20`, `45°`, `5`, `22.5` (chunk 3) |
| L7 | Discard dialog | No `Discard unsaved changes?` after Save + refused fillet + Esc + File → New, and after Exit Sketch with no edits (chunk 6) |

## Changed text vs sx-036 (use these strings)

| Where | Now |
|---|---|
| Esc in a sketch that holds geometry | Never discards. Selection → `Selection cleared — Esc again exits the sketch`; draw tool → `Tool dropped — Esc again exits the sketch`; pending first point → `First point dropped — Esc again exits the sketch`; last Esc → `Sketch saved` (empty sketch: `Sketch cancelled`) |
| Part mode keys | Ctrl+Z → status begins `Undo`; Ctrl+Shift+Z (or Ctrl+Y) → status begins `Redo` |
| Sketch undo / redo | `Undo: Jaw`, `Undo: Dimension`, `Redo: Jaw` …, `Nothing to undo` |
| N4 | second Esc is `Sketch saved`; the throwaway sketch is removed with part-mode Ctrl+Z |
| A6 | with Up To Surface active the first Circle click still lands (it is not a face pick) |
| N10 | included region = light fill, **hovered** region = stronger fill, skipped region = outline only (not "the other region is outline only") |
| A11d / A11e | `Fillet <n> edges 1.00 applied — View ▸ Timeline to edit parameters`; R1.5 on the slot floor: `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius`; Esc → `Edge pick cancelled` |
| A9b | `Extrude Up To Surface 10.0000 mm`; body 232.5 × 45.0 × 10.0 (±0.3) |
| A13 | `Preview: distance = 14.0`, no `lost on rebuild` |
| N13 | `No view for key 0 — use 1 2 3 4 6 7 8` |
| Export | `Exported 3MF → <path>` |
| Numbers | Strip `R` and panel Radius show the same text, `10 mm`, `1.5 mm`, `2 mm` |

## Soft-GL protocol (sx-037 walker)

Rules 1–16 (replan 10), 17–22 (11), 23–30 (12), 31–36 (13), 37–40 (14), 41–44 (15) stay. Highlights: read every typed field back before Enter (1); one retry of a dead click, never a third (2); the status line is the truth, screenshots lag one action (8, 36); real rail presses (33); first glyph of a label (27); never move the view to dodge the rail (28); Esc ends an armed pick (29); one Extrude click then read (41); typed export names read back (43). New:

45. **A plain click never prints `Editing sketch`.** `Editing sketch` appears only after the Timeline pencil, a double-click on a Timeline sketch, or rail Sketch → click a sketch / pad. Any other `Editing sketch` (face click, slot floor click, empty ground, a chip click) is a **product failure** (N15); stop that row, record the full status log, do not click again.
46. **Results hold 2.5 s.** After a command result (`Opened …`, `Framed all`, `No view for key 0 …`) keep moving the pointer over the body for 2 s: the label must still read the result. A hover hint (`Face — click selects body first …`) replacing it earlier is a failure (N16). After 3 s the hint is correct.
47. **Typed values replace.** First key into a numeric field replaces the whole value (strip `R`, panel Radius, Distance, circle / polygon / slot fields, dimension editor). A field reading `10` after typing `1` `.` `5`, or `1` after typing `10`, is a failure; one retry (rule 1), then record.
48. **Camera rows read the picture twice.** For N18 screenshot the part view immediately before entering the sketch and again after the Extrude result; compare the head and pivot pixel positions (±5 px).
49. **Soft-GL evidence** = screenshot + status text + one retry on a fresh frame. Allowed classes: lag (8), dropped key (1), one ~10 s File-menu stall under llvmpipe (leftover 22), large tilt per small orbit drag (`ORBIT_SPEED` 0.008 rad/px, leftover 23). Anything else is a product row.
50. **Number the contours by size** (rule 42) and read `Contour N of M — W × H mm at (x, y)` for N10.

---

## Chunk 1 — blank (15 rows)

Start: launch, File → New (`New — empty part, Top plane (XY). View ▸ Timeline to edit features`), rail **Sketch** on the ground plane. Keep the blank open through A13c (rule 10).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A1 | #185 | Read the left rail in the new sketch (before drawing) | All **19** rail labels fully visible at 1280×800, last label inside the window, none clipped. The chip row starts right of the rail, covers neither Arc nor Point, ends inside the right edge (re-read in A3 with two circles selected) |
| A2 | carry | Press **Jaw**, then **Rect** | Jaw: a status starting `Jaw`, no variant chips. Rect: `Rect — click 1 first corner, click 2 the opposite corner`; chips left to right `Corner`, `Center`, `Three Point`, `Center Three Point`, `Parallelogram` (`Corner` first and highlighted — SolidWorks rectangle flyout, Corner Rectangle default) |
| N7 | WP5 | Rail **Jaw**; then rail **Rect**; then rail **Circle** and click one centre | The armed button is visibly lit — accent fill and a 3 px accent bar on its left edge — and clearly different from a merely hovered button; only that button is lit. Circle centre click: `Circle — centre set, click the rim or type a radius` |
| L1 | carry | After Jaw press Line, Smart Dim, Trim, Slot, Circle, Select in turn: rail buttons, then keys `L` `D` `T` `C` `S` | Each press prints a sentence that starts with that tool's own name, never the previous tool's. Slot's button is lit. The Radius field is **not** prefilled with another tool's number (circle radius is separate from slot radius) |
| A3 | #182 | Delete the A2/N7 scratch (select, Delete, or Esc to empty). Circle tool: **first click** at the origin; type `10` Enter. Circle: click right of it; type `22.5` Enter. Smart Dim: click centre 1 (`Smart Dim: first pick set …`), plain click centre 2 (no Shift); type `200` Enter | Both first clicks land. Typed digits replace the field (reads `10`, `22.5`, `200`; rule 47). `Circle r=10.0000 (Ø20.0000)`, `Circle r=22.5000 (Ø45.0000)`, `Dimension updated`. Centres level (head centre y = pivot y ±0.05). Chip row check from A1 with both circles selected |
| L5 | #182 | Press `F`; then HUD **Frame**; then `Shift+F` | `Sketch view fit` (or the HUD's equivalent); **both** circles fully inside the canvas, right of the rail and inside the window each time; the grid covers the whole canvas (no small grid patch around the circles); no stale disc |
| A4 | carry | **Shaft Lines** | `Shaft lines: 2 added` |
| L6 | #183 | Read the canvas; zoom out three wheel notches | No red / orange ✕, no live Δ labels. Blue `H` / tangent badges are expected. A **red or orange** H badge or a conflict count is a failure. Squashed circles in a screenshot with equal projected x / y: soft-GL (rule 35) |
| L10 | carry | Finish bar Distance: type `10` Enter, then `14` Enter, then `10` Enter; read the field right after each Enter and one frame later | The field never shows the previous value (rule 47); ends at `10`. A one-frame flash seen only in a lagging screenshot is rule 8 |
| A5 | carry | Set Distance `10`, Blind, New. Click **Extrude** once with the mouse | After two frames: `Extrude Blind 10.0000 mm`. Then File → Export 3MF, type `blank.3mf` in `$OUT` (read the field back); `Exported 3MF → $OUT/blank.3mf`; checker blank **5/5** |
| N12 | #181 | Re-verify the A5 Extrude (rule 41): read the result, then click the **same pixel** once more | One body; Timeline `sketch 1`, `extrude 2` (names are indices, rule 37). The second click changes nothing: feature count equal, no new status, no `jaw_af` / AF chip text anywhere |
| A5b | carry | File → New: the Discard dialog → **Cancel**. Then File → Save As | Cancel keeps the blank. Save As dialog opens pre-filled `untitled.sxp`, name selected |
| L8 | carry | In that dialog do **not** press Ctrl+A; type `blank.sxp`; read the field back; OK | Typing replaced the selected name; `Saved $OUT/blank.sxp` |
| L11 | carry | Open the HUD **View ▼** menu; close; open the menu-bar **View** menu | Both lists are opaque; no button shows through them |
| N17 | WP5 | Click the body (selected). Open the menu-bar View menu, press **Esc** once; repeat with the HUD View ▼; then press Esc once more with no menu | First Esc: the menu closes, the body **stays selected**, the left panel mode is unchanged, no `Selection cleared`. Same for the HUD menu. The third Esc → `Selection cleared` |

End of chunk 1: part mode, nothing selected, `blank.sxp` saved, `blank.3mf` exported.

---

## Chunk 2 — face sketch, Esc ladder, jaw (9 rows)

Start: end of chunk 1.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A7 | carry | Plain-click the top face once, then rail **Sketch**, then click the top face again | The plain click gives a status beginning `Selected ` and **never** `Editing sketch` (rule 45). Rail Sketch: `Select a face or existing sketch (Esc to cancel)`; then `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)` |
| L2 | WP3 | In this new sketch set the finish bar to **Cut / Up To Surface / `7`**. Keep it | Used by A6 next |
| A6 | #184 | Circle tool, **one** click in the canvas (with Up To Surface still set), Esc, Esc. Exactly two presses | The click lands (`Circle — centre set, click the rim or type a radius`; no face pick, no `Selected`). Esc 1: `First point dropped — Esc again exits the sketch`. Esc 2: `Sketch cancelled` (empty sketch). No `Measure cleared` between |
| N4 | #184 | Rail **Sketch** on the top face (read the finish bar: **Blind / New / 20** — L2 reset). Polygon AF `20` at a point (type `20` Enter after the centre click). Circle tool: click the centre, click into the Radius field: (a) Ctrl+A; (b) Esc, Esc. Then part mode: Ctrl+Z | Finish bar reset (L2: a different new sketch resets). (a) the field text is selected; no `Selected … sketch entities`; selection unchanged. (b) Esc 1 `First point dropped — Esc again exits the sketch`; Esc 2 `Sketch saved`. Ctrl+Z: status begins `Undo`; the throwaway sketch is gone from the Timeline |
| A7b | carry | Rail Sketch on the top face again | Face sketch opens (`Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`); finish bar Blind / New / 20 |
| A8 | #186 | **Jaw**: click 1, click 2, **click 2 again at the same pixel**, click 3. Then **one click on the first glyph** of the width label `20`, type `20` Enter; then of the angle label `45°`, type `45` Enter | Clicks 1 and 2 each show a rotated (not axis-aligned) preview. The repeated click 2 prints `Jaw — width is zero — click 3 again for half the width`, no `Jaw committed`, entity count unchanged. Click 3: `Jaw committed — width …, long side …° — click a label to edit it`, non-zero width. Each label opens on the **first** click with its text selected (rule 47); `Dimension updated`; walls at 45°, included angle 90° ±0.05° |
| N5 | carry | Select tool. Ctrl+Z, Ctrl+Shift+Z, Ctrl+Z, Ctrl+Z … until empty, then Ctrl+Shift+Z until the jaw and both dimensions are back | `Undo: Jaw` removes the Jaw (earlier `Undo: Dimension` steps first); `Redo: Jaw` restores it; at the empty end `Nothing to undo`; after the redos `20` and `45°` are shown again with the jaw. Trust statuses and entity count (rule 40) |
| A8b | #184 | Select tool, click a jaw line, **Esc**, **Esc**; then in part mode Ctrl+Z, then Ctrl+Shift+Z | Esc 1: `Selection cleared — Esc again exits the sketch` (no `Measure cleared` first). Esc 2: `Sketch saved` — the sketch and jaw are **kept**, not discarded. Selecting the Select tool reads `Select — click geometry, or a dimension label to edit it`. Part Ctrl+Z: status begins `Undo`, the sketch leaves the Timeline. Ctrl+Shift+Z: status begins `Redo`, `sketch 2` is listed again with the jaw |
| N8a | #184 | View ▸ **Timeline** on (check N19 later). Click the **pencil** next to the jaw sketch | `Editing sketch`; no rename field (F2 on the row still renames). Finish bar reads **Blind / New / 20** (L2: re-entered existing sketch also resets) |

End of chunk 2: jaw sketch open in edit mode.

---

## Chunk 3 — pivot, trim, labels, cut (10 rows)

Start: jaw sketch open (end of chunk 2). **Before pressing the pencil in N8a** take the N18 screenshot of the part view; compare after A9b (rule 48).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A9 | #188 | Press `F`. Circle tool: **first click** on the pivot centre at the origin, 30 px right of the visible rail, view unmoved; type `5` Enter. Circle tool again: redraw the Ø45 head on the head centre, type `22.5` Enter. Draw a **plain Line** (not Centerline) across the head. **Power Trim** (`T`): drag from the **outer stub** across the Line | First click lands: `Circle r=5.0000 (Ø10.0000)` (rule 28). Trim: `Trimmed open jaw`; the Line is gone; no pan. A second drag: `Jaw is already open — nothing left to trim here`. If the Line is not across the head the status is `Nothing trimmed — no crossing at that point` (never a bare `Trimmed`); redraw and retry |
| L4 | #186 | Read the jaw labels right after Trim | Exactly one `20` and one `45°`; no `20.0005` / `45.0007°`; no overlapping labels. (Wall 45° ±0.1° is confirmed by wrench 28/28 in chunk 6) |
| N1a | #186 | Zoom with the wheel until the Ø45 head is **~150 px** across. List every dimension label (text and place) | Exactly `20`, `45°`, `5`, `22.5`. None overlap; none sits on a constraint glyph; none is under the menu / rail / chips; the first glyph of `20` and of `45°` is clickable (opens the editor; Esc closes it) |
| N21 | WP4 | Same zoom: read the constraint glyphs around the head and pivot | No pile-up: glyphs are spread (≥ ~60 % of each visible); a click on one glyph selects it (`Constraint selected: …`) |
| L12 | carry | Arm Circle; move over the jaw and shaft lines. Then Select tool and hover with no click; Esc | Circle armed: **no** ✕, no Δ labels, ever. Select + hover (no click): ✕ with Δ; Esc → `Measure cleared`, chips still showing. After a Select **click** on geometry the ✕ is gone and the next Esc is `Selection cleared — Esc again exits the sketch` (do not press a second one) |
| A17 | carry | Read the Line / Centerline chips and the Contours row | Chips do not overlap; Contours row only with more than one closed region; a Centerline commit reads `Centerline added — construction, not part of the profile` (draw one and delete it) |
| A9c | WP3 | Set the finish bar to **Cut**, **Up To Surface**, pick the opposite face (`Face: z 0.0 mm`), thin / flip off. Then File → Save As `pre-cut.sxp`; OK | `Saved $OUT/pre-cut.sxp`; the sketch, Select tool and profile are still there; the finish bar is exactly as set (Cut / Up To Surface / `Face: z 0.0 mm`) — it is **not** reset |
| N1b | #186 | List the labels again; hover a label while its editor is open | Identical to N1a (no second `45°`, no new `5` / `22.5`). Editor open: no Δ overlay, no ✕ left at an old endpoint |
| N20 | WP3 | Save As `pre-cut.sxp` again (overwrite); press Ctrl+Z | `Saved …` again; finish bar still Cut / Up To Surface / `Face: z 0.0 mm`; Extrude button enabled; Ctrl+Z status begins `Undo:` (sketch undo kept) — then Ctrl+Shift+Z |
| A9b | #188 | Click **Extrude** once; read the status after two frames | `Extrude Up To Surface 10.0000 mm`; no `breaks the chain`, no open-shell refusal. Select the body: size reads 232.5 × 45.0 × 10.0 (±0.3) (if no size readout exists, A12 28/28 is the evidence). A plain click inside the head → `Selected `, never `Editing sketch` (rule 45). **N18 (first read):** the part view equals the screenshot taken before N8a (head and pivot ±5 px) |

End of chunk 3: part mode, jaw cut, `pre-cut.sxp` saved (re-save with Ctrl+S now so it holds the cut: `Saved …`).

---

## Chunk 4 — views, slot (5 rows)

Start: end of chunk 3.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A16 | carry | View menu: Back, Left, Bottom; keys `4`, `6`, `8`; orbit off Top with the preset's orbit drag; then key `3` | Menu lists Back / Left / Bottom; each key shows its view; the drag moves the camera (a large tilt per small drag is leftover 23, soft-GL); `3` → `Top view` |
| N6 | carry | Part mode: key `3`; wheel-in three notches with the pointer on the head; wheel-out three; `F`; `Shift+F`; HUD **Frame** | The point under the pointer stays under it (±2 px) through the wheel. `F` → `Framed selection` (body selected) or `Framed all`; the part lands right of the left panel inside the window; HUD Frame gives the same view. End in Top view |
| A11a | carry | Screenshot the Top view (N18). Rail Sketch on the top face. Slot: type radius `5` Enter, click centre 1 at `(18.5, 0)`, read the field label (`c-c`), type `150` Enter | Slot lit; status `Slot — …`; stadium preview; label `c-c` after the first centre; `Slot c-c 150.0000 R5.0000 — typed` (rule 23). Finish bar: Blind / New / 20; the Extrude Distance stays 20 until you set it |
| N10 | carry | Draw a throwaway Circle (r 5) in the head so the sketch has two closed regions: the **Contours** chips appear. Hover chip `2`; click chip `1` off, then on; then delete the throwaway (Select, click it, Delete) | Hover: that region gets the **stronger** fill with a `2` tag; the included region keeps the light fill; a skipped one is outline only. Click: `Contour 1 of 2 — W × H mm at (x, y) — skipped` then `— included` (read the status, rule 50). After Delete: `Deleted 1`, chips gone |
| N18 | WP5 | Set **Cut**, **Blind**, Distance `2.5`. Click **Extrude** once. Save As `wrench-wip.sxp` | `Extrude Blind 2.5000 mm` (a real Slot). The part view is the **Top view screenshot** from A11a (head and pivot ±5 px; the camera does not jump). `Saved $OUT/wrench-wip.sxp` |

End of chunk 4: part mode, Top view, slot cut, `wrench-wip.sxp` saved.

---

## Chunk 5 — fillets (11 rows)

Start: end of chunk 4. Fillets are picked from keys `3` (Top), `4` (Back), `8` (Bottom), `1`, `7`, with the body selected. Zoom with the wheel or `F`. Click each fillet target **once**; a first click that misses is a failure (leftover 4).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A11b | #168 | Select the body (click it). Press the **Fillet** chip (Fillet armed). Key `3`. Click each **neck corner** (the two vertical edges where shaft meets head). Key `4` and click the +Y wall; press on the empty background. Do **not** press Enter yet | Corner click: `Fillet: 1 edge(s) — 10.0 mm vertical …` (not the 32.3 mm arc, and no `0.0 mm line`); the wall click keeps the set (adds an edge only within 14 px, else `No edge near click …`); the background press: `Missed the solid — click a face or edge`, set and panel kept |
| N2 | WP3 | Fillet still armed. (a) Strip `R`: ▲ then ▼ then key `3`. (b) Strip `R`: click into it, type `10`, Enter, then keys `3` and `4`. (c) Panel **Radius**: click into it, type `10`, Enter, then key `3` | (a) ▲ `2.5 mm`, ▼ `2 mm` (step 0.5), key `3` → `Top view`. (b)(c) the field reads `10 mm` (no extra digit, never `1` / `100`); each key prints `Top view` / `Back view`; **Fillet is still armed** (strip `R` visible; `Fillet r=10.00 — edit Radius, click edges, Enter`). Rule 47 |
| L3 | #168, WP3 | Strip: type `10` Tab. Panel: type `1.5` Tab; then `10` Tab | Strip `R`, panel Radius and the status show the **same** number each time (same text, `10 mm` / `1.5 mm`); Tab leaves the field and the next key goes to the viewport (key `3` → `Top view`, not `AF 10`). Enter uses the number on screen. End at `10` |
| A11c | carry | Click one wrong edge; read the status; click it again. Then press **Enter** at R10 (the apply of A11b) | Count rises then drops: status ends `— removed 179.8 mm line` (a length and kind). Enter with the two verticals: `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters` (not `Feature created`) |
| N3 | carry | Note the x of the `Fillet` and `Chamfer` chips with the body selected; then with a face selected; then with Fillet armed | Both x identical (±1 px) in all three states; the bar is fully below the menu row, never touches `Snap`, ends inside the window (wraps if needed); clicking the noted x arms **Fillet** every time |
| A11d | #188 | Fillet, radius `1`. Key `3`, click the **top face** once (inside it, away from edges, ≥ 8 px); Enter. Then key `8`; select the body; **one click on the bottom face, then move the pointer twice**; Enter | Face click: `Fillet: <n> edge(s) — …` with n ≥ 6 and no `0.0 mm line`. Both Enters: `Fillet <n> edges 1.00 applied — View ▸ Timeline to edit parameters` first try; never `No edges selected`; the body does not move and no `Moved body` |
| A11e | #188 | Key `3`; Fillet, radius `1`; **one click on the slot floor** (inside the slot outline, away from the rim); Enter. Then R `1.5` on the same floor: Enter | Click: `Fillet: <n> edge(s) — …` listing the floor's ≈150 mm lines and ≈15.7 mm arcs (not the neck loop `175.4 line, 42.2 line`). Enter: `Fillet <n> edges 1.00 applied …`. R1.5: `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius`. Esc → `Edge pick cancelled`; Fillet no longer armed |
| N15 | WP2 | Fillet not armed (after the Esc). (a) Click **empty ground** inside the part's sketch footprint; (b) click the **slot floor**; (c) click the **Fillet chip**; (d) Esc | (a)(b) status begins `Selected ` (or the selection simply changes); **never** `Editing sketch`, never a sketch entering edit mode, never a loft status. (c) `Fillet r=…` (armed). (d) `Edge pick cancelled` |
| N13 | carry | Part mode, no field focused (click empty viewport first): press `0`, then `3` | `No view for key 0 — use 1 2 3 4 6 7 8`; the camera did not move; `3` → `Top view` |
| N16 | WP5 | Press `0` again; at once move the pointer across the body for 2 s without clicking; wait to 3 s with the pointer on a face | The label still reads `No view for key 0 — use 1 2 3 4 6 7 8` for 2.5 s (rule 46); after 3 s the hover hint `Face — click selects body first, click again for face · then Pull arrow` shows |
| N19 | WP5 | View ▸ **Timeline** on. Arm Fillet; look at the left Modify panel; click the Radius field and type `2`; Esc | The Timeline does **not** cover the Radius field or any Modify panel control (they do not intersect; both fully inside the window); the click focuses Radius (field reads `2`); Esc → `Edge pick cancelled` |

End of chunk 5: Fillet disarmed, Timeline on, document dirty (`wrench-wip.sxp` is older).

---

## Chunk 6 — export, thickness, dirty flag, nut, lint (14 rows)

Start: end of chunk 5.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A12 | #188 | File → Export 3MF, type `wrench.3mf` (read back), OK | `Exported 3MF → $OUT/wrench.3mf`; checker wrench **28/28**, `flipX=False flipY=False`; open-shell / mesh warnings: none |
| N11 | #188 | File → Export 3MF, select all in the name field, type `wrench-noext` (no extension), OK | File `$OUT/wrench-noext.3mf` exists and `$OUT/wrench-noext` does not; status `Exported 3MF → …/wrench-noext.3mf`; checker wrench 28/28 on it |
| A13 | #187 | Timeline: double-click the base extrude (first Extrude, Distance 10). Distance field (text selected): type `14`, Enter | `Preview: distance = 14.0` (and the part previews 14); the status never says `lost on rebuild`; fillets still present |
| A13b | carry | With the field focused press **Esc**; reopen; type `14` Enter; click empty viewport | Esc: closes the panel; distance returns to 10 (`Edits cancelled`). Empty click: closes the panel and **keeps 14**; never `Editing sketch` |
| A13c | #187 | Export `wrench-t14.3mf`; run `thick … 14`; run the DIAG `wrench` | thick **7/7** incl. both `1mm … fillet at new T` rows. DIAG: prints `DIAG:` and the failures are **exactly** `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge`. Record every fillet row |
| N9 | #187 | (Same files.) Read the DIAG header triangle count and the other fillet rows | `head-shaft R10 fillet ±Y`, `R10 fillet not oversized`, `1mm fillet bottom outer edge` PASS (≈5760 tris; 2438 = fillets lost). No fifth failure |
| L7 | WP2 | File → Save As `wrench-t14.sxp` (`Saved …`), Ctrl+S (`Saved …`). (a) Timeline pencil on the slot sketch → `Editing sketch`; press **Exit Sketch** with **no edits** → `Sketch saved`. (b) Fillet, radius `1.5`, key `3`, click the slot floor, Enter (refused), Esc. (c) File → New | (a) `Sketch saved`, nothing in the Timeline changes. (b) `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius`, then `Edge pick cancelled`. (c) **No** `Discard unsaved changes?` dialog; `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| N8b | carry | File → Open: single-click `blank.sxp` in the list. Open | The Open button is enabled after the single click (one retry allowed, rule 2); `Opened $OUT/blank.sxp` stays on the label while you hover the body for 1.5 s (N16); the blank is **framed** (whole body inside the canvas, ≥ 40 % of its width), not extremely zoomed in. No Discard dialog (the New document was clean) |
| N14 | carry | Rail Sketch on the top face. Draw a Circle r `5` and one loose **Line** leaving an open end vertex. Set Cut / Blind / `2.5`; click Extrude. Then Esc, Esc. Then File → New | Refusal reads `Line at (x, y) breaks the chain — delete or trim it`; **no UUID anywhere** in the status; the Esc ladder statuses (`… — Esc again exits the sketch`), final Esc `Sketch saved`. File → New **does** show the Discard dialog (real edit made) — press OK |
| A10 | carry | New document, Sketch on ground: Circle r `50` (Ø100), Extrude Blind `10`. Rail Sketch on the top face: Circle r `45` (Ø90), Cut / Blind, Extrude | Exact status `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; the body is unchanged |
| A10b | carry | File → New (Discard OK); read the finish bar | `New` / `Blind` / Extrude enabled; `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| A14 | carry | Rail Sketch on ground. **Polygon** (across flats), centre click; then A14/L9 below; type `20` Enter; Circle r `5` at the centre; Extrude `7.5`; export `nut.3mf` | `Polygon AF 20.0000 — flats horizontal`; `Circle r=5.0000 (Ø10.0000)`; `Extrude Blind 7.5000 mm`; checker nut **7/7** |
| L9 | WP4 | In A14, after the centre click, move the pointer off-axis in three steps (20°, 70°, 110° from the centre) **before** typing | After each move the preview radius follows and the flats stay horizontal; the status reads `Polygon AF <size> — flats horizontal — click to place (or type the size)` (size 4 decimals); before the first move `Polygon — click the centre, then a vertex (or type the size)`. If it freezes: record the hovered control and status, repeat once with a second move (rule 34) |
| A15 | WP1–WP6 | Run `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd`; `… tests/run_rung01_replan16_walk.gd`; `KEEP_GOING=1 make test-godot` | lint prints `<N> replan16 scripts are clean` (N ≥ 6; also `6 replan15 scripts are clean`); `lint_suites: <n> suites ok` with n ≥ 160; wrench walk `0 failures` (≥ 729 checks); replan16 walk `0 failures` and `WALK-SUMMARY stages=8 first_red=none`; `make test-godot` failures are only the three known in `AGENTS.md` (`nav_preset` Alt-orbit rows, one infer DOF row, one icon row) |

End of chunk 6: all five checkers run; record every status line and checker table in WALK_LOG.

---

## Row index (64) → origin

A1 A2 A3 A4 A5 A5b A6 A7 A7b A8 A8b A9 A9b A9c A10 A10b A11a A11b A11c A11d A11e A12 A13 A13b A13c A14 A15 A16 A17 — **29 A rows**. L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 — **12 L rows**. N1a N1b N2 N3 N4 N5 N6 N7 N8a N8b N9 N10 N11 N12 N13 N14 — **16 N rows (sx-035/036)**. New in sx-037: **N15** clicks never open sketches (WP2), **N16** status hold (WP5), **N17** menu Esc (WP5), **N18** camera restored after Extrude (WP5), **N19** Timeline vs Modify panel (WP5), **N20** Save As keeps the finish bar (WP3), **N21** glyph pile-up at ~150 px (WP4) — **7 rows**. 29 + 12 + 16 + 7 = 64 (23 N rows in all).

## Out of scope

- Soft-GL / llvmpipe / Mesa / Godot renderer; switching Godot off 4.7-stable; screenshot lag; dropped keys; the one File-menu stall; orbit sensitivity.
- Checker formulas or tolerances; the probe-count "tooling" item.
- Nav preset defaults (`nav_preset` `FUSION`); `docs/plan/*` features other than the STATUS entry; the snadrus fork.
- Test-only cameras, `_look_along`, `set_view(`, writing `camera.yaw` / `camera.pitch`, `select_entity` or script-side selection in the walk or the replan16 suites.
