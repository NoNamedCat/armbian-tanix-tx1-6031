# Armbian para Tanix TX1 (Allwinner H313 - Revisión 6031 / ATBM6031)

Este repositorio contiene las instrucciones, herramientas y configuración de soporte para instalar **Armbian Linux (Kernel 6.18+ / Debian Trixie)** en la TV Box **Tanix TX1** (Allwinner H313), específicamente para la revisión que cuenta con el chip Wi-Fi **AltoBeam ATBM6031 / 6031**.

---

## 📋 Características y Estado de Hardware

| Componente | Estado | Notas |
| :--- | :--- | :--- |
| **SoC** | ✅ Funcional | Allwinner H313 (Cortex-A53 quad-core) |
| **RAM** | ✅ Funcional | 2GB LPDDR3 @ 600 MHz |
| **Almacenamiento** | ✅ Funcional | eMMC integrada (arranque directo vía U-Boot) |
| **Pantalla / GPU** | ✅ Funcional | HDMI con soporte FB / DRM (1080p60) |
| **Puertos USB** | ✅ Funcional | EHCI/OHCI y soporte USB OTG |
| **Wi-Fi** | ✅ Funcional | AltoBeam ATBM6031 en bus SDIO con firmware cargado |
| **Control Remoto** | ✅ Funcional | Receptor Infrarrojo (sunxi-ir) |

---

## 🚀 Instalación y Flasheo (vía USB FEL)

Dado que la Tanix TX1 no cuenta con ranura para tarjeta microSD ni puerto Ethernet, el sistema se instala directamente en la memoria interna eMMC mediante el modo FEL de Allwinner a través de un cable USB macho-a-macho.

### Requisitos previos:
- Una PC con Linux.
- Herramienta `sunxi-fel` instalada (`sudo apt install sunxi-tools`).
- Cable USB Tipo A macho a Tipo A macho.
- Un objeto fino (mondadientes o clip) para presionar el botón de reset oculto dentro del conector AV.

### Pasos para flashear:
1. Clona este repositorio o descarga los archivos.
2. Descarga la imagen deseada (Desktop XFCE o Minimal CLI) desde la sección de **Releases**.
3. Descomprime la imagen (`.img.xz`):
   ```bash
   unxz -k Armbian-unofficial_..._xfce_desktop.img.xz
   ```
4. Conecta el cable USB a tu PC.
5. Mantén presionado el botón dentro del jack AV y conecta el otro extremo del cable USB al puerto de la TV Box.
6. Ejecuta el script de flasheo:
   ```bash
   sudo ./flash_fel.sh <ruta_de_la_imagen.img>
   ```
7. El script detectará la caja, cargará U-Boot en memoria RAM, expondrá la memoria eMMC como disco USB y escribirá la imagen de forma automática y segura.
8. Una vez terminado, desconecta el cable USB, conecta el adaptador de corriente de 5V y el sistema arrancará directamente en Armbian.

---

## 🛠️ Cómo compilar desde las fuentes (Armbian Build Framework)

Para compilar tus propias imágenes desde cero utilizando el framework oficial de Armbian:

1. Clona el framework de compilación de Armbian:
   ```bash
   git clone --depth 1 https://github.com/armbian/build.git
   cd build
   ```
2. Copia la configuración del board y los parches provistos en este repositorio dentro de la carpeta `userpatches/`:
   - Copiar `config/boards/tanix-tx1-6031.tvb` a `userpatches/config/boards/tanix-tx1-6031.tvb`.
   - Copiar el defconfig de U-Boot a `userpatches/u-boot/v2026.07-sunxi64/board_tanix-tx1-6031/`.
   - Copiar el device tree `sun50i-h313-tanix-tx1.dts` a `userpatches/kernel/archive/sunxi-6.18/`.
3. Ejecuta la compilación:
   ```bash
   # Para versión de Escritorio (XFCE):
   ./compile.sh build BOARD=tanix-tx1-6031 BRANCH=current BUILD_DESKTOP=yes BUILD_MINIMAL=no KERNEL_CONFIGURE=no

   # Para versión Minimal (Línea de comandos):
   ./compile.sh build BOARD=tanix-tx1-6031 BRANCH=current BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=no
   ```

---

## 📄 Licencia y Créditos
- Desarrollado y mantenido por la comunidad.
- Basado en el proyecto [Armbian](https://www.armbian.com).

---

## 📡 Cómo compilar el controlador Wi-Fi (ATBM6031) desde cero

El chip Wi-Fi de esta placa es un **AltoBeam ATBM6031** (bus SDIO). El código fuente original de AltoBeam fue adaptado y parcheado para funcionar en kernels modernos de Linux (6.x / 6.18+):

### 1. Clonar el repositorio base del controlador:
```bash
git clone https://github.com/gtxaspec/atbm-wifi.git
cd atbm-wifi
```

### 2. Aplicar el parche de compatibilidad Linux 6.18 y soporte 6031:
Este repositorio incluye el parche completo con todos los fixes de la API moderna de Linux (`struct net_device`, temporizadores, macro `MODULE_DEVICE_TABLE`, carga de firmware relativa y compatibilidad con Linux 6.18):
```bash
git apply /ruta/a/patches/atbm6031_driver_linux6.18.patch
```

### 3. Compilar el módulo para arquitectura ARM64:
Asegúrate de contar con el compilador cruzado `aarch64-linux-gnu-gcc` y las cabeceras o código fuente del kernel:
```bash
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=/ruta/al/kernel/linux-sources modules
```
Esto generará el módulo listo: `hal_apollo/atbm6031.ko`.

### 4. Instalación en el sistema de destino:
1. Copiar el módulo compilado:
   ```bash
   sudo cp hal_apollo/atbm6031.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
   ```
2. Copiar los archivos de firmware incluidos en `patches/atbm6031_assets/firmware/`:
   ```bash
   sudo cp patches/atbm6031_assets/firmware/* /lib/firmware/
   ```
3. Configurar opciones y auto-carga:
   ```bash
   echo "options atbm6031 fw=atbm6031_fw.bin wifi_bt_comb=0" | sudo tee /etc/modprobe.d/atbm6031.conf
   echo "atbm6031" | sudo tee /etc/modules-load.d/atbm6031.conf
   sudo depmod -a
   ```
