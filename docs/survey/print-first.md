# Print-first survey

Companion to [tool-approaches.md](tool-approaches.md) and the [feature catalog](master-feature-list.md) §10 (additive prep) / §13 (3MF). Those documents list *what* the market ships. This one asks **how a part becomes a print** — analysis, orientation, bed, and the file a slicer actually opens — and names the SolidExpress picks.

The original seven MCAD suites treat additive as a paid extension or a late export. The tools that *feel* print-first sit outside that set: PrusaSlicer / Orca, Bambu Studio, Fusion’s FFF workspace, and (for lattices later) nTopology. SX already exports a watertight 3MF ([Wave 0.10](../plan/roadmap.md)). The gap is everything *before* File → Export: the user cannot see a thin wall, a 60° hang, or a part that does not fit the bed.

Constraints from the [implementation plan](../plan/implementation-plan.md) still bind: OCCT, no GPL slicer engine, no new dock, Form rail already reserved (Wave 4.5 SubD). Print-first **reuses Form** as the print-prep rail — SubD stays a spike verb, not a second mode.

## How to read a pick

A pick is the approach, not a license to vendor-lock a printer brand. Cards + UUIDs on every new selectable. Graph-owned geometry; print orientation is a **document setup** applied at export, not a silent rotate of the design solid.

---

## 1. Products added for print feel

### PrusaSlicer / OrcaSlicer (open, AGPL — approach only)

**What it is best at:** one glance at the part on the bed. Overhangs paint themselves. Orientation is a verb, not a dialog. The slice preview is the product.

**Take:** analyze-then-orient as two clicks. Overhang threshold defaults to 45°. Bed is a number on the strip, not a printer SDK. Paint is a *way of seeing* (like zebra), not a new workbench.

**Leave:** the AGPL slicer, G-code, supports, and printer profiles. SX does not become a slicer. 3MF out; Prusa/Orca/Bambu open it.

### Bambu Studio

**What it is best at:** “does this fit, and which way is up” in one screen. Auto-orient that minimizes supports, then height.

**Take:** cube-face orientation search (24 poses) scored by overhang area, then height. No cloud printer.

**Leave:** AMS, network printers, proprietary `.3mf` job tickets.

### Fusion Manufacture — FFF (in-CAD)

**What it is best at:** print prep that does not leave the model. Wall-thickness and overhang live next to the solid. Orientation is remembered on the document.

**Take:** in-document `PrintSetup` (bed, layer, min wall, overhang degrees, rotation). Analyze writes a digest on the selection card. 3MF carries the same metadata so a slicer sees millimeters and the bed.

**Leave:** Fusion’s toolpath/slicing workspace and the Manufacturing Extension paywall. Metal LPBF stays unscheduled.

### Creo Additive / Materialise / nTopology

**What it is best at:** lattices, trays of many parts, metal compensation.

**Leave for later:** TPMS/beam lattices, tray nesting, process simulation. Parked under Wave 5.4+ — do not start until 5.1–5.3 films exist.

---

## 2. Picks (P1–P6)

| # | Job | Pick | Leave |
|---|---|---|---|
| **P1** | Wall thickness | Ray from each face midpoint along −normal; min hit is `min_wall`. Threshold on `PrintSetup` (default 1.2 mm) | Mesh-only thickness maps, CT scans |
| **P2** | Overhangs | Face area whose outward normal · build < −sin(θ); bed-contact face (z≈min) excluded. θ default 45° | Support generation, tree supports |
| **P3** | Orient to bed | 24 cube poses; minimize overhang area, then height. Stored on `PrintSetup.rot`, applied at 3MF | Physics drop, GPU packing |
| **P4** | Bed / fit | Axis-aligned bbox in print space vs `bed_x/y/z` (default 220×220×250) | Printer catalog, exclusive beds |
| **P5** | 3MF | Existing writer + `<metadata>` for bed, layer, min_wall, digest. Vertices transformed by `rot` | GPL lib3mf, Bambu job XML |
| **P6** | Chrome | **Form rail** (already on Mode): Analyze + Orient chips. Marking-menu **Print check**. File → Export 3MF unchanged | A Print dock, a sixth mode name, ViewHud button (zebra already spent that slot) |

---

## 3. v1 bar (land this, then stop)

A stranger can: put a solid on the bed in Form mode, click **Analyze**, read a one-line digest (min wall, overhang mm², fits bed), click **Orient** when a tall part should lie down, and export a 3MF that still opens in a slicer and names the bed.

| Slice | Kernel benefit (Catch2) | Film |
|---|---|---|
| 5.1 Thickness + digest | 20 mm cube `min_wall≈20`; 20×20×1.2 plate `min_wall≈1.2` and `wall_ok=false` at threshold 2 | `print_thin_wall` |
| 5.2 Overhang + orient | L-shelf has overhang area > 0; 10×10×80 box orients to height ≈ 10 | `print_overhang_orient` |
| 5.3 3MF metadata | Exported 3MF XML contains `sx:bed` and `unit="millimeter"`; `.sxp` round-trips `print.json` | File menu already; film asserts the file |

**Not in v1:** supports, slice preview, lattices, multi-part trays, metal, G-code.

---

## 4. Chrome law

Form replaces Modify (existing Mode rail). The print strip is a 28 px chip row under TopChrome — Analyze, Orient, and the last digest. It hides in Model/Draw/Sheet/Cam/Sim. No ViewHud button. No new dock. Layout suite stays green.

---

## 5. Deferred (do not lose)

- Lattice / gyroid (nTopology feel) — Wave 5.4
- Support preview as a ghost mesh — 5.5
- Tray of instances / nest — 5.6
- Escape/drain holes as a hole-wizard preset
- Color-by-thickness in the viewport (reuse zebra shader path when a film needs it)
