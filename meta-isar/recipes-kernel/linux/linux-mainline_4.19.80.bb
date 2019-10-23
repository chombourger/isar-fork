# Example recipe for building the mainline kernel
#
# This software is a part of ISAR.
# Copyright (c) Siemens AG, 2018
#
# SPDX-License-Identifier: MIT

require recipes-kernel/linux/linux-custom.inc

ARCHIVE_VERSION = "${@ d.getVar('PV')[:-2] if d.getVar('PV').endswith('.0') else d.getVar('PV') }"

SRC_URI += " \
    https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${ARCHIVE_VERSION}.tar.xz \
    file://x86_64_defconfig"
SRC_URI[sha256sum] = "80a9ba764e088aa7fddfef5a97c0236905e291468a37832243b6f3828d36e7ec"

SRC_URI_append_de0-nano-soc = " \
    file://0001-ARM-dts-socfpga-Rename-socfpga_cyclone5_de0_-sockit-.patch"

S = "${WORKDIR}/linux-${ARCHIVE_VERSION}"

KERNEL_DEFCONFIG_qemuamd64 = "x86_64_defconfig"
