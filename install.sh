#!/bin/sh
# ============================================================
# DeskJet 2300 series on macOS — install printing + scanning
# support from the kit shipped in THIS repository (./driver).
#
# Run WITHOUT sudo (password prompts appear when needed):
#   sh install.sh
#
# Options:
#   sh install.sh              # print + scan
#   sh install.sh --scan-only  # scan support only (enough for DeskJet Scan.app)
#   sh install.sh --print-only # CUPS queue only
# ============================================================
set -e

if [ "$(id -u)" -eq 0 ]; then
  echo "Run WITHOUT sudo: sh install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-all}"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }

case "$MODE" in
  --scan-only|scan-only)
    step "Installing scanner support (sudo)"
    sudo sh "$DIR/driver/scanner/scan-setup.sh"
    ;;
  --print-only|print-only)
    step "Installing print driver and queue (sudo)"
    sudo sh "$DIR/driver/scripts/setup.sh"
    ;;
  ""|all|--all)
    step "Installing print driver and queue (sudo)"
    sudo sh "$DIR/driver/scripts/setup.sh"
    step "Installing scanner support (sudo)"
    sudo sh "$DIR/driver/scanner/scan-setup.sh"
    ;;
  *)
    echo "Unknown option: $MODE" >&2
    echo "Usage: sh install.sh [--scan-only|--print-only]" >&2
    exit 2
    ;;
esac

step "Done"
note "Scan check:  hp-scan -L"
note "Then open:   DeskJet Scan.app  (build with: sh app/build.sh)"
if [ "$MODE" = "all" ] || [ "$MODE" = "--all" ] || [ -z "$1" ]; then
  note "Print test:  echo test | lp -d HP_DeskJet_2320"
fi
