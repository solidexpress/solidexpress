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
- `post-rung-03-result.md` — confirm pass after the rung-3 layering pass (headless 214)
- `post-rung-04-result.md` — confirm pass after region pick, click budget, hexkey film
- `post-rung-05-cleanup.md` — layering pass after rung 5 and the flanged-pipe demo film (the next cleanup deletes this file)
- `post-rung-05-result.md` — confirm pass after the flanged-pipe film (headless 229)

The walks are `tools/walk_rung01.py` (77 rows), `tools/walk_rung02.py` (44 rows, the Lesson 2 box), `tools/walk_rung03.py` (46 rows, Lesson 1 parts), `tools/walk_rung04.py` (32 rows, hex key), and `tools/walk_rung05.py` (36 rows, pipe section). A walk is a `Rung` in `tools/walk/rung.py`: rows, chunks, checkpoints, checker, expectations. History of deleted per-round plans: `git log --diff-filter=D --name-only -- docs/loop`. `tools/gui_click_probe.sh` stays: it sends real X11 clicks, which the in-engine bridge does not; it is the dead-first-click probe from re-PLAN 17.
