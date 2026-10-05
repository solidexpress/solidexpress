# Rung 1 replan 10 — open the jaw the way a hand does, refuse a cut that opens the shell, keep the sketch on Esc, reset the finish bar on New

Status: plan only. No product code in this change.

Baseline: `main` at `a2ff49b4` (merge of #106; replan 9 WP1–WP4 are all in). Replan 9 is [`rung-01-replan-9.md`](rung-01-replan-9.md). The sx-030 critique of that build scored **8/10** and failed rung 1 (up from 7). Leftovers: [`rung-01-leftovers-sx030.md`](rung-01-leftovers-sx030.md). The sx-030 evidence (CRITIQUE, WALK_LOG, LEFTOVERS) was read for this plan; `a2ff49b4` is not re-critiqued.

Every claim below was measured on `a2ff49b4` on a VM with Godot 4.7-stable and OCCT 8.0.1, headless, at 1280×800. (OCCT was built from the pinned `V8_0_1` tarball with `-DBUILD_MODULE_Visualization=OFF` and `rapidjson-dev` installed; the kernel does not link visualization libraries.) Every code block in the WPs was run: the five product patches (four GDScript, one C++ hunk), the four new test files, the two Esc-test edits, and the walk, lint and Makefile edits were applied together (the libraries were rebuilt with `make build`; `make test-kernel` passed); the whole `game/tests/run_*.gd` list was run before and after (99 suites before, 103 after); `run_rung01_wrench.gd` printed `404 checks, 0 failures` with the real `check_rung01.py` inside it (nut 7/7, wrench 28/28, thick 4/4). The BUILD agent copies, it does not design.

BUILD agents execute one WP each. WP1 first; WP2 after WP1 (its test trims the jaw by click); WP3 and WP4 in any order. `game/scripts/sketch_mode.gd` is edited by WP1, WP2 and WP3 in separate hunks, so rebase on `main` before opening the PR and re-run your WP's test. WP2 contains the plan's one C++ change: run `make build` before its test, and again after every rebase that touches `sxkernel/` or `sxcore/`. WP5 (walk, lint, Makefile) merges last, rebased on `main` after WP1–WP4. Godot stays `tools/godot/godot` (4.7-stable). Do not switch the pin to 4.7.1. Set `LD_LIBRARY_PATH=<occt prefix>/lib` (for example `/opt/occt-8.0.1/lib`) before every Godot command or `libsxcore.so` does not load. The first Godot run on a fresh checkout bakes `game/.godot`; run `tools/godot/godot --headless --path game --import` once first. Godot writes a `<script>.gd.uid` file next to every script it loads. Do not commit the `.uid` files for the new `run_rung01_replan10_*.gd` tests, and do not add anything else Godot generates.

How a WP is applied: each WP's product change is shipped below as a unified diff. Save it to a file and run `git apply --3way <file>` (or `git apply <file>`); the hunk line numbers are from `a2ff49b4` and `git apply` accepts the offsets after another WP has landed. Each diff was checked with `git apply --check` on a clean `a2ff49b4` and all of them were applied in sequence to give the tree the measurements come from.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and gets what the checker wants. sx-030 got through the blank, the jaw rectangle and the pivot hole, and then hit two product walls: Power Trim never opened the jaw, and a Cut Up To Surface produced an open shell with no word. This plan removes the product causes behind both and the two smaller defects the same walk exposed:

- **Power Trim opens the handout jaw** with the cutter drawn where a person draws it (anywhere up to about 20 mm from the head centre, not only within 6 mm), a second click or a drag never turns the success into `Trim failed`, and every refusal names what blocks it. (sx-030 A9, P0.)
- **The handout jaw cut no longer comes out as an open shell.** The kernel's cut boolean returns an open shell for the trimmed jaw in about half of all documents; a fuzzy value on that one boolean makes it closed every time. A Cut or Fuse that still leaves an open shell is refused by name and rolled back, and the Up To Surface face is applied when the feature is created so every guard judges the final solid. (sx-030 A9, P0.)
- **Esc never discards a sketch that holds geometry** while there is still a selection to clear or a tool to drop. (sx-030 A8, P1.)
- **File → New puts the finish bar back to New / Blind / no face.** (sx-030 A10/A14, P2.)
- The headless walk uses a cutter offset a human would draw (12 mm, not 5) and clicks Trim twice; lint and Makefile cover replan 10.
- The sx-031 walker keeps the blank open through A8–A13, runs the scratch-document rows last, and A10 gets a clean Ø100 / Ø90 re-check.

Checker commands on files the export dialog wrote (all unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf               # 5/5, run right after Extrude 10
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

Do not pass `--allow-mirror`. Exit code 0 is the pass.

**Pass bar (unchanged).** Rung 1 is done when sx-031 follows the checklist at the end of this file, the four checker commands pass on files exported from the GUI (nut 7/7, blank 5/5, wrench 28/28, thick 4/4), `run_rung01_wrench.gd` prints 0 failures, the part was made in the real GUI without `select_entity` or any other script-side shortcut, and the score is at least 9.

## What the investigation found

### F1. P0 — Power Trim on the handout jaw path always says `Trim failed` in the GUI (headless passes)

Path (sx-030 A9): hole Ø10 at the origin, Ø45 redrawn at the head as a sketch circle, Jaw Center Three Point width 20 at 45°, an along-jaw centreline, then a perpendicular offset centreline, Power Trim on the shaft side.

Five defects in `game/scripts/sketch_mode.gd`; `run_rung01_replan10_trim.gd` fails on each of them before any change:

1. **The cap circle gate only accepts a cutter within 15 % of the radius of a sketch circle.** `_trim_open_jaw` picked its cap with `_circle_meets_cutter`, which is `_point_line_distance(c, a, b) <= 0.15 · r` for sketch circles (3.4 mm for the Ø45 head). The headless walk uses a cutter 5 mm off the head centre; 5 mm misses the gate, and a leftover branch (`md <= 6.0` against the solid's head edge via `_model_circles`) happens to catch it, so headless passes. That fallback only covers a 3.4–6 mm window and only when the solid's head is under the sketch. A person draws the offset cutter wherever the picture looks right, 8–19 mm off, which no branch accepts, and the status is the bare `Trim failed`. Measured: cutter 12 mm off → `Trim failed`.
2. **A second click on an open jaw gets no answer.** With a 5 mm cutter (the old walk's offset, where the first click does work) the same walk plus a second click on `a2ff49b4` prints no status for the second click: nothing says the jaw is already open, and the profile is unchanged. A person who clicks again because soft-GL did not repaint (rule 2 of the walker protocol tells them to repeat a click that seemed to do nothing) gets silence, and the trim code runs again on entities it has already replaced.
3. **Power Trim is a drag tool and a real click carries motion.** `begin_trim_drag` trims at the press point; every `update_trim_drag` motion then calls `trim_at` for any entity under the pointer that is not in `_trim_drag_ids`. After a successful jaw trim the new floor and arc are not in that list, so the next motion event re-runs `_trim_open_jaw` on the already-open jaw. (Code reading; the test's drag case pins it: on the fixed code a press, 12 motion steps and a release give exactly one `Trimmed open jaw` and no later failure.) The headless walk's click has no motion between press and release; a human click or a short stroke does.
4. **Widening the gate makes the cap choice matter.** The old rule was "the circle whose centre is nearest the cutter line, first one wins on a tie", among circles that passed the 15 % gate. Once a cutter 12 mm off the centre is accepted (cause 1), a smaller circle concentric with the head, such as a Ø10 pivot drawn at the head centre, qualifies too and ties on distance with the Ø45; the old rule would take whichever was drawn first. The cap must be the largest circle whose disc the cutter crosses.
5. **Every failure was the same two words.** `Trim failed` named neither the entity nor the distance, so sx-030 could not tell a gate miss from a lost click. The three new sentences below name the cause.

Fix (WP1): the cap is the largest circle (sketch circles first, then the solid's head edge) whose centre is within `0.9 · r` of the cutter line (`JAW_CUTTER_MAX_RIM_FRACTION`; 20.25 mm for the Ø45, so 12 mm and 19 mm both work and 24 mm is refused by name); a jaw that is already open answers `Jaw is already open — nothing left to trim here` and changes nothing; a successful jaw trim sets `_trim_jaw_done_in_drag` so the rest of the stroke does nothing; the three failure sentences are named. The floor normalisation through the head centre (`_snap_jaw_hits_through_centre`) already makes the floor correct for any cutter offset; the walk below proves the result is still a 28/28 wrench with a 12 mm cutter.

Measured on `a2ff49b4`: `run_rung01_replan10_trim.gd` prints `38 checks, 14 failures`.

### F2. P0 — the handout jaw cut comes out as an open shell, in about half of all documents, with no refusal

sx-030 A9: the first cut Extruded with `Face z 0.0 mm` and no error; the 3MF export then failed with `3MF mesh is open (1036/2072 edges not shared twice)`. **The same sentence, with the same two numbers, is what this repo's own suite produces today**: `run_rung01_sketch_tests.gd` draws the same hole, Ø45, 20 mm jaw and centreline, trims by click, cuts, and never exports the result (its blank is 20 mm thick because that suite's own `blank bbox Z` row already fails today; the open shell does not depend on the thickness). Exporting the body inside `finish_extrude` on `a2ff49b4` (temporary print, not part of this plan) shows `ok=true` before that suite's jaw cut and `3MF mesh is open (1036/2072 edges not shared twice)` right after it. So the open shell is not a one-off of sx-030's contour; it is what the cut of the trimmed handout jaw gives.

Measurements on `a2ff49b4` (a scratch script, not part of this plan: blank, face sketch, hole Ø10, head Ø45, jaw 20 mm at 45°, perpendicular cutter at an offset from the head centre, Power Trim click, Op Cut / End Up To Surface / Opposite face / Extrude, then export the body):

- Same input, 12 fresh documents in one Godot process: **5 closed, 7 open** (`1036/2072`).
- 16 different cutter offsets (0–20 mm), one document each: 5 closed, 11 open. Whether an offset works changes from run to run (offset 0 was closed in one run and open in the next), so no offset is "safe".
- Re-adding the same cut inside one document gives the same answer, so retrying inside the app does not help (8 re-adds of the cut, same result each time). The result depends on the document, not on the call.
- The cause is the cut's boolean: the jaw's cap arc is the same Ø45 circle as the blank's head edge, so the cut tool has a cylinder face coincident with the blank's cylinder face, and OCCT's result for coincident faces is not stable. This is a kernel boolean, not the GUI.
- With `SetFuzzyValue(1e-4)` (0.1 µm) on that boolean: **40 of 40 closed** (two runs over offsets 0–20 plus repeats at 12 mm) and 12 of 12 at 12 mm; the removed volume is the same in every closed run (5132.5 mm³ from the 53128 mm³ blank). `make test-kernel` still passes (`All tests passed (7900 assertions in 330 test cases)`), and the suites that cut (`run_rung01_replan6_cut`, `run_rung01_replan8_cut`, the walk) are unchanged.

The kernel is outside the usual scope of these plans. This change is in because the leftover requires it: leftover P0 #2 says a cut must never leave an open body, and a refusal alone would make the handout wrench impossible in about half of all documents, so the pass bar could not be reached by any amount of walking. It is one hunk (the Extrude feature's Cut boolean in `FeatureGraph::apply`), no new API, no data change; Fuse and every other boolean stay as they are.

Two GDScript causes sit next to it, in `SketchMode.finish_extrude`:

- `graph_add_extrude(...)` was called **without** the Up To Surface face id. The id was written by `_finish_feature` → `_store_up_to_face`, which edits the feature's params and regenerates it afterwards. The volume guard (`_cut_refusal`) therefore judged the solid cut *without* the face, and nothing judged the regenerated solid. `graph_add_extrude` already takes the face as its 11th argument (`to_face`; `sxcore/src/sx_document.cpp`), so it can be handed over at creation.
- Nothing checked that the cut result is a closed shell. The kernel's 3MF exporter does (`mesh_edges_closed` in `sxkernel/src/interop.cpp`; its error text is `3MF mesh is open (bad/total edges not shared twice)`), so the guard re-uses that check instead of inventing a second definition of "open".

Fix (WP2): (a) kernel: fuzzy value 1e-4 on the Extrude feature's Cut boolean; (b) pass the Up To Surface face id to `graph_add_extrude` when the feature is created; (c) after the volume guard, for Cut and Fuse, probe the target body with `export_3mf_for_body` into the cache dir; if the exporter says `mesh is open`, `graph_remove` the new feature, refresh, emit a named refusal (`Cut left an open shell (326/642 edges not shared twice). Nothing was cut — …`), and keep the sketch session so the contour can be fixed. A good cut is unaffected: the probe costs one export.

(a) and (c) land together. The guard alone, on the old kernel, refuses the handout jaw about half the time (and turns `run_rung01_sketch_tests` from `70 checks, 7 failures` into `58 checks, 17 failures`, because that suite's jaw cut is an open shell today and its later rows depend on it); the kernel alone fixes the jaw but leaves other open results silent. Together, `run_rung01_sketch_tests` still prints `70 checks, 7 failures`.

An overlapping contour (in the test: the Ø45 circle plus a 60 × 13 rectangle across it and over the body's edge) is a different case: it is refused (by the 100 % volume guard or by the open-shell sentence), and OCCT's choice between the two varies from run to run, so the test asserts an invariant for it rather than one outcome.

Measured on `a2ff49b4` (original kernel, unchanged scripts): `run_rung01_replan10_cut.gd` prints `102 checks, 11 failures` or `98 checks, 12 failures` (four runs: 11, 11, 12, 12 failures; the handout-jaw rows fail because Power Trim fails (WP1) and, once it works, because the cut is an open shell). With the guard but the old kernel it prints `114 checks, 4–8 failures` (the handout jaw is refused when the old kernel returns an open shell). On the fixed tree it prints `114 checks, 0 failures` every time.

### F3. P1 — Esc while clearing a Jaw selection can discard the whole face sketch

The Esc ladder in `ViewportInteraction._sketch_input` is: measure anchor → length override → open chain → pending Smart Dim pick → pending draw point → `sketch_mode.cancel()`, which discards the sketch. A selected Jaw line is not on that ladder, so after drawing the Jaw (four lines) and clicking one line, a person pressing Esc to clear the selection discards the sketch. (Selecting a line also sets the measure anchor, so the **first** Esc says `Measure cleared`; the second reaches the discard.)

Fix (WP3): two new rungs before the discard, in a new `SketchMode.esc_keep_sketch()`: clear a non-empty selection (`Selection cleared — Esc again exits the sketch`), then drop a draw tool back to Select when the sketch holds geometry (`Tool dropped — Esc again exits the sketch`). A sketch with no geometry, and the Select tool with nothing selected, still exit at once. Two older tests (`run_rung01_replan8_esc.gd`, `run_rung01_replan9_dim.gd`) assumed the old two-press ladder and get a bounded Esc loop.

Measured on `a2ff49b4`: `run_rung01_replan10_esc.gd` prints `25 checks, 5 failures`.

### F4. P2 — Extrude Op and End persist across File → New

`main._do_new` resets the document and camera but not the finish bar, so after a Cut / Up To Surface part the next part's first sketch opens with Op = Cut, End = Up To Surface, the face box showing, and Extrude disabled (a face is required). sx-030 A10 and A14 both inherited it. Fix (WP4): new `SketchContextChrome.reset_finish_defaults()` (Op New, End Blind, thin off, flip off, face id cleared), called from `_do_new`.

Measured on `a2ff49b4`: `run_rung01_replan10_new.gd` prints `19 checks, 8 failures`.

### F5. P2 — A10 81 % refusal needs a clean walk (no code)

The refusal exists and is unchanged (`Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; `run_rung01_replan8_cut.gd`). sx-030's attempt used wrong sizes (soft-GL dropped the radius digits) and read 82 %. A10 stays in the checklist with exact sizes: the Circle field is the **radius**, so Ø100 is `50` and Ø90 is `45`. WP4 makes A10 start on a finish bar that reads New / Blind (the walker then sets Cut for the cut, as the handout does).

### F6. Environmental — soft-GL (no WP)

Unchanged conclusion from replan 8 F5 and replan 9 F4: first-character drops in dimension fields, lost first clicks, a stale viewport, an intermittent empty clipboard. No driver WP. The walker protocol below carries the rules forward.

### F7. Carry — A11, A12, A13 never ran in the GUI

They were blocked behind A9. They stay in the checklist unchanged; headless covers them (`run_rung01_wrench.gd`: wrench 28/28, thick 4/4).

## Work packages

| WP | What | Files | Test | Red on `a2ff49b4` | Green after |
|---|---|---|---|---|---|
| WP1 | Power Trim opens the jaw with an offset cutter, is idempotent, ignores the rest of a stroke, names every refusal | `game/scripts/sketch_mode.gd` | `run_rung01_replan10_trim.gd` (new) | 38 checks, 14 failures | 38 checks, 0 failures |
| WP2 | Handout jaw cut is closed every time (kernel fuzzy value on the Extrude Cut boolean); Up To Surface face at creation; open-shell probe, rollback and named refusal | `sxkernel/src/features.cpp`, `game/scripts/sketch_mode.gd` | `run_rung01_replan10_cut.gd` (new) | 98–102 checks, 11–12 failures | 114 checks, 0 failures |
| WP3 | Esc clears a selection, then drops the tool, before it discards a sketch with geometry | `game/scripts/sketch_mode.gd`, `game/scripts/viewport_interaction.gd`, `game/tests/run_rung01_replan8_esc.gd`, `game/tests/run_rung01_replan9_dim.gd` | `run_rung01_replan10_esc.gd` (new) | 25 checks, 5 failures | 25 checks, 0 failures |
| WP4 | File → New resets the finish bar | `game/scripts/sketch_context_chrome.gd`, `game/scripts/main.gd` | `run_rung01_replan10_new.gd` (new) | 19 checks, 8 failures | 19 checks, 0 failures |
| WP5 | Walk uses a 12 mm cutter and clicks Trim twice; lint and Makefile cover replan 10 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | the walk | 399 checks, 0 failures | 404 checks, 0 failures |

Order of work: WP1 first; WP2 after WP1; WP3 and WP4 in any order; each its own PR; WP5 last. Product fixes come before the walk. If any of WP1–WP4 is not merged, WP5 does not start. PR titles: `Rung 1 replan 10 WP1: Power Trim opens the jaw`, `Rung 1 replan 10 WP2: close the handout jaw cut, refuse a cut that opens the shell`, `Rung 1 replan 10 WP3: Esc keeps a sketch with geometry`, `Rung 1 replan 10 WP4: File New resets the finish bar`, `Rung 1 replan 10 WP5: walk, lint and Makefile cover replan 10`.

How each new test was measured red: the same file was run on a tree at `a2ff49b4` with `game/scripts` unchanged (`git stash push game/scripts`); the red counts above are those runs (for WP2 on the original kernel as well). The green counts are from the tree with all five patches. Each test also passes with only its own WP's patch applied on a clean `a2ff49b4` (WP2's test additionally needs WP1, because it trims the jaw by click): trim 38/0, esc 25/0 (and the two edited Esc tests 20/0 and 35/0), new 19/0, cut 114/0.

All four new tests use the `FilmUI` rules the walk uses: sketch clicks are pushed as motion + press + release with no `await` between press and release, nothing calls `select_entity`, and `tools/lint_rung01_e2e.py` (extended in WP5) is clean on them. Two are product-state tests that call internals because the thing under test cannot be reached by a click headless: `run_rung01_replan10_cut.gd` builds the blank and the sketch geometry through the sketch API, trims the handout jaw by clicking Power Trim, and sets the End dropdown with `select` + `item_selected` (the Up To Surface popup is a native popup menu; the walk clicks it for real); `run_rung01_replan10_new.gd` calls `main._on_file_menu` and `main._on_discard_confirmed` because the Discard dialog is native-sized. `run_rung01_replan10_trim.gd` builds the sketch through the sketch API (the geometry is not what is under test) and then selects Power Trim by clicking its rail button and clicks or drags on the canvas with pushed mouse events, the path a human takes.

---

### WP1 — Power Trim opens the jaw

**Files.** `game/scripts/sketch_mode.gd` (`trim_at`, new `_jaw_cap_circle`, `JAW_CUTTER_MAX_RIM_FRACTION`, `_jaw_cutter_crosses_disc`, `_jaw_no_cap_status`, `_trim_open_jaw`, `begin_trim_drag`, `update_trim_drag`, `end_trim_drag`, new `_trim_jaw_done_in_drag`), new `game/tests/run_rung01_replan10_trim.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan10_trim.gd` with exactly this content.

```gdscript
# Rung 1 replan 10 WP1 — Power Trim opens the jaw when the centreline is NOT dead-centre, when the click
# is re-sent, when the stroke drags, and names every refusal.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_trim.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
## The walk's Power Trim click: 3 mm along the jaw and 8 mm across it, on the shaft side of the cutter.
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan10 WP1 power trim")
	FilmUI.reset_fail_count()
	await test_offset_cutter_then_second_click()
	await test_drag_after_success_keeps_jaw()
	await test_cutter_too_far_is_named()
	await test_hole_at_head_still_caps_on_head()
	await test_nothing_under_pointer_is_named()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Ø10 hole at the origin (or at `hole_c`), Ø45 head at HEAD, the 20 mm wide Jaw rectangle at 45 degrees,
## and the perpendicular cutter centreline `offset` mm along the jaw from the head centre.
func _build_jaw(sm: SketchMode, offset: float, hole_c: Vector2) -> void:
	var sk = sm.sketch
	sk.add_circle(hole_c.x, hole_c.y, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p1 := HEAD + JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p2 := HEAD + JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	var p3 := HEAD - JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + JAW_DIR * offset
	var c0 := cc - JAW_ACROSS * 25.0
	var c1 := cc + JAW_ACROSS * 25.0
	sk.set_construction(sk.add_line(c0.x, c0.y, c1.x, c1.y), true)
	sm.run_solve()


func _open_trim_scene(offset: float, hole_c: Vector2) -> FilmContext:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	_build_jaw(ctx.main.sketch_mode, offset, hole_c)
	await _zoom_uv(ctx, HEAD, 120.0)
	await FilmUI.select_sketch_tool(ctx, ctx.main.sketch_mode, SketchMode.Tool.TRIM)
	check(ctx.main.sketch_mode.tool == SketchMode.Tool.TRIM, "Power Trim is the active tool")
	return ctx


func _click_at(ctx: FilmContext, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "trim click"), "trim click on screen at %s" % str(uv))
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame


func _drag_between(ctx: FilmContext, from_uv: Vector2, to_uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var a := FilmUI.model_to_screen(ctx, sm.to_model(from_uv))
	var b := FilmUI.model_to_screen(ctx, sm.to_model(to_uv))
	check(FilmUI.require_on_screen(ctx, a, "trim drag start"), "trim drag start on screen")
	check(FilmUI.require_on_screen(ctx, b, "trim drag end"), "trim drag end on screen")
	var motion := InputEventMouseMotion.new()
	motion.position = a
	motion.global_position = a
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	vp.push_input(down)
	for i in range(1, 13):
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, float(i) / 12.0)
		m.global_position = m.position
		vp.push_input(m)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
	await process_frame


func _count_status(needle: String) -> int:
	var n := 0
	for s in _status_log:
		if s.contains(needle):
			n += 1
	return n


func _status_has(needle: String) -> bool:
	return _count_status(needle) > 0


func _arc_radius_near(sm: SketchMode, centre: Vector2) -> float:
	for id in sm.sketch.entity_ids():
		if sm.sketch.is_construction(id):
			continue
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "arc" and (info["center"] as Vector2).distance_to(centre) <= 0.5:
			return float(info.get("radius", 0.0))
	return -1.0


func test_offset_cutter_then_second_click() -> void:
	print("-- cutter 12 mm along the jaw")
	var ctx := await _open_trim_scene(12.0, Vector2.ZERO)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE)
	check(_status_has("Trimmed open jaw"), "an offset cutter opens the jaw (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed"), "no Trim failed on the first click (log: %s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "the trimmed Jaw profile is closed")
	check(absf(_arc_radius_near(sm, HEAD) - 22.5) <= 0.3,
			"the head cap arc is Ø45 (radius %.2f)" % _arc_radius_near(sm, HEAD))
	var lines_after_first := sm.sketch.entity_ids().size()
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE + Vector2(-3.0, -2.0))
	check(_status_has("Jaw is already open"), "a second click says the jaw is already open (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed"), "a second click is not a failure (log: %s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "the profile is still closed after the second click")
	check(sm.sketch.entity_ids().size() == lines_after_first, "the second click changes no entity (%d vs %d)" % [
			sm.sketch.entity_ids().size(), lines_after_first])
	await _shutdown(ctx)


func test_drag_after_success_keeps_jaw() -> void:
	print("-- a stroke that crosses the cutter and keeps moving")
	var ctx := await _open_trim_scene(12.0, Vector2.ZERO)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _drag_between(ctx, SHAFT_SIDE, HEAD + Vector2(0.0, 18.0))
	check(_status_has("Trimmed open jaw"), "the drag trims the jaw (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed"), "the rest of the stroke does not report Trim failed (log: %s)" % str(_status_log))
	check(not _status_has("already open"), "the rest of the stroke does not re-trim (log: %s)" % str(_status_log))
	check(SketchMode.profile_is_closed(sm.sketch), "the profile is closed after the stroke")
	check(_count_status("Trimmed open jaw") == 1, "the jaw is trimmed exactly once (%d)" % _count_status("Trimmed open jaw"))
	await _shutdown(ctx)


func test_cutter_too_far_is_named() -> void:
	print("-- cutter 24 mm from the head centre")
	var ctx := await _open_trim_scene(24.0, Vector2.ZERO)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE)
	check(_status_has("Trim failed — the centreline is"), "the refusal names the centreline distance (log: %s)" % str(_status_log))
	check(_status_has("head centre"), "the refusal names the head centre (log: %s)" % str(_status_log))
	check(not SketchMode.profile_is_closed(sm.sketch) or _arc_radius_near(sm, HEAD) < 0.0,
			"a refused trim does not weld a cap arc")
	await _shutdown(ctx)


func test_hole_at_head_still_caps_on_head() -> void:
	print("-- a Ø10 hole at the head centre must not become the cap")
	var ctx := await _open_trim_scene(8.0, HEAD)
	var sm: SketchMode = ctx.main.sketch_mode
	_status_log.clear()
	await _click_at(ctx, SHAFT_SIDE)
	check(_status_has("Trimmed open jaw"), "the jaw opens with a Ø10 at the head centre (log: %s)" % str(_status_log))
	check(absf(_arc_radius_near(sm, HEAD) - 22.5) <= 0.3,
			"the cap is the Ø45 arc, not the Ø10 (radius %.2f)" % _arc_radius_near(sm, HEAD))
	await _shutdown(ctx)


func test_nothing_under_pointer_is_named() -> void:
	print("-- Trim on empty canvas")
	var ctx := await _open_trim_scene(12.0, Vector2.ZERO)
	_status_log.clear()
	await _zoom_uv(ctx, Vector2(100.0, 90.0), 60.0)
	await _click_at(ctx, Vector2(100.0, 90.0))
	check(_status_has("nothing under the pointer"), "empty-canvas Trim is named (log: %s)" % str(_status_log))
	check(not _status_has("Trim failed") or _status_has("Trim failed —"), "the failure is never the bare sentence")
	await _shutdown(ctx)


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
```

Run it on the unmodified tree; it must print `38 checks, 14 failures` (the red count above).

**Commit 2 — the product diff.** Save and `git apply` this.

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -61,6 +61,7 @@ var draw_construction := false
 ## Power-trim drag state: list of already-trimmed entity ids this stroke.
 var _trim_drag_ids: Array[String] = []
 var _trim_dragging := false
+var _trim_jaw_done_in_drag := false
 ## Highlight entity under trim hover (red).
 var _trim_hover_id := ""
 ## Smart-dim / convert / mirror / pattern scratch.
@@ -2093,10 +2130,10 @@ func trim_at(pos2: Vector2) -> bool:
 		return true
 	var id := _nearest_entity_at(pos2)
 	if id == "":
-		status.emit("Trim failed")
+		status.emit("Trim failed — nothing under the pointer: click on a line or arc")
 		return false
 	if not sketch.trim_entity(id, pos2.x, pos2.y):
-		status.emit("Trim failed")
+		status.emit("Trim failed — this %s has no crossing to trim at" % str(sketch.entity_info(id).get("type", "entity")))
 		return false
 	run_solve()
 	# Drop selection entries that no longer exist after a replace-style trim.
@@ -2284,6 +2321,68 @@ func _circle_meets_cutter(c: Vector2, r: float, a: Vector2, b: Vector2) -> bool:
 	return _point_segment_distance(c, a, b) <= r + 1.0
 
 
+## Largest circle whose disc the cutter line crosses well inside the rim:
+## sketch circles first, then the solid's head edge. {} when none.
+func _jaw_cap_circle(a: Vector2, b: Vector2) -> Dictionary:
+	var best: Dictionary = {}
+	var best_r := 0.0
+	for id in sketch.entity_ids():
+		if sketch.is_construction(id):
+			continue
+		var info: Dictionary = sketch.entity_info(id)
+		if str(info.get("type", "")) != "circle":
+			continue
+		var c: Vector2 = info["center"]
+		var r := float(info.get("radius", 0.0))
+		if _jaw_cutter_crosses_disc(c, r, a, b) and r > best_r:
+			best = {"id": id, "center": c, "radius": r}
+			best_r = r
+	if not best.is_empty():
+		return best
+	for mc in _model_circles():
+		var c2: Vector2 = mc["center"]
+		var r2 := float(mc["radius"])
+		if _jaw_cutter_crosses_disc(c2, r2, a, b) and r2 > best_r:
+			best = {"id": "", "center": c2, "radius": r2}
+			best_r = r2
+	return best
+
+
+const JAW_CUTTER_MAX_RIM_FRACTION := 0.9
+
+
+func _jaw_cutter_crosses_disc(c: Vector2, r: float, a: Vector2, b: Vector2) -> bool:
+	if r < 1e-6:
+		return false
+	if _point_line_distance(c, a, b) > JAW_CUTTER_MAX_RIM_FRACTION * r:
+		return false
+	return _point_segment_distance(c, a, b) <= r + 1.0
+
+
+func _jaw_no_cap_status(a: Vector2, b: Vector2) -> String:
+	var best_r := 0.0
+	var best_d := INF
+	for id in sketch.entity_ids():
+		if sketch.is_construction(id):
+			continue
+		var info: Dictionary = sketch.entity_info(id)
+		if str(info.get("type", "")) != "circle":
+			continue
+		var r := float(info.get("radius", 0.0))
+		if r > best_r:
+			best_r = r
+			best_d = _point_line_distance(info["center"], a, b)
+	for mc in _model_circles():
+		var r2 := float(mc["radius"])
+		if r2 > best_r:
+			best_r = r2
+			best_d = _point_line_distance(mc["center"], a, b)
+	if best_r < 1e-6:
+		return "Trim failed — no head circle: redraw the Ø45 head circle on this sketch"
+	return "Trim failed — the centreline is %.1f mm from the Ø%.0f head centre (limit %.1f mm): draw it closer to the head centre" % [
+			best_d, best_r * 2.0, JAW_CUTTER_MAX_RIM_FRACTION * best_r]
+
+
 ## Click on one side of a construction centreline: drop that half, keep the
 ## other, close it with a floor on the cutter and the keep-side arc of the
 ## circle centred on the cutter. The Ø10 (centre far from the cutter) stays.
@@ -2291,6 +2390,9 @@ func _trim_open_jaw(pos2: Vector2) -> bool:
 	var cutter := _nearest_construction_line(pos2, 40.0)
 	if cutter.is_empty():
 		return false
+	if _jaw_ids_alive():
+		status.emit("Jaw is already open — nothing left to trim here")
+		return true
 	var a: Vector2 = cutter["a"]
 	var b: Vector2 = cutter["b"]
 	var dir := b - a
@@ -2309,42 +2411,13 @@ func _trim_open_jaw(pos2: Vector2) -> bool:
 	if long_dir.length_squared() > 1e-8 and _dirs_within_deg(dir, long_dir, CAP_DEG):
 		status.emit("Trim failed — draw the centreline across the jaw")
 		return true
-	var cc := Vector2.ZERO
-	var cr := 0.0
-	var circ_id := ""
-	var best_cd := INF
-	for id in sketch.entity_ids():
-		if sketch.is_construction(id):
-			continue
-		var info: Dictionary = sketch.entity_info(id)
-		if str(info.get("type", "")) != "circle":
-			continue
-		var c: Vector2 = info["center"]
-		var r := float(info.get("radius", 0.0))
-		if not _circle_meets_cutter(c, r, a, b):
-			continue
-		var d := _point_line_distance(c, a, b)
-		if d < best_cd:
-			best_cd = d
-			circ_id = id
-			cc = c
-			cr = r
-	if circ_id == "":
-		for mc in _model_circles():
-			var c2: Vector2 = mc["center"]
-			var r2 := float(mc["radius"])
-			# A ~5 mm offset cutter misses the 15% sketch-circle gate
-			# (0.15 × 22.5 = 3.375). The solid's head edge is still the cap.
-			var md := _point_line_distance(c2, a, b)
-			if _circle_meets_cutter(c2, r2, a, b) or (
-					md <= 6.0
-					and _point_segment_distance(c2, a, b) < a.distance_to(b) + 5.0):
-				cc = c2
-				cr = r2
-				break
-	if cr < 1e-6:
-		status.emit("Trim failed")
+	var cap := _jaw_cap_circle(a, b)
+	if cap.is_empty():
+		status.emit(_jaw_no_cap_status(a, b))
 		return true
+	var cc: Vector2 = cap["center"]
+	var cr: float = float(cap["radius"])
+	var circ_id: String = str(cap["id"])
 	var to_delete: Array[String] = []
 	var walls: Array = []
 	for id in sketch.entity_ids():
@@ -2474,6 +2547,7 @@ func _trim_open_jaw(pos2: Vector2) -> bool:
 	_weld_jaw_profile(floor_id, walls, arc_id)
 	_redraw()
 	_redraw_selected()
+	_trim_jaw_done_in_drag = true
 	status.emit("Trimmed open jaw")
 	return true
 
@@ -4395,6 +4485,7 @@ func hover(pos2: Vector2) -> void:
 ## Power-trim drag: trim every entity the cursor crosses.
 func begin_trim_drag(pos2: Vector2) -> void:
 	_trim_dragging = true
+	_trim_jaw_done_in_drag = false
 	_trim_drag_ids.clear()
 	trim_at(pos2)
 	var id := _nearest_entity_at(pos2)
@@ -4403,7 +4494,7 @@ func begin_trim_drag(pos2: Vector2) -> void:
 
 
 func update_trim_drag(pos2: Vector2) -> void:
-	if not _trim_dragging:
+	if not _trim_dragging or _trim_jaw_done_in_drag:
 		return
 	var id := _nearest_entity_at(pos2)
 	if id != "" and id not in _trim_drag_ids:
@@ -4415,6 +4506,7 @@ func update_trim_drag(pos2: Vector2) -> void:
 
 func end_trim_drag() -> void:
 	_trim_dragging = false
+	_trim_jaw_done_in_drag = false
 	_trim_drag_ids.clear()
 	_trim_hover_id = ""
 
```

What the diff does, in the order of the code:

1. `_jaw_cap_circle(a, b)` returns `{id, center, radius}` for the largest circle whose disc the cutter crosses within `0.9 · r` of its centre (`_jaw_cutter_crosses_disc`): sketch circles first (the redrawn Ø45), then `_model_circles()` (the solid's head edge), `{}` when none. `r > best_r` keeps the largest, which is what makes a Ø10 at the head centre lose to the Ø45.
2. `_jaw_no_cap_status(a, b)` builds the refusal text: `no head circle` when the sketch and the solid have no circle at all, otherwise the distance from the largest circle's centre to the cutter and the limit (`0.9 · r`).
3. `_trim_open_jaw` returns early with `Jaw is already open — nothing left to trim here` when `_jaw_ids_alive()` (the stored floor, arc and two walls still exist); the 2° near-parallel refusal `Trim failed — draw the centreline across the jaw` is unchanged; the old cap search (the 15 % gate and the `md <= 6.0` fallback) is replaced by `_jaw_cap_circle`; on success `_trim_jaw_done_in_drag = true` just before `Trimmed open jaw`.
4. `begin_trim_drag` clears `_trim_jaw_done_in_drag` before its first `trim_at`; `update_trim_drag` returns at once when it is set; `end_trim_drag` clears it. Ordinary Power Trim of non-jaw geometry is unchanged (the flag is only set by the jaw path).
5. `trim_at`'s two bare `Trim failed` become `Trim failed — nothing under the pointer: click on a line or arc` and `Trim failed — this <line|arc|circle…> has no crossing to trim at`.

Run the test again. Expected last line: `38 checks, 0 failures`. Also run `run_rung01_replan5_trim.gd`, `run_rung01_replan4_*`, `run_sketch_tools_tests` and compare with the whole-suite table (they must not change).

**GUI checklist item.** A9 (rewritten below): the handout Trim path gives `Trimmed open jaw`, a second click gives `Jaw is already open`, never `Trim failed`.

---

### WP2 — The handout jaw cut is closed; a cut that opens the shell is refused

Prerequisite: WP1 merged. **Files.** `sxkernel/src/features.cpp` (the Extrude feature's Cut boolean in `FeatureGraph::apply`), `game/scripts/sketch_mode.gd` (`finish_extrude`, new `_open_shell_reason`, new `_open_shell_refusal`), new `game/tests/run_rung01_replan10_cut.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan10_cut.gd` with exactly this content.

```gdscript
# Rung 1 replan 10 WP2 — Cut Up To Surface never leaves an open shell, and never leaves one without a refusal.
# Part 1: the trimmed handout jaw (hole, Ø45 head, 20 mm jaw at 45 degrees, cutter 12 mm off the head centre,
#   Power Trim by click) must cut cleanly every time. The OCCT boolean used to return an open shell for it in
#   about half of all documents (the result depends on the document's random ids), so it runs 4 times.
# Part 2: an overlapping contour is allowed to be refused, but each attempt asserts the invariant:
#   accepted -> the body exports as a closed 3MF; refused -> named, volume and feature count unchanged.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_cut.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)
const JAW_DIR := Vector2(0.70710678, 0.70710678)
const JAW_ACROSS := Vector2(-0.70710678, 0.70710678)
const CUTTER_OFFSET := 12.0
## 9 mm on the shaft side of the cutter, 8 mm off the jaw axis: where the walk's Power Trim click lands.
const SHAFT_SIDE := Vector2(200.0, 0.0) + Vector2(0.70710678, 0.70710678) * 3.0 + Vector2(-0.70710678, 0.70710678) * 8.0
const HANDOUT_ATTEMPTS := 4
const ATTEMPTS := 6

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan10 WP2 cut guard")
	FilmUI.reset_fail_count()
	for i in range(HANDOUT_ATTEMPTS):
		var h := await run_cut("handout jaw attempt %d" % (i + 1), "handout")
		check(h["accepted"], "handout jaw attempt %d: the trimmed jaw cut is accepted (log: %s)" % [i + 1, str(h["log"])])
		check(h["export_ok"], "handout jaw attempt %d: the cut body exports as a closed 3MF (%s)" % [i + 1, h["export_msg"]])
		check(h["vol_after"] < h["vol_before"] - 4000.0 and h["vol_after"] > h["vol_before"] - 6000.0,
				"handout jaw attempt %d: the jaw removed about 5100 mm³ (%.1f -> %.1f)" % [i + 1, h["vol_before"], h["vol_after"]])
	var accepted := 0
	var refused := 0
	for i in range(ATTEMPTS):
		var r := await run_cut("jaw contour attempt %d" % (i + 1), "jaw")
		if r["accepted"]:
			accepted += 1
		else:
			refused += 1
	print("jaw contour: %d accepted, %d refused" % [accepted, refused])
	var good := await run_cut("small hole through the shaft", "hole")
	check(good["accepted"], "a clean Ø8 hole cut Up To Surface is accepted (log: %s)" % str(good["log"]))
	check(good["export_ok"], "the holed body exports as a closed 3MF (%s)" % good["export_msg"])
	check(good["vol_after"] < good["vol_before"] - 300.0 and good["vol_after"] > good["vol_before"] - 700.0,
			"the hole removed about 500 mm³ (%.1f -> %.1f)" % [good["vol_before"], good["vol_after"]])
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _extrude_count(doc) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _face_at(doc, body: String, z: float) -> String:
	for f in doc.get_face_ids(body):
		var m: Vector3 = doc.face_midpoint(f)
		var bb: Dictionary = doc.measure_bbox(f)
		var ext: Vector3 = bb["max"] - bb["min"]
		if absf(m.z - z) < 0.01 and ext.z < 0.01 and ext.x * ext.y > 100.0:
			return f
	return ""


func _log_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


## Returns {accepted, export_ok, export_msg, vol_before, vol_after, log}.
func run_cut(label: String, kind: String) -> Dictionary:
	print("-- " + label)
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var sk = sm.sketch
	sk.add_circle(0.0, 0.0, 10.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var tangent_x := HEAD.x - sqrt(22.5 * 22.5 - 100.0)
	sk.add_line(0.0, 10.0, tangent_x, 10.0)
	sk.add_line(0.0, -10.0, tangent_x, -10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	var doc = ctx.view.doc
	check(not doc.body_ids().is_empty(), "the blank was extruded")
	var body: String = doc.body_ids()[0]
	var top := _face_at(doc, body, 10.0)
	var bottom := _face_at(doc, body, 0.0)
	check(top != "" and bottom != "", "the blank has a top and a bottom face")
	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	sk = sm.sketch
	check(sm.active, "the face sketch is active")
	if kind == "handout":
		await _build_and_trim_handout_jaw(ctx)
	elif kind == "jaw":
		sk.add_circle(HEAD.x, HEAD.y, 22.5)
		sk.add_line(177.0, -0.5, 237.0, -0.5)
		sk.add_line(237.0, -0.5, 237.0, 12.5)
		sk.add_line(237.0, 12.5, 177.0, 12.5)
		sk.add_line(177.0, 12.5, 177.0, -0.5)
	else:
		sk.add_circle(100.0, 0.0, 4.0)
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if kind == "handout":
		check(SketchMode.profile_is_closed(sm.sketch), "the handout jaw profile is closed after the trim")
	var op: OptionButton = chrome.find_child("FinishOp", true, false) as OptionButton
	var end: OptionButton = chrome.find_child("FinishEnd", true, false) as OptionButton
	op.select(1)
	end.select(3)
	end.item_selected.emit(3)
	await process_frame
	await _x11_click(chrome.opposite_face_button())
	await process_frame
	await process_frame
	check(str(chrome.up_to_face_id) == bottom, "Opposite face stored the bottom face")
	var vol_before := float(doc.measure_mass(body)["volume"])
	var exts_before := _extrude_count(doc)
	_status_log.clear()
	await _x11_click(chrome.extrude_button())
	await process_frame
	await process_frame
	await process_frame
	var out := {"accepted": false, "export_ok": false, "export_msg": "n/a", "vol_before": vol_before,
			"vol_after": -1.0, "log": _status_log.duplicate()}
	var bodies: PackedStringArray = doc.body_ids()
	if not bodies.is_empty():
		out["vol_after"] = float(doc.measure_mass(bodies[0])["volume"])
		var path := OS.get_cache_dir().path_join("sx-replan10-cut-%s.3mf" % kind)
		var ok: bool = doc.export_3mf_for_body(bodies[0], path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		out["export_ok"] = ok
		out["export_msg"] = "closed" if ok else str(doc.last_export_error())
	out["accepted"] = _extrude_count(doc) > exts_before
	if kind == "handout":
		pass
	elif out["accepted"]:
		check(out["export_ok"], "%s: an accepted cut leaves a closed mesh (%s)" % [label, out["export_msg"]])
	else:
		check(_log_has("Nothing was") or _log_has("Cut removed"), "%s: a refused cut is named (log: %s)" % [label, str(out["log"])])
		check(absf(float(out["vol_after"]) - vol_before) < 0.5, "%s: a refused cut keeps the volume (%.1f vs %.1f)" % [
				label, float(out["vol_after"]), vol_before])
		check(_extrude_count(doc) == exts_before, "%s: a refused cut adds no extrude feature" % label)
		check(sm.active, "%s: a refused cut keeps the sketch open" % label)
		check(out["export_ok"], "%s: the body is still a closed mesh after a refusal (%s)" % [label, out["export_msg"]])
	await _shutdown(ctx)
	return out


func _build_and_trim_handout_jaw(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var sk = sm.sketch
	sk.add_circle(0.0, 0.0, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p1 := HEAD + JAW_DIR * 30.0 - JAW_ACROSS * 10.0
	var p2 := HEAD + JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	var p3 := HEAD - JAW_DIR * 30.0 + JAW_ACROSS * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + JAW_DIR * CUTTER_OFFSET
	var c0 := cc - JAW_ACROSS * 25.0
	var c1 := cc + JAW_ACROSS * 25.0
	sk.set_construction(sk.add_line(c0.x, c0.y, c1.x, c1.y), true)
	sm.run_solve()
	await _zoom(ctx, sm.to_model(HEAD), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.TRIM)
	_status_log.clear()
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(SHAFT_SIDE))
	check(FilmUI.require_on_screen(ctx, screen, "trim click"), "the Power Trim click is on screen")
	await _x11_click_screen(ctx.main.get_viewport(), screen)
	await process_frame
	check(_log_has("Trimmed open jaw"), "Power Trim opened the jaw (log: %s)" % str(_status_log))
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
```

Run it on the unmodified tree (with WP1 applied): the handout-jaw rows fail on every run in which the document's boolean comes out open (about half of all documents; four attempts per run make it all but certain) and the overlapping-contour rows fail for every accepted-open attempt. Reference runs on `a2ff49b4` without WP1: `98 checks, 12 failures`, `102 checks, 11 failures`. Reference runs with the guard and the old kernel: `114 checks, 4 failures` to `114 checks, 8 failures`.

**Commit 2 — the kernel diff.** Save and `git apply` this, then run `make build`.

```diff
diff --git a/sxkernel/src/features.cpp b/sxkernel/src/features.cpp
--- a/sxkernel/src/features.cpp
+++ b/sxkernel/src/features.cpp
@@ -8,6 +8,7 @@
 #include <gp_Pln.hxx>
 #include <BRepAlgoAPI_Common.hxx>
 #include <BRepAlgoAPI_Cut.hxx>
+#include <TopTools_ListOfShape.hxx>
 #include <BRepAlgoAPI_Defeaturing.hxx>
 #include <BRepAlgoAPI_Fuse.hxx>
 #include <BRepBndLib.hxx>
@@ -1128,9 +1129,21 @@ bool FeatureGraph::apply(Document& doc, Feature& f,
                     EntityId target = find_feature_body("target");
                     const Body* tb = doc.body(target);
                     if (!tb) return fail("missing target body");
-                    TopoDS_Shape merged = (op == "cut")
-                                              ? TopoDS_Shape(BRepAlgoAPI_Cut(tb->shape, result).Shape())
-                                              : TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, result).Shape());
+                    TopoDS_Shape merged;
+                    if (op == "cut") {
+                        BRepAlgoAPI_Cut cutter_op;
+                        TopTools_ListOfShape args;
+                        TopTools_ListOfShape tools;
+                        args.Append(tb->shape);
+                        tools.Append(result);
+                        cutter_op.SetArguments(args);
+                        cutter_op.SetTools(tools);
+                        cutter_op.SetFuzzyValue(1e-4);
+                        cutter_op.Build();
+                        merged = cutter_op.Shape();
+                    } else {
+                        merged = TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, result).Shape());
+                    }
                     if (merged.IsNull()) return fail("boolean failed");
                     doc.replace_body_shape(target, merged);
                 }
```

`BRepAlgoAPI_Cut` is given its argument and tool lists explicitly so `SetFuzzyValue(1e-4)` can be called before `Build()`; the plain constructor has no way to set it. Fuse is untouched. `1e-4` is in the model's millimetres (0.1 µm); the removed volume of the handout jaw is identical to the digit with and without it. Run `make test-kernel`: `All tests passed (7900 assertions in 330 test cases)`, unchanged.

**Commit 3 — the GDScript guard.**

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -597,9 +598,10 @@ func finish_extrude(distance: float, op: String = "new", end: String = "blind",
 	if sk_fid == "":
 		return
 	var vol_before := _body_volume(view.body_of_feature(target_fid)) if op == "cut" else -1.0
+	var to_face_id := _up_to_face_id() if end == "to_face" else ""
 	var ex_fid: String = view.doc.graph_add_extrude(
 		sk_fid, distance, symmetric, op, target_fid if op != "new" else "", end,
-		thin_thickness, thin_type, flip_side, selected_contours)
+		thin_thickness, thin_type, flip_side, selected_contours, to_face_id)
 	if ex_fid == "" and _graph_error_text().contains("Thin wall"):
 		status.emit(_graph_error_text())
 		_reassert_camera()
@@ -613,6 +615,14 @@ func finish_extrude(distance: float, op: String = "new", end: String = "blind",
 			status.emit(refuse)
 			_reassert_camera()
 			return
+	if ex_fid != "" and op != "new":
+		var open_reason := _open_shell_reason(view.body_of_feature(target_fid))
+		if open_reason != "":
+			view.doc.graph_remove(ex_fid)
+			view.refresh()
+			status.emit(_open_shell_refusal(op, open_reason))
+			_reassert_camera()
+			return
 	var fail_msg := "Extrude failed — is the profile closed?"
 	_finish_feature(sk_fid, ex_fid, op, fail_msg)
 
@@ -627,6 +637,33 @@ func _body_volume(body_id: String) -> float:
 	return float(view.doc.measure_mass(body_id).get("volume", -1.0))
 
 
+## "" when the body exports as a closed mesh, else the kernel's own
+## "3MF mesh is open (bad/total edges not shared twice)" sentence. Uses the
+## exporter's check so the refusal and a later File > Export agree.
+func _open_shell_reason(body_id: String) -> String:
+	if body_id == "" or view == null or view.doc == null:
+		return ""
+	if not view.doc.has_method("export_3mf_for_body"):
+		return ""
+	var dir := OS.get_cache_dir()
+	DirAccess.make_dir_recursive_absolute(dir)
+	var path := dir.path_join("sx-open-shell-probe.3mf")
+	var ok: bool = view.doc.export_3mf_for_body(body_id, path)
+	if FileAccess.file_exists(path):
+		DirAccess.remove_absolute(path)
+	if ok:
+		return ""
+	var err := str(view.doc.last_export_error())
+	return err if err.contains("mesh is open") else ""
+
+
+func _open_shell_refusal(op: String, reason: String) -> String:
+	var counts := reason.substr(reason.find("(")) if reason.contains("(") else ""
+	var verb := "cut" if op == "cut" else "fused"
+	return "%s left an open shell %s. Nothing was %s — the contour overlaps or sits on the body's own edge. Fix the contour and try again." % [
+			"Cut" if op == "cut" else "Fuse", counts, verb]
+
+
 ## Named refusal for a cut that boolean-succeeded but wrecked the body.
 ## Empty string = accept.
 func _cut_refusal(before: float, after: float) -> String:
```

What the diff does:

1. `finish_extrude` reads the Up To Surface id once (`_up_to_face_id()`, only when `end == "to_face"`) and passes it as the new last argument of `graph_add_extrude`. `_store_up_to_face` still runs in `_finish_feature` and finds the id already stored; it stays as is.
2. After the existing `_cut_refusal` volume guard, for any `op != "new"`: `_open_shell_reason(body)` exports the target body to `OS.get_cache_dir()/sx-open-shell-probe.3mf` (a real path, not `user://`), deletes the file, and returns the exporter's own sentence only if it contains `mesh is open`; any other export error is not a reason to refuse.
3. If there is a reason: `view.doc.graph_remove(ex_fid)`, `view.refresh()`, emit the named refusal, `_reassert_camera()`, return. The sketch session stays active, as with the volume refusals.

Run the test again. Expected: `114 checks, 0 failures`. The line `jaw contour: 0 accepted, 6 refused` is typical; if an overlapping-contour attempt is accepted it must be a closed mesh (the check count then drops by 4 per accepted attempt). Also run `run_rung01_sketch_tests.gd` (`70 checks, 7 failures`, unchanged), `run_rung01_replan8_cut.gd` and `run_rung01_replan6_cut.gd` (unchanged counts) and `run_rung01_wrench.gd` (399/0 before WP5).

**GUI checklist item.** A9b: Op Cut, End Up To Surface, Opposite face, Extrude on the trimmed handout jaw is accepted and the body exports as the wrench. A refusal on this path is a product failure; any other refusal is named and the body and sketch are untouched.

---

### WP3 — Esc keeps a sketch that has geometry

**Files.** `game/scripts/sketch_mode.gd` (new `esc_keep_sketch`), `game/scripts/viewport_interaction.gd` (the Esc else-branch in `_sketch_input`), `game/tests/run_rung01_replan8_esc.gd` and `game/tests/run_rung01_replan9_dim.gd` (final Esc becomes a bounded loop), new `game/tests/run_rung01_replan10_esc.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan10_esc.gd` with exactly this content.

```gdscript
# Rung 1 replan 10 WP3 — Esc clears a selection, then drops the tool, before it ever discards a sketch that has geometry.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_esc.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan10 WP3 Esc keeps a sketch that has geometry")
	FilmUI.reset_fail_count()
	await test_jaw_esc_ladder()
	await test_empty_sketch_esc_exits()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _profile_lines(sm: SketchMode) -> int:
	var n := 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			n += 1
	return n


func test_jaw_esc_ladder() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point", "Jaw is the active tool")
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(30.0, 0.0))
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	check(_profile_lines(sm) == 4, "the Jaw rectangle has four lines (got %d)" % _profile_lines(sm))

	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	check(sm.selected.size() == 1, "one Jaw line is selected (got %d)" % sm.selected.size())

	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "the first Esc after selecting a Jaw line keeps the sketch open")
	check(_status_has("Measure cleared"), "the first Esc clears the measure pair (log: %s)" % str(_status_log))
	check(_profile_lines(sm) == 4, "the Jaw lines are all still there (got %d)" % _profile_lines(sm))

	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "the second Esc keeps the sketch open")
	check(sm.selected.is_empty(), "the second Esc clears the selection")
	check(_profile_lines(sm) == 4, "the Jaw lines survive the selection clear (got %d)" % _profile_lines(sm))
	check(_status_has("Selection cleared — Esc again exits the sketch"),
			"Esc names what it dropped (log: %s)" % str(_status_log))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT, "Jaw is the active tool again")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "Esc with the Jaw tool active and geometry drawn keeps the sketch open")
	check(sm.tool == SketchMode.Tool.SELECT, "Esc drops the Jaw tool back to Select")
	check(_profile_lines(sm) == 4, "the Jaw lines survive the tool drop (got %d)" % _profile_lines(sm))
	check(_status_has("Tool dropped — Esc again exits the sketch"),
			"the tool drop is named (log: %s)" % str(_status_log))

	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc with nothing selected and the Select tool still exits the sketch")
	await _shutdown(ctx)


func test_empty_sketch_esc_exits() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	check(sm.sketch.entity_ids().is_empty(), "the sketch is empty")
	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc in an empty sketch with a tool active exits at once")
	await _shutdown(ctx)

func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame
```

Run it on the unmodified tree: `25 checks, 5 failures`.

**Commit 2 — the product diff.**

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -3341,6 +3415,22 @@ func has_pending_dim_pick() -> bool:
 	return tool == Tool.SMART_DIM and not _smart_dim_pending.is_empty()
 
 
+## Esc rungs between "drop a pending point" and "discard the sketch": clear a
+## selection, then drop a draw tool back to Select once the sketch holds
+## geometry. Returns the status to show, or "" when nothing is left to drop
+## and Esc should discard the sketch.
+func esc_keep_sketch() -> String:
+	if not active or sketch == null:
+		return ""
+	if not selected.is_empty():
+		_set_selected([])
+		return "Selection cleared — Esc again exits the sketch"
+	if tool != Tool.SELECT and tool != Tool.NONE and not sketch.entity_ids().is_empty():
+		set_tool(Tool.SELECT)
+		return "Tool dropped — Esc again exits the sketch"
+	return ""
+
+
 ## Esc with a first Smart Dim pick: drop the pick and keep the sketch session.
 func cancel_pending_dim_pick() -> void:
 	_smart_dim_pending.clear()
diff --git a/game/scripts/viewport_interaction.gd b/game/scripts/viewport_interaction.gd
--- a/game/scripts/viewport_interaction.gd
+++ b/game/scripts/viewport_interaction.gd
@@ -2662,7 +2662,11 @@ func _sketch_input(event: InputEvent) -> void:
 					sketch_mode.cancel_pending_draw()
 					status.emit("First point dropped — Esc again exits the sketch")
 				else:
-					sketch_mode.cancel()
+					var kept := sketch_mode.esc_keep_sketch()
+					if kept != "":
+						status.emit(kept)
+					else:
+						sketch_mode.cancel()
 		accept_event()
 
 
```

`esc_keep_sketch()` returns the status to show, or `""` when nothing is left to drop and Esc should discard. In `_sketch_input` it sits last on the ladder, so every earlier rung (measure anchor, length override, open chain, pending Smart Dim pick, pending draw point) still wins first. Order a person sees after drawing the Jaw and clicking one line: Esc → `Measure cleared`; Esc → `Selection cleared — Esc again exits the sketch`; Esc → (with a draw tool active) `Tool dropped — Esc again exits the sketch`; Esc → the sketch exits.

**Commit 3 — the two older tests.** Both end with "Esc with nothing pending still exits the sketch". With the new rungs a single Esc is no longer enough, so each final Esc becomes a bounded loop.

`game/tests/run_rung01_replan8_esc.gd`:

```diff
diff --git a/game/tests/run_rung01_replan8_esc.gd b/game/tests/run_rung01_replan8_esc.gd
--- a/game/tests/run_rung01_replan8_esc.gd
+++ b/game/tests/run_rung01_replan8_esc.gd
@@ -57,8 +57,11 @@ func test_esc_ladder() -> void:
 		if str(info.get("type", "")) == "circle":
 			r = float(info.get("radius", 0.0))
 	check(absf(r - 10.0) < 0.6, "after the dropped point a fresh two-click circle has r~10 (got %.2f)" % r)
-	await _x11_key(vp, KEY_ESCAPE)
-	check(not sm.active, "Esc with nothing pending still exits the sketch")
+	for _i in 3:
+		if not sm.active:
+			break
+		await _x11_key(vp, KEY_ESCAPE)
+	check(not sm.active, "Esc with nothing pending still exits the sketch (after the selection and tool rungs)")
 	await _shutdown(ctx)
 
 
```

`game/tests/run_rung01_replan9_dim.gd`:

```diff
diff --git a/game/tests/run_rung01_replan9_dim.gd b/game/tests/run_rung01_replan9_dim.gd
--- a/game/tests/run_rung01_replan9_dim.gd
+++ b/game/tests/run_rung01_replan9_dim.gd
@@ -108,8 +108,11 @@ func test_esc_drops_pick() -> void:
 	check(sm.selected.is_empty(), "Esc clears the first-pick selection")
 	check(_status_has("Smart Dim pick dropped"), "Esc says the pick was dropped (log: %s)" % str(_status_log))
 	check(sm.sketch.entity_ids().size() == 2, "both circles are still in the sketch")
-	await _x11_key(vp, KEY_ESCAPE)
-	check(not sm.active, "Esc with nothing pending still exits the sketch")
+	for _i in 3:
+		if not sm.active:
+			break
+		await _x11_key(vp, KEY_ESCAPE)
+	check(not sm.active, "Esc with nothing pending still exits the sketch (after the selection and tool rungs)")
 	await _shutdown(ctx)
 
 
```

Expected after WP3: `run_rung01_replan10_esc` `25 checks, 0 failures`; `run_rung01_replan8_esc` `20 checks, 0 failures`; `run_rung01_replan9_dim` `35 checks, 0 failures`. Without commit 3 those two fail on exactly their last check.

**GUI checklist item.** A8b: Esc, Esc, Esc after selecting a Jaw line keeps the four lines until the last press.

---

### WP4 — File → New resets the finish bar

**Files.** `game/scripts/sketch_context_chrome.gd` (new `reset_finish_defaults`), `game/scripts/main.gd` (`_do_new`), new `game/tests/run_rung01_replan10_new.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan10_new.gd` with exactly this content.

```gdscript
# Rung 1 replan 10 WP4 — File > New puts the finish bar back to New / Blind / no Up To Surface face.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan10_new.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan10 WP4 File > New resets the finish bar")
	FilmUI.reset_fail_count()
	await test_new_resets_finish_bar()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_new_resets_finish_bar() -> void:
	var ctx := await _boot()
	var main = ctx.main
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	var chrome: SketchContextChrome = main.sketch_chrome
	var op := chrome.find_child("FinishOp", true, false) as OptionButton
	var end := chrome.find_child("FinishEnd", true, false) as OptionButton
	var thin := chrome.find_child("ThinFeature", true, false) as CheckButton
	var flip := chrome.find_child("FlipSide", true, false) as CheckButton
	var face_box := chrome.find_child("UpToFaceBox", true, false) as Control
	check(op != null and end != null and thin != null and flip != null and face_box != null, "finish bar controls exist")
	check(op.get_item_text(op.selected) == "New" and chrome.get_finish_end() == "blind", "a fresh session starts at New / Blind")

	op.select(1)
	end.select(3)
	chrome._on_finish_end_selected(3)
	thin.button_pressed = true
	flip.button_pressed = true
	check(op.get_item_text(op.selected) == "Cut", "the walker's Op is now Cut")
	check(chrome.get_finish_end() == "to_face", "the walker's End is now Up To Surface")
	check(face_box.visible, "the Up To Surface face box is showing")

	sm.sketch.add_circle(0.0, 0.0, 10.0)
	op.select(0)
	end.select(0)
	chrome._on_finish_end_selected(0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	check(main.view.doc.body_ids().size() == 1, "one body exists before File > New")
	op.select(1)
	end.select(3)
	chrome._on_finish_end_selected(3)
	chrome.up_to_face_id = "stale-face-id"

	main._on_file_menu(0)
	await process_frame
	await process_frame
	check(main.confirm_dialog.visible, "File > New asks to discard the unsaved body")
	main._on_discard_confirmed()
	await process_frame
	await process_frame
	check(main.view.doc.body_ids().is_empty(), "File > New gives an empty part")
	check(op.get_item_text(op.selected) == "New", "File > New resets Op to New (got %s)" % op.get_item_text(op.selected))
	check(chrome.get_finish_end() == "blind", "File > New resets End to Blind (got %s)" % chrome.get_finish_end())
	check(str(chrome.up_to_face_id) == "", "File > New clears the Up To Surface face id")
	check(not thin.button_pressed, "File > New turns Thin feature off")
	check(not flip.button_pressed, "File > New turns Flip off")
	check(not face_box.visible, "File > New hides the Up To Surface face box")

	await FilmUI.enter_sketch(ctx)
	check(main.sketch_mode.active, "a sketch opens on the new part")
	check(op.get_item_text(op.selected) == "New" and chrome.get_finish_end() == "blind",
			"the next sketch's finish bar reads New / Blind")
	var extrude_btn := chrome.extrude_button()
	check(extrude_btn != null and not extrude_btn.disabled, "Extrude is enabled on the new part's first sketch")
	await _shutdown(ctx)

func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame
```

Run it on the unmodified tree: `19 checks, 8 failures`.

**Commit 2 — the product diff.**

```diff
diff --git a/game/scripts/sketch_context_chrome.gd b/game/scripts/sketch_context_chrome.gd
--- a/game/scripts/sketch_context_chrome.gd
+++ b/game/scripts/sketch_context_chrome.gd
@@ -1118,6 +1118,25 @@ func get_finish_end() -> String:
 	return opts[i]
 
 
+## File > New starts the finish bar from its defaults. Without this a Cut / Up
+## To Surface from the last part is still selected for the next part's blank.
+func reset_finish_defaults() -> void:
+	if _finish_op != null:
+		_finish_op.select(0)
+	if _finish_end != null:
+		_finish_end.select(0)
+	if _thin_feature != null:
+		_thin_feature.set_pressed_no_signal(false)
+	if _thin_spin != null:
+		_thin_spin.value = 0
+	if _thin_type != null:
+		_thin_type.select(0)
+	if _flip_side != null:
+		_flip_side.set_pressed_no_signal(false)
+	_apply_thin_visibility()
+	clear_up_to_face()
+
+
 func set_flip_side(on: bool) -> void:
 	if _flip_side:
 		_flip_side.button_pressed = on
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -2463,6 +2463,8 @@ func _do_new() -> void:
 			interaction.triball.cancel()
 	view.new_document()
 	current_path = ""
+	if sketch_chrome != null:
+		sketch_chrome.reset_finish_defaults()
 	# Empty part on the Top plane (XY through the origin). The Box primitive
 	# stays on the palette; New must not insert or select a body (that armed
 	# the selection strip and ate the next click).
```

`reset_finish_defaults` uses `select(0)` and `set_pressed_no_signal`, so it fires no signals mid-`New`; `_apply_thin_visibility()` and `clear_up_to_face()` bring the dependent controls (thin spin, face box) back in line.

Run the test again: `19 checks, 0 failures`. Also run `run_rung01_replan9_dirty.gd` (`13 checks, 0 failures`) and `run_rung01_replan3_shell.gd` (same count as the whole-suite table).

**GUI checklist item.** A10b / A14: after File → New the finish bar reads `New` / `Blind` before anything is touched.

---

### WP5 — The walk uses a human cutter offset and clicks Trim twice; lint and Makefile cover replan 10

Prerequisite: WP1–WP4 merged. **Files.** `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile`.

Why the walk edit looks the way it does:

- `first_miss` was 5.0, the one offset that only the solid-head fallback accepted; it was the reason headless passed while the GUI failed. It becomes 12.0, an offset a person draws, inside the new 0.9 · r limit. The existing assertions (`> 0.15 · 22.5`, remaining-cutter distance) still hold, and a new one pins the upper limit.
- After `Trimmed open jaw` the walk clicks Power Trim a second time with the same helper and asserts `Jaw is already open`, a clean status, and a closed profile, the human double-click.
- No other walk step changes. No `select_entity`, no script-side selection.

Apply this diff (Makefile, walk, lint):

```diff
diff --git a/Makefile b/Makefile
--- a/Makefile
+++ b/Makefile
@@ -136,6 +136,10 @@ test-godot: build import preflight
 		[ -e "$$f" ] || continue; \
 		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
 	done
+	@for f in game/tests/run_rung01_replan10_*.gd; do \
+		[ -e "$$f" ] || continue; \
+		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
+	done
 
 lint-rung01-e2e:
 	python3 tools/lint_rung01_e2e.py
diff --git a/game/tests/run_rung01_wrench.gd b/game/tests/run_rung01_wrench.gd
--- a/game/tests/run_rung01_wrench.gd
+++ b/game/tests/run_rung01_wrench.gd
@@ -276,8 +276,9 @@ func _walk(ctx: FilmContext) -> Dictionary:
 	check(absf(head_r - 22.5) <= 0.05, "jaw sketch has Ø45 at the head (r=%.4f)" % head_r)
 	await _draw_centre_rect(ctx, Vector2(200, 0))
 	await _edit_rect_labels(ctx)
-	var first_miss := 5.0
+	var first_miss := 12.0
 	check(first_miss > 0.15 * 22.5, "offset cutter misses the Ø45 15% gate")
+	check(first_miss < 0.9 * 22.5, "offset cutter still crosses the Ø45 disc inside the 90% rim limit")
 	print("  B2.10 leftover centreline along the jaw, then offset perpendicular retry")
 	await _draw_centreline(ctx, HEAD, JAW)
 	await _end_centreline_chain(ctx, HEAD)
@@ -299,6 +300,13 @@ func _walk(ctx: FilmContext) -> Dictionary:
 	err = _take_bad_status()
 	check(err == "", "jaw trim status clean" if err == "" else err)
 	check(SketchMode.profile_is_closed(sm.sketch), "jaw profile closed")
+	_status_log.clear()
+	await _power_trim_shaft_click(ctx)
+	await process_frame
+	check(_status_has("Jaw is already open"), "a second Power Trim click says the jaw is already open")
+	err = _take_bad_status()
+	check(err == "", "second trim click status clean" if err == "" else err)
+	check(SketchMode.profile_is_closed(sm.sketch), "jaw profile still closed after the second trim click")
 	chrome = ctx.main.sketch_chrome
 	await _pick_op(_finish_op(ctx), 1)
 	await _pick_end(_finish_end(ctx), 3)
diff --git a/tools/lint_rung01_e2e.py b/tools/lint_rung01_e2e.py
--- a/tools/lint_rung01_e2e.py
+++ b/tools/lint_rung01_e2e.py
@@ -376,6 +376,22 @@ def _lint_replan9(errors: list[str]) -> None:
         _lint_dimension_label_pos2(src, errors, prefix)
 
 
+def _lint_replan10(errors: list[str]) -> None:
+    paths = sorted(TESTS.glob("run_rung01_replan10_*.gd"))
+    if not paths:
+        errors.append(f"no run_rung01_replan10_*.gd scripts under {TESTS}")
+        return
+    for path in paths:
+        src = path.read_text(encoding="utf-8")
+        rel = path.relative_to(ROOT)
+        prefix = f"{rel}:"
+        _lint_needles(src, REPLAN7_FORBIDDEN, errors, prefix)
+        _lint_text_assignment(src, errors, prefix)
+        _lint_x11_click_await(src, errors, prefix)
+        _lint_current_dir_assignment(src, errors, prefix)
+        _lint_dimension_label_pos2(src, errors, prefix)
+
+
 def main() -> int:
     if not WALK.is_file():
         print(f"lint_rung01_e2e: missing {WALK}", file=sys.stderr)
@@ -390,6 +406,7 @@ def main() -> int:
     _lint_replan7(errors)
     _lint_replan8(errors)
     _lint_replan9(errors)
+    _lint_replan10(errors)
 
     if errors:
         print("lint_rung01_e2e: GUI shortcuts remain:", file=sys.stderr)
@@ -403,6 +420,7 @@ def main() -> int:
     n7 = len(list(TESTS.glob("run_rung01_replan7_*.gd")))
     n8 = len(list(TESTS.glob("run_rung01_replan8_*.gd")))
     n9 = len(list(TESTS.glob("run_rung01_replan9_*.gd")))
+    n10 = len(list(TESTS.glob("run_rung01_replan10_*.gd")))
     print(f"lint_rung01_e2e: {WALK} is clean")
     print(f"lint_rung01_e2e: {n3} replan3 scripts are clean")
     print(f"lint_rung01_e2e: {n4} replan4 scripts are clean")
@@ -411,6 +429,7 @@ def main() -> int:
     print(f"lint_rung01_e2e: {n7} replan7 scripts are clean")
     print(f"lint_rung01_e2e: {n8} replan8 scripts are clean")
     print(f"lint_rung01_e2e: {n9} replan9 scripts are clean")
+    print(f"lint_rung01_e2e: {n10} replan10 scripts are clean")
     return 0
 
 
```

Run order and expected output:

```
python3 tools/lint_rung01_e2e.py
#   ... lint_rung01_e2e: 4 replan10 scripts are clean
tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd
#   ... 7/7 passed   (nut)
#   ... 28/28 passed (wrench)
#   ... 4/4 passed   (thick)
#   404 checks, 0 failures
```

On `a2ff49b4` the same command prints `399 checks, 0 failures`; the five extra checks are the upper-limit assertion, the on-screen check of the second click, and the three second-click assertions. (The walk with the old 5.0 offset and the new product code also prints `399 checks, 0 failures`; only the human offset and the second click are new.)

**GUI checklist item.** A15.

---

## Whole-suite check (after every WP and after WP5)

Run every `game/tests/run_*.gd` one by one (do not use `make test-godot`: it stops at the first failure) and compare with this table. These are the suites that are not clean on `a2ff49b4`; each must print the **same** count after the change. Every other suite must print `0 failures`.

| Suite | Result on `a2ff49b4` (and required after) |
|---|---|
| `run_assembly_tests` | 87 checks, 4 failures |
| `run_film_caption_tests` | exit 0, no summary line |
| `run_film_manifest_smoke` | no summary; hangs headless in the reference VM, killed by `timeout 120` (exit 124) |
| `run_howto_tests` | 91 checks, 2 failures |
| `run_icon_tests` | 13 checks, 2 failures |
| `run_insert_component_tests` | 42 checks, 2 failures |
| `run_menu_tests` | 55 checks, 2 failures |
| `run_place_tests` | 110 checks, 1 failure |
| `run_property_tests` | 17 checks, 1 failure |
| `run_rung01_replan3_input` | 110 checks, 1 failure |
| `run_rung01_replan3_shell` | 43 checks, 6 failures |
| `run_rung01_replan_shell` | 34 checks, 1 failure |
| `run_rung01_sketch_tests` | 70 checks, 7 failures |
| `run_sketch_to_3d_ui_tests` | 47 checks, 2 failures |
| `run_sketch_tools_tests` | 141 checks, 13 failures |
| `run_ui_button_coverage_tests` | 35 buttons probed, 33 work, 2 broken; 36 checks, 3 failures |
| `run_visual_ux_tests` | 86 checks, 1 failure |

Differences that are expected and required: `run_rung01_wrench` 399 → 404 checks (WP5); `run_parse_sweep_tests` 223 → 227 checks (it parses the four new files); the four new `run_rung01_replan10_*` suites. `make test-kernel` is unchanged (`All tests passed (7900 assertions in 330 test cases)`); the only C++ change is the one WP2 hunk. Run `make build` before the Godot suites so `libsxcore.so` carries it.

The reference run: 99 suites on `a2ff49b4` and 103 with the change; the two summaries differ by exactly the lines above (`run_parse_sweep_tests` 223 → 227, `run_rung01_wrench` 399 → 404, the four new `run_rung01_replan10_*` suites at `114`, `25`, `19` and `38` checks, 0 failures) and nothing else. It was measured with a script that runs each suite with `timeout 120` and prints `name | exit code | last "N checks, M failures" line`. `run_rung01_sketch_tests` is the one to watch: it stays at `70 checks, 7 failures` only with the WP2 kernel hunk and the guard together (guard alone: `58 checks, 17 failures`).

## Soft-GL protocol for the sx-031 walker (no code)

Soft-GL (llvmpipe) drops, reorders and double-fires keystrokes, sometimes loses a click, and sometimes does not repaint after a dimension commit. This is environmental. The headless suites do not see it. The walker follows these rules; none of them is a shortcut. Rules 1–12 are replan 9's, unchanged except where marked; 13–16 are new from sx-030.

1. Type into one field at a time. After typing, **read the field back** (zoom the screenshot) before pressing Enter or Tab. If it does not show the intended text, select all (`Ctrl+A` in the field), retype, read back again. Up to three tries per field; log each try in WALK_LOG.
2. A click that has no effect (no status change, no selection change) may be a lost click. Repeat it once. If it again does nothing, log it as a product failure. Never click a third time. Exception: a Smart Dim second pick whose status says `first pick kept` is a miss, not a lost click; see rule 9. Exception 2: a Power Trim click whose status says `Jaw is already open` is not a lost click; the jaw is open, go on (rule 15).
3. If a field refuses a value after three tries, draw the circle by mouse (centre click, re-issue the pointer move, rim click), then size it with Smart Dimension: click the circle's edge and type the value in the popup, reading it back before Enter. Log the fallback. The centre distance 200 is always a Smart Dimension between the two centres.
4. After each dimension, wait for the status line to change before the next action.
5. When an Extrude, cut or fillet is refused, record the refusal text verbatim; a named refusal is a pass for the refusal rows (A10), a mangled body without one is a fail. For A9 and A9b a refusal is **not** a pass: record it and see rules 15 and 16.
6. Never use the film/test hooks (`select_entity`, script-side selection, direct sketch API). The walk's lint forbids them; the human walker does not use them either.
7. **The field on a circle is the radius.** Ø20 is `10`, Ø45 is `22.5`, Ø100 is `50`, Ø90 is `45`. The `Circle r=…` status shows both radius and diameter; read it. Paste via `xclip` + `Ctrl+V` when the clipboard works (`which xclip`; install it before the walk if missing); if a paste is empty once, type instead.
8. **The status line is the truth, the viewport is not.** `radius: success`, `Dimension updated`, `Shaft lines: 2 added`, `Circle r=… (Ø…)`, `Trimmed open jaw` and the timeline panel entries (`sketch 1`, `extrude 2`) confirm a commit even when the viewport is stale. Frame **once**; if the chip rows or labels are still ghosted after that one Frame, stop framing and trust the status line. Do not retry a commit because the picture did not change.
9. **Smart Dim second pick is a plain click, no Shift.** After the first centre click the status must read `Smart Dim: first pick set …`. If the second click gives `nothing there — first pick kept`, the first pick is alive: click closer to the centre dot (or on the circle edge) and again. Do not start over.
10. **Keep the blank open until `wrench.3mf` and `wrench-t14.3mf` are exported. No File → New before then.** After A5 and A5b, File → Save As `blank.sxp` into the sx-031 `out` folder as a checkpoint. Re-save `blank.sxp` before A9b (the cut), so a bad cut can be recovered.
11. If a cut is **accepted** but the body is wrong (not refused), or the viewport stays ghosted after one Frame, and a `blank.sxp` checkpoint exists: File → Open `blank.sxp` once (press the Discard dialog's OK; it appears because the document is unsaved) and redo the jaw from the face sketch. Log what happens. A refused cut needs no recovery: the sketch stays open and the body is unchanged (WP2). If no checkpoint exists, or the reopened document is also ghosted, record HARD BLOCK and stop that row.
12. Pointer moves issued right after a click are dropped by the desktop: after each click, move the pointer in a separate action before the next click or rim pick.
13. **Mouse-draw fallback (rule 3, restated for the jaw).** If a field refuses digits three times, draw the shape by mouse, then dimension it with Smart Dimension and read the value back. The jaw rectangle is always three clicks and the width 20 is a dimension, whichever way the lines were made.
14. **Esc ladder.** With a Jaw line selected the presses are: `Measure cleared`, `Selection cleared — Esc again exits the sketch`, `Tool dropped — Esc again exits the sketch` (only if a draw tool is active), then the sketch exits. Stop pressing at the second status if you want to keep the sketch. If the sketch vanishes on the **first or second** Esc with geometry in it, that is the P1 defect again: FAIL A8b, rebuild from `blank.sxp`.
15. **Power Trim click rule.** Click once on the shaft side of the perpendicular cutter. Read the status: `Trimmed open jaw` is the pass. `Jaw is already open — nothing left to trim here` means a second click, not a failure. `Trim failed — the centreline is N mm from the Ø45 head centre (limit 20.2 mm): draw it closer to the head centre` is a named refusal: delete the cutter and draw it nearer the head centre (anything up to 18 mm). `Trim failed — draw the centreline across the jaw`: the cutter is within 2° of the jaw's long side, draw it across. `Trim failed — no head circle` means the Ø45 circle is missing from the sketch: redraw it. A bare `Trim failed` with no explanation is a product defect: record the status line and screenshot and stop A9.
16. **Cut rule.** Read the finish bar before pressing Extrude: Op `Cut`, End `Up To Surface`, face label `z 0`, thin and flip off. If the cut is refused with `Cut left an open shell (…)`, the body and sketch are untouched; record the text verbatim and the contour (what overlaps what), and **do not** retry with the same contour. A refusal on the trimmed handout jaw is a product failure (the kernel fix makes that cut closed every time). Do not press Extrude again hoping for a different result: a document's boolean result does not change between tries.

## Timeline Distance 14 (carry, GUI)

After the wrench is finished and exported as `wrench.3mf`: open the timeline, double-click the base Extrude (the first extrude, Distance 10), set Distance to 14, Enter. The Up To Surface jaw cut follows the new depth (the jaw is still open through, the slot floor stays 2.5 mm below the top). Export `wrench-t14.3mf` and run `python3 tools/check_rung01.py thick wrench-t14.3mf 14` → 4/4. If the replan 8 cut refusal fires during this edit, record the text: it means the edit changed the removed volume by more than half, which is a product failure for this row. If `Cut left an open shell` fires, that is a WP2 false refusal on the regenerated solid: record it as a product failure for this row.

## sx-031 GUI checklist

The walker does the handout in the real GUI at 1280×800 on the build that contains WP1–WP5, logs every step, and runs the four checkers on the exported files. One row per WP; the rows keep their sx-030 numbers. A step is PASS only if it was done with the mouse and keyboard.

**Walk order:** A1, A2, A3, A4, A5, A5b, A7, A6, A7b, A8, A8b, A9, A9b, A11, A12, A13, then the scratch rows A10, A10b and A14, then A15. A10 and A14 start a new document, so they come after `wrench.3mf` and `wrench-t14.3mf` are exported. A6 runs inside the face sketch of the blank so no File → New is needed before A8.

| Row | WP | Action | Pass looks like |
|---|---|---|---|
| A1 | carry | In a new sketch, read the left rail (scroll it at 800 px) | Every button has a word under its icon: Select, Line, Arc, Circle, Rect, Jaw, Polygon, Ellipse, Slot, Spline, Point, Trim, Extend, Smart Dim, Convert, Mirror, Pattern, Auto Dim |
| A2 | carry (green in sx-030) | Press `Jaw`; then `Rect`; then click `Parallelogram` twice | After `Jaw`: `Center Three Point` highlighted, other chips grey. After `Rect`: `Corner` highlighted. After the chip clicks: `Parallelogram` highlighted |
| A3 | carry (green in sx-030) | Draw Ø20 at the origin and Ø45 at the right (Radius 10 and 22.5). `Smart Dim`; click the Ø20 centre; click the Ø45 centre with plain clicks | `Smart Dim: first pick set …`, then the dimension popup. Type `200`: `Dimension updated`. No Shift |
| A4 | carry | With both circles still selected press the `Shaft Lines` chip (or `Select`, click empty canvas, click each circle edge, chip) | Status `Shaft lines: 2 added`; two horizontal lines at y = ±10 joining the circles |
| A5 | carry | Extrude 10, export 3MF | `check_rung01.py blank` 5/5 |
| A5b | carry (green in sx-030) | Do not Save. Wait a minute. File → New. Press Cancel. Then File → Save As `blank.sxp` | `Discard unsaved changes?` appears; after Cancel the blank is still on screen |
| A7 | carry | `Esc`; palette `Sketch`; one click on the top face | Body deselected; `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)` |
| A6 | carry | In that face sketch: Circle tool, one click, `Esc`; then `Esc` again | First `Esc` keeps the sketch (`First point dropped — Esc again exits the sketch`); second exits the sketch. The blank is untouched |
| A7b | carry | Palette `Sketch`; one click on the top face again | A new face sketch opens on the blank |
| A8 | carry | In the face sketch press `Jaw`; three clicks (centre, long side, half-width), dimension 20 | Four lines; width 20 |
| A8b | WP3 | With the Jaw lines on screen: `Select` tool, click one Jaw line, then press `Esc` three times, reading the status after each | `Measure cleared`; `Selection cleared — Esc again exits the sketch` (sketch and all four lines still there); then pick the Jaw tool again and `Esc`: `Tool dropped — Esc again exits the sketch`. Stop there and continue to A9 in the same sketch. FAIL if the sketch disappears before the last press |
| A9 | WP1 | In the same sketch: Circle tool, radius 5 at the origin (pivot hole); Circle tool, radius 22.5 at the head (redraw Ø45 as a sketch circle); `Line` + `Centerline` chip: a centreline along the jaw through the head centre, then end the chain; a second centreline **across** the jaw, centred 12 mm along the jaw from the head centre (any offset from 0 to 18 works; drawing it replaces the first centreline, so one cutter remains); `Power Trim`; one click on the shaft side of the cutter | Status `Trimmed open jaw`; the jaw is open at the far end with the Ø45 cap arc at the head. Click Trim once more: `Jaw is already open — nothing left to trim here`. **Never** `Trim failed`. A named refusal here is a FAIL for the row (record the text; rule 15) |
| A9b | WP2 | Finish bar: Op `Cut`, End `Up To Surface`, press `Opposite face` (label `z 0`); Extrude. Re-save `blank.sxp` first (rule 10) | Cut accepted; timeline shows the cut; the body is a wrench with an open jaw and a pivot hole, not a mangled solid. If refused, the text names it (`Cut left an open shell …` or `Cut would remove …`) and the body and sketch are untouched; that is a FAIL for this row and the walker records the contour and the cutter offset |
| A11 | carry | Slot 2.5 deep, fillets (R10 neck, 1 mm edges) | Per the handout; any refused fillet shows its reason |
| A12 | carry | Export `wrench.3mf` | `check_rung01.py wrench` 28/28, no `--allow-mirror`, orientation row `flipX=False flipY=False` |
| A13 | carry | Timeline Distance 14 (steps above), export `wrench-t14.3mf` | `check_rung01.py thick wrench-t14.3mf 14` 4/4 |
| A10 | carry (exact sizes) | Scratch document (File → New; press the Discard dialog's OK): Circle tool radius `50` (Ø100), Extrude 10; Sketch on the top face; Circle tool radius `45` (Ø90) at the origin; Op `Cut`, End `Blind`, Extrude | Status `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; body unchanged; sketch open. If the percentage is not 81 read the two `Circle r=…` statuses: a wrong size is a walker error, not a product failure |
| A10b | WP4 | Right after that File → New (before the Ø100 sketch) and again after the next File → New: open a sketch on Top and read the finish bar | Op `New`, End `Blind`, no `Face:` box, Extrude enabled. FAIL if Op shows `Cut` or End shows `Up To Surface` |
| A14 | carry | Nut (File → New again): polygon AF 20, hole Ø10 (radius 5), Extrude 7.5 without touching Op or End, export | `check_rung01.py nut` 7/7 |
| A15 | WP5 | `python3 tools/lint_rung01_e2e.py` and `run_rung01_wrench.gd` | lint clean (`4 replan10 scripts are clean`); `404 checks, 0 failures` |

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 4/4, walk 0 failures, part made in the real GUI.

If the soft-GL protocol above cannot complete A9–A13 even with the checkpoint, the critique scores what ran and lists the blocked rows by name; it does not mark them PASS.

## Out of scope

- No soft-GL / llvmpipe / Mesa driver change and no product WP for stale viewports, dropped keys, lost clicks or the clipboard.
- No kernel change beyond the one WP2 hunk (the fuzzy value on the Extrude Cut boolean; Fuse and every other boolean stay as they are), no change to `select_ray` or any pick logic, no change to the checker formulas.
- No second jaw in one sketch: `Jaw is already open` stays true while the first jaw's floor, arc and walls exist; delete them (or start a new sketch) to trim another.
- No change to the 81 % volume guard or its text (F5), no new guard on fillets.
- No unsaved-changes prompt on app quit, and nothing to the autosave (replan 9 WP3 stays as it is).
- Replan 9's chip highlight, Smart Dim first pick and autosave-dirty work are green and are not redone.
- Wave features and `docs/plan/*` are untouched.
