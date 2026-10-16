#!/usr/bin/env bash
# ==============================================================================
# Script de flasheo para Tanix TX1 (Allwinner H313, AltoBeam ATBM6031) vía FEL
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Por favor ejecuta este script con privilegios de superusuario: sudo ./flash_fel.sh <archivo.img>"
  exit 1
fi

IMG="$1"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  echo "Uso: sudo ./flash_fel.sh <ruta_de_la_imagen.img>"
  echo "Ejemplo: sudo ./flash_fel.sh dist_tx1_6031/Armbian-unofficial_..._xfce_desktop.img"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBOOT="${SCRIPT_DIR}/u-boot-sunxi-with-spl.bin"

if [ ! -f "$UBOOT" ]; then
  echo "Error: No se encontró u-boot-sunxi-with-spl.bin en ${SCRIPT_DIR}"
  exit 1
fi

# Comando uEnv para UMS (USB Mass Storage)
UMS_SCRIPT=$(mktemp)
cat << 'EOF' > "$UMS_SCRIPT"
#=uEnv
bootcmd=ums 0 mmc 2 || ums 0 mmc 1 || ums 0 mmc 0
EOF

echo "==> Conecta la TV Box con cable USB macho-a-macho y presiona el botón dentro del jack AV."
echo "==> Esperando conexión en modo FEL (id: 1f3a:efe8)..."
while ! lsusb | grep -q "1f3a:efe8"; do
    sleep 0.5
done

echo "==> Caja detectada en modo FEL!"
sunxi-fel -v uboot "$UBOOT" write 0x4fc00000 "$UMS_SCRIPT"
rm -f "$UMS_SCRIPT"

echo "==> U-Boot cargado. Esperando que aparezca la unidad de disco USB (UMS)..."
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
    echo "Error: No se detectó la unidad UMS. Revisa la salida de lsblk:"
    lsblk
    exit 1
fi

echo "==> Memoria eMMC detectada en: $disk_target"

# Desmontar cualquier partición que el sistema operativo intente auto-montar
for part in ${disk_target}*; do
    if mount | grep -q "$part"; then
        echo "==> Desmontando partición activa: $part"
        umount -f "$part" 2>/dev/null || true
    fi
done

echo "==> Flasheando imagen: $IMG en $disk_target..."
dd if="$IMG" of="$disk_target" bs=4M status=progress conv=fsync
sync

echo ""
echo "=========================================================="
echo " ==> ¡Flasheo completado con éxito! <== "
echo " 1. Desconecta el cable USB de la TV Box."
echo " 2. Conecta la fuente de poder (5V)."
echo " 3. El sistema arrancará con Wi-Fi habilitado."
echo "=========================================================="
