#!/usr/bin/env bash
set -euo pipefail

# Import the approved Kess art set into the Flame asset tree.
# Usage:
#   ./tool/import-kess-assets.sh /path/to/folder/containing/the/source/files
#
# The approved uploads were supplied with .png filenames, but byte inspection
# shows they are JPEG-encoded. The importer preserves the approved source bytes
# and writes them to truthful .jpg repository paths.
#
# This script refuses to import a file if its SHA-256 differs from the approved
# manifest.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-}"
DEST="$ROOT/gatefall_flame/assets/sprites/characters/kess"

if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  echo "usage: $0 <source-directory>" >&2
  exit 2
fi

mkdir -p   "$DEST/weapons"   "$DEST/animations/idle"   "$DEST/rig/archive"

copy_checked() {
  local src_name="$1"
  local target_rel="$2"
  local expected="$3"
  local source="$SRC/$src_name"
  local target="$DEST/$target_rel"

  [[ -f "$source" ]] || { echo "missing: $source" >&2; exit 3; }

  local actual
  actual="$(sha256sum "$source" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    echo "checksum mismatch: $src_name" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    exit 4
  }

  install -m 0644 "$source" "$target"
  echo "imported: $target_rel"
}

copy_checked "Kess_Master_Transparent_v1.png"   "kess_master.jpg"   "697555356c582c0c0be248d3cc2471032c2a1540fd99fc84f788cfdc40b42086"

copy_checked "file_00000000ba6482108a5206cf6efb40da.png"   "weapons/kess_twin_ember_blades.jpg"   "52c451b3fbde39345739c3d72c122bf402322f963ef9c24d5e72056fc8fbd6f7"

copy_checked "file_00000000a5948210b0dee833fdb8d7de.png"   "weapons/kess_twin_ember_blades_design_sheet.jpg"   "6a5e3d9dbf06a725bbee620e0d4c108dca3a2c47f1f3ce802207e89843f77203"

copy_checked "kess_idle_sprite_sheet_final.png"   "animations/idle/kess_idle_sprite_sheet_v1.jpg"   "e639bc523cfc1c327af6cbbc36b62030c4cd14e80d8afb7663ddabb257ee57ff"

copy_checked "Kess_Rig_Cutout_Sheet_v5.png"   "rig/kess_rig_cutout_v5.jpg"   "c0412c4c74b272fb7b13bad54dcf958d4286508358e9c7b58e20d65e4bdc706b"

copy_checked "Kess_Rig_Cutout_Sheet_v4.png"   "rig/archive/kess_rig_cutout_v4.jpg"   "c540e97eb651cea1183df09d4c9034b15ec7b49462363cbda85b7cb873551851"

echo "Kess asset import complete."
