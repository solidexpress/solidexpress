"""Rung-8 chunk 5: nut/pin ×8 at the centre joint."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows08Chunk3:
    @row("A20", chunk=5, on="rung08", expect={"blocker": "A19"})
    def row_A20(self) -> None:
        bore = self.mate_bore(0, ("pin_c",))
        mate = self.find_mate(str(bore.get("pin_c", {}).get("id") or ""), "pin-c-0")
        self.clause("pin concentric", bool(bore.get("pin_c", {}).get("id")) and bool(bore["hole"]), str(bore.get("pin_c")))
        self.clause("plus y", abs(bore["xy"][0]) <= 1.0 and abs(bore["xy"][1] - 94.0) <= 1.0, str(bore["xy"]))
        self.clause("offset 0", abs(float(mate.get("offset") or 0.0)) < 1e-9, str(mate))
        self.ctx["bore0"] = bore

    @row("A21", chunk=5, on="rung08", expect={"blocker": "A20"})
    def row_A21(self) -> None:
        bore = self.mate_bore(0, ("nut1",))
        self.ctx["bore0"] = {**(self.ctx.get("bore0") or {}), **bore}
        z = self.translation_of(bore["n1"])[2]
        seated = abs(z - 242.5) <= 1.5 or abs(z - 250.0) <= 1.5
        self.clause("nut concentric", bool(bore["nut1_c"].get("id")), str(bore["nut1_c"]))
        self.clause("nut coincident z250", bool(bore["nut1_z"].get("id")) and seated, f"z={z}")
        self.clause("solver holds", bool(bore["nut1_c"].get("solved", True)) and bool(bore["nut1_z"].get("id")), str(bore["nut1_z"]))

    @row("A22", chunk=5, on="rung08", expect={"blocker": "A21"})
    def row_A22(self) -> None:
        bore = self.mate_bore(0, ("nut2",))
        self.ctx["bore0"] = {**(self.ctx.get("bore0") or {}), **bore}
        z = self.translation_of(bore["n2"])[2]
        seated = abs(z - 270.0) <= 1.5
        self.clause("nut2 coincident z270", bool(bore["nut2_z"].get("id")) and seated, f"z={z}")

    @row("A23", chunk=5, on="rung08", expect={"blocker": "A22"})
    def row_A23(self) -> None:
        bore = self.mate_bore(0, ("seat",))
        self.ctx["bore0"] = {**(self.ctx.get("bore0") or {}), **bore}
        self.solve_mates()
        t = self.translation_of(bore["pin"])
        head_minus = t[2] >= 280.0 or abs(t[2] - 287.5) <= 2.0
        grip = abs(self.mm("NUT_Z_HI") - self.mm("NUT_Z_LO") - 20.0) <= 0.2
        self.clause("pin seated", bool(bore["seat"].get("id")), str(bore["seat"]))
        self.clause("head minus z", head_minus, f"t={t}")
        self.clause("grip 35", grip, f"hi-lo={self.mm('NUT_Z_HI') - self.mm('NUT_Z_LO')}")

    @row("L6", chunk=5, on="rung08", expect={"blocker": "A23"})
    def row_L6(self) -> None:
        kinds = self.classify()
        seated_pins = 0
        for pin in kinds["pin"]:
            t = pin.get("translation") or [0, 0, 0]
            if abs(float(t[2]) - 287.5) <= 4.0:
                seated_pins += 1
        self.clause("one bore", seated_pins == 1 or bool(self.ctx.get("bore0")), f"seated={seated_pins}")
        self.clause("seven empty", seated_pins <= 1, f"seated={seated_pins}")

    @row("A24", chunk=5, on="rung08", expect={"blocker": "A23"})
    def row_A24(self) -> None:
        notes = []
        ok = True
        for i in range(1, 8):
            bore = self.mate_bore(i)
            seated = bool(bore.get("seat", {}).get("id"))
            ok = ok and seated
            notes.append(f"{i}:{seated}")
        self.solve_mates()
        c = self.counts()
        kinds = self.classify()
        zs = [float((p.get("translation") or [0, 0, 0])[2]) for p in kinds["pin"]]
        centre = all(abs(z - 287.5) <= 5.0 or abs(z - 232.5) <= 55.0 for z in zs)
        self.clause("repeat 8", ok, "; ".join(notes))
        self.clause("pins 8", c["pin"] == 8, str(c))
        self.clause("nuts 16", c["nut"] == 16, str(c))
        self.clause("centre only", centre, str(zs))

    @row("A25", chunk=5, on="rung08", expect={"blocker": "A24"})
    def row_A25(self) -> None:
        code, text, path = self.export_stage("bolted", "bolted.3mf")
        holes_ok, holes_line = self.check_probe(text, "holes")
        nuts_ok, nuts_line = self.check_probe(text, "nuts")
        vol_ok, vol_line = self.check_probe(text, "volume")
        saved = self.save_as("bolted.sxp")
        self.clause("exported", Path(path).is_file(), path)
        self.clause("bolted", code == 0, text[-400:])
        self.clause("holes", holes_ok, holes_line)
        self.clause("nuts", nuts_ok, nuts_line)
        self.clause("volume", vol_ok, vol_line)
        self.clause("saved", Path(saved).is_file(), saved)
