#!/usr/bin/env python3
"""Coverage for scripts/sx-publish-demo-movies against temp JSON + poster dirs."""
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
HELPER = ROOT / "tools" / "website_demos.py"
PUB = ROOT / "website" / "assets" / "published-demos.json"
CAT = ROOT / "website" / "assets" / "demo-catalog.json"
POSTER = ROOT / "website" / "assets" / "screenshots" / "ubc_wrench.png"
FILM_ID = "ubc_wrench"


def _ffmpeg() -> str | None:
    return shutil.which("ffmpeg")


def _curated_ids() -> list[str]:
    proc = subprocess.run(
        ["python3", str(HELPER), "ids"], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


class PublishDemoMoviesTests(unittest.TestCase):
    def setUp(self) -> None:
        if _ffmpeg() is None:
            self.skipTest("ffmpeg absent")
        self._pub_before = PUB.read_bytes()
        self._cat_before = CAT.read_bytes()
        self._poster_bytes = POSTER.read_bytes() if POSTER.exists() else None

    def tearDown(self) -> None:
        if PUB.read_bytes() != self._pub_before:
            PUB.write_bytes(self._pub_before)
        if CAT.read_bytes() != self._cat_before:
            CAT.write_bytes(self._cat_before)
        if self._poster_bytes is not None and POSTER.exists():
            if POSTER.read_bytes() != self._poster_bytes:
                POSTER.write_bytes(self._poster_bytes)

    def _temp_json(self, directory: Path) -> tuple[Path, Path]:
        published = directory / "published-demos.json"
        catalog = directory / "demo-catalog.json"
        published.write_bytes(self._pub_before)
        catalog.write_bytes(self._cat_before)
        ids = [str(item) for item in json.loads(published.read_text()) if str(item) != FILM_ID]
        published.write_text(json.dumps(ids, indent=2) + "\n")
        return published, catalog

    def _env(self, movies: Path, published: Path, catalog: Path, posters: Path) -> dict[str, str]:
        env = os.environ.copy()
        env["SX_MOVIES_OUT"] = str(movies)
        env["SX_PUBLISHED_JSON"] = str(published)
        env["SX_CATALOG_JSON"] = str(catalog)
        env["SX_POSTER_DIR"] = str(posters)
        return env

    def _run(self, args: list[str], env: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SCRIPT), *args],
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
            posters = tmp / "posters"
            movies.mkdir()
            posters.mkdir()
            (movies / f"{FILM_ID}.webm").write_bytes(b"webm")
            published, catalog = self._temp_json(tmp)
            pub_bytes, cat_bytes = published.read_bytes(), catalog.read_bytes()
            proc = self._run(
                ["--dry-run", "--feature", FILM_ID],
                self._env(movies, published, catalog, posters),
            )
            self.assertEqual(proc.returncode, 0, proc.stdout + "\n" + proc.stderr)
            out = proc.stdout
            self.assertIn(f"dry-run poster: {FILM_ID}", out)
            self.assertIn("dry-run upload", out)
            self.assertIn(FILM_ID, out)
            self.assertIn("dry-run: no gh call, no file change", out)
            self.assertEqual(published.read_bytes(), pub_bytes)
            self.assertEqual(catalog.read_bytes(), cat_bytes)
            self.assertFalse(any(posters.iterdir()))
        self.assertEqual(PUB.read_bytes(), self._pub_before)
        self.assertEqual(CAT.read_bytes(), self._cat_before)
        if self._poster_bytes is not None:
            self.assertEqual(POSTER.read_bytes(), self._poster_bytes)

    def test_skip_upload_appends_id_once_and_leaves_repo_json_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            movies = tmp / "movies"
            posters = tmp / "posters"
            movies.mkdir()
            posters.mkdir()
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
            published, catalog = self._temp_json(tmp)
            env = self._env(movies, published, catalog, posters)
            env["SX_SKIP_UPLOAD"] = "1"
            proc = self._run(["--feature", FILM_ID], env)
            self.assertEqual(proc.returncode, 0, proc.stdout + "\n" + proc.stderr)
            got = [str(item) for item in json.loads(published.read_text())]
            self.assertEqual(len(got), len(set(got)))
            self.assertEqual(got.count(FILM_ID), 1)
            featured = json.loads(catalog.read_text()).get("featured", [])
            self.assertEqual(sum(1 for row in featured if row.get("id") == FILM_ID), 1)
            self.assertEqual(len(featured), len(_curated_ids()))
            self.assertTrue((posters / f"{FILM_ID}.png").is_file())
        self.assertEqual(PUB.read_bytes(), self._pub_before)
        self.assertEqual(CAT.read_bytes(), self._cat_before)
        if self._poster_bytes is not None:
            self.assertEqual(POSTER.read_bytes(), self._poster_bytes)

    def test_website_demos_helper_lists_hero_first(self) -> None:
        self.assertTrue(HELPER.is_file())
        ids = _curated_ids()
        self.assertEqual(ids[0], FILM_ID)
        self.assertEqual(len(ids), len(set(ids)))


class WebsiteTiersTests(unittest.TestCase):
    """Homepage tier vs features-page set, from tools/website_demos.py."""

    def setUp(self) -> None:
        import sys
        sys.path.insert(0, str(ROOT / "tools"))
        import website_demos
        self.wd = website_demos
        self.rows = website_demos.curated()

    def test_live_manifest_validates(self) -> None:
        self.assertEqual(self.wd.validate_curated(), [])

    def test_home_tier_is_a_few_with_hero_first(self) -> None:
        home = self.wd.home_rows(self.rows)
        self.assertTrue(self.wd.HOME_MIN <= len(home) <= self.wd.HOME_MAX)
        self.assertEqual(home[0]["id"], FILM_ID)
        self.assertTrue(home[0]["hero"])
        self.assertLess(len(home), len(self.rows))

    def test_every_film_is_in_a_known_group(self) -> None:
        for r in self.rows:
            self.assertIn(r["group"], self.wd.GROUPS, r["id"])

    def test_catalog_lists_every_curated_film(self) -> None:
        cat = json.loads(CAT.read_text())
        self.assertEqual([f["id"] for f in cat["featured"]], [r["id"] for r in self.rows])
        self.assertEqual(cat["groups"], list(self.wd.GROUPS))
        self.assertEqual(json.loads(PUB.read_text()), [r["id"] for r in self.rows])

    def test_validation_rejects_bad_tiers(self) -> None:
        manifest = self.wd.load_manifest()
        for e in manifest:
            site = e.get("website")
            if isinstance(site, dict):
                site.pop("home", None)
        errs = self.wd.validate_curated(manifest, published=[], catalog={})
        self.assertTrue(any("website.home" in e for e in errs), errs)
        manifest = self.wd.load_manifest()
        next(e for e in manifest if e.get("website"))["website"]["group"] = "Nope"
        errs = self.wd.validate_curated(manifest, published=[], catalog={})
        self.assertTrue(any("website.group" in e for e in errs), errs)

if __name__ == "__main__":
    unittest.main()
