# Loop docs

What remains here is the live contract, not the per-round plans:

- `automation-bridge.md` — test-only localhost JSON bridge (`SX_AUTOMATION=1`)
- `linux-test-build.md` — rolling Linux GUI-test tarball
- `rung-01-replan-21.md` — 77-row checklist the walk implements
- `rung-02-plan.md` — rung 2 (the SolidWorks box): gap analysis, work packages, 44-row checklist, `check_rung02.py` spec
- `rung-03-plan.md` — rung 3 (SOLIDWORKS Lesson 1: Parts, video depth 30): measured gaps, work packages, 46-row checklist, `check_rung03.py` spec
- `rung-03-result.md` — confirm pass (`tools/confirm_all.sh` counts)
- `rung-04-plan.md` — rung 4 (Pano Central hex key, Swept Boss): measured gaps, work packages, 32-row checklist, `check_rung04.py` spec
- `rung-04-checklist.md` — 32 walk rows
- `walk_rung04.py` listed with the other walks
- `rung-05-plan.md` — rung 5 (UBC ELEC391 Exercise 3: pipe section): measured gaps, work packages, 36-row checklist, `check_rung05.py` spec
- `walk_rung05.py` listed with the other walks
- `rung-06-plan.md` — rung 6 (SolidWorks Revolve & Sweep candlestick): measured gaps, 16 work packages, 46-row checklist, `check_rung06.py` spec
- `rung-06-checklist.md` — 46 walk rows
- `walk_rung06.py` listed with the other walks
- `rung-07-plan.md` — rung 7 (Mahtabalam combination spanner): measured gaps, 10 work packages, 46-row checklist, `check_rung07.py` spec
- `rung-07-checklist.md` — 46 walk rows
- `rung-07-result.md` — confirm pass (`tools/confirm_all.sh` counts)
- `rung-07-failing.md` — handoff: checklist rows still red (none at `45e96e3`)
- `walk_rung07.py` listed with the other walks
- `post-rung-03-result.md` — confirm pass after the rung-3 layering pass (headless 214)
- `post-rung-04-result.md` — confirm pass after region pick, click budget, hexkey film
- `post-rung-05-result.md` — confirm pass after the flanged-pipe film (headless 229)
- `post-rung-06-result.md` — confirm pass after Part A + candlestick film
- `post-rung-07-cleanup.md` — layering pass after rung 7 (Part B combination-spanner film parked; the next cleanup deletes this file)
- `post-rung-07-result.md` — confirm pass after Part A (Part B parked; headless 244)

The walks are `tools/walk_rung01.py` (77 rows), `tools/walk_rung02.py` (44 rows, the Lesson 2 box), `tools/walk_rung03.py` (46 rows, Lesson 1 parts), `tools/walk_rung04.py` (32 rows, hex key), `tools/walk_rung05.py` (36 rows, pipe section), `tools/walk_rung06.py` (46 rows, candlestick), and `tools/walk_rung07.py` (46 rows, combination spanner). A walk is a `Rung` in `tools/walk/rung.py`: rows, chunks, checkpoints, checker, expectations. History of deleted per-round plans: `git log --diff-filter=D --name-only -- docs/loop`. `tools/gui_click_probe.sh` stays: it sends real X11 clicks, which the in-engine bridge does not; it is the dead-first-click probe from re-PLAN 17.
