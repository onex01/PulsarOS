#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "=== Checking license headers in PulsarOS code ==="

MISSING=0
while IFS= read -r -d '' f; do
    if ! grep -qE "SPDX-License-Identifier|Copyright" "$f"; then
        echo "⚠ Missing header: $f"
        MISSING=$((MISSING+1))
    fi
done < <(find "$REPO_ROOT" \
    -path "$REPO_ROOT/packages/apps/ConsoleLauncher" -prune -o \
    -path "$REPO_ROOT/packages/apps/TVBro" -prune -o \
    -path "$REPO_ROOT/packages/apps/RetroArch" -prune -o \
    -path "$REPO_ROOT/packages/apps/Kodi" -prune -o \
    -path "$REPO_ROOT/packages/apps/EmulationStationDE" -prune -o \
    \( -name '*.kt' -o -name '*.java' -o -name '*.sh' -o -name '*.mk' \
       -o -name '*.xml' -o -name '*.bp' -o -name '*.rc' \) \
    -type f -print0)

if [[ $MISSING -gt 0 ]]; then
    echo "✗ $MISSING files missing license headers"
    exit 1
else
    echo "✓ All PulsarOS files have license headers"
fi