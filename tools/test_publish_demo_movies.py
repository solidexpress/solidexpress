#!/usr/bin/env python3
"""Dry-run coverage for scripts/sx-publish-demo-movies ID mode."""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "sx-publish-demo-movies"
PUB = ROOT / "website" / "assets" / "published-demos.json"
CAT = ROOT / "website" / "assets" / "demo-catalog.json"


class PublishDemoMoviesTests(unittest.TestCase):
    def test_dry_run_feature_id_prints_and_does_not_write(self) -> void:
        pub_before = PUB.read_text()
        cat_before = CAT.read_text()
        with tempfile.TemporaryDirectory() as raw:
            movies = Path(raw)
            (movies / "ubc_wrench.webm").write_bytes(b"webm")
            env = os.environ.copy()
            env["SX_MOVIES_OUT"] = str(movies)
            proc = subprocess.run(
                ["bash", str(SCRIPT), "--dry-run", "--feature", "ubc_wrench"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
        self.assertEqual(proc.returncode, 0, proc.stdout + "\n" + proc.stderr)
        out = proc.stdout
        self.assertIn("dry-run poster: ubc_wrench", out)
        self.assertIn("dry-run upload", out)
        self.assertIn("ubc_wrench", out)
        self.assertIn("dry-run: no gh call, no file change", out)
        self.assertEqual(PUB.read_text(), pub_before)
        self.assertEqual(CAT.read_text(), cat_before)
        self.assertNotIn("ubc_wrench", json.loads(pub_before))


if __name__ == "__main__":
    unittest.main()
