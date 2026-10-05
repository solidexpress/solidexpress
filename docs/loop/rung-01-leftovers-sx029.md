# Leftovers after sx-029 (e85bd766 / replan-8 WP1–WP5)

Source: `/workspace/sx-029/CRITIQUE.md` — FAIL 7/10.

## Product

1. **P1 — Jaw chip highlight.** `Jaw` press shows correct status; `Center Three Point` chip not highlighted.
2. **P2 — Smart Dim second pick.** Plain second click replaces selection; Shift+click required for centre-distance 200.

## Environmental / process (no BUILD code unless newly reproducible on GPU)

3. Soft-GL (llvmpipe): after circle `radius: success`, viewport often stale + ghost chips; three rebuild attempts blocked A8–A14.
4. Walker: do not File→New mid-wrench without saving; soft-GL protocol (paste/slow type/Frame once then stop).

## Untested in GUI this round (re-check next critique)

A8–A9 jaw/trim/cut, A10 81% refuse, A11 slot/fillets, A12 wrench 28/28, A13 thick 4/4, A14 nut 7/7.

## Already green (do not re-break)

- Headless `run_rung01_wrench.gd` **397/0**; lint 4 replan8 clean
- GUI A1, A3–A7; blank.3mf **5/5**
- WP1–WP5 merged on main `e85bd766`

## Status in replan 9

| Pri | Leftover | Plan |
|---|---|---|
| P1 | 1. Jaw chip not highlighted | WP1: no variant chip was ever highlighted (Jaw is the first place a human needed it). Toggle chips, exactly one pressed = the active variant, new `tool_variant_changed` signal so `Jaw` (which sets the variant after the tool) highlights `Center Three Point`. |
| P2 | 2. Smart Dim second pick needs Shift | Misdiagnosis: the sketch click path never reads Shift and the second pick is already additive. The log shows a second click that **missed** (outside snap radius and 2.5 mm pick tolerance) cleared the pending first pick; the retry then became a new first pick. WP2: a miss keeps the first pick and says so, the first pick says what to click next, a same-circle second click is refused by name, `Esc` drops the pick instead of discarding the sketch. |
| P2 | 3. Soft-GL stale viewport after radius dim | Environmental. No driver or product WP. Walker protocol (status line is the truth, one Frame, `blank.sxp` checkpoint and reopen, radius field is `10` / `22.5`). |
| P1 | 4. (Walker) do not File→New mid-wrench | Root cause found: the 60 s autosave set `_last_saved_revision`, so File→New saw a clean document and discarded the blank with no prompt. WP3 fixes it. Walker order also changed: scratch rows A10 and A14 run last. |
| — | Untested in GUI: A8–A14 | Unchanged checklist rows, re-required for sx-030. |

Plan: [`rung-01-replan-9.md`](rung-01-replan-9.md).
