# sx-026 critique: main @ 3eb4f031 (replan-5 #82–#85), OCCT 8.0.1 local build

Build sha256 b0130a670555ace2b0803fec7e8ebaf90d1704bc40e8494e5d5889a888c58bdc. Run on DISPLAY :3 at 1280×800 with real mouse and keyboard, in chunks (5:46–6:47 PM CT, Oct 4).

**Verdict: FAIL, 6/10.** Up from 5. The jaw trim now works in the GUI (`Trimmed open jaw`), the `Opposite face` button picks the bottom face (`Face: z 0.0 mm`), and the sketch never got stuck. But the jaw cut itself is refused, so there is still no wrench. The blank is also 1.5 mm long and mirrored, and a bare export name still goes to HOME.

## Tried / expected / got

| # | Tried | Expected | Got |
|---|---|---|---|
| A1–A6 | Nut: AF 20, r 5, Distance 7.5 | 7.5 nut | Pass. Checker: **nut 7/7** |
| A7 | Browse to /workspace/sx-026/gui, type bare `nut.3mf`, OK | Saved in the folder shown (WP2/#82) | **Fail.** `Exported 3MF → /tmp/sx-026-home/nut.3mf`. The full path works. |
| B1.2 | Second circle: typed 22.5 into the top field | Ø45 | The first try went into the finish-bar `D` (`Extrude 22.5 mm`). Using the radius field, it was a Pass. The two fields are easy to confuse. |
| B1.3 | Smart Dimension: click both centres | Popup for 200 | **Fail.** `2 sketch entities selected`: the relation strip appears, with no dimension popup. Centre-to-centre ended up about 201.5. |
| B1.4–5 | Tangents, Extrude 10, export | 232.5 × 45 × 10 | Closed mesh, but **233.97** × 44.88 × 10, and **mirrored** (the head ended up on −X; the checker reports flipX). |
| B2.6–9 | Top-face sketch, Ø10, Ø45, Center-3-Point jaw | Construction drawn | Pass |
| B2.10–11 | Perpendicular centreline, one shaft-side Power Trim | `Trimmed open jaw` | **Pass** (WP1/#83 fixed). Retrying the centreline left old geometry and overlapping dimension labels (`19442081`). See shots/b2-cut-failed.png. |
| B2.12 | Cut, Up To Surface, `Opposite face`, Extrude | Jaw and Ø10 hole cut | `Face: z 0.0 mm` is a Pass (WP3/#84 fixed). **Cut refused:** `Open-profile cut needs a line chain (Flip Side toggles material)`. The trimmed jaw plus the hole circle is not accepted as a cut profile. |
| B2.13–B5 | Export, slot, fillets, timeline | wrench 28/28, thick 4/4 | Not reached |

## Leftovers for re-plan 6 (P0 first)

| Pri | Problem | Evidence |
|---|---|---|
| P0 | **The cut after `Trimmed open jaw` is refused** with `Open-profile cut needs a line chain`. The headless walk passes this path, so find out what differs in the GUI sketch: the leftover first centreline and the extra geometry, the Ø45 head-circle arcs, or the hole circle in the same sketch. The cut must accept trimmed jaw plus hole, or say exactly which entity breaks the chain. | WALK_LOG B2.10–12, shots/b2-cut-failed.png, b2-trim-final.png |
| P0 | **Smart Dimension between two circle centres gives no popup.** Clicking both centres only selects them and shows the relation strip, so the 200 spacing can't be set and the blank is 1.5 mm long. | WALK_LOG B1.3, shots/b1-smart-dim.png |
| P1 | **The bare export name still goes to HOME** after browsing in the dialog. The headless WP4 test claims this is fixed, so the GUI must use a different path. | WALK_LOG A7 (both sx-025 and sx-026) |
| P1 | **The blank comes out mirrored** (head on −X), even with the head circle clicked to the right on screen. Check the screen-to-sketch X direction on a ground sketch from the default view. | Checker flipX on wrench-b1.3mf (sx-025 and sx-026) |
| P1 | The finish-bar `D` field and the sketch radius blank look alike and sit next to each other. Typing a radius can land in D (`Extrude 22.5 mm`). The `Exit Sketch` label is covered by the dim field. | WALK_LOG B1.2, screenshot top-left |
| P2 | Overlapping dimension labels in the jaw sketch are unreadable. Retrying a centreline leaves the old one in place. | shots/b2-cut-failed.png |

Score: 6/10. The nut, blank, trim, and face pick work. The jaw cut, centre-distance dimension, export folder, and blank orientation are open.

**Do not recritique this hash: 3eb4f031 / b0130a67.**
