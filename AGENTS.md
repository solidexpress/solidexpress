# AGENTS.md

## Where product intent lives (limited context)

Do not keep “we should do this later” only in chat, a PR comment, or a
transient plan. Write it into the file that owns that decision, then stop
repeating it. Index: [`docs/plan/README.md`](docs/plan/README.md).

| Question | File |
|----------|------|
| What / order / whose tool | `docs/plan/roadmap.md`, `docs/survey/tool-approaches.md` |
| How it must land (chrome, film) | `docs/plan/landing-protocol.md` |
| What has shipped | `docs/plan/STATUS.md` |
| Architecture / licenses | `docs/plan/implementation-plan.md` |

Execute Wave 0 first. Waves 1–4 are fully specified in those files so a
fresh agent can resume without prior conversation.

## Cursor Cloud specific instructions

SolidExpress is a single offline desktop parametric CAD app: a C++20 kernel
(`sxkernel`) built on OCCT + PlaneGCS, exposed to a Godot 4.7 UI (`game/`) via a
GDExtension (`sxcore` → `game/bin/libsxcore.so`). Standard build/run/test
commands live in the root `Makefile` and `README.md`; prefer those and the
notes below rather than re-deriving commands.

### Environment already provided by the VM snapshot
These are typically baked into the image (do not add them to the update script
when they are already present):
- **OCCT:** All platforms pin **8.0.1** (`packaging/occt.version`). Linux/macOS
  CI and releases build it from source via `packaging/ci/install_occt.sh`
  (default prefix `/opt/occt-8.0.1`); Windows uses vcpkg with `vcpkg.json`
  override `opencascade` → `8.0.1`. Toolkit names are `TKDESTEP`/`TKDEIGES`/
  `TKDESTL`. Ubuntu apt 7.6.3 is no longer the CI path; set
  `CMAKE_PREFIX_PATH` to the pinned install. `sxkernel/CMakeLists.txt` still
  falls back to 7.6 `TKSTEP`/`TKIGES`/`TKSTL` names if somehow present.
- System toolchain deps: `ninja-build`, `libstdc++-14-dev` (Clang 18 is the
  default `c++` and targets the gcc-14 toolchain), `libtbb-dev` (OCCT runtime),
  `libeigen3-dev`, `libboost-dev`, `zip`, and `mesa-vulkan-drivers` (lavapipe,
  for GUI rendering without a GPU).
- **Godot 4.7-stable** at `tools/godot/godot` (gitignored). The GDExtension API
  is pinned to this exact build, so keep 4.7-stable (not 4.7.1). If the binary
  is missing, fetch it:

```bash
mkdir -p tools/godot /tmp/godotdl
gh release download 4.7-stable --repo godotengine/godot-builds \
  -p 'Godot_v4.7-stable_linux.x86_64.zip' -O /tmp/godot.zip
unzip -o -q /tmp/godot.zip -d /tmp/godotdl
cp /tmp/godotdl/Godot_v4.7-stable_linux.x86_64 tools/godot/godot
chmod +x tools/godot/godot
```

**Standing rule:** never pass `user://` or `res://` paths into GDExtension C++
(`SxDocument` / kernel I/O). Always `ProjectSettings.globalize_path(...)` first.

### Building and testing (no display needed)
- `make build` then `make test` (kernel Catch2 + all headless Godot suites).
- `make test-godot` runs every manifest in `packaging/ci/suites.d/` (`tier=ci`
  and `tier=full`) and stops at the first failing suite. Add a suite by adding
  one `packaging/ci/suites.d/<name>.suite` file (`<name>` is the script basename
  without `run_` and `.gd`; `script=` is relative to `game/`; `tier=ci` also
  runs in the godot-smoke gate). Do not edit `packaging/ci/run_godot_suites.sh`
  or the Makefile `test-godot` recipe. `KEEP_GOING=1 make test-godot` runs every
  suite and prints every failure. The full tier is expected green.
  Known-red suites, if any, are listed by `make test-godot-known-red` with
  their reasons. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd`
  stay unregistered.
- First run of `make import`/`make run`/`make test-godot` bakes the `game/.godot`
  cache headlessly; this is normal.

### Running the GUI
- A display is available at `DISPLAY=:1`. `make run` launches on it, or run
  `DISPLAY=:1 tools/godot/godot --path game` directly.
- Rendering uses the Forward+ (Vulkan) renderer on **lavapipe (llvmpipe)**
  software Vulkan — there is no GPU, so the viewport renders on CPU and is slow
  but correct.
- Audio has no sound card; Godot logs ALSA errors and falls back to the dummy
  audio driver. This is harmless.

### Known pre-existing test failures (NOT environment issues)
Observed on a clean build; these are repo code/test mismatches, independent of
setup, so don't treat them as broken dependencies:
- The full tier is expected green. Known-red suites, if any, are listed by
  `make test-godot-known-red` with their reasons.
- `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.
