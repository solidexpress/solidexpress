# Rung 8 failing — round 6 leftover

Test-and-fix on `cursor/rung-08-20261019`. Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

Round-3 items stay closed. Glyphs/J6 stay closed.

## Closed this round

Walk 7 A21/A23/A26. Confirm_all at `6530e5c` had A21 with no C pad (n=2, handle 3999, ring 398). Cause: ring/hex/handle DogLeg translated the C jaws off the elliptical arc. Hold the x<80 head after solve once a ring circle exists (`99100e1`). Walk 7 from row 1: **46/46**, C **1495.7**, ring **275.2**, boss **41692** / neck **42734** / final **38892**, bbox **281.450×54.590×10**, checkers **5/5 5/5 8/8**.

Tag `rung01_replan20_tag` 67/0: disjoint r=3 was dropped as a hex sliver (`kPadArea` 50). Keep disks that are themselves CircPads.

Wrench blank min X −10: always seal ground sketches; stale `[0,1]` after the third island skipped stadium seal.

Nut/polygon extrude: do not weld Tangent endpoints onto the circle (AF hex vertices). Distance pins still weld stadium contacts.

## Still DIAG, not a regression

wrench-t14 **18/22** is by-design DIAG (T=14). Grip slot / R10 / 1 mm fillet probes are the T=14 set.

A14 hex Power Trim still logs “Nothing trimmed” on some clicks; the 12-point still punches (A21 ring 275.2) via leftover-hex recovery.

## Open after confirm_all on `c30e61a`

In-suite `film_spanner` **12/7**: after handle trim n=2 (handle 3999.3 + ring 275.2, C gone). Isolated same binary **12/0**. Cause: C-head hold required a live Ø33 and snapshotted after trim. Closed in product by `f87eeced` (arm on any east profile; snapshot before trim). confirm-r7 in-suite film **12/0**.

Walk 7 A18: trim-at-C assert wants both ends at x=22.94. The 17° ellipse is not symmetric (y=+10 at 22.94, y=−10 at 23.93). Walk continued; A21 still had C 1495.7.

Walk 7 A26/A34: neck volume **42274** vs 42733 (1.1%); final **38432** vs 38782 (0.90%). Bbox 281.450 still green. A21 showed a leftover 1395.6 island next to the 1495.7 C. Three-try volume work in round 4 was reverted; log as finding, do not retry here.

Walks 1–6 and 8 godot-floor FAILs are the 262/1 film, not product rows.

confirm-r7 (`f87eeced`) is the retry from row 1. Do not start a third confirm on this VM.
