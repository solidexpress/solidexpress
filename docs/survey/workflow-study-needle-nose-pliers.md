# Workflow study: needle-nose pliers (SolidWorks Beginner’s Guide)

Date: 2026-07-28  
Series: [SOLIDWORKS Beginner’s Guide](https://youtube.com/playlist?list=PLiKqXuECiKNLzF6aDC3z-H1BZ94ITZIQk) — Nick Ler, SolidWorks training team.  
Outcome: **two jaw/handle parts + pin**, assembled so dragging a handle **rotates about the pin axis**.

Companion micro-benchmark (through-hole clicks only): [workflow-study-mounting-block.md](workflow-study-mounting-block.md). Cut technique transcript: [sources/sw-cut-extrude-RKIEQVR-qJw.transcript.txt](sources/sw-cut-extrude-RKIEQVR-qJw.transcript.txt).

## Series map vs SolidExpress

| Stage | SolidWorks | SolidExpress | Gap tier |
|---|---|---|---|
| Pin | Sketch circle → extrude | Yes | — |
| Jaw body | Sketch → **Midplane** extrude; selected contours | Midplane / Through All / Blind ends | Shared-edge contours **done** |
| Cuts | Circle cut **Through All**; reuse sketch; **open-profile cut + Flip side** | Through All + Blind; thin + flip; open cut without thin | Open-profile cut (no thin) — [ROADMAP](../plan/ROADMAP.md) |
| Symmetry / finish | Mirror cut/features; Fillet | Feature-level mirror + constant fillet | — |
| Handle | Open sketch → **Thin Feature** extrude, merge | Thin extrude on open profile | — |
| Assembly | Multi-part; **Concentric** + **Coincident** | Same-doc instances; `concentric` + `plane_coincident`; instance↔instance | Multi-doc insert **P2** |
| Motion | Drag handle → **1 DOF rotate about pin** | Concentric leaves revolute DOF; instance drag rotates about axis | Undo for mates still open |

The rotation is the leftover DOF after concentric (axes) + coincident (jaw faces). SolidExpress exposes that axis via `instance_revolute_axis` and projects instance drag onto it when present.
## P0 — Assembly motion (priority)

| Gap | Why | Where |
|---|---|---|
| **Revolute / DOF-aware drag** | Drag jaw about concentric axis | Kernel exposes revolute axis; `MOVE_INSTANCE` rotates about it |
| **Mate A can be an instance** | Both jaws are instances | AssemblyPanel two-pick: any face → instance face |
| Undo for instance/mate | Interactive series | Follow-up (mutations still direct in v1) |

**Minimal motion recipe after P0:**

1. One jaw body + pin in the document; instance a second jaw (or instance both).
2. `concentric` hole↔hole (or hole↔pin); `plane_coincident` on mating faces.
3. Drag the movable instance → rotates about the concentric axis; `solve_mates` keeps axes/faces satisfied.

Aligns with implementation-plan **5.3–5.4** (revolute + DOF drag), implemented first as **revolute DOF on the existing concentric stack**.

## P1 — Part features the scripts use

| Gap | Workaround | Add |
|---|---|---|
| Extrude **Through All** / **Midplane** | — | **Done** |
| **Thin Feature** (open profile) | Closed offset sketch | **Done** (`thin_thickness` + flip) |
| **Open-profile cut + Flip side** (no thin) | Thin cut or closed cut | Ladder residual — [ROADMAP](../plan/ROADMAP.md) |
| Selected contours | Separate sketches | **Done** (disjoint + shared-edge) |

## P2 — Convenience (not blocking motion)

- Feature-level Mirror of a cut — **Done** (body mirror remains as alternate)
- Multi-document components (same-doc instances OK for a demo)
- Mate connectors / snap-to-mate
- Joint limits (± open angle)

Priority owner for leftovers: [ROADMAP.md](../plan/ROADMAP.md).

## Recommended add sequence

1. This study (done).
2. **P0a** — Kernel: `instance_revolute_axis`; concentric/plane apply preserves rotation about that axis. **Done.**
3. **P0b** — UI: instance drag with active revolute DOF rotates about axis; assembly tests. **Done.**
4. **P0c** — AssemblyPanel: mate instance↔instance. **Done.**
5. **P1** — Extrude Through All + Midplane + thin/flip. **Done.** Open-profile cut (no thin) next — see ROADMAP.
6. **Golden** — Headless pliers MVP: two jaws + pin, drag changes angle. **Done** (`run_pliers_motion_tests.gd`).
7. Feature-level Mirror. **Done.**

## Success criteria

- Assemble two jaw instances + pin with concentric + plane coincident.
- Dragging a jaw handle rotates it about the pin; the other jaw (or pin) stays put as designed.
- Jaw solid can use through-all / midplane without depth hacks (P1).

## Related

- [workflow-study-mounting-block.md](workflow-study-mounting-block.md)
- [howto/direct-edit.md](../howto/direct-edit.md) § assembly drag
- `game/tests/run_assembly_tests.gd`, `run_pliers_motion_tests.gd`
- [implementation-plan.md](../plan/implementation-plan.md) Phase 5.3–5.4
- [ROADMAP.md](../plan/ROADMAP.md) — active demo ladder + feasibility
