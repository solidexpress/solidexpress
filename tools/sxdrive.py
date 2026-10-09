#!/usr/bin/env python3
"""Client for the SolidExpress automation bridge (SX_AUTOMATION=1).

Library:
    drive = SxDrive()
    drive.click("rail:Circle")
    drive.state(filter="status,dims")

CLI:
    sxdrive.py click rail:Circle
    sxdrive.py state --filter status,dims
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import sys
import time
from typing import Any


DEFAULT_PORT = 47321
DEFAULT_HOST = "127.0.0.1"


class SxError(RuntimeError):
    """The bridge rejected a command or the reply was not usable."""


class SxTimeout(SxError):
    """A command did not answer before the deadline."""


def _parse_xy(text: str) -> list[float]:
    parts = [p.strip() for p in text.split(",")]
    if len(parts) < 2:
        raise SxError(f"expected x,y coordinates, got {text!r}")
    return [float(parts[0]), float(parts[1])]


def _parse_xyz(text: str) -> list[float]:
    parts = [p.strip() for p in text.split(",")]
    if len(parts) < 3:
        raise SxError(f"expected x,y,z coordinates, got {text!r}")
    return [float(parts[0]), float(parts[1]), float(parts[2])]


class SxDrive:
    """Line-delimited JSON client. Reconnects if the socket drops before a send."""

    def __init__(
        self,
        host: str = DEFAULT_HOST,
        port: int | None = None,
        timeout: float = 60.0,
    ) -> None:
        self.host = host
        self.port = int(port if port is not None else os.environ.get("SX_AUTOMATION_PORT", DEFAULT_PORT))
        self.timeout = timeout
        self._sock: socket.socket | None = None
        self._buf = b""
        self._next_id = 1

    def connect(self, attempts: int = 50, delay: float = 0.1) -> None:
        last: Exception | None = None
        for _ in range(attempts):
            try:
                sock = socket.create_connection((self.host, self.port), timeout=self.timeout)
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                self._sock = sock
                self._buf = b""
                return
            except OSError as exc:
                last = exc
                time.sleep(delay)
        raise SxError(
            f"could not connect to {self.host}:{self.port} ({last}). "
            "Is the app running with SX_AUTOMATION=1?"
        )

    def close(self) -> None:
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None

    def call(self, cmd: str, **fields: Any) -> dict[str, Any]:
        payload = {"cmd": cmd, "id": self._next_id}
        self._next_id += 1
        payload.update(fields)
        line = json.dumps(payload, separators=(",", ":")) + "\n"
        self._ensure()
        try:
            assert self._sock is not None
            self._sock.sendall(line.encode("utf-8"))
        except OSError as exc:
            self.close()
            self.connect(attempts=5, delay=0.2)
            try:
                assert self._sock is not None
                self._sock.sendall(line.encode("utf-8"))
            except OSError as again:
                raise SxError(f"connection lost before the command was sent ({again})") from exc
        try:
            reply = self._read_line()
        except SxTimeout:
            raise
        except OSError as exc:
            self.close()
            raise SxError(
                "connection lost after the command was sent; it was not retried"
            ) from exc
        try:
            data = json.loads(reply)
        except json.JSONDecodeError as exc:
            raise SxError(f"bridge reply was not JSON: {reply[:200]!r}") from exc
        if not isinstance(data, dict):
            raise SxError(f"bridge reply was not an object: {reply[:200]!r}")
        if not data.get("ok", False):
            raise SxError(str(data.get("error") or data))
        return data

    def _ensure(self) -> None:
        if self._sock is None:
            self.connect()

    def _read_line(self) -> str:
        assert self._sock is not None
        deadline = time.monotonic() + self.timeout
        while b"\n" not in self._buf:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise SxTimeout(f"timed out after {self.timeout:.0f}s waiting for a reply")
            self._sock.settimeout(remaining)
            chunk = self._sock.recv(65536)
            if not chunk:
                raise OSError("bridge closed the connection")
            self._buf += chunk
        line, _, rest = self._buf.partition(b"\n")
        self._buf = rest
        return line.decode("utf-8")

    def click(self, target: str | None = None, **fields: Any) -> dict[str, Any]:
        if target is not None:
            fields["target"] = target
        return self.call("click", **fields)

    def double_click(self, target: str | None = None, **fields: Any) -> dict[str, Any]:
        if target is not None:
            fields["target"] = target
        return self.call("double_click", **fields)

    def hover(self, target: str | None = None, **fields: Any) -> dict[str, Any]:
        if target is not None:
            fields["target"] = target
        return self.call("hover", **fields)

    def drag(self, src: dict[str, Any], dst: dict[str, Any], **fields: Any) -> dict[str, Any]:
        fields["from"] = src
        fields["to"] = dst
        return self.call("drag", **fields)

    def key(self, combo: str, action: str = "tap") -> dict[str, Any]:
        return self.call("key", combo=combo, action=action)

    def type(self, text: str, delay_ms: int = 0) -> dict[str, Any]:
        return self.call("type", text=text, delay_ms=delay_ms)

    def wheel(self, notches: int = 1, **where: Any) -> dict[str, Any]:
        where["notches"] = notches
        return self.call("wheel", **where)

    def wait_idle(self, frames: int = 2) -> dict[str, Any]:
        return self.call("wait_idle", frames=frames)

    def state(self, filter: str | list[str] | None = None) -> dict[str, Any]:
        fields: dict[str, Any] = {}
        if filter is not None:
            fields["filter"] = filter
        reply = self.call("state", **fields)
        state = reply.get("state")
        if not isinstance(state, dict):
            raise SxError("state reply missing the state object")
        return state

    def trace(self, since: int = 0) -> dict[str, Any]:
        return self.call("trace", since=since)

    def project(self, **where: Any) -> dict[str, Any]:
        return self.call("project", **where)

    def dialog_dir(self, path: str) -> dict[str, Any]:
        return self.call("dialog_dir", path=path)

    def screenshot(self, path: str) -> dict[str, Any]:
        return self.call("screenshot", path=path)

    def pixels(self, points: list[list[float]]) -> dict[str, Any]:
        return self.call("pixels", points=points)


def _add_where(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("target", nargs="?", help="automation id or node path")
    parser.add_argument("--sketch", help="sketch-plane point u,v in mm")
    parser.add_argument("--model", help="kernel point x,y,z")
    parser.add_argument("--screen", help="viewport pixel x,y")
    parser.add_argument("--dim", help="dimension label text")
    parser.add_argument("--dim-id", type=int, dest="dim_id")
    parser.add_argument("--edge", help="edge id (midpoint, or --along 0..1)")
    parser.add_argument("--along", type=float, help="fraction along an edge")
    parser.add_argument("--face", help="face id (midpoint)")
    parser.add_argument("--offset", help="pixel offset dx,dy from the centre")
    parser.add_argument("--glyph", choices=("center", "first"), default=None)


def _where_from_args(args: argparse.Namespace) -> dict[str, Any]:
    fields: dict[str, Any] = {}
    if getattr(args, "target", None):
        fields["target"] = args.target
    if getattr(args, "sketch", None):
        fields["sketch"] = _parse_xy(args.sketch)
    if getattr(args, "model", None):
        fields["model"] = _parse_xyz(args.model)
    if getattr(args, "screen", None):
        fields["screen"] = _parse_xy(args.screen)
    if getattr(args, "dim", None):
        fields["dim"] = args.dim
    if getattr(args, "dim_id", None) is not None:
        fields["dim_id"] = args.dim_id
    if getattr(args, "edge", None):
        fields["edge"] = args.edge
    if getattr(args, "along", None) is not None:
        fields["along"] = args.along
    if getattr(args, "face", None):
        fields["face"] = args.face
    if getattr(args, "offset", None):
        fields["offset"] = _parse_xy(args.offset)
    if getattr(args, "glyph", None):
        fields["glyph"] = args.glyph
    return fields


def _print(data: dict[str, Any]) -> None:
    print(json.dumps(data, indent=2, sort_keys=True))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="sxdrive.py", description="Drive a live SolidExpress window")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=int(os.environ.get("SX_AUTOMATION_PORT", DEFAULT_PORT)))
    parser.add_argument("--timeout", type=float, default=60.0)
    sub = parser.add_subparsers(dest="cmd", required=True)

    for name in ("click", "double-click", "hover"):
        _add_where(sub.add_parser(name))

    drag = sub.add_parser("drag")
    drag.add_argument("--from-sketch")
    drag.add_argument("--from-screen")
    drag.add_argument("--from-model")
    drag.add_argument("--to-sketch")
    drag.add_argument("--to-screen")
    drag.add_argument("--to-model")
    drag.add_argument("--steps", type=int, default=8)

    key = sub.add_parser("key")
    key.add_argument("combo", help="key or combo, e.g. ctrl+shift+z or enter")
    key.add_argument("--down", action="store_true")
    key.add_argument("--up", action="store_true")

    typed = sub.add_parser("type")
    typed.add_argument("text")
    typed.add_argument("--delay", type=int, default=0, help="milliseconds between characters")

    wheel = sub.add_parser("wheel")
    wheel.add_argument("--notches", type=int, default=1, help="positive zooms in")
    _add_where(wheel)

    idle = sub.add_parser("wait-idle")
    idle.add_argument("--frames", type=int, default=2)

    state = sub.add_parser("state")
    state.add_argument("--filter", default="", help="comma-separated keys, e.g. status,dims")

    trace = sub.add_parser("trace")
    trace.add_argument("--since", type=int, default=0)

    shot = sub.add_parser("screenshot")
    shot.add_argument("path")

    project = sub.add_parser("project")
    _add_where(project)

    sub.add_parser("ping")

    args = parser.parse_args(argv)
    drive = SxDrive(args.host, args.port, args.timeout)
    try:
        drive.connect()
        cmd = args.cmd
        if cmd in ("click", "double-click", "hover"):
            fields = _where_from_args(args)
            if not fields:
                raise SxError(f"{cmd} needs a target or a point")
            name = {"double-click": "double_click"}.get(cmd, cmd)
            _print(drive.call(name, **fields))
        elif cmd == "drag":
            src: dict[str, Any] = {}
            dst: dict[str, Any] = {}
            if args.from_sketch:
                src["sketch"] = _parse_xy(args.from_sketch)
            if args.from_screen:
                src["screen"] = _parse_xy(args.from_screen)
            if args.from_model:
                src["model"] = _parse_xyz(args.from_model)
            if args.to_sketch:
                dst["sketch"] = _parse_xy(args.to_sketch)
            if args.to_screen:
                dst["screen"] = _parse_xy(args.to_screen)
            if args.to_model:
                dst["model"] = _parse_xyz(args.to_model)
            if not src or not dst:
                raise SxError("drag needs a from and a to point")
            _print(drive.drag(src, dst, steps=args.steps))
        elif cmd == "key":
            action = "down" if args.down else "up" if args.up else "tap"
            _print(drive.key(args.combo, action))
        elif cmd == "type":
            _print(drive.type(args.text, args.delay))
        elif cmd == "wheel":
            fields = _where_from_args(args)
            fields["notches"] = args.notches
            _print(drive.call("wheel", **fields))
        elif cmd == "wait-idle":
            _print(drive.wait_idle(args.frames))
        elif cmd == "state":
            filt = args.filter.strip()
            _print({"state": drive.state(filt if filt else None)})
        elif cmd == "trace":
            _print(drive.trace(args.since))
        elif cmd == "screenshot":
            _print(drive.screenshot(args.path))
        elif cmd == "project":
            _print(drive.project(**_where_from_args(args)))
        elif cmd == "ping":
            _print(drive.call("ping"))
        else:
            raise SxError(f"unknown command {cmd}")
    except SxError as exc:
        print(f"sxdrive: {exc}", file=sys.stderr)
        return 1
    finally:
        drive.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
