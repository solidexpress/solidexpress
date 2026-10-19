"""Rung-8 gestures: New Assembly, insert fixtures, in-context pin, instance mates."""
from __future__ import annotations

import json
import math
import os
from pathlib import Path

from sxdrive import SxError
from walk.chrome import WalkChrome
from walk.harness import Walk

PINNED_NEW = "New — empty part, Top plane (XY). View ▸ Timeline to edit features"
PINNED_ASSEMBLY = "New — empty assembly, origin planes, mmgs"

STAGE_FILE = {
    "pin": "pin.3mf",
    "pipes": "pipes.3mf",
    "bolted": "bolted.3mf",
    "final": "assembly.3mf",
}


class WalkUI08(WalkChrome):
    _RUNG = 8
    _EMPTY_SKETCH = (-20.0, 30.0)
    _INTENDED = (
        "Insert failed: no file",
        "mate:Add rejected",
        "Fix/Float refused",
        "instance not found",
        "instance stuck while Fixed",
        "Select a closed profile",
        "nothing added",
        "mate:Remove rejected",
    )

    def part(self) -> dict:
        return WalkChrome.part(self, "check_rung08.py")

    def mm(self, key: str) -> float:
        return float(self.part()["PART"][key])

    def launch(self) -> None:
        self.write_fixtures()
        Walk.launch(self)

    def write_fixtures(self) -> None:
        nut = self.out / "nut.sxp"
        pipe = self.out / "pipe.sxp"
        wrench = self.out / "wrench.sxp"
        if nut.is_file() and pipe.is_file() and wrench.is_file():
            return
        env = os.environ.copy()
        env["SX_RUNG08_FIXTURE_DIR"] = str(self.out)
        prefix = os.environ.get("OCCT_PREFIX", "/opt/occt-8.0.1")
        lib = str(Path(prefix) / "lib")
        if Path(lib).is_dir():
            env["LD_LIBRARY_PATH"] = lib + (":" + env["LD_LIBRARY_PATH"] if env.get("LD_LIBRARY_PATH") else "")
        from walk import proc

        result = proc.run(
            [str(self.godot), "--headless", "--path", str(self.repo / "game"),
             "--script", "res://tests/write_rung08_fixtures.gd"],
            cwd=self.repo,
            env=env,
        )
        if result.returncode != 0:
            raise SxError(
                "rung08 fixtures failed: "
                + ((result.stdout or "") + (result.stderr or ""))[-400:]
            )

    def new_assembly(self) -> str:
        self.click("file:NewAssembly")
        self.d.wait_idle(frames=4)
        self.refresh("status", "units", "kind", "datums", "bodies", "instances")
        return self.S()

    def insert_sxp(self, name: str) -> dict:
        path = str(self.out / name)
        self.click("insert:Components")
        self.d.wait_idle(frames=2)
        reply = self.d.call("dialog_commit", files=[path])
        self.d.wait_idle(frames=4)
        self.refresh("status", "instances", "bodies", "hidden_bodies")
        return {"reply": reply, "status": self.S(), "instances": self.instances()}

    def insert_new_part(self) -> dict:
        self.click("insert:NewPart")
        self.d.wait_idle(frames=3)
        self.refresh("edit_component", "status", "instances", "features")
        return dict(self.st.get("edit_component") or {})

    def instances(self) -> list[dict]:
        return list(self.refresh("instances").get("instances") or [])

    def mates(self) -> list[dict]:
        return list(self.refresh("mates").get("mates") or [])

    def classify(self) -> dict[str, list[dict]]:
        kind_of: dict[str, str] = {}
        out = {"pipe": [], "nut": [], "pin": [], "wrench": []}
        for inst in self.instances():
            path = str(inst.get("source_path") or "").lower()
            name = str(inst.get("name") or "").lower()
            src = str(inst.get("source_body") or "")
            kind = ""
            if "pipe" in path or "pipe" in name:
                kind = "pipe"
            elif "nut" in path or "nut" in name or "hex" in name:
                kind = "nut"
            elif "wrench" in path or "wrench" in name:
                kind = "wrench"
            if kind and src:
                kind_of[src] = kind
        for inst in self.instances():
            src = str(inst.get("source_body") or "")
            kind = kind_of.get(src, "pin")
            out[kind].append(inst)
        return out

    def counts(self) -> dict[str, int]:
        kinds = self.classify()
        return {key: len(kinds[key]) for key in kinds}

    def source_of(self, inst: dict) -> str:
        return str(inst.get("source_body") or "")

    def hidden_ids(self) -> set[str]:
        bodies = self.refresh("bodies", "hidden_bodies")
        hidden = {str(b.get("id")) for b in (bodies.get("bodies") or []) if b.get("hidden")}
        hidden.update(str(x) for x in (bodies.get("hidden_bodies") or []))
        return hidden

    def body_of(self, bid: str) -> dict:
        for body in (self.refresh("bodies").get("bodies") or []):
            if str(body.get("id")) == bid:
                return body
        return {}

    def select_instance(self, iid: str) -> None:
        self.click(f"instance:select:{iid}")
        self.d.wait_idle(frames=1)

    def set_fixed(self, iid: str, fixed: bool) -> dict:
        target = f"instance:fix:{iid}" if fixed else f"instance:float:{iid}"
        reply = self.click(target)
        self.d.wait_idle(frames=2)
        self.refresh("instances", "status")
        return reply

    def float_all(self) -> None:
        for inst in self.instances():
            if inst.get("fixed"):
                self.set_fixed(str(inst.get("id")), False)

    def copy_extra(self, iid: str, extra: int) -> None:
        self.select_instance(iid)
        self.d.key("ctrl+c")
        self.d.wait_idle(frames=1)
        for _ in range(extra):
            self.d.key("ctrl+v")
            self.d.wait_idle(frames=1)
        self.refresh("instances")

    def translation_of(self, iid: str) -> list[float]:
        for inst in self.instances():
            if str(inst.get("id")) == iid:
                t = inst.get("translation") or [0, 0, 0]
                return [float(t[0]), float(t[1]), float(t[2])]
        return [0.0, 0.0, 0.0]

    def pose_of(self, iid: str) -> dict:
        for inst in self.instances():
            if str(inst.get("id")) == iid:
                return {
                    "translation": list(inst.get("translation") or [0, 0, 0]),
                    "axis": list(inst.get("rotation_axis") or [0, 0, 1]),
                    "angle": float(inst.get("rotation_angle_deg") or 0.0),
                    "fixed": bool(inst.get("fixed")),
                }
        return {"translation": [0, 0, 0], "axis": [0, 0, 1], "angle": 0.0, "fixed": False}

    def nudge(self, iid: str, delta) -> dict:
        reply = self.d.call("instance_nudge", id=iid, delta=list(delta))
        self.refresh("instances", "status")
        return reply

    def set_transform(self, iid: str, translation, axis=(0.0, 0.0, 1.0), angle_deg: float = 0.0) -> dict:
        reply = self.d.call(
            "instance_transform",
            id=iid,
            translation=list(translation),
            axis=list(axis),
            angle=float(angle_deg),
        )
        self.refresh("instances", "status")
        return reply

    def solve_mates(self) -> dict:
        reply = self.click("mate:Solve")
        self.d.wait_idle(frames=2)
        self.refresh("instances", "mates", "status")
        return reply

    def remove_mate(self, mid: str) -> dict:
        reply = self.click(f"mate:Remove:{mid}")
        self.d.wait_idle(frames=1)
        self.refresh("mates", "instances", "status")
        return reply

    def faces(self) -> list[dict]:
        return list(self.refresh("faces").get("faces") or [])

    def _pt3(self, value) -> tuple[float, float, float]:
        if not value:
            return (0.0, 0.0, 0.0)
        return float(value[0]), float(value[1]), float(value[2])

    def cyl_face(self, body: str, want_r: float, axis, xy, xy_tol: float) -> str:
        ax = self._pt3(axis)
        alen = math.sqrt(ax[0] ** 2 + ax[1] ** 2 + ax[2] ** 2) or 1.0
        an = (ax[0] / alen, ax[1] / alen, ax[2] / alen)
        best, best_e = "", 1e9
        for face in self.faces():
            if str(face.get("body")) != body:
                continue
            geom = str(face.get("geom") or "")
            if "cylinder" not in geom.lower():
                continue
            z = self._pt3(face.get("z_dir"))
            zlen = math.sqrt(z[0] ** 2 + z[1] ** 2 + z[2] ** 2) or 1.0
            zn = (z[0] / zlen, z[1] / zlen, z[2] / zlen)
            if abs(zn[0] * an[0] + zn[1] * an[1] + zn[2] * an[2]) < 0.9:
                continue
            origin = self._pt3(face.get("origin") or face.get("centre"))
            along = origin[0] * an[0] + origin[1] * an[1] + origin[2] * an[2]
            radial = (origin[0] - an[0] * along, origin[1] - an[1] * along)
            if math.hypot(radial[0] - xy[0], radial[1] - xy[1]) > xy_tol:
                continue
            ext = self._pt3(face.get("ext"))
            radius = 0.5 * min(v for v in ext if v > 1e-6) if any(v > 1e-6 for v in ext) else 0.0
            if abs(an[1]) > 0.9:
                radius = 0.5 * min(ext[0], ext[2]) if ext[0] > 0 and ext[2] > 0 else radius
            elif abs(an[2]) > 0.9:
                radius = 0.5 * min(ext[0], ext[1]) if ext[0] > 0 and ext[1] > 0 else radius
            err = abs(radius - want_r)
            if err < best_e:
                best_e, best = err, str(face.get("id") or "")
        return best if best_e < 8.0 else ""

    def plane_zn(self, body: str, z: float, min_xy: float, nz: float) -> str:
        fallback = ""
        for face in self.faces():
            if str(face.get("body")) != body:
                continue
            ext = self._pt3(face.get("ext"))
            if ext[2] > 0.35:
                continue
            if ext[0] < min_xy or ext[1] < min_xy:
                continue
            centre = self._pt3(face.get("centre"))
            if abs(centre[2] - z) > 0.35:
                continue
            zd = self._pt3(face.get("z_dir") or face.get("normal"))[2]
            if zd * nz > 0.0:
                return str(face.get("id") or "")
            if not fallback:
                fallback = str(face.get("id") or "")
        return fallback

    def plane_y(self, body: str, y: float) -> str:
        for face in self.faces():
            if str(face.get("body")) != body:
                continue
            ext = self._pt3(face.get("ext"))
            if ext[1] > 0.35:
                continue
            centre = self._pt3(face.get("centre"))
            if abs(centre[1] - y) <= 0.35:
                return str(face.get("id") or "")
        return ""

    def nut_flat(self, body: str, want_n) -> str:
        wn = self._pt3(want_n)
        wlen = math.sqrt(wn[0] ** 2 + wn[1] ** 2 + wn[2] ** 2) or 1.0
        wn = (wn[0] / wlen, wn[1] / wlen, wn[2] / wlen)
        best, best_dot = "", -1.0
        for face in self.faces():
            if str(face.get("body")) != body:
                continue
            if "cylinder" in str(face.get("geom") or "").lower():
                continue
            z = self._pt3(face.get("z_dir") or face.get("normal"))
            if abs(z[2]) > 0.3:
                continue
            zlen = math.sqrt(z[0] ** 2 + z[1] ** 2 + z[2] ** 2) or 1.0
            d = abs((z[0] * wn[0] + z[1] * wn[1] + z[2] * wn[2]) / zlen)
            if d > best_dot:
                best_dot, best = d, str(face.get("id") or "")
        return best

    def wrench_jaw(self, body: str) -> str:
        want = (-0.707, 0.707, 0.0)
        best, best_dot = "", -1.0
        for face in self.faces():
            if str(face.get("body")) != body:
                continue
            if "cylinder" in str(face.get("geom") or "").lower():
                continue
            z = self._pt3(face.get("z_dir") or face.get("normal"))
            if abs(z[2]) > 0.3:
                continue
            origin = self._pt3(face.get("origin") or face.get("centre"))
            if origin[0] < 150.0:
                continue
            zlen = math.sqrt(z[0] ** 2 + z[1] ** 2 + z[2] ** 2) or 1.0
            d = abs((z[0] * want[0] + z[1] * want[1] + z[2] * want[2]) / zlen)
            if d > best_dot:
                best_dot, best = d, str(face.get("id") or "")
        return best

    def add_mate(self, mtype: str, ia: str, fa: str, ib: str, fb: str, name: str,
                 flip: bool = False) -> dict:
        if not fa or not fb:
            return {"id": "", "solved": False, "status": "missing face", "added": False}
        before = len(self.mates())
        reply = self.click(
            "mate:Add",
            type=mtype,
            instance_a=ia,
            face_a=fa,
            instance_b=ib,
            face_b=fb,
            offset=0.0,
            flip=flip,
            name=name,
        )
        self.d.wait_idle(frames=2)
        self.refresh("mates", "instances", "status")
        mid = str(reply.get("id") or "")
        solved = bool(reply.get("solved"))
        err = str(reply.get("error") or "")
        if mid and not solved and not flip:
            self.remove_mate(mid)
            return self.add_mate(mtype, ia, fa, ib, fb, name + "-flip", True)
        return {
            "id": mid,
            "solved": solved,
            "status": self.S(),
            "added": len(self.mates()) > before,
            "error": err,
            "reply": reply,
        }

    def add_coincident_flip(self, ia: str, fa: str, ib: str, fb: str, name: str,
                            want_z: float | None = None) -> dict:
        pose = self.pose_of(ib)
        result = self.add_mate("plane_coincident", ia, fa, ib, fb, name)
        z = self.translation_of(ib)[2]
        if want_z is not None and abs(z - want_z) > 1.0:
            if result.get("id"):
                self.remove_mate(str(result["id"]))
            self.set_fixed(ib, False)
            self.set_transform(ib, pose["translation"], pose["axis"], pose["angle"])
            result = self.add_mate("plane_coincident", ia, fa, ib, fb, name + "-flip", True)
        return result

    def ents(self, kind: str | None = None, construction: bool | None = None) -> list[dict]:
        found = []
        for entity in self._entities():
            if kind is not None and entity.get("type") != kind:
                continue
            if construction is not None and bool(entity.get("construction")) != construction:
                continue
            found.append(entity)
        return found

    def _arm_sketch_tool(self, rail: str) -> None:
        self.click("rail:Select")
        self.d.wait_idle(frames=1)
        self.click(rail)
        self.d.wait_idle(frames=2)

    def variant(self, label: str) -> None:
        chip = self.control(f"variant:{label}")
        if chip and chip.get("visible") is not False:
            self.click(f"variant:{label}")
            self.d.wait_idle(frames=2)

    def _frame_uv(self, *points) -> None:
        for pt in points:
            self.show_sketch_point(pt)

    def draw_line(self, a, b, *, construction: bool = False) -> None:
        self._arm_sketch_tool("rail:Line")
        if construction:
            self.variant("Centerline")
        self._frame_uv(a, b)
        self.click(sketch=list(a))
        self.click(sketch=list(b))
        self.refresh("sketch", "status")

    def three_point_arc(self, p1, bulge, p3) -> None:
        self._frame_uv(p1, bulge, p3)
        self._arm_sketch_tool("rail:Arc")
        self.variant("Three Point")
        self.d.wait_idle(frames=2)
        for pt in (p1, bulge, p3):
            self.click(sketch=list(pt))
            self.d.wait_idle(frames=2)
        self.refresh("sketch", "status")

    def sketch_pin(self) -> None:
        self.draw_line((0.0, 0.0), (0.0, 55.0), construction=True)
        self.three_point_arc((0.0, 0.0), (7.071, 2.929), (10.0, 10.0))
        self.draw_line((10.0, 10.0), (5.0, 10.0))
        self.draw_line((5.0, 10.0), (5.0, 45.0))
        self.draw_line((5.0, 45.0), (10.0, 45.0))
        self.three_point_arc((10.0, 45.0), (7.071, 52.071), (0.0, 55.0))

    def revolve_360(self) -> dict:
        self.click("rail:Select")
        axis = None
        for line in self.ents("line", construction=True) or self.ents("line"):
            a, b = self._pt(line.get("start") or [0, 0]), self._pt(line.get("end") or [0, 0])
            if abs(a[0]) <= 0.4 and abs(b[0]) <= 0.4:
                axis = line
                break
        if axis:
            mid = self._line_mid(axis)
            self.show_sketch_point(mid)
            self.click(sketch=mid, offset=[8, 0])
        self._ensure_finish_bar()
        mark = self.mark()
        last = {}
        for _ in range(3):
            last = self.click("finish:Revolve")
            self.d.wait_idle(frames=10)
            self.refresh("bodies", "status", "features", "sketch", "instances", "edit_component")
            if not bool((self.st.get("sketch") or {}).get("active")):
                break
        return {
            "status": " | ".join(self.result_texts(mark)) or self.S(),
            "bodies": list(self.st.get("bodies") or []),
            "active": bool((self.st.get("sketch") or {}).get("active")),
            "reply": last,
        }

    def edit_component_off(self) -> str:
        self.click("edit:Component")
        self.d.wait_idle(frames=3)
        self.refresh("edit_component", "status", "instances")
        return self.S()

    def hole_xy(self, index: int) -> tuple[float, float]:
        theta = math.radians(90.0 + index * 45.0)
        r = self.mm("PCD")
        return r * math.cos(theta), r * math.sin(theta)

    def pin_source(self) -> str:
        kinds = self.classify()
        if kinds["pin"]:
            return self.source_of(kinds["pin"][0])
        ec = self.refresh("edit_component").get("edit_component") or {}
        return str(ec.get("source") or "")

    def export_pin(self, name: str = "pin.3mf") -> str:
        src = self.pin_source()
        path = str(self.out / name)
        reply = self.d.call("export_body", body=src, path=path)
        if reply.get("error"):
            raise SxError(f"export pin failed: {reply}")
        return path

    def write_stage_json(self, stage: str, name: str) -> Path:
        kinds = self.classify()
        keys = ["pipe"]
        if stage in ("bolted", "final"):
            keys = ["pipe", "nut", "pin"]
        if stage == "final":
            keys = ["pipe", "nut", "pin", "wrench"]
        hole_axes = []
        for inst in kinds["pin"][:8]:
            t = inst.get("translation") or [0, 0, 0]
            hole_axes.append([float(t[0]), float(t[1])])
        if not hole_axes:
            hole_axes = [list(self.hole_xy(i)) for i in range(8)]
        nut_zs = []
        for inst in kinds["nut"]:
            z = float((inst.get("translation") or [0, 0, 0])[2])
            lo, hi = self.mm("NUT_Z_LO"), self.mm("NUT_Z_HI")
            z1 = z + self.mm("NUT_T")
            pick = z if abs(z - lo) < abs(z1 - lo) or abs(z - hi) < abs(z1 - hi) else z1
            nut_zs.append(pick)
        pipes = kinds["pipe"]
        zs = sorted(float((p.get("translation") or [0, 0, 0])[2]) for p in pipes)
        joint = (zs[0] + 260.0) if zs and abs(zs[0]) < 1.0 else 260.0
        coaxial = all(
            math.hypot(float((p.get("translation") or [0, 0, 0])[0]),
                       float((p.get("translation") or [0, 0, 0])[1])) <= 0.5
            for p in pipes
        ) and len(pipes) == 2
        tangent = any(str(m.get("type")) == "tangent" for m in self.mates())
        wrench = kinds["wrench"][0] if kinds["wrench"] else {}
        wt = wrench.get("translation") or [0, 0, 0]
        meshes = {}
        if (self.out / "pipe.3mf").is_file():
            meshes["pipe"] = "pipe.3mf"
        if (self.out / "nut.3mf").is_file():
            meshes["nut"] = "nut.3mf"
        if (self.out / "pin.3mf").is_file():
            meshes["pin"] = "pin.3mf"
        if (self.out / "wrench.3mf").is_file():
            meshes["wrench"] = "wrench.3mf"
        data = {
            "instances": [],
            "meshes": meshes,
            "coaxial": coaxial,
            "joint_z": joint,
            "hole_axes": hole_axes,
            "nut_zs": nut_zs,
            "wrench": {
                "flange_z": 250.0,
                "jaw": 20.0,
                "gap": 20.0,
                "tangent": tangent,
                "handle_plus_x": float(wt[0]) > 150.0,
            },
        }
        for key in keys:
            for inst in kinds[key]:
                data["instances"].append({
                    "source": key,
                    "name": str(inst.get("name") or key),
                    "translation": list(inst.get("translation") or [0, 0, 0]),
                })
        path = Path(str(self.out / name)).with_suffix(".json")
        path.write_text(json.dumps(data))
        return path

    def export_stage(self, stage: str, name: str) -> tuple[int, str, str]:
        path = self.export_3mf(name)
        self.write_stage_json(stage, name)
        check_name = name
        if stage in ("pipes", "bolted"):
            check_name = Path(name).with_suffix(".json").name
        code, text = self.checker(stage, check_name)
        return code, text, path

    def lock_wrench(self, iid: str) -> dict:
        self.set_fixed(iid, False)
        return self.set_transform(iid, (200.0, 94.0, 250.0), (0.0, 1.0, 0.0), 180.0)

    def mate_pipes(self) -> dict:
        kinds = self.classify()
        p1 = str(kinds["pipe"][0]["id"])
        p2 = str(kinds["pipe"][1]["id"])
        src1, src2 = self.source_of(kinds["pipe"][0]), self.source_of(kinds["pipe"][1])
        self.float_all()
        self.set_transform(p1, (0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 0.0)
        self.set_fixed(p1, True)
        bore1 = self.cyl_face(src1, 65.0, (0, 0, 1), (0.0, 0.0), 20.0)
        bore2 = self.cyl_face(src2, 65.0, (0, 0, 1), (0.0, 0.0), 20.0)
        fl_hi = self.plane_zn(src1, 260.0, 80.0, 1.0)
        fl_lo = self.plane_zn(src2, -260.0, 80.0, -1.0)
        hole1 = self.cyl_face(src1, 5.0, (0, 0, 1), (0.0, 94.0), 8.0)
        hole2 = self.cyl_face(src2, 5.0, (0, 0, 1), (0.0, 94.0), 8.0)
        conc = self.add_mate("concentric", p1, bore1, p2, bore2, "pipes-conc")
        flanges = self.add_coincident_flip(p1, fl_hi, p2, fl_lo, "flanges", want_z=520.0)
        holes = self.add_mate("concentric", p1, hole1, p2, hole2, "holes")
        self.solve_mates()
        z = self.translation_of(p2)[2]
        return {
            "p1": p1, "p2": p2, "bore1": bore1, "bore2": bore2,
            "fl_hi": fl_hi, "fl_lo": fl_lo, "hole1": hole1, "hole2": hole2,
            "conc": conc, "flanges": flanges, "holes": holes, "z": z,
        }

    def bore_faces(self, index: int) -> dict:
        kinds = self.classify()
        pipe = kinds["pipe"][0]
        pipe2 = kinds["pipe"][1]
        pin = kinds["pin"][index]
        n1 = kinds["nut"][index]
        n2 = kinds["nut"][index + 8]
        pipe_src = self.source_of(pipe)
        pipe2_src = self.source_of(pipe2)
        pin_src = self.source_of(pin)
        nut_src = self.source_of(n1)
        xy = self.hole_xy(index)
        return {
            "p1": str(pipe["id"]), "p2": str(pipe2["id"]),
            "pin": str(pin["id"]), "n1": str(n1["id"]), "n2": str(n2["id"]),
            "xy": xy,
            "hole": self.cyl_face(pipe_src, 5.0, (0, 0, 1), xy, 8.0),
            "shank": self.cyl_face(pin_src, 5.0, (0, 1, 0), (0.0, 0.0), 8.0),
            "collar": self.plane_y(pin_src, 45.0),
            "nut_bore": self.cyl_face(nut_src, 5.0, (0, 0, 1), (0.0, 0.0), 4.0),
            "nut_lo": self.plane_zn(nut_src, 0.0, 5.0, -1.0),
            "nut_hi": self.plane_zn(nut_src, 7.5, 5.0, 1.0),
            "flange_back": self.plane_zn(pipe_src, 250.0, 80.0, -1.0),
            "flange_back2": self.plane_zn(pipe2_src, -250.0, 80.0, 1.0),
        }

    def mate_bore(self, index: int, steps: tuple[str, ...] = ("pin_c", "nut1", "nut2", "seat")) -> dict:
        f = self.bore_faces(index)
        i = index
        out = dict(f)
        if "pin_c" in steps:
            out["pin_c"] = self.add_mate("concentric", f["p1"], f["hole"], f["pin"], f["shank"], f"pin-c-{i}")
        if "nut1" in steps:
            out["nut1_c"] = self.add_mate("concentric", f["p1"], f["hole"], f["n1"], f["nut_bore"], f"nut1-c-{i}")
            out["nut1_z"] = self.add_mate("plane_coincident", f["p1"], f["flange_back"], f["n1"], f["nut_lo"], f"nut1-z-{i}")
        if "nut2" in steps:
            out["nut2_c"] = self.add_mate("concentric", f["p1"], f["hole"], f["n2"], f["nut_bore"], f"nut2-c-{i}")
            out["nut2_z"] = self.add_mate("plane_coincident", f["p2"], f["flange_back2"], f["n2"], f["nut_lo"], f"nut2-z-{i}")
        if "seat" in steps:
            out["seat"] = self.add_mate("plane_coincident", f["n2"], f["nut_hi"], f["pin"], f["collar"], f"pin-seat-{i}")
        return out

    def wrench_faces(self) -> dict:
        kinds = self.classify()
        wrench = kinds["wrench"][0]
        nut = kinds["nut"][0]
        pipe = kinds["pipe"][0]
        wsrc, nsrc, psrc = self.source_of(wrench), self.source_of(nut), self.source_of(pipe)
        return {
            "wrench": str(wrench["id"]), "nut": str(nut["id"]), "pipe": str(pipe["id"]),
            "w_bot": self.plane_zn(wsrc, 0.0, 20.0, -1.0),
            "flange_back": self.plane_zn(psrc, 250.0, 80.0, -1.0),
            "jaw": self.wrench_jaw(wsrc),
            "nut_flat": self.nut_flat(nsrc, (-0.707, -0.707, 0.0)),
            "head": self.cyl_face(wsrc, 22.5, (0, 0, 1), (200.0, 0.0), 30.0),
            "nut_side": self.nut_flat(nsrc, (1.0, 0.0, 0.0)),
        }

    def mate_wrench(self, steps: tuple[str, ...] = ("flange", "jaw", "tangent", "lock")) -> dict:
        f = self.wrench_faces()
        self.set_fixed(f["wrench"], False)
        out = dict(f)
        if "flange" in steps:
            out["flange"] = self.add_mate(
                "plane_coincident", f["pipe"], f["flange_back"], f["wrench"], f["w_bot"], "wrench-flange")
        if "jaw" in steps:
            out["jaw_m"] = self.add_mate(
                "plane_coincident", f["nut"], f["nut_flat"], f["wrench"], f["jaw"], "wrench-jaw")
        if "tangent" in steps:
            out["tan"] = self.add_mate(
                "tangent", f["nut"], f["nut_side"], f["wrench"], f["head"], "wrench-tan")
        if "lock" in steps:
            out["lock"] = self.lock_wrench(f["wrench"])
        return out

    def reopen_assembly(self, name: str) -> dict:
        self.new_assembly()
        self.open_file(name)
        self.refresh("status", "kind", "instances", "bodies")
        return {"status": self.S(), "kind": str(self.st.get("kind", "")), "n": len(self.instances())}

    def popup_has(self, needle: str) -> bool:
        return needle.lower() in self.popup_text().lower()

    def menu_items(self, menu: str) -> str:
        self.click(f"menu:{menu}")
        self.d.wait_idle(frames=2)
        self.refresh("popups")
        text = self.popup_text()
        self.esc()
        self.d.wait_idle(frames=1)
        return text
