#!/usr/bin/env python3
"""Pin Windows vcpkg cache key from release.yml.

Bump EXPECTED_VCPKG_WIN_CACHE_KEY when changing the windows job cache key
in .github/workflows/release.yml (Cache vcpkg binary packages).
"""
from pathlib import Path
import re
import unittest

# Update together with windows job cache key: in release.yml.
EXPECTED_VCPKG_WIN_CACHE_KEY = (
    "vcpkg-win-x64-opencascade-eigen3-tbb-boost-system-filesystem-graph"
)

REPO_ROOT = Path(__file__).resolve().parents[2]
RELEASE_YML = REPO_ROOT / ".github" / "workflows" / "release.yml"


class WindowsVcpkgCacheKeyTest(unittest.TestCase):
    def test_release_yml_cache_key_matches_pin(self):
        text = RELEASE_YML.read_text(encoding="utf-8")
        match = re.search(r"key:\s*(vcpkg-win-x64-\S+)", text)
        self.assertIsNotNone(match, "cache key not found")
        self.assertEqual(match.group(1), EXPECTED_VCPKG_WIN_CACHE_KEY)


if __name__ == "__main__":
    raise SystemExit(unittest.main())
