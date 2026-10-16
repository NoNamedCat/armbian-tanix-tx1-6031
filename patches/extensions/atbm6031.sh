# @description Installs the AltoBeam ATBM6031 WiFi module and firmware into the image
# SPDX-License-Identifier: GPL-2.0

function post_family_tweaks_bsp__install_atbm6031() {
	display_alert "Installing AltoBeam ATBM6031 WiFi driver and firmware" "atbm6031" "info"

	local kver
	kver=$(ls "${destination}/lib/modules" 2>/dev/null | head -n 1)
	if [[ -z "${kver}" ]]; then
		display_alert "Kernel modules directory not found in rootfs" "atbm6031" "warn"
		return 0
	fi

	local mod_dest="${destination}/lib/modules/${kver}/kernel/drivers/net/wireless/atbm"
	mkdir -p "${mod_dest}"
	cp -f "${SRC}/userpatches/atbm6031_assets/atbm6031.ko" "${mod_dest}/"
	chmod 644 "${mod_dest}/atbm6031.ko"

	# Install firmware
	mkdir -p "${destination}/lib/firmware"
	cp -f ${SRC}/userpatches/atbm6031_assets/firmware/* "${destination}/lib/firmware/"
	chmod 644 "${destination}/lib/firmware/"*atbm* 2>/dev/null || true

	# Automatic module load
	mkdir -p "${destination}/etc/modules-load.d"
	echo "atbm6031" > "${destination}/etc/modules-load.d/atbm6031.conf"

	# Run depmod inside rootfs
	chroot "${SDCARD}" /sbin/depmod -a "${kver}" 2>/dev/null || true
}
