#!/bin/bash
# =====================================================================
#  Seroga OS ISO būvēšana
#  Darbojas Debian 13 vidē (GitHub Actions to palaiž Docker konteinerā).
#
#  Lokāli (no Linux datora ar Docker):
#      docker run --rm --privileged -v "$PWD":/build -w /build debian:trixie ./build.sh
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Instalēju būvēšanas rīkus"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin \
  mtools dosfstools syslinux syslinux-common isolinux \
  curl jq unzip ca-certificates

chmod +x auto/* config/hooks/normal/*.hook.chroot config/includes.chroot/opt/seroga/bin/*

echo "==> Iebūvēju Seroga lietotnes no GitHub Releases"
config/includes.chroot/opt/seroga/bin/seroga-atjaunot-lietotnes \
  --build config/includes.chroot config/packages.chroot

echo "==> Būvēju ISO"
lb clean --purge || true
lb config
lb build

ISO="$(ls -1 seroga-os*.iso | head -n1)"
VERSION="$(date +%Y.%m.%d)"
mkdir -p out
mv "$ISO" "out/seroga-os-$VERSION-amd64.iso"
(cd out && sha256sum *.iso > SHA256SUMS)
echo "==> Gatavs: out/seroga-os-$VERSION-amd64.iso"
ls -lh out/
