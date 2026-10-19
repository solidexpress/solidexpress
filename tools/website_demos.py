#!/usr/bin/env python3
"""Curated website demos — single source of truth.

Manifest entries with a `website` object are the curated set. Two tiers:

  features page  every curated film, grouped by `website.group` (GROUPS order)
  homepage       films with `website.home: true` (HOME_MIN..HOME_MAX of them);
                 exactly one of those is `website.hero: true`

This module orders them (hero first, then `order`) and emits:

  website/assets/published-demos.json  (every curated id)
  website/assets/demo-catalog.json     (featured = all curated rows, with
                                        group/home/hero; groups = GROUPS)

Used by scripts/sx-publish-demo-movies, scripts/sx-check-website-demos, and
`python3 tools/website_demos.py check`.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "game" / "tests" / "ui_movie_manifest.json"
PUBLISHED_PATH = ROOT / "website" / "assets" / "published-demos.json"
CATALOG_PATH = ROOT / "website" / "assets" / "demo-catalog.json"
DEFAULT_POSTERS = ROOT / "website" / "assets" / "screenshots"

WEBSITE_KEYS = ("feature", "title", "caption", "group", "order", "home", "hero")
MAX_CAPTION = 110
# Features-page sections, in display order. Every curated film names one.
GROUPS = (
    "Projects, end to end",
    "Sketching",
    "Part modeling",
    "Assemblies, drawings & output",
)
# The homepage shows a few films (hero included) and links to the rest.
HOME_MIN, HOME_MAX = 3, 6


def poster_dir() -> Path:
    override = os.environ.get("SX_POSTER_DIR", "").strip()
    return Path(override) if override else DEFAULT_POSTERS


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def load_manifest(path: Path | None = None) -> list[dict]:
    data = load_json(path or MANIFEST)
    if not isinstance(data, list):
        raise ValueError(f"{path or MANIFEST} must be a JSON array")
    return [e for e in data if isinstance(e, dict)]


def _website_raw(entry: dict) -> dict | None:
    site = entry.get("website")
    return site if isinstance(site, dict) else None


def _row(entry: dict) -> dict:
    site = _website_raw(entry) or {}
    film_id = str(entry.get("id", ""))
    caption = str(site.get("caption") or entry.get("blurb") or "")
    title = str(site.get("title") or entry.get("title") or film_id)
    feature = str(site.get("feature") or title)
    return {
        "id": film_id,
        "feature": feature,
        "title": title,
        "caption": caption,
        "group": str(site.get("group") or ""),
        "order": int(site.get("order", 0)),
        "home": bool(site.get("home", False)),
        "hero": bool(site.get("hero", False)),
        "enabled": bool(entry.get("enabled", True)),
    }


def curated(manifest: list[dict] | None = None) -> list[dict]:
    """Website entries, hero first, then `order`, then id."""
    rows = [_row(e) for e in (manifest if manifest is not None else load_manifest()) if _website_raw(e)]
    rows.sort(key=lambda r: (0 if r["hero"] else 1, r["order"], r["id"]))
    return rows


def curated_ids(manifest: list[dict] | None = None) -> list[str]:
    return [r["id"] for r in curated(manifest)]


CATALOG_KEYS = ("id", "feature", "title", "caption", "group", "order", "home", "hero")


def featured_rows(rows: list[dict] | None = None) -> list[dict]:
    """All curated films (features page); `home` / `hero` mark the homepage tier."""
    return [{k: r[k] for k in CATALOG_KEYS} for r in (rows if rows is not None else curated())]


def home_rows(rows: list[dict] | None = None) -> list[dict]:
    return [r for r in (rows if rows is not None else curated()) if r["home"]]


def write_published(path: Path, rows: list[dict] | None = None) -> list[str]:
    ids = [r["id"] for r in (rows if rows is not None else curated())]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(ids, indent=2) + "\n")
    return ids


def demo_release(repo: str, tag: str) -> dict:
    """Where the browser fetches demo WebMs: the Release the publisher uploaded to."""
    return {
        "repo": repo,
        "tag": tag,
        "api": f"https://api.github.com/repos/{repo}/releases/tags/{tag}",
        "base": f"https://github.com/{repo}/releases/download/{tag}/",
    }


def write_featured(
    catalog_path: Path,
    rows: list[dict] | None = None,
    release: dict | None = None,
) -> list[dict]:
    cat = load_json(catalog_path) if catalog_path.is_file() else {}
    if not isinstance(cat, dict):
        cat = {}
    featured = featured_rows(rows)
    if release is not None:
        cat["demo_release"] = release
    cat["groups"] = list(GROUPS)
    cat["featured"] = featured
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(json.dumps(cat, indent=2) + "\n")
    return featured


def emit(
    published_path: Path | None = None,
    catalog_path: Path | None = None,
    manifest_path: Path | None = None,
    release: dict | None = None,
) -> tuple[list[str], list[dict]]:
    rows = curated(load_manifest(manifest_path) if manifest_path else None)
    ids = write_published(published_path or PUBLISHED_PATH, rows)
    featured = write_featured(catalog_path or CATALOG_PATH, rows, release)
    return ids, featured


def validate_curated(
    manifest: list[dict] | None = None,
    published: list | None = None,
    catalog: dict | None = None,
) -> list[str]:
    errors: list[str] = []
    rows = curated(manifest)
    ids = [r["id"] for r in rows]
    if not rows:
        errors.append("no curated website entries")
    home = home_rows(rows)
    if not HOME_MIN <= len(home) <= HOME_MAX:
        errors.append(f"expected {HOME_MIN}..{HOME_MAX} website.home films, got {len(home)}")
    if len(set(ids)) != len(ids):
        errors.append("duplicate curated ids")
    orders = [r["order"] for r in rows]
    if len(set(orders)) != len(orders):
        errors.append("duplicate website.order values")
    heroes = [r for r in rows if r["hero"]]
    if len(heroes) != 1:
        errors.append(f"expected exactly one hero, got {len(heroes)}")
    elif rows and not rows[0]["hero"]:
        errors.append(f"hero must sort first, first id is {rows[0]['id']!r}")
    elif not heroes[0]["home"]:
        errors.append(f"hero {heroes[0]['id']!r} must also set website.home")
    for r in rows:
        if not r["id"]:
            errors.append("website entry missing id")
        for key in ("feature", "title", "caption"):
            if not str(r.get(key, "")).strip():
                errors.append(f"{r['id']!r} missing website.{key}")
        if r["group"] not in GROUPS:
            errors.append(f"{r['id']!r} website.group {r['group']!r} not in {list(GROUPS)}")
        if len(r["caption"]) > MAX_CAPTION:
            errors.append(
                f"{r['id']!r} caption is {len(r['caption'])} chars (max {MAX_CAPTION})"
            )
        if not r["enabled"]:
            errors.append(f"curated {r['id']!r} is disabled")

    if catalog is None and CATALOG_PATH.is_file():
        catalog = load_json(CATALOG_PATH)
    if isinstance(catalog, dict):
        featured = catalog.get("featured") or []
        feat_ids = [str(e.get("id", "")) for e in featured if isinstance(e, dict)]
        want_ids = ids
        if feat_ids != want_ids:
            errors.append(
                f"demo-catalog featured ids {feat_ids} != curated {want_ids} "
                "(featured must be all curated, hero included)"
            )
        else:
            for feat, row in zip(featured, rows):
                for key in ("group", "home", "hero"):
                    if feat.get(key) != row[key]:
                        errors.append(f"featured {row['id']!r} {key} mismatch; regenerate")
        if catalog.get("groups") != list(GROUPS):
            errors.append("demo-catalog groups != website_demos.GROUPS; regenerate")

    if published is None and PUBLISHED_PATH.is_file():
        published = load_json(PUBLISHED_PATH)
    if isinstance(published, list):
        pub_ids = [str(x) for x in published]
        extra = [i for i in pub_ids if i not in set(ids)]
        missing = [i for i in ids if i not in set(pub_ids)]
        if missing:
            errors.append(f"published-demos.json lacks curated ids ({', '.join(missing)})")
        if extra:
            errors.append(
                "published-demos.json has non-curated ids "
                f"({', '.join(extra)}); regenerate from the manifest"
            )
        if len(set(pub_ids)) != len(pub_ids):
            errors.append("published-demos.json has duplicate ids")
    return errors


def check(offline: bool = True) -> int:
    del offline  # structural check; live Release HEAD stays in sx-check-website-demos
    try:
        errors = validate_curated()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        errors = [str(exc)]
    for e in errors:
        print(f"website_demos: {e}", file=sys.stderr)
    if errors:
        return 1
    rows = curated()
    home = [r["id"] for r in home_rows(rows)]
    print(f"website_demos: ok — {len(rows)} curated, home={','.join(home)}")
    return 0


def _cmd_ids(_: argparse.Namespace) -> int:
    for i in curated_ids():
        print(i)
    return 0


def _cmd_emit(args: argparse.Namespace) -> int:
    ids, featured = emit(
        published_path=Path(args.published) if args.published else None,
        catalog_path=Path(args.catalog) if args.catalog else None,
        release=demo_release(args.repo, args.tag) if args.repo else None,
    )
    print(f"published-demos → {len(ids)} ids")
    print(f"demo-catalog featured → {len(featured)} rows")
    return 0


def _cmd_check(args: argparse.Namespace) -> int:
    return check(offline=args.offline)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("ids", help="print curated ids, hero first")
    sub.add_parser("home-ids", help="print homepage ids, hero first")
    p_emit = sub.add_parser("emit", help="write published-demos.json + catalog featured")
    p_emit.add_argument("--published", default="")
    p_emit.add_argument("--catalog", default="")
    p_emit.add_argument("--repo", default="", help="Release repo the WebMs were uploaded to")
    p_emit.add_argument("--tag", default="demo-movies")
    p_check = sub.add_parser("check", help="validate curated set vs catalog")
    p_check.add_argument("--offline", action="store_true", default=True)
    args = parser.parse_args(argv)
    if args.cmd == "ids":
        return _cmd_ids(args)
    if args.cmd == "home-ids":
        for r in home_rows():
            print(r["id"])
        return 0
    if args.cmd == "emit":
        return _cmd_emit(args)
    return _cmd_check(args)


if __name__ == "__main__":
    sys.exit(main())
