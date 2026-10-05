# sx-027 critique: main @ 8478773d (replan-6 #87–#90), OCCT 8.0.1 local build

**Verdict: FAIL, 5/10.** Down from 6 (sx-026).

Provenance. The critic's own `LEFTOVERS-sx027.md`, `CRITIQUE.md` and `WALK_LOG.md` were attachments to the re-plan 7 brief and were not available in the planning VM. This file is rebuilt from (a) the symptom list in the brief, (b) the checker and headless outputs named in the brief (`check_nut.txt`, `check_wrench.txt`, `check_wrench_base.txt`, `check_thick.txt`, `headless_H.txt`, `headless_H2.txt`), and (c) measurements re-run on `8478773d` during planning. Rows marked "reproduced" were re-run; rows marked "reported" are taken from the brief and have not been re-run. If the verbatim critic text is available, paste it under the table and keep the Pri/Problem columns.

**Do not recritique this hash: 8478773d.** The next critique (sx-028) is a build that contains replan-7 WP4.

## Leftovers for re-plan 7 (P0 first)

| Pri | Problem | Evidence | Status in replan 7 |
|---|---|---|---|
| P0 | **Picking a face reopens Sketch 1** (or another existing sketch) instead of starting a sketch on the face. Clicking the top face of the blank, or pressing Sketch and then clicking the face, lands on a yellow pad that is behind or beside the solid. | Reproduced: `pick_pad` takes a hit on any pad bounding box with no solid depth test (`viewport_interaction.gd` `_on_release`, `_commit_pick_sketch_host`; `sketch_pad_overlay.gd` `pick_pad`). A press on an already-selected face arms push/pull and swallows the click. The walk hides it with a `select_entity` recovery in `_sketch_on_top`. | WP1 (fix), WP4 (walk stops hiding it) |
| P1 | **The blank and the wrench report `flipX=True` (MIRROR)** in `check_rung01.py`, on `wrench`, `blank` and `thick` files. | Reproduced as a checker artifact: a blank whose head is at +X prints `flipX=True flipY=False (MIRROR)` because the orientation is chosen by fewest failed rows and a hole-less blank fails the hole rows in all four. Camera right is +X (measured, 16 headless runs, head always at +X). | WP2 (checker decides the head end from the vertices; adds `blank` kind) |
| P1 | **Smart Dimension 200 between the Ø20 and the Ø45 moves both circles.** The pivot is no longer at (0, 0), so the hole, the Center Three Point jaw and the slot are off by about 1.2 mm; the jaw opens 18.4 instead of 20. | Reproduced: origin circle ends at (−1.157, 0), head at (198.84, 0); the rectangle width is 18.40; `jaw AF at z=2/5/8 is 18.400`. With unanchored circles in other orders the pair is re-centred by up to 105 mm. | WP2 (pin the circle centred on the sketch origin) |
| P1 | **`run_rung01_wrench.gd` does not run in the default shell**: `Parse Error: Cannot infer the type of "after_n" variable` at `res://tests/run_rung01_wrench.gd:850` and `:853`. | Reproduced: the real cause is `libsxcore.so` failing to load without `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` (`Could not find type "SxDocument"`). Lines 850/853 are the only two that need inference through `SxSketch`. | WP3 (typed ints, Makefile loader path, preflight) |
| P1 | **Headless walk is not the GUI walk**: 8 failures on the baseline (reproduced, 359 checks) and 17 in the reporter's run (354 checks: jaw AF 18.4, slot depth, fillet failures; reported, extras not reproduced). | Reproduced 8: `jaw sketch has Ø45 at the head`, `jaw width label exists`, `jaw width label is 20`, `jaw AF at z=2/5/8`, `check_rung01.py wrench … exit 1`, `jaw width dimension restored`. All trace to the pivot drift above. | WP2 clears the 8; WP4 removes the walk's recovery path |
| P2 | Dimension labels overlap and a centreline retry leaves the old line. | Reported in sx-026, closed by replan-6 WP1; no regression reported in sx-027. | none |
| P2 | Bare export name into a typed folder; Exit Sketch readable; Radius vs Extrude fields. | Closed by replan-6 WP2/WP3; no regression reported in sx-027. | none |

Checker outputs on the sx-027 GUI exports (reported): nut passes; wrench and thick fail rows that follow from the jaw/slot geometry above; `flipX=True` on the wrench, the base blank and the thick file.

Score: 5/10. The nut, export folder, chrome and the Trim/cut chain from replan 6 are not reported as regressions. Face pick, the pivot position after the centre-distance dimension, and the checker's orientation rule are open.

**Do not recritique this hash: 8478773d.**
