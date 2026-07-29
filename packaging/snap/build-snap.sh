#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/packaging/snap"
snapcraft pack --destructive-mode --output "$ROOT/dist/releases/"
