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

W6.0a–e (suite stabilization, CI gate) are owned by the stabilization agent — see [STATUS](../plan/STATUS.md) Wave 6; they are not renumbered here. The acceptance bar for everything below is the **2026-08-14 hands-on critique of the published 0.0.4 Linux binary** (shop-tools-construction-basis rubric): fastener-sized opening, named clearance, AF family 10/12/14, cut survives thickness (through-all / Up To Surface), head-shaft fillet, modeled thread, nozzle-multiple walls, hex as a real AF polygon.

1. W6.1 — Construction chrome (part of the 6.0 gate; green before W6.2+)
   - Focused numeric fields consume digits; view keys 1/2/3/7 never fire while a spinbox/line-edit is focused (0.0.4 ate H=1.2).
   - Box place strip and post-place property panel show W/H/D — not Radius/Spacing/Count.
   - Form keeps a one-click way back to create without losing the Analyze/Orient strip (palette may hide).
   - Selection/Timeline/Variables/Assembly/context bars never stack undismissably.
2. W6.2 — Clearance language
   - New documents seed `VariableTable` builtins `clearance=0.3`, `hole_compensation=0.2`, `layer=0.2`, `nozzle=0.4`, `jaw_af=10` (mm) — editable, not a dock.
   - Sketch dimensions accept `=jaw_af+clearance` and live-regenerate (depends on the 6.0b expr-dim fix).
   - Hole Wizard / hole Ø = nominal + `hole_compensation`; hex and slot openings = `jaw_af+clearance` (or explicit AF).
   - Configs named 10 / 12 / 14 switch `jaw_af` only — one model, no rebuild. Fusion’s actual win, made native.
   - Exit: change `clearance` 0.3→0.5 and every consumed opening updates; film `clearance_ladder`. Leave: a print-settings dock; printer SDK.
3. W6.3 — See the print
   - Thickness + Overhang paint toggles on Form (zebra shader path reserved in [print-first](print-first.md) §5). Bed ghost (default 220×220) in Form only. Digest stays, but is not the product.
   - Threshold from `PrintSetup` / `min_wall` (already 1.2 in the 0.0.4 3MF metadata); must succeed on a 1.2 mm plate (needs W6.1 so 1.2 can be typed).
   - Exit: film `see_the_print`. Leave: support generation; becoming a slicer.
4. W6.4 — Open in slicer
   - File → Open in Slicer; user-registered Prusa / Orca / Bambu executable; one body per file; “File → Export 3MF” unchanged (mm + `sx:bed` verified on 0.0.4).
   - Exit: film `open_in_slicer` — per-body mm 3MF + registered command line. Leave: GPL slicer engine; printer profiles.
5. W6.5 — Tool catalog
   - Drop-in open-end, hex socket, driver bit, nozzle sizes (IronCAD catalog feel; see [tool-approaches](tool-approaches.md) A1); AF from `jaw_af`. Not a full Toolbox — just mechanic-tool sizes.
   - Exit: film `catalog_hex_driver` — opening tracks `jaw_af`. Leave: McMaster-style hardware library.
6. W6.6 — Build the wrench (after W6.2’s param seam; can parallel W6.3–W6.5)
   - Jaw/through cuts default to through-all / Up To Surface (Blind is the amateur trap).
   - Modeled Thread reachable in chrome (Insert or Modify → Thread); in Form, Modeled is the default and cosmetic-only is a checkbox. STATUS claims thread; the 0.0.4 menus did not show it.
   - Sketch polygon gets an across-flats (`jaw_af`) mode — no Fusion `size/2` radius workaround.
   - Hole Wizard reachable from the place/context chrome we actually used, not only a buried ops path.
   - Exit: film `print_a_wrench` — a stranger builds an open-end or hex wrench with `jaw_af+clearance`, through-all jaw cut, optional modeled thread, Analyze paint, Open in Slicer or 3MF, and spins 10/12/14. This film is the critique replay.

## Will we win the 2026-08-14 critique?

Honest answer: **6.0a–e plus the old titled 6.1–6.4 would not have won.** The critique failed on construction basics (typing 1.2, W/H/D fields, Form create path, reachable Thread and Hole Wizard, AF polygon, through-all defaults) that no amount of paint or 3MF metadata fixes. W6.1 chrome + the specified W6.2–W6.5 + W6.6 is the minimum set that can win it, and `print_a_wrench` is the replay that proves it. Verified on the Linux 0.0.4 hands-on only — no claim about a working 0.0.4 DMG.

## Do not do next

- More drawings depth; sheet metal polish; CAM/FEA; lattices (parked Wave 5.4); becoming a slicer; Parasolid TNI.

## Pointers

- Print-first picks P1–P6 (and deferred 5.4–5.6): [print-first.md](print-first.md)
- Tool picks (A1, A12, A17): [tool-approaches.md](tool-approaches.md)
- Sequenced owner file: [../plan/ROADMAP.md](../plan/ROADMAP.md)
- Checkbox ledger: [../plan/STATUS.md](../plan/STATUS.md)

## Exit criteria

A stranger can model an open-end or hex wrench with named clearance, see thin walls and overhangs painted in Form with a bed ghost, export or open-in-slicer a millimeter 3MF that lands on the bed, and spin a 10/12/14 config without rebuilding.

