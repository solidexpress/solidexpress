# Loop docs

What remains here is the live contract, not the per-round plans:

- `automation-bridge.md` — test-only localhost JSON bridge (`SX_AUTOMATION=1`)
- `linux-test-build.md` — rolling Linux GUI-test tarball
- `rung-01-plan.md` — original rung-1 intent
- `rung-01-replan-21.md` — 77-row checklist the walk implements
- `post-rung-01-cleanup.md` — organization pass after rung 1

The walk is `tools/walk_rung01.py`. History of deleted per-round plans: `git log --diff-filter=D --name-only -- docs/loop`. `tools/gui_click_probe.sh` stays: it sends real X11 clicks, which the in-engine bridge does not; it is the dead-first-click probe from re-PLAN 17.
