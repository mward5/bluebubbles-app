#!/bin/bash
# Package the Flutter release bundle (from linux/build.sh) as a .deb or .rpm with nfpm.
#   bash linux/packaging/package.sh <deb|rpm> <version> [outdir]
set -euo pipefail

packager="$1"
version="$2"
outdir="${3:-dist}"

cd "$(dirname "$0")/../.."

# The package keeps source file modes, so make everything world-readable whatever the umask.
chmod -R u+rwX,go+rX,go-w build/linux/x64/release/bundle linux/packaging flatpak/icon \
    flatpak/app.bluebubbles.BlueBubbles.metainfo.xml assets/icon/bb-icon.svg

mkdir -p "$outdir"
VERSION="$version" nfpm pkg -f linux/packaging/nfpm.yaml -p "$packager" -t "$outdir/"
