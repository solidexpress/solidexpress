# Rung 8 result — confirm-now

**Does not pass the bar.** One-clean `SX_JOBS=1 SX_WALK_JOBS=1 tools/confirm_all.sh` from row 1 (`--a15`, no restores) at `build/confirm-now`, HEAD `bf67c81` (product `e024beb`). Start 2026-10-22T07:31:02Z, end 2026-10-22T10:45:22Z. Walk rcs 1. Third full confirm this cycle (after `c30e61a` and confirm-r7). No PR.

| Bar | Count |
|---|---|
| Head sha | `bf67c81` / product `e024beb` |
| Walk 1 | **76/77** (A15 godot-floor only) |
| Walk 2 | **43/44** (A25 godot-floor) |
| Walk 3 | **45/46** (A26 godot-floor) |
| Walk 4 | **31/32** (A21 godot-floor) |
| Walk 5 | **35/36** (A25 godot-floor) |
| Walk 6 | **35/46** (5 FAIL + 6 runner-gap). A27 sweep boolean failed; 3MF open 627/183018 |
| Walk 7 | **27/46** (14 FAIL + 5 blocked). A9 r=**13.64**; A10 mouth open; A18 strip PASS; A21 PASS C **1404.9** n=6 ring **275.2**; A22 one-body FAIL; A23–A26 blocked |
| Walk 8 | **47/48** (A37 godot-floor) |
| `check_rung05` | **10/10** (walk 5 final) |
| `check_rung06` | no final checker (sweep failed) |
| `check_rung07` | no boss/neck/final (A22 blocked) |
| `check_rung08` | pin **3/3**, pipes **5/5**, bolted **7/7**, final **10/10** |
| Other checkers | wrench-t14 **18/22 DIAG** (T=14) |
| Headless | **262/1** (`film_spanner` **4/2**, C ellipse stayed closed n=1 area **2159.8**). Isolated film on this binary was **12/0** |
| Kernel | **482/0** (11354 assertions) |
| Lint | **266** |
| Critique | not re-scored this round |

## C-pad / mouth (one line)

C-head circle-only hold kept walk-7 A21 C present (**1404.9**, not 1496) and A18 strip green, but in-suite `film_spanner` left the ellipse closed (**2159.8**) so godot is 262/1; A9 R15 undersized (**13.64**) then A22 fuse left a single extrude (vol 16800).
