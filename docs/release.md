# Release pipeline

SolidExpress ships desktop builds via **git tags** and GitHub Actions. Start with Linux; Windows and macOS use the same Godot export presets once native deps are built on those hosts.

## Versioning

- Single source: `VERSION` at repo root (SemVer, e.g. `0.1.0`).
- Release tags: `v0.1.0` (CI syncs `VERSION` from the tag).

## One-time setup (Linux)

```bash
./scripts/release/fetch-godot-templates.sh   # Godot 4.7 + export templates
make build
```

## Local Linux release

```bash
./scripts/release/export-linux.sh
```

Outputs:

- `dist/releases/SolidExpress-<version>-linux-x86_64/` — runnable folder
- `dist/releases/SolidExpress-<version>-linux-x86_64.tar.gz`
- `dist/releases/SolidExpress-<version>-linux-x86_64.tar.gz.sha256`

The script copies `libplanegcs.so` next to the exported binary (LGPL dynamic link).

## CI release (recommended)

```bash
git tag v0.1.0
git push origin v0.1.0
```

Workflow `.github/workflows/release.yml`:

1. Kernel tests on Ubuntu
2. `export-linux.sh` / `export-windows.sh` / `export-macos.sh`
3. macOS: Developer ID sign, `notarytool`, staple (`packaging/macos/sign-and-notarize.sh`)
4. GitHub Release with Linux/Windows/macOS artifacts + checksums

macOS signing secrets (repo Actions secrets):

- `APPLE_CERTIFICATE` — base64 Developer ID Application `.p12`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_API_KEY_ID` / `APPLE_API_ISSUER_ID` / `APPLE_API_KEY` — App Store Connect API key (`.p8` contents)

## Demo movies (marketing site)

Needs a GPU/display (not covered by `release.yml` on GitHub-hosted runners):

```bash
make movies                 # → dist/movies/*.webm
make publish-demo-movies    # posters → ../solidexpress.github.io; WebMs → website Release tag demo-movies
```

Then commit/push poster (and any HTML) changes in `solidexpress.github.io`. Do this each app release so solid.express demos match the shipped build.

Godot presets are in `game/export_presets.cfg` (`Windows Desktop`, `macOS`). Steps:

1. Build `libsxcore` for the target OS into `game/bin/` (CMake + godot-cpp cross-compile or native).
2. Copy `libplanegcs` (`.dll` / `.dylib`) beside the GDExtension.
3. Install matching Godot 4.7 export templates for that OS.
4. Export from Godot or:

   ```bash
   godot --headless --path game --export-release "Windows Desktop" dist/...
   godot --headless --path game --export-release "macOS" dist/...
   ```

**macOS:** Sign with Developer ID Application, notarize (`notarytool`), staple. App Store is optional and requires sandbox entitlements.

**Windows:** Authenticode-sign the `.exe`/installer; EV cert speeds SmartScreen reputation.

**Linux store:** Flatpak manifest (Flathub) can wrap the same tarball layout.

## Makefile shortcuts

```bash
make release-linux    # same as export-linux.sh (after fetch-godot-templates)
```

## Next CI steps
- Windows vcpkg binary cache key: bump the cache key in .github/workflows/release.yml together with EXPECTED_VCPKG_WIN_CACHE_KEY in scripts/release/test_windows_vcpkg_cache_key.py (CI pin test).
