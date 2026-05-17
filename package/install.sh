#!/usr/bin/env bash
# Thin wrapper for kpackagetool6. Use Makefile for everything else.
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:---install}"
exec kpackagetool6 --type Plasma/Applet "$ACTION" "$SELF_DIR"
