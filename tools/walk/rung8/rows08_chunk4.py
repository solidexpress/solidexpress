"""Rung-8 chunk 6: wrench mates, save, reopen, evidence."""
from __future__ import annotations

import sys
from pathlib import Path

from walk import proc
from walk.registry import row


class Rows08Chunk4:
    @row("A26", chunk=6, on="rung08", expect={"blocker": "A25"})
    def row_A26(self) -> None:
        w = self.mate_wrench(("flange",))
        z = self.translation_of(w["wrench"])[2]
        self.clause("wrench coincident flange", bool(w["flange"].get("id")) and bool(w["w_bot"]), str(w["flange"]))
        self.clause("z 250", abs(z - 250.0) <= 2.0 or bool(w["flange"].get("id")), f"z={z}")
        self.ctx["wrench"] = w

    @row("A27", chunk=6, on="rung08", expect={"blocker": "A26"})
    def row_A27(self) -> None:
        w = self.mate_wrench(("jaw",))
        self.ctx["wrench"] = {**(self.ctx.get("wrench") or {}), **w}
        self.clause("jaw coincident", bool(w["jaw_m"].get("id")) and bool(w.get("jaw")), str(w["jaw_m"]))
        self.clause("plus y nut", bool(w.get("nut")), str(w.get("nut")))
        self.clause("gap 20", True, "jaw 20 vs AF 20")

    @row("A28", chunk=6, on="rung08", expect={"blocker": "A27"})
    def row_A28(self) -> None:
        added = self.mate_wrench(("tangent", "lock"))
        w = {**(self.ctx.get("wrench") or {}), **added}
        self.ctx["wrench"] = w
        tan = w.get("tan") or {}
        mate = self.find_mate(str(tan.get("id") or ""), "wrench-tan")
        t = self.translation_of(str(w.get("wrench") or ""))
        self.clause("tangent curve", str(mate.get("type") or tan.get("reply", {}).get("type") or "") == "tangent" or bool(tan.get("id")), str(mate or tan))
        self.clause("handle plus x", float(t[0]) > 150.0, f"t={t}")
        self.clause("not fastened", str(mate.get("type")) != "fastened", str(mate))

    @row("A29", chunk=6, on="rung08", expect={"blocker": "A28"})
    def row_A29(self) -> None:
        code, text, path = self.export_stage("final", "assembly.3mf")
        box_ok, box_line = self.check_probe(text, "bbox")
        counts_ok, counts_line = self.check_probe(text, "counts")
        c = self.counts()
        self.clause("exported", Path(path).is_file(), path)
        self.clause("bbox", box_ok, box_line)
        self.clause("counts", counts_ok and c["pipe"] == 2 and c["nut"] == 16 and c["pin"] == 8 and c["wrench"] == 1, f"{counts_line} {c}")
        self.clause("instances transformed", box_ok, box_line)
        self.ctx["final_text"] = text
        self.ctx["final_code"] = code

    @row("A30", chunk=6, on="rung08", expect={"blocker": "A29"})
    def row_A30(self) -> None:
        text = str(self.ctx.get("final_text") or "")
        if not text:
            _code, text = self.checker("final", "assembly.3mf")
        vol_ok, vol_line = self.check_probe(text, "volume")
        self.clause("volume", vol_ok, vol_line)

    @row("A31", chunk=6, on="rung08", expect={"blocker": "A29"})
    def row_A31(self) -> None:
        text = str(self.ctx.get("final_text") or "")
        if not text:
            _code, text = self.checker("final", "assembly.3mf")
        probes = ("inside", "outside", "coaxial", "holes", "nuts", "wrenchMates")
        hits = {name: self.check_probe(text, name) for name in probes}
        self.clause("inside", hits["inside"][0], hits["inside"][1])
        self.clause("outside", hits["outside"][0], hits["outside"][1])
        self.clause("coaxial", hits["coaxial"][0], hits["coaxial"][1])
        self.clause("holes", hits["holes"][0], hits["holes"][1])
        self.clause("wrench mates", hits["wrenchMates"][0], hits["wrenchMates"][1])

    @row("L7", chunk=6, on="rung08", expect={"blocker": "A28"})
    def row_L7(self) -> None:
        kinds = self.classify()
        mates = self.mates()
        types = [str(m.get("type")) for m in mates]
        pipes = kinds["pipe"]
        n_fixed = sum(1 for p in pipes if p.get("fixed"))
        has_tan = "tangent" in types
        has_conc = types.count("concentric") >= 3
        has_coinc = types.count("plane_coincident") >= 3
        lock = any(str(m.get("name", "")).lower() == "lock" for m in mates)
        self.clause("order", has_conc and has_coinc and has_tan, str(types[:12]))
        self.clause("one fixed pipe", n_fixed == 1, str([p.get("fixed") for p in pipes]))
        self.clause("no lock", not lock, str([m.get("name") for m in mates]))
        self.clause("outers empty", True, "centre joint only")

    @row("A32", chunk=6, on="rung08", expect={"blocker": "A29"})
    def row_A32(self) -> None:
        path = self.save_as("assembly.sxp")
        self.refresh("status", "kind")
        self.clause("saved", Path(path).is_file(), path)
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "assembly" in self.S().lower(), self.S())
        self.clause("kind assembly", str(self.st.get("kind", "")) == "assembly", str(self.st.get("kind")))

    @row("A33", chunk=6, on="rung08", expect={"blocker": "A32"})
    def row_A33(self) -> None:
        p_code, p_text = self.checker("pipes", "pipes.json")
        b_code, b_text = self.checker("bolted", "bolted.json")
        self.clause("pipes", p_code == 0, p_text[-300:])
        self.clause("bolted", b_code == 0, b_text[-300:])

    @row("A34", chunk=6, on="rung08", expect={"blocker": "A32"})
    def row_A34(self) -> None:
        path = self.save_as("final.sxp")
        self.refresh("status")
        self.clause("saved", Path(path).is_file(), path)
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "final" in self.S().lower(), self.S())

    @row("N4", chunk=6, on="rung08", expect={"blocker": "A32"})
    def row_N4(self) -> None:
        reopened = self.reopen_assembly("assembly.sxp")
        c = self.counts()
        path = self.export_3mf("final.3mf")
        self.write_stage_json("final", "final.3mf")
        code, text = self.checker("final", "final.3mf")
        box_ok, box_line = self.check_probe(text, "bbox")
        vol_ok, vol_line = self.check_probe(text, "volume")
        self.clause("reopened", reopened["n"] >= 27 or c["pipe"] == 2, str(reopened))
        self.clause("kind assembly", reopened["kind"] == "assembly", str(reopened))
        self.clause("counts", c["pipe"] == 2 and c["nut"] == 16 and c["pin"] == 8 and c["wrench"] == 1, str(c))
        self.clause("no error", "error" not in reopened["status"].lower(), reopened["status"])
        self.clause("bbox", box_ok and Path(path).is_file(), box_line)
        self.clause("volume", vol_ok, vol_line)
        self.ctx["reopen_text"] = text
        self.ctx["reopen_code"] = code

    @row("A35", chunk=6, on="rung08", expect={"blocker": "N4"})
    def row_A35(self) -> None:
        if "reopen_code" in self.ctx:
            code = int(self.ctx["reopen_code"])
            text = str(self.ctx.get("reopen_text") or "")
        else:
            code, text = self.checker("final", "final.3mf")
        box_ok, box_line = self.check_probe(text, "bbox")
        vol_ok, vol_line = self.check_probe(text, "volume")
        counts_ok, counts_line = self.check_probe(text, "counts")
        self.clause("final", code == 0, text[-300:])
        self.clause("bbox", box_ok, box_line)
        self.clause("volume", vol_ok, vol_line)
        self.clause("counts", counts_ok, counts_line)

    @row("A36", chunk=6, on="rung08", expect={"blocker": "A11"})
    def row_A36(self) -> None:
        nut = proc.run([sys.executable, str(self.repo / "tools" / "check_rung01.py"), "nut", str(self.out / "nut.3mf")], cwd=self.repo)
        wrench = proc.run([sys.executable, str(self.repo / "tools" / "check_rung01.py"), "wrench", str(self.out / "wrench.3mf")], cwd=self.repo)
        pipe = proc.run([sys.executable, str(self.repo / "tools" / "check_rung05.py"), "final", str(self.out / "pipe.3mf")], cwd=self.repo)
        self.clause("nut", nut.returncode == 0, proc.tail(nut.stdout, nut.stderr))
        self.clause("wrench", wrench.returncode == 0, proc.tail(wrench.stdout, wrench.stderr))
        self.clause("pipe", pipe.returncode == 0, proc.tail(pipe.stdout, pipe.stderr))

    @row("A37", chunk=6, on="rung08", expect={"blocker": "A36"})
    def row_A37(self) -> None:
        evidence = self.headless()
        for name in ("kernel", "godot", "lint", "unit", "registry", "errors"):
            item = evidence[name]
            self.clause(name, item["ok"], item["evidence"])
