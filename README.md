# Armbian for Tanix TX1 (Allwinner H313 - Revision 6031 / ATBM6031)

This repository provides instructions, pre-built bootable images, tools, device trees, and patches to run **Armbian Linux (Kernel 6.18+ / Debian Trixie)** on the **Tanix TX1** TV Box (Allwinner H313), specifically targeted for the hardware revision featuring the **AltoBeam ATBM6031 / 6031** SDIO Wi-Fi chip.

---

## 📋 Hardware Support Status

| Component | Status | Details |
| :--- | :--- | :--- |
| **SoC** | ✅ Working | Allwinner H313 (Quad-Core ARM Cortex-A53) |
| **RAM** | ✅ Working | 2GB LPDDR3 @ 600 MHz |
| **Storage** | ✅ Working | Onboard eMMC storage (direct boot via U-Boot) |
| **Display / Video** | ✅ Working | HDMI 1080p60 output with DRM/KMS engine |
| **USB** | ✅ Working | EHCI/OHCI host controller and USB OTG support |
| **Wi-Fi** | ✅ Working | AltoBeam ATBM6031 on SDIO bus with custom patched driver & firmware |
| **Remote Control** | ✅ Working | Infrared sensor (sunxi-ir) |

---

## 🚀 Quick Start: Flashing Pre-built Images (via USB FEL Mode)

Since the Tanix TX1 has no physical microSD slot and no Ethernet port, the OS must be flashed directly to the onboard eMMC through Allwinner's BROM FEL mode using a standard USB Type-A to Type-A (male-to-male) cable.

### Requirements:
- A Linux host computer.
- `sunxi-tools` installed (`sudo apt install sunxi-tools`).
- USB Type-A to Type-A male-to-male cable.
- A pin or toothpick to depress the hidden reset button inside the AV audio jack.

### Flashing Steps:
1. Clone this repository:
   ```bash
   git clone https://github.com/NoNamedCat/armbian-tanix-tx1-6031.git
   cd armbian-tanix-tx1-6031
   ```
2. Download your preferred image (Desktop XFCE or Minimal CLI) from the [Releases](https://github.com/NoNamedCat/armbian-tanix-tx1-6031/releases/tag/v1.0.0) section.
3. Decompress the downloaded image (`.img.xz`):
   ```bash
   unxz -k Armbian-unofficial_..._xfce_desktop.img.xz
   ```
4. Connect the USB cable to your PC.
5. Press and hold the reset button inside the TV Box AV port, then plug the other end of the USB cable into the TV Box USB port.
6. Run the automated, password-free flashing script:
   ```bash
   sudo ./flash_fel.sh <path_to_decompressed_image.img>
   ```
7. The script will automatically detect the device in FEL mode, bootstrap U-Boot over USB, expose the internal eMMC as a USB mass storage drive (UMS), and flash the image safely.
8. Once finished, disconnect the USB cable and plug in the 5V DC power supply. The box will boot straight into Armbian with functional Wi-Fi!

---

## 🛠️ Building from Source (Armbian Build Framework)

If you wish to build the entire operating system from scratch using the official Armbian build system:

1. Clone the Armbian build repository:
   ```bash
   git clone --depth 1 https://github.com/armbian/build.git
   cd build
   ```
2. Copy the board configuration, U-Boot defconfig, device tree, and extensions from this repository into `userpatches/`:
   ```bash
   # Board configuration
   mkdir -p userpatches/config/boards/
   cp /path/to/patches/boards/tanix-tx1-6031.tvb userpatches/config/boards/

   # U-Boot defconfig
   mkdir -p userpatches/u-boot/v2026.07-sunxi64/board_tanix-tx1-6031/
   cp /path/to/patches/u-boot/0001-add-tanix-tx1-6031-defconfig.patch userpatches/u-boot/v2026.07-sunxi64/board_tanix-tx1-6031/

   # Kernel Device Tree (sun50i-h313-tanix-tx1.dts with PG18 reset & PG10 32k clock)
   mkdir -p userpatches/kernel/archive/sunxi-6.18/
   cp /path/to/patches/kernel/sun50i-h313-tanix-tx1.dts userpatches/kernel/archive/sunxi-6.18/

   # Wi-Fi driver auto-injection extension
   mkdir -p userpatches/extensions/
   cp /path/to/patches/extensions/atbm6031.sh userpatches/extensions/
   ```
3. Run the Armbian compilation:
   ```bash
   # Desktop XFCE image:
   ./compile.sh build BOARD=tanix-tx1-6031 BRANCH=current BUILD_DESKTOP=yes BUILD_MINIMAL=no KERNEL_CONFIGURE=no

   # Minimal CLI image:
   ./compile.sh build BOARD=tanix-tx1-6031 BRANCH=current BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=no
   ```

---

## 📡 Building the ATBM6031 Wi-Fi Driver from Scratch

The wireless hardware is an **AltoBeam ATBM6031** on an SDIO bus. The vendor driver has been patched for compatibility with modern 6.x Linux kernels (6.18+):

### 1. Clone the driver base repository:
```bash
git clone https://github.com/gtxaspec/atbm-wifi.git
cd atbm-wifi
```

### 2. Apply the Linux 6.18+ compatibility & SDIO wildcard patch:
We provide a comprehensive patch (`patches/atbm6031_driver_linux6.18.patch`) that includes:
- Net device & timer API updates for Linux 6.x.
- `MODULE_DEVICE_TABLE(sdio, ...)` with wildcard and `0x6031` device IDs.
- Enabled `fw` module parameter for explicit firmware selection.
- Relative firmware path loading via the kernel's `request_firmware()` subsystem.

```bash
git apply /path/to/patches/atbm6031_driver_linux6.18.patch
```

### 3. Cross-compile for ARM64:
Ensure `aarch64-linux-gnu-gcc` and kernel headers/source tree are installed:
```bash
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=/path/to/kernel/linux-sources modules
```
The compiled module will be generated at `hal_apollo/atbm6031.ko`.

### 4. Installation on the target system:
1. Copy the kernel module:
   ```bash
   sudo cp hal_apollo/atbm6031.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
   ```
2. Copy the official firmware binaries provided in `patches/atbm6031_assets/firmware/`:
   ```bash
   sudo cp patches/atbm6031_assets/firmware/* /lib/firmware/
   ```
3. Configure module parameters and auto-loading:
   ```bash
   echo "options atbm6031 fw=atbm6031_fw.bin wifi_bt_comb=0" | sudo tee /etc/modprobe.d/atbm6031.conf
   echo "atbm6031" | sudo tee /etc/modules-load.d/atbm6031.conf
   sudo depmod -a
   ```

---

## 📄 License & Credits
- Built upon the [Armbian Linux](https://www.armbian.com) build framework.
- Maintained by the open-source community.
