# Leftovers sx-028 (replan-7 build 33672f7b)

## Leftovers (for replan-8)

1. **P1 — Jaw construction discoverability / Center Three Point jaw.** GUI walker could not find a jaw tool (rail + Insert). Headless walk succeeds, so either the control is mislabeled/hidden or the walk uses a path a human can't see. Make jaw reachable with a clear rail/tooltip path and a headless+GUI checklist row.
2. **P1 — Blank needs a connected profile.** Without two tangent lines the blank is two discs; shaft/slot/fillets have no body. Soft-GL often blocks typed radii — mouse path must still allow Line + tangent constraints reliably.
3. **P2 — Face pick needs three clicks when body already selected.** B2.1 PASS; B2.2 expected face on 2nd click but got body again. Esc does not clear body selection after Extrude.
4. **P2 — Soft-GL numeric fields.** Digits drop/reorder (`10`→`0.01`, path scramble). Known environmental; still blocks unattended GUI walks.
5. **P2 — Cut Up To Surface on incomplete profile** produced a collapsed solid without a clear refuse. Prefer a named refuse over silent wreckage when the contour is not a valid jaw.
6. **Carry:** Timeline Distance 14 not re-tested in GUI this round (headless thick 4/4). Dim auto-popup on centre picks still flaky.

## Status in replan 8

| Pri | Leftover | Plan |
|---|---|---|
| P1 | 1. Jaw / Center Three Point not discoverable | WP1: text labels on the sketch rail, a `Jaw` button, a hint on the three clicks. Walk (WP5) presses `Jaw`. |
| P1 | 2. Blank is two discs without a tangent web | WP2: `Shaft Lines` chip (two lines parallel to the centre line, tangent to the Ø20, ending on the Ø45). Walk (WP5) uses it. Common outer tangents are wrong for the handout (checker row `R10 fillet not oversized`). |
| P2 | 3. Face needs three clicks; Esc does not clear the body | Not reproducible headless (Esc clears; one-click palette Sketch path passes). WP4 fixes the real Esc bug (a pending first point discarded the whole sketch) and asserts the one-click face path. `select_ray` is not changed; see F4 in the plan. |
| P2 | 4. Soft-GL numeric fields | Environmental. Walker protocol in the plan; the blank no longer needs typed numbers after the circles. |
| P2 | 5. Cut Up To Surface wrecks the body without a refuse | WP3: a cut that removes more than 50 % of the body or nothing is refused with a named status and rolled back; the sketch stays open. |
| — | 6. Timeline Distance 14 GUI re-test; Dim auto-popup flaky | Checklist row A13 (steps in the plan). Popup flake: observed, not planned. |

Plan: [`rung-01-replan-8.md`](rung-01-replan-8.md).
