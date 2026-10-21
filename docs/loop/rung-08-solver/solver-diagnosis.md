# Walk 7 A18/A23: diagnosis of "Relation did not stick"

Branch `cursor/rung-08-20261019` @ `8a35347`, worktree `/workspace/sx-086/wt`. Investigation only: nothing was committed, pushed or launched.

## Verdict: (c) a real conflict, not a solver limit

The rejected relation is the lower strip's end on the ellipse. It conflicts with the Symmetric relations that **Mirror (A17)** adds. Constraint load and DogLeg are not the cause.

- The C head is an ellipse (semi-axes 25 and 27.5) rotated 17°, so it is **not symmetric about the centreline**.
  - It crosses y=+10 at x = **22.944**.
  - It crosses y=−10 at x = **23.929**.
  - `ui07.handle_xy` already encodes these two values.
- `sketch_tools.cpp:1151` `mirror_entities` (Line case) adds `Symmetric(start_up, start_lo, CL)` and `Symmetric(end_up, end_lo, CL)`. That forces x_lo = x_up.
- In A18, the upper end goes on the ellipse first. That fixes x_up = 22.944 and leaves the sketch at 0 DOF. The lower ring coincident is then **redundant**, because the circle is symmetric. The lower point-on-ellipse needs x_lo = 23.929 but has to equal 22.944, so it is **inconsistent by 0.985 mm**. No algorithm can satisfy it.
- The leftover 0.985 mm is the reported defect. The lower strip ends at (22.944, −10), about 1 mm *inside* the C. OCCT then cuts the islands.

For one strip on its own, the numbers check out. The upper strip has 4 unknowns and 4 equations (Horizontal, dim 10, on-circle, on-ellipse). The point-on-ellipse only **fixes the strip's length**. It does not fight dim 10 or Horizontal. That is why `rung07_coincident` (one strip, no mirror) passes.

### Evidence: the real vendored PlaneGCS, same calls as `solver_planegcs.cpp`

Files: `repro_planegcs.cpp` (built from `wt/thirdparty/planegcs` and the shim) and `repro_spanner_handle.py` (an independent SVD rank check in scipy). The model has 8 unknowns: the two strips' endpoints. The ellipse, CL and ring are held fixed, as the earlier dims fix them.

| step | status | DOF | conflicting tags | redundant |
|---|---|---|---|---|
| A16+A17: H, dim10, mirror (2× Symmetric) | Success | 2 | – | – |
| + ring coincident (upper) | Success | 1 | – | – |
| + upper point-on-ellipse | Success | **0** | – | – |
| + ring coincident (lower) | Converged | 0 | – | **7** (ring_lo) |
| + **lower point-on-ellipse** | **Failed** | **−1** | **4 (Symmetric start), 6 (ell_up), 8 (ell_lo)** | 7 |

- In the scipy check, the Jacobian rank stays at 8 with 10 equations, and the least-squares residual is 5.1e-2, not 0. The system is inconsistent, not just rank-deficient.
- PlaneGCS already names the exact conflict triangle {Symmetric(start), ell_up, ell_lo}. `solve()` puts it in `result.conflicting`. The GDScript then throws it away and emits only "Relation did not stick" (`sketch_mode.gd:3380-3390`, which removes the cid and re-solves).

### Cheap solver experiments (all on the conflicting case)

- **Levenberg–Marquardt:** Failed, same conflict set.
- **DogLeg seeded on the curve** (P3 pre-projected to x = 23.929): Failed. The Symmetric relation pulls it back.
- **BFGS:** returns `Converged` (1) with a nonzero residual. **This is dangerous.** The wrapper treats `Converged` as success (`solver_planegcs.cpp:689`), so a BFGS fallback would "stick" a violated constraint with the strips about 0.5 mm off both hits. **Do not add a blind BFGS fallback.**
- **Solving only the affected subgraph:** this changes nothing. The conflict lives inside the subgraph.
- **Curve parameter as an extra unknown:** this changes nothing for consistency. PlaneGCS's implicit point-on-ellipse is a correct single equation; a parametric form (`addConstraintPointOnEllipse` vs. a curve-param/`ArcOfEllipse` start) has the same rank. It would only help the arc-range or branch selection (the "jumped to a jaw vertex" problem in attempt 3), not this case.
- **No mirror** (each strip gets its own Horizontal + dim 10, both on the ellipse): DOF 0, Success with DL and LM. One caveat from this run: the lower point landed at y=+10, because P2L distance is unsigned and the seed was poor. Use a signed or vertical distance, or seed at y=−10.

Summary of the experiments: the solver is fine, and the over-constraint comes from the walk.

### Other solver-code facts

- `solve()` uses DogLeg only. Diagnosis is planegcs `diagnose()`: a QR-rank Jacobian giving DOF, conflicting and redundant constraints, with the planegcs default QR threshold.
- On failure, the code auto-drops only constraints flagged `weak` that are also in the conflicting set (lines 709-723). Neither Symmetric nor Coincident is weak, so nothing yields.
- Point-on-curve on an elliptical arc uses the full ellipse (`ellipses[...]`, line 309). There is no arc-range term.
- `trim_line` (`sketch_tools.cpp:397`) moves the endpoint to the intersection. It does **not** add a point-on-curve relation and does **not** drop the endpoint's Symmetric or Coincident, so the next solve can drag the trimmed end back.

## Is the walk modelling the tutorial differently? Yes

Frames t0270–t0300 (`docs/loop/rung-07-frames`) show the tutorial's order:

1. Draw the upper strip long, running *into* the C.
2. Horizontal and dim 10.
3. Mirror Entities.
4. Coincident the ring ends at (226.88, ±10.02), shown in t0285 and t0292 with "Coincident46 / Symmetric3".
5. **Trim** the overflow inside the C (t0297, "trim okay").

In t0300 the sketch is **Under Defined**, and the two left ends visibly sit at different x on the rotated ellipse. The tutorial never puts a coincident on the lower end. The trim produces that end at the ellipse intersection, and SolidWorks drops the symmetric relation on the trimmed end.

The walk does two things differently:

- It draws the upper strip already ending at 22.944, so the mirror copy ends at 22.944 too, 1 mm short of the real hit inside the C.
- In A18 it then asks for point-on-ellipse on **both** ends while Symmetric still binds them.

## How other products handle this

- **FreeCAD / PlaneGCS** (the solver we use):
  - It builds the Jacobian, takes its QR rank to get DOF, and runs a "popularity contest" heuristic that splits redundant from conflicting constraints.
  - It solves with DogLeg, then falls back to LM or BFGS.
  - The UI lists the conflicting constraints by index and keeps the sketch unsolved.
  - Sources: https://quaoar.su/files/papers/gcs/fc-solver-latex.pdf , https://devtalk.freecad.org/t/implement-a-new-algorithm-in-sketch-solver/6310 , https://github.com/FreeCAD/FreeCAD/blob/main/src/Mod/Sketcher/App/planegcs/GCS.cpp
  - The devtalk thread notes that the typical fix is "substituting a symmetry constraint with a horizontal alignment", which is exactly our case.
- **SolidWorks (D-Cubed DCM):**
  - It separates over-defined (redundant: a sketch that is still consistent but has a duplicate driving dim, which goes red) from Not Solved (inconsistent).
  - Display/Delete Relations filters "Over Defining/Not Solved". SketchXpert proposes sets of relations to delete or make driven.
  - Trim removes relations on the cut end.
  - Sources: https://help.solidworks.com/2017/english/solidworks/sldworks/hidd_dve_sk_edit_relations.htm , https://my.solidworks.com/reader/onlinehelp/2021%252Fenglish%252Fsolidworks%252Fsldworks%252Fc_faq_sketch_relations.htm/faq-sketch-relations
- **Onshape (DCM):**
  - An over-defining constraint turns red. A dimension that would over-define can be kept as driven (grey, Esc) and toggled to driving later.
  - Source: https://forum.onshape.com/discussion/18785/create-circle-with-different-centre-points
- **Fusion:**
  - It refuses at insertion time ("This dimension would over-constrain the sketch") and offers the dimension as driven. It shows constraints filtered by selection.
  - Sources: https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/Over-constrained-sketch-warning-in-Fusion-360.html , https://forums.autodesk.com/t5/fusion-design-validate-document/viewing-conflicting-constraints/td-p/6476854
- Point-on-curve: in DCM and PlaneGCS this is an implicit or curve-parameter relation. Arc *range* is a separate concern; in planegcs it is handled through arc endpoints.

## Recommended fix path

1. **Walk fix (S, about 1–2 h; this unblocks A23/A26).** Model the tutorial:
   - Draw the upper strip from about (18, 10), inside the C, to the ring chord. Do the Horizontal, dim 10 and Mirror as now.
   - Ring coincidents stay. The lower one is redundant but harmless; it is reported redundant, not conflicting.
   - Replace the two A18 point-on-ellipse picks with **Trim at (18, ±10)** on the strip overflow, which needs step 2. Or apply point-on-ellipse to the **upper end only**, and delete the lower start Symmetric before putting the lower end on the ellipse.
   - Expected result: lower end at 23.929, C area 1496, volume about 41693, as `run_rung07_boss` already shows.
2. **Product: trim keeps the end on the cutter (M, about 0.5–1 day).**
   - In `trim_line`, when an end moves to an intersection with curve K, remove that endpoint's Symmetric, Coincident and point-on-curve relations, then add `Coincident(point, K)`.
   - This matches SolidWorks and FreeCAD trim behaviour.
   - Unit test: mirror a strip, rotate the ellipse 17°, trim both overflows, and check both ends are on the ellipse with Success, DOF ≥ 0 and the ends at 22.944 / 23.929.
3. **Product: report conflicts instead of "did not stick" (S, about 2–4 h).**
   - Return `result.conflicting` and `result.redundant` to GDScript.
   - On a failed add, emit text like "Coincident conflicts with Symmetric (mirror) + Coincident (upper end); delete one or make it driven" and highlight those entities.
   - Keep the rollback. Keep a distinct "redundant (ok)" status, because redundant is not failure.
4. **Solver hygiene (S).**
   - If a fallback is added, try LM and accept only `Success` (residual 0), never BFGS `Converged`.
   - Optionally treat `Converged` with a residual above 1e-6 as Failed.
   - Do not chase DogLeg tuning, subgraph solves or curve-parameter rewrites for this bug.
5. **Optional (M).** Allow non-driving (reference) relations, Onshape/SolidWorks style, so a user can keep an over-defining relation as driven.

### Guidance for a fix agent

- Reproduce with `repro_planegcs.cpp`. It is header-compatible with the vendored planegcs; build it with:
  `g++ -std=c++20 -I wt/thirdparty/planegcs -I wt/thirdparty/planegcs-shim -I /usr/include/eigen3 repro_planegcs.cpp wt/thirdparty/planegcs/*.cpp`
  I installed libeigen3-dev, libboost-graph-dev and g++ on the box.
- Do not loosen the volume band. Do not seat lower ends geometrically. Do not add a BFGS acceptance.
- The defining check: after A18, `diagnose()` reports no conflicts, and the lower strip's left end is at about (23.93, −10).
