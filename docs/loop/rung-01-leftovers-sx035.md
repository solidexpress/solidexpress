# Leftovers after sx-035 (build `d408a8c7` / replan-14 WP1–WP8, then the spin-outs #163–#169)

Source: the sx-035 FULL GUI critique of linux-test-build `d408a8c7a592614d863a94c3e6c2bab4542ff567` (`SolidExpress-linux-test-latest-x86_64.tar.gz` → `SolidExpress-0.0.12-linux-x86_64`, sha256 `bccb500819c39690218e6ebfdaed01fc79f00d6b4cc1de2c3b2965456dc8cfb8`, OCCT 8.0.1, Godot 4.7-stable, soft GL via `launch.sh`, one GUI session in six chunks, walked 2026-10-06) and its `LEFTOVERS-BRIEF.md`. This file condenses both so a BUILD agent never needs the walker's box. Only the **ten leftovers** below are planned, in [`rung-01-replan-15.md`](rung-01-replan-15.md). Do not re-critique sha256 `bccb5008…`.

**Verdict: FAIL, ~6.5/10** (down from 8.5 at sx-034). Pass bar is score ≥ 9 and every row PASS. The geometry collapsed because **A9 Power Trim never produced `Trimmed open jaw`**; that knocked on to A9b, A11e, A12 and A13c.

## What was green (do not regress)

- A8 zero-width guard (`Jaw — width is zero — click 3 again…`, no commit); N5 sketch Undo / Redo (`Undo: Jaw`, `Redo: Jaw`, `Nothing to undo`); N7 Jaw lights Jaw (no chips), Rect has its own chips, Circle centre status prints; N8a timeline pencil → `Editing sketch`; N8b Open enables after one click, Discard → picker works.
- Slot Blind cut of Contour 2 succeeds once the chain-break line is deleted (`Extrude Blind 2.5000 mm`); A11d top / bottom face R1 apply first try; A11c remove-wrong-edge works; blank **5/5** (bbox `232.416 × 44.882 × 10.0`, head at +X).
- Headless: lint clean (`7 replan14 scripts are clean`), replan-14 walk 646 checks / 0 failures (STATUS). The critique box could not run the headless A15 (`SKIP`: OCCT 8.0.1 still compiling, `preflight_sxcore.gd` → libsxcore not loaded).

## Failed rows and where they went (do not re-plan)

| Row | Symptom | Fix | State at planning time (`main` = `d534765cf39b6418e889a72248b3d528775629ad`) |
|---|---|---|---|
| A9 | Power Trim: `no crossing` / jaw collapses into a diamond / cutter stub trimmed; never `Trimmed open jaw` | [#165](https://github.com/solidexpress/solidexpress/pull/165) | merged `81a6910` |
| N1a / N1b | ~150 px: only `20` + `45°` (missing `5`, `22.5`); after Save As `45°` on top of `20` | [#164](https://github.com/solidexpress/solidexpress/pull/164) | merged `73a2bfd` |
| A11a | typed `5` set Extrude 20→5 and kept Distance focused; `150` never reached Slot; field read `Radius r 150.0` | [#163](https://github.com/solidexpress/solidexpress/pull/163) | merged `18eb043` |
| N4 | Esc from a focused sketch field needed three presses | [#167](https://github.com/solidexpress/solidexpress/pull/167) | merged `1007303` |
| A11c | re-clicking a picked Fillet edge added a duplicate | [#166](https://github.com/solidexpress/solidexpress/pull/166) | merged `8c5be4c` |
| N6 | HUD Frame printed `Framed all` but a less-zoomed view than `F` | [#169](https://github.com/solidexpress/solidexpress/pull/169) | merged `f73c8e2` |
| L3 | type 10 + Tab: status `r=10.00`, strip `0.0 mm`; Tab landed on the `AF 10` chip | [#168](https://github.com/solidexpress/solidexpress/pull/168) | merged `d534765` (also: Tab / Enter return viewport keys; Fillet stays armed after arm so KEY_3 is Top) |
| A9b, A11e, A12, A13c / N9 | **knock-ons of A9** (open jaw never made) | none spun | re-verified by replan-15 WP3 |

## Checkers (`tools/check_rung01.py` @ `d408a8c7`)

| File | Source | Result |
|---|---|---|
| `out/blank.3mf` | GUI A5 | **5/5** |
| `out/wrench.3mf` | GUI A12 (renamed from the truncated `wrench.3`) | **13/22**, 2178 triangles. FAIL pivot hole open / diameter, jaw open / floor / AF at z=2,5, grip slot, R10 ±Y. PASS closed / bbox / orientation / jaw AF z=8 / boss / 1 mm outer + jaw fillets |
| `out/wrench-t14.3mf` | GUI A13 Distance 10 → 14 | thick **4/7** (PASS closed, bbox Z=14, 1 mm top + jaw top at new T; FAIL pivot / jaw through, grip slot from top) |
| DIAG on the T=14 file | `check_rung01.py wrench …` | `DIAG:` header present; **9/22**; far more than the four by-design failures |

**Reading the row count.** The wrench checker prints 22 rows when the grip slot is *not found* (`xs` empty in `wrench_tests`: the slot-floor / width / length / X-centre / floor-fillet / below-solid rows are never added) and 28 rows when it is. `sx-033` recorded the same (`Checker printed 22 rows … full handout with slot is still 28`). So "22 vs 28" is not a tooling regression: **a printed total of 22 is itself the failure signal "no slot"**, and 28/28 is the only passing total. The brief's "checker probe count tooling" item stays out of scope; the pass bar stays 28/28.

## Per-row summary (walk order)

PASS: A2/N7, A3, L5 (partial), A4, L6 (partial), A5 (note below), L8, L11 (menu), A7, A6, A8 (defect below), A8b, N8a, L12, A17, N5, A9c, A16, A11d, A13 / A13b, N8b. PARTIAL: A5b, L2, A11b (R10 refused at limit 1.993, applied R1.5, keys 3/4 ignored while armed), N2, N3, N4, N6, A15. FAIL: A9, N1a, N1b, A9b, A11a (first try), L3, A11e, A12, A13c / N9. Not scored: A1, L1, L10, A7b. SKIP (headless / CI): L7, A10, A10b, A14, L9.

## The ten leftovers

Severity: **B** blocks-pass, **U** usability, **C** cosmetic. Numbering is the brief's. Status strings are verbatim from the walk; screenshots lived under `/workspace/sx-035/gui/` (not available to BUILD agents).

### 1. A11e slot-floor R1 unpickable — A9-dependent (B)

After A9 failed the Contour 2 Slot cut left a pocket that looked fused with the neck. Every Fillet face click inside the slot outline selected the neck top loop (`175.4 line, 42.2 line, …`). A second face click → `No edge near click — …`. No slot-floor R1 applied. Evidence: walk-chunk5, `5-o.png` … `5-u.png`, `5-A11d-*.png`.

Expected on a real open jaw + Slot pocket: one face click on the slot floor fillets that face; Enter → `Fillet … edges 1.00 applied`; R1.5 still refuses with the floor-depth limit. **Re-verify, not a speculative rebuild of picking, unless it fails on a good body.**

### 2. Contours 1 / 2 toggles have no highlight (B, borderline)

After deleting the chain-break line the `Contours` chips `1` / `2` appeared. Contour 1 (jaw) Cut → open-shell refusal; Contour 2 (slot) → Blind 2.5 OK. The toggles give no visual indication which region is which; the walker guessed. Evidence: walk-chunk4, `4-del1.png`, `4-A11a-cut.png`, `4-A11a-cut2.png`.

Expected: arming Contour N highlights that closed region in the viewport (fill or outline); status names the contour (e.g. `Contour 2 of 2 — slot`); a wrong contour still refuses honestly, the highlight just makes the first try the right one.

### 3. Export 3MF filename truncates (`wrench.3`) (U)

File → Export 3MF with typed name `wrench.3mf` wrote `…/wrench.3`. Soft GL also dropped keys; the walker reports that even with `--delay` typing the product path truncated, and renamed the file on disk. Status `Exported 3MF → …/wrench.3`. Evidence: walk-chunk6, `6-a12-export.png`. Expected: the dialog accepts `wrench.3mf` and writes that path; the extension is preserved when typed or when the 3MF filter is picked.

### 4. Fillet success status says `applied`, not `Feature created` (U)

Actual: `Fillet 6 edges 1.00 applied — adjust parameters (Esc cancels, deselect keeps)`. The A11d pass text (historical) expects `Feature created`. Behaviour was fine; the wording drifted. Expected: pick one and make headless + GUI agree. Evidence: walk-chunk5 A11d, `5-A11d-top.png`, `5-A11d-bottom.png`.

### 5. View key `0` is a no-op (U)

Keys 3 / 4 / 6 / 8 change views; key `0` does nothing (no status, no camera change). Expected: document as unused, or map it; prefer a status if ignored, e.g. `No view for key 0`. Evidence: walk-chunk5 N2 note.

### 6. Jaw still armed: clicking a dimension label starts a new Jaw (U)

After `Jaw committed — … — click a label to edit it`, clicking the width label's first glyph with Jaw still armed printed `Jaw — centre set…` instead of opening the Dim editor; it worked only after switching to Select. Expected: with Jaw armed a click on a dim label opens the editor (same as Select), or Jaw switches to Select on commit; the status must match the behaviour. Evidence: walk-chunk1, `1-A8-labelclick-with-jaw-armed.webp`.

### 7. Finish-bar Extrude: mouse click no-op, Enter works (U)

A5: two mouse presses on the *focused* Extrude finish-bar button changed nothing; Enter extruded. May be soft GL; classify if it reproduces on a headless press path. Expected: a real left click on Extrude commits the Blind extrude and prints `Extrude Blind …`. Evidence: walk-chunk1 A5 note.

### 8. Chain-break / refuse status leaks a raw entity UUID (U)

Extrude refuse printed `line caf49d4e-7375-4211-a356-e024b28a988c at (187.5, 18.7) breaks the chain`. Expected e.g. `Line at (187.5, 18.7) breaks the chain — delete or trim it`. Evidence: walk-chunk3 A9b, `3-A9b-cut.png`.

### 9. N2 regression: view keys ignored while Fillet stays armed (B)

replan-14 WP2 (#158) was supposed to return focus after a strip commit so `3` changes the view with Fillet still armed. On `d408a8c7`: after strip Enter, `3` → `Top view` but **Fillet disarmed**; after re-arming, keys `3` / `4` did nothing while Fillet stayed armed. Expected: after Tab / Enter / spinner on the strip (or panel) Radius the viewport owns the keys; `3` / `4` / `8` print the view status and **Fillet remains armed**; the field keeps the committed value. Evidence: walk-chunk4 N2, `4-N2-strip.png`, `4-A11b-3b.png`, `4-A11b-4.png`.

### 10. Extrude success status reads `jaw_af = 10 (config 10)` (C)

After the A5 Extrude Blind 10 the status briefly / oddly read `jaw_af = 10 (config 10)` instead of `Extrude Blind 10.0000 mm` (export still worked). Expected: the user-facing Extrude success names the feature and depth only. Evidence: walk-chunk1 A5.

## Out of scope (stays out)

Soft GL / llvmpipe / dropped keys / screenshot lag; anything in the "failed rows" table above; the checker probe-count tooling (see the row-count note); nut / A10 / L7 (headless / CI this round); the snadrus fork.

## Walker protocol notes carried forward

Rules 1–40 (replan 10–14) stay. The critique added: the status line is trusted over a lagging screenshot (rules 8, 36); a key that did nothing *anywhere* is a dropped key (rule 1), a digit that appears in a field is a product failure (rule 39). New rules for sx-036 are in [`rung-01-replan-15.md`](rung-01-replan-15.md).
