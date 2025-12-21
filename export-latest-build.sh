#!/usr/bin/env bash
set -euo pipefail

# Run this from: ~/openwrt/rbm33g-gateway/openwrt
TOP="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$TOP"

TARGET_DIR="bin/targets/ramips/mt7621"

SYSUP="openwrt-ramips-mt7621-mikrotik_routerboard-m33g-squashfs-sysupgrade.bin"
INITR="openwrt-ramips-mt7621-mikrotik_routerboard-m33g-initramfs-kernel.bin"
SUMS="sha256sums"

HGFS_MNT="/mnt/hgfs"

# Optional: set SHARE_NAME to pick a specific share if multiple exist.
# Example: SHARE_NAME=Share ./export-latest-build.sh
SHARE_NAME="${SHARE_NAME:-}"

echo "==> Ensuring VMware shared folders are mounted at ${HGFS_MNT} ..."

sudo mkdir -p "$HGFS_MNT"

# If not already mounted, mount the VMware host share namespace
if ! mountpoint -q "$HGFS_MNT"; then
  echo "==> ${HGFS_MNT} not mounted; mounting .host:/ ..."
  # vmhgfs-fuse typically comes from open-vm-tools / open-vm-tools-desktop
  sudo vmhgfs-fuse -o allow_other .host:/ "$HGFS_MNT"
else
  echo "==> ${HGFS_MNT} is already mounted."
fi

echo "==> Shares visible under ${HGFS_MNT}:"
ls -la "$HGFS_MNT"

# Decide which directory to copy into
DEST_ROOT=""
if [[ -n "$SHARE_NAME" ]]; then
  # Use explicitly provided share
  if [[ -d "${HGFS_MNT}/${SHARE_NAME}" ]]; then
    DEST_ROOT="${HGFS_MNT}/${SHARE_NAME}"
  else
    echo "ERROR: SHARE_NAME='${SHARE_NAME}' not found under ${HGFS_MNT}."
    echo "Available:"
    ls -1 "$HGFS_MNT"
    exit 1
  fi
else
  # If there is exactly one directory under /mnt/hgfs, use it.
  # If there are files directly under /mnt/hgfs (your current case), use /mnt/hgfs itself.
  shopt -s nullglob
  dirs=( "$HGFS_MNT"/*/ )
  shopt -u nullglob

  if [[ ${#dirs[@]} -eq 1 ]]; then
    DEST_ROOT="${dirs[0]%/}"
    echo "==> Auto-selected single share directory: ${DEST_ROOT}"
  else
    # If you already see your host files directly under /mnt/hgfs with no subdir,
    # treat /mnt/hgfs as the destination root.
    DEST_ROOT="$HGFS_MNT"
    echo "==> Using ${DEST_ROOT} as destination root (files appear directly under /mnt/hgfs)."
    if [[ ${#dirs[@]} -gt 1 ]]; then
      echo "NOTE: Multiple share directories exist; set SHARE_NAME=... to pick one explicitly."
    fi
  fi
fi

EXPORT_DIR="${DEST_ROOT}/openwrt_exports/rbm33g"
mkdir -p "$EXPORT_DIR"

echo "==> Export directory: ${EXPORT_DIR}"

# Sanity check build artifacts
for f in "$SYSUP" "$INITR" "$SUMS"; do
  if [[ ! -f "${TARGET_DIR}/${f}" ]]; then
    echo "ERROR: Missing ${TARGET_DIR}/${f}"
    exit 1
  fi
done

echo "==> Copying artifacts..."
cp -av "${TARGET_DIR}/${SYSUP}" "${EXPORT_DIR}/"
cp -av "${TARGET_DIR}/${INITR}" "${EXPORT_DIR}/"
cp -av "${TARGET_DIR}/${SUMS}" "${EXPORT_DIR}/"

echo "==> Verifying SHA256 for sysupgrade (against sha256sums file)..."
( cd "${TARGET_DIR}" && grep -F " ${SYSUP}" "${SUMS}" ) | awk '{print $1"  '"${EXPORT_DIR}/${SYSUP}"'"}' | sha256sum -c -

echo "==> Done."
echo "    Sysupgrade: ${EXPORT_DIR}/${SYSUP}"
echo "    Initramfs:  ${EXPORT_DIR}/${INITR}"
echo "    Sums:       ${EXPORT_DIR}/${SUMS}"

# Optional: update defconfig from current .config (explicit opt-in)
if [ "${UPDATE_DEFCONFIG:-0}" = "1" ]; then
    echo "==> Updating configs/rbm33g_gateway.defconfig from .config"
    scripts/kconfig/merge_config.sh -m .config configs/rbm33g_gateway.defconfig
    make defconfig
    echo "==> Done with defconfig update"
fi

