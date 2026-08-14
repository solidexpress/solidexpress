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
These are baked into the image (do not add them to the update script):
- **OCCT 7.9.0 built from source, installed to `/usr/local`.** The repo requires
  OCCT 7.9+ (it links the 7.7+ toolkit names `TKDESTEP`/`TKDEIGES`/`TKDESTL`),
  but Ubuntu 24.04 apt only ships OCCT 7.6.3. Both are present; `find_package`
  resolves `/usr/local` (7.9) first, which is what you want. Do not "fix" the
  build by pointing it at the apt 7.6 packages.
- System toolchain deps: `ninja-build`, `libstdc++-14-dev` (Clang 18 is the
  default `c++` and targets the gcc-14 toolchain), `libtbb-dev` (OCCT runtime),
  `libeigen3-dev`, `libboost-dev`, `zip`, and `mesa-vulkan-drivers` (lavapipe,
  for GUI rendering without a GPU).
- **Godot 4.7-stable** at `tools/godot/godot` (gitignored). The GDExtension API
  is pinned to this exact build, so keep 4.7-stable (not 4.7.1).

### Building and testing (no display needed)
- `make build` then `make test` (kernel Catch2 + all headless Godot suites).
- `make test-godot` runs each `game/tests/run_*.gd` script and **stops at the
  first failing script**; to see the full picture run the scripts individually
  (`tools/godot/godot --headless --path game --script tests/<name>.gd`).
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
- `nav_preset` defaults to `FUSION` (`game/scripts/orbit_camera.gd`) while
  several tests assume `SOLIDEXPRESS`, so the Alt-orbit checks fail in
  `run_camera_tests`, `run_place_tests`, and `run_howto_tests`.
- `run_infer_tests` (DOF chip update) and `run_icon_tests` (a 1–2 char button
  without an icon) each have one unrelated pre-existing failure.
