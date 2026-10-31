#!/bin/bash
# =====================================================================
#  Seroga OS ISO būvēšana — Ubuntu 26.04 LTS bāze
#
#  Darbojas Ubuntu 26.04 vidē ar root tiesībām. GitHub Actions to palaiž
#  Docker konteinerā. Lokāli (Linux dators ar Docker):
#      docker run --rm --privileged -v "$PWD":/build -w /build ubuntu:26.04 bash ./build.sh
#
#  Rezultāts: out/seroga-os-<datums>-amd64.iso
# =====================================================================
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
ROOT_DIR="$PWD"
# shellcheck source=config/seroga.conf
. config/seroga.conf

WORK="$ROOT_DIR/work"
CHROOT="$WORK/chroot"
IMAGE="$WORK/image"
BOOT="$WORK/boot"
STAGE="$WORK/includes"
DEBS="$WORK/debs"
OUT="$ROOT_DIR/out"
DATE="$(date +%Y.%m.%d)"
ISO="$OUT/seroga-os-$DATE-amd64.iso"

export DEBIAN_FRONTEND=noninteractive

step() { echo; echo "════════════════════════════════════════════"; echo "==> $*"; echo "════════════════════════════════════════════"; }
warn() { echo "BRĪDINĀJUMS: $*"; }

in_chroot() {
  chroot "$CHROOT" /usr/bin/env -i \
    HOME=/root LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$@"
}

APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

mount_chroot() {
  mount --bind /dev     "$CHROOT/dev"
  mount --bind /dev/pts "$CHROOT/dev/pts"
  mount -t proc  proc   "$CHROOT/proc"
  mount -t sysfs sysfs  "$CHROOT/sys"
}
umount_chroot() {
  for m in dev/pts dev proc sys; do
    umount -lf "$CHROOT/$m" 2>/dev/null || true
  done
}
trap umount_chroot EXIT

# Nolasa pakotņu sarakstu (bez komentāriem un tukšām rindām)
read_list() { sed 's/#.*//' "$@" | awk 'NF'; }

# ---------------------------------------------------------------------
step "1/9  Būvēšanas rīki"
apt-get update
apt-get install -y --no-install-recommends \
  debootstrap squashfs-tools xorriso mtools dosfstools \
  grub-common grub-pc-bin grub-efi-amd64-bin \
  curl jq unzip tar rsync ca-certificates

# Parakstītie Secure Boot ielādētāji — tikai izvelk failus, neinstalē
rm -rf "$WORK" && mkdir -p "$WORK" "$BOOT" "$DEBS" "$OUT"
( cd "$WORK" && apt-get download shim-signed grub-efi-amd64-signed )
mkdir -p "$WORK/efi-src"
for d in "$WORK"/*.deb; do dpkg-deb -x "$d" "$WORK/efi-src"; done
rm -f "$WORK"/*.deb

find_efi() { find "$WORK/efi-src" -name "$1" | sort | tail -n1; }
SHIM="$(find_efi 'shimx64.efi.signed.latest')"
[ -z "$SHIM" ] && SHIM="$(find_efi 'shimx64.efi.signed*')"
MM="$(find_efi 'mmx64.efi*')"
GRUBEFI="$(find_efi 'gcdx64.efi.signed')"
for f in "$SHIM" "$GRUBEFI"; do [ -f "$f" ] || { echo "Nav atrasts Secure Boot fails"; exit 1; }; done
echo "shim: $SHIM"; echo "grub: $GRUBEFI"; echo "mm:   ${MM:-nav}"

# ---------------------------------------------------------------------
step "2/9  Ubuntu $UBUNTU_VERSION ($CODENAME) pamatsistēma"
debootstrap --arch=amd64 --variant=minbase \
  --components=main,restricted,universe,multiverse \
  "$CODENAME" "$CHROOT" "$MIRROR"

mount_chroot
rm -f "$CHROOT/etc/resolv.conf"
cp /etc/resolv.conf "$CHROOT/etc/resolv.conf"
cp config/seroga.conf "$CHROOT/tmp/seroga.conf"

# Krātuves
: > "$CHROOT/etc/apt/sources.list"
cat > "$CHROOT/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: $CODENAME $CODENAME-updates $CODENAME-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: $SECURITY_MIRROR
Suites: $CODENAME-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

# Būvēšanas laikā servisi nestartējas
printf '#!/bin/sh\nexit 101\n' > "$CHROOT/usr/sbin/policy-rc.d"
chmod +x "$CHROOT/usr/sbin/policy-rc.d"

# Konteinerī nav īsta diska — grub instalēšanu būvēšanas laikā atslēdz
# (instalētājs Calamares to izdarīs pareizi uz īstā datora)
GRUB_TOOLS=(/usr/sbin/grub-install /usr/sbin/update-grub /usr/lib/grub/grub-multi-install)
for t in "${GRUB_TOOLS[@]}"; do
  in_chroot dpkg-divert --local --rename --add "$t" >/dev/null
  mkdir -p "$CHROOT$(dirname "$t")"
  ln -sf /bin/true "$CHROOT$t"
done

in_chroot apt-get update
in_chroot apt-get "${APT_OPTS[@]}" install --no-install-recommends curl ca-certificates gnupg systemd-sysv dbus
in_chroot apt-get "${APT_OPTS[@]}" upgrade

# ---------------------------------------------------------------------
step "3/9  Āķi pirms pakotnēm (bez snap, Firefox, Waydroid krātuves)"
for h in config/hooks/pirms/*.sh; do
  echo "--> $(basename "$h")"
  cp "$h" "$CHROOT/tmp/hook.sh"
  in_chroot bash /tmp/hook.sh
done
rm -f "$CHROOT/tmp/hook.sh"
in_chroot apt-get update

# ---------------------------------------------------------------------
step "4/9  Pamatpakotnes, KDE Plasma, Wine, latviešu valoda"
mapfile -t REQUIRED < <(read_list config/package-lists/0*.list)
echo "Instalēju ${#REQUIRED[@]} pakotnes"
in_chroot apt-get "${APT_OPTS[@]}" install "${REQUIRED[@]}"

step "5/9  Papildu pakotnes (ja pieejamas)"
while IFS= read -r line; do
  IFS='|' read -ra alts <<<"$line"
  done_one=0
  for p in "${alts[@]}"; do
    p="$(echo "$p" | xargs)"
    [ -z "$p" ] && continue
    if in_chroot apt-cache show "$p" >/dev/null 2>&1; then
      if in_chroot apt-get "${APT_OPTS[@]}" install "$p"; then
        echo "   ✓ $p"; done_one=1; break
      else
        warn "neizdevās instalēt $p"
      fi
    fi
  done
  [ "$done_one" = 0 ] && echo "   – izlaists: $line"
done < <(read_list config/package-lists/9*.list)

# ---------------------------------------------------------------------
step "6/9  Seroga lietotnes un sistēmas faili"
rm -rf "$STAGE" && cp -a config/includes "$STAGE"
bash "$STAGE/opt/seroga/bin/seroga-atjaunot-lietotnes" --build "$STAGE" "$DEBS"

if compgen -G "$DEBS/*.deb" >/dev/null; then
  mkdir -p "$CHROOT/tmp/seroga-debs"
  cp "$DEBS"/*.deb "$CHROOT/tmp/seroga-debs/"
  for d in "$CHROOT"/tmp/seroga-debs/*.deb; do
    in_chroot apt-get "${APT_OPTS[@]}" install "/tmp/seroga-debs/$(basename "$d")" \
      || warn "neizdevās instalēt $(basename "$d")"
  done
  rm -rf "$CHROOT/tmp/seroga-debs"
fi

rsync -a "$STAGE"/ "$CHROOT"/

# ---------------------------------------------------------------------
step "7/9  Āķi pēc pakotnēm (valoda, nosaukums, ātrdarbība)"
for h in config/hooks/pec/*.sh; do
  echo "--> $(basename "$h")"
  cp "$h" "$CHROOT/tmp/hook.sh"
  in_chroot bash /tmp/hook.sh
done

in_chroot update-initramfs -u -k all

# Atjauno īstos grub rīkus
for t in "${GRUB_TOOLS[@]}"; do
  rm -f "$CHROOT$t"
  in_chroot dpkg-divert --local --rename --remove "$t" >/dev/null
done

# Tīrīšana
in_chroot apt-get "${APT_OPTS[@]}" autoremove --purge
in_chroot apt-get clean
rm -f "$CHROOT/usr/sbin/policy-rc.d" "$CHROOT/tmp/hook.sh" "$CHROOT/tmp/seroga.conf"
rm -rf "$CHROOT"/tmp/* "$CHROOT"/var/lib/apt/lists/* "$CHROOT"/root/.bash_history
: > "$CHROOT/etc/machine-id"
rm -f "$CHROOT/var/lib/dbus/machine-id"
ln -sf ../run/systemd/resolve/stub-resolv.conf "$CHROOT/etc/resolv.conf"

# Saraksts ar instalētajām pakotnēm (instalētājam)
mkdir -p "$IMAGE/casper"
in_chroot dpkg-query -W --showformat='${Package} ${Version}\n' > "$IMAGE/casper/filesystem.manifest"
cp "$IMAGE/casper/filesystem.manifest" "$IMAGE/casper/filesystem.manifest-desktop"
printf '%s\n' casper discover laptop-detect calamares calamares-settings-kubuntu \
  calamares-settings-ubuntu-common > "$IMAGE/casper/filesystem.manifest-remove"

umount_chroot

# ---------------------------------------------------------------------
step "8/9  Saspiestā sistēma (squashfs) — tas aizņem laiku"
KERNEL="$(ls -1 "$CHROOT"/boot/vmlinuz-* | sort -V | tail -n1)"
INITRD="$(ls -1 "$CHROOT"/boot/initrd.img-* | sort -V | tail -n1)"
cp "$KERNEL" "$IMAGE/casper/vmlinuz"
cp "$INITRD" "$IMAGE/casper/initrd"

mksquashfs "$CHROOT" "$IMAGE/casper/filesystem.squashfs" \
  -noappend -comp xz -b 1M -Xdict-size 100% \
  -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'run/*' 'tmp/*'
du -sx --block-size=1 "$CHROOT" | cut -f1 > "$IMAGE/casper/filesystem.size"

# Diska apraksts
mkdir -p "$IMAGE/.disk" "$IMAGE/boot/grub/fonts" "$IMAGE/EFI/ubuntu"
echo "$OS_NAME $OS_VERSION \"$CODENAME\" - amd64 ($(date +%Y%m%d))" > "$IMAGE/.disk/info"
echo "full_cd/single" > "$IMAGE/.disk/cd_type"
touch "$IMAGE/.disk/base_installable"
cp config/grub/grub.cfg "$IMAGE/boot/grub/grub.cfg"
cp config/grub/loader.cfg "$IMAGE/EFI/ubuntu/grub.cfg"
[ -f /usr/share/grub/unicode.pf2 ] && cp /usr/share/grub/unicode.pf2 "$IMAGE/boot/grub/fonts/"

# ---------------------------------------------------------------------
step "9/9  Ielādētāji (UEFI + Secure Boot, vecais BIOS) un ISO"

# UEFI: shim → parakstīts grub, iepakots FAT attēlā
cp "$SHIM"    "$BOOT/bootx64.efi"
cp "$GRUBEFI" "$BOOT/grubx64.efi"
[ -n "$MM" ] && cp "$MM" "$BOOT/mmx64.efi"
dd if=/dev/zero of="$BOOT/efiboot.img" bs=1M count=16 status=none
mkfs.vfat -F 16 -n SEROGA_EFI "$BOOT/efiboot.img" >/dev/null
export MTOOLS_SKIP_CHECK=1
mmd   -i "$BOOT/efiboot.img" ::/EFI ::/EFI/boot ::/EFI/ubuntu
mcopy -i "$BOOT/efiboot.img" "$BOOT/bootx64.efi" ::/EFI/boot/bootx64.efi
mcopy -i "$BOOT/efiboot.img" "$BOOT/grubx64.efi" ::/EFI/boot/grubx64.efi
[ -f "$BOOT/mmx64.efi" ] && mcopy -i "$BOOT/efiboot.img" "$BOOT/mmx64.efi" ::/EFI/boot/mmx64.efi
mcopy -i "$BOOT/efiboot.img" config/grub/loader.cfg ::/EFI/ubuntu/grub.cfg

# BIOS: grub ar iebūvētu meklēšanas konfigurāciju
grub-mkstandalone \
  --format=i386-pc \
  --output="$BOOT/core.img" \
  --install-modules="linux16 linux normal iso9660 biosdisk memdisk search search_fs_file tar ls configfile echo test all_video font gfxterm reboot" \
  --modules="linux16 linux normal iso9660 biosdisk search search_fs_file configfile" \
  --locales="" --fonts="" \
  "boot/grub/grub.cfg=config/grub/loader.cfg"
cat /usr/lib/grub/i386-pc/cdboot.img "$BOOT/core.img" > "$BOOT/bios.img"

EFI_GRAFTS=(
  "/EFI/boot/bootx64.efi=$BOOT/bootx64.efi"
  "/EFI/boot/grubx64.efi=$BOOT/grubx64.efi"
  "/boot/grub/bios.img=$BOOT/bios.img"
)
[ -f "$BOOT/mmx64.efi" ] && EFI_GRAFTS+=("/EFI/boot/mmx64.efi=$BOOT/mmx64.efi")

(
  cd "$IMAGE"
  xorriso -as mkisofs \
    -iso-level 3 -full-iso9660-filenames -R -J -joliet-long \
    -volid "$ISO_VOLUME" \
    -output "$ISO" \
    -eltorito-boot boot/grub/bios.img \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
      --eltorito-catalog boot/grub/boot.cat \
      --grub2-boot-info \
      --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -partition_offset 16 --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$BOOT/efiboot.img" \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -eltorito-alt-boot \
      -e '--interval:appended_partition_2:::' \
      -no-emul-boot \
    -graft-points "${EFI_GRAFTS[@]}" .
)

(cd "$OUT" && sha256sum "$(basename "$ISO")" > SHA256SUMS)
step "Gatavs!"
ls -lh "$OUT"
