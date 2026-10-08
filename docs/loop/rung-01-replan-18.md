# Rung 1 re-PLAN 18 — sx-038 leftovers and the sx-039 checklist (UBC ECE Exercise 2 wrench + nut)

Status: planned. Docs only. Baseline: `main` `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed` (re-PLAN 17 complete plus the spin-outs #216–#225; the tip was re-checked when this plan was written and had not moved). Previous plans: [`rung-01-replan-17.md`](rung-01-replan-17.md) and the files before it. Next walk: **sx-039** = the checklist embedded below (69 rows, 6 chunks). Work packages (self-contained BUILD prompts): [`rung-01-replan-18-wp1.md`](rung-01-replan-18-wp1.md) … [`-wp4.md`](rung-01-replan-18-wp4.md).

## Where we are

Walk sx-038 (build of `main` `5520742d`, Linux, soft GL, physical screen 1920x1200 with 1280x800 screenshots) scored **FAIL 7.5/10**: 8 FAIL, 8 PARTIAL, the rest PASS; checkers all green (blank 5/5, wrench 28/28, wrench-noext 28/28, thick 14 7/7, DIAG exactly the four by-design rows, nut 7/7). Ten spin-outs (#216–#225, all merged, table below) fixed every FAIL row and every PARTIAL row except those handled here. **This plan covers only what the spin-outs did not**, and finds that the product work is small: **four work packages, one of them without product code at all**.

The most important finding is not in the walk. **The full test tier is red on `main`**: `KEEP_GOING=1 make test-godot` ends `suites: 181 run, 5 failed` at `f81c1e5`, while `AGENTS.md` and the sx-038 A15 row say the full tier is expected green (the walker's A15 run was made on the *pre*-spin-out build `5520742d`, where it was green). Five spin-out merges each broke one old suite. Two are real product regressions (Ctrl+Z in a focused number field; labels jumping when the sketch is saved) and three are tests that encode behaviour a spin-out changed on purpose. All five are bisected below and each fix was applied and run on the PLAN box.

Pass bar for sx-039 (unchanged): score ≥ 9; checkers nut 7/7, blank 5/5, wrench 28/28, thick 7/7 (`tools/check_rung01.py`, never `--allow-mirror`); headless walks 0 failures; **`make test-godot` ends `0 failed`**; every A / L / N row PASS (or soft-GL **with evidence**); fillets succeed first try; a real Slot.

## How this plan was measured (not guessed)

- OCCT 8.0.1 at `/opt/occt-8.0.1`, `make build`, then `KEEP_GOING=1 GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --tier full --keep-going` at `f81c1e5`: **`suites: 181 run, 5 failed`**. Each of the five was re-run alone and is red again (`bisect` below).
- **Bisect.** One git worktree per spin-out commit (`5520742` base, `260d3f6` #216, `f263dce` #218, `dec9fb0` #222, `9650cbd` #220, `1673982` #223, `a5755d2` #224, `f08fca9` #221, `8815841` #219, `0dc693e` #225, `f81c1e5` #217), each run with the five red suites. Results: all five green at `5520742` and `f263dce`; `run_rung01_replan14_savelabels` first red at `dec9fb0` (#222); `run_rung01_replan11_ux` first red at `9650cbd` (#220); `run_film_manifest_smoke` first red at `f08fca9` (#221); `run_rung01_replan14_undo` and `run_rung01_replan15_extrude` green at `0dc693e`, red at `f81c1e5` (#217). (`libsxcore.so` was the `main` build in every worktree; only #225 changed kernel C++ and it is not involved.)
- **Verified fixes.** All five fixes (WP2 three test files, WP3 one function, WP4 one line) were applied together on `f81c1e5` and the full tier re-run: see "Whole-suite table".
- **L9 measured.** A headless probe (real `InputEventMouseMotion` at exactly 150.0 px from the centre, 8 bearings, snap on and off): every bearing prints the same `Polygon AF 26.4910 — flats horizontal — click to place (or type the size)`; the circumradius is `AF / √3 = 15.2946 mm` and each hover is 150.0 px from the centre. The probe output is attached to the PR body as an artifact. The sx-038 "~2 %" was walker pixel error (scaled screenshots) plus the centre click snapping to the origin: the click was 11 px from the origin and the snap radius is `max(1.25, 0.02 × span)` mm (≈ 16 px at that zoom).
- **N24 measured.** The walk's steps (a)–(g) reproduced headlessly with the real drag path: windows, crossing, Shift-additive, empty-click clear and Delete all match the checklist; `1 click → 2 selected` happens only when the previous selection is still alive (a plain click on a second entity adds it, by design: see D6).
- No product code, test, checker, CI or Makefile file was changed by this plan. The only new files are the six docs of this PR (the L9 probe output is attached to the PR body, not committed).

## Merged since sx-038 (verify only, do not re-plan)

Each row was checked on the PLAN box: the pinning suite is registered, green on `main`, and was exercised by the full-tier run above.

| PR | Item | What it did | Pinning suite (green on `main`) | Re-verified by sx-039 row |
|---|---|---|---|---|
| #216 | N8a | DOF chip is recomputed when a saved sketch is opened (never `—` with geometry) | `rung01_replan17_dof` | N8a, N25 |
| #217 | L1 L10 A3 A8 A9 N18 | Fast keystrokes stay in length fields, label editors and the rail; first key replaces; Ctrl+A / Tab / Enter rules; a rail press switches tools | `rung01_sx038_focuskeys` | L1, A3, L10, A8, A9, N18 |
| #218 | N12 | A second click on the Extrude pixel cannot hit the part-mode `Hide` chip (`POST_FINISH_PRESS_GUARD_MSEC := 400`, shield until a press elsewhere) | `rung01_sx038_extrude_dblclick` | N12 |
| #219 | N4 L10 | Polygon's first press lands; the AF blank placeholder is ` AF`, never `0.01` | `rung01_sx038_polypress` | N4, A11a |
| #220 | L1 A3 | One lit rail button; Smart Dim between centres adds a two-centre horizontal and no point, no coincident glyph | `rung01_sx038_sketch` | L1, A3 |
| #221 | L12 N24 | Suggestion chips clear on Esc / empty click / Delete / undo; the first empty drag is a box, Shift is additive | `rung01_replan17_selectbox` | L12, N24 |
| #222 | N21 N26 N1a | A press on a badge selects that constraint; badges stay ≤ 40 px from their anchors, leaders at 12 px, the `22.5` callout sits on the head arc | `rung01_replan17_n21` | N21, N26, N1a |
| #223 | N23 A11c A11d A11e N19 N3 | Timeline sits 8 px under the chip row; the Fillet / Chamfer Radius row hides on disarm; Fillet apply ends `— Fillet no longer armed` | `rung01_sx038_chrome` | N23, N3, A11c, A11d, A11e, N19 |
| #224 | A13 A13b | Timeline double-click focuses Distance; the Params JSON row hides with the panel | `rung01_sx038_a13` | A13, A13b |
| #225 | L7 N14 | T14 slot-floor fillet limit is `1.250`; the host face drops on sketch exit (tint gone after the pointer moves) | `rung01_sx038_regress` | L7, N14 |

None of the ten is incomplete **by its own suite**. The two regressions they caused elsewhere (#217 → WP3, #222 → WP4) are in the triage table.

## Triage of the leftovers

Verdicts: **STALE** (the test is wrong, the product is right), **PRODUCT** (the code is wrong), **DESIGN** (behaviour is right, the checklist wording was wrong), **RE-VERIFY** (merged and pinned; the walk re-checks it with explicit numbers), **SOFT-GL** (environment).

| # | Leftover | Verdict | Evidence / root cause | WP |
|---|---|---|---|---|
| T1 | **L9** spec conflict (vertex under the pointer vs AF = √3·r) and a ~2 % AF spread | DESIGN, **not a bug** | Probe: AF identical at 8 bearings, snap on / off, 150 px (0.000 % spread). Spec decided in D2 (pointer on the circumscribed circle). The headless net for equal-pixel-distance hovers did not exist: `_check_polygon_bearings` in the replan17 walk derives the expected AF from the measured radius, so it cannot see a bearing-dependent radius | WP1 (tests only) |
| T2 | Full tier: `run_film_manifest_smoke` (`propose_parallel`: `FilmUI: clickable control missing or hidden (parallel?)`) | STALE | First red at #221: chips hide on an empty selection (L12). With two lines selected `Parallel?` is the 19th of 20 chips and sits in `… More` | WP2 |
| T3 | Full tier: `run_rung01_replan11_ux` (`near-X centres get horizontal (dy=0.0000 horiz=0)`) | STALE | First red at #220: Smart Dim centres now get a two-centre `horizontal` (level geometry), no construction line; the helper counted horizontals on construction lines | WP2 |
| T4 | Full tier: `run_rung01_replan15_extrude` (B1: typed `abc`) | STALE | First red at #217: letters never reach the Distance field (tool keys before a digit; re-asserted digits after). `1.2.3` is still unreadable and still prints `Cannot read distance: 1.2.3` | WP2 |
| T5 | Full tier: `run_rung01_replan14_undo` (`Ctrl+Z in the Radius field does not undo the sketch`; `entities 7→0`, `Undo: Jaw`) | **PRODUCT** | First red at #217: `_shortcut_blocked_by_numeric_edit` lets Ctrl+Z through an untouched focused number field; undo wiped the jaw from under the Radius box | WP3 |
| T6 | Full tier: `run_rung01_replan14_savelabels` (labels move 5–6 px on Ctrl+S / Save As) | **PRODUCT** | First red at #222: `_on_sketch_camera_moved` resolves labels against the previous glyph layout, `_rebuild_dimension_labels` against the current one; the next redraw (a Save) moves the labels | WP4 |
| T7 | A11d wording | DESIGN | Fillet disarms after apply (#205, #223): the row says **re-arm**; every Fillet row now says it | checklist |
| T8 | A3 PARTIAL (typed `22.5` → `2.5` / `0.5` / `225`; stray point in circle 1) | RE-VERIFY | #217 + #220; `rung01_sx038_focuskeys`, `rung01_sx038_sketch` green. The row now reads each field back before Enter and zooms on both circles | checklist |
| T9 | N8a PARTIAL (DOF chip `— DOF` in a re-edit session) | RE-VERIFY | #216, `rung01_replan17_dof` green; the row records the chip text before leaving the sketch and after re-opening | checklist |
| T10 | N1a PARTIAL (`22.5` ~100 px above the head; `45°` 4–6 px from a coincident badge) | RE-VERIFY | #222, `rung01_replan17_n21` asserts ≤ 40 px from the head circle and ≥ 4 px to badges; WP4 keeps the labels from moving afterwards. The headless suite runs at the test's zoom; the real ~150 px head is a **GUI-only measurement**, so N1a / N21 / N26 are written with explicit physical-pixel numbers and the walker records the zoom | checklist |
| T11 | L1 FAIL (two rail buttons lit; `S` swallowed by the Radius field) | RE-VERIFY | #220 (one lit button) + #217 (tool keys work while an armed field is untouched). By design a field you clicked or typed in keeps its keys: the row says to write `field owned` and use the rail button | checklist |
| T12 | L10 PARTIAL (field keeps focus after Enter) | RE-VERIFY | #217: Enter releases the field; row extended with Ctrl+A and a `2.5` burst | checklist |
| T13 | N24 "1 click → 2 selected" | DESIGN | `SketchMode._select_at` accumulates: a plain click on a second entity **adds** it (click again to deselect). Not a bug; row says so and asks which step preceded | checklist |
| T14 | L7(b) refusal read `0.250` not `1.250` | RE-VERIFY | #225, `rung01_sx038_regress`. Row text unchanged except the Enter-first order the walker had to discover | checklist |
| — | Dead first clicks with no `[input-trace]` line; N16 timing; N8b details | SOFT-GL | rule 51 and 46 (walker side); headless twins exist | rules |

## Decisions (final — BUILD agents do not choose)

1. **Scope.** Four WPs, all independent. No new behaviour and no new or changed status string anywhere. Items the spin-outs covered are not re-planned: they appear only as re-verify rows in the checklist.
2. **L9 spec (decided).** Across-flats polygon, flats horizontal, start angle 0. The pointer sits on the **circumscribed circle**; `AF = √3 × |pointer − centre|`, independent of the bearing; a vertex is under the pointer only at 0° / 60° / 120° …; typed size = AF. WP1 pins it headless; the L9 row asserts it by hand with equal **physical-pixel** distances.
3. **Ctrl+Z (WP3).** A focused numeric field owns Ctrl+Z (undo) even when untouched; redo (Ctrl+Shift+Z, Ctrl+Y) and tool keys stay with the sketch while it is untouched (#217 unchanged).
4. **Label layout (WP4).** Both layout paths rebuild the glyphs before resolving labels. The rule "glyph is laid out first, labels yield to it" is unchanged.
5. **Stale tests (WP2).** Changed to the new behaviour; no product edit, no new test.
6. **Selection.** A plain click on a second entity adds it to the selection (design). The N24 row and the changed-text table say so.
7. **Fillet.** Fillet disarms after every apply; every row that applies two fillets says **re-arm** between them (A11d, A11e, L7).
8. **Walker process.** One action per step, read after each, WALK_LOG after each row (rules 52–60). Physical pixels only (rule 54): sx-038 measured scaled screenshots.
9. **No other product WP.** Nothing else reproduces on `main`. If the sx-039 walk finds a new FAIL, it becomes a spin-out as before.
10. **PR rules for every BUILD PR.** Repo `github.com/solidexpress/solidexpress` only; start from `main`; ready (not draft); never self-merge; quick CI (linux kernel, godot-smoke, website-demos) green; do not wait for `windows-export` / `macos-kernel`; **do not edit `docs/plan/STATUS.md`** (notes go in the PR body); reproduce first.

## Work packages

| WP | Items | Rows unblocked | Files it owns | Verified edit | Order |
|---|---|---|---|---|---|
| [WP1](rung-01-replan-18-wp1.md) | T1 | L9, A14 | new `game/tests/run_rung01_replan18_polyaf.gd`, new `packaging/ci/suites.d/rung01_replan18_polyaf.suite` | none (net must be green on `main`) | parallel, merge last |
| [WP2](rung-01-replan-18-wp2.md) | T2 T3 T4 | A15 | `game/tests/films/film_propose_parallel.gd`, `game/tests/run_rung01_replan11_ux.gd`, `game/tests/run_rung01_replan15_extrude.gd` | 3 test diffs, run green | parallel, merge first |
| [WP3](rung-01-replan-18-wp3.md) | T5 | L10, A15 | `game/scripts/viewport_interaction.gd`: `_shortcut_blocked_by_numeric_edit` and its three call sites | 1 diff (10 lines), run green | parallel |
| [WP4](rung-01-replan-18-wp4.md) | T6 | N1a, N21, N26, A15 | `game/scripts/sketch_mode.gd`: `_on_sketch_camera_moved` | 1 line, run green | parallel |

**Dependency waves.** One wave: WP1–WP4 start at once on the same `main` and touch disjoint files (WP3 `viewport_interaction.gd`, WP4 `sketch_mode.gd`, WP2 three test files, WP1 two new files). No WP depends on another's code. **Merge order:** WP2, WP3, WP4, WP1 (any order is safe; this one turns the full tier from 5 red to 2 to 1 to 0 and adds the new suite last). Each WP's own acceptance list names the suites it must keep green; WP3 and WP4 also run the full tier once and may leave only the other WPs' suites red. sx-039 starts when all four are merged and `main`'s `make test-godot` ends `0 failed`.

## Whole-suite table

Baseline `f81c1e5`: `suites: 181 run, 5 failed` (full tier = `tier=ci` 47 + `tier=full` 134; plus 4 `known-red`, listed by `make test-godot-known-red`). Target after WP1–WP4: `suites: 182 run, 0 failed` (the 181 plus `rung01_replan18_polyaf`).

| Suite | Baseline | First red | Class | WP | After the fix |
|---|---|---|---|---|---|
| `run_film_manifest_smoke` | `65 films, 1 failures` | #221 `f08fca9` | stale | WP2 | `65 films, 0 failures` |
| `run_rung01_replan11_ux` | `12 checks, 1 failures` | #220 `9650cbd` | stale | WP2 | `12 checks, 0 failures` |
| `run_rung01_replan15_extrude` | `47 checks, 3 failures` | #217 `f81c1e5` | stale | WP2 | `47 checks, 0 failures` |
| `run_rung01_replan14_undo` | `119 checks, 2 failures` | #217 `f81c1e5` | product | WP3 | `119 checks, 0 failures` (and `rung01_sx038_focuskeys` stays `109 checks, 0 failures`) |
| `run_rung01_replan14_savelabels` | `229 checks, 6 failures` | #222 `dec9fb0` | product | WP4 | `229 checks, 0 failures` |
| `run_rung01_replan18_polyaf` (new) | — | — | net | WP1 | `<n> checks, 0 failures`, n ≥ 120 |
| every other suite | green | | | | green (see the full-tier re-run line below) |

**Re-run with all five fixes applied** (WP2 three test files, WP3 diff, WP4 diff, on a working tree of `f81c1e5`, reverted afterwards): `suites: 181 run, 0 failed` (full tier, `KEEP_GOING=1` run of `packaging/ci/run_suites.sh --tier full --keep-going`). The log and the combined diff are attached to the PR body as artifacts.


## sx-039

The checklist is **embedded below** (it is the walker's only input besides the soft-GL rules). 69 rows in 6 chunks, each chunk continuing from the previous one's app state, with the rows of #216–#225 restated, an explicit **re-verify map** for every spin-out, one-action-at-a-time instructions, and the soft-GL protocol. Walk it on the Linux build from the rolling `linux-test-build` prerelease whose `BUILDINFO.txt` `commit=` is the full sha of `main` after WP1–WP4 are merged, at a **1280×800 physical screen** if possible (if not, rule 54), with `SX_INPUT_TRACE=1` and its output in `$OUT/input-trace.log`.

### Chunks

| Chunk | Rows | Starts in | Ends in |
|---|---|---|---|
| 1 | N22 A1 A2 N7 L1 A3 L5 A4 L6 L10 A5 N12 A5b L8 L11 N17 (16) | Fresh app (window read first), File → New, ground sketch | Part mode, blank (Ø45 head + Ø20 pivot, 10 thick) exported and saved as `blank.sxp`, nothing selected, no menu open |
| 2 | A7 L2 A6 N4 A7b A8 N5 N25 A8b N8a (10) | End of 1 | Jaw sketch open for editing (pencil), Timeline visible, jaw `20` / `45°` committed, no pivot or head circle yet |
| 3 | A9 L4 N1a N21 N26 L12 N24 A17 A9c N1b N20 A9b (12) | End of 2 (sketch open) | Part mode, body cut by the open jaw (`Extrude Up To Surface 10.0000 mm`), `pre-cut.sxp` saved |
| 4 | A16 N6 A11a N10 N18 (5) | End of 3 | Part mode, shaft Slot cut (`Extrude Blind 2.5000 mm`), saved as `wrench-wip.sxp`, Top view |
| 5 | A11b N2 L3 A11c N3 A11d A11e N15 N13 N16 N19 N23 (12) | End of 4 | Part mode, neck R10 + top / bottom / slot-floor R1 applied, Fillet disarmed, nothing selected, Timeline on, document dirty |
| 6 | A12 N11 A13 A13b A13c N9 L7 N8b N14 A10 A10b A14 L9 A15 (14) | End of 5 | nut exported, lints, headless walks and full tier run |

If a chunk fails a row that the next chunk depends on, say which, and re-enter from the last saved `.sxp` (rule 11): after chunk 1 `blank.sxp`, after 3 `pre-cut.sxp`, after 4 `wrench-wip.sxp`. **Recovery that deletes geometry:** use the sketch drag-box (N24: Select tool, drag from empty canvas, then Delete). Ctrl+A also works.

### Re-verify map: every spin-out fix has a row

Walk these rows with the PR in mind. If one fails, write `REGRESSION of #nnn` in WALK_LOG with the full status log (rule 56).

| PR | Rows (chunk) | What the walker must see |
|---|---|---|
| #216 DOF chip | N8a (2), N25 (2) | After the pencil re-opens the jaw sketch the DOF chip reads the same text as before leaving it (a number or `OK`), never `—` / `— DOF`; after `Undo: Jaw` empties the sketch it is `—` |
| #217 fast keystrokes | L1 (1), A3 (1), L10 (1), A8 (2), A9 (3), N18 (4) | Every typed value arrives whole (`10`, `22.5`, `200`, `45`, `2.5`), a `2.5` burst after Ctrl+A replaces the field, Enter releases the field, a rail press or a tool key switches tools |
| #218 Extrude double-click | N12 (1) | A second click on the Extrude pixel changes nothing (`[input-trace]` `drop:shield`); no `hidden` status; the chip row is not under that pixel |
| #219 polygon | N4 (2), A11a (4) | The first Polygon press lands; the AF blank shows ` AF` and never `0.01`; typed `20` → `Polygon AF 20.0000 — flats horizontal` |
| #220 rail + Smart Dim | L1 (1), A3 (1) | Exactly one lit rail button after every press / key; no point marker and no coincident / horizontal badge inside either circle after the Smart Dim picks |
| #221 chips + box | L12 (3), N24 (3) | `Parallel?` / `Equal?` / `Perpendicular?` are gone after Esc, an empty click, Delete and undo; the first empty drag is a box (blue left→right, green right→left); Shift adds |
| #222 glyphs | N1a, N21, N26 (3) | At a ~150 px head: `22.5` on the head arc with a leader; one press on a badge selects that constraint; every badge ≤ 40 px from its anchor |
| #223 Timeline / Fillet | N23 (5), N3 (5), A11c–A11e (5), N19 (5) | Timeline ≥ 4 px under the chip row (8 px designed); Modify Radius row hidden after Fillet disarms; `… — Fillet no longer armed` |
| #224 Timeline editor | A13 (6), A13b (6) | Double-click focuses Distance with its text selected; `1` `4` land in the field (no `Front view` / `Back view`); the Params JSON row is gone after close |
| #225 T14 + host face | L7 (6), N14 (6) | Refusal says `1.250 mm limit`; the host face's tan tint is gone after the pointer moves |
| WP2–WP4 of this plan | A15 (6), L10, N1a | `make test-godot` ends `0 failed`; Ctrl+Z in a focused field leaves the sketch alone; labels do not move on Ctrl+S |

### Re-verify rows (FAIL or PARTIAL in sx-038)

| Row | sx-038 | Fixed by | Pass now (chunk) |
|---|---|---|---|
| L1 | FAIL two lit buttons; `S` swallowed | #220 #217 | one lit button; `S` switches (1) |
| N12 | FAIL second click hid the body | #218 | nothing changes (1) |
| N21 | FAIL glyph click did not select | #222 | `Constraint selected: <type> — Del removes it` (3) |
| N26 | FAIL badge pile-up, no leaders | #222 | spread, leaders at 12 px (3) |
| N23 | FAIL 2 px gap | #223 | ≥ 4 px (5) |
| A13 | FAIL Distance unfocused | #224 | focused, keys land (6) |
| L7(b) | FAIL `0.250` | #225 | `1.250` (6) |
| N14 | FAIL host face selected | #225 | tint gone (6) |
| A3 N8a N1a L10 N4 L12 N24 L9 | PARTIAL | #216 #217 #219 #220 #221 #222; L9 is the spec decision | rows restated with the exact numbers (1, 2, 3, 6) |

### Changed text vs sx-038 (use these strings)

| Where | Now |
|---|---|
| Fillet apply | `Fillet <n> edges <r> applied — View ▸ Timeline to edit parameters — Fillet no longer armed` (r with two decimals). Fillet is **disarmed**: re-arm (body selected → `Fillet` chip) before the next fillet |
| Fillet refusal at T=14 | `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius` |
| Polygon hover | The pointer sits on the **circumscribed circle** (not necessarily on a vertex); `Polygon AF <size> — flats horizontal — click to place (or type the size)` with `<size>` = √3 × the pointer's distance from the polygon centre; independent of the bearing. Typed size: `Polygon AF 20.0000 — flats horizontal`. The AF blank placeholder is ` AF` |
| Select statuses | `Selected body <id8>` / `Selected face <id8>` / `Selected edge <id8>`; sketch: `Selected 1 sketch entity`, `Selected <n> sketch entities`, `No sketch entities`. A plain click on a second sketch entity **adds** it (click again to deselect) |
| Constraint glyph press | `Constraint selected: <type> — Del removes it` |
| Esc in a sketch that holds geometry | Never discards. Selection → `Selection cleared — Esc again exits the sketch`; draw tool → `Tool dropped — Esc again exits the sketch`; pending first point → `First point dropped — Esc again exits the sketch`; last Esc → `Sketch saved` (empty sketch: `Sketch cancelled`) |
| Keys in a number field | Letters never enter a length field. Before a digit is typed a tool key (`L`, `D`, `T`, `C`, `S`) still switches tools; once a digit has landed the field owns its keys. A field you **clicked into** owns Ctrl+Z; Ctrl+Shift+Z / Ctrl+Y stay with the sketch until a digit is typed |
| Sketch undo / redo | `Undo: Jaw`, `Undo: Dimension`, `Redo: Jaw` …, `Nothing to undo`; the DOF chip follows (`—` when empty) |
| Part mode keys | Ctrl+Z → status begins `Undo`; Ctrl+Shift+Z (or Ctrl+Y) → status begins `Redo` |
| Views | keys `1` Front, `2` Right, `3` Top, `4` Back, `6` Left, `7` Iso, `8` Bottom; menu-bar View → Orientation lists the same seven; Top and Bottom look **through the open jaw** (a click in the jaw slot selects nothing) |
| Jaw preview | A rotated **rectangle** after click 1 and after click 2 (never narrower than 3.0 mm across) |
| A8b | The jaw sketch is `sketch 3` (names are indices) |
| Shaft lines | `Shaft lines: 2 added`; tangent to the Ø20 pivot (offset 10 mm), not to the Ø45 head (by design) |
| Export | `Exported 3MF → <path>` |

### Soft-GL protocol (sx-039 walker)

Rules 1–16 (replan 10), 17–22 (11), 23–30 (12), 31–36 (13), 37–40 (14), 41–44 (15), 45–51 (16, 17) stay as in [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md). Highlights: read every typed field back before Enter (1); one retry of a dead click, never a third (2); the status line is the truth, screenshots lag one action (8, 36); real rail presses (33); first glyph of a label (27); never move the view to dodge the rail (28); Esc ends an armed pick (29); one Extrude click then read (41); typed export names read back (43). Restated 45–51:

45. **A plain click never prints `Editing sketch`.** `Editing sketch` appears only after the Timeline pencil, a double-click on a Timeline sketch, or rail Sketch → click a sketch / pad. Any other `Editing sketch` is a **product failure** (N15); stop that row, record the full status log, do not click again.
46. **Results hold 2.5 s, then the hint arrives by itself.** After a command result (`Opened …`, `Framed all`, `No view for key 0 …`) keep the pointer **still** on a face (nothing selected): the label reads the result until 2.5 s after the result, and the hover hint replaces it by 3 s **without any pointer movement** (N16). A hint earlier than 2.5 s, or no hint at 4 s, is a failure. Moving the pointer off the body during the hold must leave the result on the label.
47. **Typed values replace.** The first key into a numeric field replaces the whole value (strip `R`, panel Radius, Distance, circle / polygon / slot fields, dimension editor). A field reading `10` after typing `1` `.` `5`, or `1` after typing `10`, is a failure; one retry (rule 1), then record.
48. **Camera rows read the picture twice.** For N18 screenshot the part view immediately before entering the sketch and again after the Extrude result; compare the head and pivot pixel positions (±5 physical px).
49. **Soft-GL evidence** = screenshot + status text + one retry on a fresh frame. Allowed classes: lag (8), dropped key (1), one ~10 s File-menu stall under llvmpipe, large tilt per small orbit drag. Anything else is a product row.
50. **Number the contours by size** (rule 42) and read `Contour N of M — W × H mm at (x, y)` for N10.
51. **A dead first click is recorded, not guessed.** With `SX_INPUT_TRACE=1` every left press prints `[input-trace] press (x,y) <disposition>` to `$OUT/input-trace.log` (`sketch-click:<TOOL>`, `sketch-drag:<TOOL>`, `sketch-box:SELECT`, `drop:over-chrome:<name>`, `drop:not-owner:<name>`, `drop:shield`, `drop:dim-label:<i>`, `model-click`). When a click does nothing: copy the last log line into WALK_LOG (that is the evidence), retry once (rule 2), never a third. A dead click whose log line is `sketch-click:<TOOL>` with no entity added, or any `drop:*` on a canvas point, is a **product failure**; a click with no log line at all is a window-focus click (soft-GL).

New in this plan (sx-038 walkers batched actions and lost detail):

52. **One action, one read.** One tool call = one click, or one key, or one typed string, or one drag, or one hover. After it read the status line and take one screenshot **before** the next action. Never send two actions in one call; never type a value and press Enter in the same call (type, read the field back, then Enter).
53. **Write WALK_LOG after every row**, before starting the next: row id, verdict (`PASS` / `FAIL` / `PARTIAL` / `SOFT-GL`), the exact status text read, the screenshot name, any retry. Never summarise a chunk afterwards; a row with no WALK_LOG line is not walked.
54. **Physical pixels.** At the start write the physical screen size and the screenshot size. Every pixel number in a row (gaps, distances, zoom, 40 px, 150 px) is measured on a **full-resolution** screenshot (or with `xdotool getmouselocation` / `xwininfo`); if the screenshot is scaled, multiply by the scale factor and write it down. sx-038 measured scaled images (1920×1200 screen, 1280×800 shots).
55. **Bursts and keys.** "As one burst" means `xdotool type --delay 10 '<text>'` in a single call, then read the field. "Type `1` then `4`" means two separate key calls. A burst that loses a key is retried once (rule 1), then recorded as `FAIL #217`.
56. **Name the regression.** A row that re-verifies a PR (map above) and fails is written `REGRESSION of #nnn` with the full status log of that row and the `[input-trace]` lines of the presses.
57. **PASS means every clause.** A row is PASS only when every clause of "Pass looks like" held. Otherwise it is PARTIAL and the failing clause is quoted. A clause you did not measure is not passed.
58. **Retries are visible.** Any retry (rule 2) is written in the verdict (`PASS after 1 retry`); a row that passes only after a retry on a first-click clause is PARTIAL.
59. **No setup beyond the row.** Do not click, type or press anything the row does not list. If you must recover (rule 11), write the recovery in WALK_LOG and mark the next row `recovered`.
60. **Start-up evidence.** Before row N22 record the build: `BUILDINFO.txt` `commit=` equals the full sha of `main` after WP1–WP4; the launch line shows `SX_INPUT_TRACE=1`; `DISPLAY`; the physical screen size.

### The 69 rows

### Chunk 1 — blank (16 rows)

Start: launch (rule 51 env), read the window (N22), File → New (`New — empty part, Top plane (XY). View ▸ Timeline to edit features`), rail **Sketch** on the ground plane. Keep the blank open through A13c (rule 10).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| N22 | r17-WP4 | Before any click: `xdotool search --name SolidExpress` → `xdotool getwindowgeometry <id>`; `xprop -id <id> _NET_WM_STATE`; `xdpyinfo | grep dimensions` | Window width ≥ 1272 and height ≥ 750 on a 1280×800 screen (usable rect minus decorations, ±8 px), or `_NET_WM_STATE_MAXIMIZED_HORZ` and `_VERT` present. Not ~1072×620. The menu bar, left rail and bottom status row are all inside the screen. **Write the physical screen size and the screenshot size in WALK_LOG**; if they differ (sx-038 used a 1920×1200 screen and 1280×800 screenshots) every pixel number in this walk is physical (rule 54) |
| A1 | #185 | Read the left rail in the new sketch (before drawing) | All **19** rail labels fully visible at 1280×800, last label inside the window, none clipped. The chip row starts right of the rail, covers neither Arc nor Point, ends inside the right edge (re-read in A3 with two circles selected) |
| A2 | #196 | Press **Jaw**, then **Rect** | Jaw: a status starting `Jaw`, no variant chips. Rect: `Rect — click 1 first corner, click 2 the opposite corner`; chips left to right `Corner` (highlighted), `Center`, `Three Point`, `Center Three Point`, `Parallelogram` |
| N7 | #198 | Rail **Jaw**; then rail **Rect**; then rail **Circle** and click one centre | The armed button is lit — accent fill and a 3 px accent bar on its left edge — clearly different from a merely hovered button; only that button is lit. Circle centre click: `Circle — centre set, click the rim or type a radius` |
| L1 | #220 #217 | One press, then read, per button. Rail: **Jaw**, then Line, Smart Dim, Trim, Slot, Circle, Select in turn. Then keys, one at a time, **without clicking or typing in the Radius field**: `L`, `D`, `T`, `C`, `S` | Each press prints a sentence that starts with that tool's own name, never the previous tool's. **Exactly one** rail button is lit after every press and every key (the active tool's), also when the previously pressed button is still under the pointer; Slot's button is lit while Slot is armed. The Radius field is **not** prefilled with another tool's number. After `C` the Radius blank is focused but untouched: `S` still switches to `Select …` (by design a field you clicked or typed in keeps its keys: if you did, press the Select rail button instead and write `field owned` in WALK_LOG). Each rail press and each first canvas click lands on the first attempt (rule 51 for any miss) |
| A3 | #182 #217 #220 | Delete the A2/N7 scratch (select, Delete, or Esc to empty). Circle tool: **first click** at the origin; type `10` Enter. Circle: click right of it; type `22.5` as **one burst** (`xdotool type --delay 10 22.5`, rule 55) and read the field back before Enter; Enter. Smart Dim: click centre 1 (`Smart Dim: first pick set …`), plain click centre 2 (no Shift); type `200` Enter | Both first clicks land. Typed digits replace the field and every key arrives: `10`, `22.5` (never `2.5`, `0.5`, `225`), `200` (rule 47). `Circle r=10.0000 (Ø20.0000)`, `Circle r=22.5000 (Ø45.0000)`, `Dimension updated`. Centres level (head centre y = pivot y ±0.05). **No stray point marker and no coincident / horizontal badge inside either circle after the Smart Dim picks** (#220; zoom a screenshot on each circle). Chip row check from A1 with both circles selected |
| L5 | #182 | Press `F`; then HUD **Frame**; then `Shift+F` | `Sketch view fit` (or the HUD's equivalent); **both** circles fully inside the canvas, right of the rail and inside the window each time; the grid covers the whole canvas; no stale disc |
| A4 | carry | **Shaft Lines** | `Shaft lines: 2 added` (offset 10 mm from the axis: tangent to the Ø20 pivot, by design not to the head) |
| L6 | #183 | Read the canvas; zoom out three wheel notches | No red / orange ✕, no live Δ labels. Blue `H` / tangent badges are expected. A **red or orange** H badge or a conflict count is a failure. Squashed circles in a screenshot with equal projected x / y: soft-GL (rule 35) |
| L10 | #200 #217 | Finish bar Distance: type `10` Enter, then `14` Enter, then `10` Enter; read the field right after each Enter and one frame later. Then click the field again, type `1` `.` `5`; Ctrl+A; then type `2.5` as one burst | The field never shows the previous value (rule 47); ends at `10`; `1.5` reads `1.5`; Ctrl+A selects the field text (it does not select sketch entities) and the burst `2.5` replaces it (`2.5`, never `2.05` or `2.052.5`); Enter releases the field, so a key pressed after Enter goes to the viewport. A one-frame flash seen only in a lagging screenshot is rule 8. Leave the field at `10` |
| A5 | #197 | Set Distance `10`, Blind, New. Click **Extrude** once with the mouse | After two frames: `Extrude Blind 10.0000 mm`. The view frames the whole new body (Ø45 head and Ø20 pivot ends both visible), **no** red ✕, **no** yellow sketch lines over the body. Then File → Export 3MF, type `blank.3mf` in `$OUT` (read the field back); `Exported 3MF → $OUT/blank.3mf`; checker blank **5/5** |
| N12 | #181 #218 | Re-verify the A5 Extrude (rule 41): read the result and the part chip row. Then (a) click the **same pixel** once more (a real second click, ≥ 0.5 s after the first); (b) move the pointer onto the `Fillet` chip and click it once; (c) Esc, and Esc again until `Selection cleared` (at most twice) | One body; Timeline `sketch 1`, `extrude 2` (names are indices, rule 37). The chip row (`Hide`, `Fillet` …) is **not drawn on the Extrude pixel**. (a) changes nothing: feature count equal, body still visible, no `hidden` status, no `jaw_af` / AF chip text, and the `[input-trace]` line for that press is `drop:shield` (#218). (b) the press lands: status begins `Fillet r=` (a motion onto another chip is a new gesture). (c) `Edge pick cancelled`, then `Selection cleared`; nothing is selected when A5b starts |
| A5b | carry | File → New: the Discard dialog → **Cancel**. Then File → Save As | Cancel keeps the blank. Save As dialog opens pre-filled `untitled.sxp`, name selected |
| L8 | carry | In that dialog do **not** press Ctrl+A; type `blank.sxp`; read the field back; OK | Typing replaced the selected name; `Saved $OUT/blank.sxp` |
| L11 | carry | Open the HUD **View ▼** menu; close; open the menu-bar **View** menu | Both lists are opaque; no button shows through them |
| N17 | #204 | Click the body (selected; the status names the level, `Selected body …` on an unselected body, `Selected face …` when the body was already selected). Open the menu-bar View menu, press **Esc** once; repeat with the HUD View ▼; then press Esc once more with no menu | First Esc: the menu closes, the selection **stays**, the left panel mode is unchanged, no `Selection cleared`. Same for the HUD menu. The third Esc → `Selection cleared`. (A face vs body result is the two-stage pick, by design: the status word says which) |

End of chunk 1: part mode, nothing selected, `blank.sxp` saved, `blank.3mf` exported.

---

### Chunk 2 — face sketch, Esc ladder, jaw (10 rows)

Start: end of chunk 1.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A7 | #199 | Plain-click the top face once, then rail **Sketch**, then click the top face again | The plain click gives a status beginning `Selected ` and **never** `Editing sketch` (rule 45). Rail Sketch: `Select a face or existing sketch (Esc to cancel)`; then `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`; the view frames the **whole blank**: Ø45 head and Ø20 pivot both inside the canvas, right of the rail, without `F` |
| L2 | carry | In this new sketch set the finish bar to **Cut / Up To Surface / `7`**. Keep it | Used by A6 next |
| A6 | #201 | Circle tool, **one** click in the canvas (with Up To Surface still set), Esc, Esc. Exactly two presses | The click lands (`Circle — centre set, click the rim or type a radius`; no face pick, no `Selected`). Esc 1: `First point dropped — Esc again exits the sketch`. Esc 2: `Sketch cancelled` (empty sketch). No `Measure cleared` between. Afterwards **no face is selected** and no `Face: …` pick is pending |
| N4 | #201 #219 | Rail **Sketch** on the top face (read the finish bar: **Blind / New / 20**). Rail **Polygon**; read the status and the AF field; **one canvas press** for the centre (it must land first time, rule 51); read the AF field again; type `20` Enter. Circle tool: click the centre, click into the Radius field: (a) Ctrl+A; (b) Esc, Esc. Then part mode: Ctrl+Z | Finish bar reset. Polygon: status after the rail press `Polygon — click the centre, then a vertex (or type the size)`; the centre press lands (hexagon preview follows the pointer); the AF blank shows its placeholder ` AF` and **never `0.01`**; typed `20` replaces it → `Polygon AF 20.0000 — flats horizontal`. (a) the field text is selected; no `Selected … sketch entities`; selection unchanged. (b) Esc 1 `First point dropped — Esc again exits the sketch`; Esc 2 `Sketch saved`; the host face is **not** left selected. Ctrl+Z: status begins `Undo`; the throwaway sketch leaves the Timeline |
| A7b | #199 | Rail Sketch on the top face again | Face sketch opens framed on the whole blank (`Sketch on face (plane +Z @ origin 0.0,0.0,10.0)`); finish bar Blind / New / 20 |
| A8 | r17-WP2 #217 | **Jaw**: click 1 (on the Ø45 head end of the blank), click 2, **click 2 again at the same pixel**, click 3. Then **one click on the first glyph** of the width label `20`, type `20` Enter; then of the angle label `45°`, type `45` as one burst (rule 55), read it back, Enter | After click 1 the preview is a rotated **rectangle** (4 edges), not one line; after click 2 a rotated rectangle; with the pointer on the axis a thin rectangle (3.0 mm across, never a doubled line). The repeated click 2 prints `Jaw — width is zero — click 3 again for half the width`, no `Jaw committed`, entity count unchanged. Click 3: `Jaw committed — width …, long side …° — click a label to edit it`, non-zero width. Each label opens on the **first** click with its text selected (rule 47); the field reads `20` / `45`, never `4` (a dropped digit is a product failure after #217: one retry, then record); `Dimension updated`; walls at 45°, included angle 90° ±0.05°. Initial labels like `16.9044` / `-32.49°` before editing are fine |
| N5 | carry | Select tool. Ctrl+Z, Ctrl+Shift+Z, Ctrl+Z, Ctrl+Z … until empty, then Ctrl+Shift+Z until the jaw and both dimensions are back | `Undo: Jaw` removes the Jaw (earlier `Undo: Dimension` steps first); `Redo: Jaw` restores it; at the empty end `Nothing to undo`; after the redos `20` and `45°` are shown again with the jaw. Trust statuses and entity count (rule 40) |
| N25 | r17-WP2 | Read the DOF chip (bottom-left status area) at three moments of N5: with the jaw drawn; right after `Undo: Jaw` with the sketch empty; right after `Redo: Jaw` | Empty sketch: `—` (never `3` or any stale number); after the redo the chip equals its text before the undo (a number or `OK`, same as a fresh jaw). No `!` conflict marker |
| A8b | checklist | Select tool, click a jaw line, **Esc**, **Esc**; then in part mode Ctrl+Z, then Ctrl+Shift+Z | Esc 1: `Selection cleared — Esc again exits the sketch` (no `Measure cleared` first). Esc 2: `Sketch saved` — the sketch and jaw are **kept**. Selecting the Select tool reads `Select — click geometry, or a dimension label to edit it`. Part Ctrl+Z: status begins `Undo`, the sketch leaves the Timeline. Ctrl+Shift+Z: status begins `Redo`, **`sketch 3`** is listed again with the jaw (Timeline: `sketch 1`, `extrude 2`, `sketch 3`; the N4 throwaway was removed by its Ctrl+Z, so it consumes no number) |
| N8a | #184 #216 | Take the **N18 screenshot** of the part view (rule 48), then View ▸ **Timeline** on (check N19 / N23 later). Read the DOF chip once in the sketch you are about to leave (it reads a number or `OK`); click the **pencil** next to the jaw sketch | `Editing sketch`; no rename field (F2 on the row still renames). Finish bar reads **Blind / New / 20**; the sketch view is centred on the part. The DOF chip in the re-opened sketch reads the **same text as before the exit**, never `—` or `— DOF` while the sketch has geometry (#216) |

End of chunk 2: jaw sketch open in edit mode.

---

### Chunk 3 — pivot, trim, labels, cut (12 rows)

Start: jaw sketch open (end of chunk 2). The N18 screenshot from N8a is the reference for A9b (rule 48).

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A9 | #203 #217 | Press `F`. Circle tool: **first click** on the pivot centre at the origin, 30 px right of the visible rail, view unmoved; type `5` Enter. Circle tool again: redraw the Ø45 head on the head centre, type `22.5` as one burst, read it back, Enter. Draw a **plain Line** (not Centerline) across the head: read the Line Length field before typing. **Power Trim** (`T`): drag from the **outer stub** across the Line | First click lands: `Circle r=5.0000 (Ø10.0000)` (rule 28); the head reads `22.5`. The Line Length field is **not** `22.5` (no leak from Circle). Trim: `Trimmed open jaw`; the Line is gone; no pan; **no red trail** left after the mouse is released (screenshot after the release). A second drag: `Jaw is already open — nothing left to trim here`. If the Line is not across the head the status is `Nothing trimmed — no crossing at that point` (never a bare `Trimmed`); redraw and retry. WALK_LOG: the Line Length text, the two Trim statuses, the screenshot name (sx-038 lost these) |
| L4 | #186 | Read the jaw labels right after Trim | Exactly one `20` and one `45°`; no `20.0005` / `45.0007°`; no overlapping labels. (Wall 45° ±0.1° is confirmed by wrench 28/28 in chunk 6) |
| N1a | r17-WP1 #222 r18-WP4 | Zoom with the wheel until the Ø45 head is **~150 px** across (physical px, rule 54). List every dimension label (text and place) | Exactly `20`, `45°`, `5`, `22.5`. `22.5` sits **on the head arc** (≤ 40 px from the head circle, with a thin leader to it) — not ~100 px above the head; the `45°` label is ≥ 4 px from the nearest coincident badge; none overlaps another label or a glyph (gap ≥ 4 px); none is under the menu / rail / chips; the first glyph of `20` and of `45°` is clickable (opens the editor; Esc closes it) |
| N21 | r17-WP1 #222 r18-WP4 | Same zoom: read the constraint glyphs around the head and pivot. Select tool; **one press** on a horizontal badge, read the status; one press on a parallel badge, read; one press on a coincident badge, read | No pile-up: glyphs are spread (≥ ~60 % of each visible). Each press **selects that constraint, not the line or circle under it**: status `Constraint selected: <type> — Del removes it` (type names the badge). Do not press Delete |
| N26 | r17-WP1 #222 r18-WP4 | Same zoom: for each tangent and coincident badge find the vertex or contact point it belongs to | Every badge is within 40 px of its vertex / contact point; a badge pushed 12 px or more has a thin leader line to its point; none sits off the part (nothing below the shaft's lower edge, none inside empty space between shaft and head); the `5` label has clear space (≥ 4 px) to every `H` badge |
| L12 | #206 #221 | Arm Circle; move over the jaw and shaft lines. Then Select tool and hover with no click; leave the line; press `F`; hover again; Esc. Then click a shaft line (thin) once. Then: select the two shaft lines (click one, click the other), read the chips, press Esc; select them again, click empty canvas; select them again, press Delete (then Ctrl+Z) | Circle armed: **no** ✕, no Δ labels, ever. Select + hover: ✕ **with** Δu / Δv; the ✕ is gone when the pointer leaves the line, after `F`, `Shift+F` or HUD Frame, and after a click on empty canvas. Esc over a ✕ → `Measure cleared`, chips still showing. The shaft-line click selects it **on the first click**; then the ✕ is gone and the next Esc is `Selection cleared — Esc again exits the sketch`. With the two lines selected the chips `Parallel?` / `Equal?` / `Perpendicular?` may show; **after Esc, after an empty click, after Delete and after the undo none of them is still on screen** (#221). Redo the Delete only if the next row needs the lines |
| N24 | r17-WP3 #221 | Select tool. Draw a throwaway Circle r `3` in empty canvas (≥ 60 px from all geometry); Select tool. Every drag **starts on empty canvas ≥ 60 px from any entity** (a drag that starts on an entity moves it). (a) Left-to-right drag that **encloses** the circle; (b) press-release on empty canvas; (c) right-to-left drag from empty canvas that crosses only the circle's rim; (d) a left-to-right drag that only **cuts through** the rim; (e) click one jaw wall, then Shift + window drag around the circle; (f) click empty canvas; (g) window-drag the circle again, press Delete | (a) a **blue** box shows while dragging; status `Selected 1 sketch entity`. The **first** drag of each kind works (#221: no dead first drag). (b) selection cleared. (c) a **green** box; `Selected 1 sketch entity`. (d) `No sketch entities` and the selection is empty (window needs the whole entity). (e) the click selects only the wall (1), the Shift window adds the circle: `Selected 2 sketch entities`. (f) cleared. (g) `Deleted 1`; the jaw, pivot and head are unchanged (entity count back to the count before the throwaway) and `20` / `45°` labels remain. By design a **plain click on a second entity adds it** to the selection (click it again to deselect): two selected after one click means the previous selection was still alive; write the step before it in WALK_LOG |
| A17 | #202 | Read the Line / Centerline chips and the Contours row. Click the Centerline chip with the pointer over the canvas | Chips do not overlap; Contours row only with more than one closed region; the chip click places **no** point or line on the canvas; a Centerline commit reads `Centerline added — construction, not part of the profile` (draw one and delete it); after Ctrl+Z and Ctrl+Shift+Z no phantom line appears and no suggestion chip lingers after the undo |
| A9c | carry | Set the finish bar to **Cut**, **Up To Surface**, pick the opposite face (`Face: z 0.0 mm`), thin / flip off. Then File → Save As `pre-cut.sxp`; OK | `Saved $OUT/pre-cut.sxp`; the sketch, Select tool and profile are still there; the finish bar is exactly as set (Cut / Up To Surface / `Face: z 0.0 mm`) — it is **not** reset |
| N1b | #186 | List the labels again; hover a label while its editor is open | Identical to N1a (no second `45°`, no new `5` / `22.5`). Editor open: no Δ overlay, no ✕ left at an old endpoint |
| N20 | carry | Save As `pre-cut.sxp` again (overwrite); press Ctrl+Z | `Saved …` again; finish bar still Cut / Up To Surface / `Face: z 0.0 mm`; Extrude button enabled; Ctrl+Z status begins `Undo:` (sketch undo kept) — then Ctrl+Shift+Z |
| A9b | #197 | Click **Extrude** once; read the status after two frames | `Extrude Up To Surface 10.0000 mm`; no `breaks the chain`, no open-shell refusal. The view frames the new body; **no** yellow jaw / pivot / head lines remain over the solid. Select the body: size reads 232.5 × 45.0 × 10.0 (±0.3) (if no size readout exists, A12 28/28 is the evidence). A plain click inside the head → `Selected `, never `Editing sketch` (rule 45). **N18 (first read):** the part view equals the screenshot from N8a (head and pivot ±5 px) |

End of chunk 3: part mode, jaw cut, `pre-cut.sxp` saved (re-save with Ctrl+S now so it holds the cut: `Saved …`).

---

### Chunk 4 — views, slot (5 rows)

Start: end of chunk 3.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A16 | #204 | Menu-bar View → Orientation; HUD View list; keys `1` `2` `4` `6` `7` `8`; orbit off Top with the preset's orbit drag; then key `3` | Both lists show Front, Back, Left, Right, Top, Bottom, Isometric; each key shows its view (`Front view`, `Right view`, `Back view`, `Left view`, `Isometric view`, `Bottom view`); key `6` and the HUD Left give the same picture; the drag moves the camera (a large tilt per small drag is leftover 23, soft-GL); `3` → `Top view`, exact top (straight down, orthographic), the part centred, the **open jaw seen through**: a click in the jaw slot selects nothing |
| N6 | carry | Part mode: key `3`; wheel-in three notches with the pointer on the head; wheel-out three; `F`; `Shift+F`; HUD **Frame** | The point under the pointer stays under it (±2 px) through the wheel. `F` → `Framed selection` (body selected) or `Framed all`; the part lands right of the left panel inside the window; HUD Frame gives the same view. End in Top view |
| A11a | #199 #203 #219 | Screenshot the Top view (N18). Rail Sketch on the top face (click the head meat, not the jaw slot). Rail **Slot**; type radius `5` Enter; click centre 1 at `(18.5, 0)` (**first canvas press, it must land**, rule 51); read the field label (`c-c`); type `150` Enter | The sketch opens framed on the whole body. Slot lit; status `Slot — …`; stadium preview; centre 1 is set by the first press; label `c-c` after the first centre, the field is **not** prefilled `5.0` and not `0.01`; `Slot c-c 150.0000 R5.0000 — typed` (rule 23). Finish bar: Blind / New / 20; the Extrude Distance stays 20 until you set it |
| N10 | r17-WP1 | Draw a throwaway Circle (r 5) in the head so the sketch has two closed regions: the **Contours** chips appear. Hover chip `2`; click chip `1` off, then on; then delete the throwaway (Select, click it, Delete) | Hover: that region gets a clearly **stronger** fill (about 3 × the included region's fill, visible without a zoom tool) with a `2` tag and a double outline; the included region keeps the light fill; a skipped one is outline only. Click: `Contour 1 of 2 — W × H mm at (x, y) — skipped` then `— included` (read the status, rule 50). After Delete: `Deleted 1`, chips gone |
| N18 | carry #217 | Set **Cut**, **Blind**; click the Distance field, Ctrl+A, type `2.5` as one burst, read it back, Enter. Click **Extrude** once. Save As `wrench-wip.sxp` | The Distance field read `2.5` (never `2.05` / `2.052.5`, #217). `Extrude Blind 2.5000 mm` (a real Slot). The part view is the **Top view screenshot** from A11a (head and pivot ±5 px; the camera does not jump). `Saved $OUT/wrench-wip.sxp` |

End of chunk 4: part mode, Top view, slot cut, `wrench-wip.sxp` saved.

---

### Chunk 5 — fillets (12 rows)

Start: end of chunk 4. Fillets are picked from keys `3` (Top), `4` (Back), `8` (Bottom), `1`, `7`, with the body selected. Zoom with the wheel or `F`. Click each fillet target **once**; a first click that misses is a failure (leftover 4). In Top view the jaw slot is see-through: click the neck corners and head, never the slot.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A11b | #168 | Select the body (click it). Press the **Fillet** chip (Fillet armed). Key `3`. Click each **neck corner** (the two vertical edges where shaft meets head). Key `4` and click the +Y wall; press on the empty background. Do **not** press Enter yet | Corner click: `Fillet: 1 edge(s) — 10.0 mm vertical …` (not the 32.3 mm arc, and no `0.0 mm line`); the wall click keeps the set (adds an edge only within 14 px, else `No edge near click …`); the background press: `Missed the solid — click a face or edge`, set and panel kept |
| N2 | #205 | Fillet still armed. (a) Strip `R`: ▲ then ▼ then key `3`. (b) Strip `R`: click into it, type `10`, Enter, then keys `3` and `4`. (c) Panel **Radius**: click into it, type `10`, Enter, then key `3` | (a) ▲ `2.5 mm`, ▼ `2 mm` (step 0.5), key `3` → `Top view`. (b)(c) the field reads `10 mm` (no extra digit, never `1` / `100`); **Enter does not apply the fillet** and no fillet editor opens; the field releases the keyboard (key `3` → `Top view`, key `4` → `Back view`); **Fillet is still armed** (strip `R` visible; `Fillet r=10.00 — edit Radius, click edges, Enter`). Rule 47 |
| L3 | #200 | Strip: type `10` Tab. Panel: type `1.5` Tab; then `10` Tab | Strip `R`, panel Radius and the status show the **same** number each time (same text, `10 mm` / `1.5 mm`; the `.` is not dropped); Tab leaves the field and the next key goes to the viewport (key `3` → `Top view`, not `AF 10`). Enter uses the number on screen. End at `10` |
| A11c | #205 #223 | Click one wrong edge; read the status; click it again. Then press **Enter** in the viewport at R10 (the apply of A11b) | Count rises then drops: status ends `— removed 179.8 mm line` (a length and kind). Enter with the two verticals: `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters — Fillet no longer armed` (not `Feature created`; **no** editor opens; Esc afterwards does not undo it). **Fillet is disarmed now (#223): the Modify Radius row is gone** and the next fillet needs the Fillet chip again |
| N3 | carry #223 | Note the x of the `Fillet` and `Chamfer` chips with the body selected; then with a face selected; then with Fillet armed. Note the right edge x of the left Modify panel in the same three states | Both chip x identical (±1 px) in all three states; the bar is fully below the menu row, never touches `Snap`, ends inside the window (wraps if needed); clicking the noted x arms **Fillet** every time. The Modify panel's width is the same armed and disarmed (±1 px; #223). Minor label overlap near `Name` is a note, not a failure, unless text is clipped |
| A11d | #205 #223 | **Re-arm Fillet** (the apply in A11c disarmed it; if the part chip row is not showing click the body once, `Selected body …`, then click the `Fillet` chip). Click the strip `R` field, type `1`, Enter. Key `3`; click the **top face** once (inside it, away from edges, ≥ 8 px; not in the jaw slot); Enter. Then **re-arm again** (body selected → `Fillet` chip → strip `R` `1` Enter); key `8`; **one click on the bottom face, then move the pointer twice**; Enter | Face click: `Fillet: <n> edge(s) — …` with n ≥ 6 and no `0.0 mm line`. Both Enters: `Fillet <n> edges 1.00 applied — View ▸ Timeline to edit parameters — Fillet no longer armed` first try; never `No edges selected`; the body does not move and no `Moved body`; after each apply Fillet is disarmed and the Modify Radius row is hidden (a second Enter does nothing) |
| A11e | #205 #223 | **Re-arm Fillet** (as A11d, strip `R` `1`). Key `3`; **one click on the slot floor** (inside the slot outline, away from the rim); Enter. **Re-arm again**; strip `R` `1.5`, Enter; click the slot floor again; Enter. Esc | Click: `Fillet: <n> edge(s) — …` listing the floor's ≈150 mm lines and ≈15.7 mm arcs (not the neck loop `175.4 line, 42.2 line`). First Enter: `Fillet <n> edges 1.00 applied … — Fillet no longer armed`. The R1.5 Enter is **refused** and Fillet stays armed: `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius`. Esc → `Edge pick cancelled`; Fillet no longer armed; the Modify Radius row hides |
| N15 | carry | Fillet not armed (after the Esc). (a) Click **empty ground** inside the part's sketch footprint; (b) click the **slot floor**; (c) click the **Fillet chip**; (d) Esc | (a)(b) status begins `Selected ` (or the selection simply changes); **never** `Editing sketch`, never a sketch entering edit mode, never a loft status. (c) `Fillet r=…` (armed). (d) `Edge pick cancelled` |
| N13 | carry | Part mode, no field focused (click empty viewport first): press `0`, then `3` | `No view for key 0 — use 1 2 3 4 6 7 8`; the camera did not move; `3` → `Top view` |
| N16 | r17-WP4 | Click empty background so **nothing is selected** (status `Selection cleared` or no selection chips). Press `0`; **at once move the pointer onto a face of the body, then do not touch the mouse** (no 1 px nudge); watch the label for 4 s | The label reads `No view for key 0 — use 1 2 3 4 6 7 8` until 2.5 s (rule 46); between 2.5 s and ~3.5 s it changes **by itself** to the hint `Face — click selects body first, click again for face · then Pull arrow`. Repeat once moving the pointer off the body to empty ground during the hold: the result stays on the label (no stale hint) |
| N19 | carry #223 | View ▸ **Timeline** on (already on from N8a: leave it). Click the body, click the `Fillet` chip; look at the left Modify panel; click the Radius field and type `2`; Esc | The Timeline does **not** cover the Radius field or any Modify panel control (they do not intersect; both fully inside the window); the click focuses Radius (field reads `2`); Esc → `Edge pick cancelled` and the Modify `Radius` row is **hidden** (no stale `Radius 1.5 / 2 mm` panel; #223). Fillet is not armed |
| N23 | r17-WP4 #223 | Timeline on. Click the body (it is selected: the part chip row shows `Group`, `Similar`, `Hole`, `Hole Wizard`, `Fillet`, `Chamfer` …). Read the left end of the chip row and the Timeline top **in physical px** (rule 54). Esc (deselect); click the body again | The chip row's left end (`Group` …) is fully visible, not covered by the Timeline; the Timeline sits **below** the chip row (top ≥ chip row bottom + 4 px on a 1280×800 screen; ≥ 6 physical px if the screen is 1920×1200) while the body is selected, both inside the window; with nothing selected the Timeline returns to the top of the left column; selecting again moves it below again. The chip row does not move (x unchanged ±1 px, N3). End with nothing selected |

End of chunk 5: Fillet disarmed, nothing selected, Timeline on, document dirty (`wrench-wip.sxp` is older).

---

### Chunk 6 — export, thickness, dirty flag, nut, lint (14 rows)

Start: end of chunk 5.

| Row | Check | Action | Pass looks like |
|---|---|---|---|
| A12 | #188 | File → Export 3MF, type `wrench.3mf` (read back), OK | `Exported 3MF → $OUT/wrench.3mf`; checker wrench **28/28**, `flipX=False flipY=False`; open-shell / mesh warnings: none |
| N11 | #188 | File → Export 3MF, select all in the name field, type `wrench-noext` (no extension), OK | File `$OUT/wrench-noext.3mf` exists and `$OUT/wrench-noext` does not; status `Exported 3MF → …/wrench-noext.3mf`; checker wrench 28/28 on it |
| A13 | #207 #224 | Timeline: **double-click** the base extrude (first Extrude, Distance 10). Do **not** click anything else. Read which control has focus (text selected in Distance). Type `1` then `4` (two key presses), read the field; Enter | The Distance field is focused with its text selected after the double-click. Keys `1` `4` land in the field: **no** `Front view` / `Back view` status (#224). Enter → `Preview: distance = 14.0` (and the part previews 14); the status never says `lost on rebuild`; the preview still shows the pivot hole, the open jaw and the fillets (not a plain slab) |
| A13b | carry #224 | With the field focused press **Esc**; reopen (double-click); type `14` Enter; click empty viewport | Esc: closes the panel; distance returns to 10 (`Edits cancelled`). Empty click: closes the panel and **keeps 14**; never `Editing sketch`. After either close the `Params (JSON, advanced)` row is **gone** (#224) |
| A13c | #187 | Export `wrench-t14.3mf`; run `thick … 14`; run the DIAG `wrench` | thick **7/7** incl. both `1mm … fillet at new T` rows. DIAG: prints `DIAG:` and the failures are **exactly** `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge`. Record every fillet row |
| N9 | #187 | (Same files.) Read the DIAG header triangle count and the other fillet rows | `head-shaft R10 fillet ±Y`, `R10 fillet not oversized`, `1mm fillet bottom outer edge` PASS (≈5760 tris; 2438 = fillets lost). No fifth failure |
| L7 | #200 #201 #225 | File → Save As `wrench-t14.sxp` (`Saved …`), Ctrl+S (`Saved …`). (a) Timeline pencil on the slot sketch → `Editing sketch`; press **Exit Sketch** with **no edits** → `Sketch saved`. (b) Click the body, click the `Fillet` chip, click the strip `R` field, Ctrl+A, type `1.5`, **Enter** (commits the number, releases the keys), key `3`, click the slot floor, Enter (refused), Esc. (c) File → New | (a) `Sketch saved`, nothing in the Timeline changes. (b) Ctrl+A selects the field text, not faces; `Fillet r=1.50 exceeds the 1.250 mm limit set by the 150.000 mm line edge — click it again to remove it, or reduce Radius` (**1.250**, not `0.250`, at T=14; #225), then `Edge pick cancelled`. (c) **No** `Discard unsaved changes?` dialog; `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| N8b | r17-WP4 | File → Open: single-click `blank.sxp` in the list. Open. Keep the pointer **still** on the body | The Open button is enabled after the single click (one retry allowed, rule 2); `Opened $OUT/blank.sxp` stays on the label for 2.5 s, then the hover hint appears with the pointer still (rule 46); the blank is **framed** (whole body inside the canvas, ≥ 40 % of its width), not extremely zoomed in. No Discard dialog (the New document was clean) |
| N14 | #201 #225 | Rail Sketch on the top face. Draw a Circle r `5` and one loose **Line** leaving an open end vertex. Set Cut / Blind / `2.5`; click Extrude. Then Esc, Esc. Move the pointer over the part (no click); screenshot. Then File → New | Refusal reads `Line at (x, y) breaks the chain — delete or trim it`; **no UUID anywhere** in the status; Esc 1 is the ladder (`… — Esc again exits the sketch`), Esc 2 `Sketch saved`; the host face is not left selected **and its tan hover / selection tint is gone after the pointer moves** (#225). File → New **does** show the Discard dialog (real edit made) — press OK |
| A10 | #203 | New document, Sketch on ground: Circle r `50` (Ø100), Extrude Blind `10` (Distance field is `10` after typing, not `5` or a value left by an earlier tool). Rail Sketch on the top face: Circle r `45` (Ø90), Cut / Blind, Extrude | Exact status `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; the body is unchanged. The Circle Radius field shows its own last value, not `50` carried into a new document |
| A10b | carry | File → New (Discard OK); read the finish bar | `New` / `Blind` / Extrude enabled; Distance is the default (not `5`); `New — empty part, Top plane (XY). View ▸ Timeline to edit features` |
| A14 | r17-WP2 | Rail Sketch on ground. **Polygon** (across flats), centre click; then L9 below; type `20` Enter; Circle r `5` at the centre; Extrude `7.5`; export `nut.3mf` | `Polygon AF 20.0000 — flats horizontal`; `Circle r=5.0000 (Ø10.0000)`; `Extrude Blind 7.5000 mm`; checker nut **7/7** |
| L9 | r18-WP1 | In A14, after the centre click on the origin, hover at **three bearings** (20°, 70°, 110° from the centre) at the **same distance (≥ 150 physical px)** from the centre; read the status after each (one move, one read). Then at 70° hover at ≈ 100, ≈ 150 and ≈ 200 px. Do not click: the next action is A14's typed `20` | **Spec (decided):** the pointer sits on the **circumscribed circle** of the hexagon: the six corners lie on the circle through the pointer, the flats stay horizontal, and the status reads `Polygon AF <size> — flats horizontal — click to place (or type the size)` with `<size>` = √3 × the pointer's distance from the **polygon centre** (4 decimals). A vertex is under the pointer only at 0° / 60° / 120° …; at 20° and 110° the pointer is on the circle between two corners, **by design**. AF is **independent of the bearing**: three equal-distance hovers print the same AF to ±1.5 % (walker pixel error and the centre snapping to the origin within ~20 px are the only allowed spread; sx-038's 2 % was exactly that). Along one ray AF scales with distance: ≈ 100 : 150 : 200 px → AF in ratio 1 : 1.5 : 2 ±3 %. Keep the pointer ≥ 40 px off the horizontal and vertical lines through the centre (the H / V snap pulls it onto the axis within ~2 % of the view span). A click at a hover position would commit `Polygon AF <same size> — flats horizontal` (headless asserts it). Exact equality is asserted headless (`run_rung01_replan18_polyaf`). If it freezes: record the hovered control and status, repeat once with a second move (rule 34) |
| A15 | r17-WP5 r17-WP6 r18 | Run `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd`; `… tests/run_rung01_replan16_walk.gd`; `… tests/run_rung01_replan17_walk.gd`; `… tests/run_rung01_replan18_polyaf.gd`; `make test-godot`; `make test-godot-known-red` | lint prints `<N> replan16 scripts are clean`, `<N> replan17 scripts are clean` and `<N> replan18 scripts are clean` (N ≥ 7, ≥ 8, ≥ 1); `lint_suites: <n> suites ok` with n ≥ 186 (`known-red` counted); wrench walk `0 failures` (≥ 729 checks); replan16 walk `0 failures`, `WALK-SUMMARY stages=8 first_red=none`; replan17 walk `0 failures`, `WALK-SUMMARY stages=8 first_red=none`; the polyaf suite `0 failures`; **`make test-godot` ends `suites: <n> run, 0 failed` with n ≥ 182** (on `f81c1e5` it ends `181 run, 5 failed`; the five are the plan's WP2–WP4); `make test-godot-known-red` prints each known-red suite with its `reason=` and exits 0 |

End of chunk 6: all five checkers run; record every status line and checker table in WALK_LOG.

---

### Row index (69) → origin

A1 A2 A3 A4 A5 A5b A6 A7 A7b A8 A8b A9 A9b A9c A10 A10b A11a A11b A11c A11d A11e A12 A13 A13b A13c A14 A15 A16 A17 — **29 A rows**. L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 — **12 L rows**. N1a N1b N2 N3 N4 N5 N6 N7 N8a N8b N9 N10 N11 N12 N13 N14 N15 N16 N17 N18 N19 N20 N21 — **23 N rows (sx-035 to sx-037)**. N22 window, N23 Timeline vs chip row, N24 sketch drag-box, N25 DOF chip after undo, N26 glyphs on their vertices — **5 rows (sx-038)**. 29 + 12 + 23 + 5 = 69 (28 N rows in all). The "Check" column of a row names the merged PR(s) it re-verifies; `r17-WPn` is a re-PLAN 17 work package.

## A15 — the full tier

Measured at `f81c1e5`: `suites: 181 run, 5 failed` (table above). `AGENTS.md` states the full tier is expected green and lists known-red suites via `make test-godot-known-red` (4 today, each with a `reason=`). After WP1–WP4 the A15 row requires `suites: <n> run, 0 failed`. This plan does not touch `AGENTS.md`, `run_suites.sh` or the known-red list.

## Out of scope

- Soft-GL / llvmpipe / Mesa / Godot renderer; switching Godot off 4.7-stable; screenshot lag; dropped keys; the one File-menu stall; orbit sensitivity; a click that never reaches the app (rule 51: no log line).
- Checker formulas or tolerances; the probe-count "tooling" item; the `A17` undo label (`Line` for a centerline, minor).
- Nav preset defaults (`nav_preset` `FUSION`); `docs/plan/*` features other than the STATUS entry; the snadrus fork and PR #11.
- Test-only cameras, `_look_along`, `set_view(`, writing `camera.yaw` / `camera.pitch`, `select_entity` or script-side selection in the walk or the replan16 / replan17 / replan18 suites.
