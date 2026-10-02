# Rung 1 leftovers from sx-020 (build 4b8ca9cf, main @ 63fc39f): GUI walk FAIL, 5/10

The headless walk passes 81/81 (nut 7/7, wrench 28/28, thick 4/4). It does that by
setting state in code. A real GUI walk got nut 1/7 (AC 40, 20 thick, no Ø10 bore,
open mesh). The wrench blank never extruded. The full critique was the sx-020
session writeup and is not in this repo. This file is that leftover list, kept
so the replan can cite it. Screenshot of the blank extrude: one circle on
screen, finish-bar spins clipped, status
`Extrude failed — is the profile closed? — extrude 2: profile: no usable open line chain for thin profile`.

## P0
1. **Up To Surface face pick.**
   - When End = Up To Surface, show a `Face:` selection box in the finish bar and arm a one-shot face pick. The next model-face click during the sketch sets it; highlight the face and name it.
   - Disable Extrude until a face is set.
   - Clear `up_to_face_id` on session start and on End change. Today it copies `view.selected_face` (the host top face), which gives a zero-depth cut, and the id is never cleared.
   - Add a face re-pick row to the extrude property panel.
   - Files: `game/scripts/sketch_context_chrome.gd` (193-202), `sketch_mode.gd` (`_store_up_to_face`), `viewport_interaction.gd` (`_input` pick mode), `property_panel.gd`.
2. **Dim blank typing.**
   - Problem: a second click on the already-focused blank places the caret and typing appends (`23.22.5`). Canvas clicks are consumed in `_input`, so the field keeps focus. An unparseable value silently commits the rubber-band value.
   - Fix: select all on every click/focus and on every new preview. Release focus on canvas click and on commit. On a parse failure, show a status error and do not commit.
   - Files: `sketch_context_chrome.gd`, `viewport_interaction.gd`, `main.gd` (`_on_sketch_dim_submitted`).
3. **Finish-bar legibility.**
   - Problem: the 72–88 px spins scroll to the tail, so "20.0 mm" reads "0.0 mm". Distance and Thin look identical.
   - Fix: make the fields wider (≥110 px scaled) and add labels (D, Thin). Put Thin behind a "Thin feature" toggle, off by default (SW). Show a badge when thin > 0.
   - File: `sketch_context_chrome.gd`.
4. **E2E test must drive the GUI.**
   - Rewrite `game/tests/run_rung01_wrench.gd` so it uses only:
     - key events typed into the dim blank
     - OptionButton picks via click/`item_selected`
     - a viewport click for the Up To Surface face
     - Smart Dimension label click + keystrokes for width 20 / Ø / 45°
     - File > Export 3MF through the FileDialog
   - No `set_finish_*`, `set_up_to_face`, `set_extrude_distance`, `LineEdit.text =`, or `doc.export_3mf()`.
   - Run the checker on the dialog-written files.

## P1
5. **Thin path on a circles-only sketch** (`features.cpp:940`, `sketch.cpp:791`).
   - Problem: thin>0 forces the lines-only builder, which gives "no usable open line chain for thin profile" under a "profile closed?" banner.
   - Fix: warn "Thin wall is on (N mm)" when closed contours exist and there is no line chain.
6. **3MF export writes an open mesh and reports success** (GUI nut: 29/55 bad edges).
   - Fix: check watertightness after tessellation and fail loudly.
   - Files: sxkernel 3MF writer, `main.gd:2653`.
7. **Nut AF / bore in the GUI.**
   - Problem: the hex came out circumradius 20 (Vertex, not Across Flats) and the bore is not a Ø10 circle. Cause unconfirmed; the operator gave no details.
   - Fix: keep the Polygon variant sticky, and have the e2e assert AF from typed `20`.
   - Files: `sketch_mode.gd`, `sketch_context_chrome.gd`.
8. **One Esc must drop TriBall + selection + gizmo from any focus.**
   - Problem: `main._unhandled_input` cancels TriBall and returns without clearing the selection. The full path in `viewport_interaction._gui_key` runs only with Interaction focus, and a LineEdit eats Esc.
   - Fix: one shared cancel stack, and release field focus first. Stop auto-arming TriBall on body select.
   - Files: `main.gd` (2824), `viewport_interaction.gd` (2967).
9. **Tangent-line blank tolerances.**
   - Problem: the region builder needs 1e-4, `_seal_tangent_bosses` 0.05, and inference 0.5. There is no tangent, quadrant, or on-circle snap.
   - Fix: add tangent and on-circle snaps, and solve before the region build.
   - Files: `sketch_mode.gd`, `sxkernel/src/sketch.cpp` (`contour_faces`).

## P2
10. **Ctrl+A in property-panel spins.**
    - Problem: the panel spins lack `select_all_on_focus`, the panel overlaps the left dock (clicks fall through), and Interaction maps Ctrl+A to scene select-all.
    - Fix: use `SxUi.configure_spin` with select-all, give the panel an opaque STOP background, and never select scene items while a text field has focus.
    - Files: `property_panel.gd`, `ui_spin.gd`, `viewport_interaction.gd`.
11. **Smart Dimension: single-line angle to horizontal (45°)**, and label-edit by click + typing.
    - Files: `sketch_mode.gd`, `viewport_interaction.gd`.
12. **Export 3MF dialog defaults.** Set `current_dir` to the last export dir (else the doc dir or ~) and `current_file` to `<doc>.3mf`.
    - File: `main.gd` (`_show_file_dialog`).
