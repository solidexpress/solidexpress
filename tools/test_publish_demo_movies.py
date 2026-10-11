#!/usr/bin/env python3
"""Coverage for scripts/sx-publish-demo-movies ID mode against temp JSON copies."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "sx-publish-demo-movies"
PUB = ROOT / "website" / "assets" / "published-demos.json"
CAT = ROOT / "website" / "assets" / "demo-catalog.json"
POSTER = ROOT / "website" / "assets" / "screenshots" / "ubc_wrench.png"
FILM_ID = "ubc_wrench"


def _ffmpeg() -> str | None:
    return shutil.which("ffmpeg")


class PublishDemoMoviesTests(unittest.TestCase):
    def setUp(self) -> None:
        if _ffmpeg() is None:
            self.skipTest("ffmpeg absent")
        self._pub_before = PUB.read_bytes()
        self._cat_before = CAT.read_bytes()
        self._poster_before = POSTER.read_bytes() if POSTER.exists() else None

    def tearDown(self) -> None:
        if self._poster_before is None:
            if POSTER.exists():
                POSTER.unlink()
        else:
            POSTER.write_bytes(self._poster_before)

    def _temp_json(self, directory: Path) -> tuple[Path, Path, bytes, bytes]:
        published = directory / "published-demos.json"
        catalog = directory / "demo-catalog.json"
        published.write_bytes(self._pub_before)
        catalog.write_bytes(self._cat_before)
        ids = [str(item) for item in json.loads(published.read_text()) if str(item) != FILM_ID]
        published.write_text(json.dumps(ids, indent=2) + "\n")
        return published, catalog, published.read_bytes(), catalog.read_bytes()

    def _env(self, movies: Path, published: Path, catalog: Path) -> dict[str, str]:
        env = os.environ.copy()
        env["SX_MOVIES_OUT"] = str(movies)
        env["SX_PUBLISHED_JSON"] = str(published)
        env["SX_CATALOG_JSON"] = str(catalog)
        return env

    def _run(self, args: list[str], env: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )

    def test_dry_run_feature_id_prints_planned_append_and_does_not_write(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            movies = tmp / "movies"
            movies.mkdir()
            (movies / f"{FILM_ID}.webm").write_bytes(b"webm")
            published, catalog, pub_bytes, cat_bytes = self._temp_json(tmp)
            proc = self._run(
                ["--dry-run", "--feature", FILM_ID],
                self._env(movies, published, catalog),
            )
            self.assertEqual(proc.returncode, 0, proc.stdout + "\n" + proc.stderr)
            out = proc.stdout
            self.assertIn(f"dry-run poster: {FILM_ID}", out)
            self.assertIn("dry-run upload", out)
            self.assertIn(f"append ['{FILM_ID}']", out)
            self.assertIn("dry-run: no gh call, no file change", out)
            self.assertEqual(published.read_bytes(), pub_bytes)
            self.assertEqual(catalog.read_bytes(), cat_bytes)
        self.assertEqual(PUB.read_bytes(), self._pub_before)
        self.assertEqual(CAT.read_bytes(), self._cat_before)

    def test_skip_upload_appends_id_once_and_leaves_repo_json_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            movies = tmp / "movies"
            movies.mkdir()
            webm = movies / f"{FILM_ID}.webm"
            made = subprocess.run(
                [
                    "ffmpeg", "-y", "-f", "lavfi",
                    "-i", "color=c=black:s=64x64:d=0.1",
                    "-c:v", "libvpx-vp9",
                    str(webm),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(made.returncode, 0, made.stderr)
            published, catalog, _pub_bytes, _cat_bytes = self._temp_json(tmp)
            env = self._env(movies, published, catalog)
            env["SX_SKIP_UPLOAD"] = "1"
            proc = self._run(["--feature", FILM_ID], env)
            self.assertEqual(proc.returncode, 0, proc.stdout + "\n" + proc.stderr)
            got = [str(item) for item in json.loads(published.read_text())]
            self.assertEqual(got, sorted(got))
            self.assertEqual(got, sorted(set(got)))
            self.assertEqual(got.count(FILM_ID), 1)
            featured = json.loads(catalog.read_text()).get("featured", [])
            self.assertEqual(sum(1 for row in featured if row.get("id") == FILM_ID), 1)
        self.assertEqual(PUB.read_bytes(), self._pub_before)
        self.assertEqual(CAT.read_bytes(), self._cat_before)


if __name__ == "__main__":
    unittest.main()
