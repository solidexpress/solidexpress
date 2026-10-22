# Rung 8 result — confirm-hex

**Does not pass the bar.** One-clean `SX_JOBS=1 SX_WALK_JOBS=1 tools/confirm_all.sh` from row 1 (`--a15`, no restores) at `build/confirm-hex`, HEAD `b1afa64` (product `fed0a88`). Start 2026-10-22T18:31:14Z, end 2026-10-22T22:12:07Z. Isolated film on `92de9b9` was **12/0**. No PR.

| Bar | Count |
|---|---|
| Head sha | `b1afa64` / product `fed0a88` |
| Walk 1 | **76/77** (A15 godot-floor only) |
| Walk 2 | **43/44** (A25 godot-floor) |
| Walk 3 | **40/46** (N8/A19 fillet r=30 applied 9 edges; A20 r=1.5; A22 shell; N12; A26 floor) |
| Walk 4 | **31/32** (A21 godot-floor) |
| Walk 5 | **35/36** (A25 godot-floor) |
| Walk 6 | **45/46** (A36 godot-floor). Sweep **7/7** |
| Walk 7 | **42/46**. A9 R15, A18 strip, A21 C **1495.7** ring **275.2**, A23 boss **5/5** bbox **281.450**. A26 neck **42370** (4/5). A34 vol **38528**. N4. A37 floor |
| Walk 8 | **47/48** (A37 godot-floor) |
| `check_rung05` | **10/10** (walk 5 final) |
| `check_rung06` | **7/7** (walk 6 final) |
| `check_rung07` | boss **5/5**, neck **4/5**, final **7/8** (volume) |
| `check_rung08` | pin **3/3**, pipes **5/5**, bolted **7/7**, final **10/10** |
| Other checkers | wrench-t14 **18/22 DIAG** (T=14) |
| Headless | **262/4** (`film_manifest_smoke` timeout 900s; in-suite `film_spanner` **12/5**; `replan16_suites` packaging clone; `rung07_boss` neck **41864**). Isolated unique-HOME film **12/0** C **1494.5** `check_rung07` **8/8** vol **38958** |
| Kernel | **483/0** (11370 assertions) |
| Lint | **266** |
| Critique | not re-scored this round |

## C-pad / volume (one line)

Walk-7 A21 C **1495.7** ring **275.2** and isolated film **12/0** hold; in-suite clone `film_spanner` still **12/5** (n=4 extra 2257.8, R30 `limit 26`). Neck/final volume sit one R30 crotch low (**42370** / **38528**) — logged after 3 tries, do not loosen.
