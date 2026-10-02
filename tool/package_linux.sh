#!/usr/bin/env bash
# Packages the Linux build as a .deb via fastforge (https://fastforge.dev),
# using linux/packaging/deb/make_config.yaml for package metadata.
#
# Usage: tool/package_linux.sh
#
# One-time setup:
#   dart pub global activate fastforge
#   (Windows only: add %APPDATA%\Pub\Cache\bin to PATH)
#
# Produces dist/cat_eyekeeper-<version>-linux.deb (fastforge decides the
# exact file name; check the command's own output for the final path).
#
# NOTE: this script has not been run on a real Linux machine (this repo was
# developed on Windows) — it is written to fastforge's documented deb-maker
# config format but has only been reviewed for correctness, not
# build-tested. Run it yourself on a Linux box and fix anything that comes
# up before relying on it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! command -v fastforge >/dev/null 2>&1; then
  echo "fastforge is not installed or not on PATH. Install it with:" >&2
  echo "  dart pub global activate fastforge" >&2
  exit 1
fi

version=$(grep '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//; s/+.*//')
echo "Packaging Screen Time v$version for Linux..."

fastforge package --platform linux --targets deb
