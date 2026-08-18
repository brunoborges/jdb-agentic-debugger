#!/usr/bin/env bash
# prepare-test.sh — Prepare an isolated test directory for interactive debugging.
#
# Sets up a temporary folder with compiled classes, plugin files, and scripts,
# then writes the test prompt to prompt.txt. The user can cd into the directory
# and launch Claude or Copilot interactively.
#
# Usage:
#   ./tests/prepare-test.sh [--no-plugin]
#
# Options:
#   --no-plugin   Only copy compiled classes and prompt.txt (skip plugin files)
#
# Prerequisites:
#   - JDK with javac on PATH
set -euo pipefail

NO_PLUGIN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-plugin) NO_PLUGIN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--no-plugin]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${CYAN}[prep]${NC} $*"; }
pass() { echo -e "${GREEN}[OK]${NC}   $*"; }
fail() { echo -e "${RED}[ERR]${NC}  $*"; }

# ─────────────────────────────────────────────
# Verify prerequisites
# ─────────────────────────────────────────────
check_javac
resolve_sources

# ─────────────────────────────────────────────
# Create work directory
# ─────────────────────────────────────────────
WORKDIR=$(make_temp_dir)

log "Creating test directory: $WORKDIR"

log "Compiling sample app with debug symbols..."
compile_samples "$WORKDIR"

if [[ "$NO_PLUGIN" == false ]]; then
  install_plugin "$WORKDIR"
fi
install_permissions "$WORKDIR"

# ─────────────────────────────────────────────
# Copy prompt.txt
# ─────────────────────────────────────────────
cp "$SCRIPT_DIR/prompt.txt" "$WORKDIR/prompt.txt"

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
pass "Test directory ready: $WORKDIR"
echo ""
echo -e "${BOLD}To start an interactive session:${NC}"
echo ""
echo "  cd $WORKDIR"
echo ""
echo -e "  ${BOLD}Claude:${NC}  claude --plugin-dir ."
echo -e "  ${BOLD}Copilot:${NC} copilot"
echo ""
echo -e "Then paste or reference the prompt from ${BOLD}prompt.txt${NC}."
echo ""
echo -e "${CYAN}Tip:${NC} To clean up afterwards, run: rm -rf $WORKDIR"
