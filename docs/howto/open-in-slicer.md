# Open in Slicer

Goal: hand each body to your registered slicer as its own millimeter 3MF.

## Steps

1. Build one or more solids.
2. **File → Open in Slicer…** — pick (or Browse to) PrusaSlicer / Orca / Bambu / a custom executable; optional args.
3. Confirm. SolidExpress writes one `.3mf` per body under a temp folder and launches the command (or dry-runs in headless tests).

Headless / CI records the command under `user://slicer_last_command.txt`.

## Registry

Settings persist in `user://slicer.cfg` (also written by the dialog):

```ini
[slicer]
executable="/usr/bin/prusa-slicer"
args=["--some-flag"]
```

- `executable`: absolute path to the slicer binary.
- `args`: optional string arguments; exported `.3mf` paths are appended automatically.

## Notes

- File → Export 3MF is unchanged (whole document, `unit="millimeter"`, `sx:bed` metadata).
- No slicer engine is embedded — the external app remains the destination for supports and G-code.

Film: `open_in_slicer`.
