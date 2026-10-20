# Rung 8 progress

- HEAD was `61190fb`. Isolated full headless **262 run, 0 failed**.
- confirm-r3 in flight: godot **262/1** (`run_film_spanner_tests.gd` C-unopened 233.556×33). Isolated film after `c49c820` was 12/0. Kernel.rc 0. Walks from row 1 (`SX_WALK_JOBS=1`); do not rebuild `libsxcore.so` under them.
- Product: ViewCube stays IGNORE; ViewportInteraction owns the snap so Line/Trim under the 84 px cube cannot lose the GUI-before-`_input` race.
- Next after walks: cheap film + glyphs/jaw; then clean `confirm-r4` from row 1.
