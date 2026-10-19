#!/usr/bin/env python3
"""Frozen row-id order for the split walk package."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import walk.app  # noqa: E402, F401
import walk.app02  # noqa: E402, F401
import walk.app03  # noqa: E402, F401
import walk.app04  # noqa: E402, F401
import walk.app05  # noqa: E402, F401
import walk.app06  # noqa: E402, F401
import walk.app07  # noqa: E402, F401
from walk import registry  # noqa: E402
from walk.expect import CHECKS, State, gate  # noqa: E402
from walk.rung import Expect  # noqa: E402

# 75 checklist ids in registration order (chunks 1–6). Plus two variant walks = 77.
FROZEN_ROWS = [
    "N22", "A1", "A2", "N7", "L1", "A3", "L5", "A4", "L6", "L10",
    "A5", "N12", "A5b", "L8", "L11", "N17",
    "A7", "L2", "A6", "N4", "A7b", "A8r", "A8w", "A8", "N5", "N25", "A8b", "N8a",
    "A9", "L4", "N1a", "N21", "N21b", "N26", "L12", "N24", "N24b", "A17",
    "A9c", "N1b", "N20", "A9b",
    "A16", "N6", "A11a", "N10", "N18",
    "A11b", "N2", "L3", "A11c", "N3", "A11d", "A11e", "A11f", "N15", "N13",
    "N16", "N19", "N23",
    "A12", "N11", "A13b", "A13d", "A13", "A13c", "N9", "L7", "N8b", "N14",
    "A10", "A10b", "A14", "L9", "A15",
]
FROZEN_VARIANTS = ("A8b-variant-walk", "A9-variant-walk")
FROZEN_CHUNKS = {
    1: FROZEN_ROWS[0:16],
    2: FROZEN_ROWS[16:28],
    3: FROZEN_ROWS[28:42],
    4: FROZEN_ROWS[42:47],
    5: FROZEN_ROWS[47:60],
    6: FROZEN_ROWS[60:75],
}


# 44 checklist ids. Chunks are the slices in docs/loop/rung-02-plan.md.
FROZEN_ROWS_02 = [
    "N1", "A1", "A2", "L1", "A3", "N2", "A4", "L2", "N3", "A5", "A6",
    "A7", "L3", "A8", "N4", "N5", "A9",
    "A10", "L4", "N6", "N7", "A11", "A12",
    "A13", "A14", "L5", "A15", "A16", "N8", "A17", "A18", "A19", "L6", "N9", "A20", "N10", "A21",
    "A22", "A23", "N11", "A24", "N12", "L7", "A25",
]
FROZEN_CHUNKS_02 = {
    1: FROZEN_ROWS_02[0:11],
    2: FROZEN_ROWS_02[11:17],
    3: FROZEN_ROWS_02[17:23],
    4: FROZEN_ROWS_02[23:37],
    5: FROZEN_ROWS_02[37:44],
}


# 46 checklist ids. Chunks are the slices in docs/loop/rung-03-plan.md.
FROZEN_ROWS_03 = [
    "N1", "A1", "A2", "L1", "A3", "N2", "A4", "A5",
    "A6", "L2", "A7", "A8", "N3", "A9", "A10",
    "A11", "A12", "L3", "N4", "A13", "N5", "A14", "L4", "A15",
    "A16", "L5", "A17", "N6", "A18", "N7", "N8", "A19", "A20",
    "A21", "L6", "N9", "A22", "N10", "A23", "L7", "A24", "N11",
    "A25", "N12", "L8", "A26",
]
FROZEN_CHUNKS_03 = {
    1: FROZEN_ROWS_03[0:8],
    2: FROZEN_ROWS_03[8:15],
    3: FROZEN_ROWS_03[15:24],
    4: FROZEN_ROWS_03[24:33],
    5: FROZEN_ROWS_03[33:42],
    6: FROZEN_ROWS_03[42:46],
}


# 32 checklist ids. Chunks are the slices in docs/loop/rung-04-plan.md.
FROZEN_ROWS_04 = [
    "N1", "A1", "A2", "L1", "A3", "A4", "N2", "A5", "L2", "A6",
    "A7", "A8", "L3", "A9", "A10", "L4", "A11", "N3", "A12", "L5", "A13", "A14",
    "N4", "A15", "A16", "A17", "A18", "A19", "L6", "A20", "N5", "A21",
]
FROZEN_CHUNKS_04 = {
    1: FROZEN_ROWS_04[0:10],
    2: FROZEN_ROWS_04[10:22],
    3: FROZEN_ROWS_04[22:32],
}


# 36 checklist ids. Chunks are the slices in docs/loop/rung-05-plan.md.
FROZEN_ROWS_05 = [
    "N1", "A1", "A2", "L1", "A3", "A4", "A5", "N2", "A6", "A7",
    "A8", "A9", "A10", "A11", "A12", "L2", "A13", "L3", "N3", "A14", "A15", "A16",
    "N4", "A17", "A18", "L4", "A19", "A20", "A21",
    "A22", "N5", "A23", "L5", "A24", "N6", "A25",
]
FROZEN_CHUNKS_05 = {
    1: FROZEN_ROWS_05[0:10],
    2: FROZEN_ROWS_05[10:22],
    3: FROZEN_ROWS_05[22:29],
    4: FROZEN_ROWS_05[29:36],
}


# 46 checklist ids. Chunks are the slices in docs/loop/rung-06-plan.md.
FROZEN_ROWS_06 = [
    "N1", "A1", "A2", "L1", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "N2",
    "A10", "A11", "A12", "L2", "A13", "A14", "A15",
    "A16", "A17", "A18", "A19", "A20", "A21", "A22", "L3", "A23",
    "N3", "A24", "A25", "A26", "A27", "A28", "L4", "A29",
    "A30", "A31", "N4", "A32", "A33", "A34", "L5", "A35", "N5", "A36",
]
FROZEN_CHUNKS_06 = {
    1: FROZEN_ROWS_06[0:19],
    2: FROZEN_ROWS_06[19:28],
    3: FROZEN_ROWS_06[28:36],
    4: FROZEN_ROWS_06[36:46],
}


# 46 checklist ids. Chunks are the slices in docs/loop/rung-07-plan.md.
FROZEN_ROWS_07 = [
    "N1", "A1", "A2", "L1", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10", "L2",
    "A11", "A12", "A13", "A14", "A15", "A16", "A17", "A18", "L3", "A19", "A20",
    "N2", "A21", "A22", "A23", "A24", "A25", "A26", "L4", "A27",
    "A28", "N3", "A29", "A30", "A31", "A32", "A33", "A34", "A35", "L5", "A36", "N4", "A37",
]
FROZEN_CHUNKS_07 = {
    1: FROZEN_ROWS_07[0:13],
    2: FROZEN_ROWS_07[13:24],
    3: FROZEN_ROWS_07[24:33],
    4: FROZEN_ROWS_07[33:46],
}


class WalkRegistryTests(unittest.TestCase):
    def test_frozen_id_list_is_registry_order(self) -> None:
        self.assertEqual(list(registry.RUNG1.rows), FROZEN_ROWS)
        self.assertEqual(tuple(registry.RUNG1.variants), FROZEN_VARIANTS)
        self.assertEqual(len(registry.RUNG1.rows) + len(registry.RUNG1.variants), 77)

    def test_every_id_has_a_chunk(self) -> None:
        for rid in FROZEN_ROWS:
            chunk = next(n for n, rows in registry.RUNG1.chunks.items() if rid in rows)
            self.assertEqual(chunk, next(n for n, rows in FROZEN_CHUNKS.items() if rid in rows))

    def test_chunks_match_frozen_slices(self) -> None:
        self.assertEqual({n: list(rows) for n, rows in registry.RUNG1.chunks.items()}, FROZEN_CHUNKS)
        flattened = [rid for n in sorted(registry.RUNG1.chunks) for rid in registry.RUNG1.chunks[n]]
        self.assertEqual(flattened, FROZEN_ROWS)

    def test_handlers_cover_rows_and_variants(self) -> None:
        for rid in FROZEN_ROWS:
            handler = registry.RUNG1.handlers[rid]
            self.assertTrue(callable(handler))
            self.assertEqual(handler.__name__, "row_" + rid)
        for rid in FROZEN_VARIANTS:
            self.assertTrue(callable(registry.RUNG1.variants[rid]))

    def test_rung2_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG2", None)
        self.assertIsNotNone(rung, "rung 2 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_02)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_02)
        self.assertEqual(len(FROZEN_ROWS_02), 44)
        for rid in FROZEN_ROWS_02:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
        self.assertEqual(rung.checker, "check_rung02.py")
        self.assertEqual(rung.checkpoints[2], "box.sxp")

    def test_rung3_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG3", None)
        self.assertIsNotNone(rung, "rung 3 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_03)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_03)
        self.assertEqual(len(FROZEN_ROWS_03), 46)
        for rid in FROZEN_ROWS_03:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
            self.assertEqual(rung.handlers[rid].__name__, "row_" + rid)
        self.assertEqual(rung.checker, "check_rung03.py")
        self.assertEqual(rung.checkpoints[2], "base.sxp")
        self.assertEqual(rung.checkpoints[5], "rounded.sxp")

    def test_rung4_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG4", None)
        self.assertIsNotNone(rung, "rung 4 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_04)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_04)
        self.assertEqual(len(FROZEN_ROWS_04), 32)
        for rid in FROZEN_ROWS_04:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
            self.assertEqual(rung.handlers[rid].__name__, "row_" + rid)
        self.assertEqual(rung.checker, "check_rung04.py")
        self.assertEqual(rung.checkpoints[2], "hex.sxp")
        self.assertEqual(rung.checkpoints[3], "path.sxp")

    def test_rung5_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG5", None)
        self.assertIsNotNone(rung, "rung 5 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_05)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_05)
        self.assertEqual(len(FROZEN_ROWS_05), 36)
        for rid in FROZEN_ROWS_05:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
            self.assertEqual(rung.handlers[rid].__name__, "row_" + rid)
        self.assertEqual(rung.checker, "check_rung05.py")
        self.assertEqual(rung.checkpoints[2], "shelled.sxp")
        self.assertEqual(rung.checkpoints[3], "cut.sxp")
        self.assertEqual(rung.checkpoints[4], "reshell.sxp")

    def test_rung6_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG6", None)
        self.assertIsNotNone(rung, "rung 6 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_06)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_06)
        self.assertEqual(len(FROZEN_ROWS_06), 46)
        for rid in FROZEN_ROWS_06:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
            self.assertEqual(rung.handlers[rid].__name__, "row_" + rid)
        self.assertEqual(rung.checker, "check_rung06.py")
        self.assertEqual(rung.checkpoints[2], "revolve.sxp")
        self.assertEqual(rung.checkpoints[3], "path.sxp")
        self.assertEqual(rung.checkpoints[4], "sweep.sxp")

    def test_rung7_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG7", None)
        self.assertIsNotNone(rung, "rung 7 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_07)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_07)
        self.assertEqual(len(FROZEN_ROWS_07), 46)
        for rid in FROZEN_ROWS_07:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
            self.assertEqual(rung.handlers[rid].__name__, "row_" + rid)
        self.assertEqual(rung.checker, "check_rung07.py")
        self.assertEqual(rung.checkpoints[3], "sketch.sxp")
        self.assertEqual(rung.checkpoints[4], "neck.sxp")

    def test_gate_walks_the_check_table(self) -> None:
        self.assertEqual(list(CHECKS), ["mode", "sketch", "bodies", "bbox", "timeline", "finish_bar"])
        state = State(
            status="x", sketch_active=False, n_circles=0, n_lines=1, circle_span=0,
            n_bodies=0, bbox_x=10, finish_op="", finish_end="", popup_text="",
            timeline="", dim_texts="",
        )
        reasons = gate(state, Expect(blocker="A1", mode="sketch", sketch={"min_lines": 4}))
        self.assertEqual(reasons, ["sketch not active status='x'", "lines=1"])
        self.assertEqual(registry.RUNG1.expectations["A2"].mode, "sketch")

    def test_suite_check_counts_reads_past_80k(self) -> None:
        from walk.gates import suite_check_counts

        filler = ("status-trace " + ("x" * 200) + "\n") * 500
        log = (
            "rung01 replan19 keys\n"
            + filler
            + "157 checks, 0 failures\n"
            "Godot Engine v4.7.stable\n"
            "rung01 wrench walk (replan-6 WP4 sx-026 sequence)\n"
            + filler
            + "711 checks, 0 failures\n"
        )
        self.assertGreater(log.find("157 checks"), 80_000)
        self.assertEqual(suite_check_counts(log, "rung01 replan19 keys"), (157, 0))
        self.assertEqual(suite_check_counts(log, "rung01 wrench walk"), (711, 0))
        self.assertIsNone(suite_check_counts(log, "rung01 replan19 shield"))

    def test_run_tier_uses_confirm_cache(self) -> None:
        import os
        import tempfile
        from unittest import mock
        from walk.gates import run_tier

        class FakeWalk:
            repo = str(ROOT)

        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "godot.log").write_text("cached-tier\n", encoding="utf-8")
            Path(tmp, "godot.rc").write_text("0\n", encoding="utf-8")
            with mock.patch.dict(os.environ, {"SX_CONFIRM_DIR": tmp}):
                with mock.patch("walk.proc.run") as run:
                    got = run_tier(FakeWalk())
        run.assert_not_called()
        self.assertEqual(got.returncode, 0)
        self.assertEqual(got.stdout, "cached-tier\n")

    def test_resume_mid_chunk_replays_prefix_or_restores_snapshot(self) -> None:
        from walk.checkpoint import plan_resume
        from walk.rung import Rung

        chunks = {
            1: ["N1", "A1", "A10", "L2"],
            2: ["A11", "A16", "A20"],
            3: ["N2", "A21", "A24", "A27"],
            4: ["A28", "A36"],
        }
        rows = tuple(rid for group in chunks.values() for rid in group)
        rung = Rung(
            name="rung07",
            checker="check_rung07.py",
            chunks=chunks,
            checkpoints={3: "sketch.sxp", 4: "neck.sxp"},
            expectations={},
            rows=rows,
            handlers={rid: (lambda self: None) for rid in rows},
        )
        first = plan_resume(rung, "N1", set())
        self.assertIsNone(first.restore_chunk)
        self.assertIsNone(first.restore_file)
        self.assertEqual(first.replay, ())

        mid1 = plan_resume(rung, "A10", set())
        self.assertIsNone(mid1.restore_chunk)
        self.assertEqual(mid1.replay, ("N1", "A1"))

        chunk3 = plan_resume(rung, "N2", {"sketch.sxp"})
        self.assertEqual(chunk3.restore_chunk, 3)
        self.assertEqual(chunk3.replay, ())

        mid3 = plan_resume(rung, "A24", {"sketch.sxp"})
        self.assertEqual(mid3.restore_chunk, 3)
        self.assertEqual(mid3.replay, ("N2", "A21"))

        snap = plan_resume(rung, "A24", {"sketch.sxp", "ckpts/A21.sxp"})
        self.assertEqual(snap.restore_file, "ckpts/A21.sxp")
        self.assertEqual(snap.replay, ())

        no_ckpt = plan_resume(rung, "A16", set())
        self.assertIsNone(no_ckpt.restore_chunk)
        self.assertEqual(no_ckpt.replay, ("N1", "A1", "A10", "L2", "A11"))

    def test_resume_open_uses_ckpt_parent_dir(self) -> None:
        import tempfile
        from pathlib import Path

        from walk.checkpoint import resolve_open_parts

        with tempfile.TemporaryDirectory() as tmp:
            ck = Path(tmp) / "ckpts"
            ck.mkdir()
            (ck / "A23.sxp").write_text("sxp", encoding="utf-8")
            directory, filename = resolve_open_parts(tmp, "ckpts/A23.sxp")
            self.assertEqual(filename, "A23.sxp")
            self.assertEqual(Path(directory), ck)
            abs_dir, abs_name = resolve_open_parts(tmp, str(ck / "A23.sxp"))
            self.assertEqual(abs_name, "A23.sxp")
            self.assertEqual(Path(abs_dir), ck)

    def test_click_budget_counts_press_and_key(self) -> None:
        from walk.click_budget import check_log, count_trace

        text = (
            "[input-trace] t=1.0 press (10,10) sketch shift=0 additive=0\n"
            "[key-trace] t=1.1 key=A unicode=97 pressed=1 echo=0 accepted=1 focus=\n"
            "[key-trace] t=1.2 key=A unicode=97 pressed=1 echo=1 accepted=0 focus=\n"
        )
        got = count_trace(text)
        self.assertEqual(got, {"clicks": 1, "keys": 1, "actions": 2})
        ok, note = check_log(text, "ubc_wrench", {"ubc_wrench": {"max_actions": 1}})
        self.assertFalse(ok)
        self.assertIn("budget 1", note)
        ok, _ = check_log(text, "ubc_wrench", {"ubc_wrench": {"max_actions": 2}})
        self.assertTrue(ok)


if __name__ == "__main__":
    unittest.main()
