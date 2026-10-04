# Rung 1 leftovers from sx-025 (build 33f20902, main @ 09fb9b22): GUI walk FAIL, 5/10

After replan-4 (#76–#80) the nut and wrench blank are makeable in the real GUI (nut checker
**7/7**; blank bbox ~232.5×45×10, closed). Typed Distance 7.5 sticks; dialog Cancel/Escape keep
the app alive; Smart Dimension 200 between centres works. The open jaw is blocked: Power Trim
fails on the Center-3-Point jaw rectangle, then a failed sketch regenerate sticks forever
(`Failed to update sketch`) — Undo, Exit Sketch, and File→New cannot recover; only killing the
process works. Headless WP4 claimed X11 walk **307/0** while GUI cannot finish B2. Full critique:
`/workspace/sx-025/CRITIQUE.md`. Prior: `LEFTOVERS-sx024.md` / replan-4.

Root causes, fixes, and acceptance checks are in [`rung-01-replan-5.md`](rung-01-replan-5.md).

## P0

1. **Sticky "Failed to update sketch" after a downstream open-loop regenerate.**
   - After Power Trim / cut left an open profile on extrude 2, logs show
     `regenerate stopped at feature extrude 2` / `edit sketch: extrude 2: profile: profile has an open loop`.
     Status `Failed to update sketch` persists through Undo, Exit Sketch, and File→New. Document is
     unrecoverable without restarting the app. Reproduced on B2r and again after fresh-app R2
     (Smart Dimension path led back into the same stuck state).
   - Fix: failed regenerate must not poison document/sketch session state; Undo / Exit / New must
     clear the failure and restore a usable empty or prior-good document.
   - Acceptance: force an open-loop sketch error, then Undo+Exit or File→New → status clear, new
     sketch works; no app restart required.
   - Evidence: WALK_LOG B2r.1–7, R2.2; logs/app.log lines 139–224; shots/b2r-*.png, r2-failure.png.

2. **Power Trim of the Center-3-Point jaw rectangle fails in the GUI.**
   - B2.11: rectangle at ~45.6°, centreline perpendicular through head centre, trim shaft-side →
     status `Trim failed` (expected `Trimmed open jaw`). Headless walk passes this; add a
     GUI-coordinate repro that matches the real click path.
   - Acceptance: GUI B2 Power Trim opens the jaw; status Trimmed open jaw; cut can proceed.
   - Files: Power Trim / trim tool handlers, Center Three Point rectangle geometry.

3. **Smart Dimension must not drive the sketch into the stuck state; nut Smart Dim must work.**
   - A5 nut: `coincident: failed` then `Measure cleared`.
   - R2 blank: Smart Dimension intermittently → `Failed to update sketch` again after a fresh app.
   - Acceptance: nut centre-to-flat + bore Smart Dim usable; blank centres 200 still works and never
     leaves an unrecoverable document.

## P1

4. **Up To Surface face pick** too easily cancelled (orbit needed; pick lost). Prefer a
   "pick bottom/opposite face" affordance or accept side-view click. Carry forward until B2 trim works.
5. **Bare Export filename saves to HOME**, not the folder the dialog shows. Full absolute path works.

## P2

6. Checker flags blank as mirrored (flipX) — confirm head at +X or relax checker.
7. Log spam: `focus_entered`/`tree_exited` connect/disconnect on root Window (likely WP1/WP3 first-key arming).

## Out of scope / already good (do not re-open unless regression)

- Typed numeric replace (replan-4 WP1) — B1 circles Ø20/Ø45 Pass.
- Finish-bar Distance 7.5 first Extrude — A6 Pass; nut 7/7.
- File/Export dialog Cancel and Escape — app stays alive (WP2).
- Smart Dimension centres 200 on blank — B1.4 Pass (WP3).
- Nut Polygon AF 20 / Ø10 bore / closed mesh.
- Do not recritique hash 09fb9b22 / 33f20902.
