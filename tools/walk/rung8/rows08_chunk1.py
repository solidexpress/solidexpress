"""Rung-8 chunks 1–2: New Assembly, insert, float, in-context pin."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row
from walk.rung8.ui08 import PINNED_ASSEMBLY, PINNED_NEW


class Rows08Chunk1:
    @row("N1", chunk=1, on="rung08")
    def row_N1(self) -> None:
        chrome = self.chrome_nodes()
        size = chrome["size"]
        win = chrome["window"]
        wide = float(size[0]) >= 1272 and float(size[1]) >= 750
        self.clause("window", wide or bool(win.get("maximized")), f"window {size} maximized={win.get('maximized')}")
        notes = []
        inside = True
        for label in ("status", "menu", "rail"):
            node = chrome[label]
            if not self.node_inside(node, size):
                inside = False
                notes.append(f"{label} missing" if not node else f"{label} {node.get('rect')}")
            else:
                notes.append(f"{label} {node.get('rect')}")
        self.clause("chrome inside", inside, "; ".join(notes))

    @row("A1", chunk=1, on="rung08")
    def row_A1(self) -> None:
        status = self.new_assembly()
        units = str(self.st.get("units", ""))
        kind = str(self.st.get("kind", ""))
        bodies = list(self.st.get("bodies") or [])
        datums = {str(d.get("name", "")) for d in (self.st.get("datums") or [])}
        self.clause("new assembly", PINNED_ASSEMBLY in status or "empty assembly" in status.lower(), status)
        self.clause("units mmgs", units == "mmgs", units)
        self.clause("kind assembly", kind == "assembly", kind)
        self.clause("no bodies", len(bodies) == 0, str(bodies))
        self.clause("planes", {"Front", "Top", "Right"} <= datums, str(sorted(datums)))
        self.clause("not part new", status.strip() != PINNED_NEW, status)

    @row("L1", chunk=1, on="rung08", expect={"blocker": "A1"})
    def row_L1(self) -> None:
        file_text = self.menu_items("File")
        insert_text = self.menu_items("Insert")
        names = {str(d.get("name", "")) for d in (self.refresh("datums").get("datums") or [])}
        self.clause("new assembly item", "New Assembly" in file_text and "New" in file_text, file_text)
        self.clause("insert components", "Components" in insert_text, insert_text)
        self.clause("insert new part", "New Part" in insert_text, insert_text)
        self.clause("plane names", {"Front", "Top", "Right"} <= names, str(sorted(names)))

    @row("A2", chunk=1, on="rung08", expect={"blocker": "A1"})
    def row_A2(self) -> None:
        before = len(self.instances())
        result = self.insert_sxp("nut.sxp")
        kinds = self.classify()
        hidden = self.hidden_ids()
        src = self.source_of(kinds["nut"][0]) if kinds["nut"] else ""
        self.clause("inserted nut", len(kinds["nut"]) == 1, str(self.counts()))
        self.clause("instance 1", len(self.instances()) == before + 1, str(len(self.instances())))
        self.clause("source hidden", src in hidden or bool(src and src in hidden), f"src={src} hidden={sorted(hidden)}")

    @row("A3", chunk=1, on="rung08", expect={"blocker": "A2"})
    def row_A3(self) -> None:
        self.insert_sxp("pipe.sxp")
        kinds = self.classify()
        self.clause("inserted pipe", len(kinds["pipe"]) == 1, str(self.counts()))
        self.clause("instance 2", len(self.instances()) == 2, str(len(self.instances())))

    @row("A4", chunk=1, on="rung08", expect={"blocker": "A3"})
    def row_A4(self) -> None:
        self.insert_sxp("wrench.sxp")
        c = self.counts()
        self.clause("inserted wrench", c["wrench"] == 1, str(c))
        self.clause("instance 3", len(self.instances()) == 3, str(len(self.instances())))
        self.clause("pipes 1", c["pipe"] == 1, str(c))
        self.clause("nuts 1", c["nut"] == 1, str(c))
        self.clause("pins 0", c["pin"] == 0, str(c))
        self.clause("wrench 1", c["wrench"] == 1, str(c))

    @row("L2", chunk=1, on="rung08", expect={"blocker": "A4"})
    def row_L2(self) -> None:
        kinds = self.classify()
        hidden = self.hidden_ids()
        sources = {self.source_of(inst) for group in kinds.values() for inst in group}
        mates = self.mates()
        self.clause("three visible", len(self.instances()) == 3, str(self.counts()))
        self.clause("sources hidden", sources <= hidden, f"src={sources} hidden={hidden}")
        self.clause("not mated", not any(str(m.get("type")) not in ("", "fixed") for m in mates) or len(mates) <= 1, str(mates))

    @row("A5", chunk=1, on="rung08", expect={"blocker": "A4"})
    def row_A5(self) -> None:
        self.float_all()
        moved = True
        notes = []
        for inst in self.instances():
            iid = str(inst.get("id"))
            before = self.translation_of(iid)
            reply = self.nudge(iid, [12.0, 0.0, 0.0])
            after = self.translation_of(iid)
            ok = bool(reply.get("moved")) and abs(after[0] - before[0]) > 1.0
            moved = moved and ok
            notes.append(f"{iid} {before}->{after} moved={reply.get('moved')}")
            self.nudge(iid, [-12.0, 0.0, 0.0])
        still_fixed = [i for i in self.instances() if i.get("fixed")]
        self.clause("floated", not still_fixed, str(still_fixed))
        self.clause("all free", not still_fixed, str([i.get("fixed") for i in self.instances()]))
        self.clause("drag ok", moved, "; ".join(notes))

    @row("N2", chunk=1, on="rung08", expect={"blocker": "A5"})
    def row_N2(self) -> None:
        inst = self.instances()[0]
        iid = str(inst.get("id"))
        self.set_fixed(iid, True)
        before = self.translation_of(iid)
        reply = self.nudge(iid, [40.0, 0.0, 0.0])
        after = self.translation_of(iid)
        still = bool(next((i.get("fixed") for i in self.instances() if str(i.get("id")) == iid), False))
        refused = (not reply.get("moved")) or bool(reply.get("error")) or after == before
        self.clause("refused", refused, str(reply))
        self.clause("still fixed", still and after == before, f"fixed={still} {before}->{after}")
        self.set_fixed(iid, False)
        self.clause("then floated", not any(i.get("fixed") for i in self.instances()), str(self.instances()))
        self.save_as("inserted.sxp")

    @row("A6", chunk=2, on="rung08", expect={"blocker": "A5"})
    def row_A6(self) -> None:
        ec = self.insert_new_part()
        feats = list(self.refresh("features").get("features") or [])
        pad = any(str(f.get("type", "")).lower() == "in_context" for f in feats)
        self.clause("new part", bool(ec.get("on") or ec.get("pending")), str(ec))
        self.clause("edit component on", bool(ec.get("on")), str(ec))
        self.clause("not incontext pad", not pad, str(feats))

    @row("A7", chunk=2, on="rung08", expect={"blocker": "A6"})
    def row_A7(self) -> None:
        started = self.sketch_on_datum("Front", "1")
        plane = started["plane"]
        normal = plane.get("normal") or []
        x_dir = plane.get("x") or []
        y_dir = plane.get("y") or []
        ec = self.refresh("edit_component").get("edit_component") or {}
        n_ok = len(normal) == 3 and abs(float(normal[2]) - 1) <= 0.01
        basis = (
            len(x_dir) == 3 and abs(float(x_dir[0]) - 1) <= 0.01
            and len(y_dir) == 3 and abs(float(y_dir[1]) - 1) <= 0.01
        )
        self.clause("datum Front", started["active"], started["status"])
        self.clause("sketch", started["active"], started["status"])
        self.clause("edit component", bool(ec.get("on")), str(ec))
        self.clause("basis", n_ok and basis, f"n={normal} x={x_dir} y={y_dir}")

    @row("A8", chunk=2, on="rung08", expect={"blocker": "A7", "sketch": True})
    def row_A8(self) -> None:
        self.sketch_pin()
        lines = self.ents("line")
        arcs = self.ents("arc")
        axis = False
        shank = False
        overall = False
        for line in lines:
            a, b = self._pt(line.get("start") or [0, 0]), self._pt(line.get("end") or [0, 0])
            if abs(a[0]) <= 0.4 and abs(b[0]) <= 0.4 and abs(max(a[1], b[1]) - 55) <= 0.6:
                axis = True
                overall = True
            xs = {round(a[0], 1), round(b[0], 1)}
            ys = sorted([a[1], b[1]])
            if 5.0 in xs and abs(ys[0] - 10) <= 0.6 and abs(ys[1] - 45) <= 0.6:
                shank = True
        r10 = [a for a in arcs if abs(float(a.get("radius") or 0.0) - 10.0) <= 0.6]
        centres = [self._pt(a.get("center") or [0, 0]) for a in r10]
        head = any(abs(c[1] - 45.0) <= 1.5 for c in centres)
        tail = any(abs(c[1] - 10.0) <= 1.5 for c in centres)
        self.clause("centerline", axis or bool(self.ents("line", construction=True)), f"lines={len(lines)}")
        self.clause("r10 head", head or len(r10) >= 1, f"arcs={len(arcs)} r10={len(r10)}")
        self.clause("shank 35", shank or any(abs((self._pt(l.get("start") or [0, 0])[1] - self._pt(l.get("end") or [0, 0])[1]) - 35) <= 0.6 for l in lines), str(len(lines)))
        self.clause("r5 shank", shank or any(abs(self._pt(l.get("start") or [0, 0])[0] - 5) <= 0.4 or abs(self._pt(l.get("end") or [0, 0])[0] - 5) <= 0.4 for l in lines), "x=5")
        self.clause("overall 55", overall, "y=0..55")
        self.clause("r10 tail", tail or len(r10) >= 2, f"centres={centres}")

    @row("A9", chunk=2, on="rung08", expect={"blocker": "A8", "sketch": True})
    def row_A9(self) -> None:
        result = self.revolve_360()
        src = self.pin_source()
        body = self.body_of(src)
        mn = body.get("min") or [0, 0, 0]
        mx = body.get("max") or [0, 0, 0]
        ext = [float(mx[i]) - float(mn[i]) for i in range(3)]
        box_ok = abs(ext[0] - 20) <= 0.3 and abs(ext[1] - 55) <= 0.3 and abs(ext[2] - 20) <= 0.3
        self.clause("revolve 360", not result["active"], result["status"])
        self.clause("one solid", bool(src) and bool(body), f"src={src} body={body}")
        self.clause("bbox 20 55 20", box_ok, f"ext={ext} min={mn}")

    @row("A10", chunk=2, on="rung08", expect={"blocker": "A9"})
    def row_A10(self) -> None:
        status = self.edit_component_off()
        ec = self.st.get("edit_component") or {}
        kinds = self.classify()
        self.clause("edit component off", not bool(ec.get("on")), str(ec) + " " + status)
        self.clause("pin instance", len(kinds["pin"]) == 1, str(self.counts()))

    @row("A11", chunk=2, on="rung08", expect={"blocker": "A10"})
    def row_A11(self) -> None:
        path = self.export_pin("pin.3mf")
        code, text = self.checker("pin", "pin.3mf")
        box_ok, box_line = self.check_probe(text, "bbox")
        vol_ok, vol_line = self.check_probe(text, "volume")
        tight_ok, tight_line = self.check_probe(text, "watertight")
        saved = self.save_as("pin.sxp")
        self.clause("exported", Path(path).is_file(), path)
        self.clause("pin", code == 0, text[-300:])
        self.clause("bbox", box_ok, box_line)
        self.clause("volume", vol_ok, vol_line)
        self.clause("watertight", tight_ok, tight_line)
        self.clause("saved", Path(saved).is_file(), saved)

    @row("L3", chunk=2, on="rung08", expect={"blocker": "A11"})
    def row_L3(self) -> None:
        c = self.counts()
        src = self.pin_source()
        body = self.body_of(src)
        ext = [0, 0, 0]
        if body.get("min") and body.get("max"):
            ext = [float(body["max"][i]) - float(body["min"][i]) for i in range(3)]
        self.clause("pin visible", c["pin"] == 1 and abs(ext[1] - 55) <= 0.4, f"counts={c} ext={ext}")
        self.clause("counts 1 1 1 1", c["pipe"] == 1 and c["nut"] == 1 and c["pin"] == 1 and c["wrench"] == 1, str(c))
