# Rung 8 failing — round 3

Test-and-fix on `cursor/rung-08-20261019`. Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

Confirm-r4 left three items. Glyphs/J6 and the rest of the old 17 are closed; do not re-open them.

## 1. Film C-unopened bbox flake (233.556 × 33)

`run_film_spanner_tests.gd` in the full headless tier (`--jobs nproc`) ends **233.556 × 33** (ring Ø33 + handle, C not in the body). Isolated `--jobs 1 --only '*film_spanner*'` is **12/0**, bbox 281.450 × 54.591 × 10.

Cause: a Line/Trim click for the C opening lands on ViewHud **Shade** / **Frame** (STOP). Interaction drops it as chrome; the ellipse stays closed, heads extrude only the Ø33. Dummy-renderer layout under load puts that UV on the HUD more often than a solo run.

Fix: Shade/Frame IGNORE while a draw tool is placing (item 2). Frame the opening UV, retry Trim C, then `SketchMode.trim_at` if the ellipse is still closed. Fail only when the ellipse stays closed (open-wire n=0 is not the flake). Do not loosen the bbox.

Cheap: `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '*film_spanner*'` then the same with `--jobs $(nproc)` in a full-tier confirm.

## 2. ViewHud Shade/Frame must IGNORE while placing

Cube IGNORE was not enough under confirm. `_control_blocks_at` still treats BaseButtons as chrome, so Shade/Frame eat Line/Trim on the model under the bottom-right HUD.

While `SketchMode.places_on_model()`: Shade, Frame, and Section are `MOUSE_FILTER_IGNORE`, and Interaction does not name them as `_over_chrome`. View strip (▼ / Save) stays STOP so Front view still opens. When not placing they are STOP (Shade still cycles display).

Cheap: `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '*visual_ux*'`

## 3. A15-class godot-log gates (walks r1 / r2)

Rung 1 **A15** and rung 2 **A25** read `SX_CONFIRM_DIR/godot.log`. Two parser bugs fire even when product rows are green:

1. `parse_tier` takes the last `suites: N run, M failed` substring. confirm_all appends stderr after the real summary; a stray inner match (N < 204) becomes the gate.
2. `suite_check_counts` truncates at the first `\nGodot Engine` after the banner. A mid-suite reprint hides the Catch2 line (`no checks line`).

`parse_tier` keeps the last line-anchored summary with N ≥ 204. `suite_check_counts` matches the banner at line start and does not drop the checks line across one Engine reprint.

Give a walk row three fix attempts, then log it as a finding and move on. Final `confirm_all` is one clean pass from row 1 (375 rows), checkers, headless **262/0**.
