# Rung 8 failing — round 7

Test-and-fix on `cursor/rung-08-20261019` head `e024beb8`. Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

No clean `confirm_all` from row 1 this round. wrench-t14 **18/22** stays DIAG (T=14).

## Remaining

### film_spanner in-suite C pad (original item)

Isolated dummy+clean-HOME **12/0**: after handle trim n=3 C **1495.8** ring **275.2** handle **3999.2**, bbox **281.450×54.591×10**, `check_rung07` **8/8**.

Same binary after `film_hexkey` (own HOME, own Godot process): **12/7**, after handle trim **n=2** (handle 3999.2 + ring 275.2, C gone, arc=1), R30 `limit 10.215; 6.000 mm vertical at (22.944, 10.000)`, bbox **233.56×33**.

This VM hexkey-then-spanner (`bf67c81`): hexkey **8/0**, spanner **12/0**, n=3 C **1494.5**. Flake not reproduced on a two-suite sequence.

Per-suite HOME rules out preferences. Separate processes rule out SketchMode/solver singletons. Shared `game/.godot` import cache (or intra-sketch trim/solve flake that shows up on a warm run) remains. C-head now: arm on first ring circle, keep `_c_head_armed` if hex trim drops Ø33, snapshot **before** Power Trim, restore at 0 mm. East-x (A9 R15 freeze) and golden-from-A11 (A21 n=2) were reverted.

### Walk 7 A26 / A34 / N4 volume

From row 1 at `e024beb8`: **43/46**. A9 r=15.006, A18 strip, A21 C **1495.7** handle **3999.3** ring **398.2**, A23 boss **5/5** bbox **281.450×54.590×10**.

- A26 neck vol **42154** vs 42733 (4/5, bbox still 281.450)
- A34 final vol **38312** vs 38782
- N4 reopen of that final

A21 ring **398** (hex not punched in-sketch; leftover-hex recovery adds sketch 4 / extrude 5). Round-4 volume retries were reverted; do not loosen bands.

## Closed / not remaining

Walk 7 A21 C pad on this sweep (1495.7). confirm-r7 walks 1–6 **77/44/46/32/36/46**, walk 8 **48/48**, godot **262/0** (pre-sweep binary). Glyphs/J6 stay closed.

Golden-hold walk 7 on this VM (`238949b`) finished **26/36** (5 FAIL + 4 blocked + runner-gap): A21 n=6 no C. Not remaining on current `e024beb` sweep.
