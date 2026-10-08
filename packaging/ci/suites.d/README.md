Add a suite by adding one file here: `<name>.suite`, where `<name>` is the script basename without `run_` and `.gd` (for example `rung01_replan15_jawstub.suite`).
Keys are `script=tests/<file>.gd` (relative to `game/`) and `tier=ci|full|known-red` (`ci` runs in the godot-smoke gate and in `make test-godot`; `full` only in `make test-godot`; `known-red` is listed by `make test-godot-known-red` and is not run by `--tier ci` or `--tier full`). Optional `timeout=<seconds>` (default 900).
`reason=` is required when `tier=known-red` and forbidden otherwise. It is non-empty and starts with `env:`, `stale-feature:`, or `product:` (one sentence after the class).
`--tier known-red` prints `<script> — <reason>` and exits 0. `--tier known-red --run` runs them and exits 1 only when a suite is now green.
Never edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe to register a suite.
