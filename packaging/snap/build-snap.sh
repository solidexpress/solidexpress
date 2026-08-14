#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VER="$(tr -d '[:space:]' < "$ROOT/VERSION")"
YAML="$ROOT/packaging/snap/snapcraft.yaml"
python3 - "$YAML" "$VER" <<'PY'
import re
import sys
from pathlib import Path
p = Path(sys.argv[1])
ver = sys.argv[2]
text = p.read_text()
text = re.sub(r"^version:.*$", f"version: '{ver}'", text, flags=re.M)
text = re.sub(r"SolidExpress-[0-9.]+-linux-x86_64", f"SolidExpress-{ver}-linux-x86_64", text)
p.write_text(text)
print("snapcraft.yaml pinned to", ver)
PY
cd "$ROOT/packaging/snap"
snapcraft pack --destructive-mode --output "$ROOT/dist/releases/"
