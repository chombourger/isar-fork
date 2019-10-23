#!/bin/bash
#
# Custom kernel build
#
# This software is a part of ISAR.
# Copyright (c) Siemens AG, 2018
#
# SPDX-License-Identifier: MIT

source /isar/common.sh

host_arch=$(dpkg --print-architecture)

if [ "$host_arch" != "$target_arch" ]; then
    case $target_arch in
    armhf)
        export ARCH=arm
        export CROSS_COMPILE="arm-linux-gnueabihf-"
        ;;
    arm64)
        export ARCH=arm64
        export CROSS_COMPILE="aarch64-linux-gnu-"
        ;;
    mipsel)
        export ARCH=mips
        export CROSS_COMPILE="mipsel-linux-gnu-"
        ;;
    *)
        echo "error: unsupported architecture ($target_arch)"
        exit 1
        ;;
    esac
fi

REPACK_DIR="$1/../repack"
REPACK_LINUX_IMAGE_DIR="${REPACK_DIR}/linux-image"
REPACK_LINUX_HEADERS_DIR="${REPACK_DIR}/linux-headers"

make ${KERNEL_CONFIG_TARGET} || exit ${?}
if [ -n "${KERNEL_FRAGMENTS}" ]; then
    scripts/kconfig/merge_config.sh -m .config ${KERNEL_FRAGMENTS}
fi

KV=$( make -s kernelrelease )
if [ "${KV}" != "${PV}" ]; then
	echo "ERROR: Recipe PV is \"${PV}\" but should be \"${KV}\"" 1>&2
	echo "ERROR: Probably due to CONFIG_LOCALVERSION" 1>&2
	exit 1
fi

rm -f .version
KBUILD_DEBARCH=$target_arch make -j $(($(nproc) * 2)) deb-pkg

rm -rf "${REPACK_DIR}"
mkdir -p "${REPACK_DIR}"
mkdir -p "${REPACK_LINUX_IMAGE_DIR}"
mkdir -p "${REPACK_LINUX_HEADERS_DIR}"

cp -a debian "${REPACK_DIR}"

# dpkg-gencontrol performs cross-incompatible checks on the
# Architecture field; trick it to accept the control file
sed -i "s/Architecture: .*/Architecture: any/" "${REPACK_DIR}/debian/control"

cd ..

dpkg-deb -R linux-image-${PV}_${PV}-1_*.deb "${REPACK_LINUX_IMAGE_DIR}"
dpkg-deb -R linux-headers-${PV}_${PV}-1_*.deb "${REPACK_LINUX_HEADERS_DIR}"

dpkg-gencontrol -crepack/debian/control \
	-lrepack/debian/changelog \
	-frepack/debian/files \
	-plinux-image-${PV} \
	-P"${REPACK_LINUX_IMAGE_DIR}" \
	-DPackage="linux-image-${KERNEL_NAME}" \
	-DSection=kernel \
	-DPriority=required \
	-DDepends="${KERNEL_DEBIAN_DEPENDS}" \
	-DArchitecture=$target_arch

# Add Debian-like link installation to postinst
mkdir -p ${REPACK_LINUX_IMAGE_DIR}/lib/modules/${PV}
touch "${REPACK_LINUX_IMAGE_DIR}/lib/modules/${PV}/.fresh-install"
sed -i "${REPACK_LINUX_IMAGE_DIR}/DEBIAN/postinst" \
    -e "/^set -e$/a\\
\\
if [ -f /lib/modules/${PV}/.fresh-install ]; then\\
	change=install\\
else\\
	change=upgrade\\
fi\\
linux-update-symlinks \$change ${PV} /boot/${KERNEL_FILE}-${PV}\\
rm -f /lib/modules/${PV}/.fresh-install"

# Add Debian-like link removal to postrm
sed -i "${REPACK_LINUX_IMAGE_DIR}/DEBIAN/postrm" \
    -e "/^set -e$/a\\
\\
rm -f /lib/modules/${PV}/.fresh-install\\
\\
if [ \"\$1\" != upgrade ] && command -v linux-update-symlinks >/dev/null; then\\
	linux-update-symlinks remove ${PV}  /boot/${KERNEL_FILE}-${PV}\\
fi"

# Make sure arm64 kernels are decompressed
if [ "$target_arch" = "arm64" ]; then
	kernel_file="${REPACK_LINUX_IMAGE_DIR}/boot/${KERNEL_FILE}-${PV}"
	mv "${kernel_file}" "${kernel_file}.gz"
	gunzip "${kernel_file}.gz"
fi

dpkg-gencontrol -crepack/debian/control \
	-lrepack/debian/changelog \
	-frepack/debian/files \
	-plinux-headers-${PV} \
	-P"${REPACK_LINUX_HEADERS_DIR}" \
	-Vkernel:debarch="${KERNEL_NAME}" \
	-DPackage="linux-headers-${KERNEL_NAME}" \
	-DSection=kernel \
	-DDepends="${KERNEL_HEADERS_DEBIAN_DEPENDS}" \
	-DArchitecture=$target_arch

fakeroot dpkg-deb -b "${REPACK_LINUX_IMAGE_DIR}" \
	linux-image-${KERNEL_NAME}_${PV}-1_${KERNEL_NAME}.deb
rm -f linux-image-${PV}_${PV}-1_*.deb
fakeroot dpkg-deb -b "${REPACK_LINUX_HEADERS_DIR}" \
	linux-headers-${KERNEL_NAME}_${PV}-1_${KERNEL_NAME}.deb
rm -f linux-headers-${PV}_${PV}-1_*.deb
