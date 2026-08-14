# Commercial MCAD Feature Survey

A survey of the seven major commercial parametric mechanical CAD (MCAD) applications, produced to drive the feature roadmap for the `solidexpress` project. It answers two questions: *what is the complete universe of features these products offer*, and *who supports what, at which price/tier*.

**Priority owner:** [docs/plan/ROADMAP.md](../plan/ROADMAP.md) (SW beginner demo ladder + feasibility tiers). This survey is the competitor universe and workflow evidence — not the weekly priority list. Checkbox ledger: [STATUS.md](../plan/STATUS.md).

## Purpose

`solidexpress` aims to be 3D modeling software in the SolidWorks mold. Before designing anything, we need a requirements catalog grounded in what the market actually ships. The [master feature list](master-feature-list.md) is written vendor-neutrally so it doubles as that catalog; the [matrix](feature-matrix.md) and [profiles](profiles/) show where each competitor is strong, weak, or charging extra — i.e., where the opportunities are. Near-term script ladder (Nick Ler beginner series): [workflow-study-mounting-block.md](workflow-study-mounting-block.md) → [workflow-study-needle-nose-pliers.md](workflow-study-needle-nose-pliers.md).

**What to build, and whose tool to copy:** the [tool-approaches](tool-approaches.md) survey picks a winner per capability (including products outside the original seven). The sequenced product plan that implements those picks is [../plan/roadmap.md](../plan/roadmap.md).

## Documents

| Document | Contents |
|---|---|
| [master-feature-list.md](master-feature-list.md) | ~230 features across 16 categories, each with a canonical name and a vendor-neutral description of what it does and why it matters. The core deliverable. |
| [feature-matrix.md](feature-matrix.md) | Products-by-features support matrix (Full / Partial / Add-on / Not supported) with ~190 footnotes covering per-product terminology and tier nuances. |
| [interaction-patterns.md](interaction-patterns.md) | How peers make actions visually discoverable (hover, gizmos, context chrome) and how SolidExpress maps those patterns. |
| [tool-approaches.md](tool-approaches.md) | How the best *tools* work — including Shapr3D, Plasticity, IronCAD, Solid Edge, FreeCAD — and the binding SolidExpress picks (A1–A20). |
| [print-first.md](print-first.md) | How a part becomes a print (P1–P6): wall/overhang/orient/3MF. Form rail, not a slicer. |
| [../plan/roadmap.md](../plan/roadmap.md) | Sequenced feature waves that implement those picks against current STATUS. |
| [../plan/landing-protocol.md](../plan/landing-protocol.md) | How each wave row lands: chrome budget, L1–L5, film ids, slices. |
| [workflow-study-mounting-block.md](workflow-study-mounting-block.md) | Click-count study: SolidWorks “brick + through-hole” (processed Cut Extrude video + beginner recipes) vs SolidExpress Place hole / sketch→cut. |
| [workflow-study-needle-nose-pliers.md](workflow-study-needle-nose-pliers.md) | Gap map for the SolidWorks needle-nose pliers series (midplane/thin/through-all + revolute DOF drag). |
| [profiles/](profiles/) | One deep-dive per product: positioning, architecture (kernel, formats, deployment), standout features, weaknesses, licensing/pricing, ecosystem. |

## Products and versions surveyed

| Product | Vendor | Version surveyed | Profile |
|---|---|---|---|
| SolidWorks | Dassault Systèmes | 2026 (desktop) | [profiles/solidworks.md](profiles/solidworks.md) |
| Fusion (Fusion 360) | Autodesk | continuous release, mid-2026 | [profiles/fusion.md](profiles/fusion.md) |
| Onshape | PTC | SaaS, mid-2026 | [profiles/onshape.md](profiles/onshape.md) |
| Inventor Professional | Autodesk | 2026 | [profiles/inventor.md](profiles/inventor.md) |
| Creo Parametric | PTC | Creo 12/13 era | [profiles/creo.md](profiles/creo.md) |
| NX / Designcenter | Siemens | June 2026 release (2606) | [profiles/nx.md](profiles/nx.md) |
| CATIA | Dassault Systèmes | V5-6R2026 and 3DEXPERIENCE R2026x | [profiles/catia.md](profiles/catia.md) |

Scope decision for the **feature catalog and matrix**: commercial parametric MCAD applications only. Open-source CAD (FreeCAD, SolveSpace), geometry kernels/libraries (Parasolid, OpenCASCADE), and adjacent tools (Rhino, Blender, OpenSCAD) were excluded from those two documents per original project direction.

The **tool-approaches** survey deliberately re-opens that door. Shapr3D, Plasticity, IronCAD, Solid Edge, FreeCAD, Rhino/Grasshopper, and SolveSpace are included there because several of them have a better *tool* for a job SolidExpress still has to do — even when they are not full MCAD suites. See [tool-approaches.md](tool-approaches.md).

## Methodology

1. Each product was researched independently (July 2026) against official vendor documentation, product/feature/pricing pages, release notes, and reputable reseller and comparison sources, using a fixed 16-category template so inventories merge cleanly.
2. The seven inventories were merged into the master list, deduplicating features that go by different names (e.g. SolidWorks "mates" vs. Fusion "joints" vs. Onshape "mate connectors"; "fillet" vs. "round"; "loft" vs. "multi-section solid" vs. "blend"). Canonical names were chosen for neutrality; product terminology is preserved in the matrix footnotes.
3. The matrix records support at the level of each product's *entry commercial offering*: anything requiring a higher tier, a paid extension/module, or a separate same-vendor product is marked Add-on, because that cost boundary matters when scoping a competing product.
4. Profiles were written from the per-product research plus cross-product comparison after the merge.

## How to read the matrix

| Symbol | Meaning |
|---|---|
| **F** | Full — built into the base/entry commercial offering |
| **P** | Partial — limited depth, workaround-level, or notable restrictions |
| **A** | Add-on — higher tier, paid extension/module, or separate same-vendor product |
| **–** | Not supported (third-party/partner apps may fill the gap) |

Baselines used for "entry commercial offering": SolidWorks Standard, Fusion base subscription, Onshape Standard, Inventor Professional (standalone), Creo Design Essentials, NX/Designcenter Standard-tier, CATIA V5 mid config / 3DX entry mechanical role. Follow the footnote numbers — the tier nuances are where the real competitive information lives.

## Caveats

- Pricing is 2025–2026 US/EU list from vendor stores and published reseller pages; enterprise deals rarely pay list. Regional variation is significant.
- Vendor packaging churns constantly (Creo renamed its tiers in the Creo 12 era; Siemens rebranded NX CAD to Designcenter in June 2026; Autodesk discontinued the Fusion Signal Integrity Extension and Inventor Mold Design). Verify tier claims before relying on them for anything contractual.
- Support-level judgments (F vs. P) for depth-of-capability necessarily involve editorial judgment informed by user-community consensus, not just vendor claims.
