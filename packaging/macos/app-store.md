# Mac App Store

Requires App Sandbox, security-scoped file access for `.sxp`/STEP, separate Godot export preset.

1. Enable sandbox in export preset; test open/save dialogs.
2. Archive in Xcode or `productbuild` pipeline; upload via Transporter / `altool`.
3. App Store Connect metadata + review (CAD apps often need demo account notes).

Direct-download DMG (CI) uses Developer ID + notarization — different from App Store build.
