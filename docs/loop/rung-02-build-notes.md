# Rung 2 build notes

Measured while implementing `docs/loop/rung-02-plan.md`. Status texts are the `[status-trace] … kind=result text=…` lines a row will pin. WP1 has no UI, so there are no status texts.

## WP1 — checker and shared geometry

Red, before `tools/check_rung02.py` existed (`python3 tools/test_check_rung02.py`):

```
Traceback (most recent call last):
  File "/workspace/sx-build/src/tools/test_check_rung02.py", line 21, in <module>
    import check_rung02 as c
ModuleNotFoundError: No module named 'check_rung02'
```

`python3 tools/test_check_rung01.py` was green before the move to `tools/geom.py` (6 tests) and after it.

No status texts. Checker row names pinned by the unit tests: `bbox`, `watertight`, `corner R10`, `wall x`, `wall y`, `floor`, `open top`, `hole axis`, `hole Ø10`, `hole only in x walls`, `volume`, `usage`.

`python3 tools/lint_suites.py`: `lint_suites: 207 suites ok (59 ci, 144 full, 4 known-red)`. `test_check_rung01.py` 6 ok, `test_check_rung02.py` 19 ok. `make test-tools` then fails in `test_publish_demo_movies.py`: `ubc_wrench` is already in `website/assets/published-demos.json` (same list at `a79c809`). Not part of WP1.
