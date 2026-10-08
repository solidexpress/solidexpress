# Rung 1 replan 17 — WP5: the full tier goes green (A15) — fix the stale suites, a `known-red` tier with reasons, a lint test that does not rot

Status: planned. Plan: [`rung-01-replan-17.md`](rung-01-replan-17.md) (section "A15", the 32-suite table is the work list). Next walk: [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md) row A15. Baseline: `main` `1a1cc6ac40303fb747bd2a14d8e8ec98f1d5f705`.

Triage item fixed: **T4** (`make test-godot` is red: 32 of 170 suites on `main`, not the 3 `AGENTS.md` names; and `python3 tools/test_lint_suites.py` fails 2 of 8 tests). Walk row unblocked: **A15**.

Files you may edit: `packaging/ci/run_suites.sh`, `packaging/ci/suites.d/*.suite` (retier / add `reason=` only; never rename), `tools/lint_suites.py`, `tools/test_lint_suites.py`, `Makefile` (add the target `test-godot-known-red` and add its name to `.PHONY`; do **not** touch the `test-godot` recipe; add one line to `test-tools`), `AGENTS.md` (only the paragraph that lists known-red suites and the known pre-existing failures), `packaging/ci/suites.d/README.md` (document the new tier and key), `game/tests/lib/film_ui.gd` (new helper `place_instance`), the eight films and the test files named in the A15 table, and the product functions named in the A15 table rows you fix (`sketch_context_chrome.gd` `_on_distance_edit_gui_input` for R3, `ops_panel.gd` for the `Move` icon). Do **not** touch: `packaging/ci/run_godot_suites.sh`, `tools/lint_rung01_e2e.py`, `docs/plan/STATUS.md`, and the three polygon suites WP2 owns (`run_rung01_replan2_commit.gd`, `run_rung01_replan2_pointer.gd`, the `polygon is committed` check of `run_rung01_replan3_input.gd`).

## Rules for every BUILD agent (read first)

- **Repository:** `github.com/solidexpress/solidexpress` only. Never the `snadrus` fork. Do not touch PR #11.
- **Model / start:** grok-4.7, medium effort. `starting_ref` = the full 40-character sha of `main` at launch (the plan was written against `1a1cc6ac40303fb747bd2a14d8e8ec98f1d5f705`; function names below are stable, line numbers are for that sha).
- **One PR per WP, to `main`.** Mark it **ready for review** (not draft). Never merge it yourself. Quick CI must be green: **linux kernel, godot-smoke, website-demos**. **Do not wait for `windows-export` or `macos-kernel`.**
- **Do NOT edit `docs/plan/STATUS.md`** (take `main`'s version on any conflict). Put your notes (what changed, reproduce-first output, skipped items with the reason) in the **PR body**.
- **Reproduce first.** Write the new suite, run it on the starting ref **before** any product edit, paste the real red/green output in the PR body. Green on baseline = keep the suite as a regression net and say the item was already fixed or is soft-GL.
- **Tests are real input.** Setup (placing geometry, entering a sketch, adding entities) may use the document / sketch API and `tests/lib/film_ui.gd`. Every press, key, motion and wheel **under test** is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed with `Viewport.push_input`. Forbidden on a path under test (the e2e lint fails the PR): `select_entity`, `.text =`, `.value =`, `.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =`. Boot at 1280x800 (`FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))`). Templates to copy: `game/tests/run_rung01_sx037_chipclick.gd` (`_boot`, `_x11_click`, `_x11_click_screen`, `_click_uv`, `_push_key`), `run_rung01_sx037_exit.gd`, `run_rung01_l12_measure.gd`.
- **Register a suite** by adding one new file `packaging/ci/suites.d/<name>.suite` (`<name>` = script basename without `run_` and `.gd`). Keys: `script=tests/run_rung01_replan17_<x>.gd`, `tier=ci` (when it runs in <= 60 s measured; say so in the PR) or `tier=full`, optional `timeout=<s>`. **Never edit** `packaging/ci/run_godot_suites.sh`, the Makefile `test-godot` recipe or `tools/lint_rung01_e2e.py` (WP5 is the only exception, and only for the files its own text names). Do not commit `.gd.uid` files.
- **Before opening the PR run, one at a time:** your new suite; `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` (0 failures, >= 729 checks); `tools/godot/godot --headless --path game --script tests/run_rung01_replan16_walk.gd` (0 failures, `WALK-SUMMARY stages=8 first_red=none`); every suite in your "Also run" list. Environment: `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib`, `DISPLAY=:1` for X11 suites; run suites alone. The known-red suites in `AGENTS.md` stay exactly as they are unless WP5 changes their tier.
- **Never** pass `user://` or `res://` into GDExtension C++ (`SxDocument` / kernel I/O); `ProjectSettings.globalize_path(...)` first.
- **Parallel-safe edits.** Other WPs run at the same time on the same files in *different functions*. Edit only the functions your WP names. No reformatting, no moved code, no new top-of-file constants outside your own block, no renames of existing status strings unless your WP says so.
- **No design decisions are left to you.** Every choice is in the `Decisions` section of your WP. If the code on `main` contradicts a stated fact, stop, say so in the PR body, and implement the closest reading of the decision.

## Why

Facts measured on `main` `1a1cc6a` (OCCT 8.0.1 built from source): `KEEP_GOING=1 make test-godot` → `suites: 170 run, 32 failed`; the full tier has no CI gate (godot-smoke runs only `tier=ci`), so tests rotted behind deliberate UI changes (#39 shop surface, #184 / #201 Esc ladder, #191, #193, #194 / #200 numeric fields, #195, #204 views, #205 fillet Enter). The table in `rung-01-replan-17.md` "A15" gives, per suite, the failing checks, a verdict (product / stale), whether it is verified or a hypothesis, and the action.

## Decisions (final)

1. **Fix, do not hide.** Product bugs and stale tests are fixed. A suite goes to `tier=known-red` only when, after reading its failing check and the code it exercises, you cannot classify it in this PR; the manifest then carries `reason=<class>: <one sentence naming the failing check and what you ruled out>` with class `env`, `stale-feature` (cite the PR that removed the behaviour) or `product` (a real bug you could not fix here). No other class, no empty reason. The target is **zero** known-red suites; each one left is listed in the PR body with its reason.
2. **New tier `known-red`.** Not run by `--tier ci` or `--tier full` (so `make test-godot` and godot-smoke ignore it). `--tier known-red` **lists** `<script> — <reason>` per line and exits 0; `--tier known-red --run` runs them, prints `still red: <script>` or `NOW GREEN: <script> (re-tier it)` and exits 1 only when one is now green. `--list` keeps printing script paths only (for `known-red` too).
3. **Manifest key `reason=`.** Allowed only with `tier=known-red`, required there, non-empty, starts with `env:`, `stale-feature:` or `product:`. `tools/lint_suites.py` enforces it (`ALLOWED_KEYS`, `TIERS`, summary `lint_suites: <n> suites ok (<a> ci, <b> full, <c> known-red)`; the summary keeps the `(<a> ci, <b> full` prefix and appends `, <c> known-red` only when c > 0).
4. **`tools/test_lint_suites.py` stops hard-coding counts.** The two failing tests become count-agnostic: total in the summary equals the number of `*.suite` files and equals `ci + full + known-red`; the ci `--list` contains every `OLD_CI` script and `run_rung01_replan16_suites.gd` and has at least 29 lines; `KNOWN_RED` (the five legacy names) is removed as a tier assertion and replaced by: each of the five is either `ci`, `full` or `known-red` (a suite fixed by you may be `full`). Add cases: `known-red` without `reason=` exits 1 and names the manifest; `reason=` on a `ci` suite exits 1; a bad class prefix exits 1; `--tier known-red --list` prints scripts; `--tier known-red` prints the reason. The baseline test keeps `len(baseline) == 154`-style checks only as `>=`.
5. **Wire it.** `make test-tools` also runs `python3 tools/test_lint_suites.py` (one line, after `lint_suites.py`). `make test-godot-known-red` = `GODOT_BIN=$(GODOT) packaging/ci/run_suites.sh --tier known-red $(if $(RUN),--run)`.
6. **`AGENTS.md`.** Replace the "Known-red suites (...) stay `tier=full`" sentence and the "Known pre-existing test failures" bullets with: the full tier is expected green; known-red suites (if any) are listed by `make test-godot-known-red` with their reasons; `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered; the `nav_preset` note stays only if a suite still depends on it. Keep every other line (the AGENTS.md rules are shared with other agents).
7. **Order of work inside the PR** (commit each group separately): (a) runner + lint + lint test + Makefile + README (no suite changes) and prove with a temporary manifest in a temp `SX_SUITES_DIR`; (b) R3 product fix; (c) R1/R2 films and `FilmUI.place_instance`; (d) stale tests R1b R4 R4c R5 R6 R9; (e) R7; (f) whatever is left becomes known-red with reasons; (g) `AGENTS.md`.

## Steps

1. **`packaging/ci/run_suites.sh`**: in `parse_manifest` add `REASON=""`, `seen_reason`, and
```bash
      reason)
        if [[ "${seen_reason}" -eq 1 ]]; then
          echo "duplicate reason key in $(basename "${file}")" >&2
          return 2
        fi
        seen_reason=1
        REASON="${val}"
        ;;
```
   after the loop: tier must be `ci`, `full` or `known-red` (message `bad tier …` unchanged for anything else); `known-red` requires `REASON` to match `^(env|stale-feature|product): .+` (else `missing reason in <file>` / `bad reason class in <file>`, exit 2); `REASON` set with another tier → `reason only allowed on known-red in <file>`, exit 2. Parse `--run` (`RUN=1`). Tier selection: `ci` keeps tier ci only; `full` keeps ci and full; `known-red` keeps known-red only (and `ONLY` globs still apply). Collect `selected_reasons[]` next to `selected_scripts[]`. After `--list` handling:
```bash
if [[ "${TIER_ARG}" == known-red && "${RUN}" -eq 0 ]]; then
  for i in "${!selected_scripts[@]}"; do
    printf '%s — %s\n' "${selected_scripts[$i]}" "${selected_reasons[$i]}"
  done
  echo "suites: ${#selected_scripts[@]} known-red"
  exit 0
fi
```
   With `--run`: run as today without `break`, and invert the verdict per suite (rc 0 → `NOW GREEN: …`, failed += 1; rc != 0 → `still red: …`). The final `suites: <run> run, <failed> failed` line keeps its shape.
2. **`tools/lint_suites.py`**: `ALLOWED_KEYS = {"script", "tier", "timeout", "reason"}`, `TIERS = {"ci", "full", "known-red"}`, the `reason` rules of Decision 3 in `parse_manifest`, the summary line of Decision 3 in `main`. `collect_errors` already counts known-red as registered.
3. **`tools/test_lint_suites.py`** per Decision 4; run it: `Ran N tests ... OK`.
4. **`Makefile`**: `.PHONY` gains `test-godot-known-red`; new target under `test-godot`; `test-tools` gains the line `python3 tools/test_lint_suites.py`.
5. **R3 product fix** (`sketch_context_chrome.gd` `_on_distance_edit_gui_input`, after `SxUi.write_typed_text(line, next)` and before `accept_event()`):
```gdscript
			var typed: Variant = _parse_spin_text(_extrude_spin, next)
			if typed != null:
				_distance_line_invalid = false
				_distance_invalid_raw = ""
				_write_extrude_spin(float(typed), next)
```
   Also fix the test-facing setter in the same file (verified: it reduces `run_rung01_sketch_tests` to its two angle failures). Replace the body of `set_extrude_distance(v)` so it writes the spin and the LineEdit text together:
```gdscript
	_write_extrude_spin(v, "%s mm" % _plain_num(v))
```
   (the Extrude click parses the LineEdit text, so writing only `_extrude_spin.value` loses the value). An unparsable prefix leaves today's state. Suites that must stay green: `run_rung01_sx037_l10.gd`, `run_rung01_replan16_fields.gd`, `run_rung01_sx037_fields.gd`, `run_rung01_replan16_walk.gd`, `run_rung01_wrench.gd`. Expected newly green: `run_rung01_replan2_distance.gd`, `run_rung01_replan3_distance.gd`, `run_rung01_replan4_numeric.gd`, `run_rung01_replan13_typed.gd`; `run_rung01_sketch_tests.gd` is newly green except `angle 45° solves` and `solved angle is 45°` (R3b angle rows: read the test's hand-built sketch; product, stale or `known-red` with a `product:` reason naming the constraint set). `run_rung01_replan3_input.gd`'s two Distance rows depend on the polygon commit (R8, WP2 / WP3) and stay red until those merge.
6. **R1 / R2 films**: add to `tests/lib/film_ui.gd`
```gdscript
static func place_instance(ctx) -> void:
	await click_button(ctx, "Place")
```
   check that `click_button` finds the Modify panel's `Place` (not another button whose text begins with `Place`): if it does not, resolve the button with `ctx.main.ops_panel.find_children("*", "Button", true, false)` filtered on `text == "Place"` and click that. Replace every `click_button(ctx, "Place instance of selection")` in `tests/films/*.gd` (eight films: `fasten_bolt`, `crank_slider`, `snap_bolt_drop`, `drawing_bom`, `explode_gearbox`, `bolt_circle_pattern`, `intent_flush`, `config_drawing`; `grep -rn "Place instance of selection" game/tests`). Then the R2 rows (`precision_plate`, `sketch_edit_in_out`) per the table. A film that still errors after the click is fixed in its own script; `film_manifest_smoke` must end `0 failures` (about 4 minutes; run it alone, with `DISPLAY=:1`). The `SCRIPT ERROR` lines for `pliers_motion` (`instance_revolute_axis`) and `sketch_tools` (`animate_pointer_click` on Nil) are printed today with `ok - … finished`; they do not fail the smoke, and you leave them alone unless you touch those films.
7. **Stale tests** (R1b, R4, R4c, R5, R6, R9 and the R9 "mixed" row): one commit per suite, message names the suite and the PR that changed the behaviour. Keep each check's intent; change only the expectation or the way the test drives the UI (real input stays real: do not replace a click with `.emit`).
8. **R7**: `ops_panel.gd` (~429) give the hole-row `Move` button the icon name the other move buttons use (`grep -n '"move"' game/scripts/ops_panel.gd game/scripts/ui_icons.gd`); `run_icon_tests.gd` treats a button whose text is a plain number (`10`, `12`, `14`) as a value chip, not a cryptic label.
9. **Whatever is left red** → `known-red` with a `reason=` (Decision 1). Update `packaging/ci/suites.d/README.md` with the new tier / key (3 lines).
10. **`AGENTS.md`** per Decision 6.

## Acceptance (exact)

- `python3 tools/test_lint_suites.py` → `OK` (no failure; includes the new known-red cases).
- `python3 tools/lint_suites.py` → `lint_suites: <n> suites ok (<a> ci, <b> full[, <c> known-red])`, exit 0.
- `bash packaging/ci/run_suites.sh --tier known-red` → one `<script> — <reason>` line per known-red suite, `suites: <c> known-red`, exit 0; `--tier full --list` and `--tier ci --list` list no known-red script.
- `KEEP_GOING=1 make test-godot` → every suite green **except** the three owned by WP2 (R8), or fully green once WP2 is merged. Paste the final `suites: <n> run, <f> failed` and the list of failed names in the PR body, plus the table "suite → fixed / stale-fixed / known-red (reason)" for all 32.
- `run_rung01_wrench.gd`, `run_rung01_replan16_walk.gd`, `run_rung01_sx037_l10.gd`, `run_rung01_replan16_fields.gd` stay green; quick CI (linux kernel, godot-smoke, website-demos) green (the website-demos job validates the film manifest: if it names a film you edited, run `make check-website-demos` locally).
- No new status string anywhere; no change to `docs/plan/STATUS.md`.

## Also run

`run_film_manifest_smoke.gd`, every suite whose file you edited (alone), `make test-tools`, `make lint-rung01-e2e`.

## Rows unblocked

A15 (`make test-godot` green; `make test-godot-known-red` prints the reasons); WP6's final gate 4.
