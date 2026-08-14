# SolidExpress marketing site (canonical source)

This directory is the **canonical** source for [solid.express](https://solid.express).
Deploy by syncing to the GitHub Pages repo:

```bash
# from the app repo
scripts/sx-sync-website
# then commit + push inside ../solidexpress.github.io
```

Demo preview posters live in `assets/screenshots/`. Full demo WebMs are on the
[`demo-movies`](https://github.com/solidexpress/solidexpress.github.io/releases/tag/demo-movies)
Release on the Pages repo. Refresh from the app repo:

```bash
make movies && scripts/sx-publish-demo-movies
scripts/sx-sync-website   # also copies ui_movie_manifest.json
```

## Download links (hard rule)

Every platform button must hydrate from **`/repos/solidexpress/solidexpress/releases/latest` only**.
Never fall back to an older release when an asset is missing (that is how macOS used to keep serving `v0.0.1` while the page claimed a newer version). See `.cursor/rules/website-latest-release-downloads.mdc`.
