# Binary distributions — your checklist

This document is the **operator runbook** for shipping SolidExpress on Linux, Windows, and macOS, plus optional store channels (Flathub, Microsoft Store, Mac App Store). It assumes the repo already has `VERSION`, Godot export presets, `scripts/release/`, and `.github/workflows/release.yml` (Linux tag releases).

For pipeline internals, see [release.md](./release.md).

---

## Overview

| Channel | Status in repo | What you do |
|--------|----------------|-------------|
| Linux `.tar.gz` | **Automated** on `v*` tags | Tag + push; optional local smoke test |
| Linux Flatpak / Flathub | **Not wired yet** | Manifest + Flathub PR (steps below) |
| Windows installer | **Presets only** | Build `libsxcore` on Windows, export, sign |
| macOS `.dmg` (notarized) | **Presets only** | Build on Mac, export, sign + notarize |
| GitHub Releases | **Automated** (Linux) | Same as Linux tag |
| Microsoft Store | **Manual** | MSIX + Partner Center |
| Mac App Store | **Manual / high effort** | Sandbox + separate export profile |

**Recommended order:** GitHub Releases (Linux) → notarized macOS → signed Windows → Flathub → other stores.

---

## Prerequisites (all platforms)

### Accounts and legal

- [ ] **GitHub**: push access to `solidexpress/solidexpress`; Actions enabled on the repo.
- [x] **Privacy policy URL** (required for stores): https://solid.express/privacy.html
- [x] **Support channel**: https://solid.express/support.html → [GitHub Issues](https://github.com/solidexpress/solidexpress/issues)
- [x] **Third-party notices**: root `NOTICE` (+ `LICENSE`, `THIRD_PARTY.md`) copied into every export by `scripts/release/export-*.sh`

### Versioning (every release)

1. Edit `VERSION` at repo root (SemVer, e.g. `0.2.0`).
2. Commit on `main`.
3. Tag **`v` + same version**: `git tag v0.2.0 && git push origin v0.2.0`.
4. CI reads the tag and syncs `VERSION` during the Linux job.

Do not tag without intending to publish; the release workflow runs on every `v*` push.

### Godot version lock

- Project targets **Godot 4.7** (see `scripts/release/fetch-godot-templates.sh`, default `GODOT_VERSION=4.7.stable`).
- Export templates on each machine must **match** the editor used to export.

---

## Phase 1 — Linux tarball (GitHub Releases)

**Goal:** Users download `SolidExpress-<version>-linux-x86_64.tar.gz` from GitHub Releases.

### One-time (your dev machine)

```bash
cd /path/to/solidexpress
./scripts/release/fetch-godot-templates.sh   # Godot 4.7 + templates → tools/godot/
make build                                   # or let export-linux.sh build
```

Ubuntu deps (same as CI): `cmake`, `ninja-build`, `g++`, OCCT dev packages, `libeigen3-dev`, `libboost-dev` — see `.github/workflows/release.yml`.

### Verify locally before tagging

```bash
./scripts/release/export-linux.sh
# or: make release-linux

tar -xzf dist/releases/SolidExpress-*.tar.gz -C /tmp
/tmp/SolidExpress-*-linux-x86_64/SolidExpress.x86_64   # smoke: launch, quit
```

Check:

- [ ] `SolidExpress.x86_64` runs on a clean-ish Ubuntu (22.04/24.04).
- [ ] `libsxcore.so`, `libplanegcs.so`, and OCCT/TBB (via `packaging/linux/bundle-shared-libs.sh`) are next to the binary with `RUNPATH=$ORIGIN`.
- [ ] `.sha256` file matches: `sha256sum -c dist/releases/*.sha256`.

### Publish

```bash
git tag v0.2.0
git push origin v0.2.0
```

GitHub Actions (`release.yml`):

1. Kernel tests
2. `export-linux.sh`
3. Upload artifact → **GitHub Release** with `.tar.gz` + checksum

### After publish

- [ ] Update [solidexpress.github.io](https://github.com/solidexpress/solidexpress.github.io) download links to the latest Release asset URL.
- [ ] Attach release notes (features, known issues, build from source fallback).

---

## Phase 2 — Linux Flatpak (optional “store”)

**Goal:** `flatpak install flathub com.solidexpress.SolidExpress` (after Flathub accepts your app).

Flatpak is **not** in CI yet. Add under `packaging/flatpak/` (suggested):

- `com.solidexpress.SolidExpress.yml` — manifest
- `com.solidexpress.SolidExpress.metainfo.xml` — AppStream (screenshots from UI films / marketing site)
- `solidexpress-wrapper` — sets `LD_LIBRARY_PATH=/app/lib` if needed

### Manifest strategy (simplest)

1. **Pin the GitHub Release tarball** as a source URL in the manifest (version = tag).
2. Install files into `/app/bin` and `/app/lib` mirroring the tarball layout.
3. **finish-args** (typical CAD):

   ```yaml
   finish-args:
     - --share=ipc
     - --socket=fallback-x11
     - --socket=wayland
     - --device=dri
     - --filesystem=home
     # tighten later: xdg-documents, xdg-download only
   ```

### Your steps

- [ ] `flatpak-builder` locally against the manifest; run the app from the sandbox.
- [ ] `ldd` on `SolidExpress.x86_64` inside the bundle — no missing host-only libs (OCCT must be in `libsxcore`, not system OCCT).
- [ ] LGPL: document PlaneGCS/OCCT compliance in metainfo + Flathub PR description.
- [ ] Submit to Flathub: fork their repo pattern, open PR; wait for review.
- [ ] Optional CI job: on tag, build `.flatpak` bundle and attach to GitHub Release **in addition** to `.tar.gz`.

---

## Phase 3 — Windows

**Goal:** Signed `SolidExpress.exe` (zip or installer) on GitHub Releases.

CI job `windows` in `release.yml` is **`if: false`** until you provision OCCT + godot-cpp on `windows-latest`.

### One-time setup

- [ ] **Windows 10/11** dev PC or VM with Visual Studio Build Tools, CMake, Ninja.
- [ ] Build **Open CASCADE** and **godot-cpp** for `x64`, produce `libsxcore.dll` → `game/bin/`.
- [ ] Build or obtain **`libplanegcs.dll`** beside the GDExtension (LGPL dynamic link).
- [ ] Install Godot 4.7 + **Windows export templates**.
- [ ] **Code signing cert** (OV or EV) for Authenticode — store PFX for CI later.

### Export (local)

```powershell
# After cmake Release build and game/bin populated:
godot --headless --path game --export-release "Windows Desktop" dist\releases\SolidExpress.exe
```

Copy `libplanegcs.dll` (and any other runtime DLLs `dumpbin /dependents` or `ldd` equivalent requires) next to the exe.

### Package

- [ ] Zip folder **or** build **Inno Setup** / WiX installer (recommended for users).
- [ ] **Sign** exe and installer: `signtool sign /fd SHA256 ...`

### CI (when ready)

- [ ] Enable `windows` job: vcpkg or cached OCCT, build sxkernel/sxcore, Godot export, sign with secrets `WINDOWS_CERT_PFX`, `WINDOWS_CERT_PASSWORD`.
- [ ] Attach `.zip` or `.exe` installer to the **same** GitHub Release as Linux.

### Microsoft Store (optional, later)

- [ ] Enroll [Microsoft Partner Center](https://partner.microsoft.com/) (individual or company).
- [ ] Package as **MSIX** (Desktop Bridge or dedicated MSIX project).
- [ ] Store policy review, age rating, privacy URL.
- [ ] Promote **same signed build** you tested on GitHub — do not maintain a second build system.

---

## Phase 4 — macOS (Developer ID + notarization)

**Goal:** Notarized `.dmg` or `.zip` for direct download (best fit for CAD).

You have an **Apple Developer Program** membership.

### One-time setup (Mac with Xcode CLT)

- [ ] **Developer ID Application** certificate in Keychain (or export for CI).
- [ ] **App Store Connect API key** (recommended) or app-specific password for `notarytool`.
- [ ] Build **libsxcore** for macOS (`game/bin/libsxcore.dylib`) + **libplanegcs.dylib**.
- [ ] Godot 4.7 + **macOS export templates** (universal or separate arm64/x64).
- [ ] In Godot export preset: enable **Hardened Runtime**, set entitlements plist (file access; **no App Sandbox** for direct-download CAD unless you design for it).

### Export (local)

Prefer the release script (builds sxcore, exports, **bundles Homebrew OCCT into Frameworks**):

```bash
./scripts/release/export-macos.sh
# or manually after Godot export:
./packaging/macos/bundle-dylibs.sh dist/releases/SolidExpress-<ver>-macos/SolidExpress.app
```

`libsxcore.dylib` links OCCT from Homebrew (`/opt/homebrew/opt/opencascade/...`). Without bundling, end users get a grey empty window because `SxDocument` never registers.

### Sign and notarize

1. Run `bundle-dylibs.sh` first (rewrites install names; ad-hoc signs).
2. Sign all binaries inside `.app` (Frameworks, MacOS, dylibs) with Developer ID.
3. Sign the `.app` bundle: `codesign --force --deep --options runtime --sign "Developer ID Application: ..." SolidExpress.app`
4. Submit: `xcrun notarytool submit SolidExpress.zip --apple-id ... --team-id ... --password ... --wait`
5. Staple: `xcrun stapler staple SolidExpress.app` (or staple the dmg).

Checklist:

- [ ] Gatekeeper: `spctl -a -vv SolidExpress.app` passes on another Mac.
- [ ] OpenGL/Metal viewport works with `--device=dri` equivalent (full macOS — no Flatpak-style args).

### CI (when ready)

- [ ] Enable `macos` job in `release.yml` with `macos-latest`, secrets for signing + notary API key.
- [ ] Upload stapled `.dmg` to GitHub Release.

### Mac App Store (optional, high effort)

- [ ] Separate export with **App Sandbox** on.
- [ ] Security-scoped bookmarks for user file pickers; no arbitrary filesystem.
- [ ] App Review; often **not** the first macOS channel for full CAD.

---

## Phase 5 — Store assets and marketing sync

Use one set of assets everywhere:

| Asset | Source |
|-------|--------|
| Icon 512×512 | `docs/branding/logo.png` |
| Screenshots | `make movies` → last frames via `make publish-demo-movies` (PNG posters on GitHub Pages; full WebMs on solidexpress.github.io Release `demo-movies`) |
| Short description | solidexpress.github.io tagline |
| Long description | README + feature list |
| Privacy policy | https://solid.express/privacy.html |
| Support | https://solid.express/support.html |
| Copyright / license | Apache-2.0 (`LICENSE`) + `NOTICE` / `THIRD_PARTY.md` for OCCT/PlaneGCS/etc. |

- [ ] Flathub: `metainfo.xml` screenshots + releases
- [ ] Microsoft Partner Center: listing + MSIX
- [ ] Apple App Store Connect (if MAS): separate listing

---

## Simple release process (recurring)

Use this every version:

1. **Develop** on `main`; keep `make test` green.
2. **Bump** `VERSION`; commit.
3. **Local smoke** (at least Linux): `./scripts/release/export-linux.sh` and run binary.
4. **Tag** `vX.Y.Z` and push.
5. **Wait** for GitHub Actions release workflow; verify Release assets and checksums.
6. **Smoke** download Release tarball on a clean VM.
7. **Demo movies** (GPU machine — not in CI yet):
   ```bash
   make movies && make publish-demo-movies
   ```
   Uploads WebMs to [solidexpress.github.io `demo-movies`](https://github.com/solidexpress/solidexpress.github.io/releases/tag/demo-movies) and refreshes PNG posters in the Pages checkout. Commit and push poster/HTML changes in `solidexpress.github.io`.
8. **Update** marketing site download links / README “Latest release” if the version changed.
9. **Optional manual gates** (until CI secrets exist):
   - macOS: notarize local export, upload dmg to Release manually
   - Windows: sign installer, upload manually
10. **Store promotion** (when ready): bump Flatpak manifest tag; submit MSIX / MAS builds that match the GitHub Release version.

---

## CI secrets cheat sheet (when enabling Win/Mac jobs)

| Secret | Purpose |
|--------|---------|
| `GITHUB_TOKEN` | Already used for Releases |
| Apple `AC_*` / App Store Connect API key | Notarization |
| `APPLE_CERTIFICATE` + password | codesign in CI (base64 .p12) |
| `WINDOWS_CERT_PFX` + password | Authenticode |

Document secret rotation in your password manager; never commit certs.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Export fails “No export template” | Run `fetch-godot-templates.sh`; template version must match Godot |
| App starts, no OCCT / crash on open | `libsxcore` missing or wrong arch; or OCCT not bundled (Linux/macOS/Windows packagers must ship TK* next to the GDExtension) |
| Sketch constraints fail | `libplanegcs.so` / `.dll` / `.dylib` beside binary or in `game/bin/` |
| Linux CI fails kernel tests | Fix on `main` before re-tagging (prefer new tag, not force-push) |
| macOS “damaged” / Gatekeeper | Notarization + staple; or quarantine `xattr -cr` for local dev only |
| macOS grey empty window / can’t open libsxcore | OCCT dylibs not bundled — `packaging/macos/bundle-dylibs.sh` (wired into `export-macos.sh`). Workaround: `brew install opencascade`. |
| Windows missing TK*.dll | `packaging/windows/bundle-dlls.sh` must run against `libsxcore.dll` (not only the .exe). |
| Windows SmartScreen | Sign binary; EV cert helps reputation over time |
| Flatpak blank window | `--device=dri`, Wayland/X11 sockets; verify GL in sandbox |

---

## What to implement next in the repo (engineering)

Track these as issues if not done:

1. [ ] `packaging/flatpak/` manifest + metainfo + CI artifact
2. [ ] Enable `windows` / `macos` jobs with cached OCCT/godot-cpp
3. [ ] `scripts/release/export-windows.sh` / `export-macos.sh` mirroring Linux
4. [ ] Inno Setup or WiX script under `packaging/windows/`
5. [x] Runtime lib bundlers: `packaging/linux/bundle-shared-libs.sh`, `packaging/windows/bundle-dlls.sh`, `packaging/macos/bundle-dylibs.sh` (+ dmg script)
6. [x] `NOTICE` file bundled in all exports (`export-linux.sh` / `export-windows.sh` / `export-macos.sh`)
7. [x] Release workflow: attach all three OS artifacts + unified release notes

---

## Quick reference commands

```bash
# Linux local release
./scripts/release/fetch-godot-templates.sh
make release-linux

# Publish
git tag v0.2.0 && git push origin v0.2.0

# Godot headless export (other OS, after bin/ libs built)
godot --headless --path game --export-release "Windows Desktop" /path/to/SolidExpress.exe
godot --headless --path game --export-release "macOS" /path/to/SolidExpress.app
```

Related: [release.md](./release.md), `.github/workflows/release.yml`, `game/export_presets.cfg`.
