"""Rung 1 chunk start: jaw rebuild, cut file, wrench WIP.
The three builders are the only constructors of those checkpoint parts.
"""
from __future__ import annotations

from pathlib import Path

from sxdrive import SxError
from walk.harness import RowAbort


def _previous_chunk_ready(walk, chunk: int) -> bool:
    """True when the previous chunk already left the state this chunk expects."""
    prev = chunk - 1
    if prev < 1:
        return True
    sketch = walk._sketch_active()
    if prev == 1:
        return (walk.out / "blank.sxp").exists() and not sketch
    if prev == 2:
        texts = walk.dim_texts()
        return (
            sketch
            and any(walk._label_is("20", t) for t in texts)
            and any(walk._label_is("45", t) for t in texts)
        )
    if prev == 3:
        return (walk.out / "cut.sxp").exists() and not sketch
    if prev == 4:
        return (walk.out / "wrench-wip.sxp").exists() and not sketch
    if prev == 5:
        return (walk.out / "wrench-wip.sxp").exists() and not sketch and not walk.modal_open()
    return True


def build_open_jaw(walk) -> None:
    """Open blank.sxp and leave the 20 mm / 45° jaw sketch editing."""
    walk.dismiss_modals()
    walk.open_file("blank.sxp")
    walk.refresh("status", "sketch")
    if walk._sketch_active():
        walk.click("rail:ExitSketch")
        walk.refresh("status")
    walk.sketch_on_top()
    if "Sketch on face" not in walk.S():
        raise SxError(f"jaw rebuild did not open the face sketch: {walk.S()!r}")
    walk.jaw_basis()
    walk._jaw_clicks(-10)
    if "Jaw committed" not in walk.S():
        raise SxError(f"jaw rebuild did not commit: {walk.S()!r}")
    width, angle = walk._drawn_angle_and_width()
    if width is None or angle is None:
        raise SxError(f"jaw rebuild has no labels: {walk.dim_texts()}")
    walk.edit_dim(width, "20")
    angle = walk.find_dim(lambda d: "°" in str(d.get("text", "")))
    if angle is None:
        raise SxError(f"jaw width edit dropped the angle: {walk.dim_texts()}")
    walk.edit_dim(angle, "45")
    texts = walk.dim_texts()
    if not any(walk._label_is("45", t) for t in texts):
        raise SxError(f"jaw rebuild angle is not 45°: {texts}")


def build_cut_file(walk) -> bool:
    """Chunk 3 cut, from blank.sxp, saved as cut.sxp."""
    build_open_jaw(walk)
    walk.circle([0, 0], "5")
    walk.circle([200, 0], "22.5", burst=True)
    walk.click("rail:Line")
    walk.click(sketch=[160, 40])
    walk.click(sketch=[240, -40])
    walk.click("rail:Trim")
    walk.d.drag({"sketch": [250, 0]}, {"sketch": [190, 0]})
    walk.refresh("status")
    print(f"checkpoint: cut trim {walk.S()!r}", flush=True)
    walk.pick_mouth()
    print(f"checkpoint: mouth region {walk.S()!r}", flush=True)
    walk.click("finish:Extrude", frames=10)
    walk.refresh("status")
    path = walk.save_as("cut.sxp")
    ok = Path(path).exists() and "Saved" in walk.S()
    print(f"checkpoint: built cut.sxp ok={ok} status={walk.S()!r}", flush=True)
    return ok


def build_wip_file(walk) -> bool:
    """Slot cut from cut.sxp, saved as wrench-wip.sxp."""
    walk.dismiss_modals()
    walk.open_file("cut.sxp")
    walk.sketch_on_top()
    walk.click("rail:Slot")
    walk.type_into("finish:Radius", "5")
    walk.enter()
    walk.click(sketch=[18.5, 0])
    walk.d.type("150")
    walk.enter()
    walk.set_option("finish:Op", "Cut")
    walk.set_option("finish:End", "Blind")
    walk.type_into("finish:Distance", "2.5", burst=True)
    walk.enter()
    walk.click("finish:Extrude", frames=10)
    walk.refresh("status")
    path = walk.save_as("wrench-wip.sxp")
    ok = Path(path).exists() and "Saved" in walk.S()
    print(f"checkpoint: built wrench-wip.sxp ok={ok} status={walk.S()!r}", flush=True)
    return ok


class Rung1ChunkStart:
    def __call__(self, walk, chunk: int, force: bool = False) -> None:
        if chunk <= 1:
            return
        if not force and _previous_chunk_ready(walk, chunk):
            return
        try:
            if chunk == 2:
                if (walk.out / "blank.sxp").exists():
                    walk._reload_checkpoint("blank.sxp")
                return
            if chunk == 3:
                if not (walk.out / "blank.sxp").exists():
                    print("checkpoint: blank.sxp missing, cannot rebuild the jaw", flush=True)
                    return
                print("checkpoint-reload blank.sxp", flush=True)
                build_open_jaw(walk)
                return
            if chunk == 4:
                if not (walk.out / "cut.sxp").exists():
                    if not (walk.out / "blank.sxp").exists():
                        print("checkpoint: blank.sxp missing, cannot build cut.sxp", flush=True)
                        return
                    print("checkpoint: building cut.sxp from blank.sxp", flush=True)
                    if not build_cut_file(walk):
                        return
                walk._reload_checkpoint("cut.sxp")
                return
            if chunk in (5, 6):
                if not (walk.out / "wrench-wip.sxp").exists():
                    if not (walk.out / "cut.sxp").exists():
                        if not (walk.out / "blank.sxp").exists():
                            print("checkpoint: no blank.sxp to build the wrench", flush=True)
                            return
                        if not build_cut_file(walk):
                            return
                    print("checkpoint: building wrench-wip.sxp from cut.sxp", flush=True)
                    if not build_wip_file(walk):
                        return
                walk._reload_checkpoint("wrench-wip.sxp")
        except (SxError, RowAbort) as exc:
            print(f"checkpoint: chunk {chunk} reload failed: {exc}", flush=True)
