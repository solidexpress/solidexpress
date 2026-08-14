# Tool Approaches Survey

Companion to the [feature catalog](master-feature-list.md) and [support matrix](feature-matrix.md). Those documents ask *what* each product can do. This one asks *how the best tools in each product work* — interaction model, solver philosophy, and command design — and names a **SolidExpress pick** for each area.

The original survey scoped to seven commercial parametric MCAD suites. Several products outside that set have a better *tool* for a job we still need to do. They are included here for approach, not as feature-completeness peers.

## How to read a pick

A pick is the approach SolidExpress should implement, not a license to copy UI chrome or proprietary kernels. Constraints from the [implementation plan](../plan/implementation-plan.md) still bind: OCCT + PlaneGCS, no GPL/AGPL, hybrid history + recorded direct edits, semantic cards, `SolverBackend` seam, offline desktop.

When this document and the plan's "do what the majority does" rule disagree, **this document wins on tool design**. The plan still wins on architecture and licensing.

---

## 1. Products added for tool design

### Shapr3D (Parasolid, Windows / macOS / iPad / Vision Pro)

**What it is best at:** selection-aware tools and a short path from "I pointed at this" to "I changed it." Tools appear next to the selection; Apple Pencil / gesture input is first-class; hybrid direct + history without forcing a feature-tree-first session.

**Take:** nearby verbs (thin selection strip + marking menu), not a far dock, as the primary path after a pick. Keep docks as the power-user / property surface.

**Leave:** tablet-only assumptions, Vision Pro as a near-term client.

### Plasticity (Parasolid + xNURBS, Windows / macOS / Linux)

**What it is best at:** boolean and fillet *feel*. Keyboard-first commands, live previews, chain/edge-condition fillets that adapt instead of failing, watertight booleans on messy solids. History is optional; that is why the tools can be aggressive.

**Take:** the command feel — single-key tools, live preview, smart edge chains, "try the hard fillet and degrade gracefully." Record successful ops as history features so SX stays parametric.

**Leave:** history-free as the product model. Plasticity is a complement to parametric CAD, not a replacement for a SolidWorks-shaped app.

### IronCAD (ACIS + Parasolid dual kernel)

**What it is best at:** catalog drag-and-drop as the *primary* modeler (IntelliShapes), plus the **TriBall** — one gizmo for move, rotate, copy, and pattern about any inferred axis. SmartAssembly attachment points snap catalog drops into place.

**Take:** deepen the existing SX palette into a real catalog (user parts, holes, fasteners) and replace the split move/rotate/stretch grips with one TriBall-class positioner. Attachment-point snap is the assembly-side twin of Onshape mate connectors.

**Leave:** dual-kernel complexity; OCCT stays the only kernel.

### Solid Edge (Parasolid, Designcenter mid-range)

**What it is best at:** **Synchronous Technology** in a mid-range seat — live geometric conditions (coplanar, concentric, symmetric) on native or imported faces, plus a Steering Wheel gizmo. Ordered + synchronous live in one part.

**Take:** the *goal* of live conditions on imported / late-stage faces (move this hole, keep the pattern). Implement as recorded direct-edit features with pattern/symmetry recognition (Creo FMX style), not a second modeling kernel.

**Leave:** a separate "synchronous side" of the tree that dissolves ordered features. Users should not have to migrate features between modes.

### FreeCAD (OCCT + PlaneGCS — same stack as SX)

**What it is best at:** the topological-naming problem (TNP) on *this* kernel. FreeCAD 1.0 shipped Realthunder's history-based name graph plus geometric fallback and "here is the likely repair" UI. Same failure mode SX will hit.

**Take:** the TNP algorithm family and the repair-candidate UX. SX already has signature matching; the next step is a history-based name graph on OCCT `BRepBuilderAPI` history, with FreeCAD-style assisted repair when matching fails.

**Leave:** the workbench fragmentation and the "finish the solid before you fillet" culture. Those are symptoms of TNP, not a workflow we want.

### Rhino + Grasshopper

**What it is best at:** curve/surface tool density and node-graph generative modeling. Not an MCAD peer.

**Take:** later, a Grasshopper-style node graph *associative with* the feature timeline (CATIA xGenerative / NX Algorithmic Modeling pattern), and Rhino-like curve tools (blend, match, rebuild) inside the surfacing wave.

**Leave:** Rhino as the modeling paradigm. SX is history + cards, not a document of loose objects.

### SolveSpace

**What it is best at:** a tiny, transparent constraint solver with excellent DOF diagnostics. Useful as a reference for what "the solver explained itself" looks like.

**Take:** per-entity DOF coloring and a constraint browser that names the conflicting set, not just a whole-sketch chip.

**Leave:** SolveSpace's 3D-constraint-as-the-whole-app model.

### xDesign (3DEXPERIENCE browser CAD)

**What it is best at:** a SolidWorks-shaped toolset in the browser, plus cloud AI (auto drawings, assembly structure). Confirms the SW command set is still the education/job-market default.

**Take:** keep SW-familiar names for sketch/feature commands so CSWA-trained users land cleanly (see [education-research.md](../education-research.md)).

**Leave:** cloud-mandatory data.

---

## 2. Distilled winners from the original seven

These are *tool* wins, not "has the feature" wins. Full product write-ups live in [profiles/](profiles/).

| Area | Winner | Why it wins | Runner-up |
|---|---|---|---|
| Sketch inference glyphs | **SolidWorks** | Yellow relation previews while drawing; users learn constraints by seeing them | Fusion snap glyphs |
| Sketch always-solves | **Creo weak dimensions** | Every sketch is solved; weak dims auto-complete and yield to strong ones. No "I cannot leave sketch" trap | NX adaptive solver |
| Sketch drag-to-repair | **Inventor Relax Mode** / **NX** | Drag or add a dim; conflicting constraints highlight and drop instead of locking the sketch | Onshape drag-to-test |
| Adaptive constraint finding | **NX Sketch** | Solver proposes relations on the current selection; geometric constraints stop being 30% of sketch time | Creo auto-weak |
| Multi-part single history | **Onshape Part Studios** | Top-down without external refs; one timeline, many bodies | Fusion (same idea, file-shaped) |
| Timeline scrubbing | **Fusion** | Drag the marker to any point; the model *is* the history | SW/Onshape rollback bar |
| Direct edit on dumb solids | **NX Synchronous** (reference) / **Creo FMX** (adoptable) | NX is the live-conditions gold standard; FMX records the same idea as history features we can actually build | Fusion "do not capture history" |
| Fillet / boolean feel | **Plasticity** (outside the seven) | See §1 | NX / CATIA robustness |
| Assembly paradigm | **Onshape mate connectors** | One DOF-typed mate per connection; connectors survive topology change | Fusion Joints (same idea, weaker frames) |
| In-context refs | **Onshape contexts** | Named snapshot, explicit update — no silently broken links | Creo/NX lockable refs |
| Sheet metal | **Onshape simultaneous folded/flat** | Folded, flat, and bend table side by side, live | SW/Inventor depth |
| Custom features | **Onshape FeatureScript** | The vendor's own features are user-level code; AI can emit the same language | NX Knowledge Fusion |
| Rules / ETO | **Inventor iLogic** | Best in-CAD rules engine in the mid-range; forms for non-CAD users | CATIA Knowledgeware (deeper, heavier) |
| Multi-CAD open | **Creo Unite** / **Inventor AnyCAD** | Live foreign files, no translate step | SW 3D Interconnect |
| Drawings depth | **SolidWorks** | The detailing users already know; education default | Inventor (native DWG) |
| MBD / GD&T | **Creo** (Advisor + semantic PMI in every seat) | Do not chase this until drawings work | NX PMI |
| Integrated CAM | **Fusion** | 2.5/3-axis in the base seat; open post library | SW CAM (bundled, shallower) |
| ECAD in-CAD | **Fusion Electronics** | Full schematic + PCB + 3D board | Onshape + Altium |
| Large assemblies | **NX** / **Creo** | Lightweight reps, WAVE/skeletons | SW SpeedPak |
| Collaboration | **Onshape** | Real-time co-edit + branch/merge | Creo+ / 3DX |
| Offline / air-gap | **Desktop incumbents** | Disqualifying requirement for a slice of SX's audience | Fusion temp cache |
| First-hour joy | **Fusion** + **IronCAD** + **Shapr3D** | Drop, push/pull, nearby verbs | SW tutorials |

---

## 3. SolidExpress picks (binding)

Each row is a product decision. Implementation tasks in [roadmap.md](../plan/roadmap.md) cite these IDs.

| ID | Capability | Adopt | Reject / defer |
|---|---|---|---|
| **A1** | First-session modeling | IronCAD catalog drop + Fusion push/pull + Shapr3D nearby verbs. SX already started here; finish the gizmo and the catalog. | SW "must sketch first" as the only path |
| **A2** | Universal gizmo | IronCAD TriBall / Solid Edge Steering Wheel: one tool for move, rotate, copy-about-axis, and face offset | Separate move / rotate / scale commands as the only UI |
| **A3** | Sketch solver philosophy | Creo weak + Inventor Relax + NX propose-on-select. Sketches always solve. Weak constraints auto-apply and yield. Drag/add-dim relaxes conflicts. Solver *suggests* relations on the current selection; users promote them. | SW "fully define or else" as the default; Creo "always fully constrained" without a relax hatch |
| **A4** | Sketch visuals | SW inference glyphs + SolveSpace per-entity DOF colors + click-to-delete badges (already in SX) | Hidden constraint browser as the only diagnostic |
| **A5** | Feature history | Fusion timeline scrub + Onshape Part Studios (many bodies, one graph). Rollback bar stays. | Separate part files as the only way to have two solids |
| **A6** | Direct edits | Creo FMX: every push/pull, move-face, delete-face, replace-face is a timeline feature. Pattern/symmetry recognition on imported bodies. | NX-style second kernel; Fusion "history off" as a document mode |
| **A7** | Fillet / boolean tools | Plasticity feel (live preview, chain select, keyboard, graceful degrade) on OCCT, recorded as A6 features | Dialog-only fillet with no preview |
| **A8** | Assemblies | Onshape mate connectors + Fusion/Onshape DOF joints (fastened, revolute, slider, cylindrical, planar, ball, pin-slot). Magnetic snap on drop (IronCAD SmartAssembly). | Growing the current face-pair mate list (coincident / concentric / parallel) as the long-term model. Those stay as *legacy adapters* that compile down to connectors. |
| **A9** | In-context design | Onshape named contexts with explicit update | Silent live external refs |
| **A10** | Sheet metal | Onshape simultaneous folded / flat / bend table; SW/Inventor flange toolset for coverage | Fusion's thinner sheet-metal as the ceiling |
| **A11** | Custom features | Onshape FeatureScript-shaped language over the existing JSON feature graph (cards + params). Native features are the same format users and AI write. | Closed C++-only features forever |
| **A12** | Rules / configs | Inventor iLogic-style rules (if/then on variables, suppress, component swap) + SW/Fusion configuration tables | Excel-only design tables as the only driver |
| **A13** | Drawings | SW view/dimension vocabulary and detailing depth; Onshape version-compare; own DXF writer (no GPL) | Inventor native-DWG authoring (not worth the format war) |
| **A14** | Topological naming | FreeCAD TNP name graph + geometric fallback + repair candidates | "Fillet last" as user guidance instead of a fix |
| **A15** | Selection / commands | Fusion marking menu + Onshape S-key toolbox + Shapr3D adaptive strip. Overlapping-pick disambiguation popup. | Ribbon-only discovery |
| **A16** | Voice / AI | SX semantic cards + intent layer (already unique). SW AURA-style "what's wrong" on failed regen. Language compiles to A11 features and A8 connectors. | Chat bolted on with no card/UUID ground truth |
| **A17** | Interop | STEP AP214/AP242 + STL/3MF first; Creo Unite *ambition* (associative native import) only after a translator we can license or write | Parasolid-exact exchange we cannot do; GPL DXF libs |
| **A18** | CAM / sim / ECAD | Fusion's *scope* later (2.5-axis + open posts; linear static; board-in-enclosure), not Fusion's cloud-token packaging | Building these before drawings and joints work |
| **A19** | Data / collab | Offline `.sxp` + Git-friendly zip (already). Onshape branch/merge *semantics* on the command log when we add PDM-lite. | Cloud-only documents |
| **A20** | Education names | SW-familiar command names (Smart Dimension, Extrude, Mate) with modern guts (A3, A8) | Inventing a parallel vocabulary |

---

## 4. What we will not copy

- **CATIA Class-A / ICEM** — wrong market, years of surface math, not load-bearing for a SolidWorks-shaped app.
- **NX token-module packaging** — the opposite of an approachable product.
- **Onshape no-offline** — conflicts with A19 and the air-gap audience.
- **Fusion extension / token metering as a product ethic** — ship capability, do not nickel-and-dime the core.
- **SolidWorks Toolbox-as-paid-tier** — standard hardware belongs in the base catalog (A1).
- **Workbenches (FreeCAD)** — one modeling environment, modes inside it.

---

## Related

- [README.md](README.md) — original seven-product survey
- [interaction-patterns.md](interaction-patterns.md) — hover, gizmos, chrome already mapped into SX
- [../plan/README.md](../plan/README.md) — where to park later-wave intent
- [../plan/roadmap.md](../plan/roadmap.md) — sequenced feature waves that implement these picks
- [../plan/landing-protocol.md](../plan/landing-protocol.md) — chrome, L1–L5, film ids
- [../plan/implementation-plan.md](../plan/implementation-plan.md) — architecture and phase machinery
