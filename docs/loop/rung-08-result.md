# Rung 8 result — round 7

**Does not pass the bar.** Head `e024beb8`. No one-clean `confirm_all` from row 1 after the C-head sweep.

| Bar | Count |
|---|---|
| Head sha | `e024beb8` |
| Walk 1 | **77/77** (confirm-r7, pre-sweep) |
| Walk 2 | **44/44** (confirm-r7) |
| Walk 3 | **46/46** (confirm-r7) |
| Walk 4 | **32/32** (confirm-r7) |
| Walk 5 | **36/36** (confirm-r7) |
| Walk 6 | **46/46** (confirm-r7) |
| Walk 7 | **43/46** from row 1 at `e024beb8`. A21 C **1495.7**, A23 boss **5/5** bbox **281.450×54.590×10**. A26 neck **42154** (4/5). A34 **38312**. N4 reopen |
| Walk 8 | **48/48** (confirm-r7) |
| `check_rung05` | **10/10** (confirm-r7 units) |
| `check_rung06` | **7/7** |
| `check_rung07` | boss **5/5**, neck **4/5**, final volume fail |
| `check_rung08` | pin **3/3**, pipes **5/5**, bolted **7/7**, final **10/10** (confirm-r7) |
| Other checkers | wrench-t14 **18/22 DIAG** (T=14) |
| Headless | confirm-r7 **262/0**; isolated film_spanner **12/0**; after hexkey **12/7** |
| Lint | **266** (confirm-r7) |
| Critique | not re-scored this round |

## C-pad leak (one line)

C-head hold re-checked a live Ø33 after hex trim dropped it and `run_solve` snapshotted the pad *after* Power Trim, so a nick froze; session `_c_head_armed` + pre-trim restore keeps walk-7 C **1495.7**, but in-suite film after hexkey still n=2 (not HOME/singleton — shared `game/.godot` or trim flake).
