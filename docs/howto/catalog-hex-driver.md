# Catalog: Hex‑driver blank (Wave 6.5)

Goal: Drop a hex‑driver blank (regular hexagonal prism) sized to across‑flats (AF). The AF tracks the `jaw_af` variable when present (Wave 6.2); when missing, a local 10 mm default is used.

Steps:
1. In the left rail, under the Primitives palette, click the hex‑driver icon.
2. A hexagonal bar is created as a real B‑rep body (sketch → extrude), Z‑up.
3. The across‑flats dimension is:
   - `jaw_af` when the variable exists, or
   - 10 mm when no variable is defined.

Notes:
- Mechanic‑tool entries are part of the in‑base catalog (not a paid Toolbox).
- Related blanks: hex socket (cylinder with internal hex), open‑end wrench head, and nozzle‑hex.
- All inserts are built with existing graph primitives and booleans — no separate kernel path. 
