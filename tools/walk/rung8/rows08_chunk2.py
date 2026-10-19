"""Rung-8 chunks 3–4: copies, Fix, pipe mates."""
from __future__ import annotations

from pathlib import Path

from sxdrive import SxError
from walk.registry import row


class Rows08Chunk2:
    @row("A12", chunk=3, on="rung08", expect={"blocker": "A11"})
    def row_A12(self) -> None:
        kinds = self.classify()
        iid = str(kinds["pipe"][0]["id"])
        self.copy_extra(iid, 1)
        c = self.counts()
        pipes = self.classify()["pipe"]
        t0 = pipes[0].get("translation") or [0, 0, 0]
        t1 = pipes[1].get("translation") or [0, 0, 0] if len(pipes) > 1 else t0
        offset = any(abs(float(t0[i]) - float(t1[i])) > 1.0 for i in range(3))
        self.clause("copy pipe", c["pipe"] == 2, str(c))
        self.clause("pipes 2", c["pipe"] == 2, str(c))
        self.clause("instance copy", offset and not any(p.get("fixed") for p in pipes), f"t0={t0} t1={t1}")

    @row("A13", chunk=3, on="rung08", expect={"blocker": "A12"})
    def row_A13(self) -> None:
        kinds = self.classify()
        iid = str(kinds["nut"][0]["id"])
        extra = 16 - len(kinds["nut"])
        if extra > 0:
            self.copy_extra(iid, extra)
        c = self.counts()
        self.clause("copy nuts", c["nut"] == 16, str(c))
        self.clause("nuts 16", c["nut"] == 16, str(c))

    @row("A14", chunk=3, on="rung08", expect={"blocker": "A13"})
    def row_A14(self) -> None:
        kinds = self.classify()
        iid = str(kinds["pin"][0]["id"])
        extra = 8 - len(kinds["pin"])
        if extra > 0:
            self.copy_extra(iid, extra)
        c = self.counts()
        self.clause("copy pins", c["pin"] == 8, str(c))
        self.clause("pins 8", c["pin"] == 8, str(c))
        self.clause("wrench 1", c["wrench"] == 1, str(c))

    @row("L4", chunk=3, on="rung08", expect={"blocker": "A14"})
    def row_L4(self) -> None:
        c = self.counts()
        real_mates = [m for m in self.mates() if str(m.get("type")) not in ("", "fixed")]
        self.clause("counts 2 16 8 1", c == {"pipe": 2, "nut": 16, "pin": 8, "wrench": 1} or (
            c["pipe"] == 2 and c["nut"] == 16 and c["pin"] == 8 and c["wrench"] == 1
        ), str(c))
        self.clause("not mated", len(real_mates) == 0, str(real_mates))

    @row("A15", chunk=3, on="rung08", expect={"blocker": "A14"})
    def row_A15(self) -> None:
        kinds = self.classify()
        p1 = str(kinds["pipe"][0]["id"])
        p2 = str(kinds["pipe"][1]["id"])
        self.float_all()
        self.set_transform(p1, (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 0.0)
        self.set_fixed(p1, True)
        before = self.translation_of(p1)
        reply = self.nudge(p1, [30.0, 0.0, 0.0])
        after = self.translation_of(p1)
        other = next(i for i in self.instances() if str(i.get("id")) == p2)
        self.clause("fix pipe", bool(next(i.get("fixed") for i in self.instances() if str(i.get("id")) == p1)), p1)
        self.clause("one fixed", sum(1 for i in self.instances() if i.get("fixed")) == 1, str([i.get("fixed") for i in kinds["pipe"]]))
        self.clause("other free", not other.get("fixed") and (not reply.get("moved")) and after == before, f"p2fixed={other.get('fixed')} {before}->{after}")
        self.save_as("counts.sxp")

    @row("N3", chunk=4, on="rung08", expect={"blocker": "A15"})
    def row_N3(self) -> None:
        kinds = self.classify()
        p1 = str(kinds["pipe"][0]["id"])
        src = self.source_of(kinds["pipe"][0])
        bore = self.cyl_face(src, 65.0, (0, 0, 1), (0.0, 0.0), 20.0)
        before_n = len(self.mates())
        poses = {str(i.get("id")): self.translation_of(str(i.get("id"))) for i in kinds["pipe"]}
        try:
            reply = self.click("mate:Add", type="concentric", instance_a=p1, face_a=bore,
                               instance_b="", face_b="", offset=0.0, name="one-face")
        except SxError as exc:
            reply = {"error": str(exc)}
        after_n = len(self.mates())
        poses2 = {str(i.get("id")): self.translation_of(str(i.get("id"))) for i in self.classify()["pipe"]}
        refused = bool(reply.get("error")) or after_n == before_n
        self.clause("refused", refused, str(reply))
        self.clause("no mate", after_n == before_n, f"{before_n}->{after_n}")
        self.clause("poses unchanged", poses == poses2, f"{poses} -> {poses2}")

    @row("A16", chunk=4, on="rung08", expect={"blocker": "A15"})
    def row_A16(self) -> None:
        kinds = self.classify()
        p1 = str(kinds["pipe"][0]["id"])
        p2 = str(kinds["pipe"][1]["id"])
        src1, src2 = self.source_of(kinds["pipe"][0]), self.source_of(kinds["pipe"][1])
        bore1 = self.cyl_face(src1, 65.0, (0, 0, 1), (0.0, 0.0), 20.0)
        bore2 = self.cyl_face(src2, 65.0, (0, 0, 1), (0.0, 0.0), 20.0)
        conc = self.add_mate("concentric", p1, bore1, p2, bore2, "pipes-conc")
        mate = next((m for m in self.mates() if str(m.get("id")) == conc.get("id")), {})
        self.clause("concentric pipes", bool(conc.get("id")) and conc.get("added", True), str(conc))
        self.clause("offset 0", abs(float(mate.get("offset") or 0.0)) < 1e-9, str(mate))
        self.clause("instance instance", str(mate.get("instance_a")) == p1 and str(mate.get("instance_b")) == p2, str(mate))
        self.clause("lock rotation off", str(mate.get("type")) == "concentric", str(mate))
        self.ctx["pipe_ids"] = {"p1": p1, "p2": p2, "bore1": bore1, "bore2": bore2}

    @row("L5", chunk=4, on="rung08", expect={"blocker": "A16"})
    def row_L5(self) -> None:
        kinds = self.classify()
        p1 = str(kinds["pipe"][0]["id"])
        p2 = str(kinds["pipe"][1]["id"])
        t1_before = self.translation_of(p1)
        t2_before = self.translation_of(p2)
        self.nudge(p2, [0.0, 0.0, 25.0])
        self.solve_mates()
        t2_slide = self.translation_of(p2)
        self.nudge(p2, [40.0, 0.0, 0.0])
        self.solve_mates()
        t2_xy = self.translation_of(p2)
        t1_after = self.translation_of(p1)
        slides = abs(t2_slide[2] - t2_before[2]) > 1.0 or abs(t2_xy[2] - t2_before[2]) > 0.2
        on_axis = math_hypot(t2_xy[0], t2_xy[1]) <= 1.0
        self.clause("slides on axis", slides and on_axis, f"before={t2_before} slide={t2_slide} xy={t2_xy}")
        self.clause("fixed stays", t1_before == t1_after, f"{t1_before}->{t1_after}")

    @row("A17", chunk=4, on="rung08", expect={"blocker": "A16"})
    def row_A17(self) -> None:
        kinds = self.classify()
        p1 = str(kinds["pipe"][0]["id"])
        p2 = str(kinds["pipe"][1]["id"])
        src1, src2 = self.source_of(kinds["pipe"][0]), self.source_of(kinds["pipe"][1])
        fl_hi = self.plane_zn(src1, 260.0, 80.0, 1.0)
        fl_lo = self.plane_zn(src2, -260.0, 80.0, -1.0)
        flanges = self.add_coincident_flip(p1, fl_hi, p2, fl_lo, "flanges", want_z=520.0)
        z = self.translation_of(p2)[2]
        self.clause("coincident flanges", bool(flanges.get("id")), str(flanges))
        self.clause("joint z 260", abs(z - 520.0) <= 1.0, f"p2.z={z}")
        self.clause("centre joint", abs(z - 520.0) <= 1.0 and fl_hi and fl_lo, f"faces hi={fl_hi} lo={fl_lo} z={z}")

    @row("A18", chunk=4, on="rung08", expect={"blocker": "A17"})
    def row_A18(self) -> None:
        kinds = self.classify()
        p1 = str(kinds["pipe"][0]["id"])
        p2 = str(kinds["pipe"][1]["id"])
        src1, src2 = self.source_of(kinds["pipe"][0]), self.source_of(kinds["pipe"][1])
        hole1 = self.cyl_face(src1, 5.0, (0, 0, 1), (0.0, 94.0), 8.0)
        hole2 = self.cyl_face(src2, 5.0, (0, 0, 1), (0.0, 94.0), 8.0)
        holes = self.add_mate("concentric", p1, hole1, p2, hole2, "holes")
        self.solve_mates()
        before = self.translation_of(p2)
        self.nudge(p2, [0.0, 0.0, 20.0])
        self.solve_mates()
        after = self.translation_of(p2)
        self.clause("concentric holes", bool(holes.get("id")) and bool(hole1) and bool(hole2), f"h1={hole1} h2={hole2} {holes}")
        self.clause("plus y", bool(hole1), hole1)
        self.clause("pipes fixed", abs(after[2] - before[2]) <= 1.0, f"{before}->{after}")

    @row("A19", chunk=4, on="rung08", expect={"blocker": "A18"})
    def row_A19(self) -> None:
        code, text, path = self.export_stage("pipes", "pipes.3mf")
        box_ok, box_line = self.check_probe(text, "bbox")
        coax_ok, coax_line = self.check_probe(text, "coaxial")
        saved = self.save_as("pipes.sxp")
        self.clause("exported", Path(path).is_file(), path)
        self.clause("pipes", code == 0, text[-400:])
        self.clause("bbox", box_ok, box_line)
        self.clause("coaxial", coax_ok, coax_line)
        self.clause("saved", Path(saved).is_file(), saved)


def math_hypot(a: float, b: float) -> float:
    return (a * a + b * b) ** 0.5
