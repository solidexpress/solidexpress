# Leftovers after sx-033 (main 0573dea2 / replan-12 WP1–WP7)

Source: `/workspace/sx-033/CRITIQUE.md` on the parent box (attached to the replan-13 task). **FAIL 7.5–8/10.** The critique is reproduced verbatim below so a BUILD agent never needs the parent box. Only the section **Leftovers (for re-PLAN 13)** is planned in [`rung-01-replan-13.md`](rung-01-replan-13.md); the four spin-outs (#134, #135, #136, bc-1e0b30a3) are in flight and are only verified.

---
# sx-033 critique — main `0573dea2` (replan-12 WP1–WP7, #125–#133)

**Build:** `SolidExpress-0573dea-occt8.0.1-linux-x86_64.tar.gz`
**sha256:** `c2159210cf8d302f004b1190e201dcdc8706dc22a68dd4cc4a68536706ee611f`
Built from origin/main `0573dea2321ffd1fd5b7e2bd3c9b5486c5e83a59` (BUILD.md). GUI walk used that tip.

**Verdict: FAIL, 7.5–8/10** (not a rung pass).

Replan 12 fixed most of what sx-032 failed in the real GUI:
- A6 Esc is exactly two presses; Circle press status is correct (WP4).
- A8 width/angle labels open on the **first** glyph click; values take (WP2).
- A9 pivot hole lands at the origin next to the rail (WP3); Power Trim opens the jaw with the along-jaw line left in.
- A9c Save As keeps the sketch open; Extrude after Save As still works.
- A11b first-try neck fillet from Top corners + Back miss keeps the set; status is `Fillet 2 edges 10.00 applied …` (WP6).
- A11c toggle-remove prints `— removed 179.8 mm line`.
- A11d top and bottom face R1 apply; sharp-neck refusal then one Esc → `Edge pick cancelled`.
- A13 / A13b timeline Distance Esc cancels and empty click keeps 14 (WP5).
- A13c thick `1mm top fillet at new T` PASSES (WP1/WP7); DIAG 18/22 with the four expected z=10 probes.
- A14 nut **7/7** first try, flats horizontal.
- Headless walk **456/0**, lint 7 replan12 clean, all seven replan12 suites 0 failures.

It still fails the pass rule. **Slot never arms** (A11a), so the grip slot and A11e are impossible and wrench/thick cannot hit their slot rows. Several spun-out defects remain (chip row over the rail, Jaw silent click-2 path, bottom-face `Moved body`). Score is below ≥9 and the handout is not hand-makeable with Slot broken.

Top failures, in plain words:
1. **Slot is dead.** Rail Slot press clears other chips but never highlights, never shows a Slot hint, and never draws a stadium preview. Typing 5 Enter goes to Smart-Dim distance; a canvas drag draws a plain line. A11a FAIL → A11e NOT REACHED → wrench 21/22 and thick 5/6 without a slot.
2. **Constraint chip row covers the rail** when two circles are selected (A1). Starts at x≈12, hides Arc/Point, runs off the right edge.
3. **Jaw gives no per-click feedback.** Click 1/2 keep the armed hint and an axis-aligned box preview; a repeated click 2 is silently consumed as a zero-width click 3. Retry with three deliberate clicks does commit; labels then edit on one click.
4. **Plain bottom-face click can `Moved body`.** First try after Top R1: key 8, body select, one click on the bottom face, then a separate pointer move → body dragged. Did not reproduce when the pointer was held still after the click (likely missed button-up or zero dead-zone).

## Checkers (repo `tools/check_rung01.py` @ 0573dea2)

| File | Source | Result |
|---|---|---|
| `out/blank.3mf` | GUI A5 | **5/5**, head at +X, head centre y 0.000 |
| `out/wrench-noslot.3mf` | GUI A12 (no slot) | **21/22**. Only FAIL: `grip slot present at y=0,z=8.75`. All fillet rows PASS (R10 ±Y, not oversized, 1mm top/bottom/jaw). 4240 tris, `flipX=False flipY=False`. Checker printed 22 rows (slot-length / slot-floor rows absent without a slot; full handout with slot is still 28) |
| `out/wrench-t14-noslot.3mf` | GUI A13c, timeline 10→14 | thick **5/6** — only FAIL `grip slot open from the top` (expected). `1mm top fillet at new T` **PASS** |
| DIAG same file | `check_rung01.py wrench wrench-t14-noslot.3mf` | **18/22**: FAIL bbox Z 14 vs 10, grip slot, `1mm fillet top outer edge`, `1mm fillet on jaw top edge` (z≈10 probes). Bottom R1 and R10 rows PASS. Same pattern as headless A13c expectation minus the missing slot |
| `out/nut.3mf` | GUI A14, first try, pointer off-axis | **7/7**, `Polygon AF 20.0000 — flats horizontal` |
| headless | `run_rung01_wrench.gd` @ 0573dea2 | **456/0** (BUILD.md). nut 7/7, wrench 28/28, thick 6/6, blank 5/5 inside the suites |

## Headless H + lint

- `python3 tools/lint_rung01_e2e.py` → `4 replan10` + `11 replan11` + `7 replan12` scripts clean.
- `run_rung01_wrench.gd` → **456 checks / 0 failures**.
- Replan12 suites: fillet 19/0, labels 20/0, rail 17/0, dialog 3/0, status 9/0, panel 12/0, pick 27/0.
- Kernel: `7943 assertions in 333 test cases` (+ sxvoice 8/1).

Honesty gaps that remain:
- The walk arms Slot and cuts the grip slot; the GUI cannot, so A11a/A11e/wrench-with-slot were never exercised in soft-GL.
- The walk never hits the silent Jaw click-2 / zero-width click-3 path the GUI walker hit.
- The walk never clicks a bottom face then moves the pointer (the `Moved body` trap).

## Per-checklist (replan-12 §sx-033)

| Row | Result | Notes |
|---|---|---|
| A1 | **FAIL** *(spin-out bc-6000dc1d → PR #134)* | All 18 rail labels present. With 2 circles selected the constraint chip row starts at x≈12, covers Arc/Point, runs off the right edge |
| A2 | PASS | Jaw then Rect status/chips as specified |
| A3 | PASS | `Dimension updated` 200; head y 0.000 |
| A4 | PASS | `Shaft lines: 2 added` |
| A5 | PASS | blank **5/5** |
| A5b | PASS | Discard Cancel kept blank; Save As pre-filled `untitled.sxp`; saved `blank.sxp` |
| A7 | PASS | `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)` |
| A6 | PASS | Circle press status; Esc ×2 → drop then `Sketch cancelled` |
| A7b | PASS | Face sketch reopened in one click |
| A8 | **FAIL first try** / PASS careful retry *(spin-out bc-00c1a817 → PR #135)* | No per-click status/preview; silent zero-width click 3 on repeat. Retry three clicks → committed; width/angle one-click glyph edit → 20 and 45° |
| A8b | PASS | Esc ladder; Select status; sketch kept |
| A9 | PASS | Origin click landed first try (~31 px right of rail); Trim `Trimmed open jaw` then already-open |
| A17 | PASS | Line/Centerline chips clear; Contours on multi-region; Centerline commit status |
| A9c | PASS | Save As `pre-cut.sxp` kept finish bar + profile; Extrude still worked |
| A9b | PASS | Cut Up To Surface → closed jaw |
| A16 | PASS | View menu Back/Left/Bottom; keys 4/6/8; orbit off Top |
| A11a | **FAIL** *(spin-out bc-abcb9539 → PR #136)* | Slot never arms (press clears chips / no Slot tool). Diagnostics: no highlight, no stadium, typed 5 → Smart-Dim distance, drag → plain line |
| A11b | PASS (first try) | Top corners → two 10.0 mm verticals; Back wall → `No edge near click…`; empty → `Missed the solid…` keeps set; Enter → `Fillet 2 edges 10.00 applied — View ▸ Timeline…` |
| A11c | PASS | Add 179.8 mm line then remove → `— removed 179.8 mm line`; Enter applies |
| A11d | PASS (after resume) *(bottom first-try → spin-out bc-1e0b30a3, no PR yet)* | Sharp-neck refusal + Esc cancel PASS. Top R1 11 edges PASS. Bottom first try `Moved body`; retry with pointer held still → bottom R1 11 edges PASS |
| A11e | **NOT REACHED** | No slot (parent-approved skip); blocked by A11a |
| A12 | **FAIL 21/22** (expected without slot) | All non-slot rows PASS including fillets; only grip-slot FAIL |
| A13 | PASS | Distance pre-selected; 10→14; no `lost on rebuild` |
| A13b | PASS | Esc → cancelled back to 10; retype 14 + empty click keeps 14 |
| A13c | PASS except expected slot row | thick **5/6** (`1mm top fillet at new T` PASS; grip slot FAIL). DIAG 18/22 as expected for T=14 z=10 probes + missing slot |
| A10 | PASS | Exact 81% cut refusal |
| A10b | PASS ×2 | New / Blind / no Face box / Extrude enabled |
| A14 | PASS | nut **7/7** first try, flats horizontal |
| A15 | PASS | lint 7 replan12 clean; walk **456/0** |

Walk failures for the pass rule: **A1 (chip row), A8 (Jaw feedback first try), A11a (Slot dead), A11e (not reached), A12 21/22, thick 5/6**. Not 0, and Slot blocks a hand-makeable wrench, so FAIL whatever the other totals.

## Spin-out agents

| Agent | Issue | PR | Head sha | Draft? | CI (as of ~11:32 CDT) | Agent |
|---|---|---|---|---|---|---|
| bc-6000dc1d | A1 chip row covers rail | [#134](https://github.com/solidexpress/solidexpress/pull/134) | `b5f17d72` | yes | website-demos ✅, kernel ✅, godot-smoke ⏳, macos-kernel ⏳ | PR open; no further commits since 11:27 CDT — treat as waiting on CI (not actively pushing) |
| bc-00c1a817 | A8 Jaw no per-click feedback / box preview / silent zero-width click3 | [#135](https://github.com/solidexpress/solidexpress/pull/135) | `ee7ab50f` | yes | website-demos ✅, kernel ✅, godot-smoke ✅, macos-kernel ⏳ | PR open since ~11:10 CDT; likely done waiting on macos-kernel |
| bc-abcb9539 | A11a Slot never arms | [#136](https://github.com/solidexpress/solidexpress/pull/136) | `aad234f3` | yes | website-demos ✅, kernel ✅, godot-smoke ⏳, macos-kernel ⏳ | PR opened ~11:28 CDT; body still says it will report quick CI — may still be RUNNING or finishing |
| bc-1e0b30a3 | plain bottom-face click → `Moved body` | **no PR** | — | — | — | No branch/PR found matching this agent id; did not reproduce when pointer held still after click |

Do not merge from this critique. Parent decides merge order (agents note #136 will rebase if #134/#135 land first — they each add a replan12 test).

## Verified without a slot

Parent-approved noslot continuation after A11a FAIL:

- **A11d1** sharp-neck refusal + Esc `Edge pick cancelled`
- **A11b** first-try Top corners + Back miss + Enter apply
- **A11c** toggle-remove with length in status
- **A11d2** top + bottom face R1 (after resume; bottom careful click)
- **A12** 21/22 (slot row only fail)
- **A13 / A13b / A13c** thick 5/6 with `1mm top fillet at new T` PASS; DIAG 18/22
- **A10 / A10b** 81% refusal; finish bar New/Blind
- **A14** nut 7/7
- **A15** headless 456/0 + lint

Not verified: A11a slot cut, A11e slot-floor R1, wrench 28/28, thick 6/6 with grip slot open.

## Soft-GL / walker notes

- Save As name: Ctrl+A sometimes dropped; typed name appended (A5b `blank.sxp` try 1 → `p`; A12 `wrench-fillets-noslot.sxp` first Ctrl+A dropped). Read-back + retry caught them.
- Extrude status lagged ~3 s once (not a lost click).
- First pointer move after a click often dropped by the desktop (rule 12); second move worked.
- Screenshots sometimes lagged one action; status line trusted (rule 8).
- Jaw first-try failure was product UX (silent click 2), not soft-GL.

## Leftovers (for re-PLAN 13) — NOT already covered by a spin-out

| # | Leftover |
|---|---|
| 1 | Stale status when arming Line / Smart Dim / Trim / Slot (related to Slot agent but broader — press works, status stays on previous tool) |
| 2 | Finish bar keeps previous sketch's Op/End/distance when opening a new sketch (Slot PR #136 claims a Blind/New reset for new sketches — confirm after merge; still list until verified) |
| 3 | Fillet Radius in context bar disagrees with the panel (bar shows 1.0 / 0.0 while panel has 10; panel value wins on apply) |
| 4 | After Trim, jaw labels pile up and drift (`20.0005` / `45.0007°`); measured wall ≈45.4° after setting 45 |
| 5 | F frames only the Ø20 after the 200 dim (Ø45 left off-screen) |
| 6 | Red/orange X and H markers after Shaft Lines; circles look squashed when zoomed out |
| 7 | Discard dialog after a refused fillet that didn't change the model |
| 8 | Save As: Ctrl+A sometimes dropped; typed name appends |
| 9 | Polygon preview stops following after an off-axis move until AF is typed |
| 10 | Extrude distance field briefly flashes the old value after typing |
| 11 | View HUD menu drawn semi-transparent over buttons |
| 12 | Stuck measure overlay during jaw-sketch circle work |
| 13 | Wrench checker on T=14 still probes top fillets at z≈10 (thick checker's `1mm top fillet at new T` passes) — clarify whether the DIAG checker should follow T |

## Pass criteria check

| Criterion | Result |
|---|---|
| blank 5/5 | **yes** |
| nut 7/7 | **yes** |
| wrench 28/28 | **NO** (21/22 without slot) |
| thick 6/6 | **NO** (5/6 without slot) |
| walk 0 failures (GUI) | **NO** (A1, A8 first try, A11a, A11e) |
| hand-makeable with Slot broken | **NO** |
| score ≥ 9 | **NO** (7.5–8) |

## Score rationale

- **+:** A6, A9 rail origin, A9c Save As, A11b/A11c first try, A11d face R1 + T=14 fillet survival, A13/A13b panel dismiss, A14 first try, blank 5/5, headless 456/0. Most checklist rows pass in the real GUI once Slot is skipped.
- **−:** Slot dead blocks A11a/A11e and wrench/thick slot rows. A1 chip-row FAIL. A8 Jaw silent path. Bottom-face move trap. Leftover polish (stale status, finish-bar carry, fillet bar mismatch, label drift, F framing, Discard after refused fillet, …).
- **Net 7.5–8/10.** Below the pass bar (≥9 and walk 0 failures and hand-makeable wrench).

## Next step

Wait for the four spin-out PRs to merge (#134, #135, #136, and a PR from bc-1e0b30a3 if/when it opens) — quick CI checks only — then **re-PLAN 13 for leftovers only**, **OR** parent launches re-PLAN 13 now for leftovers while spin-outs finish. Parent will decide.

## windows-nightly on main (watchdog note)

Watchdog wrongly thought #130 might not have merged. Confirmed:
- PR **#130** MERGED as `e6a14b3a` ("ci: run Windows export daily when main changes"), ancestor of main tip `0573dea2`.
- `.github/workflows/windows-nightly.yml` is on main (`gh api …/actions/workflows/windows-nightly.yml` → state `active`; present in the `0573dea2:.github/workflows` tree alongside `ci.yml` and `release.yml`).
