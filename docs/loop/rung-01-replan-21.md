# Rung 1 re-PLAN 21 — sx-041 bridge walk findings and the runner-evaluable sx-042 checklist (UBC ECE Exercise 2 wrench + nut)

Status: planned. Docs only. Baseline: `main` `bb13358675fc8ab4212225048e66a84fd4bf0ace` (PR #236, the automation bridge and `tools/walk_rung01.py`; verified with `git ls-remote origin refs/heads/main` when this plan was written). Previous plans: [`rung-01-replan-20.md`](rung-01-replan-20.md) (#235; the sx-041 checklist this plan keeps row for row), [`rung-01-replan-19.md`](rung-01-replan-19.md), [`automation-bridge.md`](automation-bridge.md) (the bridge and runner contract). Next walk: **sx-042** = `tools/walk_rung01.py` on a local Linux build, **no screenshot walker**: the checklist embedded below has 77 rows (75 + the two variant rows), every one judged by the runner from bridge state and `[…-trace]` lines. Work packages: **eight, sequential, for ONE grok BUILD agent that implements all of them in order in a single PR, plus one integration step** (this file is the only prompt: no per-WP files, no parallel waves).

## Where we are

Round sx-041 was walked twice on the same code. The screenshot walk (build `6d0e3b61`, chunks 1–3 through N21, `WALK_LOG_fa3e.md`) was ruled too slow, so #236 added `SX_AUTOMATION=1`, `tools/sxdrive.py` and `tools/walk_rung01.py`. Its full run on `0f1ea29` (**526.6 s**, 77 rows incl. the A8b / A9 variant rows) gave **68 PASS / 6 FAIL / 3 PARTIAL (visual-only) / 0 runner-gap**: blank 5/5, nut 7/7, but wrench **19/28** (`wrench.3mf`, `wrench-noext.3mf`), 16/28 (`wrench-t14.3mf`, DIAG) and thick **4/7**. The six FAILs are N16, A12, N11, A13, A13c and the A8b variant; the three PARTIALs are N26, N24 and A11a.

**The key finding of this plan: five of the six FAILs are runner-fidelity defects, not product defects, and the sixth is a real product defect with a verified root cause.** The runner does not do what the headless wrench script (`run_rung01_wrench.gd`, 702 checks, 0 failures, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22 on `main`) does, and what it does differently is exactly what the checkers measure:

1. **Stray bodies.** The runner's `wrench-t14.sxp` holds **three bodies**: `extrude 2` (the wrench, 43979.75 mm³), `Box 1` (4178.8 mm³, a primitive from N16's blind `click(screen=[60, 680])` that lands on the palette's Box button) and `extrude 12` (866.0 mm³, `sketch 11` + `extrude 12`, a hexagonal prism). **Both appear in the document right after N16** (P2b). Every exported 3MF contains all three, which is why `bbox X` reads **237.499** (want 232.5), `pivot hole diameter` reads 5.0 (want 10.0), `jaw floor through head centre` reads 6.492, thick `bbox Z` reads **11.0**, and which shifts the coordinates every other probe of the checker samples.
2. **Incomplete fillets.** The runner's fillet features are `fillet 7` (**one** R10 neck edge: `A11b` picks `hits[0]`), `fillet 8` (the **slot-floor** loop: `top_face()` takes the face with the highest centroid z, and the outer top face's centroid lies inside the slot, so the click lands on the slot floor), `fillet 9` (bottom) and `fillet 10` (**one** 150 mm lip edge at `(93.5, −5, 10)` from `A11e`). Missing against the headless set: the second R10 neck (`head-shaft R10 fillet +Y/−Y`), the outer top face with the jaw top edge (`1mm fillet top outer edge`, `1mm fillet on jaw top edge`).
3. **An order bug in A13.** `A13` types 14 + Enter (`Preview: distance = 14.0`), then `A13b` and `A13d` press Esc, and `PropertyPanel.cancel_edits` undoes every un-committed preview write (`property_panel.gd` 770–785). The thickness is back at 10 before `A13c` exports it.

With the product untouched and those three things done the way the headless walk does them (probes P3–P7 below) the runner reaches **wrench 28/28 `flipX=False flipY=False`, DIAG 18/22 with exactly the four by-design rows, thick 14 7/7, and no `[ERROR] fillet soft-skip` line**.

The real product defect is **A8b-variant**: Exit Sketch, reopen with the Timeline pencil, Esc, Esc (`Sketch saved`), then part Ctrl+Z leaves `sketch 3` in the Timeline. It takes **two** Ctrl+Z: a no-op reopen/exit pushes a graph undo entry because `exit_sketch` compares the sketch snapshot **string** to the baseline and the solve in `_activate_session` changes the last digits of the parameters (P8). This is also the best lead for the `-135°` label of the screenshot walk (Decision 8).

Pass bar for sx-042 (unchanged): score ≥ 9; every row PASS; checkers blank 5/5, wrench 28/28 with `flipX=False flipY=False`, wrench-noext 28/28, thick 14 7/7, DIAG on `wrench-t14.3mf` failing **exactly** the four by-design rows (18/22), nut 7/7 (`tools/check_rung01.py`, never `--allow-mirror`); headless 0 failures (`make test-godot` ends `suites: <n> run, 0 failed`, lints clean). New in this plan: the report has **no PARTIAL and no runner-gap row** (the three visual PARTIALs become state clauses, WP7) and **no vacuous clause** (WP1, WP8).

## How this plan was measured (not guessed)

All probes ran on `main` `bb13358` on the PLAN box (Linux, Xvfb `DISPLAY=:1`, soft GL; the `linux-test-build` prerelease libraries in `game/bin/`; `tools/godot/godot` 4.7-stable; `SX_AUTOMATION=1`). `tools/walk_rung01.py` was driven both as shipped (a full 77-row walk: 663.97 s, 67 PASS / 7 FAIL / 3 PARTIAL; the extra FAIL is N4, see P1) and as a library (`Walk(...)`, `w.launch()`, `w.open_file(...)`, `w.run_row(...)`) from throwaway scripts that are **not committed** (this PR is docs only). Probe outputs are attached to the PR body. A probe never shares `--out` with another one (they all write `input-trace.log`).

| # | Probe | What it did | Result |
|---|---|---|---|
| P1 | **Full runner walk on `main`** (`python3 tools/walk_rung01.py --out /tmp/full1`) | 77 rows | `PASS 67, FAIL 7, PARTIAL 3`. FAIL: N4, N16, A12, N11, A13, A13c, A8b-variant-walk. A12 / N11 `19/28` (`bbox X 237.499`, `pivot hole diameter 5.0`, `jaw open through full depth`, `jaw floor through head centre 6.492`, `head-shaft R10 fillet +Y / −Y`, `1mm fillet bottom outer edge`, `1mm fillet on jaw top edge`); A13c thick `4/7` (`bbox Z 11.0`, `jaw still through`, `grip slot open from the top floor=8.5`); A13 `count=1`. **N4** failed its `saved sketch` clause with `First point dropped — Esc again exits the sketch \| Face — click selects body first, click again for face · then Pull arrow`: the second Esc's `Sketch saved` was replaced by the hover hint before the runner read the live status label (the OCCT build of the PLAN box was running at the time; the bridge run on `0f1ea29` passed N4). The runner reads **`status`**, a live label, where it should read the `[status-trace] kind=result` line since its mark |
| P2 | **What is in the exported document** (`unzip -p wrench-t14.sxp cards/*.md`, `features.json`) | read every body card and the feature timeline of the walk's `wrench-t14.sxp` | three bodies: `extrude 2` (34 faces, volume 43979.75), **`Box 1` (13 faces, 4178.8 mm³)**, **`extrude 12` (8 faces, 866.03 mm³)**. Timeline: `sketch 1, extrude 2, sketch 3, extrude 4, sketch 5, extrude 6, fillet 7, fillet 8, fillet 9, fillet 10, sketch 11, extrude 12`. `fillet 7` has **1** edge (`e2f725db…`, point `(179.84, 10, 5)`, dir Z, R10); `fillet 8` edge cues at `(93.5, ±5, 7.5)` (the **slot floor**); `fillet 9` at z = 0 (bottom); `fillet 10` **1** edge at `(93.5, −5, 10)`, R1. And the **A13 commit status** of that walk: `Preview: distance = 14.0 — fillet 10: all 1 edges lost on rebuild — it changes nothing now` (the source of the `[ERROR]` line, P7) |
| P2b | **Which row adds the stray bodies** (`/tmp/probe_bodies.py`: open the walk's `wrench-wip.sxp`, then `run_row` for A11b … N23 in the runner's order, printing `bodies` and the last four timeline names after each row) | | `A11b` … `N15`, `N13`: bodies `['extrude 2']`, timeline ends `fillet 7 … fillet 10`. After **`N16`: bodies `['extrude 2', 'Box 1']` and the timeline ends `fillet 9, fillet 10, sketch 11, extrude 12`**; `N19`, `N23` leave them. (In the same run `A11d` read `Fillet: 4 edge(s) — 150.0 mm line, 15.7 mm arc, …`: its "top" fillet is the 4-edge slot-floor loop; `A11e` read `Fillet: 1 edge(s) — 150.0 mm line`, `Fillet edge 1.00 applied`; `A11f` `Fillet: 1 edge(s) — 9.1 mm line`.) So N16's blind `click(screen=[60, 680])` is the single source of both strays |
| P3 | **Which view picks the necks** (`/tmp/probe_neck.py`: `wrench-wip.sxp`, `_arm_fillet`, view key, `d.click(edge=<id>, along=0.5)`, status, Esc Esc; both vertical neck edges `e2f725…` at `(179.8, +10, 10)` and `70e4ba…` at `(179.8, −10, 10)`) | views `3` (Top), `1` (Front), `6` (Right), `7` (iso) | `3`: neck +Y → `Fillet: 1 edge(s) — 10.0 mm vertical`, **neck −Y → `1 edge(s) — 179.8 mm line`** (wrong edge); `1` and `6`: both `10.0 mm vertical`; `7`: neck +Y → **`32.3 mm arc`**, neck −Y `10.0 mm vertical`. So the runner's top-view pick of the second neck can never work, and the **same pick by a user in top view** returns the long line (a product defect candidate, P9) |
| P4 | **The headless fillet set done by the runner** (`/tmp/probe_fillet5.py` from the walk's `wrench-wip.sxp`: key `6`, both necks `d.click(edge=…, along=0.5)`, type `10`, Enter, key `3`, Enter = apply; then `_arm_fillet`, `1`, Enter, key `3`, `click(model=[200,−16,10])`, Enter; key `8`, `click(model=[50,0,0])`, Enter; key `3`, `click(model=[93.5,0,7.5])`, Enter; `export_3mf` + checker after each step) | the four applies | after R10: `Fillet 2 edges 10.00 applied`, wrench **24/28**; after top: `Fillet: 15 edge(s) — 174.4 mm line, 9.1 mm line, 31.4 mm arc, …` / `Fillet 15 edges 1.00 applied`, **26/28**; after bottom: `Fillet 11 edges 1.00 applied`, **27/28**; after floor: `Fillet: 4 edge(s) — 150.0 mm line, 15.7 mm arc, 150.0 mm line, 15.7 mm arc` / `Fillet 4 edges 1.00 applied`, **28/28 passed**; one body `extrude 2` `[-10, -22.5, 0] → [222.5, 22.5, 10]` |
| P5 | **A13 / A13c on that document** (`/tmp/probe_fillet7.py`, rows in the runner's order `A13, A13b, A13d, A13c`, Timeline shown first) | | `A13` PASS (**0** `[ERROR] fillet soft-skip` lines; the only `ERROR` in the log is the engine's `status < 0 … ERR_CANT_OPEN`), `A13c` **FAIL thick 5/7**: `bbox Z got 10.0 want 14.0`, `grip slot open from the top floor=7.5` (the 14 was rolled back by A13b's Esc) |
| P6 | **A13 in the order `A13b, A13d, A13, A13c`** (`/tmp/probe_fillet7.py` re-ordered, `/tmp/p8`) | | `A13` PASS, `A13d` PASS, **`A13c` PASS thick 7/7** (`bbox Z got 14.0`, `jaw still through at new T`, `grip slot open from the top`, `1mm top fillet at new T`, `1mm jaw top fillet at new T`) and `check-wrench-wrench-t14.txt` **`18/22 passed`**: the four failing rows are exactly `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge` (the by-design four); 0 soft-skip `[ERROR]`. So **A13c is not a product defect** and neither is the thick rebuild |
| P7 | **Why the A13 grep found `1`** | read `ops_dress.cpp` `resolve_dressup_edges` (680–686) and P2 | a fillet whose only edge is gone after the upstream thickness edit (here the single lip edge `fillet 10`, recorded at z = 10, while the top moved to z = 14 and no `face_cues` exist for a lone edge) writes `sx::log::error("fillet soft-skip: 1 edges lost on rebuild")` **and** `graph.add_warning(…)` (the user-visible `— fillet 10: all 1 edges lost on rebuild — it changes nothing now`). The same condition is therefore a warning for the user and an `[ERROR]` in the log. The faithful fillet set (P4) has no single-edge fillet, so the line disappears (P6); the level is still wrong for a documented, non-fatal degrade (Decision 9) |
| P8 | **A8b variant, reproduced and root-caused** (`/tmp/probe_a8b.py`: `build_open_jaw`, Exit Sketch, `_reopen_sketch3`, Select, wall click at 40 %, Esc, Esc, then Ctrl+Z three times with `tl()` after each; a temporary `print` in `exit_sketch`, since reverted) | | `exit1 'Sketch saved' [sketch 1, extrude 2, sketch 3]`; `reopen 'Editing sketch'`; `esc2 'Sketch saved'`; **`undo1 'Undo' [sketch 1, extrude 2, sketch 3]`**, **`undo2 'Undo' [sketch 1, extrude 2]`**, `undo3 'Undo'` unchanged. So **two** Ctrl+Z are needed: the exit after a no-op reopen pushed a graph snapshot. Instrumented: `PROBE-A8B snapshot differs at 4433 len 4993 vs 4979` and the two strings differ only in the printed digits of the jaw parameters: baseline `194.169064849386, -19.97307077434498, 219.973070774345, …`, session `194.16906484938613, -19.973070774344936, 219.97307077434505, …` (15 vs 17 significant digits). `begin_edit` stores `_edit_baseline = loaded.snapshot()` (`sketch_mode.gd` 625), `_activate_session` runs `refresh_dof_state()` (a solve), and `exit_sketch` (828) tests `sketch.snapshot() == _edit_baseline` as a **string**, so any solver round-off turns a no-op into an `update sketch` undo entry. (The main A8b row passes because the sketch was never reopened.) With Ctrl+Z then Ctrl+Shift+Z then the A9 variant steps the labels read `['45°', '5', '22.5', '20']`: the redo path alone does not produce `-135°` |
| P9 | **Why the −Y neck pick fails in top view** (read `document_view.gd` 1301–1330, `_polyline_screen_nearest` 1350–1370, `_edge_point_visible` 1375–1390 against P3) | | `edge_near_screen` ties two edges within `EDGE_PICK_SCREEN_TIE_PX` (8) and prefers the one most parallel to the view ray, which should make the end-on vertical beat the 179.8 mm line. But `_polyline_screen_nearest` returns the **first** sample of an end-on edge (every sample projects to the same pixel, `d < best` is false for the rest), and `_edge_point_visible` then ray-tests **that** point against the body: for a vertical edge whose polyline starts at z = 0 the point is **under the body** in top view and the edge is skipped, so the line wins. Which neck loses depends on the edge's polyline direction (+Y neck works, −Y does not). **Hypothesis from code reading, to be confirmed in WP5's red step** (print `near["point"]` and the visibility result for both necks) |
| P10 | **N16, read from the runner** (`row_N16`, `main.gd` `_hint_tick`, `viewport_interaction.gd` `_update_hover` 3481–3548) | | the runner's first line is `self.click(screen=[60, 680])`: a blind pixel that is the palette's **Box** button on this layout (P2: `Box 1`). A body is then **selected**, and `_update_hover` emits the Face hint only when **nothing is selected**, so after key `0` (`No view for key 0 — use 1 2 3 4 6 7 8`, `kind=result`) there is never a `kind=restore`. The product behaviour (result → restore after `STATUS_HOLD_MS`) is unchanged and tested headless (`rung01_replan19_hint`, 30 checks). The row's last clause (`leave clears hint`) ends in `or True` |
| P11 | **N24 box colour** (`automation_bridge.gd` 370–390 vs `viewport_interaction.gd` `_draw` 4520–4527) | | the product draws the **fill** green for a crossing box (`Color(0.35, 0.85, 0.45, 0.18)`) and the **edge** the same blue for both (`Color(0.35, 0.6, 0.95, 0.85)` = `[89, 153, 242, 217]`, the value the PARTIAL printed). `_box_paint` in the bridge **re-declares both constants** instead of reading the product's, and the runner's `green` test looks at the edge, which is blue by design. So N24's `box colour` is unmeasurable as written, and the bridge copy could drift from the product |
| P12 | **N26 / A11a state that exists** | read `sketch_mode.gd` 8505–8560 and 8735–8755 (`glyph_debug`), `automation_bridge.gd` 1676 (`_collect_glyphs`), `row_A11a` / `row_N18` | `sketch_mode.glyph_debug()` already returns `cid`, `type`, `offset_px`, `leader` (`offset_px ≥ GLYPH_LEADER_MIN_PX` 12), `anchor` and `pos` per badge, and the leaders are one `GlyphLeaders` `MeshInstance3D` of triangle ribbons, but `_collect_glyphs` forwards only `type`, `rect`, `occluded`. The `camera` and `project(model=…)` bridge commands already give the part-mode top-view pose and the projected pivot / head, which is all A11a / N18's "camera does not jump, head and pivot ±5 px" needs |
| P13 | **Vacuous clauses in the runner** (`grep -n "or True\|and True" tools/walk_rung01.py`, the clause names in `walk_report.json`) | | `L5` `HUD Frame` (`… or True`), `N24` `enclose` (`(blue or True)`), `N16` `leave clears hint` (`… or True`), `N16` / `N8b` `headless-only hold`, `N9` (`name.split()[0] in text or "PASS" in text`, true for any file with one PASS), `A13c` `DIAG` (`"DIAG:" in text`, true for any non-T10 file), `A15` `headless tier` (`True`, "skipped inside the GUI walk"). Seven clauses can never fail |
| P14 | **-135° (screenshot walk L4 / N1a), three tries** | (a) `_jaw_clicks(-10)` A8 jaw, width 20, angle 45, circles, line, Power Trim (the runner's A9 / variant); (b) the same after Exit + pencil reopen + wall click + Esc Esc + Ctrl+Z + Ctrl+Shift+Z (`/tmp/probe_a8b2.py`); (c) a mirrored jaw (`_jaw_clicks(+10)`) with the same circles / line / trim (`/tmp/probe_mirror.py`) | labels `['45°', '5', '22.5', '20']` (a, b) and `['20.0152', '45°', '5', '22.5']` (c): **never `-135°`**. The screenshot walk's history differs in N5 (Ctrl+Z to `Nothing to undo`, redo), A8w + Delete-all, the N8a reopen and its A8b Ctrl+Z (which in that walk also left `sketch 3`: the same P8 defect); so the sign flip is **unreproduced** and Decision 8 handles it in two layers |
| P15 | **Baselines** | `python3 tools/lint_suites.py`; `python3 tools/lint_rung01_e2e.py`; `tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd` | `lint_suites: 203 suites ok (57 ci, 142 full, 4 known-red)` (so `make test-godot` runs 199); `9 replan19 scripts are clean`, `7 replan20 scripts are clean`; wrench walk **`702 checks, 0 failures`** in 45.8 s with `7/7 passed`, `28/28 passed` ×2, `18/22 passed` and the only `[ERROR]` lines the intended refusals (`fillet 10: fillet failed (limit 1.250; 150.000 mm line at (93.500, 5.000, 7.500))`, `regenerate stopped at feature fillet 10` / `extrude 2`, `edit sketch: extrude 2: profile: profile has an open loop`), 0 `soft-skip` errors (78 `[DEBUG]` lines) |

### The runner gap (RC1), read from the code

| Aspect | `tools/walk_rung01.py` (sx-041) | `run_rung01_wrench.gd` (702 / 0) |
|---|---|---|
| Bodies in the export | whatever N16 left (3 bodies, P2 / P2b) | exactly one body; `measure_bbox(body)` is asserted (`thick bbox Z is 14`) before the export |
| R10 neck | `A11b`: `click_edge_near(vertical_neck)` → `hits[0]`, **one** edge, in **top** view (the −Y neck cannot be picked there, P3) | `_fillet_neck` on **both** necks, then `R10` applied once (`head-shaft R10 fillet ±Y`) |
| Outer top face + jaw edge | `A11d`: `top_face()` = highest-centroid face = **slot floor** (P2 `fillet 8`) | `_fillet_face(… Vector3(200, −16, 10) …)`: a **model-point** click on the outer top: 15 edges including the jaw top edge |
| Bottom | `bottom_face()` (ok) | `(50, 0, 0)` after key `8` |
| Slot floor | `A11e`: one `slot_floor` edge, R1, then a refused R1.5 (leaves a 1-edge `fillet 10`) | `_fillet_face(… (93.5, 0, 7.5) …)` = the 4-edge loop; the R1.5 refusal is a separate attempt that leaves no feature |
| Thickness | `A13` Enter = preview, `A13b` / `A13d` Esc = **roll back**, then export | `_type_timeline_distance` + `_timeline_panel_dismiss` (commit), then export |
| Status reads | live `status` label (races the hover hint, N4) | `main.status_trace_log` |
| Row semantics | 7 clauses that cannot fail (P13) | every `check` can fail |

## Triage of every finding

Classes: **PRODUCT** = a code defect, fixed in a WP; **RUNNER** = a defect of `tools/walk_rung01.py` (what it does or what it asserts), fixed in a WP; **DESIGN** = decided as intended; **LOG** = noted, deliberately not fixed (see "Out of scope"). Every row has a reason and a destination. `WPn` means this plan's.

### Every non-PASS result (6 FAIL, 3 PARTIAL in the bridge run; N4 in the PLAN run)

| Row | Verdict (bridge run on `0f1ea29`, evidence verbatim) | Class | Root cause | Goes to |
|---|---|---|---|---|
| A12 | FAIL: `Exported 3MF`; wrench **19/28**; `1mm fillet on jaw top edge got want outside` | **RUNNER** | P2 / P4: three bodies in the export (`Box 1`, `extrude 12`), one R10 neck instead of two, the slot-floor loop instead of the outer top face. With the headless fillet set on one body: **28/28** (P4) | WP1 (bodies), WP2 (fillets) |
| N11 | FAIL: `wrench-noext.3mf` created, no extensionless file; **19/28**, same jaw-top miss | **RUNNER** | same document as A12; the filename clause passes | WP1, WP2 |
| A13c | FAIL: thick **4/7**: `bbox Z got 11.0 want 14.0`, `jaw not through`, `grip slot not open from the top` | **RUNNER** | P5 / P6: (a) `Box 1` raises the bbox to z = 11, (b) A13b / A13d Esc roll the 14 back to 10, (c) the stray bodies move the jaw / slot probes. Corrected order on one body: **thick 7/7, DIAG 18/22** | WP1, WP2 |
| N9 | PASS in the report, but its three clauses are vacuous (P13) | **RUNNER** | `name.split()[0] in text or "PASS" in text` | WP1 |
| A13 | FAIL: `[ERROR] fillet soft-skip: 1 edges lost on rebuild` (count 1) | **RUNNER** + **PRODUCT** (log level) | P2 / P7: the single-edge `fillet 10` of A11e loses its edge when the thickness changes (a documented, user-visible warning: `— fillet 10: all 1 edges lost on rebuild — it changes nothing now`) and the kernel also logs it at `error`. 0 errors with the faithful fillet set (P6) | WP2 (no 1-edge fillet), WP6 (level) |
| N16 | FAIL: key 0 logs only `kind=result text=No view for key 0 — use 1 2 3 4 6 7 8`; no hint or restore | **RUNNER** | P10: blind click on the Box palette button selects a body, which suppresses the hover hint; the product restore works with nothing selected | WP1 |
| A8b-variant-walk | FAIL: Exit Sketch, pencil (`Editing sketch`), wall click, Esc, Esc, Ctrl+Z → `Undo`, `sketch 3` still in the Timeline | **PRODUCT** | P8: `exit_sketch` compares snapshot strings; the activation solve changes the 16th–17th digits; a no-op reopen / exit pushes an `update sketch` undo entry. Two Ctrl+Z needed | WP3 |
| A9-variant-walk | PASS: `Trimmed open jaw`, drawn labels `45°`, `5`, `22.5`, `20`; did not draw `-135°` | — | P14: not reproduced in three histories | WP4 (pin) |
| N26 | PARTIAL (visual): `badge leaders` (9 glyphs) | **RUNNER** + state exposure | P12: `glyph_debug()` has leader data; `_collect_glyphs` drops it | WP7 |
| N24 | PARTIAL (visual): crossing-box edge colour `[89, 153, 242, 217]` | **RUNNER** (+ bridge copy) | P11: the edge is blue by design, the crossing differs by **fill**; the bridge re-declares the colours | WP7 |
| A11a | PARTIAL (visual): `top before slot` | **RUNNER** | P12: the "same top view" is a projection compare, not a screenshot | WP7 |
| N4 | PLAN-run FAIL (not in the bridge run): `saved sketch` read `Face — click selects body first …` | **RUNNER** | P1: live-label read races the hover hint (the strays are N16's, P2b, not N4's) | WP1 |
| A15 | PASS, but `headless tier` is `True` "skipped inside the GUI walk" (P13) | **RUNNER** | the pass bar says `make test-godot` ends `0 failed`; the runner never runs it | WP8 |

Class counts: **RUNNER** 11, **PRODUCT** 2 (A8b-variant undo, soft-skip level), **PRODUCT candidate** 1 (end-on edge pick, P9), **DESIGN** 0.

### Root causes

| RC | What | Rows | Class | Disposition |
|---|---|---|---|---|
| RC1 | **The runner exports a document that is not the wrench**: stray `Box 1` and `sketch 11` / `extrude 12`, both from N16's blind click (P2b) | A12, N11, A13c (and every checker run after N16) | **RUNNER** | **WP1**: a body guard (`S0`) at every export, N4 / N16 post-conditions, no pixel literals |
| RC2 | **The runner's fillet set is not the handout's** (one neck, slot floor for "top", a 1-edge lip fillet, top-view neck pick) and **A13 / A13c rolled the thickness back** | A12, N11, A13, A13c, N9 | **RUNNER** | **WP2** |
| RC3 | **A no-op reopen / exit pushes a graph undo entry** (snapshot string compare vs solver round-off) | A8b-variant (and the screenshot walk's A8b) | **PRODUCT** | **WP3** |
| RC4 | **`-135°`**: a sign / orientation fallback in the jaw angle record, trigger unproven | L4, N1a (screenshot walk) | **PRODUCT** (latent) | **WP4**: normalise + pin |
| RC5 | **End-on edge pick can return the line instead of the vertical** | A11b-top (N2 / N3 flows) | **PRODUCT** candidate | **WP5** |
| RC6 | **A documented, non-fatal degrade is logged `[ERROR]`** | A13 | **PRODUCT** (log level) | **WP6** |
| RC7 | **Visual-only clauses** (N26, N24, A11a) and **vacuous clauses** (P13) | N26, N24, A11a, L5, N16, N9, A13c, A15 | **RUNNER** | **WP7** (state), **WP1 / WP8** (vacuous) |

### Comparison to sx-041

The sx-041 screenshot walk could not finish (chunks 1–3, 4 h) and found `-135°`; the bridge run finished in 526.6 s and found six FAILs, of which one is product (A8b variant). Re-PLAN 20's work packages hold in the runner: A8r / A8w / A8 (drawn `0°` → `45°`), A9 (no orphan `V`), N21b (**9 of 9 walls free**; screenshot walk 8 of 9), N24b (Shift-add), A17 (rail), N10 (tag), L12 (`20.16 Δu 14.25 Δv 14.25`, click clears), A13d (a typed prefix writes nothing: `prefix silent` PASS).

### What is deliberately not a WP (LOG)

A single-edge fillet losing its edge when an upstream edit moves the edge (naming limitation; the warning is the design, Decision 9); the engine's signal-connection noise; the soft-GL squashed circles; `windows-export` / `macos-kernel`.

## Decisions (final — the BUILD agent does not choose)

1. **Scope and shape.** Eight WPs, **sequential, one grok agent, one PR**, in the order below, plus one integration step. Every WP's step 1 is a **failing** repro (a runner row that is red, or a new headless suite that is red on the untouched code); its red output goes in the PR body, then the fix. If a WP's own check is red, fix it before starting the next WP; the full tier runs after WP3 and at the integration step.
2. **The runner is the walker.** sx-042 is `python3 tools/walk_rung01.py --out $OUT` on a local Linux build (`BUILDINFO.txt` `commit=` equals the sha under test), **no screenshots as evidence**. A screenshot may be written as an artefact on a FAIL; it is never a verdict. The report must show `PASS 77` and no `PARTIAL`, `BLOCKED` or `runner-gap`.
3. **Body guard.** A new runner step `S0` (not a row; a clause group attached to every export row: A5, A12, N11, A13c, A14) asserts, from bridge `bodies`, **exactly one body** before it exports; for the wrench exports (A5, A12, N11, A13c) its name starts `extrude` and its bbox is `232.5 ± 0.3` × `45 ± 0.1` × `T ± 0.01` (T = 10, or 14 after A13); for the nut (A14) only the body count is asserted. A violation is `FAIL runner-gap: stray body <name> (<volume>)` naming the body and the row that left it, **not** a checker FAIL. N4 and N16 each assert `bodies` and `timeline` are unchanged by the row.
4. **No pixel literals.** Every `click(screen=[x, y])` with literal numbers in the runner is replaced by a bridge selector (`target=`, `model=`, `sketch=`, `edge=`, `face=` or a position derived from `bodies[i].screen` / `project`). The only literal coordinates left are inside `jaw_px` (derived from measured `H`).
5. **Canonical fillet sequence** (measured, P3–P4): A11b arms Fillet, key `1` (Front), picks **both** vertical neck edges with `d.click(edge=<id>, along=0.5)` (status `Fillet: 2 edge(s) — 10.0 mm vertical, 10.0 mm vertical — click more, Enter to apply, Esc cancel`); N2 / L3 / A11c as today (R10, `Fillet 2 edges 10.00 applied … Fillet no longer armed`); A11d arms R1, key `3`, `click(model=[200, −16, 10])` → `Fillet: 15 edge(s)` → `Fillet 15 edges 1.00 applied`, then key `8`, `click(model=[50, 0, 0])` → `Fillet 11 edges 1.00 applied`; A11e arms R1, key `3`, `click(model=[93.5, 0, 7.5])` → `Fillet: 4 edge(s)` → `Fillet 4 edges 1.00 applied`, then the **R1.5 refusal** on the slot floor as the headless walk does it (`exceeds the 1.250 mm limit`, no feature added). After A11e the timeline holds exactly the four fillet features, none with a single edge. Row A11f stays as it is (it removes its pick again).
6. **A13 order and commit.** The runner order is `A13b, A13d, A13, A13c` (the two cancel rows first; `A13` last, ends with the commit; the BUILD agent measures which path commits (a click on empty viewport runs `PropertyPanel.commit()`, status `Feature updated (n change(s))`; the export also flushes the typed text) and the clause asserts that status when it is emitted and, always, `bbox Z 14.0` in A13c). The row index and chunk lists change accordingly; row ids do not.
7. **The `[status-trace]` is the status.** Any clause that judges a status text reads the `[status-trace] … kind=result text=…` lines since the row's mark (`trace_from`), never the live label. The live label is read only for hover hints.
8. **`-135°` (two layers).** (a) WP3 removes the likely trigger (a spurious undo entry that makes Ctrl+Z / Ctrl+Shift+Z cycle through a drifted sketch). (b) WP4 makes an angle dimension that measures a **long-side direction** against the horizontal datum independent of the line's direction: the recorded value is normalised to `(−90°, 90°]` (a line direction is defined mod 180°; `-135°` ≡ `45°`), in the three writers (`_record_dimension("angle", …, "jaw_angle")` after Trim, `_dimension_records_from_sketch` on reopen, `_add_angle_to_horizontal`), the label text and the editor value (`Dim 45.0`) use the same number, and a headless regression suite pins `45°` after **every** history in a generated matrix (Decision 8c). (c) The matrix: jaw built with click 3 on both sides (±10), Smart Dim / jaw edit order (width then angle), Exit Sketch + pencil reopen 0 / 1 / 2 times, part Ctrl+Z × 0..2 followed by Ctrl+Shift+Z × 0..2, sketch Ctrl+Z to `Nothing to undo` and redo, Delete-all + redraw, then circles, a line across the head and Power Trim from either stub; after each: drawn labels contain `45°` and none contains `-`.
9. **Soft-skip log level.** `resolve_dressup_edges` logs a lost-edge summary with **`warn`** (not `error`), prefixed with the feature name (`fillet 10: fillet soft-skip: 1 edges lost on rebuild`), and keeps the per-edge `debug` lines and the `graph.add_warning` the user sees. The A13 clause counts `[ERROR].*soft-skip` = 0 and additionally asserts the `Preview: distance = 14.0` status of a faithful document carries no `— fillet …` warning suffix. The naming limitation itself is LOG.
10. **End-on pick.** In `_polyline_screen_nearest`, when several samples are within 0.01 px of the best screen distance the **sample nearest the camera** is returned (so the visibility test of `edge_near_screen` / `edge_near_point` looks at the end of an end-on edge that faces the viewer, not the first vertex). If WP5's red step shows the hypothesis (P9) is wrong, the BUILD agent records the measured cause in the PR body and fixes **that**; the acceptance test (both necks, top view, ±2 px) does not change.
11. **No-op exit.** `exit_sketch` compares the sketch to its baseline **numerically** (same entity ids and types, same constraint ids, types, refs and driving flags, every parameter and value within **1e-9** absolute or relative), and `_edit_baseline` is re-taken after the activation solve in `_activate_session` so the first comparison is against the solved state. A real edit (a moved point, a changed dimension) still pushes `graph_update_sketch`.
12. **State exposure** (test-only, bridge and product accessors; nothing changes for a user): `automation_bridge._collect_glyphs` adds `cid`, `offset_px`, `leader`, `anchor`, `pos` from `glyph_debug()` and a top-level `glyph_leaders` `{present, tris}` read from the `GlyphLeaders` mesh; `viewport_interaction` gains `box_colours(crossing: bool) -> Dictionary` (`{fill, edge}`) used by **both** `_draw` and `_box_paint` (the bridge no longer re-declares colours); `camera` and `project` already exist for A11a.
13. **A15 runs.** The runner's A15 runs `lint_rung01_e2e.py`, `lint_suites.py` and `make test-godot` (stdout to `$OUT/test-godot.log`, `KEEP_GOING=1`) when `--a15` is passed, and the checklist's A15 row requires it; without `--a15` the row is `BLOCKED-by-flag`, never PASS. A 702-check floor for the wrench walk and the replan19 / replan20 suite floors are asserted from the log.
14. **Traces.** No new traces. The existing `[status-trace]`, `[hover-trace]`, `[popup-trace]` and `[input-trace]` lines are enough (P10, Decision 7).
15. **PR rules for the BUILD PR.** Repo `github.com/solidexpress/solidexpress` only; start from `main`; ready (not draft); never self-merge; quick CI (linux kernel, godot-smoke, website-demos) green; do not wait for `windows-export` / `macos-kernel`; **do not edit `docs/plan/STATUS.md`**; new headless tests follow `.cursor/rules/gdscript-click-driven-tests.mdc` and pass `tools/lint_rung01_e2e.py` (extended to scan `run_rung01_replan21_*.gd`); the PR description lists every changed runner expectation, the red output of each WP's step 1, the exact suite counts of the integration step and a full 77-row runner report (`walk_report.json` counts + `WALK_LOG.md` head) from the final build.

## Work packages

Order is fixed. Each WP: **items**, **root cause** (verified on `main` `bb13358` by the probes above), **files**, **tests** (a runner row, a headless suite + `packaging/ci/suites.d/<name>.suite` manifest + tier + minimum check count), **acceptance**. Every new suite's manifest is `script=tests/run_rung01_replan21_<name>.gd`, `timeout=180` (WP4 `300`). Suite names are `rung01_replan21_<name>`. Runner changes are verified by running `python3 tools/walk_rung01.py` (rows named per WP) and pasting the row table; a runner row's "red" is the verdict before the edit.

### WP1 — Runner: one body, no pixel literals, status from traces (A12, N11, A13c, N16, N4, L5, N9)

**Items:** RC1, RC7 (vacuous clauses L5, N16, N9); rows N4, N16, A12, N11, A13c, N9, L5, and the `S0` guard on A5, A12, N11, A13c, A14.

**Root cause (P1, P2, P10, P13).** See "The runner gap". `row_N16` clicks `screen=[60, 680]` (a palette button) and leaves a selected `Box 1` plus `sketch 11` / `extrude 12` (P2b); `row_N4` reads a live status label; nothing checks the document before an export; `L5`, `N16`, `N9` and `A13c` have clauses that cannot fail.

**Files:** `tools/walk_rung01.py` only (`export_3mf` guard `S0`, `row_N4`, `row_N16`, `row_L5`, `row_N9`, a `status_since(mark)` helper over `trace_from`), `docs/loop/automation-bridge.md` (the `S0` and trace-status rules).

**Tests / red first.** (1) Run the shipped runner once through chunk 5 (`python3 tools/walk_rung01.py --from A7 --out /tmp/w1 --checkpoint` after the first chunk's `blank.sxp`, or a full walk) and paste the `bodies` of the exported file: the new `S0` clause must be **red** (`stray body Box 1 4178.8` / `extrude 12 866.0`) before the N4 / N16 edits. (2) After the edits: `S0` green at every export; `N4` PASS with `saved sketch` read from `[status-trace] kind=result text=Sketch saved`, and `bodies` / `timeline` equal before and after; `N16` per Decision 7: nothing selected (`clear_selection`), pointer on `bodies[0].screen` (never a literal), key `0` → trace order `kind=result No view for key 0 — use 1 2 3 4 6 7 8` then `kind=restore` with the Face text, Δt in **2.0–4.0 s**, no `[hover-trace]` between; run 2: key `0`, pointer to a ground point (`project(model=[400, 300, 0])`), `[hover-trace] target=none`, and **no** `kind=hint|restore` Face line in the next 4.0 s (the vacuous `or True` is gone); `L5` `HUD Frame` asserts `Sketch view fit` / `Framed` from the trace; `N9` reads `check-wrench-wrench-t14.txt` and asserts the exact lines `PASS  head-shaft R10 fillet +Y`, `PASS  head-shaft R10 fillet -Y`, `PASS  R10 fillet not oversized`, `PASS  1mm fillet bottom outer edge` and the `tris` count line (each a separate clause).

**Acceptance.** The runner's N4, N16, L5, N9 rows PASS with no vacuous clause (`grep -n "or True\|and True" tools/walk_rung01.py` finds nothing except the documented `headless-only` clauses, which become `skip`-kind clauses that the report counts as `headless-only`, not PASS); `S0` is part of every export row's clause list in `WALK_LOG.md`.

### WP2 — Runner: the handout's fillet set and the A13 order (A11b, A11d, A11e, A12, N11, A13, A13c)

**Items:** RC2; rows A11b, A11d, A11e, A12, N11, A13, A13b, A13d, A13c, N9, and the `ROWS` / `CHUNKS` / `EXPECT` / `checkpoint_file` tables.

**Root cause (P3, P4, P5, P6).** As in "The runner gap": one neck instead of two, the slot floor as "top", a 1-edge lip fillet, A13b / A13d rolling back A13.

**Files:** `tools/walk_rung01.py` (`row_A11b`, `row_A11d`, `row_A11e`, `ROWS`, `CHUNKS[5/6]`, `EXPECT`, `row_A13*`), `tools/check_rung01.py` unchanged.

**Tests / red first.** Red = the current A12 / N11 / A13c rows after WP1 (`S0` green, so the failures are now purely the fillet set / order): `19/28`-class failures `head-shaft R10 fillet +Y/-Y`, `1mm fillet top outer edge` / `1mm fillet on jaw top edge`, thick `bbox Z got 10.0` (A13 rolled back). Then the Decision 5 sequence and Decision 6 order. Per-step runner clauses: after A11c `Fillet 2 edges 10.00 applied`; after A11d `Fillet 15 edges 1.00 applied` and `Fillet 11 edges 1.00 applied`; after A11e `Fillet 4 edges 1.00 applied`, the refusal string `exceeds the 1.250 mm limit`, and the **timeline fillet count == 4** (bridge `timeline`: `fillet 7` … `fillet 10`), the four apply statuses reading `2 edges`, `15 edges`, `11 edges`, `4 edges` (so none has a single edge); A12 `wrench.3mf` **28/28 `flipX=False flipY=False`** (exact `28/28 passed` line); N11 `wrench-noext` 28/28 and no extensionless file; A13 `prefix silent`, `commit 14` (`Preview: distance = 14.0` then the commit), `[ERROR].*soft-skip` count `0`, the `Preview: distance = 14.0` status has **no `— fillet …` warning suffix**; A13c thick **7/7** and DIAG **exactly** `{bbox Z (thickness), grip slot present at y=0,z=8.75, 1mm fillet top outer edge, 1mm fillet on jaw top edge}` failing (set equality, not the substring `DIAG:`).

**Acceptance.** `python3 tools/walk_rung01.py --out $OUT` chunks 5–6: A11b, A11d, A11e, A11f, A12, N11, A13, A13b, A13d, A13c, N9 all PASS; `check-wrench-wrench.txt` `28/28 passed`, `check-wrench-wrench-noext.txt` `28/28 passed`, `check-thick-wrench-t14.txt` `7/7 passed`, `check-wrench-wrench-t14.txt` `18/22 passed`.

### WP3 — A no-op reopen / exit pushes no undo entry (A8b variant)

**Items:** RC3; rows A8b, A8b-variant-walk, N8a, N20, A9c (re-verify).

**Root cause (P8).** `begin_edit` stores `_edit_baseline = loaded.snapshot()` (`sketch_mode.gd` 625), `_activate_session` solves (`refresh_dof_state`), and `exit_sketch` (828) tests `sketch.snapshot() == _edit_baseline` as a string; the jaw parameters differ in the 16th–17th digits (`194.169064849386` vs `194.16906484938613`), so the exit calls `view.doc.graph_update_sketch(editing_fid, sketch)` and the graph records an undo snapshot. Part Ctrl+Z then undoes that entry (`Undo`), and `sketch 3` leaves only on the second.

**Files:** `game/scripts/sketch_mode.gd` (`exit_sketch`, `_activate_session`, a `_snapshots_equal(a: String, b: String, tol := 1e-9)` helper that parses both JSON snapshots and compares structure exactly and numbers within tolerance), nothing else.

**Tests.** New `game/tests/run_rung01_replan21_sketchundo.gd` (`rung01_replan21_sketchundo.suite`, **`tier=ci`**, **n ≥ 40**), real clicks / keys on a built jaw (`film_jaw` lib): (1) Exit Sketch, Timeline pencil, Esc, Esc → status `Sketch saved` and **one** part Ctrl+Z removes `sketch 3` (`Undo`), Ctrl+Shift+Z brings it back (`Redo`), each read from the Timeline rows (the row that fails red today: after the first Ctrl+Z `sketch 3` is still listed); (2) the same after 1, 2 and 3 reopen / exit cycles; (3) after a **real** edit (move a point by a drag, or change a dimension `20` → `21`) the exit **does** push an entry: one Ctrl+Z restores the previous value, status `Undo`; (4) `_snapshots_equal`: identical → true; one parameter changed by 1e-12 → true; by 1e-6 → false; one constraint removed → false; entity order changed → false; (5) the main A8b path (no reopen) is unchanged: one Ctrl+Z removes `sketch 3`.

**Acceptance.** `rung01_replan21_sketchundo` `<n> checks, 0 failures` (n ≥ 40); the runner's `A8b-variant-walk` PASS (`sketch 3 after part undo`); `run_rung01_replan19_timeline` (75), `run_rung01_replan16_sketchvis` and the replan16 / 17 walks green. **Full tier run after this WP.**

### WP4 — `-135°`: a jaw angle never reads a flipped direction

**Items:** RC4; rows L4, N1a, A9, N5, N8a, A9-variant-walk.

**Root cause.** Not reproduced (P14 a, b, c), so this WP is a **regression pin plus a normalisation**, as the task allows. Code lead: after Trim the jaw code (`sketch_mode.gd` ~3690–3935) records the angle dimension from existing dimensions (`have_angle`) and otherwise from the wall direction with the fallback `Vector2(1, 0).angle_to(md)`, a **signed direction angle in (−180°, 180°]**: the same line read from its other end is `−135°`, which is the value the screenshot walk's editor showed (`Dim -135.0`). `_dimension_records_from_sketch` (rebuilding records from kernel constraint info on reopen) has the same freedom. The earlier-undo defect (WP3) is the only history found that makes the record be rebuilt from a drifted sketch.

**Files:** `game/scripts/sketch_mode.gd` (`_record_dimension` for `"angle"` with `kind == "jaw_angle"`, `_add_angle_to_horizontal`, `_dimension_records_from_sketch` / `_dimension_record_from_cid`, the label formatter): Decision 8b; no kernel change.

**Tests.** New `game/tests/run_rung01_replan21_angle.gd` (`rung01_replan21_angle.suite`, `tier=full`, `timeout=300`, **n ≥ 80**): the Decision 8c matrix built with real input (jaw `20` / `45`, click 3 at `±10`, 0–2 reopen cycles, part undo / redo 0..2, sketch undo to empty and redo, Delete-all + redraw, circles `5` / `22.5`, a line across the head, Power Trim from the outer and the inner stub): after **each** case (a) the drawn `Label3D` list contains exactly one text matching `^[0-9.]+°$` and it reads `45°`, (b) no label contains `-`, (c) the editor opened on that label reads `45.0` (`Dim 45.0`), (d) `dimensions[]` has one angle record in `(−90°, 90°]`. Unit cases: a record built from a wall pointing at 135° and at −45° both give `45°`; a 0° and a 90° jaw give `0°` / `90°`; a 5° jaw gives `5°`. The red step is the unit cases with the **direction-reversed wall** (expected `45°`, today `-135°`) — if even that is green on `main`, the suite is the pin and the PR body says so.

**Acceptance.** `rung01_replan21_angle` `<n> checks, 0 failures` (n ≥ 80); `run_rung01_replan19_jaw` (77), `run_rung01_replan20_jaw`, `run_rung01_wrench.gd` (≥ 702, 28/28 / 28/28 / 7/7 / 18/22) green; the runner's L4 / N1a / A9-variant rows still read `45°`.

### WP5 — End-on edge pick: the vertical beats the line in top view (A11b, N2, N3)

**Items:** RC5; rows A11b (top-view variant row `A11b-top`, below), N2, A11e, A11f.

**Root cause (P3, P9).** In Top view the −Y vertical neck edge picks as `179.8 mm line`; the +Y one picks correctly. Hypothesis: `_polyline_screen_nearest` returns the first sample of an end-on edge, `_edge_point_visible` ray-tests that point against the body, and for the edge whose polyline starts at z = 0 it is under the body (Decision 10).

**Files:** `game/scripts/document_view.gd` (`_polyline_screen_nearest`: nearest-to-camera tie-break), nothing else.

**Tests.** New `game/tests/run_rung01_replan21_pick.gd` (`rung01_replan21_pick.suite`, **`tier=ci`**, **n ≥ 36**), the `wrench-wip` document built headless by the same steps as `run_rung01_wrench.gd` (or opened from a fixture written by the wrench walk): for the **two** neck edges in views `1`, `2`, `3`, `4`, `6` and `7`: click the vertical edge's midpoint plus a **±2 px jitter grid (9 points)**; the picked edge has `|dir.z| > 0.8` and length 8–14 (36 checks minimum for the Top view alone: 2 necks × 9 jitters + the red step's `near["point"]` print). Plus: an arc and a line meeting at the picked point still resolve to the edge the pointer is on when the pointer is ≥ 9 px from the junction. Red step: print `near["point"].z` and `_edge_point_visible` for both necks in Top view; paste it.

**Runner row (new, after A11c in chunk 5, state-neutral):** `A11b-top` arms Fillet, key `3`, picks the **−Y** neck with `d.click(edge=…, along=0.5)`, asserts `Fillet: 1 edge(s) — 10.0 mm vertical`, Esc Esc (`Edit` cancelled, no feature added). The 77-row total is unchanged because the row is a **clause group of A11b** (clauses `top view +Y`, `top view -Y`), not a row.

**Acceptance.** `rung01_replan21_pick` `<n> checks, 0 failures` (n ≥ 36); `run_rung01_replan19_fillet_pick` (44) and `run_rung01_wrench.gd` green; A11b's two new clauses PASS.

### WP6 — Soft-skip: a warning, not an error (A13)

**Items:** RC6; rows A13, L7, A11e.

**Root cause (P7).** `resolve_dressup_edges` (`sxkernel/src/features/ops_dress.cpp` 680–686) `sx::log::error`s the lost-edge summary while `report_lost_edges` already raises the user-facing warning.

**Files:** `sxkernel/src/features/ops_dress.cpp` (`warn` + the feature name, per-edge `debug` kept; `ctx.feature.name` is already used by `report_lost_edges`), kernel Catch2 test in `sxkernel/tests` where the dressup tests live.

**Tests.** New `game/tests/run_rung01_replan21_dressup.gd` (`rung01_replan21_dressup.suite`, `tier=full`, **n ≥ 20**) and one Catch2 case: a block with a single-edge fillet on a top edge; edit the upstream extrude distance 10 → 14 so the edge cannot be found; assert `graph_warnings()` contains `all 1 edges lost on rebuild — it changes nothing now`, the log text contains `fillet soft-skip` at **`WARN`** and **no** `[ERROR]` line mentions `soft-skip`; a two-edge fillet with one lost edge → `1 of 2 edges lost on rebuild`; a fillet with every edge found → no warning; the status line after the edit still ends with the warning text. Red step: the same assertions on `main` (the `[ERROR]` line is present).

**Acceptance.** `rung01_replan21_dressup` `<n> checks, 0 failures` (n ≥ 20); `make test-kernel` passes; `run_rung01_wrench.gd` ≥ 702 / 0 failures; the runner's A13 clause `no error soft-skip` PASS.

### WP7 — State for the visual PARTIALs (N26, N24, A11a)

**Items:** RC7; rows N26, N24, A11a, N18.

**Root cause (P11, P12).** N26: the leader data exists (`glyph_debug`) but is not exposed. N24: the crossing box differs by **fill**; the edge is blue in both; the bridge re-declares the colours. A11a / N18: a projection compare needs no screenshot.

**Files:** `game/scripts/automation_bridge.gd` (`_collect_glyphs`, `_box_paint`), `game/scripts/viewport_interaction.gd` (`box_colours(crossing)` used by `_draw` and the bridge: Decision 12), `tools/walk_rung01.py` (`row_N26`, `row_N24`, `row_A11a`, `row_N18`, `visual()` removed).

**Tests.** New `game/tests/run_rung01_replan21_state.gd` (`rung01_replan21_state.suite`, **`tier=ci`**, **n ≥ 40**): (1) badges: on the jaw sketch after Trim, `_collect_glyphs` returns for every glyph `cid`, `offset_px`, `leader`, `anchor`, `pos`; `leader == (offset_px ≥ 12)`; `glyph_leaders.present == any(leader)` and `tris == 2 × count(leader)`; **leader clearance** (the runner clause): for each leader glyph, the segment `anchor → pos` does not intersect any dimension-label rect and does not cross the glyph rect of another badge, its far end is ≤ 40 px from the anchor (`GLYPH_MAX_OFFSET_PX`) and its near end lies inside its own glyph rect grown by 2 px; (2) box: window drag left-to-right → `box.fill` blue-dominant (`b > g > r`), crossing right-to-left → green-dominant (`g > b`, `g > r`), `box.edge` equal to `box_colours(false).edge` in both, and `_draw` / `_box_paint` read the same function (a test that changes the function's return value changes both); (3) pose: part mode, key `3`, record `camera` (target, distance, yaw, pitch) and `project(model=[0,0,10])` / `project(model=[200,0,10])`; after a Slot sketch is opened, cut and the part view returns, the same records agree within **5 px** and the camera pose within 1e-3.

**Runner rows.** `N26` `badge leaders` PASS from (1) (clauses `leader flag`, `leader mesh`, `leader clearance`), `N24` `box colour` PASS from (2) (clauses `window fill blue`, `crossing fill green`, `edge colour shared`), `A11a` `top before slot` records the pose and `N18` `top after slot` asserts it (±5 px, pose equal). No `visual()` call remains in the runner.

**Acceptance.** `rung01_replan21_state` `<n> checks, 0 failures` (n ≥ 40); `run_rung01_replan17_selectbox`, `run_rung01_replan19_glyphs`, `run_rung01_replan20_glyphs` green; the runner reports 0 PARTIAL.

### WP8 — A15, the checklist and the runner's expectations (A15, ROWS, EXPECT)

**Items:** RC7 (A15, `headless-only` clauses); the 77-row table below; `docs/loop/automation-bridge.md`.

**Files:** `tools/walk_rung01.py` (`row_A15`, `--a15`, `EXPECT` for any row whose blocker changed with WP2's order, report: counts of `PASS`, `PARTIAL`, `FAIL`, `BLOCKED`, `runner-gap`, `headless-only`), `docs/loop/automation-bridge.md` (rules R1–R10 below), `tools/lint_rung01_e2e.py` (scan `replan21`).

**Tests.** `python3 tools/walk_rung01.py --a15 --out $OUT` (one full run, ~10 min + the tier): `A15` runs the two lints and `make test-godot`, asserts `suites: <n> run, 0 failed` in the log and the floors of the integration step; without `--a15` the row is `BLOCKED-by-flag`. A clause `headless-only` is reported as `headless-only` and is not counted as PASS.

**Acceptance.** `walk_report.json` `counts` has `PASS 77` and no other key except `headless-only` clauses listed in the row evidence; `WALK_LOG.md` lists no `or True` / `and True` clause.

### Integration step (after WP8, same PR)

1. `make build`; `make test` (kernel Catch2 + all headless suites).
2. `KEEP_GOING=1 make test-godot` → **`suites: 204 run, 0 failed`** (199 + 5 new); `make test-godot-known-red` unchanged (4).
3. `python3 tools/lint_suites.py` → **`lint_suites: 208 suites ok (61 ci, 143 full, 4 known-red)`**; `python3 tools/lint_rung01_e2e.py` → replan19 / 20 clean as before and **`5 replan21 scripts are clean`**.
4. `tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd` → `0 failures` and **≥ 702 checks**, checker lines 28/28 / 28/28 / 7/7 / 18/22.
5. **The runner, once, full:** `python3 tools/walk_rung01.py --a15 --out /tmp/sx-042-plan-check` on the BUILD box: **`PASS 77`**, 0 PARTIAL / FAIL / BLOCKED / runner-gap, wall time ≤ 15 min, blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7. The counts and the `WALK_LOG.md` head go in the PR body.
6. PR description lists every stale expectation changed (the runner's rows, any replan19 / 20 suite expectation that encoded a snapshot string compare or a signed jaw angle), the red output of every WP's step 1 and the exact suite counts above.

## Whole-suite table

Baseline `main` `bb13358`: `lint_suites: 203 suites ok (57 ci, 142 full, 4 known-red)`, so `make test-godot` runs 199; `run_rung01_wrench.gd` `702 checks, 0 failures`. Target after WP1–WP8: **`suites: 204 run, 0 failed`**, `lint_suites: 208 suites ok (61 ci, 143 full, 4 known-red)`.

| Suite | Baseline | WP | Tier | After |
|---|---|---|---|---|
| `rung01_replan21_sketchundo` (new) | — | WP3 | ci | `<n> checks, 0 failures`, n ≥ 40 |
| `rung01_replan21_angle` (new) | — | WP4 | full | n ≥ 80 |
| `rung01_replan21_pick` (new) | — | WP5 | ci | n ≥ 36 |
| `rung01_replan21_dressup` (new) | — | WP6 | full | n ≥ 20 (+ one Catch2 case) |
| `rung01_replan21_state` (new) | — | WP7 | ci | n ≥ 40 |
| `run_rung01_wrench.gd` | `702 checks, 0 failures` | WP4, WP5, WP6 | ci | `≥ 702 checks, 0 failures`, 28/28, 28/28, 7/7, 18/22 |
| `rung01_replan19_jaw` / `timeline` / `glyphs` / `fillet_pick` | 77 / 75 / 83 / 44, 0 failures | WP3, WP4, WP5 | ci / full | same floors, green |
| `rung01_replan20_jaw` / `glyphs` / `shift` / `traces` | green | WP3, WP4, WP7 | ci / full | green |
| `run_rung01_replan16_sketchvis`, `replan16_walk`, `replan17_walk`, `replan17_selectbox`, `replan18_polyaf` | green | WP3, WP7 | | green |
| every other suite | green | | | green |

The new `.suite` files are the only edits under `packaging/ci/suites.d/`. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe.

---

## sx-042

The checklist below is **embedded** (it is the runner's contract; `tools/walk_rung01.py` `ROWS`, `CHUNKS` and the row functions implement it). **77 rows**: the 75 rows of sx-041 (A 33, L 12, N 30) in 6 chunks plus the two variant rows `A8b-variant-walk` and `A9-variant-walk` that the runner executes after chunk 6 from `blank.sxp`. Every row is judged by the runner from bridge `state` and `[status-trace]`, `[key-trace]`, `[input-trace]`, `[popup-trace]` and `[hover-trace]` lines; no row needs a screenshot. Walk it on a Linux build whose `BUILDINFO.txt` `commit=` equals the full sha of `main` after the BUILD PR is merged: **either** a local box build **or** the rolling `linux-test-build` prerelease.

```bash
SX_AUTOMATION=1 python3 tools/walk_rung01.py --a15 --out $OUT        # the whole walk, ~10 min + the headless tier
python3 tools/walk_rung01.py --rows A11b,A11d,A11e --checkpoint --out $OUT   # a re-check, from the saved .sxp of the previous chunk
```

### Runner rules R1–R10 (replace walker rules 1–78 for this walk)

1. **One command, one verdict.** The verdict is `walk_report.json` + `WALK_LOG.md` + the `check-*.txt` files in `$OUT`. A row the runner marks `PASS` is PASS; there is no second opinion from a screenshot.
2. **`--rows` is a diagnostic.** A partial run has no prior state (it can show false FAILs); verdicts come from the full run or from `--from <row> --checkpoint`, which reloads the previous chunk's `.sxp` (`blank.sxp`, `cut.sxp`, `wrench-wip.sxp`, `wrench-t14.sxp`).
3. **Statuses come from traces** (Decision 7). A clause that reads a status takes the `kind=result` line since the row's mark.
4. **Body guard** (Decision 3): every export row asserts one body of the right size; a violation is `runner-gap`, not a checker FAIL.
5. **FAIL / PARTIAL / BLOCKED / runner-gap.** FAIL = a clause failed on a valid state; PARTIAL = a clause could not be evaluated (target: none); BLOCKED-by-<row> = the starting state of the row is missing; runner-gap = the runner could not do what the row says. The pass bar needs 0 of the last three.
6. **No vacuous clause.** A clause that can only pass is a defect of the runner (WP1, WP8), reported as such.
7. **`headless-only` clauses** (the 2.5 s hold edge in N16 / N8b) are listed as `headless-only` with the suite that owns them; they are not PASS.
8. **Timing.** Waits use the bridge (`wait_idle`, `trace(since=…)`), never `sleep` longer than the row's own clause (N16: 2.0–4.0 s window, A13d: 0.4 s).
9. **Rule 71 noise.** `already connected` / `nonexistent connection` lines are counted and never judged; every other `[ERROR]` line is listed in the report and must be 0 except the three intended fillet refusals (`limit 1.250`, `regenerate stopped …`, `edit sketch: … open loop`) and the engine's Vulkan start-up lines.
10. **A15 runs** (`--a15`, Decision 13).

### Chunks

| Chunk | Rows | Starts in | Ends in |
|---|---|---|---|
| 1 | N22 A1 A2 N7 L1 A3 L5 A4 L6 L10 A5 N12 A5b L8 L11 N17 (16) | Fresh app (window read first), File → New, ground sketch | Part mode, blank (Ø45 head + Ø20 pivot, 10 thick) exported and saved as `blank.sxp`, nothing selected, no menu open, Timeline off |
| 2 | A7 L2 A6 N4 A7b A8r A8w A8 N5 N25 A8b N8a (12) | End of 1 | Jaw sketch open for editing (pencil), jaw `20` / `45°` committed, no pivot or head circle yet; **bodies and timeline as chunk 1 left them plus `sketch 3`** |
| 3 | A9 L4 N1a N21 N21b N26 L12 N24 N24b A17 A9c N1b N20 A9b (14) | End of 2 (sketch open) | Part mode, body cut by the open jaw (`Extrude Up To Surface 10.0000 mm`), `pre-cut.sxp` saved before the cut and **`cut.sxp` saved after it**; one body |
| 4 | A16 N6 A11a N10 N18 (5) | End of 3 | Part mode, shaft Slot cut (`Extrude Blind 2.5000 mm`), saved as `wrench-wip.sxp`, Top view, **camera as at A11a** |
| 5 | A11b N2 L3 A11c N3 A11d A11e A11f N15 N13 N16 N19 N23 (13) | End of 4 | Part mode, **four fillet features** (R10 ×2 edges, top 15, bottom 11, slot floor 4), Fillet disarmed, nothing selected, Timeline on, document dirty, **one body** |
| 6 | A12 N11 A13b A13d A13 A13c N9 L7 N8b N14 A10 A10b A14 L9 A15 (15) | End of 5 | nut exported, lints, headless tier run; then the two variant rows |

16 + 12 + 14 + 5 + 13 + 15 = **75**, + 2 variant rows = **77**. Chunk 6's row order differs from sx-041 only in `A13b, A13d, A13` (Decision 6); row ids and counts do not change.

### Re-verify map: every WP has rows

| WP | Rows it unblocks | Rows it must not regress |
|---|---|---|
| WP1 | N4, N16, L5, N9, `S0` on A5 / A12 / N11 / A13c / A14 | N12, N17, N19, N23 |
| WP2 | A11b, A11d, A11e, A12, N11, A13, A13c, N9 | A11f, N2, N3, L3, N15, N13 |
| WP3 | A8b-variant-walk | A8b, N8a, N20, A9c, A9 |
| WP4 | L4, N1a, A9-variant-walk (pin) | A8r, A8w, A8, N5, N1b |
| WP5 | A11b (top-view clauses) | A11e, A11f, N2 |
| WP6 | A13 (`soft-skip`) | L7, A11e |
| WP7 | N26, N24, A11a, N18 | N21, N21b, N24b, A17, N10 |
| WP8 | A15 | every row |

### The 77 rows

Each row: its chunk, the runner function in `tools/walk_rung01.py`, the clauses it asserts (clause names in `walk_report.json`, taken from the bridge run on this plan's baseline) and what sx-042 changes. A clause name in **bold** is a new or rewritten clause; "—" means the row is unchanged from sx-041.

#### Chunk 1 — blank (16 rows)

| # | Row | Verdict on the PLAN run | Clauses the runner asserts | sx-042 change |
|---|---|---|---|---|
| 1 | **N22** | PASS | `window`; `chrome inside` | — |
| 2 | **A1** | PASS | `new`; `sketch`; `Snap Infer`; `dof glyph`; `rail labels` | — |
| 3 | **A2** | PASS | `jaw status`; `jaw has no chips`; `rect status`; `rect chips` | — |
| 4 | **N7** | PASS | `Jaw status`; `Jaw lit`; `Rect status`; `Rect lit`; `Circle status`; `Circle lit`; `circle centre`; `lit vs hover fill` | — |
| 5 | **L1** | PASS | `Jaw`; `Line`; `Smart Dim`; `Trim`; `Slot`; `Circle`; `Select`; `key l`; `key d`; `key t`; `key c`; `key s` | — |
| 6 | **A3** | PASS | `r10`; `r22.5`; `two circles`; `first pick`; `second pick`; `burst 200`; `dimension` | — |
| 7 | **L5** | PASS | `F`; `HUD Frame`; `both circles inside` | **`HUD Frame` asserts `Sketch view fit` / `Framed` from the trace** (was `… or True`) (WP1) |
| 8 | **A4** | PASS | `chip visible`; `shaft`; `shaft added`; `two shaft lines`; `select tool`; `cleared`; `line 1`; `empty`; `line 2`; `both lines`; `esc clears chips`; `empty clears chips`; `delete`; `undo lines` | — |
| 9 | **L6** | PASS | `no live delta` | — |
| 10 | **L10** | PASS | `distance 10`; `distance 14`; `distance 10`; `1.5`; `burst 2.5` | — |
| 11 | **A5** | PASS | `extrude`; `one body`; `exported`; `blank 5/5` | **`S0` body guard before the export** (WP1) |
| 12 | **N12** | PASS | `chip y stable`; `fillet chip`; `cleared`; `timeline rows`; `popup trace` | — |
| 13 | **A5b** | PASS | `cancel keeps blank`; `save as prefilled` | — |
| 14 | **L8** | PASS | `name replaced`; `saved`; `file exists` | — |
| 15 | **L11** | PASS | `HudView trace` | — |
| 16 | **N17** | PASS | `body`; `selected`; `esc keeps selection`; `hud esc keeps selection`; `third esc` | — |

#### Chunk 2 — face sketch, Esc ladder, jaw (12 rows)

| # | Row | Verdict on the PLAN run | Clauses the runner asserts | sx-042 change |
|---|---|---|---|---|
| 17 | **A7** | PASS | `not editing`; `face sketch`; `framed` | — |
| 18 | **L2** | PASS | `cut up to` | — |
| 19 | **A6** | PASS | `centre`; `esc ladder`; `no face` | — |
| 20 | **N4** | FAIL | `finish reset`; `polygon`; `centre set`; `AF placeholder`; `AF 20`; `ctrl+a field`; `saved sketch`; `undo sketch` | **`saved sketch` read from `[status-trace] kind=result text=Sketch saved`**; **post-condition: `bodies` and `timeline` equal before and after** (WP1) |
| 21 | **A7b** | PASS | `sketch`; `measured` | — |
| 22 | **A8r** | PASS | `click 2 names click 3`; `committed 0`; `two labels`; `angle right of rail`; `width right of rail` | — |
| 23 | **A8w** | PASS | `labels present`; `width 20`; `angle still drawn`; `angle 45`; `dof not bang`; `empty undo`; `dof em dash`; `deleted dof` | — |
| 24 | **A8** | PASS | `zero width`; `committed`; `labels before edit`; `width field`; `angle field`; `no conflict` | — |
| 25 | **N5** | PASS | `undo redo`; `labels back` | — |
| 26 | **N25** | PASS | `empty dash`; `restored` | — |
| 27 | **A8b** | PASS | `select tool`; `wall`; `esc`; `part undo`; `sketch 3 leaves timeline`; `sketch 3` | unchanged; the variant row below covers the exit / reopen path (WP3) |
| 28 | **N8a** | PASS | `pencil`; `editing`; `finish 20`; `dof matches A8b` | — |

#### Chunk 3 — pivot, trim, labels, cut (14 rows)

| # | Row | Verdict on the PLAN run | Clauses the runner asserts | sx-042 change |
|---|---|---|---|---|
| 29 | **A9** | PASS | `pivot circle`; `head circle`; `length not 22.5`; `trimmed`; `no yellow hint`; `second trim` | —; pinned `45°` by WP4 |
| 30 | **L4** | PASS | `one 20 one 45`; `not 20.0005` | —; WP4 normalises the jaw angle record, the clause `one 20 one 45` also asserts **no label contains `-`** |
| 31 | **N1a** | PASS | `zoom`; `label 20`; `label 45`; `label 5`; `label 22.5`; `22.5 near head` | —; **no label contains `-`** (WP4) |
| 32 | **N21** | PASS | `glyphs drawn`; `glyph click`; `glyph click` | — |
| 33 | **N21b** | PASS | `8 of 9 free` | — |
| 34 | **N26** | PARTIAL | `badges on canvas`; `badge leaders` | **`badge leaders` → `leader flag`, `leader mesh`, `leader clearance`** from `glyphs[].leader`, `glyph_leaders` (WP7); was PARTIAL |
| 35 | **L12** | PASS | `circle has no measure`; `hover delta`; `click clears` | — |
| 36 | **N24** | PARTIAL | `enclose`; `empty click`; `crossing`; `box colour`; `cut misses`; `deleted throwaway` | **`enclose` asserts window fill blue-dominant; `crossing` asserts fill green-dominant; `edge colour shared`** from `box_colours()` (WP7); was PARTIAL and `(blue or True)` |
| 37 | **N24b** | PASS | `wall`; `shift add`; `plain replaces`; `cleanup` | — |
| 38 | **A17** | PASS | `chip lights Line`; `centerline`; `undo line`; `redo line` | — |
| 39 | **A9c** | PASS | `saved`; `finish kept` | — |
| 40 | **N1b** | PASS | `same labels`; `editor has no delta` | — |
| 41 | **N20** | PASS | `overwritten`; `finish stays`; `sketch undo` | — |
| 42 | **A9b** | PASS | `cut`; `size`; `cut saved` | — |

#### Chunk 4 — views, slot (5 rows)

| # | Row | Verdict on the PLAN run | Clauses the runner asserts | sx-042 change |
|---|---|---|---|---|
| 43 | **A16** | PASS | `orientation list`; `hud view trace`; `Front`; `Right`; `Back`; `Left`; `Isometric`; `Bottom`; `Top`; `jaw see-through or body` | — |
| 44 | **N6** | PASS | `body`; `first notch`; `frame` | — |
| 45 | **A11a** | PARTIAL | `top before slot`; `sketch`; `centre 1`; `not prefilled 5`; `slot typed` | **`top before slot` records `camera` and `project(model=…)` of pivot and head in part Top view** (WP7); was PARTIAL (screenshot) |
| 46 | **N10** | PASS | `chips`; `tag clearance`; `deleted` | — |
| 47 | **N18** | PASS | `2.5`; `slot cut`; `saved` | **`top after slot`: same projections ±5 px, camera pose equal** (WP7) |

#### Chunk 5 — fillets (13 rows)

| # | Row | Verdict on the PLAN run | Clauses the runner asserts | sx-042 change |
|---|---|---|---|---|
| 48 | **A11b** | PASS | `armed`; `neck edge` | **key `1`, both neck edges (`Fillet: 2 edge(s) — 10.0 mm vertical, 10.0 mm vertical`)**; clause group **`top view +Y`, `top view −Y`** (WP2, WP5) |
| 49 | **N2** | PASS | `spinner`; `enter does not apply` | — |
| 50 | **L3** | PASS | `tab releases`; `second click stays`; `1.5` | — |
| 51 | **A11c** | PASS | `applied` | — |
| 52 | **N3** | PASS | `chips present`; `chips side by side` | — |
| 53 | **A11d** | PASS | `released`; `face loop`; `top fillet`; `bottom fillet` | **outer top by `model=[200,-16,10]` (`Fillet 15 edges 1.00 applied`), bottom by `model=[50,0,0]` (`Fillet 11 edges 1.00 applied`)** (WP2) |
| 54 | **A11e** | PASS | `floor pick`; `R1 applied`; `refused` | **slot-floor loop by `model=[93.5,0,7.5]` (`Fillet 4 edges 1.00 applied`), R1.5 refusal leaves no feature, timeline fillet count == 4, none with 1 edge** (WP2) |
| 55 | **A11f** | PASS | `near`; `removed` | — |
| 56 | **N15** | PASS | `ground not sketch`; `armed`; `cancelled` | — |
| 57 | **N13** | PASS | `no view`; `camera still`; `top` | — |
| 58 | **N16** | FAIL | `result then hint`; `headless-only hold edge`; `leave clears hint` | **rewritten: nothing selected, pointer on `bodies[0].screen`; `result` then `restore` in 2.0–4.0 s, no `[hover-trace]` between; run 2: `target=none` and no Face line for 4 s; no pixel literal; bodies unchanged** (WP1) |
| 59 | **N19** | PASS | `timeline misses radius`; `esc hides radius` | — |
| 60 | **N23** | PASS | `title below chips` | — |

#### Chunk 6 — export, thickness, dirty flag, nut, lint (15 rows + 2 variant rows)

| # | Row | Verdict on the PLAN run | Clauses the runner asserts | sx-042 change |
|---|---|---|---|---|
| 61 | **A12** | FAIL | `exported`; `28/28` | **`S0`; `28/28 passed` exact line, `flipX=False flipY=False`** (WP1, WP2) |
| 62 | **N11** | FAIL | `extension added`; `28/28` | **`S0`; `28/28 passed`; no extensionless file** (WP1, WP2) |
| 63 | **A13b** | PASS | `row`; `double click`; `cancel` | moved before A13 (Decision 6) |
| 64 | **A13d** | PASS | `extrude row`; `prefix writes nothing`; `cancelled` | moved before A13 (Decision 6) |
| 65 | **A13** | FAIL | `extrude row`; `focused`; `prefix silent`; `commit 14`; `no error soft-skip` | **last of the thickness rows; ends with the commit; `[ERROR].*soft-skip` count 0; no warning suffix on the preview status** (WP2, WP6) |
| 66 | **A13c** | FAIL | `thick 7/7`; `DIAG` | **`S0`; DIAG failing set equals the four by-design rows (set equality); thick `7/7 passed`** (WP1, WP2) |
| 67 | **N9** | PASS | `head-shaft R10`; `not oversized`; `bottom outer`; `tris` | **four exact checker lines (`head-shaft R10 fillet +Y`, `… -Y`, `R10 fillet not oversized`, `1mm fillet bottom outer edge`) + `tris`** (was vacuous) (WP1) |
| 68 | **L7** | PASS | `ctrl+s writes`; `clean new` | — |
| 69 | **N8b** | PASS | `opened`; `framed`; `headless-only hold` | `headless-only hold` is reported as `headless-only` (WP8) |
| 70 | **N14** | PASS | `FinishOp`; `2.5`; `refusal`; `esc`; `discarded` | — |
| 71 | **A10** | PASS | `81%` | — |
| 72 | **A10b** | PASS | `fresh` | — |
| 73 | **A14** | PASS | `polygon 20`; `extrude 7.5`; `nut 7/7` | **`S0` (exactly one body)** (WP1) |
| 74 | **L9** | PASS | `AF bearings` | — |
| 75 | **A15** | PASS | `lint_rung01_e2e`; `lint_suites`; `headless tier` | **runs both lints and `make test-godot` with `--a15`; asserts `suites: <n> run, 0 failed` and the floors; without `--a15` BLOCKED-by-flag** (WP8) |

#### Variant rows (after chunk 6, from `blank.sxp`)

| # | Row | Verdict on the PLAN run | Clauses the runner asserts | sx-042 change |
|---|---|---|---|---|
| 76 | **A8b-variant-walk** | **FAIL** (product, P8) | `exit sketch`; `pencil reopen`; `wall`; `esc`; `sketch 3 after part undo` | —; green after WP3 (`sketch 3 after part undo` with one Ctrl+Z) |
| 77 | **A9-variant-walk** | PASS | `pencil reopen`; `pivot circle`; `head circle`; `length not 22.5`; `trimmed`; `angle after this trim` | —; `angle after this trim` asserts **no label contains `-`** (WP4) |

### A15 — headless and lint evidence (chunk 6, last row; needs `--a15`)

`python3 tools/walk_rung01.py --a15 --out $OUT` runs, from the repo root, in this order, and writes each output to `$OUT/a15-*.log`: `python3 tools/lint_rung01_e2e.py` (replan19 / 20 / 21 scripts clean); `python3 tools/lint_suites.py` (`lint_suites: 208 suites ok (61 ci, 143 full, 4 known-red)` or more); `KEEP_GOING=1 make test-godot` with `OCCT_PREFIX=<prefix>` when OCCT is not in the Makefile default (walk-box example `/workspace/sx-build/deps/occt/V8_0_1`, CI default `/opt/occt-8.0.1`) ending **`suites: <n> run, 0 failed`** with `<n> ≥ 204`; and the floors from the suite output: wrench walk **≥ 702** checks, replan19 keys 151 / shield 32 / jaw 77 / hint 30 / glyphs 83 / timeline 75 / camera 25 / fillet_pick 44 / polish 68, and each `rung01_replan21_*` suite at or above its minimum (sketchundo 40, angle 80, pick 36, dressup 20, state 40). Any miss is a FAIL of A15 naming the line.

### Pass bar for sx-042

Score ≥ 9 / 10; **`walk_report.json` `counts` = `PASS 77`** (no FAIL, PARTIAL, BLOCKED or runner-gap; `headless-only` clauses listed with their suite); checkers `tools/check_rung01.py` (never `--allow-mirror`): blank 5/5, wrench 28/28 with `flipX=False flipY=False`, wrench-noext 28/28, thick 14 7/7, DIAG on `wrench-t14.3mf` failing exactly the four by-design rows (18/22), nut 7/7; headless walks 0 failures; `make test-godot` ends `0 failed`; lints clean; fillets succeed on the first try (four fillet features, none with a single edge); a real Slot; a drawn `45°` jaw angle label that never reads `-`; **one body in every export**. Carry-over: a regression of a re-PLAN 19 / 20 work package is named in `WALK_LOG.md` and fails the walk.

## Errata of this plan's inputs

| # | Erratum | Fix |
|---|---|---|
| 1 | The bridge report and PR body list A12 / N11 / A13c as **product** FAILs. They are runner-fidelity defects (P2, P4, P6): the exported document is not the wrench. | classes in the triage table; WP1 / WP2 |
| 2 | The `N24` PARTIAL reports the crossing-box **edge** colour `[89, 153, 242, 217]` as unmeasurable; it is the bridge's own constant and equals the product's blue edge, which is the same for window and crossing by design (P11). The crossing is distinguished by the **fill**. | WP7, Decision 12 |
| 3 | `N9`, `L5 HUD Frame`, `N16 leave clears hint`, `A13c DIAG`, `N24 enclose` and `A15 headless tier` pass whatever happens (P13). | WP1, WP2, WP7, WP8 |
| 4 | `A13` expected the thickness to survive `A13b` / `A13d` (Esc) after Enter; Enter is a **preview**, Esc rolls it back (`cancel_edits`). | Decision 6 |
| 5 | The PR body says the `-135°` was "not reproduced by the runner's replay" and leaves the cause open. Three more histories did not reproduce it either (P14); the only history found that perturbs the reloaded sketch is the spurious undo entry (P8). | Decision 8, WP3, WP4 |
| 6 | The PLAN-run `wrench-t14.sxp` is not the wrench: it also holds `Box 1` and `sketch 11` / `extrude 12`, both added by N16's blind click (P2, P2b). | WP1 post-condition |

## Out of scope for this plan

- **Single-edge fillets after an upstream edit** (naming limitation): the warning text is the design; only its log level changes (Decision 9).
- **Angle-first editing of the wide (A8w, 97 mm) jaw:** the solver refuses it (`Dimension rejected — constraints could not be satisfied`); width first works. LOG, as in re-PLAN 20.
- **Engine log noise** (`Signal 'focus_entered' is already connected`, `Attempt to disconnect a nonexistent connection`, `Signal 'tree_exited' is already connected`, Vulkan start-up lines, `status < 0 … ERR_CANT_OPEN`): counted by R9, never judged.
- **Screenshot-based verdicts:** the vision walker is retired for rung 1; screenshots are optional artefacts.
- **The kernel** apart from the one log level of WP6; `sxkernel` behaviour does not change.
- **`windows-export` / `macos-kernel`** (~2 h) are not waited for; **`docs/plan/STATUS.md`** is not edited; `run_rung01_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.
- **Anything not named in a WP.** The BUILD agent adds no behaviour, no new rail button and no new status text beyond the strings quoted in the WPs.
