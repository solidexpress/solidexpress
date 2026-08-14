# Wave 6 — print a tool this afternoon

Premise: pretend 0.0.4 / Waves 0–5 work (per [STATUS](../plan/STATUS.md)). This is a priority flip, not a binary claim. The product north star stays SW-shaped MCAD; the near-term owner is the print-first loop to design and FDM‑print custom mechanic tools (wrenches, hex drivers, nozzle tools, jigs). We do not become a slicer.

## Why this owns next

Slicers already win on supports, Arachne, printer profiles, and paint-on supports. CAD’s remaining jobs for a one-off printed wrench are: clearance parameters, modeled threads, “wall intent,” units in the 3MF, and a hex that stays a hex after tessellation. Fusion’s “named user parameters + modeled Thread + Save as Mesh 3MF” is the fastest real path today; SolidWorks shops use Thickness Analysis + 3MF/STL; Onshape exports 3MF and lets the slicer do the rest. If SX Analyze/Orient are working (Wave 5), SX is already differentiated at “see thin walls / overhangs” before the slicer.

## Scorecard (mechanic-tool print job)

| Product | Fastest viable path today | Gaps vs SX print-first bet |
|---|---|---|
| Fusion | Design → named params (`clearance`, `hole_compensation`, `jaw_af`) → modeled Thread → Save as Mesh 3MF (mm) → slicer | No true Thickness Analysis; Draft Analysis is mold-focused; parameters are the real win |
| SolidWorks | Thickness Analysis → Save as 3MF/STL (≤1° chordal, Z-up CS) → slicer | Good wall tool; export fine; no overhang paint; Print3D is optional theater |
| Onshape | Part Studio → Export 3MF Fine → slicer | No wall/overhang; relies on slicer UX |
| Slicers (Prusa/Orca/Bambu) | Open 3MF; supports/profiles/paint-on in one place | Own supports/profiles; not CAD. Keep them as destination, not embedded GPL |
| Plasticity / Shapr | Faster capture; iterate worse on AF sizes | Great modeling feel; weak param/config iteration for AF ladders |
| nTop | Lattices/metal AM | Later (parked — not an FDM wrench job) |

## Binding next bets (W6.1–W6.6)

W6.0a–e (suite stabilization, CI gate) are owned by the stabilization agent — see [STATUS](../plan/STATUS.md) Wave 6; they are not renumbered here.

1. W6.1 — Construction chrome
   - Number fields keep keystrokes while focused (view keys never steal them mid-typing); box placement gets W/H/D fields; the Form rail gets a create path instead of assuming a pre-built solid; docked panels stack without overlap.
2. W6.2 — Clearance language
   - Built-in print params (`clearance`, `hole_compensation`, `layer`, `nozzle`, `jaw_af`) that Hole Wizard / hex / slot consume.
   - Configs make 10/12/14 mm one model (AF ladder without rebuild). Fusion’s actual win, made native.
3. W6.3 — See the print
   - Color-by-thickness and overhang paint on Form (reuse the zebra shader path reserved in [print-first](print-first.md) §5). Bed ghost. Digest stays, but is not the product.
4. W6.4 — Open in slicer
   - User-registered Prusa/Orca/Bambu; one body per file when opening externally; “File → Export 3MF” unchanged. No GPL slicer engine. Units = mm in 3MF.
5. W6.5 — Tool catalog
   - Drop-in open-end, hex socket, driver bit, nozzle sizes (IronCAD catalog feel; see [tool-approaches](tool-approaches.md) A1). Not a full Toolbox — just mechanic-tool sizes.
6. W6.6 — Build the wrench
   - Integration exit: film `print_a_wrench` clicks W6.2–W6.5 end to end (catalog blank, clearance-compensated jaw, painted check, millimeter 3MF on the bed).

## Do not do next

- More drawings depth; sheet metal polish; CAM/FEA; lattices (parked Wave 5.4); becoming a slicer; Parasolid TNI.

## Pointers

- Print-first picks P1–P6 (and deferred 5.4–5.6): [print-first.md](print-first.md)
- Tool picks (A1, A12, A17): [tool-approaches.md](tool-approaches.md)
- Sequenced owner file: [../plan/ROADMAP.md](../plan/ROADMAP.md)
- Checkbox ledger: [../plan/STATUS.md](../plan/STATUS.md)

## Exit criteria

A stranger can model an open-end or hex wrench with named clearance, see thin walls and overhangs painted in Form with a bed ghost, export or open-in-slicer a millimeter 3MF that lands on the bed, and spin a 10/12/14 config without rebuilding.

