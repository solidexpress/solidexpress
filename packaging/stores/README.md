# Store channels (beyond GitHub Releases)

CI builds **installers**; **store listing** requires your accounts and one-time portal setup.

| Channel | Artifact from CI | Your account / action |
|---------|------------------|------------------------|
| **GitHub Releases** | tar.gz, setup.exe, dmg, flatpak, snap | None |
| **Flathub** | Use `packaging/flatpak/` manifest | GitHub PR to [flathub/flathub](https://github.com/flathub/flathub); Flathub builds after merge |
| **Snap Store** | `solidexpress_*.snap` from snapcraft | [Snapcraft](https://snapcraft.io/) account; `snapcraft upload` + `release` |
| **Microsoft Store** | Start from MSIX (see `packaging/windows/store-msix.md`) | [Partner Center](https://partner.microsoft.com/); MSIX + signing |
| **Mac App Store** | Sandboxed export preset (see `packaging/macos/app-store.md`) | App Store Connect + sandbox entitlements |

Privacy policy URL (required): https://solidexpress.github.io (add a `/privacy.html` page if missing).
Support URL: GitHub Issues.
