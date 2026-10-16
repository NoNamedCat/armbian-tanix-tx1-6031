#!/usr/bin/env bash
# ==============================================================================
# Flashing script for Tanix TX1 (Allwinner H313, AltoBeam ATBM6031) via FEL mode
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with root privileges: sudo ./flash_fel.sh <image.img>"
  exit 1
fi

IMG="$1"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  echo "Usage: sudo ./flash_fel.sh <path_to_image.img>"
  echo "Example: sudo ./flash_fel.sh Armbian-unofficial_..._xfce_desktop.img"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBOOT="${SCRIPT_DIR}/u-boot-sunxi-with-spl.bin"

if [ ! -f "$UBOOT" ]; then
  echo "Error: u-boot-sunxi-with-spl.bin not found in ${SCRIPT_DIR}"
  exit 1
fi

# Generate temporary uEnv script for USB Mass Storage (UMS)
UMS_SCRIPT=$(mktemp)
cat << 'EOF' > "$UMS_SCRIPT"
#=uEnv
bootcmd=ums 0 mmc 2 || ums 0 mmc 1 || ums 0 mmc 0
EOF

echo "==> Connect the TV Box using a male-to-male USB cable while pressing the reset button inside the AV jack."
echo "==> Waiting for device in FEL mode (id: 1f3a:efe8)..."
while ! lsusb | grep -q "1f3a:efe8"; do
    sleep 0.5
done

echo "==> Device detected in FEL mode!"
sunxi-fel -v uboot "$UBOOT" write 0x4fc00000 "$UMS_SCRIPT"
rm -f "$UMS_SCRIPT"

echo "==> U-Boot loaded. Waiting for USB Mass Storage (UMS) disk to appear..."
disk_before=$(lsblk -d -n -o NAME)
disk_target=""
for i in $(seq 1 20); do
    sleep 1
    for d in /sys/block/sd*; do
        [ -e "$d" ] || continue
        name=$(basename "$d")
        if ! echo "$disk_before" | grep -q "^$name$"; then
            disk_target="/dev/$name"
            break 2
        fi
    done
done

if [ -z "$disk_target" ]; then
    echo "Error: UMS disk not detected. Please verify lsblk output:"
    lsblk
    exit 1
fi

echo "==> eMMC storage detected at: $disk_target"

# Unmount any partition that the host system might have automounted
for part in ${disk_target}*; do
    if mount | grep -q "$part"; then
        echo "==> Unmounting active partition: $part"
        umount -f "$part" 2>/dev/null || true
    fi
done

echo "==> Flashing image: $IMG to $disk_target..."
dd if="$IMG" of="$disk_target" bs=4M status=progress conv=fsync
sync

echo ""
echo "=========================================================="
echo " ==> Flashing completed successfully! <== "
echo " 1. Disconnect the USB cable from the TV Box."
echo " 2. Connect the 5V DC power supply."
echo " 3. The system will boot with Wi-Fi fully enabled."
echo "=========================================================="
