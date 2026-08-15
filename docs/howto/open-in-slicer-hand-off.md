# Open in Slicer

Goal: hand each body to your registered slicer as its own millimeter 3MF.

## Steps

1. Build one or more solids.
2. **File → Open in Slicer…**
3. Pick (or Browse to) PrusaSlicer / Orca / Bambu / custom executable; optional args.
4. Confirm — SolidExpress writes one `.3mf` per body and launches (or dry-runs) the command.

Headless / CI records the command under `user://slicer_last_command.txt`.

Film: `open_in_slicer`. See also the longer note in this folder if present for registry details.
