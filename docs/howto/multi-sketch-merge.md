# Multi-sketch → 3D (SolidWorks comparison)

SolidWorks turns multiple 2D sketches into solids through several parallel paths. SolidExpress covers the core set with **planar sketches + merge path + sweep/loft**, using colored pads and on-canvas chips instead of a free 3D sketch environment.

## SolidWorks vs SolidExpress

| Capability | SolidWorks | SolidExpress |
|---|---|---|
| Free 3D sketch | Full 3D sketch mode | **Path feature** — one open rail, or merge rails on different planes |
| Boss extrude / cut | Extrude from closed profile | **Extrude** (New / Cut / Fuse) from sketch |
| Revolve | Revolve boss/cut | **Revolve** from sketch + axis line |
| Sweep | Profile + path (open or closed) | **Sweep along path** — profile + Path, or one-shot profile + rail(s) |
| Loft | 2+ closed profiles | **Loft ruled / smooth** — Shift+box or Ctrl+select profile pads |
| Guide curves | Sweep/loft guides | **Open rails** with loft profiles, or with a timeline-selected Path + sweep profile |
| Thin feature | Wall thickness on extrude/sweep | **Sweep** thin wall (property panel); extrude thin not yet |
| Convert entities | Project model edges into sketch | **Associative Convert** (selected edges → external sketch entities; dangling on missing edges) |
| Intersection curve | Curve at face intersection | Not yet |
| 2D→3D wizard | Front/top/side view import | Not yet — use explicit planes + merge |
| Path preview | 3D sketch visible | **Cyan path tube** on Path features |
| Pad profile in 3D | — | **Gold** strokes = closed profile (loft/extrude); **cyan** = open rail (merge/guide) |

## Workflow A — Path + sweep (L-shaped tube, pipe, rail)

### Multi-rail merge

1. **Sketch A** on ground — open spline, line chain, or arc (rail). Uncheck **Auto-close** if using multi-line. **Exit Sketch**.
2. **Sketch B** on a vertical face or custom plane — open leg. **Exit Sketch**.
3. **Ctrl+click** both cyan (open) pads → **Merge join** (or **Merge spline** for smooth bridge).
4. A **Path** row appears on the timeline; a **cyan tube** shows the merged rail in 3D.
5. **Sketch C** — closed circle (profile). **Exit Sketch**.
6. **Ctrl+click** the gold (closed) profile pad → **Sweep along path** (Path stays selected after merge). Or select the Path row first, then Ctrl+click profile → Sweep.

### Single-rail / one-shot

1. Sketch one open cyan rail (line/arc/spline chain). **Exit Sketch**.
2. Ctrl+click the rail → **Use as path** (creates a Path from that sketch alone).
3. Sketch a closed gold profile. **Exit Sketch**.
4. Ctrl+click the profile → **Sweep along path**.

Or skip the Path chip: Ctrl+click the profile **and** the rail(s) → **Sweep along path** creates the Path and solid in one step.

Optional guides: select a Path on the timeline, then Ctrl+click the profile **plus** open cyan guide rails → Sweep uses those rails as guide curves.

## Workflow B — Loft between profiles (funnel, transition)

1. Create **Sketch A** and **Sketch B** on different planes — each a **closed** profile (circle, rectangle, closed loop). Pads render **gold**.
2. **Shift+drag** (or **Ctrl+click**) both profile pads.
   - **Shift+left-drag** empty space = window box (fully inside only)
   - **Shift+right-drag** empty space = crossing box (partial capture counts)
3. Optional: also Ctrl+click an **open cyan rail** — it becomes a **guide curve** (loft waist follows the rail).
4. Choose **Loft ruled** or **Loft smooth**.

## Workflow C — Simple extrude (baseline)

Single closed profile → **Extrude** — see [extrude-s-shape.md](extrude-s-shape.md).

## Tips

- **Cyan / open** pads → Path / merge chips or loft/sweep guides. **Gold / closed** pads → loft / extrude / sweep profile.
- Mixed selection of 2+ profiles + rails loft with guides; rails alone still offer Path/merge.
- Sweep never silently picks a random Path — select a Path on the timeline, keep the Path selected after merge/Use as path, or include rail(s) with the profile for one-shot.
- Edit source sketches to update paths and solids associatively. Sweep properties include Result (new/fuse/cut) and Thin wall.

Verified by `run_sketch_parity_tests.gd`, `run_sweep_loft_solid_tests.gd`, `run_sketch_fully_defined_tests.gd`, `run_sketch_expr_dim_tests.gd`, `run_convert_entities_tests.gd`, and `run_sketch_to_3d_ui_tests.gd`.
