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

No open walk rows after the C-head hold.
