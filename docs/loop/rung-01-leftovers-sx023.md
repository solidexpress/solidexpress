# Rung 1 leftovers from sx-023 (build 4719c431, main @ c967f4e5): GUI walk FAIL, 6/10

After replan-2 (#59–#67) typed digits, chip layout, empty-sketch confirm, and export path status
work in the real GUI. Nut checker **6/7** (only thickness wrong). Wrench blank still fails open
profile → Box fallback. Headless local **238/20** (not the claimed 238/0). Full critique:
`/workspace/sx-023/CRITIQUE.md`. Prior: `LEFTOVERS-sx022.md` / replan-2.

Root causes, fixes, and acceptance checks are in [`rung-01-replan-3.md`](rung-01-replan-3.md).

## P0

1. **Finish-bar Distance typed 7.5 must produce Extrude thickness 7.5.**
   - GUI nut still **20.0** thick after Extrude. Status never showed a committed 7.5 distance.
   - Fix: Distance spin select-all + commit on Enter; Extrude must read the live spin value
     (not a cached default 20). Visible readout of the distance Extrude will send.
   - Acceptance: GUI types 7.5 (pre-click optional), Extrude → 3MF Z=7.5±0.2; checker nut 7/7.
   - Files: `sketch_context_chrome.gd`, finish-extrude path in `main.gd`.

2. **Wrench blank must Extrude closed after handout tangents (no open-profile).**
   - Exact status: `Extrude failed — open profile. Close it (or set Thin wall > 0)`.
   - Circles Ø20 @ origin + Ø45 @ (200,0) + upper/lower tangent lines look closed but Extrude
     refuses. Inference/tangent/on-circle must leave a closed wire Extrude accepts, or the
     status must identify the open vertex.
   - Acceptance: GUI B1 → Extrude Blind 10 → solid 232.5×45×10 without Thin and without Box.
   - Files: sketch close/validation, `sketch_mode.gd`, Extrude profile gather, snaps/tangent.

3. **Headless e2e honesty (238/20 locally vs claimed 238/0).**
   - Local OCCT-8 run fails fillet limit 1.250, open-mesh 3MF on wrench exports, jaw angle after
     AF21, timeline fillet count. CI/#66 must not claim green while this path fails.
   - Fix product (fillets/mesh) and/or stop cheating in the harness. Never weaken checker.
   - Files: `tests/run_rung01_wrench.gd`, fillet/kernel paths, 3MF export closed-mesh gate.

4. **Up To Surface bottom-face pick — still GUI-unverified.**
   - Blocked by #2. Keep P0 until critique shows pick → through jaw with Extrude gated on face.
   - Files: `sketch_context_chrome.gd`, `viewport_interaction.gd`.

5. **Timeline / property Distance 10→14 must stick.**
   - `wrench-t14.3mf` still Z=10 after editing depth to 14 on the fallback Box.
   - Acceptance: edit Distance 14, deselect/Enter keeps, export thick check 4/4.
   - Files: property panel / timeline extrude edit.

## P1

6. FileDialog: absolute path in name field must replace, not append (preselect basename already works).
7. After open-profile fail, do not encourage Insert Box as the recovery path in docs/tests.

## Out of scope / already good

- Camera keys vs sketch digits (WP6/#60).
- Chip/finish-bar layout at 1280×800 (WP1/#63).
- Empty-sketch Exit confirm (WP4/#64+#67).
- Nut AF 20 / AC 23.094 / bore Ø10 / closed mesh.
- Export status `Exported 3MF → <path>`.
