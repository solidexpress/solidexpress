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

## WP2 — face sketches upright (`PlaneBasis`)

Red, before `PlaneBasis` (`tests/run_rung02_plane_basis.gd`). ±Z already matched the pinned basis. Side faces were the old `n × Z` frame (sketch +Y = world −Z):

```
  +X plane x=(0.0, -1.0, 0.0) y=(0.0, 0.0, -1.0) origin=(100.0, 0.0, 0.0)
  FAIL - +X basis x=(0.0, -1.0, 0.0) y=(0.0, 0.0, -1.0) (want (0.0, 1.0, 0.0) (0.0, 0.0, 1.0))
  FAIL - +X SketchMode axes match the sketch plane
  +X click recorded (-19.99999, -30.0) (want (20.0, 30.0))
  FAIL - +X click records (20.0, 30.0) (got (-19.99999, -30.0))
  -X plane x=(0.0, 1.0, 0.0) y=(0.0, 0.0, -1.0) origin=(0.0, 0.0, 0.0)
  FAIL - -X basis x=(0.0, 1.0, 0.0) y=(0.0, 0.0, -1.0) (want (0.0, -1.0, 0.0) (0.0, 0.0, 1.0))
  FAIL - -X click records (-20.0, 30.0) (got (20.0, -30.0))
  +Y plane x=(1.0, 0.0, 0.0) y=(0.0, 0.0, -1.0) origin=(0.0, 60.0, 0.0)
  FAIL - +Y basis x=(1.0, 0.0, 0.0) y=(0.0, 0.0, -1.0) (want (-1.0, 0.0, 0.0) (0.0, 0.0, 1.0))
  FAIL - +Y click records (-20.0, 30.0) (got (20.0, -30.0))
  -Y plane x=(-1.0, 0.0, 0.0) y=(0.0, 0.0, -1.0) origin=(0.0, 0.0, 0.0)
  FAIL - -Y basis x=(-1.0, 0.0, 0.0) y=(0.0, 0.0, -1.0) (want (1.0, 0.0, 0.0) (0.0, 0.0, 1.0))
  FAIL - -Y click records (20.0, 30.0) (got (-20.0, -30.0))
70 checks, 12 failures
```

±Z pinned from that same run (unchanged by the fix): `+Z` x=(1,0,0) y=(0,1,0); `-Z` x=(1,0,0) y=(0,-1,0). Click on world `(100, 20, 30)` in the +X sketch records `(20, 30)`.

Status texts measured on this build (existing sentences, not new chrome):

- `Extrude Blind 50.0000 mm`
- `Right view` `Left view` `Back view` `Front view` `Top view` `Bottom view`
- `Sketch on face (plane +X @ origin 100.0,0.0,0.0)`
- `Sketch on face (plane -X @ origin 0.0,0.0,0.0)`
- `Sketch on face (plane +Y @ origin 0.0,60.0,0.0)`
- `Sketch on face (plane -Y @ origin 0.0,0.0,0.0)`
- `Sketch on face (plane +Z @ origin 0.0,0.0,50.0)`
- `Sketch on face (plane -Z @ origin 0.0,0.0,0.0)`
- `Sketch: Select · Line · Rect · Circle · Exit Sketch · Esc discard`
- `First point dropped — Esc again exits the sketch`
- `Sketch cancelled`

`run_rung02_plane_basis.gd` 70 checks, 0 failures. `run_rung01_replan7_facepick.gd` 31 checks, 0 failures. `run_extrude_frame_tests.gd` 20 checks, 0 failures. `python3 tools/lint_suites.py`: `lint_suites: 208 suites ok (60 ci, 144 full, 4 known-red)`.

## WP3 — references survive a resize (`TopoCue`)

Red, before `TopoCue` (`sxkernel_tests "fillet and shell survive a rectangle resize"`). Shell on the filleted box built. After the width edit, one fillet edge was soft-skipped and the shell face id was gone:

```
[DEBUG] fillet soft-skip: missing edge uuid 8f04176c-dd15-40c9-9bff-f70105fec4a6
[WARN] fillet: fillet soft-skip: 1 edges lost on rebuild
[ERROR] regenerate stopped at feature shell
FAILED:
  REQUIRE( ok )
with expansion:
  false
with messages:
  shell: missing face uuid 49dd10da-60a3-48a4-b993-d0534cc8fb69
test cases: 1 | 1 failed
assertions: 9 | 8 passed | 1 failed
```

No UI status texts. Kernel log wording when a stored cue does not resolve (fillet stays a warning; shell fails the regen through `ctx.fail`, which prefixes the feature name):

- `fillet soft-skip: missing edge uuid <id>; lost edge cue point (x, y, z) dir (dx, dy, dz)`
- `fillet <name>: fillet soft-skip: N edges lost on rebuild` (unchanged warning)
- `lost face cue point (x, y, z) dir (dx, dy, dz)` (shell error, after the feature name)

Shell on this filleted body succeeds (`MakeThickSolidByJoin` did not need a join change). `65 → 60 → 65` keeps fillet and shell: volume `no_hole(60) = 94173.7` and `no_hole(65) = 98923.7` within 0.5 %, walls 5.0 ± 0.1. `sxkernel_tests` 347 cases, 8325 assertions, all passed. `python3 tools/lint_suites.py`: `lint_suites: 208 suites ok (60 ci, 144 full, 4 known-red)`.

## WP4 — Shell reachable and faithful

Red, before the chip (`tests/run_rung02_shell_chip.gd`). The box and the four Z-edge fillets were already in place; `strip:shell` was not:

```
  ok   - Shell chip absent with nothing selected
  ok   - +Z face selected
  FAIL - strip:shell is visible on the top face
16 checks, 1 failures
```

Catch2 `shell a filleted box opens the top` was green on the existing `MakeThickSolidByJoin` (11 assertions). `apply_shell` was not changed; the join was not switched to `GeomAbs_Arc`.

Status texts measured on this build (`[status-trace] … kind=result`):

- `Shell thickness 30.0000 mm is at least half the 50.0000 mm extent (limit) — nothing added`
- `Shell 5.0000 mm applied`
- `Shell needs a planar face — nothing added`

Timeline name: `Shell 5.0000 mm`. Thickness field id `finish:Thickness` (default `5`), OK id `finish:Ok`, chip id `strip:shell`. Chip rect at 1280×800: `[P: (833.0, 83.0), S: (46.0, 31.0)]`. Shelled filleted box volume `94173.6752` (`no_hole(60)` within 0.5 %). Double-click of the timeline row opens `Param_thickness` at `5.0000`.

`run_rung02_shell_chip.gd` 38 checks, 0 failures. `run_ui_tests.gd` 275 checks, 0 failures. `run_workflow_tests.gd` 82 checks, 0 failures. `python3 tools/lint_suites.py`: `lint_suites: 209 suites ok (61 ci, 144 full, 4 known-red)`.
