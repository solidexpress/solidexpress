# Workflow study: mounting block with centered through-hole

Date: 2026-07-28  
Question: Can SolidExpress build the same beginner SolidWorks part, and with how many gestures?

## Part under study

**Rectangular mounting block** — `100 × 60 × 30 mm` solid with a **Ø20 mm centered through-hole**.

This is the canonical SolidWorks beginner “brick with a hole” exercise (Extruded Boss → sketch circle → Extruded Cut Through All).

## Sources processed

| Role | Source | What we extracted |
|---|---|---|
| **Video (captions processed)** | [Creating a Cut Extrude](https://youtu.be/RKIEQVR-qJw) — Nick Ler, SolidWorks training team (needle-nose pliers series, video 3) | Full auto-caption transcript; gesture sequence for sketch→cut-extrude→Through All |
| **Full part recipe (click-complete)** | [SolidWorks Extrude Cut tutorial](https://solidworkstutorialsforbeginners.com/solidworks-extrude-cut/) — 100×60×30 + Ø20 | End-to-end New Part → rectangle → extrude → circle → cut |
| **Alternate centering recipe** | [Artisans Asylum Brackets Tutorial 1](https://wiki.artisansasylum.com/wiki/Brackets_Tutorial_1:_Solidowrks_From_Zero) | Same part class; uses a construction diagonal to find the face center |

Transcript artifact: [sources/sw-cut-extrude-RKIEQVR-qJw.transcript.txt](sources/sw-cut-extrude-RKIEQVR-qJw.transcript.txt).

> Note: Additional YouTube caption downloads (other “how to make L-bracket” videos) were rate-limited (HTTP 429) during this study. The Cut Extrude video plus the matching written recipes cover the same feature path every beginner SW video uses for this part.

## Counting rules

A **gesture** is one discrete user action:

- mouse click (tool, entity, OK/checkmark, face/plane)
- click-drag-release (rectangle, circle radius)
- typed value + commit (dimension / depth / Ø)
- dropdown selection (e.g. Through All)
- hotkey that replaces a toolbar click (counted once, not both)

Orbit / pan / zoom are **not** counted. New-document dialogs count. Optional Normal-To is counted when the tutorial asks for it.

---

## SolidWorks path (efficient beginner recipe)

Matches [solidworkstutorialsforbeginners Extrude Cut](https://solidworkstutorialsforbeginners.com/solidworks-extrude-cut/) and the cut technique in the processed video.

### Phase A — Make the brick

| # | Action | Gestures |
|---|---|---|
| A1 | File → New → Part → OK | 3 |
| A2 | Select Top Plane | 1 |
| A3 | Start Sketch (or Extruded Boss then pick plane — same net cost) | 1 |
| A4 | Rectangle tool | 1 |
| A5 | Click-drag rectangle | 1 |
| A6 | Smart Dimension → length **100** → OK | 4 |
| A7 | Smart Dimension → width **60** → OK | 4 |
| A8 | Exit Sketch | 1 |
| A9 | Extruded Boss/Base → depth **30** → OK | 3 |
| | **Phase A subtotal** | **19** |

### Phase B — Centered through-hole (video-corroborated cut path)

From the processed video: *select face → Circle at center/origin → Smart Dimension → Features → Extruded Cut → Through All → OK*.

| # | Action | Gestures |
|---|---|---|
| B1 | Select top face | 1 |
| B2 | Sketch | 1 |
| B3 | Circle tool | 1 |
| B4 | Place center (mid/origin snap) + rim | 2 |
| B5 | Smart Dimension → Ø **20** → OK | 4 |
| B6 | Exit Sketch | 1 |
| B7 | Features → Extruded Cut | 1 |
| B8 | End condition → **Through All** | 1 |
| B9 | OK (green check) | 1 |
| | **Phase B subtotal** | **13** |

### SolidWorks totals

| Path | Gestures | Notes |
|---|---|---|
| **Efficient (above)** | **32** | Center snap / property radius |
| Artisans Asylum diagonal-center | **~38–40** | Extra construction line + For Construction + midpoint snap |

---

## SolidExpress paths

### Path SX-A — Preferred: Box + Place hole (same or fewer)

| # | Action | Gestures |
|---|---|---|
| 1 | Primitives → **Box** | 1 |
| 2 | Set size **100 × 60 × 30** in place HUD (three fields) | 3 |
| 3 | Click ground to place | 1 |
| 4 | Select top face | 1 |
| 5 | Set Hole **Ø 20** | 1 |
| 6 | Set Hole **Depth ≥ 30** (e.g. 30 or 35) | 1 |
| 7 | **Place hole…** | 1 |
| 8 | Click face center (mid magnet) | 1 |
| | **Total** | **10** |

**Apply hole** (face-center only) can drop steps 7–8 to one click when the default center is acceptable → **~8–9** gestures.

Aligned with workflow ceilings in `game/tests/run_workflow_tests.gd` (`chamfered plate` place-hole path; `hole corner inset` ≤ 6 for the hole segment alone).

### Path SX-B — SW-parity: sketch → extrude cut

For users who want the same mental model as the video:

| # | Action | Gestures |
|---|---|---|
| 1–3 | Box place sized (or sketch-rect → Extrude New) | 5–19 |
| 4 | Select top face → Sketch | 2 |
| 5 | Circle tool → center + rim | 3 |
| 6 | Smart Dim Ø20 (optional if typed radius while drawing) | 0–4 |
| 7 | Finish Extrude, op **Cut**, depth **30** | 2–3 |
| | **Total (from sized box)** | **~12–17** |

Still at or under the SolidWorks Phase B+ remainder when starting from a placed box.

---

## Verdict

| Question | Answer |
|---|---|
| Can we build it? | **Yes** — full geometric parity for this part |
| Best SX gesture count | **~10** (Box + Place hole) |
| SW efficient count | **~32** |
| Ratio | SX ≈ **3× fewer** gestures on the preferred path |
| SW-parity sketch→cut | **Yes**, ~12–17 from a placed box; Extrude ends include **Through All** / Midplane (use Blind depth ≥ stock if preferred) |

```
Gestures (lower is better)
SW efficient     ████████████████████████████████  32
SX sketch→cut    ████████████████                  ~15
SX Place hole    ██████████                        10
```

---

## Limitations surfaced

These do **not** block this part. Several former gaps have landed; leftovers are for script fidelity elsewhere (pliers):

| Gap | Impact on this part | Status |
|---|---|---|
| Extrude **Through All** / Midplane / thin + flip | Not required for this brick | **Shipped** — Blind depth ≥ stock still works |
| **Hole Wizard** multi-point | Nice-to-have vs Place hole | **MVP shipped**; full ANSI-ISO tap library still thin |
| Fully Define / Analyze coach | Dimensions optional on SX path | **Shipped** (sketch upgrades); Place hole still carries Ø/depth |
| Face-center hole without Place hole | **Apply hole** drills face center in one click | Prefer when exact mid is fine |
| Open-profile **cut** + Flip side (no thin) | Out of scope for this brick | Ladder residual — see [ROADMAP.md](../plan/ROADMAP.md) |

### What the processed video also showed (out of scope for this part)

The Cut Extrude video continues with:

1. Reusing a prior sketch (Show → Cut Extrude → reverse direction)
2. Open-profile cut + **Flip side to cut**
3. Teaser for Mirror + Fillet on the pliers

SolidExpress supports Through All / Midplane, thin + flip, feature mirror, fillet, and sketch→cut. Remaining script gap for later jaw videos: **open-profile cut without thin** — [ROADMAP.md](../plan/ROADMAP.md) Hard near-term.

---

## Product takeaways

1. **Place / Apply hole is the win** for this class of beginner tutorial — SW’s sketch→cut ritual is 13 gestures; SX’s pick-place is 4–5 after the body exists (centered: **`O`** / selection-strip **Hole**).
2. Keep a **sketch→cut** path discoverable so SW-trained users are not blocked; gesture parity is already close once the body exists; Through All is available when matching SW scripts verbatim.
3. Highest-value remaining gap for later SW videos (pliers jaws): **open-profile cut + Flip side** without requiring a thin wall — tracked on the demo ladder in [ROADMAP.md](../plan/ROADMAP.md).
4. Optional follow-up study: L-bracket + inner fillet (`workflow_bracket` ceiling 20 in SX) vs a full SW L-bracket video once captions are available.

Verified howto (click vs keyboard): [howto/mounting-block.md](../howto/mounting-block.md).

## Related

- [howto/mounting-block.md](../howto/mounting-block.md) — SX recipe + click vs keyboard ceilings
- [interaction-patterns.md](interaction-patterns.md)
- [howto/horizontal-hole.md](../howto/horizontal-hole.md)
- `game/tests/run_workflow_tests.gd` — gesture ceilings
- [profiles/solidworks.md](profiles/solidworks.md)
