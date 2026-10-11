# Loop docs

What remains here is the live contract, not the per-round plans:

- `automation-bridge.md` — test-only localhost JSON bridge (`SX_AUTOMATION=1`)
- `linux-test-build.md` — rolling Linux GUI-test tarball
- `rung-01-plan.md` — original rung-1 intent
- `rung-01-replan-21.md` — 77-row checklist the walk implements
- `rung-02-plan.md` — rung 2 (the SolidWorks box): gap analysis, work packages, 44-row checklist, `check_rung02.py` spec
- `post-rung-01-cleanup.md` — organization pass after rung 1 (executed; WP2 of the next plan deletes it)
- `post-rung-02-cleanup.md` — layering pass after rung 2 and the Lesson 2 box demo film (planned)

The walks are `tools/walk_rung01.py` (77 rows) and `tools/walk_rung02.py` (44 rows, the Lesson 2 box). A walk is a `Rung` in `tools/walk/rung.py`: rows, chunks, checkpoints, checker, expectations. History of deleted per-round plans: `git log --diff-filter=D --name-only -- docs/loop`. `tools/gui_click_probe.sh` stays: it sends real X11 clicks, which the in-engine bridge does not; it is the dead-first-click probe from re-PLAN 17.
