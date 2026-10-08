# Rung 1 re-PLAN 19 — sx-039 findings and the sx-040 checklist (UBC ECE Exercise 2 wrench + nut)

Status: planned. Docs only. Baseline: `main` `7062ffb892b1b251afb74b2622020ecf4264293d` (`631e4b97` re-PLAN 18 build, WP1–WP4 #227–#231, plus #230, which changes only a Windows workflow; the tip was re-checked when this plan was written and had not moved). Previous plans: [`rung-01-replan-18.md`](rung-01-replan-18.md) (+ `-wp1` … `-wp4`), [`rung-01-replan-17.md`](rung-01-replan-17.md), [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md) and the files before them. Next walk: **sx-040** = the checklist embedded below (72 rows, 6 chunks). Work packages: **nine, sequential, for ONE grok-4.7 BUILD agent that implements all of them in order in a single PR** (this file is the only prompt; there are no per-WP files, because one agent builds everything and the loop rules forbid parallel WP agents and walk spin-outs).

## Where we are

Walk sx-039 (local build of `main` `631e4b97`, Linux, soft GL (llvmpipe), physical screen 1920×1200 with 1280×800 screenshots, `SX_INPUT_TRACE=1`) scored **FAIL 7.0/10** (sx-038: 7.5): **PASS 41, PARTIAL 20, FAIL 8** of 69 rows. The FAILs are N12, A8, N5, N25, N21, L3, A11d, N16. Checkers are all green (blank 5/5, wrench 28/28 with `flipX=False flipY=False`, wrench-noext 28/28, thick 14 7/7, DIAG on t14 exactly the four by-design rows 18/22, nut 7/7) and the headless tier is green (`suites: 182 run, 0 failed`, `lint_suites: 186 suites ok`, 48 ci suites 5393 checks). **Every failure is therefore something the headless suites cannot see.** Three are named regressions of earlier fixes: #217 (dropped digit, Enter kept focus), #218 (Extrude → `Hide`), #222 (badge pile-up).

The key finding of this plan is that the walk's two biggest failure families are **reproducible headlessly or on the PLAN box's real X11 display once the test pushes the events the way the walker's `xdotool` and a lagging frame deliver them**, which the existing suites never did:

- **A3 / L3 / A11d (keys).** On real X11, `xdotool type --delay 10 22.5` delivers the second `2` as `pressed=true echo=true`, and every `not event.echo` guard in the app drops it (`22.5` → `2.5`, `200` → `20`). Separately, a click that focuses a strip / panel number field and keys that arrive **in the same frame** lose to deferred focus-entry writes (`1.5` typed → `2.0` restored). Both are invisible to `Viewport.push_input` suites, which never set `echo` and always await a frame between click and keys.
- **N12 (shield).** The #218 shield is disarmed by a **File-menu press**, and disarming moves the chip row from below the Extrude button to the top of the canvas, onto the Extrude pixel. Reproduced headlessly.
- **A8 (jaw).** A first jaw whose width side is longer than its long side (the walk's `hl = 20 mm`, `hw = 48.4 mm`) cannot be re-dimensioned to 20 / 45°: the solver fails and leaves a red `!`. Reproduced headlessly. The jaw preview is also blank after click 1.
- **N16 / N8b (hint).** A hint that was shown **before** a command result is never shown again while the pointer stays still, and a hint shown during the hold **stays after the pointer leaves**. Reproduced headlessly with the status label. The "<1 s" and "1.5 s" readings were taken from screenshot order on a lagging box; this plan adds timestamps so the timing is decided by the app's own log, not by the walker.

Pass bar for sx-040 (unchanged): score ≥ 9; every A / L / N row PASS (or soft-GL **with evidence**); checkers nut 7/7, blank 5/5, wrench 28/28, wrench-noext 28/28, thick 14 7/7, DIAG exactly the four by-design failures (`tools/check_rung01.py`, never `--allow-mirror`); headless walks 0 failures; **`make test-godot` ends `suites: <n> run, 0 failed`** with lints clean; fillets succeed first try; a real Slot.

## How this plan was measured (not guessed)

All probes ran on the PLAN box on `main` `7062ffb` (OCCT 8.0.1 at `/opt/occt-8.0.1`, `make build`, `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script <probe>.gd`; the key probe ran non-headless on `DISPLAY=:1` with real `xdotool`). Probe scripts are throwaway (not committed: this PR is docs only); their outputs are attached to the PR body.

| # | Probe | What it did | Result |
|---|---|---|---|
| P1 | real-X11 key log (`xdotool type --delay 10` into the focused Circle Radius blank; every `InputEventKey` reaching `_input` printed) | 3 positions × `22.5`, `200`, `1.5`, `45` × 3 trials | `22.5` → `2.5` in **9 of 9**, `200` → `20` in ~7 of 9; `1.5` and `45` always correct; independent of pointer position. The log shows the order **press `2` (echo=false), press `2` (echo=**true**, same millisecond), release `2`, press `.` …**: Godot's X11 backend treats a same-keycode press that follows a release at the same X timestamp as auto-repeat, drops the first release and flags the press as echo. The app ignores echo presses (`viewport_interaction.gd` 426, 647, 893, 1009, 2128, 2767, 5616–5723, 5777, 5944, 5976, 5991; `sketch_context_chrome.gd` 1465, 1524; `ops_panel.gd` 285; `main.gd` 4248) |
| P2 | headless typing fuzz (6 event patterns × 4 strings into the same field) | pushes press / release with and without frames between | all OK: `push_input` never sets `echo`, so the headless suites cannot see P1 |
| P3 | headless same-frame burst on strip R and panel Radius (`probe_burst`) | click + Ctrl+A + `1.5` pushed with **no** frame between | the typed text is correct for the first events (`1`, then `1.5`), and **one frame later the field is back to the model value `2.0`** (strip and panel alike; Enter then applies the old value). With a frame between click and Ctrl+A the text survives. A same-frame `22.5` and `1.5` into the strip are both overwritten. Deferred focus-entry writes (`viewport_interaction.gd` strip `focus_entered` 596–611 → `_write_strip_radius(model, true)`; `SxUi.reveal_committed_spin.call_deferred` 52; `arm_replace_on_focus` 282) run after the typed keys. This matches sx-039 L3 exactly (`.` then `.5`: a late select-all replaced the leading `1`) |
| P4 | real-X11 strip and panel typing, spaced 0.3–1.2 s (`xdotool key ctrl+a`; `type --delay 10 1.5`; `key Return`/`Tab`; `key 3`) | 6 + 6 + 4 trials, including the exact L3 sequence (strip `10` Tab, panel Ctrl+A `1.5` Tab, `10` Tab) | all correct (`1.5`, `Top view`, focus returned). So the L3 / A11d failures need the lag (several events in one frame) of the walk box, not a plain slow typist: P3 is their headless twin |
| P5 | N12: `probe_n12` (finish bar → Extrude click, File menu press, second press on the Extrude pixel) | shield armed, strip y read each step | shield armed after Extrude; strip chip row y = 83; the **File press disarms the shield** (`_note_finish_press_outside`, `viewport_interaction.gd` 6911–6919, `call_deferred("_disarm_finish_click_shield")`); strip y drops to 48 (`_finish_click_strip_y` 6968 stops pushing it below the Extrude rect); the second press on the Extrude pixel is `drop:over-chrome:SelectionStrip` (no `drop:shield`), status `Chamfer r=2.00 — edit Radius, click edges, Enter` |
| P6 | A8: `probe_jaw_wide` — jaw with `hl` / `hw` / angle / snap on and off, then width → 20 and angle → 45 | 8 cases | `hl=20 hw=10` OK; `hl=40 hw=48.4` OK; **`hl=20 hw=48.4`, snap off: width→20 `failed`, DOF `!`, angle→45 `failed`**; snap on (long side snaps to 0°): width→20 `success` but included angle becomes 90° and DOF `!`, then angle→45 `failed`; `hl=5 hw=48.4` fails. `hw` = 10 / 30 / 70 with `hl=40` are fine. So the collapse is specific to a jaw whose width side is longer than twice its long side |
| P7 | A8 preview: `probe_jaw_preview` | pointer at / near the centre after click 1, and at 5–60 mm | blank (plus `ERROR: No vertices were added` from `surface_end`, `sketch_mode.gd` 8702) when the pointer is at / near the centre; renders at offsets ≥ ~20 mm. Click 1 leaves the pointer exactly on the centre, so the walker sees nothing |
| P8 | N16: `probe_hint` — hint then result with a still pointer; result then hint then pointer leaves; result then pointer leaves | label read at 0.5 s / 3.0–3.5 s | still pointer after a result: **the hint never returns** (rule 46 wants it by 3 s); hint held during the hold: written at 2.5 s, and **after `_on_hover_hint("")` (pointer left) the label still reads the hint** (stale). The hold itself is correct (`STATUS_HOLD_MS = 2500`, `main.gd` 146, 2620–2662) |
| P9 | N6: `probe_cam` — key `3`, then a wheel notch at once vs after the tween | head position before / after the first notch | first notch **during** the 0.25 s view tween moves the point under the pointer by 9.8–42.7 px (the anchor is computed from the mid-tween pose: `zoom_at` 561, `_zoom_anchor` 591, `_animate_pose` 740); after the tween 0.0 px |
| P10 | L9 / jaw / A11d spaced replays on real X11 (P4) and headless (probe `a11d`: strip click, Ctrl+A, `1`, Enter, key `3`, 4 variants) | focus owner and field text after each step | spaced A11d is correct headlessly (focus back on `Interaction`, `Top view`); A11d joins P3 (same-frame) |

Static reading (each is the first step of its WP to turn into a headless repro): N21 / N26 / A8b / N24(e) (the glyph score prefers a position **on** a sketch curve and nothing keeps a badge off a wall: `_glyph_block_score` `sketch_mode.gd` 7819, `_separate_glyph_screen` 7842); A13b (the first press of the double-click selects the feature, the Timeline relayouts under the pointer, the second press lands on empty ground: `timeline_panel.gd` 263–316, N23 relayout in `main.gd` `_update_panel_visibility` 1954); F7 (first fillet pick: `ops_panel.gd` `_accumulate_dressup_edge` 2286 uses a 6 px gate, `DRESSUP_FIRST_PICK_EDGE_PX` 2334, then `_add_dressup_face` 2502 seeds the face loop); N14 tint (`_update_hover` 3387 returns early for a selected body and while sketching, so `view.clear_hover()` is skipped when the pointer moves onto chrome); L12 Δv (`measure_overlay.gd` 460–486 omits Δv when `|dv| ≤ 1e-4`: an axis-aligned shaft line has none, by design); N4 `AF` text (`sketch_context_chrome.gd` 1213–1227: the blank holds the real text ` AF` and select-all arms replace, by design); A1 checkboxes (`main.gd` 936–947: Snap and Infer are `CheckBox` with `text = ""`); DOF `OK` on an emptied sketch (`run_solve` 5443 has no empty guard; `refresh_dof_state` 5429 and `_restore_undo_entry` 1153 do); L9 centre feedback (`sketch_mode.gd` Polygon branch ~4793 appends the centre with no status, Circle and Jaw have `CIRCLE_CENTRE_SET` / `JAW_AFTER_CENTRE`); N10 tag (`sketch_mode.gd` 4557 puts the tag at the region's bbox centre, which is the hole's centre when the region has a hole).

- **Checks.** `python3 tools/lint_suites.py` → `lint_suites: 186 suites ok (48 ci, 134 full, 4 known-red)`; `python3 tools/lint_rung01_e2e.py` → `7 / 8 / 1` clean scripts for replan16 / 17 / 18 (replan19 scripts are linted automatically when they exist: `tools/lint_rung01_e2e.py` `_lint_replan_n`).
- No product code, test, checker, CI or Makefile file was changed by this plan. The only new file is this document.

## Triage of every finding

Verdicts: **PRODUCT** (code is wrong; goes into a WP), **DESIGN** (behaviour is right; the checklist wording changes, quoted below), **PROCESS** (walker protocol; new rule in "Soft-GL protocol"), **LOG** (engine / log only; decided, not fixed). "Rows" are the sx-039 non-PASS rows the item explains.

### F1. Keystrokes and number fields

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 1 | A3: `22.5` → `2.5`, `200` → `20` (committed a 20 mm distance and killed the body) | **PRODUCT** (regression of #217 under real X11) | P1: echo-flagged second identical press, dropped by `not event.echo` guards. Rows A3, (L10, A8, A9, N18 re-verify) | WP1 |
| 2 | L3: panel Radius Ctrl+A `1.5` → `.` then `.5`, `0.5 mm`; then a click on the re-laid-out panel selected `Face 1 of extrude 2` and `10` went to the viewport (`No view for key 0`) | **PRODUCT** (regression of #200 / #217) | P3: typed text overwritten by deferred focus-entry writes when click and keys share a frame; the click that "selected a face" is the A13b relayout class (item 30). Row L3 | WP1 (keys), WP6 (relayout under the pointer) |
| 3 | A11d: strip R Ctrl+A `1` Enter kept focus; one `1` after Ctrl+A went to the viewport (`Front view`) | **PRODUCT** | P3 (the same-frame class: text overwritten by deferred writes). The `Front view` leak is the same window (keys before the field owns focus); WP1 test 4 asserts it cannot happen. Spaced replays (P4, P10) are fine, so the repro is the same-frame harness. Row A11d | WP1 |
| 4 | A8 angle editor read `4` before `45` | **PROCESS** | lag: the field settles at `45`; rule 62 (wait ≥ 1 s, read, screenshot) | rules |

### F2. Part-mode chrome, selection strip, rail

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 5 | N12: after a File menu press the chip row moves up and `Hide` sits on the Extrude pixel; no `drop:shield` anywhere in the trace | **PRODUCT** (regression of #218) | P5: the shield is disarmed by any press that is not on the Extrude rect or the chip row, including a menu press; disarming moves the strip to y 48. Row N12 | WP2 |
| 6 | A7 / A11a: the rail loses Sketch while a body or face is selected; first head click is `Selected body`, second is `Selected face` | **DESIGN** | Part-mode selection turns the rail into the inspector (context toolbar and inspector pencil carry Sketch); the two-stage pick is the decided two-stage pick (the status word says `body` or `face`; re-PLAN 18 row N17). Rows A7, A11a get an explicit how-to | rules (66), rows |
| 7 | N3 / Fillet armed with a face selected: no edge count | **DESIGN** | no edge is picked yet; status is `Fillet r=… — edit Radius, click edges, Enter`. Row N3 states it | row |
| 8 | A1: `—` DOF-chip fragment and two unlabeled checkboxes under Auto Dim | **PRODUCT** (small) | `main.gd` 926–947: DOF label and two `CheckBox` with `text = ""` (Snap, Infer). Row A1 | WP9 |
| 9 | A17: no rail tool highlighted after sketch Undo / Redo | **PRODUCT** (small) | static reading: `_sync_sketch_rail_highlight` (`main.gd` 1705) runs from `tool_changed` (1746) and session start (1609); `_restore_undo_entry` (`sketch_mode.gd` 1138) does not re-emit it. WP9 step 1 reproduces. Row A17 | WP9 |
| 10 | N14: the finish-bar op dropdown keeps closing | **PRODUCT-or-PROCESS, unproven** | popups are separate X windows on this build; a focus change from the driver closes them, and `return_viewport_keys()` / `grab_focus()` calls can too. Not reproducible headless. WP9 adds `[popup-trace]` (show / hide with timestamps) so the next walk decides; row N14 asks for one click to open, one to choose, with the trace lines | WP9 (trace), rule 70 |
| 11 | Log noise `Signal 'focus_entered' is already connected …` / `Attempt to disconnect a nonexistent connection … 'focus_entered'/'tree_exited'` on every File / View menu open or close | **LOG** | the app connects `focus_entered` only on its own LineEdits / Buttons (`grep focus_entered game/scripts`: `ops_panel` 266, `property_panel` 359, `sketch_context_chrome` 207 / 259 / 1856, `timeline_panel` 293, `viewport_interaction` 596 / 817); none on the root Window. The two messages come from the engine's embedded-popup show / hide on the root Window (the codebase already works around it: `viewport_interaction.gd` 849, 1046). Decided: out of scope, not a row verdict. The walker records the count (rule 71) | out of scope |

### F3. Jaw tool

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 12 | A8: no preview after click 1; a wide first jaw edited to width 20 collapses to 90° with `!`; `45` rejected; N5 / N25 / N8a knock-ons | **PRODUCT** | P6, P7. Rows A8, N5, N25, A8b, N8a | WP3 |
| 13 | DOF chip `OK` on an **empty** sketch after Ctrl+A / Delete | **PRODUCT** (small) | `run_solve` 5443 emits `solve_updated(0, …)` for an empty sketch (`dofs == 0` → `OK` in `main.gd` 1202); `refresh_dof_state` already emits `-1`. Row N25 | WP3 |

### F4. Constraint glyphs and dimension labels

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 14 | N21: badge pile-up; it also steals wall clicks (N24(e), A8b: `Constraint selected: perpendicular|coincident`) | **PRODUCT** (regression of #222) | `_glyph_block_score` rewards a centre **on** a sketch curve (+40 when none) and the offset budget is 40 px, so a vertex-rich jaw (coincident ×N, parallel, perpendicular, equal, tangent) cannot spread; a press inside any glyph rect wins over the line under it. Rows N21, N24, A8b | WP4 |
| 15 | N1a: `22.5` label ≈45 px from the head (> 40), overlaps badges | **PRODUCT** | same density; the 40 px bound was met in the #222 suite at the suite's zoom, not at a 155 px head. Row N1a | WP4 |
| 16 | N26: badges within ~40 px but stacked, cannot be attributed | **PRODUCT** | same cause. Row N26 | WP4 |
| 17 | L6: badges white-on-black, not blue; dense cluster round the r10 circle | **DESIGN** (colour) + **PRODUCT** (density, WP4) | the glyph style is white on black; red / orange = conflict. Row L6 reads: no red / orange, no live Δ labels; neutral badges are expected | row, WP4 |
| 18 | A9: orphan yellow `V` badge in empty space after `Trimmed open jaw`; jaw redrawn as a compact cluster; first Circle click only `Circle — centre set …` | **PRODUCT** (orphan) + **DESIGN** (centre-set) | the walker's plain Line is auto-constrained `vertical`; after the Trim its glyph is still drawn until the next click (static reading: the Trim path redraws at `sketch_mode.gd` 3905, the delete path of the crossed Line may not; WP4 test 4 decides). The compact jaw came from the batched / arbitrary jaw clicks (rule 61, exact points in A8). Circle: the first click only sets the centre (`CIRCLE_CENTRE_SET`); the radius is typed. Row A9 | WP4 (orphan), rows |

### F5. Sketch tools, misc

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 19 | N4: AF field holds `AF` as selected text; hexagon yellow after `Sketch saved` | **DESIGN** | the blank is the real text ` AF`, select-all so the first digit replaces it (#219); a saved sketch is drawn as a yellow pad until extruded or undone (`SketchPadOverlay`, `document_view.gd` 2432). Row N4 reads: ` AF` (may be drawn selected), never `0.01`; yellow pad expected | row |
| 20 | L12: Select hover ✕ shows `Δu 87.26` only | **DESIGN** | an axis-aligned shaft line has `dv = 0`; `measure_overlay.gd` 478 omits it. Row L12 hovers a slanted jaw wall for both | row |
| 21 | L9: the Polygon centre press does not change the status | **PRODUCT** (small) | no `*_CENTRE_SET` for Polygon. New status `Polygon — centre set, click a vertex or type the size`. Row L9 | WP9 |
| 22 | N10: the big `2` tag hides the small region | **PRODUCT** (small) | `sketch_mode.gd` 4557: tag at the region's bbox centre = the hole's centre. The `— skipped` status was a lag miss (rule 62). Row N10 | WP9 |
| 23 | N14 #225: tan hover tint stays after the pointer leaves | **PRODUCT** | static reading: `_update_hover` (`viewport_interaction.gd` 3387) returns before `clear_hover()` when a body is selected or a sketch is active, and a pointer that moves onto chrome may never reach it; WP9 step 1 reproduces. Row N14 | WP9 |

### F6. Camera

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 24 | N6: first notch after a view preset jumps; in/out not reversible; `F` and `Shift+F` both `Framed all` | **PRODUCT** (first notch) + **DESIGN** (rest) | P9. Reversibility is not a requirement (the anchor point stays under the pointer; `ZOOM_OUT_MAX_FIT_MULT` clamps). `F` frames the selection or all, `Shift+F` frames all: with the body selected they differ (`Framed selection` vs `Framed all`); with nothing selected both are `Framed all`. Row N6 selects the body first | WP7 |

### F7. Fillet edge picking

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 25 | First edge click near a vertex sometimes seeds the 13-edge top-face loop | **PRODUCT** | `_accumulate_dressup_edge` 2286: a first pick whose press is farther than 6 px (`DRESSUP_FIRST_PICK_EDGE_PX`) from every edge **and** lands on a face seeds the face loop. A walker's ±1.5 px aim error (screenshots scaled 1.5×) is enough. A pre-selected face is not consulted by this code; WP8 asserts it stays that way. Rows A11b, A11d | WP8 |
| 26 | A11b first body click → `Selected edge …`; A11d first body click dead | **DESIGN** + **PROCESS** | a click within the hover-edge slack of an edge selects that edge (status `Selected edge`); the rows say click the body ≥ 20 px from every edge. A dead click is rule 51 / 67 (copy the trace line) | rows |
| 27 | Log: `[ERROR] fillet soft-skip: missing edge uuid …` ×19 per rebuild at T14 | **PRODUCT** (log level) | `ops_dress.cpp` 656–677: each unresolved edge is logged at error level **before** the face-cue recovery re-finds it, so a recovered fillet prints 19 errors. Decided: per-edge line at `debug`; one `error` only for edges still lost after recovery | WP8 |

### F8. Hover hint timing

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 28 | N16: hint replaced the key-0 result <1 s after the pointer move; on run 2 the hint stayed after the pointer left | **PRODUCT** (stale hint, missing re-show) + **PROCESS** (timing read from screenshots) | P8. The "<1 s" came from tool-call latency: with ≥ 2.5 s between key `0` and the pointer move the hint rightly appears at once. WP5 fixes stale and missing re-show and adds `[status-trace]` timestamps. Row N16 | WP5 |
| 29 | N8b: hint ~1.5 s after `Opened …` | **PROCESS** (+ WP5 trace) | same as 28: screenshot order on a lagging box; the pointer was not on the body in the first run. Decided by `[status-trace]` timestamps. Row N8b | WP5, rule 63 |

### F9. Timeline editor

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 30 | A13b: after an Esc-cancelled edit the double-click on `extrude 2` fails twice: press 1 `drop:not-owner:@Button`, press 2 `model-click` | **PRODUCT** | press 1 selects the feature, which moves the Timeline (N23 relayout, `main.gd` 1954) so the row is no longer under the pointer for press 2; the 3rd try works because the layout has settled. WP6 freezes the Timeline position while a press on it is in flight. Row A13b | WP6 |

### F10. Files / save

| # | Item | Verdict | Reason / evidence | WP |
|---|---|---|---|---|
| 31 | Ctrl+S prints the same `Saved <path>` as the previous Save | **PROCESS** | identical text is by design; a fresh save is proven by the file's mtime (`stat`), new rule 65. No string change | rules |
| 32 | The checklist's "re-save with Ctrl+S" overwrote `pre-cut.sxp` with the cut part | **PROCESS** (checklist bug) | chunk 3 now ends with Save As `cut.sxp`; chunk-4 recovery re-enters from `cut.sxp` | checklist |

### Every non-PASS row

| Row | sx-039 | Cause | Resolution | WP / where |
|---|---|---|---|---|
| N12 | FAIL | item 5 | PRODUCT | WP2 |
| A8 | FAIL | items 12 | PRODUCT; exact jaw points + new wide-jaw row A8w | WP3, checklist |
| N5, N25 | FAIL (knock-on) | item 12, 13 | PRODUCT | WP3 |
| N21 | FAIL | item 14 | PRODUCT; new row N21b (wall clicks) | WP4 |
| L3 | FAIL | items 2 | PRODUCT | WP1, WP6 |
| A11d | FAIL | item 3 | PRODUCT | WP1 |
| N16 | FAIL | item 28 | PRODUCT + PROCESS | WP5 |
| A1 | PARTIAL | item 8 | PRODUCT | WP9 |
| N7 | PARTIAL | not measured (rule 57) | PROCESS: row asks for two measured pixel colours (lit vs hovered) | row |
| A3 | PARTIAL | item 1 | PRODUCT | WP1 |
| L6 | PARTIAL | items 17 | DESIGN wording + WP4 density | row, WP4 |
| A7 | PARTIAL | item 6 | DESIGN; how-to (rule 66) | row |
| N4 | PARTIAL | item 19 | DESIGN wording | row |
| A8b | PARTIAL | item 14 | PRODUCT | WP4 |
| N8a | PARTIAL | carries A8's `!` | resolved by WP3 | WP3 |
| A9 | PARTIAL | item 18 | PRODUCT (orphan) + DESIGN | WP4, row |
| N1a | PARTIAL | item 15 | PRODUCT | WP4 |
| N26 | PARTIAL | item 16 | PRODUCT | WP4 |
| L12 | PARTIAL | items 20 + row steps | DESIGN wording (hover a slanted wall for Δv); second-line pick given exact placement | row |
| N24 | PARTIAL | item 14 (e); box colours unmeasured | PRODUCT (WP4); row asks for two pixel colours | WP4, row |
| N1b | PARTIAL | eye-check only | PROCESS: row lists labels and the distances | row |
| N6 | PARTIAL | item 24 | PRODUCT (first notch) + DESIGN | WP7 |
| N10 | PARTIAL | item 22 | PRODUCT (tag) + PROCESS (lag) | WP9, rule 62 |
| A11b | PARTIAL | items 25, 26 | PRODUCT (first pick) + DESIGN | WP8 |
| A13b | PARTIAL | item 30 | PRODUCT | WP6 |
| N8b | PARTIAL | item 29 | PROCESS + trace | WP5 |
| N14 | PARTIAL | items 10, 23 | PRODUCT (tint) + trace (dropdown); refusal text must be quoted | WP9 |
| L9 | PASS (note: centre press has no feedback) | item 21 | PRODUCT (small) | WP9 |

The other 41 rows stay as in sx-039 and are re-walked in sx-040 because the rows they share state with are re-walked.

## Decisions (final — BUILD agents do not choose)

1. **Scope and shape.** Nine WPs, **sequential, for one grok-4.7 agent in one PR**, in the order below (regressions first). No new behaviour beyond what a WP names. If a WP's own suite is red, fix it before starting the next WP; the full tier runs after WP4, WP8 and at the integration step.
2. **Key delivery (WP1).** A key press is accepted when it is not an echo, **or** when it is a *burst echo*: same keycode as the previous press the app accepted, ≤ `ECHO_BURST_MSEC = 80` ms after it, and that previous press was itself accepted. A real auto-repeat (first echo ≥ 250 ms after the press) is never accepted, so holding a key does not run away; only digits, `.`, `,`, `-`, `+` and the tool letters (`L D T C S`) use the burst rule; Enter, Esc, Tab, arrows, Delete and any Ctrl / Alt / Meta combination never accept an echo. One helper `SxUi.press_accepted(event) -> bool` (memoised per `event.get_instance_id()` because several `_input` handlers see the same event) replaces `not event.echo` at every key-typing site listed in P1.
3. **Typed text wins (WP1).** Any write scheduled by a focus-entry, claim or reveal path (`_write_strip_radius(model, true)`, `reveal_committed_spin`, `arm_replace_on_focus`'s select-all, `_reassert_empty_dim`, the panel and Distance equivalents) captures a per-line type counter when it is scheduled and does nothing if the counter changed (a character was typed) before it runs. Keys that arrive before the line owns focus are routed to it, not to the viewport.
4. **Shield (WP2).** The Extrude shield is disarmed only by a left press that reaches the canvas (`model-click`, a sketch click), by a press on a part chip, or by a new sketch / tool start. A press on the menu bar, a menu popup, the status bar or any other chrome never disarms it. The chip row's y and the shield rect are read after the post-Extrude layout has settled and are not recomputed on disarm.
5. **Jaw (WP3).** `set_dimension_value` for a jaw (and a Rect) distance or angle applies the edit in steps of at most 25 % of the current value (continuation), re-solving after each, and **restores the pre-edit snapshot** if any step fails (status `Dimension rejected — constraints could not be satisfied`, DOF chip as before). A failed edit never leaves `!`. The jaw preview draws from click 1 with a minimum half-length of 1.5 mm and half-width of 1.5 mm, and never calls `surface_end` with zero vertices. `run_solve` emits `-1` (`—`) for an empty sketch.
6. **Glyph density (WP4).** (a) **Coincident** glyphs are drawn only for the selected entities' vertices, for the vertex under the pointer (≤ 14 px) and for a selected coincident constraint; every other type is drawn always. (b) A glyph's rect must not cover any sketch-curve point except at its own anchor: the placement score penalises a rect that intersects a curve (replacing the +40 that rewards sitting on one) and keeps the ≤ 40 px offset bound. (c) The orphan rule: after every redraw each glyph's constraint exists in the sketch. (d) A press selects the glyph only if it is inside the glyph rect; geometry wins elsewhere. The `22.5` callout stays ≤ 40 px from the head arc **measured to the label's nearest edge**.
7. **Hint model (WP5).** `main.gd` keeps `_current_hint` (the last non-empty hover hint while the pointer is on a target). A result holds 2.5 s; when the hold ends and `_current_hint != ""` the label shows it again without any pointer motion. `_on_hover_hint("")` clears `_current_hint`, and if the label currently shows that hint it returns to the idle text (the start-up string). Time comes from `main._now_msec()` (overridable in tests); the flush is polled from `_process`, not a `SceneTreeTimer`. With `SX_INPUT_TRACE=1` every label write prints `[status-trace] t=<unix seconds, 3 decimals> kind=<result|hint|restore|idle> text=<label text>`.
8. **Timeline guard (WP6).** The Timeline does not change position while the left button is down on it or for `TIMELINE_RELAYOUT_GUARD_MSEC = 600` ms after the last press on it; the relayout (N23 rule: 8 px under the chip row when a body is selected) is applied after the guard. N23's rule itself is unchanged.
9. **Camera (WP7).** A wheel / pinch zoom while a view tween is running first finishes the tween (pose = target) and then computes the anchor.
10. **Fillet first pick (WP8).** `DRESSUP_FIRST_PICK_EDGE_PX` goes from 6 to 12. A first-pick press farther than 12 px from every edge and on a face seeds the face loop, as today; nearer than 12 px picks a single edge (the status names it). A selected face never joins the edge set. Kernel: unresolved-edge lines go to `sx::log::debug`; `error` only for edges still lost after the face-cue recovery.
11. **Small items (WP9).** Snap / Infer checkboxes read `Snap` / `Infer` (the rail width does not change); Polygon centre status `Polygon — centre set, click a vertex or type the size`; contour tag anchored on the region's own fill, ≥ 4 px clear of every hole outline; hover tint cleared on any pointer motion that leaves the part (including onto chrome); rail highlight re-synced after sketch undo / redo; `[popup-trace] t=… show|hide <node name>` for every `PopupMenu`.
12. **Traces (WP1, WP5, WP9).** All additions are printed with `printerr` only when `SX_INPUT_TRACE=1` (same gate as `[input-trace]`; no behaviour change when unset): `[key-trace] t=<unix> key=<keycode name> unicode=<n> pressed=<0|1> echo=<0|1> accepted=<0|1> focus=<node path>`, `[status-trace]`, `[popup-trace]`. Time is `Time.get_unix_time_from_system()` so it compares directly with `date +%s.%N`.
13. **Design confirmations (no product change).** Rail Sketch is hidden while a body / face is selected (use Esc to clear, or the inspector pencil); two-stage pick; badge colours (white on black); Δv only for non-axis-aligned entities; ` AF` blank text; yellow sketch pad after `Sketch saved`; Ctrl+S text identical to Save; `F` / `Shift+F`; zoom in / out not required to be reversible; the engine log lines of F2 item 11.
14. **Checklist = process.** 72 rows (69 + A8w, N21b, A11f), rules 61–71, chunk 3 ends with Save As `cut.sxp`, exact jaw points, timestamps for timing rows, explicit pointer placement.
15. **PR rules for the BUILD PR.** Repo `github.com/solidexpress/solidexpress` only; start from `main`; ready (not draft); never self-merge; quick CI (linux kernel, godot-smoke, website-demos) green; do not wait for `windows-export` / `macos-kernel` (~2 h); **do not edit `docs/plan/STATUS.md`** (notes go in the PR body); reproduce first (each WP's step 1); new tests follow `.cursor/rules/gdscript-click-driven-tests.mdc` (visible controls and real `InputEvent`s) and pass `tools/lint_rung01_e2e.py` (no `.text =` / `.value =` assignments, no `interaction._input`, no `text_submitted.emit`, no direct camera yaw / pitch writes, no await between a press and its release).

## Work packages

Order is fixed. Each WP: **items** (F-numbers above, sx-039 rows), **root cause** (verified in code or by probe), **files**, **tests** (suite file + `packaging/ci/suites.d/<name>.suite`, what each check asserts), **acceptance**. Every new suite's `.suite` manifest is `script=tests/run_rung01_replan19_<name>.gd`, `tier=ci` (WP1, WP2, WP3, WP5) or `tier=full` (WP4, WP6, WP7, WP8, WP9), `timeout=120` (240 for WP4 and WP8). Suite names are `rung01_replan19_<name>`. The status strings quoted in acceptance are exact.

### WP1 — Keys: burst echo, same-frame focus, traces (#217 regression)

**Items:** F1 1, 2, 3 (rows A3, L3, A11d; re-verifies L10, A8, A9, N18). **Rows unblocked:** A3, L3, A11d.

**Root cause.** (a) P1: on real X11 the second identical press of a burst is `echo=true` and every typing site drops echo (`viewport_interaction.gd` 426, 647, 893, 1009, 2128, 2767, 5616, 5650, 5678, 5698, 5723, 5777, 5944, 5976, 5991; `sketch_context_chrome.gd` 1465, 1524; `ops_panel.gd` 285; `main.gd` 4248). (b) P3: `strip_le.focus_entered` (`viewport_interaction.gd` 596–611) calls `_write_strip_radius(model, true)` and `SxUi.arm_replace_on_focus` (`ui_spin.gd` 282) schedules a select-all; `SxUi.reveal_committed_spin` (`ui_spin.gd` 52, called deferred from `viewport_interaction.gd` 586, 627 and 634) rewrites the committed text; the panel Radius and the Distance field have the same pattern (`ops_panel.gd` 266 `radius_le.focus_entered`). When click and keys share a frame these deferred writes run **after** the typed characters and restore the model text or select-all over them.

**Files:** `game/scripts/ui_spin.gd` (new `press_accepted`, `ECHO_BURST_MSEC`, per-line `_sx_type_gen` bumped by `write_typed_text` / `compose_typed_char`, checked in `reveal_committed_spin`, `arm_replace_on_focus`'s deferred select-all, `release_line_now`), `game/scripts/viewport_interaction.gd` (every site above; strip `focus_entered` write guarded by the counter; `_consume_numeric_select_all` 6030 and `_promote_visible_numeric_line` 6060 route a key that arrives before focus to the field), `game/scripts/sketch_context_chrome.gd`, `game/scripts/ops_panel.gd`, `game/scripts/main.gd` 4248 (only if it types), `[key-trace]` printed from `viewport_interaction._input`'s first lines (one line per `InputEventKey` press).

**Tests.** New `game/tests/run_rung01_replan19_keys.gd` (`rung01_replan19_keys.suite`, tier=ci), booting a fresh `main` per case (never reuse an app between trials), all events via `Viewport.push_input` with **no await between events of one burst** and a 10 ms-equivalent gap = same frame:
1. *Echo burst*: for each of `22.5`, `200`, `1.5`, `45`, `2.5`, `10`, `100`: push the digit keys exactly as X11 delivers them (press, **press with `echo=true`**, release, …: the second and later identical digits are echo presses and the first release is missing) into (i) the Circle Radius blank after a centre click, (ii) strip R, (iii) panel Radius, (iv) finish-bar Distance, (v) the in-viewport dimension label editor, (vi) the Slot c-c blank. Assert the field text equals the typed string exactly, then Enter commits it (status `Circle r=22.5000 (Ø45.0000)` for (i) `22.5`; `Slot c-c 150.0000 R5.0000 — typed` for `150`).
2. *Real repeat is not typed*: press `5` (non-echo), then one echo press 400 ms later (fake clock via `SxUi._now_msec` override) and then echo presses every 30 ms: the field gets exactly one `5`.
3. *Same-frame focus (the P3 matrix)*: for strip R and panel Radius and Distance: (a) click, Ctrl+A (press / release) and the burst `1.5`, `22.5`, `10` pushed in one frame → after 3 frames the field text is the typed string and the model value equals it; (b) click and the burst only (no Ctrl+A); (c) burst then Enter then key `3` in the same frame → focus owner is `Interaction` and the status is `Top view`; (d) Ctrl+A then `1` then Enter then `3`, each a separate frame (the A11d sequence) → `Top view`, strip text `1 mm`.
4. *Keys before focus*: push the click and `1` in the same frame with the viewport as focus owner → the `1` never produces a `Front view` status (it goes to the field).
5. *Trace*: with `SX_INPUT_TRACE` unset nothing is printed (`OS.get_environment` stubbed through a `SxUi.trace_enabled()` helper the test flips); with it set each press prints one `[key-trace]` line with `echo=` and `accepted=` fields.
6. *No regression*: `run_rung01_sx038_focuskeys` (109 checks) and `run_rung01_replan14_undo` (119 checks) stay `0 failures`.

**Acceptance.** `rung01_replan19_keys` `<n> checks, 0 failures` (n ≥ 90); on the BUILD box with `DISPLAY=:1` the real-X11 recipe (`xdotool type --delay 10 22.5` and `200` into the focused Circle Radius blank, 10 trials each) reads `22.5` / `200` 10 of 10; statuses exactly `Circle r=22.5000 (Ø45.0000)`, `Fillet r=1.50 — edit Radius, click edges, Enter`, `Top view`; `run_rung01_sx038_focuskeys`, `run_rung01_replan14_undo`, `run_rung01_replan16_n2`, `run_rung01_replan16_fields`, `run_rung01_replan15_armedkeys` green.

### WP2 — Shield: Extrude → menu → second click (#218 regression)

**Items:** F2 5 (row N12). **Rows unblocked:** N12.

**Root cause (P5).** `_note_finish_press_outside` (`viewport_interaction.gd` 6911) disarms the shield for any left press that is not on the Extrude rect or the chip row; a File / View menu press qualifies. `_finish_click_strip_y` (6968) pushes the chip row below the Extrude rect only while the shield is armed, so disarming moves the row from y 83 to y 48, onto the Extrude pixel; the next press there is `drop:over-chrome:SelectionStrip`, and it reaches whichever chip is now under it (`Hide` in the walk, `Chamfer` in the probe).

**Files:** `game/scripts/viewport_interaction.gd` (`_note_finish_press_outside`: only a press that returns `model-click`/sketch, a part chip press, or `_on_sketch_rail_tool` / sketch start disarms; menu bar, popup, status bar and other chrome are ignored; `_layout_selection_strip` computes the final y once after the post-Extrude layout), `game/scripts/main.gd` `_on_sketch_rail_tool` (~1688) unchanged semantics.

**Tests.** New `game/tests/run_rung01_replan19_shield.gd` (`rung01_replan19_shield.suite`, tier=ci), extending the pattern of `run_rung01_sx038_extrude_dblclick.gd` (`_extrude_ready`, `_press_release`): Circle sketch → Extrude by clicking the real button, then
1. read the chip-row top y and the Extrude pixel; press the **File** menu-bar button (real press / release), press Esc (menu closes); read y again → equal (±1 px) to the first reading and **not** within the Extrude pixel's column / row;
2. press the same Extrude pixel → `last_click_disposition == "drop:shield"`, feature count unchanged (`sketch`, `extrude`), no status containing `hidden`, no `Chamfer` / `Fillet` status;
3. same with the **View** menu and with a HUD **View ▼** open / close;
4. move the pointer to the `Fillet` chip and press → status begins `Fillet r=` (a motion onto another chip is a new gesture; the shield ends);
5. a canvas press (empty ground) ends the shield: the next press at the old Extrude pixel is a normal canvas click (`model-click`).

**Acceptance.** `rung01_replan19_shield` `<n> checks, 0 failures` (n ≥ 30); `run_rung01_sx038_extrude_dblclick` still green; on the BUILD box (real X11, SX_INPUT_TRACE=1) Extrude → File menu open / Esc → second click on the Extrude pixel prints `[input-trace] press (x,y) drop:shield` and the Timeline shows `sketch 1`, `extrude 2` only.

### WP3 — Jaw: wide-jaw dimensioning, preview, empty-sketch DOF (A8)

**Items:** F3 12, 13 (rows A8, N5, N25, A8b, N8a). **Rows unblocked:** A8, N5, N25, N8a; new A8w.

**Root cause (P6, P7).** A jaw built with `hw ≥ 2·hl` (`hl=20, hw=48.4` committed as `Jaw committed — width 96.8000, long side 5.0°`; width → 20 asks the solver for a 79 % one-shot change of the distance dimension of a quad whose angle dimension is on the *shorter* pair of sides) lands on another solver branch: with snap off `set_dimension_value` (`sketch_mode.gd` 6279) returns `failed` and leaves the DOF chip `!`; with the long side snapped to 0° it returns success but the included angle comes out 90° and the later `45` is `failed` (`Dimension rejected — constraints could not be satisfied`). The same code path with `hw ≤ 1.2·hl` works. `_update_preview` (8618) → `_append_jaw_preview` (8527) draws nothing (and calls `surface_end` with no vertices, `ERROR: No vertices were added`, line 8702) when the pointer is within ~20 mm of the centre, which is exactly where click 1 leaves it. `run_solve` (5443) has no empty-sketch guard.

**Files:** `game/scripts/sketch_mode.gd` (`set_dimension_value`: continuation in ≤ 25 % steps per solve, restore snapshot on failure; `_append_jaw_preview` minimum 1.5 mm half-length / half-width, skip `surface_end` when empty; `run_solve` emits `solve_updated(-1, "", 0)` when `sketch.entity_ids().is_empty()`), `game/scripts/main.gd` (no change expected).

**Tests.** New `game/tests/run_rung01_replan19_jaw.gd` (`rung01_replan19_jaw.suite`, tier=ci), using the `_click_uv` helper of `run_rung01_replan17_dof.gd`:
1. *Wide jaw (the walk)*: Jaw tool, click 1 at the origin, click 2 at 20 mm along +x (5° off), click 3 at 48.4 mm half-width → `Jaw committed — width 96.8000, long side 5.0° — click a label to edit it`; click the first glyph of the width label, type `20` Enter → `Dimension updated`, DOF chip not `!`, the four jaw lines have lengths 40 ± 0.05 and 20 ± 0.05 and the included angle between the long sides is 0° ± 0.05; angle label → `45` Enter → `Dimension updated`, walls at 45° ± 0.05, included angle 90° ± 0.05 between the two walls, DOF chip not `!`. Repeat with snap on and off, and with `hl` = 5, 20, 40 and `hw` = 10, 48.4, 70.
2. *Atomic failure*: set width to an unsatisfiable value (e.g. angle `0` on a closed jaw with an equal constraint) → status `Dimension rejected — constraints could not be satisfied`, entity geometry and DOF chip text identical to before (snapshot string equal), no `!`.
3. *Undo / redo*: Ctrl+Z ×n to `Nothing to undo`, DOF `—`; Ctrl+Shift+Z back; DOF text equals the pre-undo text, never `!`.
4. *Preview*: after click 1 with the pointer still on the centre the preview mesh has ≥ 8 vertices (a 4-edge rectangle); with the pointer at 0.5, 5, 20, 60 mm the vertex count is ≥ 8; no engine `ERROR` is raised (`push_error` hook count 0).
5. *Empty DOF*: draw a Line, Ctrl+A, Delete → DOF chip `—` (never `OK`).

**Acceptance.** `rung01_replan19_jaw` `<n> checks, 0 failures` (n ≥ 60); statuses exactly `Jaw committed — width 96.8000, long side 5.0° — click a label to edit it`, `Dimension updated` ×2; `run_rung01_replan17_dof`, `run_rung01_replan10_*jaw*` and the wrench walk (`run_rung01_wrench.gd`, ≥ 729 checks) green.

### WP4 — Glyph density (#222 regression)

**Items:** F4 14–18 (rows N21, N21b, N26, N1a, N24(e), A8b, A9, L6). **Rows unblocked:** N21, N26, N1a, N24, A8b, A9.

**Root cause.** `_glyph_block_score` (`sketch_mode.gd` 7819) hard-limits glyph-on-glyph overlap (> 16 %) but adds +40 when a glyph centre is **not** on a sketch curve, so badges are pulled onto the walls; with the 40 px offset bound (`GLYPH_MAX_OFFSET_PX`) a jaw plus pivot plus head carries ~20 constraints (coincident at every vertex, parallel, perpendicular, equal, tangent, H / V), which cannot spread. Presses inside a glyph rect select the constraint (`Constraint selected: …`), so a badge on a wall steals wall clicks (A8b, N24(e)). The orphan `V`: a plain Line drawn across the head is auto-constrained `vertical`; after Power Trim removes it its glyph anchor is not rebuilt until a later click (`_rebuild_constraint_glyphs` 8021; the Trim path calls `_redraw()` at 3905 but the delete path of the crossed Line may not).

**Files:** `game/scripts/sketch_mode.gd` (`_rebuild_constraint_glyphs`: coincident only for selected / hovered vertices; `_glyph_block_score`: replace the +40 on-curve reward by a penalty for a rect that intersects a curve away from its own anchor; `_separate_glyph_screen`; rebuild glyphs after every delete / trim / undo; `_select_at` 2465 glyph hit-test = inside the rect only), `game/scripts/viewport_interaction.gd` (hover vertex for coincident: reuse the existing sketch hover), label placement of the head radius callout measured to the label's nearest edge.

**Tests.** New `game/tests/run_rung01_replan19_glyphs.gd` (`rung01_replan19_glyphs.suite`, tier=full). Build the **walk's sketch** with real clicks (not the replan17_n21 sketch): Circle r10 at the origin, Circle r22.5 at (200, 0), the two shaft lines, a jaw with the exact points of row A8 edited to 20 / 45°, a plain Line across the head, Power Trim; zoom with the real wheel until the head circle is **150 ± 8 px** across (`camera` wheel events, not yaw / pitch writes):
1. every drawn glyph's rect is ≥ 60 % visible (not covered by a later glyph); glyph rects ≤ 40 px from their anchor; none below the shaft's lower edge;
2. for each jaw wall and each shaft line: presses at 25 %, 50 %, 75 % of its length (skipping points inside a grown glyph rect) select the wall: `Selected 1 sketch entity`; none prints `Constraint selected`;
3. a press at the centre of each non-coincident glyph prints `Constraint selected: <type> — Del removes it` with that glyph's type; coincident glyphs are absent until a vertex is hovered (pointer ≤ 14 px) or an entity is selected; then pressing the badge prints `Constraint selected: coincident — Del removes it`;
4. after the Trim: no glyph anchor refers to a missing constraint; the count of glyph rects equals the count of drawn constraints (`constraint_glyph_screen_rects()`); no `V` badge outside ≤ 40 px of an entity;
5. the `22.5` and `5` labels: nearest edge ≤ 40 px from the head arc (for `22.5`), ≥ 4 px from every glyph rect and from the other labels; the first glyph of `20` and `45°` opens the editor on the first click;
6. Select-tool drag box rows of N24 (a)–(g) still pass (the existing `run_rung01_replan17_selectbox`).

**Acceptance.** `rung01_replan19_glyphs` `<n> checks, 0 failures` (n ≥ 80); the stale expectations in `run_rung01_replan17_n21`, `run_rung01_replan14_*` glyph checks and any film test that counted coincident glyphs are updated to decision 6 (list each in the PR body); **full tier run after this WP**: `suites: <n> run, 0 failed`.

### WP5 — Hint / result timing and traces (r17-WP4 regression)

**Items:** F8 28, 29 (rows N16, N8b). **Rows unblocked:** N16, N8b.

**Root cause (P8).** `main.gd` `_on_hover_hint` (2632) only queues a hint that arrives during the hold; nothing remembers a hint shown **before** the result, and `viewport_interaction._update_hover` (3387) emits only when the hover key changes (`_last_hover_key`, 3427–3430), so with a still pointer nothing re-emits it. `_on_hover_hint("")` clears `_held_hint` but does not touch a label that already shows the hint (stale). The flush uses a `SceneTreeTimer` (`_arm_hint_flush` 2648), which a test cannot drive with a fake clock.

**Files:** `game/scripts/main.gd` (`_current_hint`, `_now_msec()`, `_hint_tick()` called from `_process`, idle text constant from the start-up string at 835, `[status-trace]` in a single `_set_status_label(text, kind)`), `game/scripts/viewport_interaction.gd` (no change expected except `hover_hint` on pointer leave).

**Tests.** New `game/tests/run_rung01_replan19_hint.gd` (`rung01_replan19_hint.suite`, tier=ci), driving real mouse motion over the body and real key `0` presses with `main._clock_override_msec` set by the test (no real sleeping):
1. pointer on a face → label is the face hint; press `0` → `No view for key 0 — use 1 2 3 4 6 7 8`; clock +2.4 s → still the result; clock +2.6 s (`_hint_tick()`) → the hint is back **without any pointer event**;
2. result first, then the pointer moves onto the face during the hold → the hint is written at hold end (not before: at +2.4 s the label is still the result);
3. pointer moves off the body (empty ground) during the hold → at +3 s the label is the result or the idle text, **never the hint**; moving off after the hint is shown → the label returns to the idle text at once (`[status-trace] kind=idle`);
4. `Opened …` path: `_on_status("Opened /x/blank.sxp")` then the same checks;
5. trace lines: with tracing on each label write prints `[status-trace] t=… kind=… text=…`; the result → hint gap in the trace is ≥ 2.5 s with the fake clock.

**Acceptance.** `rung01_replan19_hint` `<n> checks, 0 failures` (n ≥ 30); statuses exactly `No view for key 0 — use 1 2 3 4 6 7 8` and `Face — click selects body first, click again for face · then Pull arrow`; the existing `run_rung01_replan17_*` hold suite stays green.

### WP6 — Timeline: double-click leak and relayout under the pointer (#224)

**Items:** F9 30, F1 2 (the panel relayout half) (rows A13b, L3). **Rows unblocked:** A13b.

**Root cause.** `_make_row` (`timeline_panel.gd` 263–316): press 1 on a row name button triggers `_select_feature(fid)` (and focus handling, 293); selecting a feature changes the part selection, and `main.gd` `_update_panel_visibility` (1954) / the N23 rule moves the Timeline below the chip row, so press 2 of the double-click (the one that carries `double_click`, 308) lands where the row used to be: `model-click`. After a second settle the third try works. The same relayout moves the Modify panel under a click in L3.

**Files:** `game/scripts/main.gd` (`TIMELINE_RELAYOUT_GUARD_MSEC`, defer Timeline / Modify panel relayout while the left button is down on either or within the guard), `game/scripts/timeline_panel.gd` (press timestamp), `game/scripts/viewport_interaction.gd` (`_input` ignores presses that were over the Timeline at press time, for the matching release).

**Tests.** New `game/tests/run_rung01_replan19_timeline.gd` (`rung01_replan19_timeline.suite`, tier=full): wrench-like doc (sketch, extrude, fillet); open the Distance editor by real double-click on the `extrude` row name, Esc (`Edits cancelled`), then:
1. real double-click again with 80 ms between the presses (in fake time): both presses are `drop:not-owner:*` (never `model-click`); the Distance field is focused with its text selected; repeat 5 times, with the body selected and not selected beforehand;
2. Timeline top y read before press 1 and after press 2 is equal (±1) and moves only after the guard (+600 ms) to the N23 position;
3. the Modify panel Radius row: with Fillet armed click the panel Radius field twice in 0.3 s (the L3 second click): never `Selected face`, focus stays in the field;
4. N23: after the guard the Timeline is ≥ 4 px under the chip row with the body selected and back at the top when nothing is selected (existing `run_rung01_sx038_chrome`).

**Acceptance.** `rung01_replan19_timeline` `<n> checks, 0 failures` (n ≥ 40); `run_rung01_sx038_a13`, `run_rung01_sx038_chrome` green.

### WP7 — Camera: first wheel notch during a view tween

**Items:** F6 24 (row N6). **Rows unblocked:** N6.

**Root cause (P9).** `apply_standard_view_id` (`orbit_camera.gd` 677) starts `_animate_pose` (740); a wheel notch during the tween calls `zoom_at` (561) → `_zoom_anchor` (591) which solves the anchor against the mid-tween pose; the tween then continues to its original target, so the point under the pointer moves by 9.8–42.7 px (0.0 after the tween).

**Files:** `game/scripts/orbit_camera.gd` (`zoom_at`, pinch path: `_finish_pose_tween()` first).

**Tests.** New `game/tests/run_rung01_replan19_camera.gd` (`rung01_replan19_camera.suite`, tier=full): a body, key `3`, then a real `InputEventMouseButton` wheel-up with the pointer on the body **in the same frame** and again after 2 s: the screen position of a model point under the pointer changes by ≤ 2 px in both cases and for notches 1–3; wheel-out ×3 keeps the point within ±2 px; `F` with the body selected → `Framed selection`, with nothing selected `Framed all`; `Shift+F` → `Framed all`; HUD Frame equals `Shift+F`.

**Acceptance.** `rung01_replan19_camera` `<n> checks, 0 failures` (n ≥ 25); `run_rung01_replan14_camera` and the replan16 camera suites green.

### WP8 — Fillet first pick and kernel log

**Items:** F7 25, 26, 27 (rows A11b, A11d, N3; new A11f). **Rows unblocked:** A11b, A11d.

**Root cause.** `ops_panel.gd` `_accumulate_dressup_edge` (2286): `first_pick` with a press > 6 px from every edge and a face under it → `_add_dressup_face` (2502): the face loop (`Fillet: 13 edge(s) — 179.8 mm line, 31.4 mm arc, 32.3 mm arc, … 150.0 mm line`). 6 px is inside the walker's ±1.5 px aim error at 1.5× scaling plus a corner seen end-on in Top view. The kernel soft-skip lines come from `resolve_dressup_edges` (`sxkernel/src/features/ops_dress.cpp` 656–677) logging every unresolved edge before the face-cue recovery.

**Files:** `game/scripts/ops_panel.gd` (`DRESSUP_FIRST_PICK_EDGE_PX` 12; `_dressup_pick_status` 2486 keeps its strings; a selected face / `view.selected_face` is never read), `sxkernel/src/features/ops_dress.cpp` (per-edge `sx::log::debug`, one `sx::log::error` for `out.lost > 0` after recovery).

**Tests.** New `game/tests/run_rung01_replan19_fillet_pick.gd` (`rung01_replan19_fillet_pick.suite`, tier=full): wrench body (use the wrench walk's builder), Fillet armed:
1. presses at 2, 5, 8, 11 px from the neck vertical in Top view → status begins `Fillet: 1 edge(s) —` (never `13 edge(s)`), and at 14, 20, 30 px from every edge inside the top face → `Fillet: <n> edge(s)` with n ≥ 6 and no `0.0 mm line`;
2. with a face pre-selected (`view.select_entity`-equivalent through a real click on it) the first corner press gives the same result as without;
3. rebuild at T14 through the Timeline Distance editor (Enter `14`) → the document's warnings contain no `edges lost on rebuild`; the kernel suite (`make test-kernel`) adds a Catch2 case: a fillet whose edge uuids are stale but whose `face_cues` match writes **no** error line to the `sx::log::set_file_sink` file (`sxkernel/tests/test_dress.cpp`) and writes exactly one when an edge is truly lost.

**Acceptance.** `rung01_replan19_fillet_pick` `<n> checks, 0 failures` (n ≥ 40); `make test-kernel` passes; `run_rung01_replan15_*` fillet suites updated only where they encoded the 6 px band (list in the PR body); **full tier run after this WP**.

### WP9 — Small UI items (A1, A17, L9, N10, N14, traces)

**Items:** F2 8, 9, 10; F5 21, 22, 23 (rows A1, A17, L9, N10, N14, N25's empty-sketch half). **Rows unblocked:** A1, A17, L9, N10, N14.

**Root cause.** See the triage (F2 8, 9, 10; F5 21, 22, 23).

**Files:** `game/scripts/main.gd` (Snap / Infer `text`, rail highlight re-sync from the undo / redo handler, `[popup-trace]` on every `PopupMenu` via `about_to_popup` / `popup_hide`), `game/scripts/sketch_mode.gd` (`POLYGON_CENTRE_SET`, emitted when the Polygon centre is appended; `_contour_tag` anchor), `game/scripts/viewport_interaction.gd` (`_update_hover`: `view.clear_hover()` when the pointer is over chrome or the viewport loses the pointer, including with a selected body), `game/scripts/document_view.gd` if `clear_hover` needs a re-tint.

**Tests.** New `game/tests/run_rung01_replan19_polish.gd` (`rung01_replan19_polish.suite`, tier=full):
1. rail rect width unchanged (±1 px) with the new `Snap` / `Infer` texts; the 19 rail labels still fully visible at 1280×800; the checkboxes' text is `Snap` / `Infer`;
2. after Ctrl+Z and Ctrl+Shift+Z in a sketch exactly one rail button is lit and it is the active tool's;
3. Polygon (across flats) centre press → status exactly `Polygon — centre set, click a vertex or type the size`; hover → `Polygon AF <size> — flats horizontal — click to place (or type the size)`; AF blank ` AF`;
4. two closed regions with a hole: the `2` tag's screen rect is ≥ 4 px clear of every hole outline;
5. pointer over the part (tint: `view.hovered_face != ""`), then real motion onto the menu bar / a panel / empty ground → `hovered_face == ""` and the face material is the untinted one, with a body selected and with nothing selected;
6. `[popup-trace]` prints `show` / `hide` lines for the File menu with tracing on.

**Acceptance.** `rung01_replan19_polish` `<n> checks, 0 failures` (n ≥ 40); statuses exactly as above; `run_rung01_sx038_polypress`, `run_rung01_replan16_*` UI suites green.

### Integration step (after WP9, same PR)

1. `make build`; `make test` (kernel Catch2 + all headless suites).
2. `KEEP_GOING=1 make test-godot` → `suites: 191 run, 0 failed` (182 + 9 new); `make test-godot-known-red` unchanged (4).
3. `python3 tools/lint_suites.py` → `lint_suites: 195 suites ok (52 ci, 139 full, 4 known-red)`; `python3 tools/lint_rung01_e2e.py` → replan16 / 17 / 18 clean as before and **`9 replan19 scripts are clean`**.
4. Wrench walk and replan walks: `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` → `0 failures` (≥ 729 checks); `run_rung01_replan16_walk.gd`, `run_rung01_replan17_walk.gd`, `run_rung01_replan18_polyaf.gd` → `0 failures`, `WALK-SUMMARY stages=8 first_red=none` where printed.
5. Real-X11 smoke on the BUILD box (`DISPLAY=:1`, `SX_INPUT_TRACE=1`): the WP1 `xdotool` recipe and the WP2 Extrude → File menu → second click recipe, both with the output pasted in the PR body.
6. PR description lists: every stale test expectation changed (WP4, WP8), the traces added, and the exact suite counts above.

## Whole-suite table

Baseline `main` `7062ffb`: `suites: 182 run, 0 failed` (full tier = `tier=ci` 48 + `tier=full` 134; plus 4 `known-red`; `lint_suites: 186 suites ok`). Target after WP1–WP9: **`suites: 191 run, 0 failed`**, `lint_suites: 195 suites ok (52 ci, 139 full, 4 known-red)`.

| Suite | Baseline | WP | Tier | After |
|---|---|---|---|---|
| `rung01_replan19_keys` (new) | — | WP1 | ci | `<n> checks, 0 failures`, n ≥ 90 |
| `rung01_replan19_shield` (new) | — | WP2 | ci | n ≥ 30 |
| `rung01_replan19_jaw` (new) | — | WP3 | ci | n ≥ 60 |
| `rung01_replan19_glyphs` (new) | — | WP4 | full | n ≥ 80 |
| `rung01_replan19_hint` (new) | — | WP5 | ci | n ≥ 30 |
| `rung01_replan19_timeline` (new) | — | WP6 | full | n ≥ 40 |
| `rung01_replan19_camera` (new) | — | WP7 | full | n ≥ 25 |
| `rung01_replan19_fillet_pick` (new) | — | WP8 | full | n ≥ 40 |
| `rung01_replan19_polish` (new) | — | WP9 | full | n ≥ 40 |
| `run_rung01_sx038_focuskeys` | `109 checks, 0 failures` | WP1 | ci | `109 checks, 0 failures` |
| `run_rung01_replan14_undo` | `119 checks, 0 failures` | WP1 | full | `119 checks, 0 failures` |
| `run_rung01_sx038_extrude_dblclick` | green | WP2 | ci | green |
| `run_rung01_replan17_dof`, wrench walk | green (≥ 729 checks) | WP3 | | green |
| `run_rung01_replan17_n21`, `replan14_*` glyph checks, glyph films | green | WP4 | | updated to decision 6 only where they counted coincident glyphs; green |
| `run_rung01_replan15_*` fillet suites | green | WP8 | | updated only where they encoded the 6 px band; green |
| every other suite | green | | | green |

The new `.suite` files are the only edits under `packaging/ci/suites.d/`. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe.


---

## sx-040

The checklist is **embedded below** (it is the walker's only input besides the soft-GL rules). **72 rows in 6 chunks** (the 69 of sx-039 plus three new: A8w, N21b, A11f), each chunk continuing from the previous one's app state, with an explicit **re-verify map** (row ↔ WP), exact jaw click points, timestamps for timing rows, and the soft-GL protocol. Walk it on the Linux build from the rolling `linux-test-build` prerelease whose `BUILDINFO.txt` `commit=` is the full sha of `main` after the BUILD PR of this plan is merged, at a **1280×800 physical screen** if possible (if not, rule 54), with `SX_INPUT_TRACE=1` and its stderr in `$OUT/input-trace.log` (`[input-trace]`, `[key-trace]`, `[status-trace]`, `[popup-trace]` lines all land there).

### Chunks

| Chunk | Rows | Starts in | Ends in |
|---|---|---|---|
| 1 | N22 A1 A2 N7 L1 A3 L5 A4 L6 L10 A5 N12 A5b L8 L11 N17 (16) | Fresh app (window read first), File → New, ground sketch | Part mode, blank (Ø45 head + Ø20 pivot, 10 thick) exported and saved as `blank.sxp`, nothing selected, no menu open |
| 2 | A7 L2 A6 N4 A7b A8w A8 N5 N25 A8b N8a (11) | End of 1 | Jaw sketch open for editing (pencil), Timeline visible, jaw `20` / `45°` committed, no pivot or head circle yet |
| 3 | A9 L4 N1a N21 N21b N26 L12 N24 A17 A9c N1b N20 A9b (13) | End of 2 (sketch open) | Part mode, body cut by the open jaw (`Extrude Up To Surface 10.0000 mm`), `pre-cut.sxp` saved before the cut and **`cut.sxp` saved after it** |
| 4 | A16 N6 A11a N10 N18 (5) | End of 3 | Part mode, shaft Slot cut (`Extrude Blind 2.5000 mm`), saved as `wrench-wip.sxp`, Top view |
| 5 | A11b N2 L3 A11c N3 A11d A11e A11f N15 N13 N16 N19 N23 (13) | End of 4 | Part mode, neck R10 + top / bottom / slot-floor R1 applied, Fillet disarmed, nothing selected, Timeline on, document dirty |
| 6 | A12 N11 A13 A13b A13c N9 L7 N8b N14 A10 A10b A14 L9 A15 (14) | End of 5 | nut exported, lints, headless walks and full tier run |

16 + 11 + 13 + 5 + 13 + 14 = **72**.

If a chunk fails a row that the next chunk depends on, say which, and re-enter from the last saved `.sxp` (rule 11): after chunk 1 `blank.sxp`, after 3 `cut.sxp` (the cut part; `pre-cut.sxp` is the sketch before the cut and is never overwritten), after 4 `wrench-wip.sxp`. **Recovery that deletes geometry:** use the sketch drag-box (N24: Select tool, drag from empty canvas, then Delete). Ctrl+A also works.

### Re-verify map: every WP has rows

Walk these rows with the BUILD PR in mind. If one fails, write `REGRESSION of #nnn` (or `WPn of re-PLAN 19`) in WALK_LOG with the full status log and the trace lines (rule 56).

| WP | Rows (chunk) | What the walker must see |
|---|---|---|
| WP1 keys | A3 (1), L10 (1), A8 (2), A9 (3), N18 (4), L3 (5), A11d (5), A11e (5) | Every typed burst arrives whole (`22.5`, `200`, `1.5`, `45`, `2.5`, `10`) on the first try; a click that focuses a field followed at once by keys keeps the typed text; Enter after a single character releases the field (key `3` → `Top view`) |
| WP2 shield | N12 (1) | After Extrude → File menu open / Esc, the chip row top y is unchanged (±1 px) and a second click on the Extrude pixel is `drop:shield`; nothing is hidden |
| WP3 jaw | A8w, A8, N5, N25, A8b, N8a (2) | Preview is a rectangle from click 1 on; a 97 mm first jaw dimensions to `20` / `45` without `!`; an emptied sketch reads `—` |
| WP4 glyphs | N21, N21b, N26, N1a, A9, L12, N24, A8b, L6 (2–3) | Badges spread, none over a wall; wall clicks select walls; coincident badges only on hover / selection; no orphan badge after the Trim |
| WP5 hint | N16 (5), N8b (6) | `[status-trace]` shows the result held ≥ 2.5 s, the hint back by itself ≤ 3.5 s with a still pointer, no stale hint after the pointer leaves |
| WP6 timeline | A13b (6), L3 (5) | The double-click on a Timeline row opens the editor on the first try (both presses `drop:not-owner:*`, no `model-click`); the panel does not move under a second click |
| WP7 camera | N6 (4) | The first wheel notch right after a view key keeps the point under the pointer (±2 px) |
| WP8 fillet pick | A11b, A11d, A11e, A11f (5), A13 (6) | A first press 2–11 px from an edge picks one edge, never the 13-edge loop; no `fillet soft-skip` error lines at the 14 mm preview |
| WP9 small | A1 (1), A17 (3), N4 (2), N10 (4), L9 (6), N14 (6) | `Snap` / `Infer` labels; one lit rail button after undo / redo; `Polygon — centre set, click a vertex or type the size`; contour tag clear of the small circle; tint gone after the pointer leaves; `[popup-trace]` lines |
| Checklist / process | N7, A7, A7b, A11a (2, 4), A9c, N20 (3), cut.sxp (3), L7 (6) | measured colours; face sketch via Esc then rail Sketch; `cut.sxp`; Ctrl+S proved by mtime |

### Re-verify rows (FAIL or PARTIAL in sx-039)

| Row | sx-039 | Fixed by | Pass now (chunk) |
|---|---|---|---|
| N12 | FAIL (#218 regression) | WP2 | `drop:shield` after the File menu; chip row did not move (1) |
| A8 N5 N25 | FAIL | WP3 | rectangle preview; wide jaw edits cleanly; no `!`; `—` when empty (2) |
| N21 | FAIL (#222 regression) | WP4 | spread badges, `Constraint selected: <type> — Del removes it`; wall clicks select walls (3) |
| L3 | FAIL | WP1 WP6 | `1.5` lands whole, Tab releases, second click focuses the field (5) |
| A11d | FAIL | WP1 | single character + Enter releases the strip field; `Top view` (5) |
| N16 | FAIL | WP5 | result held, hint back by itself, no stale hint (5) |
| A3 | PARTIAL | WP1 | `22.5` / `200` whole (1) |
| A1 A17 N4 N10 N14 L9 | PARTIAL | WP9 | see the map (1–6) |
| N1a N26 A9 A8b L12 N24 L6 | PARTIAL | WP4 + wording | spread badges, exact click points (2–3) |
| N6 | PARTIAL | WP7 | first notch holds (4) |
| A11b | PARTIAL | WP8 | first pick one edge (5) |
| A13b | PARTIAL | WP6 | double-click opens first try (6) |
| N8b | PARTIAL | WP5 | trace-timed hint (6) |
| N7 A7 N1b | PARTIAL | wording | measured colours; Esc-then-Sketch; label list with distances (1–3) |

### Changed text vs sx-039 (use these strings)

| Where | Now |
|---|---|
| Polygon centre press | `Polygon — centre set, click a vertex or type the size` (new). Hover: `Polygon AF <size> — flats horizontal — click to place (or type the size)`; typed: `Polygon AF 20.0000 — flats horizontal`; the AF blank is ` AF` and may be drawn selected |
| Rail checkboxes | `Snap`, `Infer` (were unlabeled); the DOF chip stays `—` / number / `OK` / `!` |
| Jaw preview | A rotated rectangle from click 1 on, including with the pointer still on the centre (3.0 mm across at the least) |
| Jaw first jaw | `Jaw committed — width <w>, long side <a>° — click a label to edit it`; a failed dimension edit says `Dimension rejected — constraints could not be satisfied` and leaves the sketch as it was |
| Coincident badges | drawn only on a selected entity's vertices, the hovered vertex, or when selected; press → `Constraint selected: coincident — Del removes it` |
| Hint / result | a result holds 2.5 s; the hover hint then returns **by itself** if the pointer is still on the target; moving off a shown hint restores the idle text |
| Fillet first pick | within 12 px of an edge → one edge (`Fillet: 1 edge(s) — …`); farther, on a face → the face loop (`Fillet: <n> edge(s) — …`, n ≥ 6) |
| Kernel log | no `fillet soft-skip` error line for an edge the face cues recover; one error only for edges truly lost |
| Traces (`SX_INPUT_TRACE=1`) | `[key-trace] t=<unix> key=<name> unicode=<n> pressed=<0|1> echo=<0|1> accepted=<0|1> focus=<path>`, `[status-trace] t=<unix> kind=<result|hint|restore|idle> text=<label>`, `[popup-trace] t=<unix> <show|hide> <node>`; `t` compares with `date +%s.%N` |
| Save | `Saved <path>` (Ctrl+S prints the same text as Save As, by design: prove a fresh save with `stat -c %y <file>`, rule 65) |
| Chunk 3 end | Save As `cut.sxp` (`Saved $OUT/cut.sxp`) |
| Selection and Sketch | While a body or face is selected the left rail is the inspector and has no Sketch button: press Esc until `Selection cleared`, then rail Sketch (rule 66). A first click on a body is `Selected body …`, a second `Selected face …` (two-stage pick, by design) |
| Fillet apply | `Fillet <n> edges <r> applied — View ▸ Timeline to edit parameters — Fillet no longer armed` (r with two decimals); Fillet is **disarmed**: re-arm (body selected → `Fillet` chip) before the next fillet |
| Fillet refusal at T=14 | `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius` |
| Select statuses | `Selected body <id8>` / `Selected face <id8>` / `Selected edge <id8>`; sketch: `Selected 1 sketch entity`, `Selected <n> sketch entities`, `No sketch entities`. A plain click on a second sketch entity **adds** it (click again to deselect) |
| Constraint glyph press | `Constraint selected: <type> — Del removes it` |
| Esc in a sketch that holds geometry | Never discards. Selection → `Selection cleared — Esc again exits the sketch`; draw tool → `Tool dropped — Esc again exits the sketch`; pending first point → `First point dropped — Esc again exits the sketch`; last Esc → `Sketch saved` (empty sketch: `Sketch cancelled`) |
| Keys in a number field | Letters never enter a length field. Before a digit is typed a tool key (`L`, `D`, `T`, `C`, `S`) still switches tools; once a digit has landed the field owns its keys. A field you **clicked into** owns Ctrl+Z; Ctrl+Shift+Z / Ctrl+Y stay with the sketch until a digit is typed. Bursts arrive whole (WP1) |
| Sketch undo / redo | `Undo: Jaw`, `Undo: Dimension`, `Redo: Jaw` …, `Nothing to undo`; the DOF chip follows (`—` when empty); one rail button stays lit |
| Part mode keys | Ctrl+Z → status begins `Undo`; Ctrl+Shift+Z (or Ctrl+Y) → status begins `Redo` |
| Views | keys `1` Front, `2` Right, `3` Top, `4` Back, `6` Left, `7` Iso, `8` Bottom; Top and Bottom look **through the open jaw** (a click in the jaw slot selects nothing). `F` frames the selection (`Framed selection`) or all; `Shift+F` and HUD Frame frame all |
| A8b | The jaw sketch is `sketch 3` (names are indices) |
| Shaft lines | `Shaft lines: 2 added`; tangent to the Ø20 pivot (offset 10 mm), not to the Ø45 head (by design) |
| Select hover ✕ | Δu on an axis-aligned line; Δu **and** Δv on a slanted line |
| Saved sketch | a saved, not yet extruded sketch is drawn as a yellow pad (by design) |
| Export | `Exported 3MF → <path>` |

### Soft-GL protocol (sx-040 walker)

Rules 1–16 (replan 10), 17–22 (11), 23–30 (12), 31–36 (13), 37–40 (14), 41–44 (15), 45–51 (16, 17) stay as in [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md); rules 52–60 (re-PLAN 18) stay as in [`rung-01-replan-18.md`](rung-01-replan-18.md) (one action one read (52), WALK_LOG after every row (53), physical pixels (54), bursts and keys (55), name the regression (56), PASS means every clause (57), retries visible (58), no setup beyond the row (59), start-up evidence (60: `BUILDINFO.txt` `commit=` equals the full sha of `main` after the BUILD PR)). Highlights: read every typed field back before Enter (1); one retry of a dead click, never a third (2); the status line is the truth, screenshots lag one action (8, 36); real rail presses (33); first glyph of a label (27); never move the view to dodge the rail (28); Esc ends an armed pick (29); one Extrude click then read (41); typed export names read back (43); a plain click never prints `Editing sketch` (45); results hold 2.5 s (46); typed values replace (47); camera rows read the picture twice (48); soft-GL evidence (49); contours numbered by size (50); a dead first click is recorded with its `[input-trace]` line (51).

New in this plan (sx-039 walkers batched actions, read screenshots as clocks and aimed clicks by eye):

61. **No batching, ever.** One tool call = one click, **or** one key, **or** one typed string, **or** one drag, **or** one hover. Never send two actions in one call, never `xdotool` chains (`click … key …`), never a typed value and Enter together. A row walked with batched actions is **void** (sx-039 voided chunk 1 attempt 1 and A11e; a batched stray Ctrl+A selected 44 faces). Write `voided` in WALK_LOG and redo the row.
62. **Lag waits.** After every action wait ≥ 1 s (≥ 2 frames; `sleep 1`) **before** reading the status, then read the status line, then take the screenshot. The screenshot may show the state one action earlier (`22.0` then `22.5`, `4` then `45`): trust the status line and a second read, never the first screenshot, and write both readings when they differ.
63. **Timing rows use clocks, not screenshots** (N16, N8b). Run `date +%s.%N` in its own call immediately before the key / click that starts the clock and write it as T0; every reading carries its own `date +%s.%N`. The verdict comes from the `[status-trace]` lines in `$OUT/input-trace.log` (`kind=result` at T0, `kind=hint` ≥ 2.4 s later); screenshots only confirm. A row read from screenshot order alone is PARTIAL.
64. **Pointer placement is part of the row.** Rows that need the pointer on the body say where (a face and a physical-pixel target) and the off-body point for the second half. Before the row write the pixel you used (`xdotool getmouselocation`). A row whose pointer was not on the target is **void**, not failed (N8b run 1 in sx-039).
65. **A fresh save is proven by the file.** Ctrl+S prints the same `Saved <path>` as Save As (by design). Run `stat -c '%y %s' <file>` in its own call before and after the key; the mtime must change.
66. **Face sketch with the rail hiding Sketch.** While a body or face is selected the left rail is the inspector (no Sketch button). To start a face sketch: press Esc, one call each, until `Selection cleared`; then rail **Sketch** (`Select a face or existing sketch (Esc to cancel)`); then click the face **once** (`Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`). If a selection must stay, use the inspector pencil, then click the face once. A rail without Sketch after `Selection cleared` is a failure.
67. **Dead click or dead key = evidence.** For a click that did nothing copy its `[input-trace]` line (rule 51); for a key that did nothing or arrived wrong copy the `[key-trace]` lines around it. Retry once (rule 2), never a third. A dead first click on a part chip, a Timeline row or a field is FAIL with those lines.
68. **Burst readback.** For every typed burst (`22.5`, `200`, `1.5`, `45`, `2.5`, `10`) wait 1 s, read the field, and only then press Enter. If the field differs from the typed text copy the `[key-trace]` lines for that burst (`echo=1 accepted=0` on a repeated digit is the WP1 signature) and retype once; a second miss is `FAIL #217`.
69. **Jaw geometry is measured, not eyed.** In the A7b / A8 screenshot (full resolution) write the head disc's left x, right x and middle y in physical px; `s = (x_right − x_left) / 45` px per mm; `H = ((x_left + x_right) / 2, y_mid)`. Jaw click points are `H`, `H + (20·s, 0)` and `H + (20·s, −10·s)` (A8) or `H + (20·s, −48.4·s)` (A8w). Screen y grows downward. If `H` cannot be measured write why and use the nearest visible centre.
70. **Popups: one click opens, one click chooses.** Menus and dropdowns (File, View, the finish-bar Op dropdown) are separate windows: open with one click, wait 1 s, copy any `[popup-trace]` line, choose with one click, with no pointer motion between. A dropdown that closes before the choice: copy the `[popup-trace]` and `[input-trace]` lines and record FAIL (N14), do not work around it by clicking Select first.
71. **Engine log noise is counted, not judged.** `ERROR: Signal 'focus_entered' is already connected …` and `Attempt to disconnect a nonexistent connection …` lines come from the engine's popup handling (decided out of scope). Write the count at the end of each chunk; a verdict never depends on them. Any other `ERROR:` / `[ERROR]` line is copied into WALK_LOG with the row it appeared in (in particular `fillet soft-skip` after WP8).


---

### The 72 rows

### Chunk 1 — blank (16 rows)

Start: launch (rule 51 env), read the window (N22), File → New (`New — empty part, Top plane (XY). View ▸ Timeline to edit features`), rail **Sketch** on the ground plane. Keep the blank open through A13c (rule 10).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| N22 | r17-WP4 | Before any click: `xdotool search --name SolidExpress` → `xdotool getwindowgeometry <id>`; `xprop -id <id> _NET_WM_STATE`; `xdpyinfo | grep dimensions` | Window width ≥ 1272 and height ≥ 750 on a 1280×800 screen (usable rect minus decorations, ±8 px), or `_NET_WM_STATE_MAXIMIZED_HORZ` and `_VERT` present. Not ~1072×620. The menu bar, left rail and bottom status row are all inside the screen. **Write the physical screen size and the screenshot size in WALK_LOG**; if they differ (sx-038 used a 1920×1200 screen and 1280×800 screenshots) every pixel number in this walk is physical (rule 54) |
| A1 | #185 r19-WP9 | Read the left rail in the new sketch (before drawing) | The two checkboxes read **`Snap`** and **`Infer`** (they had no text in sx-039); the DOF chip is a single glyph (`—`, a number, `OK` or `!`); the rail width is the same as in sx-039 (±1 px). All **19** rail labels fully visible at 1280×800, last label inside the window, none clipped. The chip row starts right of the rail, covers neither Arc nor Point, ends inside the right edge (re-read in A3 with two circles selected) |
| A2 | #196 | Press **Jaw**, then **Rect** | Jaw: a status starting `Jaw`, no variant chips. Rect: `Rect — click 1 first corner, click 2 the opposite corner`; chips left to right `Corner` (highlighted), `Center`, `Three Point`, `Center Three Point`, `Parallelogram` |
| N7 | #198 | Rail **Jaw**; then rail **Rect**; then rail **Circle** and click one centre | The armed button is lit — accent fill and a 3 px accent bar on its left edge — clearly different from a merely hovered button (**measure it**: write the RGB of the lit button's fill and of a hovered, not armed, button at the same offset; they differ by ≥ 20 in at least one channel); only that button is lit. Circle centre click: `Circle — centre set, click the rim or type a radius` |
| L1 | #220 #217 | One press, then read, per button. Rail: **Jaw**, then Line, Smart Dim, Trim, Slot, Circle, Select in turn. Then keys, one at a time, **without clicking or typing in the Radius field**: `L`, `D`, `T`, `C`, `S` | Each press prints a sentence that starts with that tool's own name, never the previous tool's. **Exactly one** rail button is lit after every press and every key (the active tool's), also when the previously pressed button is still under the pointer; Slot's button is lit while Slot is armed. The Radius field is **not** prefilled with another tool's number. After `C` the Radius blank is focused but untouched: `S` still switches to `Select …` (by design a field you clicked or typed in keeps its keys: if you did, press the Select rail button instead and write `field owned` in WALK_LOG). Each rail press and each first canvas click lands on the first attempt (rule 51 for any miss) |
| A3 | #182 #217 #220 r19-WP1 | Delete the A2/N7 scratch (select, Delete, or Esc to empty). Circle tool: **first click** at the origin; type `10` Enter. Circle: click right of it; type `22.5` as **one burst** (`xdotool type --delay 10 22.5`, rule 55), wait 1 s, read the field back, only then Enter (rule 68; on a miss copy the `[key-trace]` lines and retype once). Smart Dim: click centre 1 (`Smart Dim: first pick set …`), plain click centre 2 (no Shift); type `200` as one burst, wait 1 s, read it back, Enter | Both first clicks land. Typed digits replace the field and every key arrives: `10`, `22.5` (never `2.5`, `0.5`, `225`), `200` (rule 47). `Circle r=10.0000 (Ø20.0000)`, `Circle r=22.5000 (Ø45.0000)`, `Dimension updated`. Centres level (head centre y = pivot y ±0.05). **No stray point marker and no coincident / horizontal badge inside either circle after the Smart Dim picks** (#220; zoom a screenshot on each circle). Chip row check from A1 with both circles selected |
| L5 | #182 | Press `F`; then HUD **Frame**; then `Shift+F` | `Sketch view fit` (or the HUD's equivalent); **both** circles fully inside the canvas, right of the rail and inside the window each time; the grid covers the whole canvas; no stale disc |
| A4 | carry | **Shaft Lines** | `Shaft lines: 2 added` (offset 10 mm from the axis: tangent to the Ø20 pivot, by design not to the head) |
| L6 | #183 | Read the canvas; zoom out three wheel notches | No red / orange ✕, no live Δ labels. Neutral (white-on-black) `H` / tangent badges are expected — their colour is by design, not blue. A **red or orange** H badge or a conflict count is a failure. Squashed circles in a screenshot with equal projected x / y: soft-GL (rule 35) |
| L10 | #200 #217 r19-WP1 | Finish bar Distance: type `10` Enter, then `14` Enter, then `10` Enter; read the field right after each Enter and one frame later. Then click the field again, type `1` `.` `5`; Ctrl+A; then type `2.5` as one burst (rule 68) | The field never shows the previous value (rule 47); ends at `10`; `1.5` reads `1.5`; Ctrl+A selects the field text (it does not select sketch entities) and the burst `2.5` replaces it (`2.5`, never `2.05` or `2.052.5`); Enter releases the field, so a key pressed after Enter goes to the viewport. A one-frame flash seen only in a lagging screenshot is rule 8. Leave the field at `10` |
| A5 | #197 | Set Distance `10`, Blind, New. Click **Extrude** once with the mouse | After two frames: `Extrude Blind 10.0000 mm`. The view frames the whole new body (Ø45 head and Ø20 pivot ends both visible), **no** red ✕, **no** yellow sketch lines over the body. Then File → Export 3MF, type `blank.3mf` in `$OUT` (read the field back); `Exported 3MF → $OUT/blank.3mf`; checker blank **5/5** |
| N12 | #181 #218 r19-WP2 | Re-verify the A5 Extrude (rule 41): read the result and the part chip row, and write the chip row's **top y in physical px** (Y0). Then (a) open the menu-bar **File** menu with one click, wait 1 s, press **Esc** (one call each; `[popup-trace]` lines go in WALK_LOG) and read the chip row top y again; (b) click the **same Extrude pixel** once more (a real second click, ≥ 0.5 s after (a)); (c) move the pointer onto the `Fillet` chip and click it once; (d) Esc, and Esc again until `Selection cleared` (at most twice) | One body; Timeline `sketch 1`, `extrude 2` (names are indices, rule 37). The chip row (`Hide`, `Fillet` …) is **not drawn on the Extrude pixel**. (a) the chip row top y equals Y0 (±1 px) after the menu opened and closed (WP2: the menu press does not disarm the shield). (b) changes nothing: feature count equal, body still visible, no `hidden` status, no `jaw_af` / AF chip text, and the `[input-trace]` line for that press is `drop:shield` (#218). (c) the press lands: status begins `Fillet r=` (a motion onto another chip is a new gesture). (d) `Edge pick cancelled`, then `Selection cleared`; nothing is selected when A5b starts |
| A5b | carry | File → New: the Discard dialog → **Cancel**. Then File → Save As | Cancel keeps the blank. Save As dialog opens pre-filled `untitled.sxp`, name selected |
| L8 | carry | In that dialog do **not** press Ctrl+A; type `blank.sxp`; read the field back; OK | Typing replaced the selected name; `Saved $OUT/blank.sxp` |
| L11 | carry | Open the HUD **View ▼** menu; close; open the menu-bar **View** menu | Both lists are opaque; no button shows through them |
| N17 | #204 | Click the body (selected; the status names the level, `Selected body …` on an unselected body, `Selected face …` when the body was already selected). Open the menu-bar View menu, press **Esc** once; repeat with the HUD View ▼; then press Esc once more with no menu | First Esc: the menu closes, the selection **stays**, the left panel mode is unchanged, no `Selection cleared`. Same for the HUD menu. The third Esc → `Selection cleared`. (A face vs body result is the two-stage pick, by design: the status word says which) |

End of chunk 1: part mode, nothing selected, `blank.sxp` saved, `blank.3mf` exported.

---

### Chunk 2 — face sketch, Esc ladder, jaw (11 rows)

Start: end of chunk 1.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A7 | #199 r19-process | Plain-click the top face once (read the status). Then press **Esc**, one call each, until `Selection cleared` (rule 66), then rail **Sketch**, then click the top face **once** | The plain click gives a status beginning `Selected ` and **never** `Editing sketch` (rule 45). While the face is selected the rail has no Sketch button (by design, decided 13): after `Selection cleared` the rail shows it. Rail Sketch: `Select a face or existing sketch (Esc to cancel)`; the face click: `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`; the view frames the **whole blank**: Ø45 head and Ø20 pivot both inside the canvas, right of the rail, without `F` |
| L2 | carry | In this new sketch set the finish bar to **Cut / Up To Surface / `7`**. Keep it | Used by A6 next |
| A6 | #201 | Circle tool, **one** click in the canvas (with Up To Surface still set), Esc, Esc. Exactly two presses | The click lands (`Circle — centre set, click the rim or type a radius`; no face pick, no `Selected`). Esc 1: `First point dropped — Esc again exits the sketch`. Esc 2: `Sketch cancelled` (empty sketch). No `Measure cleared` between. Afterwards **no face is selected** and no `Face: …` pick is pending |
| N4 | #201 #219 r19-WP9 | Rail **Sketch** on the top face (read the finish bar: **Blind / New / 20**). Rail **Polygon**; read the status and the AF field; **one canvas press** for the centre (it must land first time, rule 51); read the status and the AF field again; type `20` Enter. Circle tool: click the centre, click into the Radius field: (a) Ctrl+A; (b) Esc, Esc. Then part mode: Ctrl+Z | Finish bar reset. Polygon: status after the rail press `Polygon — click the centre, then a vertex (or type the size)`; the centre press lands: status `Polygon — centre set, click a vertex or type the size`, and the hexagon preview follows the pointer; the AF blank shows its placeholder ` AF` (it may be drawn selected, by design) and **never `0.01`**; typed `20` replaces it → `Polygon AF 20.0000 — flats horizontal`. (a) the field text is selected; no `Selected … sketch entities`; selection unchanged. (b) Esc 1 `First point dropped — Esc again exits the sketch`; Esc 2 `Sketch saved`; the host face is **not** left selected. Ctrl+Z: status begins `Undo`; the throwaway sketch leaves the Timeline. (A saved, not yet extruded sketch is drawn as a yellow pad — by design, not a failure) |
| A7b | #199 r19-process | Press **Esc**, one call each, until `Selection cleared` (rule 66); rail **Sketch**; click the top face once. Then read the screenshot at full resolution and **measure the head** (rule 69): write the head disc's left x, right x and middle y, `s` and `H` | Face sketch opens framed on the whole blank (`Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`); finish bar Blind / New / 20. WALK_LOG has `x_left`, `x_right`, `y_mid`, `s`, `H` in physical px for A8 |
| A8w | r19-WP3 | (Wide first jaw; do this **before** A8, in the same sketch.) With `s` and `H` from A7b: **Jaw**; click 1 at `H`; click 2 at `H + (20·s, 0)`; click 3 at `H + (20·s, −48.4·s)` (width side longer than twice the long side: the sx-039 walker's accidental jaw). Read the status. Click the first glyph of the width label, type `20` as one burst, read it back, Enter; the angle label: `45` as one burst, read it back, Enter. Then Ctrl+Z until `Nothing to undo`, read the DOF chip; then Ctrl+Shift+Z once, Ctrl+A, Delete, read the DOF chip | `Jaw committed — width <w>, long side <a>° — click a label to edit it` (a wide width such as 96.8 and a long side near 0° / 5°). Width edit: `Dimension updated`, never `Dimension rejected`, DOF chip not `!`; angle edit: `Dimension updated`, walls at 45°, included angle 90° ±0.05°, DOF chip not `!`. After Ctrl+Z to the end: `Nothing to undo`, DOF `—`. After Delete of everything: DOF `—`, **never `OK`** and never a stale number. If an edit is refused the status is `Dimension rejected — constraints could not be satisfied` **and the sketch is unchanged** (no `!`). The sketch is empty when A8 starts |
| A8 | r17-WP2 #217 r19-WP3 | **Jaw** (empty sketch from A8w): click 1 at `H`; **move the pointer to `H + (20·s, 0)` and read the preview before clicking** (rule 69); click 2 there; click 2 again at the same pixel; click 3 at `H + (20·s, −10·s)`. Then **one click on the first glyph** of the width label (`20`), type `20` as one burst, read it back, Enter; then of the angle label (`45°`), type `45` as one burst, read it back, Enter | After click 1, with the pointer still on `H`, the preview is already a rotated **rectangle** (4 edges, at least 3.0 mm across; not one line, not blank); at `H + (20·s, 0)` a rotated rectangle; with the pointer on the axis a thin rectangle (never a doubled line). The repeated click 2 prints `Jaw — width is zero — click 3 again for half the width`, no `Jaw committed`, entity count unchanged. Click 3: `Jaw committed — width …, long side …° — click a label to edit it`, non-zero width. Each label opens on the **first** click with its text selected (rule 47); the field reads `20` / `45`, never `4` (a dropped digit is a product failure after WP1: copy the `[key-trace]` lines, one retry, then record); `Dimension updated`; walls at 45°, included angle 90° ±0.05°; DOF chip not `!`. Initial labels like `16.9044` / `-32.49°` before editing are fine |
| N5 | carry r19-WP3 | Select tool. Ctrl+Z, Ctrl+Shift+Z, Ctrl+Z, Ctrl+Z … until empty, then Ctrl+Shift+Z until the jaw and both dimensions are back | `Undo: Jaw` removes the Jaw (earlier `Undo: Dimension` steps first); `Redo: Jaw` restores it; at the empty end `Nothing to undo`; after the redos `20` and `45°` are shown again with the jaw. Trust statuses and entity count (rule 40) |
| N25 | r17-WP2 r19-WP3 | Read the DOF chip (bottom-left status area) at three moments of N5: with the jaw drawn; right after `Undo: Jaw` with the sketch empty; right after `Redo: Jaw` | Empty sketch: `—` (never `3` or any stale number); after the redo the chip equals its text before the undo (a number or `OK`, same as a fresh jaw). No `!` conflict marker |
| A8b | checklist r19-WP4 | Select tool, click a jaw wall **at 40 % of its length** (not near a badge; read the status: `Selected 1 sketch entity`, never `Constraint selected`), then **Esc**, **Esc**; then in part mode Ctrl+Z, then Ctrl+Shift+Z | Esc 1: `Selection cleared — Esc again exits the sketch` (no `Measure cleared` first). Esc 2: `Sketch saved` — the sketch and jaw are **kept**. Selecting the Select tool reads `Select — click geometry, or a dimension label to edit it`. Part Ctrl+Z: status begins `Undo`, the sketch leaves the Timeline. Ctrl+Shift+Z: status begins `Redo`, **`sketch 3`** is listed again with the jaw (Timeline: `sketch 1`, `extrude 2`, `sketch 3`; the N4 throwaway was removed by its Ctrl+Z, so it consumes no number) |
| N8a | #184 #216 r19-WP3 | Take the **N18 screenshot** of the part view (rule 48), then View ▸ **Timeline** on (check N19 / N23 later). Read the DOF chip once in the sketch you are about to leave (it reads a number or `OK`); click the **pencil** next to the jaw sketch | `Editing sketch`; no rename field (F2 on the row still renames). Finish bar reads **Blind / New / 20**; the sketch view is centred on the part. The DOF chip in the re-opened sketch reads the **same text as before the exit**, never `—` or `— DOF` while the sketch has geometry (#216) |

End of chunk 2: jaw sketch open in edit mode.

---

### Chunk 3 — pivot, trim, labels, cut (13 rows)

Start: jaw sketch open (end of chunk 2). The N18 screenshot from N8a is the reference for A9b (rule 48).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A9 | #203 #217 r19-WP1 r19-WP4 | Press `F`. Circle tool: **first click** on the pivot centre at the origin, 30 px right of the visible rail, view unmoved; type `5` Enter. Circle tool again: redraw the Ø45 head on the head centre, type `22.5` as one burst, read it back, Enter. Draw a **plain Line** (not Centerline) across the head: read the Line Length field before typing. **Power Trim** (`T`): drag from the **outer stub** across the Line | First click lands: `Circle — centre set, click the rim or type a radius`, then the typed `5` gives `Circle r=5.0000 (Ø10.0000)` (rule 28); the head reads `22.5` (burst readback, rule 68). The Line Length field is **not** `22.5` (no leak from Circle). Trim: `Trimmed open jaw`; the Line is gone; no pan; **no red trail** left after the mouse is released (screenshot after the release); **no orphan badge**: no `V` / `H` badge remains where the deleted Line was (every drawn badge belongs to an existing constraint). A second drag: `Jaw is already open — nothing left to trim here`. If the Line is not across the head the status is `Nothing trimmed — no crossing at that point` (never a bare `Trimmed`); redraw and retry. WALK_LOG: the Line Length text, the two Trim statuses, the screenshot name (sx-038 lost these) |
| L4 | #186 | Read the jaw labels right after Trim | Exactly one `20` and one `45°`; no `20.0005` / `45.0007°`; no overlapping labels. (Wall 45° ±0.1° is confirmed by wrench 28/28 in chunk 6) |
| N1a | r17-WP1 #222 r18-WP4 r19-WP4 | Zoom with the wheel until the Ø45 head is **~150 px** across (physical px, rule 54). List every dimension label (text and place) | Exactly `20`, `45°`, `5`, `22.5`. `22.5` sits **on the head arc** (the label's **nearest edge** is ≤ 40 px from the head circle, with a thin leader to it; write the measured distance) — not ~100 px above the head; the `45°` label is ≥ 4 px from the nearest coincident badge; none overlaps another label or a glyph (gap ≥ 4 px); none is under the menu / rail / chips; the first glyph of `20` and of `45°` is clickable (opens the editor; Esc closes it) |
| N21 | r17-WP1 #222 r18-WP4 r19-WP4 | Same zoom: read the constraint glyphs around the head and pivot. Select tool; **one press** on a horizontal badge, read the status; one press on a parallel badge, read; then **hover** a vertex of the jaw (pointer on the corner, no click): a coincident badge appears for it; one press on that badge, read | No pile-up: glyphs are spread (≥ ~60 % of each visible); **coincident badges are not drawn for every vertex** — only for the hovered or selected entity's vertices (decided 6). Each press **selects that constraint, not the line or circle under it**: status `Constraint selected: <type> — Del removes it` (type names the badge). Do not press Delete |
| N21b | r19-WP4 | Same zoom, Select tool. **One click per call**, on each of: the two jaw walls and the jaw's end line at 25 %, 50 % and 75 % of their length, and each shaft line at 50 %; read the status after every click; between clicks click empty canvas (≥ 60 px from geometry) to clear (rule 61) | Every click reads `Selected 1 sketch entity` (a plain click on a second entity adds it, so clear between clicks); **never** `Constraint selected`. A click that lands inside a badge rect is retried 6 px along the wall and the badge position is written. At least 9 of the 11 positions are free of a badge (rects ≤ 40 % of the wall length covered) |
| N26 | r17-WP1 #222 r18-WP4 r19-WP4 | Same zoom: for each tangent and coincident badge find the vertex or contact point it belongs to | Every badge is within 40 px of its vertex / contact point; a badge pushed 12 px or more has a thin leader line to its point; none sits off the part (nothing below the shaft's lower edge, none inside empty space between shaft and head); the `5` label has clear space (≥ 4 px) to every `H` badge |
| L12 | #206 #221 r19-WP4 | Arm Circle; move over the jaw and shaft lines. Then Select tool and hover with no click; leave the line; press `F`; hover again; Esc. Then click a **slanted jaw wall** at 25 % of its length: the ✕ shows **Δu and Δv** (a slanted line; an axis-aligned line shows Δu only, by design). Then click a shaft line (thin) at 25 % once. Then: select the two shaft lines (click one, click the other), read the chips, press Esc; select them again, click empty canvas; select them again, press Delete (then Ctrl+Z) | Circle armed: **no** ✕, no Δ labels, ever. Select + hover: ✕ **with** Δu / Δv; the ✕ is gone when the pointer leaves the line, after `F`, `Shift+F` or HUD Frame, and after a click on empty canvas. Esc over a ✕ → `Measure cleared`, chips still showing. The shaft-line click selects it **on the first click**; then the ✕ is gone and the next Esc is `Selection cleared — Esc again exits the sketch`. With the two lines selected the chips `Parallel?` / `Equal?` / `Perpendicular?` may show; **after Esc, after an empty click, after Delete and after the undo none of them is still on screen** (#221). Redo the Delete only if the next row needs the lines |
| N24 | r17-WP3 #221 r19-WP4 | Select tool. Draw a throwaway Circle r `3` in empty canvas (≥ 60 px from all geometry); Select tool. Every drag **starts on empty canvas ≥ 60 px from any entity** (a drag that starts on an entity moves it). (a) Left-to-right drag that **encloses** the circle; (b) press-release on empty canvas; (c) right-to-left drag from empty canvas that crosses only the circle's rim; (d) a left-to-right drag that only **cuts through** the rim; (e) click one jaw wall, then Shift + window drag around the circle; (f) click empty canvas; (g) window-drag the circle again, press Delete | (a) a **blue** box shows while dragging (measure the box edge colour and write the RGB: blue-dominant for (a), green-dominant for (c)); status `Selected 1 sketch entity`. The **first** drag of each kind works (#221: no dead first drag). (b) selection cleared. (c) a **green** box; `Selected 1 sketch entity`. (d) `No sketch entities` and the selection is empty (window needs the whole entity). (e) the click on the wall **at 40 %** selects only the wall (1) — never `Constraint selected` — the Shift window adds the circle: `Selected 2 sketch entities`. (f) cleared. (g) `Deleted 1`; the jaw, pivot and head are unchanged (entity count back to the count before the throwaway) and `20` / `45°` labels remain. By design a **plain click on a second entity adds it** to the selection (click it again to deselect): two selected after one click means the previous selection was still alive; write the step before it in WALK_LOG |
| A17 | #202 r19-WP9 | Read the Line / Centerline chips and the Contours row. Click the Centerline chip with the pointer over the canvas | Chips do not overlap; Contours row only with more than one closed region; the chip click places **no** point or line on the canvas; a Centerline commit reads `Centerline added — construction, not part of the profile` (draw one and delete it); after Ctrl+Z and Ctrl+Shift+Z no phantom line appears, no suggestion chip lingers after the undo, and **exactly one rail button is lit** (the active tool's) after each of them |
| A9c | carry | Set the finish bar to **Cut**, **Up To Surface**, pick the opposite face (`Face: z 0.0 mm`), thin / flip off. Then File → Save As `pre-cut.sxp` (read the name field back); OK | `Saved $OUT/pre-cut.sxp`; the sketch, Select tool and profile are still there; the finish bar is exactly as set (Cut / Up To Surface / `Face: z 0.0 mm`) — it is **not** reset |
| N1b | #186 r19-WP4 | List the labels again **with the distance of each to its anchor** (as N1a); hover a label while its editor is open | Identical to N1a (no second `45°`, no new `5` / `22.5`). Editor open: no Δ overlay, no ✕ left at an old endpoint |
| N20 | carry | Save As `pre-cut.sxp` again (read the name back; overwrite); press Ctrl+Z | `Saved …` again; finish bar still Cut / Up To Surface / `Face: z 0.0 mm`; Extrude button enabled; Ctrl+Z status begins `Undo:` (sketch undo kept) — then Ctrl+Shift+Z |
| A9b | #197 r19-process | Click **Extrude** once; read the status after two frames | `Extrude Up To Surface 10.0000 mm`; no `breaks the chain`, no open-shell refusal. The view frames the new body; **no** yellow jaw / pivot / head lines remain over the solid. Select the body: size reads 232.5 × 45.0 × 10.0 (±0.3) (if no size readout exists, A12 28/28 is the evidence). A plain click inside the head → `Selected `, never `Editing sketch` (rule 45). **N18 (first read):** the part view equals the screenshot from N8a (head and pivot ±5 px). Then File → Save As `cut.sxp` (read the name back): `Saved $OUT/cut.sxp` (the cut part; chunk 4 starts from it) |

End of chunk 3: part mode, body cut by the open jaw, `pre-cut.sxp` saved (the sketch before the cut; never overwritten) and **`cut.sxp` saved after the cut** (A9b). The CI-less walker has no other copy of the cut part: re-enter chunk 4 from `cut.sxp` if needed.

---

### Chunk 4 — views, slot (5 rows)

Start: end of chunk 3.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A16 | #204 | Menu-bar View → Orientation; HUD View list; keys `1` `2` `4` `6` `7` `8`; orbit off Top with the preset's orbit drag; then key `3` | Both lists show Front, Back, Left, Right, Top, Bottom, Isometric; each key shows its view (`Front view`, `Right view`, `Back view`, `Left view`, `Isometric view`, `Bottom view`); key `6` and the HUD Left give the same picture; the drag moves the camera (a large tilt per small drag is leftover 23, soft-GL); `3` → `Top view`, exact top (straight down, orthographic), the part centred, the **open jaw seen through**: a click in the jaw slot selects nothing |
| N6 | carry r19-WP7 | Part mode: key `3`; **in the very next call** (no wait beyond rule 62's 1 s) one wheel-in notch with the pointer on the head (write the pixel of a head feature before and after); two more notches; three wheel-out; then `F` with the body selected; click empty background (nothing selected), `F`; `Shift+F`; HUD **Frame** | The point under the pointer stays under it (±2 px) through **every** notch **including the first one right after key `3`** (the view tween finishes first, WP7). `F` with the body selected → `Framed selection`; with nothing selected `Framed all`; `Shift+F` and HUD Frame → `Framed all` (`F` and `Shift+F` differ by design when a body is selected); the part lands right of the left panel inside the window. End in Top view |
| A11a | #199 #203 #219 r19-process | Screenshot the Top view (N18). Press **Esc**, one call each, until `Selection cleared` (rule 66); rail **Sketch**; click the top face once (click the head meat, not the jaw slot). Rail **Slot**; type radius `5` Enter; click centre 1 at `(18.5, 0)` (**first canvas press, it must land**, rule 51); read the field label (`c-c`); type `150` Enter | The sketch opens framed on the whole body. Slot lit; status `Slot — …`; stadium preview; centre 1 is set by the first press; label `c-c` after the first centre, the field is **not** prefilled `5.0` and not `0.01`; `Slot c-c 150.0000 R5.0000 — typed` (rule 23). Finish bar: Blind / New / 20; the Extrude Distance stays 20 until you set it |
| N10 | r17-WP1 r19-WP9 | Draw a throwaway Circle (r 5) in the head so the sketch has two closed regions: the **Contours** chips appear. Hover chip `2`; click chip `1` off, then on; then delete the throwaway (Select, click it, Delete) | Hover: that region gets a clearly **stronger** fill (about 3 × the included region's fill, visible without a zoom tool) with a `2` tag **clear of the small circle's outline (≥ 4 px)** and a double outline; the included region keeps the light fill; a skipped one is outline only. Click: `Contour 1 of 2 — W × H mm at (x, y) — skipped` then `— included` (read the status, rule 50). After Delete: `Deleted 1`, chips gone |
| N18 | carry #217 | Set **Cut**, **Blind**; click the Distance field, Ctrl+A, type `2.5` as one burst, read it back, Enter. Click **Extrude** once. Save As `wrench-wip.sxp` | The Distance field read `2.5` (never `2.05` / `2.052.5`, #217). `Extrude Blind 2.5000 mm` (a real Slot). The part view is the **Top view screenshot** from A11a (head and pivot ±5 px; the camera does not jump). `Saved $OUT/wrench-wip.sxp` |

End of chunk 4: part mode, Top view, slot cut, `wrench-wip.sxp` saved.

---

### Chunk 5 — fillets (13 rows)

Start: end of chunk 4. Fillets are picked from keys `3` (Top), `4` (Back), `8` (Bottom), `1`, `7`, with the body selected. Zoom with the wheel or `F`. Click each fillet target **once**; a first click that misses is a failure (leftover 4). In Top view the jaw slot is see-through: click the neck corners and head, never the slot.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A11b | #168 r19-WP8 | Select the body (click it **≥ 20 px from every edge**: `Selected body …`; a click within ~14 px of an edge is `Selected edge …` by design). Press the **Fillet** chip (Fillet armed). Key `3`. Click each **neck corner** (the two vertical edges where shaft meets head). Key `4` and click the +Y wall; press on the empty background. Do **not** press Enter yet | Corner click: `Fillet: 1 edge(s) — 10.0 mm vertical …` (never `13 edge(s)`, not the 32.3 mm arc, and no `0.0 mm line`); the wall click keeps the set (adds an edge only within 14 px, else `No edge near click …`); the background press: `Missed the solid — click a face or edge`, set and panel kept |
| N2 | #205 | Fillet still armed. (a) Strip `R`: ▲ then ▼ then key `3`. (b) Strip `R`: click into it, type `10`, Enter, then keys `3` and `4`. (c) Panel **Radius**: click into it, type `10`, Enter, then key `3` | (a) ▲ `2.5 mm`, ▼ `2 mm` (step 0.5), key `3` → `Top view`. (b)(c) the field reads `10 mm` (no extra digit, never `1` / `100`); **Enter does not apply the fillet** and no fillet editor opens; the field releases the keyboard (key `3` → `Top view`, key `4` → `Back view`); **Fillet is still armed** (strip `R` visible; `Fillet r=10.00 — edit Radius, click edges, Enter`). Rule 47 |
| L3 | #200 r19-WP1 r19-WP6 | Strip: type `10` Tab. Panel: click the Radius field, wait 1 s, **click it a second time** (the L3 second click), type `1.5` as one burst, read it back, Tab; then `10` Tab (bursts: rule 68) | Strip `R`, panel Radius and the status show the **same** number each time (same text, `10 mm` / `1.5 mm`; the `.` is not dropped); Tab leaves the field and the next key goes to the viewport (key `3` → `Top view`, not `AF 10`). Enter uses the number on screen. The second click keeps the focus in the field and never prints `Selected face`. End at `10` |
| A11c | #205 #223 | Click one wrong edge; read the status; click it again. Then press **Enter** in the viewport at R10 (the apply of A11b) | Count rises then drops: status ends `— removed 179.8 mm line` (a length and kind). Enter with the two verticals: `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters — Fillet no longer armed` (not `Feature created`; **no** editor opens; Esc afterwards does not undo it). **Fillet is disarmed now (#223): the Modify Radius row is gone** and the next fillet needs the Fillet chip again |
| N3 | carry #223 r19-process | Note the x of the `Fillet` and `Chamfer` chips with the body selected; then with a face selected; then with Fillet armed. Note the right edge x of the left Modify panel in the same three states | Both chip x identical (±1 px) in all three states; the bar is fully below the menu row, never touches `Snap`, ends inside the window (wraps if needed); clicking the noted x arms **Fillet** every time. The Modify panel's width is the same armed and disarmed (±1 px; #223). Minor label overlap near `Name` is a note, not a failure, unless text is clipped. Armed with a **face** selected the chip row shows no edge count (by design: the face is not an edge pick) |
| A11d | #205 #223 r19-WP1 r19-WP8 | **Re-arm Fillet** (the apply in A11c disarmed it; if the part chip row is not showing click the body once, `Selected body …`, then click the `Fillet` chip). Click the strip `R` field, press **Ctrl+A**, type `1`, Enter (one call each), then key `3` (**must** read `Top view`: the field released the keys); click the **top face** once (inside it, away from edges, ≥ 8 px; not in the jaw slot); Enter. Then **re-arm again** (body selected → `Fillet` chip → strip `R` `1` Enter); key `8`; **one click on the bottom face, then move the pointer twice**; Enter | Face click (≥ 20 px from every edge): `Fillet: <n> edge(s) — …` with n ≥ 6 and no `0.0 mm line`. Both Enters: `Fillet <n> edges 1.00 applied — View ▸ Timeline to edit parameters — Fillet no longer armed` first try; never `No edges selected`; the body does not move and no `Moved body`; after each apply Fillet is disarmed and the Modify Radius row is hidden (a second Enter does nothing) |
| A11e | #205 #223 | **Re-arm Fillet** (as A11d, strip `R` `1`). Key `3`; **one click on the slot floor** (inside the slot outline, away from the rim); Enter. **Re-arm again**; strip `R` `1.5`, Enter; click the slot floor again; Enter. Esc | Click: `Fillet: <n> edge(s) — …` listing the floor's ≈150 mm lines and ≈15.7 mm arcs (not the neck loop `175.4 line, 42.2 line`). First Enter: `Fillet <n> edges 1.00 applied … — Fillet no longer armed`. The R1.5 Enter is **refused** and Fillet stays armed: `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius`. Esc → `Edge pick cancelled`; Fillet no longer armed; the Modify Radius row hides |
| A11f | r19-WP8 | Re-arm Fillet (body selected → `Fillet` chip; strip `R` `1`, Enter). Key `3`. Measure a neck corner (the vertical edge where the shaft meets the head) in physical px. (a) **First press 8–11 px** from the corner (place the pointer first, rule 64; `xdotool getmouselocation`); read the status. (b) Press the same spot again; read. (c) Esc. Re-arm; (d) first press **≤ 4 px** from the corner; read; Esc | (a) `Fillet: 1 edge(s) — …` (a single edge; **never `13 edge(s)`**); (b) the edge is removed (`… removed …`, count 0 or the status names the removal); (c) `Edge pick cancelled`; (d) `Fillet: 1 edge(s) — 10.0 mm vertical …`; Esc → `Edge pick cancelled`. If the first press says `Selected …` instead of a fillet status, copy its `[input-trace]` line (rule 67) |
| N15 | carry | Fillet not armed (after the Esc). (a) Click **empty ground** inside the part's sketch footprint; (b) click the **slot floor**; (c) click the **Fillet chip**; (d) Esc | (a)(b) status begins `Selected ` (or the selection simply changes); **never** `Editing sketch`, never a sketch entering edit mode, never a loft status. (c) `Fillet r=…` (armed). (d) `Edge pick cancelled` |
| N13 | carry | Part mode, no field focused (click empty viewport first): press `0`, then `3` | `No view for key 0 — use 1 2 3 4 6 7 8`; the camera did not move; `3` → `Top view` |
| N16 | r17-WP4 r19-WP5 | Click empty background so **nothing is selected** (status `Selection cleared`). Place the pointer on a **face of the body** (top face, ≥ 20 px from edges; write the pixel, rule 64) and do not touch the mouse again. In its own call run `date +%s.%N` (**T0**) and, in the next call, press `0`. Wait; read the label at each of 1 s, 3 s and 4 s with its own `date +%s.%N`. Then `grep status-trace $OUT/input-trace.log | tail -8`. **Second run:** repeat but, ≥ 0.5 s after `0`, move the pointer **off the body** onto empty ground and leave it there | The label reads `No view for key 0 — use 1 2 3 4 6 7 8` until 2.5 s (rule 46) and, with the pointer still, changes **by itself** by ~3.5 s to the hint `Face — click selects body first, click again for face · then Pull arrow` (the `[status-trace]` lines show `kind=result` then `kind=hint` ≥ 2.4 s later with no pointer motion). Second run: the result stays on the label and **no hint appears later**; after the pointer left the body the label ends on the result or the idle text, never the hint (`kind=idle` or `kind=result` as the last trace line) |
| N19 | carry #223 r19-WP6 | View ▸ **Timeline** on (already on from N8a: leave it). Click the body, click the `Fillet` chip; look at the left Modify panel; click the Radius field and type `2`; Esc | The Timeline does **not** cover the Radius field or any Modify panel control (they do not intersect; both fully inside the window); the click focuses Radius (field reads `2`); Esc → `Edge pick cancelled` and the Modify `Radius` row is **hidden** (no stale `Radius 1.5 / 2 mm` panel; #223). Fillet is not armed |
| N23 | r17-WP4 #223 | Timeline on. Click the body (it is selected: the part chip row shows `Group`, `Similar`, `Hole`, `Hole Wizard`, `Fillet`, `Chamfer` …). Read the left end of the chip row and the Timeline top **in physical px** (rule 54). Esc (deselect); click the body again | The chip row's left end (`Group` …) is fully visible, not covered by the Timeline; the Timeline sits **below** the chip row (top ≥ chip row bottom + 4 px on a 1280×800 screen; ≥ 6 physical px if the screen is 1920×1200) while the body is selected, both inside the window; with nothing selected the Timeline returns to the top of the left column; selecting again moves it below again. The chip row does not move (x unchanged ±1 px, N3). End with nothing selected |

End of chunk 5: Fillet disarmed, nothing selected, Timeline on, document dirty (`wrench-wip.sxp` is older).

---

### Chunk 6 — export, thickness, dirty flag, nut, lint (14 rows)

Start: end of chunk 5.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A12 | #188 | File → Export 3MF, type `wrench.3mf` (read back), OK | `Exported 3MF → $OUT/wrench.3mf`; checker wrench **28/28**, `flipX=False flipY=False`; open-shell / mesh warnings: none |
| N11 | #188 | File → Export 3MF, select all in the name field, type `wrench-noext` (no extension), OK | File `$OUT/wrench-noext.3mf` exists and `$OUT/wrench-noext` does not; status `Exported 3MF → …/wrench-noext.3mf`; checker wrench 28/28 on it |
| A13 | #207 #224 r19-WP8 | Timeline: **double-click** the base extrude (first Extrude, Distance 10). Do **not** click anything else. Read which control has focus (text selected in Distance). Type `1` then `4` (two key presses), read the field; Enter | The Distance field is focused with its text selected after the double-click. Keys `1` `4` land in the field: **no** `Front view` / `Back view` status (#224). Enter → `Preview: distance = 14.0` (and the part previews 14); the status never says `lost on rebuild`; the preview still shows the pivot hole, the open jaw and the fillets (not a plain slab); `grep -c "fillet soft-skip" $OUT/input-trace.log` (stderr) is `0` (rule 71) |
| A13b | carry #224 r19-WP6 | Timeline row of the base extrude: **double-click it with one call** `xdotool click --repeat 2 --delay 80 1` (pointer placed on the row name first, rule 64); read the focus. With the field focused press **Esc**; reopen the same way; type `14` as one burst, read it back, Enter; click empty viewport | Both presses of the double-click print `[input-trace] … drop:not-owner:*` (neither is `model-click`) and the Distance field is focused with its text selected **on the first try** (a dead first double-click is FAIL with the trace lines, rule 67). Esc: closes the panel; distance returns to 10 (`Edits cancelled`). Empty click: closes the panel and **keeps 14**; never `Editing sketch`. After either close the `Params (JSON, advanced)` row is **gone** (#224). The Timeline did not move between the two presses (top y equal ±1 px) |
| A13c | #187 | Export `wrench-t14.3mf`; run `thick … 14`; run the DIAG `wrench` | thick **7/7** incl. both `1mm … fillet at new T` rows. DIAG: prints `DIAG:` and the failures are **exactly** `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge`. Record every fillet row |
| N9 | #187 | (Same files.) Read the DIAG header triangle count and the other fillet rows | `head-shaft R10 fillet ±Y`, `R10 fillet not oversized`, `1mm fillet bottom outer edge` PASS (≈5760 tris; 2438 = fillets lost). No fifth failure |
| L7 | #200 #201 #225 r19-process | File → Save As `wrench-t14.sxp` (`Saved …`), then `stat -c '%y %s' $OUT/wrench-t14.sxp`; wait 2 s; Ctrl+S (`Saved …`); `stat` again (rule 65). (a) Timeline pencil on the slot sketch → `Editing sketch`; press **Exit Sketch** with **no edits** → `Sketch saved`. (b) Click the body, click the `Fillet` chip, click the strip `R` field, Ctrl+A, type `1.5`, **Enter** (commits the number, releases the keys), key `3`, click the slot floor, Enter (refused), Esc. (c) File → New | The second `stat` mtime is later than the first (Ctrl+S wrote the file; its status text equals Save As' by design). (a) `Sketch saved`, nothing in the Timeline changes. (b) Ctrl+A selects the field text, not faces; `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius` (**1.250**, not `0.250`, at T=14; #225), then `Edge pick cancelled`. (c) **No** `Discard unsaved changes?` dialog; `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| N8b | r17-WP4 r19-WP5 | File → Open: single-click `blank.sxp` in the list. In its own call run `date +%s.%N` (**T0**), then click Open. Place the pointer on the body (top face) at once and keep it **still** (write the pixel, rule 64). Read the label at 1 s and at 3.5 s (each with `date +%s.%N`); then `grep status-trace $OUT/input-trace.log | tail -6` | The Open button is enabled after the single click (one retry allowed, rule 2); `Opened $OUT/blank.sxp` stays on the label for 2.5 s (`kind=result`), then the hover hint appears with the pointer still (`kind=hint` ≤ 3.5 s after T0, rule 46/63); the blank is **framed** (whole body inside the canvas, ≥ 40 % of its width), not extremely zoomed in. No Discard dialog (the New document was clean) |
| N14 | #201 #225 r19-WP9 | Rail Sketch on the top face. Draw a Circle r `5` and one loose **Line** leaving an open end vertex. Set Cut / Blind / `2.5` (the finish-bar Op dropdown: one click opens, wait 1 s, one click chooses, rule 70; copy the `[popup-trace]` lines); click Extrude. Then Esc, Esc. **Before** moving the pointer over the part, write the RGB of one top-face pixel; move the pointer over the part, read it again (hovered); then move the pointer onto empty ground / a panel and read it a third time. Then File → New | Refusal reads `Line at (x, y) breaks the chain — delete or trim it`; **no UUID anywhere** in the status; Esc 1 is the ladder (`… — Esc again exits the sketch`), Esc 2 `Sketch saved`; the host face is not left selected **and its tan hover / selection tint is gone after the pointer moves off the part** (#225): the third RGB equals the first (±3 per channel). The Op dropdown opens on one click and stays open until the choice (`[popup-trace] show` with no `hide` before the choice). File → New **does** show the Discard dialog (real edit made) — press OK |
| A10 | #203 | New document, Sketch on ground: Circle r `50` (Ø100), Extrude Blind `10` (Distance field is `10` after typing, not `5` or a value left by an earlier tool). Rail Sketch on the top face: Circle r `45` (Ø90), Cut / Blind, Extrude | Exact status `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; the body is unchanged. The Circle Radius field shows its own last value, not `50` carried into a new document |
| A10b | carry | File → New (Discard OK); read the finish bar | `New` / `Blind` / Extrude enabled; Distance is the default (not `5`); `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| A14 | r17-WP2 | Rail Sketch on ground. **Polygon** (across flats), centre click; then L9 below; type `20` Enter; Circle r `5` at the centre; Extrude `7.5`; export `nut.3mf` | `Polygon AF 20.0000 — flats horizontal`; `Circle r=5.0000 (Ø10.0000)`; `Extrude Blind 7.5000 mm`; checker nut **7/7** |
| L9 | r18-WP1 r19-WP9 | In A14, after the centre click on the origin (status `Polygon — centre set, click a vertex or type the size`), hover at **three bearings** (20°, 70°, 110° from the centre) at the **same distance (≥ 150 physical px)** from the centre; read the status after each (one move, one read). Then at 70° hover at ≈ 100, ≈ 150 and ≈ 200 px. Do not click: the next action is A14's typed `20` | **Spec (decided):** the pointer sits on the **circumscribed circle** of the hexagon: the six corners lie on the circle through the pointer, the flats stay horizontal, and the status reads `Polygon AF <size> — flats horizontal — click to place (or type the size)` with `<size>` = √3 × the pointer's distance from the **polygon centre** (4 decimals). A vertex is under the pointer only at 0° / 60° / 120° …; at 20° and 110° the pointer is on the circle between two corners, **by design**. AF is **independent of the bearing**: three equal-distance hovers print the same AF to ±1.5 % (walker pixel error and the centre snapping to the origin within ~20 px are the only allowed spread; sx-038's 2 % was exactly that). Along one ray AF scales with distance: ≈ 100 : 150 : 200 px → AF in ratio 1 : 1.5 : 2 ±3 %. Keep the pointer ≥ 40 px off the horizontal and vertical lines through the centre (the H / V snap pulls it onto the axis within ~2 % of the view span). A click at a hover position would commit `Polygon AF <same size> — flats horizontal` (headless asserts it). Exact equality is asserted headless (`run_rung01_replan18_polyaf`). If it freezes: record the hovered control and status, repeat once with a second move (rule 34) |
| A15 | r17-WP5 r17-WP6 r18 r19 | Run the commands of **the A15 section** below, in order: `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; the five headless walks; the nine `replan19` suites; `make test-godot`; `make test-godot-known-red` | Every output equals the table in the A15 section (lint `9 replan19 scripts are clean`, `lint_suites: 195 suites ok …`, wrench walk `0 failures` ≥ 729 checks, **`make test-godot` ends `suites: 191 run, 0 failed`** (n ≥ 191), known-red unchanged). Record every line in WALK_LOG |

End of chunk 6: all five checkers run; record every status line and checker table in WALK_LOG.

---

### Row index (72) → origin

A1 A2 A3 A4 A5 A5b A6 A7 A7b A8w A8 A8b A9 A9b A9c A10 A10b A11a A11b A11c A11d A11e A11f A12 A13 A13b A13c A14 A15 A16 A17 — **31 A rows**. L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 — **12 L rows**. N1a N1b N2 N3 N4 N5 N6 N7 N8a N8b N9 N10 N11 N12 N13 N14 N15 N16 N17 N18 N19 N20 N21 — **23 N rows (sx-035 to sx-037)**. N22 window, N23 Timeline vs chip row, N24 sketch drag-box, N25 DOF chip after undo, N26 glyphs on their vertices — **5 rows (sx-038)**. A8w wide first jaw, N21b wall clicks, A11f first fillet pick near a corner — **3 rows (sx-040)** (A8w and A11f are A rows, N21b an N row). 31 + 12 + 23 + 5 + 1 = 72 (A 31, L 12, N 29). The "Check" column of a row names the merged PR(s) it re-verifies; `r17-WPn` / `r18-WPn` / `r19-WPn` is a work package of that re-PLAN, `r19-process` a wording or protocol change only.


---

### A15 — headless and lint evidence (chunk 6, last row)

Run on the walk box from the repo root of the commit under test (`make build` first; `CMAKE_PREFIX_PATH=/opt/occt-8.0.1`, `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` where the box needs it). Write each command's last lines in WALK_LOG. Nothing here is walked by hand: the verdict is the printed text.

| # | Command | Must print |
|---|---|---|
| 1 | `python3 tools/lint_rung01_e2e.py` | `<N> replan16 scripts are clean` (N ≥ 7), `<N> replan17 scripts are clean` (N ≥ 8), `<N> replan18 scripts are clean` (N ≥ 1) and **`9 replan19 scripts are clean`** (exactly the nine new suites; more is fine only if the BUILD PR lists why) |
| 2 | `python3 tools/lint_suites.py` | `lint_suites: 195 suites ok (52 ci, 139 full, 4 known-red)` (n ≥ 195) |
| 3 | `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` | `0 failures`, ≥ 729 checks |
| 4 | the same with `tests/run_rung01_replan16_walk.gd` and `tests/run_rung01_replan17_walk.gd` | `0 failures`, `WALK-SUMMARY stages=8 first_red=none` for each |
| 5 | the same with `tests/run_rung01_replan18_polyaf.gd` | `0 failures` |
| 6 | the same with each of `tests/run_rung01_replan19_{keys,shield,jaw,glyphs,hint,timeline,camera,fillet_pick,polish}.gd` | `<n> checks, 0 failures` with n ≥ 90, 30, 60, 80, 30, 40, 25, 40, 40 |
| 7 | `make test-kernel` | all Catch2 cases pass, including the new stale-uuid / face-cue log case (WP8) |
| 8 | `make test-godot` | ends **`suites: 191 run, 0 failed`** (n ≥ 191; baseline `main` `7062ffb` is `182 run, 0 failed`) |
| 9 | `make test-godot-known-red` | prints each of the same four known-red suites with its `reason=` and exits 0 (no suite is added to or removed from known-red by this plan) |

A15 is PASS only if every line holds. A red suite is named with its output in WALK_LOG, and the row is FAIL even when every walked row passed.

### Pass bar for sx-040

Score ≥ 9 / 10; every A / L / N row PASS (a row that is soft-GL only is PASS **with** the rule-49 evidence; a row walked with a batched action is void until redone); checkers `tools/check_rung01.py` (never `--allow-mirror`): blank 5/5, wrench 28/28 with `flipX=False flipY=False`, wrench-noext 28/28, thick 14 7/7, DIAG on `wrench-t14.3mf` failing exactly the four by-design rows, nut 7/7; headless walks 0 failures; `make test-godot` ends `0 failed`; lints clean; fillets succeed on the first try; the Slot is a real Slot. Carry-over rule: a regression of #217, #218 or #222 or of an r19 WP is named in WALK_LOG and fails the walk even when the rest passes.

## Out of scope for this plan

Decided here so no later agent reopens them; each has its reason in the triage or in decision 13.

- The engine's `ERROR: Signal 'focus_entered' is already connected …` / `Attempt to disconnect a nonexistent connection …` lines (F2 item 11): they come from Godot's popup handling, do not change behaviour and are only counted (rule 71). Fixing them would mean replacing `PopupMenu` / `OptionButton`.
- Any change to `docs/plan/STATUS.md`, `docs/plan/roadmap.md` or other docs: the BUILD PR describes itself in its body; the status document is updated by the loop after the walk.
- Windows and macOS CI (`windows-export`, `macos-kernel`, ~2 h): not awaited, not changed; the quick gates (linux kernel, godot-smoke, website-demos) are the merge bar.
- Product changes that the triage marked **DESIGN**: the rail has no Sketch button while a body / face is selected; two-stage body → face pick; neutral badge colours; Δv only on non-axis-aligned entities; the ` AF` blank text and the yellow pad of a saved sketch; Ctrl+S printing the same text as Save; `F` versus `Shift+F`; zoom in / out not being exactly reversible.
- The N14 Op-dropdown beyond the `[popup-trace]` lines and the tint fix: if the dropdown still closes early after WP9 the trace decides the next plan; no speculative rewrite.
- New tools, new constraint types, new features or UI restyling of any kind; per-WP prompt files; extra BUILD or walk agents; the two unregistered suites `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd`; the `.uid` files that Godot writes into `game/tests/`.
- Any edit of `packaging/ci/run_godot_suites.sh`, the Makefile `test-godot` recipe or CI workflows. New suites are added only as `packaging/ci/suites.d/<name>.suite` manifests.
