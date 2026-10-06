# Rung 1 replan 13 — leftovers after the four spin-outs: statuses, trim drift, fillet radius, dirty flag, frame, measure marks, Save As, popups, checker

Status: plan only. No product code in this change.

Baseline: `main` at `0573dea2321ffd1fd5b7e2bd3c9b5486c5e83a59` (**confirmed still the tip when this plan was written**; replan-12 WP1–WP7, #125–#133). Replan 12 is [`rung-01-replan-12.md`](rung-01-replan-12.md). The sx-033 GUI critique of that build scored **7.5–8/10** and failed rung 1. The critique is reproduced verbatim in [`rung-01-leftovers-sx033.md`](rung-01-leftovers-sx033.md). Do not re-critique sha256 `c2159210`.

Headless on `0573dea2` is green: walk **456/0**, nut 7/7, wrench 28/28, thick 6/6, blank 5/5 (inside the suites), the seven replan12 suites, kernel `7943 assertions in 333 test cases`, lint `4 replan10 + 11 replan11 + 7 replan12` clean. What the GUI found is what headless cannot see; this plan turns each leftover into a headless test that is red first.

**How this plan was measured.** Unlike replan 12 it was **not** run: the planning VM has no OCCT 8.0.1, no Godot 4.7 and no `libsxcore.so`. Every cause below was read from `0573dea2` (and, for the spin-outs, from the PR branches) and is labelled a *hypothesis*. Each WP therefore starts with a **reproduce-first gate**: write the failing test, run it on the starting ref, paste the output in the PR. If a test is green on baseline it is kept as a regression net and the PR says the leftover is soft-GL or already fixed. Red counts are recorded by the BUILD agent, never edited to match this document.

## Already spun out — not planned here (verify after merge)

Four fix agents own these. **No WP below changes their behaviour.** They appear only as verification rows in the sx-034 checklist and as walk rows in WP9.

| Spin-out | What | PR | Planned here? |
|---|---|---|---|
| bc-6000dc1d | A1: constraint chip row covers the left rail / runs off the right edge | [#134](https://github.com/solidexpress/solidexpress/pull/134) (draft, `chiprow-rail-overlap`) | covered by spin-out; verify after merge (sx-034 A1, walk row 3) |
| bc-00c1a817 | A8: Jaw per-click status, axis-aligned box preview, silent zero-width click 3 | [#135](https://github.com/solidexpress/solidexpress/pull/135) (`jaw-three-click-preview`) | covered by spin-out; verify after merge (A8, walk row 2) |
| bc-abcb9539 | A11a: Slot never arms (also: finish-bar Blind/New reset for a new sketch, `tool_arm_hint` for every tool) | [#136](https://github.com/solidexpress/solidexpress/pull/136) (draft, `a11a-slot-rail-arm`) | covered by spin-out; verify after merge (A11a, walk row 1). Leftovers 1 and 2 are **audited** by WP1 against this PR |
| bc-1e0b30a3 | A11d: a still click on the bottom face must not translate the body (`Moved body`) | opened after the plan started: [#137](https://github.com/solidexpress/solidexpress/pull/137) (draft, `sx033-click-vs-body-move`) | covered by spin-out; verify after merge (A11d bottom, walk row 4) |

After they merge, **A11e** (slot-floor R1) and **wrench 28/28 / thick 6/6 with a real slot** become reachable again. There is no separate Slot WP; if either is still unreachable after #136 the spin-out is not done.

The spin-outs touch `main.gd`, `sketch_mode.gd`, `sketch_context_chrome.gd`, `viewport_interaction.gd` (#137), `tools/lint_rung01_e2e.py` (each bumps `expected N run_rung01_replan12_*.gd`; the second to merge rebases that line) and the Makefile (#137). Every WP below names the hunks it owns and rebases on `main`.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and every first try works, **including the Slot and the bottom-face pick the spin-outs repair**. sx-033 left thirteen smaller traps; this plan removes the ones that are product bugs and **classifies the rest with evidence**, so the next critique never has to guess whether a defect is soft-GL.

**Pass bar.** Score ≥ 9. nut 7/7, blank 5/5, wrench **28/28**, thick **7/7** (6/6 fallback, see decision 13) on files exported from the GUI. Walk 0 failures. `run_rung01_wrench.gd` 0 failures. The part is made in the real GUI with no script-side shortcut and a real Slot. 3MF dimensions within 0.2 mm. Every L row of sx-034 passes or carries a recorded soft-GL classification.

Checker commands (thick gains one row, wrench is unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf          # 5/5
python3 tools/check_rung01.py nut    nut.3mf            # 7/7
python3 tools/check_rung01.py wrench wrench.3mf         # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14  # 7/7 (6/6 if decision 13 falls back)
```

Do not pass `--allow-mirror`. Exit code 0 is the pass. Godot stays `tools/godot/godot` (4.7-stable); put `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` before every Godot command and run scripts as `--script res://tests/<name>.gd` from `--path game`; the first run on a fresh checkout bakes `game/.godot` (`tools/godot/godot --headless --path game --import`). Do not commit `.gd.uid` files. The walk clicks real X11 widgets: also `export DISPLAY=:1`, and run it alone.

## BUILD agents (read before launching any)

- **Model:** grok-4.6, `effort: high`, `fast: false`.
- **starting_ref:** `main` (or the full 40-character sha of `main` at launch time; never a short sha). WP1 and WP9 start only **after** their dependencies are merged (table below).
- **Prompt:** one file per agent: `rung-01-replan-13-wpN.md`. The prompts are the implementation; this file holds the decisions, the order, the suite table and the checklist. Do not redesign what a prompt specifies.
- **Merge rule:** merge when the agent reports **FINISHED** and the quick CI checks are green: `linux/kernel`, `godot-smoke`, `website-demos`. `macos-kernel` may be skipped if it is only pending; never wait for `windows-export`. A red quick check is a product failure: reopen the WP, do not merge.
- **Branches / PRs:** one WP per PR, titles below. Repository `github.com/solidexpress/solidexpress` only (never the snadrus fork).
- **Reproduce first.** Each prompt says what the test is expected to show on baseline; the agent records the real run before changing product code.

| WP | Prompt | Leftovers |
|---|---|---|
| WP1 | [`rung-01-replan-13-wp1.md`](rung-01-replan-13-wp1.md) | 1, 2 |
| WP2 | [`rung-01-replan-13-wp2.md`](rung-01-replan-13-wp2.md) | 4 |
| WP3 | [`rung-01-replan-13-wp3.md`](rung-01-replan-13-wp3.md) | 3 |
| WP4 | [`rung-01-replan-13-wp4.md`](rung-01-replan-13-wp4.md) | 7 |
| WP5 | [`rung-01-replan-13-wp5.md`](rung-01-replan-13-wp5.md) | 5 |
| WP6 | [`rung-01-replan-13-wp6.md`](rung-01-replan-13-wp6.md) | 6, 12 |
| WP7 | [`rung-01-replan-13-wp7.md`](rung-01-replan-13-wp7.md) | 8, 11 |
| WP8 | [`rung-01-replan-13-wp8.md`](rung-01-replan-13-wp8.md) | 9, 10 |
| WP9 | [`rung-01-replan-13-wp9.md`](rung-01-replan-13-wp9.md) | 13 + the walk/lint/Makefile for all |

## Leftover → work package (all thirteen, with the verdict)

| # | Leftover (sx-033) | Verdict | WP |
|---|---|---|---|
| 1 | Stale status when arming Line / Smart Dim / Trim (any rail tool) | **Mostly covered by #136** (`tool_arm_hint` for every tool). WP1 proves it for every rail button and shortcut, and fixes any arm path whose last emit is not the tool sentence | WP1 |
| 2 | Finish bar keeps the previous sketch's Op/End/distance | **New-sketch path covered by #136** (`reset_finish_for_new_sketch`, only when `editing_fid == ""`). Residual WP1 plans: re-entering a **different** existing sketch (`begin_edit(other)`) keeps the last session's values | WP1 |
| 3 | Fillet Radius in the context bar (`StripRadius`) disagrees with the panel | **Product bug**: one-way sync, different ranges | WP3 |
| 4 | After Trim the jaw labels pile up and drift (`20.0005` / `45.0007°`; wall ≈ 45.4°) | **Product bug**: Trim re-records the *measured* width/angle instead of the typed ones, and moves the walls before recording | WP2 |
| 5 | `F` frames only the Ø20 after the 200 dim | **Product bug**: no framing hook in a sketch; `frame_contents` with no body recentres on the origin | WP5 |
| 6 | Red/orange ✕ and H after Shaft Lines; circles look squashed zoomed out | ✕ and its live labels = **product bug** (sticky measure marks planted by every tool). Blue H = expected glyph (a probe decides if one is orange/red). Squashed circles = **decided by a camera-aspect probe**: equal x/y → soft-GL, else fix in `orbit_camera.gd` | WP6 |
| 7 | Discard dialog after a refused fillet that changed nothing | **Product bug**: the failure path of `apply_graph_edit` reverts the graph but leaves `revision()` bumped | WP4 (kernel) |
| 8 | Save As: Ctrl+A dropped; typed name appends | **Product bug** (replan 12 pre-filled the name; Save As never focuses/selects it, Export 3MF does). The dropped Ctrl+A itself stays soft-GL | WP7 |
| 9 | Polygon preview stops following after an off-axis move until AF is typed | **Reproduce-first**: hover delivery while the AF blank is focused vs. soft-GL rule 12. The 30° orientation snap is by design | WP8 |
| 10 | Extrude Distance field flashes the old value after typing | **Reproduce-first** frame-by-frame spy; soft-GL if no frame shows the old text | WP8 |
| 11 | View HUD menu semi-transparent over buttons | **Product bug**: popups use the engine default stylebox; theme sets only font sizes | WP7 |
| 12 | Stuck measure overlay during jaw-sketch circle work | Same cause as the ✕ in 6 | WP6 |
| 13 | Wrench checker at T=14 still probes top fillets at z≈10 | **Decision: DIAG does not follow T.** `thick` gains one T-aware row for the jaw top fillet (the one probe DIAG cannot see); measured before it ships | WP9 |

## Decisions (nothing left open)

1. **Every armed tool names itself.** `SketchMode.set_tool` emits the tool sentence last; `tool_arm_hint` (#136) is the single table. Chip variants re-emit the sentence with the variant. `_on_status("")` keeps ignoring an empty string (the Esc suites depend on it). WP1.
2. **The finish bar belongs to a sketch.** `sketch_context_chrome` stores the owner fid. A new sketch resets to Blind/New/20 (#136); re-entering the **same** sketch (Save As) keeps the values; entering a **different** existing sketch resets. File → New still resets everything. WP1.
3. **One fillet radius.** The panel's `_radius_spin` is the value; the strip mirrors it through a signal, both share the range `0.05..100`, a focused strip field is never overwritten mid-typing, and Enter in the viewport commits the strip text first. WP3.
4. **Trim keeps what the user typed.** The jaw width and angle are captured from the live dimension records (or the measured values rounded to 1e-4 when none exist) **before** the wall surgery, and the new constraints are added with those numbers; the wall direction is re-derived from the captured angle; one record per fact. WP2.
5. **`F` in a sketch fits the sketch.** `OrbitCamera.sketch_fit` (a `Callable` installed by `SketchMode`) is called first by `frame_selection_or_all` and `frame_contents`; it is `fit_view()` (sketch extents with radii + 20% pad). Outside a sketch nothing changes. WP5.
6. **The sketch measure ✕ is an inspector for the Select tool.** `_update_sketch_measure` runs only for `Tool.SELECT`; arming any other tool, a rail geometry action, or the death of the anchored entity clears the pair. The Select-tool Esc `Measure cleared` rung stays. The constraint-glyph colours are touched only if a probe finds an orange or red glyph on valid shaft lines. WP6.
7. **A refused graph edit leaves the revision unchanged.** `Document::restore_revision` (kernel-internal) is called by `apply_graph_edit`'s failure branch after the revert. No content hash. WP4.
8. **Save As is like Export 3MF.** The filename field is focused and fully selected on open, with the same deferred re-select; typing replaces the name. Read-back of `Saved <path>` stays the rule. WP7.
9. **The polygon preview equals what the next action commits** and follows every delivered motion. One helper `_polygon_start_angle` serves preview and commit. If the probe is green on baseline, it is soft-GL and nothing changes. WP8.
10. **The Distance field never shows the old text on any frame.** If the spy sees it, `_write_extrude_spin` writes text before value and loses the racing deferred call; if not, soft-GL, no code. WP8.
11. **Popups are opaque.** `_apply_ui_theme` gives `PopupPanel/panel` and `PopupMenu/panel` an opaque `StyleBoxFlat`. The HUD shell keeps its empty style. WP7.
12. **Squashed circles are decided, not argued.** The probe in WP6 (equal projected x/y extents at 1280×800 and 1920×1080 within 0.5%) classifies it; the verdict goes in the PR and, if soft-GL, in the sx-034 rules below (rule 35).
13. **DIAG does not follow T; thick gets one jaw row.** `check_rung01.py wrench` stays the T=10 handout checker; its docstring lists the three rows that fail by design at T≠10. `thick` gains `1mm jaw top fillet at new T` (probe `(200 + (10 − 10.08)·√2/2, (10 + 10.08)·√2/2, T − 0.08)`, expected `outside`), thick **6/6 → 7/7**. It ships only if the walk's own T=14 export passes it; if it fails, thick stays 6/6 and the failure is written to `rung-01-leftovers-sx034.md` as a product bug (never loosen the probe). WP9.
14. **Lint without a hard count.** `_lint_replan13` globs `run_rung01_replan13_*.gd`, applies the replan-12 camera needles, prints `<N> replan13 scripts are clean`, asserts `N ≥ 1`. The replan12 expected count is owned by the spin-outs (whoever merges last rebases it).
15. **Out of scope per WP.** Each prompt has a "Do not" list; none changes a replan 10/11/12 status string.
16. **Reproduce first, classify honestly.** A green reproduction test is not a failure of the WP: it is the evidence that the leftover is soft-GL or already fixed, and the PR says so.
17. **Soft-GL / operator rules stay** (below): rules 1–30 of replan 10/11/12 plus 31–36.
18. **Walk.** `run_rung01_wrench.gd` gains the rows listed in WP9 (real input only), including the three honesty gaps the critique named (real rail Slot press, Jaw click-2 repeat, bottom-face click then pointer move).

## Work packages

| WP | What | Files (hunks) | Test | Depends on |
|---|---|---|---|---|
| WP1 | Tool statuses audit; finish bar owner | `sketch_mode.gd` `set_tool`/`tool_arm_hint`; `main.gd` session/tool-changed handlers; `sketch_context_chrome.gd` `reset_finish_for_new_sketch`, `show_for_session` | `run_rung01_replan13_arm.gd` | **#136 merged** (needs `tool_arm_hint`, `_sketch_rail_buttons`); rebase on #134/#135/#137 |
| WP2 | Trim keeps typed 20/45°, one label per fact | `sketch_mode.gd` `_trim_open_jaw`, `_drop_stale_dimensions`, `_record_dimension` | `run_rung01_replan13_trim.gd` | none (rebase if #135 merged) |
| WP3 | Fillet radius single source | `ops_panel.gd` radius spin/`dressup_radius`/`_apply_dressup`; `viewport_interaction.gd` strip radius hunks | `run_rung01_replan13_radius.gd` | none (rebase on #137) |
| WP4 | Refused graph edit does not dirty the document | `sxkernel/include/sx/document.hpp`, `sxcore/src/sx_document.cpp` `apply_graph_edit` | `sxkernel/tests/test_rung01_replan13_dirty.cpp` + `run_rung01_replan13_dirty.gd` | none. **The only C++ WP.** `make build`, `make test-kernel` |
| WP5 | `F` fits the sketch | `orbit_camera.gd` framing entry points; `sketch_mode.gd` session start/end (hook assignment) | `run_rung01_replan13_frame.gd` | none |
| WP6 | Sketch measure ✕ only while measuring; squash probe | `measure_overlay.gd`; `viewport_interaction.gd` `_update_sketch_measure` + sketch hover branch | `run_rung01_replan13_measure.gd` | none (rebase on #137) |
| WP7 | Save As selects the name; opaque popups | `main.gd` `_show_file_dialog`, `_apply_ui_theme`; `view_hud.gd` | `run_rung01_replan13_chrome.gd` | none |
| WP8 | Polygon preview; Distance flash | `sketch_mode.gd` `_update_preview` POLYGON arm, `hover`; `sketch_context_chrome.gd` `_write_extrude_spin` | `run_rung01_replan13_typed.gd` | none (rebase on #134/#136) |
| WP9 | Walk, lint, Makefile, thick jaw row, DIAG note | `run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile`, `tools/check_rung01.py`, `tools/test_check_rung01.py` | the walk, lint, `test_check_rung01.py`, `check_rung01.py thick` | **Everything merged:** WP1–WP8 and #134, #135, #136, #137 |

### Waves

| Wave | WPs | Why |
|---|---|---|
| 0 (running now) | #134, #135, #136, #137 | The spin-outs. Not ours; do not duplicate or wait on them for Wave A |
| A | WP2, WP3, WP4, WP5, WP6, WP7, WP8 | Disjoint hunks (see below); launch **in parallel, immediately**. No spin-out dependency (rebase when one merges first) |
| B | WP1 | Needs #136's `tool_arm_hint`, rail buttons and finish-bar reset on `main` |
| C | WP9 | The walk needs every product change and every spin-out |

Merge order inside a wave is free except: WP4 first if you want the kernel suite counts settled early; WP9 last. Expected total once all are merged: `make test-kernel` = replan-12 count + the WP4 cases.

Hunks, per file (so parallel agents do not collide; search by name, line numbers are `0573dea2`):

- `sketch_mode.gd`: WP2 owns `_trim_open_jaw` (~2558–2735) and the two dimension helpers; WP5 owns two one-line hook assignments in the session start/end path (`_enter_camera` ~471, `_leave_camera` ~517); WP8 owns the POLYGON arm of `_update_preview` (~5494) and `hover` (~4716); WP1 owns `set_tool` / `tool_arm_hint` (#136's block ~966). #135 owns the Jaw creation path and preview; #136 owns `set_tool`/the Slot preview. No shared lines among the WPs.
- `sketch_context_chrome.gd`: WP1 owns `reset_finish_for_new_sketch` and `show_for_session` (~1201); WP8 owns `_write_extrude_spin`/`_reassert_distance_line` (~650–700). #134 and #136 edit the same file elsewhere: rebase.
- `viewport_interaction.gd`: WP3 owns the strip radius widgets (~359–380) and `_sync_strip_dressup_radius` (~4684); WP6 owns the sketch hover branch (~2603–2620) and `_update_sketch_measure` (~2728). #137 owns the press/release path.
- `main.gd`: WP7 owns `_show_file_dialog` (~3120) and `_apply_ui_theme` (~911); WP1 owns `_on_sketch_session_started` (~1410) and `_on_sketch_tool_changed`. #136 and #134 edit `_build_ui` and the same session handler: rebase.
- `ops_panel.gd`: WP3 only. `orbit_camera.gd`: WP5 only. `measure_overlay.gd`: WP6 only. `view_hud.gd`: WP7 only.
- C++: WP4 touches exactly `sxkernel/include/sx/document.hpp`, `sxcore/src/sx_document.cpp` and adds `sxkernel/tests/test_rung01_replan13_dirty.cpp`. No other WP touches C++. After WP4 Godot must run against the rebuilt `libsxcore.so`.

PR titles:

- `Rung 1 replan 13 WP1: every armed tool names itself; finish bar follows its sketch`
- `Rung 1 replan 13 WP2: Power Trim keeps the typed jaw width and angle`
- `Rung 1 replan 13 WP3: fillet radius in the strip and the panel are one value`
- `Rung 1 replan 13 WP4: a refused feature edit leaves the document clean`
- `Rung 1 replan 13 WP5: F fits the sketch`
- `Rung 1 replan 13 WP6: sketch measure marks only while measuring`
- `Rung 1 replan 13 WP7: Save As selects the name; popups are opaque`
- `Rung 1 replan 13 WP8: polygon preview follows the pointer; Distance never flashes`
- `Rung 1 replan 13 WP9: walk, lint, thick jaw row and Makefile`

## Failing-first tests (red = on the starting ref, **hypotheses until a BUILD agent runs them**)

| Test | Expected red on `0573dea2` | Expected green |
|---|---|---|
| `run_rung01_replan13_arm.gd` | residual: re-entering a different sketch keeps the last Op/End/distance; the rest may already be green after #136 | all |
| `run_rung01_replan13_trim.gd` | two width labels; `20.0005` / `45.0007°`; wall ≈ 45.4° | all |
| `run_rung01_replan13_radius.gd` | strip ≠ panel after a panel edit; different minimum | all |
| `[replan13]` Catch2 (`test_rung01_replan13_dirty.cpp`) + `run_rung01_replan13_dirty.gd` | revision moved by a refused edit; `_document_is_dirty()` true; File → New prompts | all; a real edit still prompts |
| `run_rung01_replan13_frame.gd` | Ø45 extremes off screen after `F` / Frame | all |
| `run_rung01_replan13_measure.gd` | `has_anchor()` true under Circle; marks after Shaft Lines | all; squash and glyph probes record numbers |
| `run_rung01_replan13_chrome.gd` | filename not selected; typed name appends; HUD popup stylebox alpha < 1 | all |
| `run_rung01_replan13_typed.gd` | possibly the polygon follow check; the Distance spy is a probe | all; soft-GL verdicts allowed (decision 16) |
| `python3 tools/test_check_rung01.py` | new `thick_jaw_top_probe` test errors (helper absent) | pass |
| `run_rung01_wrench.gd` (WP9) | `thick checker prints 7/7` fails against the unmodified checker | 0 failures |

## Whole-suite check (every WP, and WP9 last)

Use the replan-12 table in [`rung-01-replan-12.md`](rung-01-replan-12.md) ("Whole-suite check") as the **baseline** and the critique's headless numbers for `0573dea2` (walk 456/0; replan12 fillet 19/0, labels 20/0, rail 17/0, dialog 3/0, status 9/0, panel 12/0, pick 27/0; kernel 333 cases / 7943 assertions; lint 7 replan12 clean). Run every `game/tests/run_*.gd` one at a time with `timeout 120`, nothing else running (`make test-godot` stops at the first failure; the pre-existing failures listed in `AGENTS.md` and in that table stay exactly as they are; do not flip `nav_preset`).

Deltas this plan requires (everything else identical before and after, **after** the spin-outs' own deltas):

| Suite | Change |
|---|---|
| `run_rung01_replan13_{arm,trim,radius,dirty,frame,measure,chrome,typed}` | 8 new files, 0 failures each (counts recorded by the BUILD agents) |
| `run_parse_sweep_tests` | parses every `game/tests/*.gd`: +8 files (and the spin-outs' own) |
| `run_rung01_wrench` | 456/0 → 456 + WP9 rows / 0 (plan target ≥ 490) |
| `make test-kernel` | 333 cases / 7943 assertions → +3 cases and the WP4 assertions |
| `python3 tools/lint_rung01_e2e.py` | adds `<N> replan13 scripts are clean` |
| `python3 tools/test_check_rung01.py` | `Ran 4 tests … OK` → 5 tests |
| `run_rung01_replan9_chip`, `run_rung01_replan12_*` | whatever the spin-outs changed; WPs must not change them further |

## sx-034 GUI checklist

Walk order = sx-033 with the L rows (this replan's leftovers) inserted where they happen, and the spin-out rows marked **S**. Order: A1 (S), A2, **L1**, A3, **L5**, A4, **L6**, A5, **L10**, A5b, **L8**, **L11**, A7, **L2**, A6, A7b, A8 (S), A8b, A9, **L4**, **L12**, A17, A9c, A9b, A16, A11a (S), A11b, **L3**, A11c, A11d (S, bottom face), A11e (S), A12, A13, A13b, A13c (**L13**), **L7**, A10, A10b, A14, **L9**, A15. Keep the blank open through A13c. A10 and A14 start a new document. Keep the sx-033 row ids.

| Row | Origin | Action | Pass looks like |
|---|---|---|---|
| A1 | **S #134** | New face sketch, select two circles, read the rail and the chip row | All 18 rail labels. The chip row starts right of the rail, covers neither Arc nor Point, and ends inside the right edge of the window |
| A2 | carry | Jaw, then Rect | Jaw status; then `Rect — click 1 first corner, click 2 the opposite corner`. Chips Center / Three Point, then Corner |
| L1 | WP1 | After Jaw press Line, Smart Dim, Trim, Slot, Circle, Select in turn (rail buttons, then keys `L`, `S` …) | Each press prints a sentence that starts with that tool's name and never the previous tool's. Slot's button is highlighted |
| A3 | carry | Ø20 at the origin, Ø45 right, Smart Dim the centres along +X, type 200 | `Dimension updated`. Head centre y within 0.05 of the pivot y |
| L5 | WP5 | Press `F` after the 200 dim; then the View HUD `Frame` button | **Both** circles are fully on screen, right of the rail, inside the window. Same for `Shift+F` |
| A4 | carry | Shaft Lines | `Shaft lines: 2 added` |
| L6 | WP6 | Read the canvas after Shaft Lines; zoom out three wheel notches | No red/orange ✕ and no live Δ labels remain. Blue `H`/tangent badges are expected. A red or orange H badge, or a conflict count, is a product failure. Circles: read the PR's squash verdict; if it said soft-GL, a squashed screenshot is soft-GL (rule 35) |
| A5 | carry | Extrude 10, export | blank **5/5** |
| L10 | WP8 | Type the extrude distance in the finish bar (`10` Enter, then `14` Enter), read the field right after each Enter and one frame later | The field never shows the previous value. A one-frame flash seen only in a lagging screenshot is rule 8, not a failure |
| A5b | carry | Discard Cancel, then Save As `blank.sxp` | Cancel keeps the blank. Dialog pre-filled `untitled.sxp` |
| L8 | WP7 | In that Save As dialog **do not press Ctrl+A**; type the name | The pre-filled name is selected on open; typing replaces it. Read the field back before OK; `Saved <path>` names the resolved path |
| L11 | WP7 | Open the View ▼ menu in the HUD and the menu-bar View menu | Both lists are opaque; no button shows through them |
| A7 | carry | Sketch on the top face | `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)` |
| L2 | WP1 | Set the finish bar to Cut / Up To Surface / 7 on the previous sketch, then open this **new** sketch; later re-open the first sketch from the timeline | New sketch: Blind, New, 20. A different existing sketch re-entered: also reset. Save As inside a sketch keeps its own values |
| A6 | carry | Circle tool, one click, Esc, Esc | `First point dropped — Esc again exits the sketch`, then exit. Exactly two presses (no `Measure cleared` in between) |
| A7b | carry | Sketch on the top face again | Face sketch opens |
| A8 | **S #135** | Jaw: click 1, click 2, **click 2 again**, click 3; then one click on the first glyph of the width label and the angle label; type 20 and 45 | Each click prints its own status and shows a rotated (not axis-aligned) preview; the repeated click 2 does not commit a zero-width jaw; click 3 commits `Jaw committed — width …`. Labels open on the first click |
| A8b | carry | Select a jaw line, Esc ladder | `Selection cleared — …`; sketch kept. Select tool reads `Select — click geometry, or a dimension label to edit it` |
| A9 | carry | Pivot hole at the origin next to the rail, along-jaw construction line, cross-jaw cutter, Power Trim | First click lands. `Trimmed open jaw`, then `Jaw is already open — nothing left to trim here` |
| L4 | WP2 | Read the jaw labels right after Trim | Exactly one width label `20` and one angle label `45°`, no `20.0005` / `45.0007°`, no overlapping labels. Export later: measured wall 45 ± 0.1° |
| L12 | WP6 | While the jaw sketch is open arm Circle and move over the jaw and shaft lines | No ✕ mark and no Δ labels appear or stay. Select tool + hover still shows the ✕ and Esc says `Measure cleared` |
| A17 | carry | Line/Centerline chips; Contours (blank sketch only) | Chips do not overlap. Centerline commit: `Centerline added — construction, not part of the profile` |
| A9c | carry | File → Save As while the jaw sketch is open | `Saved <path>`; sketch, finish bar and profile still there; Extrude still works |
| A9b | carry | Cut, Up To Surface, opposite face | Closed jaw cut |
| A16 | carry | View menu; keys `4`, `6`, `8`; orbit off Top | Back/Left/Bottom; the camera moves |
| A11a | **S #136** | Press the rail **Slot**; type radius 5 Enter; click two centres; read back; cut blind 2.5 | Slot highlighted; status `Slot — …`; stadium preview; `Slot c-c 150.0000 R5.0000` (Smart Dim to 150 if it differs); then the cut. The finish bar is Blind/New on this new sketch |
| A11b | carry | Fillet armed, key `3`, click each neck corner, key `4` and the +Y wall, press off the solid, Enter at R10 | `Fillet: 1 edge(s) — 10.0 mm vertical …`; wall click keeps the set; `Missed the solid — …`; `Fillet 2 edges 10.00 applied — View ▸ Timeline …` |
| L3 | WP3 | While Fillet is armed read **both** Radius fields (selection strip `R` and Modify panel Radius), type 10 in one, then 1.5 in the other | The two always show the same number (never `1.0` / `0.0` against `10`). Enter uses the number on screen |
| A11c | carry | Add one wrong edge, click it again | `— removed 179.8 mm line`. Enter still applies the two verticals |
| A11d | **S #137** | Top face R1, then key `8`, select the body, **one click on the bottom face, then move the pointer (two moves)**; R1 | Bottom R1 applies first try. The body does not move; the status never says `Moved body`. Sharp-neck refusal + one Esc → `Edge pick cancelled` |
| A11e | **S #136** | Slot-floor R1 from Top (key `3`) after the faces; refused R1.5 first is fine, end with one Esc | `Fillet <n> edges 1.00 applied …`. **Reachable now**: if it is not, #136 is incomplete |
| A12 | carry | Export `wrench.3mf` | wrench **28/28**, `flipX=False flipY=False` |
| A13 | carry | Timeline, first extrude, Distance 14, Enter | Previews 14; no `lost on rebuild` |
| A13b | carry | Esc, retype 14, click empty viewport | Esc → 10 (`Edits cancelled`); click keeps 14 |
| A13c | carry, **L13** | Export `wrench-t14.3mf`; `check_rung01.py thick … 14`; DIAG `check_rung01.py wrench …` | thick **7/7** incl. `1mm top fillet at new T` and `1mm jaw top fillet at new T` (6/6 if WP9 fell back; then the leftovers file says why). DIAG header ≈ 5760 tris; DIAG failures are exactly `bbox Z`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge` (by design at T≠10; no slot row failure now that the slot exists). Record every fillet row |
| L7 | WP4 | After A13c: Save (`Ctrl+S`), arm Fillet on the slot floor at R1.5 (refused), press Esc once, then File → New | **No** `Discard unsaved changes?` dialog. (Make any real edit, e.g. a colour, and File → New does prompt) |
| A10 | carry | Ø100 extruded, Ø90 cut on the face | Exact `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.` |
| A10b | carry | File → New, read the finish bar | New / Blind / Extrude enabled |
| A14 | carry | Polygon, centre click, type AF 20 with the pointer off the X axis; hole radius 5; extrude 7.5 | nut **7/7**; `flats horizontal` |
| L9 | WP8 | In A14, after the centre click move the pointer off-axis in three steps **before** typing | The preview radius follows each move. If it freezes, record the hovered control and the status, repeat once with a second move (rule 34); a freeze that survives is a product failure |
| A15 | WP9 | lint and `run_rung01_wrench.gd` | lint prints `<N> replan13 scripts are clean`; walk `0 failures` |

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 7/7 (6/6 only with the recorded WP9 fallback), walk 0 failures, first-try fillets from the views the app offers, a real Slot, every L row passed or classified soft-GL **with evidence**.

## Soft-GL protocol (sx-034 walker)

Rules 1–16 of replan 10, 17–22 of replan 11 and 23–30 of replan 12 still apply (read-back before commit, view keys not hidden cameras, no renderer changes, Esc ends an armed pick, never move the view to dodge the rail, first glyph of a label, read every path back). New in this replan:

31. **Save As: type the name, no Ctrl+A.** The name is selected on open (WP7). If the field is not selected, that is a product failure after one retry; if a dropped key corrupts the name, read-back catches it (rule 24).
32. **Bottom-face pick: click, then move.** Do the pointer move that sx-033 avoided (two moves; rule 12 says the first may be dropped). `Moved body` is a product failure now (#137).
33. **Real rail presses.** Press rail buttons with the pointer, not by a script emit; read the status line after each (L1).
34. **First move after a click may be dropped** (rule 12). For L9 and L10, make a second move / read one frame later before calling a product failure.
35. **Squashed circles.** If the WP6 PR classified them as soft-GL (equal projected x/y at both sizes), do not fail a row for a squashed screenshot; record "soft-GL (rule 35)". If it classified them as a product bug and fixed it, a squash is a failure.
36. **Screenshots lag one action** (rule 8). A flash that the status line and the field text read-back do not confirm is not a failure.

## Out of scope

- Soft-GL / llvmpipe / Mesa / Godot renderer; switching Godot off 4.7-stable.
- Checker formulas or tolerances other than the one thick row in decision 13 (the DIAG rows and every wrench probe stay).
- The four spin-outs' own behaviour; `docs/plan/*` and wave features; the snadrus fork; PR #11.
- The replan-10/11/12 work listed as "what stayed green" in the critique.
- A kernel blend that fillets the jaw-mouth arc while the neck is sharp (replan-11 decision 1).
- Test-only cameras, `_look_along`, `set_view(`, writing `camera.yaw` / `camera.pitch`, `select_entity` or script-side selection in walk or e2e **picks**. The eight replan13 suites are validation suites: they may place geometry and enter a sketch through helpers, but every press, key and motion under test is a real event.
