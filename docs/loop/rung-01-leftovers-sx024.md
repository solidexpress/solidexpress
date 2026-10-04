# Rung 1 leftovers from sx-024 (build 52d337f4, main @ f2770220): GUI walk FAIL, 4/10

After replan-3 (#68–#75) the nut is fully makeable in the real GUI (checker **7/7**). The wrench
cannot get past its first sketch: radius/dim input appends instead of replacing, so the Ø45 circle
cannot be typed. Typed finish-bar Distance still ignores 7.5 on first Extrude (Timeline edit was
needed). The app exited during a File dialog. Headless claimed **280/0** while the real GUI fails.
Full critique: `/workspace/sx-024/CRITIQUE.md`. Prior: `LEFTOVERS-sx023.md` / replan-3.

Root causes, fixes, and acceptance checks are in [`rung-01-replan-4.md`](rung-01-replan-4.md).

## P0

1. **Sketch dim blank / radius input must REPLACE prior text, not append.**
   - After first entry, typing again produced garbage like `2.522.522.5` / `2.522.5`. Second circle
     radius refused 22.5 and landed **r=2.0000 (Ø4)** instead of Ø20 / Ø45. Reproduced on two walks.
   - Fix: focused numeric field selects-all / clears on focus or first key; commit replaces value.
   - Acceptance: GUI B1 type circle r=10 then r=22.5 in same sketch → Ø20 and Ø45; no append.
   - Files: sketch numeric entry / LineEdit handlers (radius, Smart Dimension, similar).

2. **Finish-bar Distance typed 7.5 must Extrude at 7.5 on first Extrude (no Timeline rescue).**
   - GUI nut still Extruded **Blind 20.0000 mm** after typing 7.5; only Timeline Distance edit made
     Z=7.5. WP1/#72 is not fixed for real keyboard input.
   - Acceptance: type 7.5 in finish bar → Extrude → 3MF Z=7.5±0.2 without Timeline edit; nut 7/7.
   - Files: `sketch_context_chrome.gd`, finish-extrude path in `main.gd`, Distance spin commit.

3. **App must not exit during File / Export / Save dialog interaction.**
   - SolidExpress process died while interacting with Save/Export dialog (retry walk B2).
   - Acceptance: open Export/Save, type path, Cancel and Save — app stays alive; export works.
   - Files: FileDialog handlers, native dialog bridge, window close-on-dialog bugs.

4. **Headless / Godot e2e must drive the same X11 keyboard path as the real GUI.**
   - Claimed honest walk **280/0** while GUI fails on second dim entry and typed Distance.
   - e2e must cover: second numeric entry in same sketch (replace, not append); non-default typed
     Distance 7.5 on Extrude without injecting state; File dialog without crash.
   - Never weaken `check_rung01.py`. Do not claim green while GUI path fails.
   - Files: `tests/run_rung01_wrench.gd` and related GUI-input harness.

## P1

5. **Smart Dimension usable in GUI walk** (A5 was skipped; B1.4 not completed).
6. Wrench blank Extrude closed + Up To Surface face pick + Timeline Distance 10→14 — still needed
   once B1 sketch input works (carry forward from sx-023 if still broken after P0).

## Out of scope / already good

- Nut Polygon AF 20 / AC 23.094 / Ø10 bore / closed mesh / export to nut.3mf (checker 7/7).
- Camera keys vs sketch digits (replan-2).
- Chip/finish-bar layout at 1280×800.
- Empty-sketch Exit confirm.
- Do not recritique hash f2770220 / 52d337f4.
