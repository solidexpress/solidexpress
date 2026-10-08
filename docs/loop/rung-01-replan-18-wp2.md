# Rung 1 replan 18 — WP2: three stale tests: propose_parallel film, replan11_ux, replan15_extrude (tests only)

Status: planned. Plan: [`rung-01-replan-18.md`](rung-01-replan-18.md). Next walk: **sx-039** (the checklist embedded in the plan). Baseline: `main` `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed` (re-PLAN 17 complete plus the spin-outs #216–#225).

Start from `main`. Open one PR. Stay until quick CI (linux kernel, godot-smoke, website-demos) is green. Never wait for `macos-kernel` or `windows-export`. Do not edit `docs/plan/STATUS.md`. This WP is independent of the other WPs of the plan: start it now.

Triage items covered: **T2, T3, T4** (full-tier reds `run_film_manifest_smoke`, `run_rung01_replan11_ux`, `run_rung01_replan15_extrude`). Walk rows unblocked: A15 (full tier 0 failed).

## Rules for every BUILD agent (read first)

- **Repository:** `github.com/solidexpress/solidexpress` only. Never the `snadrus` fork. Do not touch PR #11.
- **Model / start:** grok-4.7, medium effort. Start from `main` (`starting_ref` = the full 40-character sha of `main` at launch; the plan was written against `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed`). If `main` has moved, say so in the PR body and carry on from the new tip. Function names below are stable; line numbers are not quoted.
- **One PR per WP, to `main`.** Open it **ready for review** (not draft). Never merge it yourself. Stay with the PR until quick CI is green: **linux kernel, godot-smoke, website-demos**. **Never wait for `macos-kernel` or `windows-export`.**
- **Do NOT edit `docs/plan/STATUS.md`** (take `main`'s version on any conflict). Put your notes (what changed, red-first output, skipped items with the reason) in the **PR body**.
- **Reproduce first.** Run the named suite(s) on the starting ref **before** any edit and paste the real output (the `FAIL -` lines) in the PR body. If a suite that the plan says is red is already green, stop, say so, change nothing, and open no PR.
- **Tests are real input.** Setup (placing geometry, entering a sketch, adding entities) may use the document / sketch API and `tests/lib/film_ui.gd`. Every press, key, motion and wheel **under test** is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed with `Viewport.push_input`. Forbidden on a path under test (the e2e lint fails the PR for `run_rung01_replan16_*` and later): `select_entity`, `.text =`, `.value =`, `.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =`. Boot at 1280x800 (`FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))`).
- **Register a suite** only by adding one new file `packaging/ci/suites.d/<name>.suite` (`<name>` = script basename without `run_` and `.gd`; keys `script=tests/<file>.gd`, `tier=ci|full`, optional `timeout=<s>`). **Never edit** `packaging/ci/run_godot_suites.sh`, `packaging/ci/run_suites.sh`, the Makefile `test-godot` recipe, `tools/lint_rung01_e2e.py` or `AGENTS.md`. Do not commit `.gd.uid` files.
- **Run suites one at a time** with `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` (and `DISPLAY=:1` for X11 suites): `tools/godot/godot --headless --path game --script tests/<file>.gd`. A suite passes when it prints `<n> checks, 0 failures` (films: `65 films, 0 failures`).
- **Before opening the PR run, one at a time:** the suites your WP names; `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; and the "Also run" list of your WP. Paste the last line of each in the PR body.
- **Never** pass `user://` or `res://` into GDExtension C++ (`SxDocument` / kernel I/O); `ProjectSettings.globalize_path(...)` first.
- **Parallel-safe edits.** The other WPs of this plan run at the same time on the same `main`. Edit **only** the files and functions your WP names. No reformatting, no moved code, no renames, no new status strings, no new top-of-file constants.
- **No design decisions are left to you.** Every choice is in the `Decisions` section of your WP. If the code on `main` contradicts a stated fact, stop, say so in the PR body, and implement the closest reading of the decision.

## Why

The full tier is red on `main` (`suites: 181 run, 5 failed`, bisected in the plan). Three of the five failures are **tests that encode behaviour a later, deliberate merge replaced**. The product is right; the test is stale. Each fix below was written and run on the PLAN box (the diff is exact), and each makes its suite green with no product change.

| Suite | Failing check(s) on `main` | Deliberate change that made it stale |
|---|---|---|
| `run_film_manifest_smoke` | `propose_parallel: no FilmUI offscreen/control errors (got 1)` (`FilmUI: clickable control missing or hidden (parallel?)`) | #221: the sketch suggestion chips (`Parallel?`, `Equal?`) are hidden while the selection is empty (L12: they must not linger after Esc / Delete). The film drew two lines and clicked the chip with nothing selected. With both lines selected the chip row holds 20 chips and `Parallel?` is in the `… More` menu. |
| `run_rung01_replan11_ux` | `near-X centres get horizontal (dy=0.0000 horiz=0)` | #220: Smart Dim between two circle centres no longer adds a construction line; it adds a **two-centre** `horizontal` constraint (geometry is level: `dy=0.0000`). The helper counted horizontals on construction lines. |
| `run_rung01_replan15_extrude` | `B1 status is the invalid-distance sentence (got 'Extrude Blind 20.0000 mm')`, `B1 no feature added`, `B1 the sketch stays open` | #217: letters never reach the Extrude Distance field. Before a digit they are sketch tool keys (`a` Arc, `c` Circle: the field stays `20.0`); after a digit the typed digits are re-asserted (`1abc` leaves `1`). The test typed `abc` and expected unreadable text. `1.2.3` still is unreadable and still prints `Cannot read distance: 1.2.3`. |

## Decisions (final)

1. **Files you may edit:** `game/tests/films/film_propose_parallel.gd`, `game/tests/run_rung01_replan11_ux.gd`, `game/tests/run_rung01_replan15_extrude.gd`. **No product code. No other test. No `.suite` file.**
2. Apply the three diffs below **exactly** (they are `git diff` output against `main`; `git apply` works, or edit by hand). Do not "improve" them.
3. If a diff does not apply because `main` moved, re-derive the same edit from the table above; if the table's cause no longer matches the code, stop and say so in the PR body.

### Diff 1 — `game/tests/films/film_propose_parallel.gd`

```diff
diff --git a/game/tests/films/film_propose_parallel.gd b/game/tests/films/film_propose_parallel.gd
index 9f013b1..4cc0afc 100644
--- a/game/tests/films/film_propose_parallel.gd
+++ b/game/tests/films/film_propose_parallel.gd
@@ -10,21 +10,25 @@ func run_film(ctx: FilmContext) -> void:
 	var sm = ctx.main.sketch_mode
 	await FilmUI.draw_line(ctx, sm, Vector2(18, 18), Vector2(36, 18.4))
 	await FilmUI.draw_line(ctx, sm, Vector2(18, 26), Vector2(36, 26.8))
+	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
+	await FilmUI.click_sketch(ctx, sm, Vector2(27, 18.2), "Select the first line")
+	await FilmUI.click_sketch(ctx, sm, Vector2(27, 26.4), "Select the second line")
 	await FilmUI.wait_frames(ctx.tree, 2)
-	var ix = ctx.main.interaction
-	if ix != null and ix.has_method("_open_marking_menu"):
-		ix._open_marking_menu(ix._screen_center() if ix.has_method("_screen_center") else Vector2(400, 300))
-		await FilmUI.wait_frames(ctx.tree, 3)
-		var menu: MarkingMenu = ix.marking_menu
-		if menu != null and menu.visible:
-			var b := FilmUI.find_button(menu, "parallel?")
-			if b != null:
-				await FilmUI.click_control(ctx, b, FilmUI.FilmUICues.alert("S", "Propose parallel"))
-			else:
-				await FilmUI.click_button(ctx, "parallel?")
+	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Parallel?")
+	if chip != null:
+		await FilmUI.click_control(ctx, chip, FilmUI.FilmUICues.alert("S", "Propose parallel"))
+	else:
+		var more := FilmUI.find_button(ctx.main.sketch_chrome, "… More") as MenuButton
+		var item_id := -1
+		if more != null:
+			var popup := more.get_popup()
+			for i in popup.item_count:
+				if str(popup.get_item_text(i)) == "Parallel?":
+					item_id = i
+					break
+		if item_id >= 0:
+			await FilmUI.activate_menu_id(ctx, more, item_id, FilmUI.FilmUICues.alert("S", "Propose parallel"))
 		else:
 			await FilmUI.click_button(ctx, "parallel?")
-	else:
-		await FilmUI.click_button(ctx, "parallel?")
 	await ctx.beat("Proposed parallel", 0.8)
 	await ctx.camera.showcase_smooth(0.7, 14.0)
```

### Diff 2 — `game/tests/run_rung01_replan11_ux.gd`

```diff
diff --git a/game/tests/run_rung01_replan11_ux.gd b/game/tests/run_rung01_replan11_ux.gd
index f42b378..54e6aad 100644
--- a/game/tests/run_rung01_replan11_ux.gd
+++ b/game/tests/run_rung01_replan11_ux.gd
@@ -53,18 +53,18 @@ func _run() -> void:
 	sm.run_solve()
 	var y0: float = float(sm.sketch.entity_info(c0)["center"].y)
 	var y1: float = float(sm.sketch.entity_info(c1)["center"].y)
-	check(absf(y1 - y0) <= 0.05 and _horiz_on_construction(sm) >= 1,
-			"near-X centres get horizontal (dy=%.4f horiz=%d)" % [y1 - y0, _horiz_on_construction(sm)])
+	check(absf(y1 - y0) <= 0.05 and _horiz_between(sm, c0, c1) >= 1,
+			"near-X centres get a two-centre horizontal (dy=%.4f horiz=%d)" % [y1 - y0, _horiz_between(sm, c0, c1)])
 
-	var horiz_before := _horiz_on_construction(sm)
+	var horiz_before := _horiz_total(sm)
 	var c2: String = sm.sketch.add_circle(30.0, 20.0, 4.0)
 	sm._smart_dim_between(
 			{"entity": c0, "role": "center"},
 			{"entity": c2, "role": "center"})
 	sm.run_solve()
-	check(_horiz_on_construction(sm) == horiz_before,
+	check(_horiz_total(sm) == horiz_before,
 			"20° centre pair does not add a horizontal constraint (before=%d after=%d)" % [
-				horiz_before, _horiz_on_construction(sm)])
+				horiz_before, _horiz_total(sm)])
 
 	var lid: String = sm.sketch.add_line(0.0, 40.0, 12.0, 40.0)
 	var sel: Array[String] = []
@@ -204,18 +204,28 @@ func _sxp_text(path: String) -> String:
 	return txt
 
 
-func _horiz_on_construction(sm: SketchMode) -> int:
+func _horiz_total(sm: SketchMode) -> int:
+	var n := 0
+	for cid in sm.sketch.constraint_ids():
+		var info: Dictionary = sm.sketch.constraint_info(str(cid))
+		if str(info.get("type", "")) == "horizontal":
+			n += 1
+	return n
+
+
+func _horiz_between(sm: SketchMode, ida: String, idb: String) -> int:
 	var n := 0
 	for cid in sm.sketch.constraint_ids():
 		var info: Dictionary = sm.sketch.constraint_info(str(cid))
 		if str(info.get("type", "")) != "horizontal":
 			continue
-		for ref in info.get("refs", []):
-			var eid := str(ref.get("entity", ""))
-			if sm.sketch.is_construction(eid) \
-					and str(sm.sketch.entity_info(eid).get("type", "")) == "line":
-				n += 1
-				break
+		var refs: Array = info.get("refs", [])
+		if refs.size() < 2:
+			continue
+		var a := str(refs[0].get("entity", ""))
+		var b := str(refs[1].get("entity", ""))
+		if (a == ida and b == idb) or (a == idb and b == ida):
+			n += 1
 	return n
```

### Diff 3 — `game/tests/run_rung01_replan15_extrude.gd`

```diff
diff --git a/game/tests/run_rung01_replan15_extrude.gd b/game/tests/run_rung01_replan15_extrude.gd
index be9fe0a..33946dd 100644
--- a/game/tests/run_rung01_replan15_extrude.gd
+++ b/game/tests/run_rung01_replan15_extrude.gd
@@ -236,7 +236,7 @@ func test_invalid_distance() -> void:
 	await _ground_rectangle(ctx)
 	var chrome: SketchContextChrome = ctx.main.sketch_chrome
 	var sm: SketchMode = ctx.main.sketch_mode
-	var edit := await _type_distance(ctx, "abc")
+	var edit := await _type_distance(ctx, "1.2.3")
 	print("B1 distance text='%s'" % (edit.text if edit != null else ""))
 	var doc = ctx.view.doc
 	var ex0 := _extrude_count(doc)
```

## Acceptance (exact)

Red first, then green, one at a time (paste both):

- `tests/run_rung01_replan11_ux.gd`: before `12 checks, 1 failures`; after `12 checks, 0 failures`.
- `tests/run_rung01_replan15_extrude.gd`: before `47 checks, 3 failures`; after `47 checks, 0 failures`.
- `tests/run_film_manifest_smoke.gd` (about 4 minutes): before `65 films, 1 failures`; after `65 films, 0 failures`. The film must still end by showing the proposed parallel (`await ctx.beat("Proposed parallel", 0.8)` is untouched).
- `python3 tools/lint_suites.py`; `bash scripts/sx-check-website-demos` (the film feeds the website demo manifest; it must stay green).

## Also run

`tests/run_rung01_replan17_selectbox.gd` (pins the empty-selection chip hiding that made the film stale; it stays green), `tests/run_rung01_sx038_sketch.gd`, `tests/run_rung01_sx038_focuskeys.gd`.

## Rows unblocked

A15 (`make test-godot` ends `suites: <n> run, 0 failed` once WP2, WP3 and WP4 are all merged).
