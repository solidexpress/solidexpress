Add a suite by adding one file here: `<name>.suite`, where `<name>` is the script basename without `run_` and `.gd` (for example `rung01_replan15_jawstub.suite`).
Keys are `script=tests/<file>.gd` (relative to `game/`) and `tier=ci|full` (`ci` runs in the godot-smoke gate and in `make test-godot`; `full` only in `make test-godot`). Optional `timeout=<seconds>` (default 900).
Never edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe to register a suite.
