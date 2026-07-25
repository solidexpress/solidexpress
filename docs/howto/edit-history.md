# Edit history: timeline, rollback, constraints, dimensions

Goal: use the parametric surfaces the way a SolidWorks / Fusion / Onshape user
expects — scrub the timeline with a rollback bar, read failure badges, edit
sketch dimensions by clicking them, and manage constraints as visible badges.

## Timeline (left dock)

1. Every feature row shows a **type icon** (box, extrude, fillet, …), a
   suppress checkbox, and the name. Double-click the name (or the pencil) to
   rename; **drag a row** onto another to reorder it. Dependency-blocked drops
   flash the row red and leave the order unchanged.
2. The **`═══ rollback ═══` bar** sits at the end of the timeline. Drag it
   onto a feature to roll back *before* that feature: everything below the bar
   dims and its geometry disappears, exactly like the SolidWorks rollback bar
   or dragging the Fusion timeline scrubber. Double-click the bar to roll to
   the end. Rollback is undoable (Ctrl+Z) and persists in the saved file.
3. If a parameter edit breaks regeneration, the edit is reverted and the
   offending row gets a red **!** badge — hover it for the kernel's error
   message. Fixing the parameters clears the badge.

## Sketch constraints and dimensions

1. Enter a sketch (select a face → **Sketch**). While drawing lines, a yellow
   **H / V / ◉ hint** follows the cursor whenever the segment would get an
   automatic horizontal / vertical / coincident relation on commit. The
   **Snap**, **Infer**, and **Auto-close** toolbar toggles control snapping (including perpendicular), auto-relations, and closing multi-line chains on finish.
2. Committed constraints appear as small **badges** beside their geometry
   (H, V, ∥, ⊥, =, ◉). With the Select tool, click a badge to select the
   constraint (it turns orange) and press **Del** to remove it.
3. The toolbar **DOF chip** counts remaining degrees of freedom: blue while
   under-constrained, green **Fully constrained** at zero, red
   **Over-constrained** when the solver reports conflicts — and the entities
   involved in the conflict draw red so you can see what to delete.
4. **Click a dimension label** to edit it in place: a small editor opens at
   the cursor; Enter commits and re-solves, and a value the solver cannot
   satisfy is rejected with a status message.

## What “good” looks like

- Rolling back hides later features' bodies; rolling to end restores them.
- A bad edit never silently reverts: the row is badged with the reason.
- Constraints are visible, clickable objects — not hidden solver state.
- Dimensions read like annotations but edit like fields.

Verified by `run_timeline_ux_tests.gd` / `run_infer_tests.gd`.
