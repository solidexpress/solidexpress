# Open in Slicer

SolidExpress can launch your preferred external slicer (PrusaSlicer, OrcaSlicer, Bambu Studio, or a custom executable) with a 3MF of the current document.

What happens:

- File → Open in Slicer exports one 3MF per body in the document (units = millimeter; 3MF metadata carries `sx:bed`, layer height, and `sx:min_wall`).
- The configured slicer executable is invoked with all exported `.3mf` file paths appended to the configured argument list.
- In headless runs and tests, no external process is required: the command that would be spawned is recorded to `user://slicer_last_command.txt`.

Configuration (user registry):

Edit `user://slicer.cfg` to register your slicer command. The simplest way is to let the app write it; you can also author the file manually:

```ini
[slicer]
executable="/usr/bin/prusa-slicer"
args=["--some-flag"]
```

- `executable`: absolute path to the slicer binary.
- `args`: optional JSON array of string arguments. The exported `.3mf` files are appended automatically.

Multi‑body documents:

- Each solid body is exported as its own `.3mf` alongside its body name (sanitized for filenames). The slicer is launched once with all per‑body files as arguments. This keeps body separation explicit in the slicer while preserving the existing single‑file 3MF export for File → Export 3MF.

Notes:

- File → Export 3MF is unchanged and continues to export the whole document to one `.3mf` with `unit="millimeter"` and `sx:bed` metadata.
- No slicer engine or printer profiles are embedded; the external slicer remains the destination for slicing, supports, and G‑code.

