"""Bridge sugar: clicks, menus, fields, dialogs, sketch helpers."""
from __future__ import annotations

from sxdrive import SxError

class WalkUI:
    def refresh(self, *keys: str) -> dict:
        filt = ",".join(keys) if keys else (
            "status,focus,focus_text,dof,sketch,finish,tool,rail,dims,timeline,"
            "selection,bodies,features,popups,measure,infer,glyphs,contours,window,card,camera"
        )
        self.st = self.d.state(filter=filt)
        return self.st

    def S(self) -> str:
        return str(self.st.get("status", ""))

    def click(self, target: str | None = None, **fields):
        if target is not None:
            return self.d.click(target, **fields)
        return self.d.click(**fields)

    def menu(self, menu: str, item: str) -> None:
        self.click(f"menu:{menu}")
        self.click(f"popup:{item}")

    def popup_text(self) -> str:
        parts = []
        for p in self.st.get("popups") or []:
            parts.append(str(p.get("text", "")) + " " + str(p.get("id", "")) + " " + str(p.get("title", "")))
        return " ".join(parts)

    def has_popup(self, needle: str) -> bool:
        return needle.lower() in self.popup_text().lower()

    def lit_names(self) -> list[str]:
        names = []
        for b in self.st.get("rail") or []:
            if b.get("lit") or b.get("pressed"):
                names.append(str(b.get("text", "")))
        return names

    def field(self, fid: str) -> str:
        for f in (self.st.get("finish") or {}).get("fields") or []:
            if f.get("id") == fid:
                return str(f.get("text", ""))
        return ""

    def control(self, cid: str) -> dict | None:
        self.refresh("controls", "window", "status")
        for c in self.st.get("controls") or []:
            if c.get("id") == cid:
                return c
        return None

    def type_into(self, target: str, text: str, burst: bool = False) -> str:
        self.click(target)
        self.d.key("ctrl+a")
        self.d.type(text, delay_ms=10 if burst else 0)
        self.refresh("focus_text", "status", "focus")
        return str(self.st.get("focus_text", ""))

    def enter(self) -> str:
        reply = self.d.key("enter")
        self.refresh("status", "focus", "focus_text", "dof")
        return str(reply.get("status", self.S()))

    def esc(self) -> str:
        reply = self.d.key("esc")
        self.refresh("status", "focus", "selection", "popups")
        return str(reply.get("status", self.S()))

    def esc_until(self, fragment: str, limit: int = 4) -> bool:
        self.refresh("status")
        for _ in range(limit):
            if fragment in self.S():
                return True
            self.esc()
        return fragment in self.S()

    def set_option(self, control: str, item: str) -> None:
        self.click(control)
        self.click(f"popup:{item}")
        self.refresh("finish", "status", "popups")

    def _arm_dialog_dir(self) -> None:
        self.d.dialog_dir(str(self.out))
        self.refresh("focus", "focus_text", "popups")

    def _type_dialog_name(self, name: str, replace_selection: bool) -> str:
        focus = str(self.refresh("focus", "focus_text").get("focus", ""))
        if "LineEdit" not in focus and "dialog:Name" not in focus:
            self.click("dialog:Name")
            self.refresh("focus", "focus_text")
        if not replace_selection:
            self.d.key("ctrl+a")
        self.d.type(name, delay_ms=10)
        return str(self.refresh("focus_text", "status").get("focus_text", ""))

    def commit_dialog(self, name: str | None = None, set_dir: bool = True) -> dict:
        """Set the file dialog path and press its real OK, then the overwrite OK."""
        fields: dict = {}
        if set_dir:
            fields["path"] = str(self.out)
        if name:
            fields["file"] = name
        reply = self.d.call("dialog_commit", **fields)
        self.d.wait_idle(frames=2)
        self.refresh("status", "popups")
        snap = self.d.state(filter="dialogs")
        self.st["dialogs"] = snap.get("dialogs") or {}
        self.st["status"] = str(reply.get("status") or self.st.get("status") or "")
        return reply

    def save_as(self, name: str) -> str:
        path = str(self.out / name)
        self.menu("File", "Save As...")
        reply = self.commit_dialog(name)
        if reply.get("visible"):
            dialogs = self.st.get("dialogs") or {}
            raise SxError(
                f"Save As stayed open file={dialogs.get('file')!r} "
                f"overwrite={dialogs.get('overwrite_text')!r} status={self.S()!r}"
            )
        return path

    def export_3mf(self, name: str) -> str:
        path = str(self.out / name)
        self.menu("File", "Export 3MF...")
        reply = self.commit_dialog(name)
        if reply.get("visible"):
            raise SxError(f"Export dialog stayed open status={self.S()!r}")
        return path

    def open_file(self, name: str) -> None:
        self.menu("File", "Open...")
        self.refresh("popups", "status")
        snap = self.d.state(filter="dialogs")
        dialogs = snap.get("dialogs") or {}
        if dialogs.get("discard_visible") or self.has_popup("Discard"):
            self.click("dialog:DiscardOk")
            self.d.wait_idle(frames=2)
        reply = self.commit_dialog(name)
        if reply.get("visible"):
            raise SxError(f"Open dialog stayed open status={self.S()!r}")

    def file_new(self, discard: str | None = None) -> None:
        self.menu("File", "New")
        self.refresh("popups", "status")
        if self.has_popup("Discard"):
            self.click("dialog:DiscardOk" if discard == "ok" else "dialog:DiscardCancel")
            self.refresh("status", "popups")

    def sketch_ground(self) -> None:
        self.click("rail:Sketch")
        self.click(model=[0, 0, 0])
        self.refresh("status", "sketch")

    def clear_selection(self) -> None:
        self.esc_until("Selection cleared", 5)

    def top_face(self) -> dict:
        self.refresh("faces")
        faces = list(self.st.get("faces") or [])
        if not faces:
            raise SxError("no faces")
        tops = [f for f in faces if float(f["mid"][2]) >= 9.0]
        pool = tops or faces
        return max(pool, key=lambda f: (float(f["mid"][2]), -abs(float(f["mid"][0]) - 100.0)))

    def bottom_face(self) -> dict:
        self.refresh("faces")
        faces = list(self.st.get("faces") or [])
        lows = [f for f in faces if float(f["mid"][2]) <= 1.0]
        pool = lows or faces
        return min(pool, key=lambda f: float(f["mid"][2]))

    def sketch_on_top(self) -> None:
        self.clear_selection()
        self.click("rail:Sketch")
        face = self.top_face()
        self.click(face=face["id"])
        self.refresh("status", "sketch", "finish")

    def circle(self, uv: list[float], radius: str, burst: bool = False) -> str:
        self.click("rail:Circle")
        self.click(sketch=uv)
        self.refresh("status", "focus")
        if "Radius" in str(self.st.get("focus", "")) or "Dim" in str(self.st.get("focus", "")):
            self.d.type(radius, delay_ms=10 if burst else 0)
            typed = self.refresh("focus_text").get("focus_text", "")
        else:
            typed = self.type_into("finish:Radius", radius, burst=burst)
        self.enter()
        return str(typed)

    def dims(self) -> list[dict]:
        self.refresh("dims", "status", "dof")
        return list(self.st.get("dims") or [])

    def dim_texts(self) -> list[str]:
        return [str(d.get("text", "")) for d in self.dims() if d.get("visible", True)]

    def _num_is(self, text: str, want: float) -> bool:
        token = str(text).strip().rstrip("°").split()[0] if str(text).strip() else ""
        try:
            return abs(float(token) - want) < 1e-3
        except ValueError:
            return False

    def _label_is(self, token: str, text: str) -> bool:
        t = str(text).replace(" ", "")
        if token == "45":
            return t.startswith("45") and "°" in t
        if token == "20":
            return t.startswith("20") and "°" not in t
        if token == "5":
            return t.startswith("5") and not t.startswith("22") and "°" not in t and "45" not in t
        if token == "22.5":
            return t.startswith("22.5")
        return token in t

    def find_dim(self, pred) -> dict | None:
        for d in self.dims():
            if pred(d):
                return d
        return None

    def _dim_editor_open(self) -> bool:
        return str((self.control("dim:Edit") or {}).get("text", "")) != ""

    def edit_dim(self, dim: dict, text: str) -> str:
        label = str(dim.get("text", ""))
        self.click("rail:Select")
        points: list[list[float]] = []
        for key in ("rect", "hit_rect"):
            rect = dim.get(key) or []
            if len(rect) < 4 or float(rect[2]) < 1.0:
                continue
            x, y, w, h = [float(v) for v in rect[:4]]
            points.append([x + min(8.0, w * 0.25), y + h * 0.5])
            points.append([x + w * 0.5, y + h * 0.5])
        opened = False
        for pt in points:
            self.d.click(screen=pt)
            self.d.wait_idle(frames=1)
            if self._dim_editor_open():
                opened = True
                break
        if not opened:
            self.d.click(dim=label, glyph="first")
            self.d.wait_idle(frames=2)
        got = self._type_dim_editor(text)
        if not opened and not self._num_is(got, float(text) if text.replace(".", "", 1).isdigit() else -1):
            got = f"{got} rect={dim.get('rect')} hit={dim.get('hit_rect')}"
        self.enter()
        return got

    def _dim_editor_text(self) -> str:
        # The popup takes digits even while focus stays on the rail button, so
        # focus_text is empty. Read the line edit itself.
        edit = self.control("dim:Edit") or {}
        text = str(edit.get("text", ""))
        if text == "":
            text = str(self.st.get("focus_text", ""))
        return text

    def _type_dim_editor(self, text: str) -> str:
        """Type once into the viewport Dim editor. A second burst appends."""
        self.d.wait_idle(frames=2)
        current = self._dim_editor_text()
        if current == text:
            return current
        self.d.type(text, delay_ms=10)
        self.d.wait_idle(frames=2)
        return self._dim_editor_text()

    def _entities(self) -> list[dict]:
        sk = self.st.get("sketch") or {}
        if not sk:
            self.refresh("sketch")
            sk = self.st.get("sketch") or {}
        return list(sk.get("entities") or [])

    def _circle_span(self, ents: list[dict] | None = None) -> float:
        centres = []
        for e in (ents if ents is not None else self._entities()):
            if e.get("type") == "circle" and e.get("center"):
                centres.append(e["center"])
        best = 0.0
        for i, a in enumerate(centres):
            for b in centres[i + 1:]:
                best = max(best, ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5)
        return best

    def _bbox_x(self, bodies: list[dict]) -> float | None:
        if not bodies:
            return None
        best = None
        for b in bodies:
            mn, mx = b.get("min"), b.get("max")
            if not mn or not mx:
                continue
            span = float(mx[0]) - float(mn[0])
            best = span if best is None else max(best, span)
        return best

    def _shaft_mids(self) -> list[list[float]]:
        mids = []
        for e in self._entities():
            if e.get("type") != "line":
                continue
            a, b = e.get("start"), e.get("end")
            if not a or not b:
                continue
            if abs(a[1] - b[1]) > 1.0:
                continue
            if abs(abs(a[1]) - 10.0) > 2.0:
                continue
            mids.append([(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5])
        mids.sort(key=lambda p: p[1])
        return mids

    def _select_both_circles(self) -> None:
        self.click("rail:Select")
        self.refresh("sketch", "selection")
        circles = [e for e in self._entities() if e.get("type") == "circle" and e.get("center")]
        circles.sort(key=lambda e: float(e["radius"]))
        sel = (self.st.get("selection") or {}).get("sketch") or []
        if len(sel) >= 2:
            return
        self.click(sketch=[0, 40])
        self.refresh("status")
        for e in circles[:2]:
            self.click(sketch=list(e["center"]))
        self.refresh("selection", "status")

    def rail_right(self) -> float:
        rights = []
        for b in (self.refresh("rail").get("rail") or []):
            rect = b.get("rect") or []
            if len(rect) >= 4:
                rights.append(float(rect[0]) + float(rect[2]))
        return max(rights) if rights else 129.0

    def label_clear(self, dim: dict) -> bool:
        rect = dim.get("rect") or []
        if len(rect) < 4:
            return False
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        x, y, w, h = [float(v) for v in rect[:4]]
        return x >= self.rail_right() - 1 and y >= 36 and x + w <= float(win[0]) - 2 and y + h <= float(win[1]) - 2

    def edges(self) -> list[dict]:
        self.refresh("edges")
        return list(self.st.get("edges") or [])

    def click_edge_near(self, pred, along: float = 0.5) -> str:
        hits = [e for e in self.edges() if pred(e)]
        if not hits:
            raise SxError("no edge matched")
        edge = hits[0]
        reply = self.d.click(edge=edge["id"], along=along)
        self.refresh("status")
        return str(reply.get("status", self.S()))

    def _timeline_names(self) -> list[str]:
        return [str(r.get("name", "")) for r in (self.refresh("timeline").get("timeline") or []) if r.get("name")]

    def _timeline_visible(self) -> bool:
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "panel":
                return bool(row.get("visible"))
        return False

    def _show_timeline(self) -> None:
        if self._timeline_visible():
            return
        self.menu("View", "Timeline")
        self.d.wait_idle(frames=2)

    def _reopen_sketch3(self) -> str:
        self._show_timeline()
        self.click("timeline:pencil:sketch 3")
        self.d.wait_idle(frames=3)
        self.refresh("status", "sketch")
        return self.S()
