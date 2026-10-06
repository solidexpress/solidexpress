# Linux test build (not a release)

Rolling Linux GUI-test tarball published by `.github/workflows/linux-test-build.yml`.
It replaces box-local Linux test builds so a tester box can `curl` a binary with
**no GitHub login** (Actions artifacts need a token; this prerelease does not).

This is **not** a product release. The tag is `linux-test-build`, always a
prerelease, and is never GitHub “latest”. Real versioned builds still come from
`release.yml` on `v*` tags.

## Download (no login)

Stable names (overwritten every successful run):

```
https://github.com/solidexpress/solidexpress/releases/download/linux-test-build/SolidExpress-linux-test-latest-x86_64.tar.gz
https://github.com/solidexpress/solidexpress/releases/download/linux-test-build/SolidExpress-linux-test-latest-x86_64.tar.gz.sha256
https://github.com/solidexpress/solidexpress/releases/download/linux-test-build/BUILDINFO.txt
```

Each run also uploads `SolidExpress-<shortsha>-linux-x86_64.tar.gz` (+ `.sha256`)
for the commit that was built. Older shortsha assets are deleted so the
prerelease only holds the current files.

```bash
curl -fsSL -O https://github.com/solidexpress/solidexpress/releases/download/linux-test-build/SolidExpress-linux-test-latest-x86_64.tar.gz
curl -fsSL -O https://github.com/solidexpress/solidexpress/releases/download/linux-test-build/SolidExpress-linux-test-latest-x86_64.tar.gz.sha256
curl -fsSL -O https://github.com/solidexpress/solidexpress/releases/download/linux-test-build/BUILDINFO.txt
sha256sum -c SolidExpress-linux-test-latest-x86_64.tar.gz.sha256
cat BUILDINFO.txt
```

## Verify the commit

`BUILDINFO.txt` is a few lines:

```
commit=<full git sha>
occt=8.0.1
godot=<Godot --version>
built_at_utc=<ISO-8601 UTC>
```

Match `commit=` to `origin/main` (or the ref you dispatched). The tarball is
the same client `scripts/release/export-linux.sh` produces for a real Linux
release (no Flatpak/Snap).

## When it runs

- **Push to `main`**, except when the push only touches `docs/**`, `website/**`,
  or root `*.md`.
- **`workflow_dispatch`**, with an optional `ref` (branch, tag, or SHA).
- No `pull_request` trigger. A newer run **cancels** an older in-flight run
  (including a dispatch cancelled by a later `main` push).

### Dispatch a specific ref

GitHub UI: Actions → `linux-test-build` → Run workflow. Leave **Use workflow
from** on `main` (that is the workflow file). Set **ref** to the branch, tag,
or SHA to export.

With `gh` (maintainers; testers do not need this):

```bash
# Build current main (workflow file + source both from main)
gh workflow run linux-test-build.yml --ref main

# Build some other commit, still using the workflow file on main
gh workflow run linux-test-build.yml --ref main -f ref=abc1234
gh workflow run linux-test-build.yml --ref main -f ref=my-branch
```

Wait until the run is green, then download the stable URL above. The
prerelease title is `Linux test build (not a release)`.
