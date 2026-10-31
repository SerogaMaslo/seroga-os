#!/bin/bash
# Seroga OS sistēmas iestatījumi (darbojas pēc visu pakotņu instalēšanas)
set -e
. /tmp/seroga.conf

# --- Latviešu valoda, tastatūra, laika josla ---
sed -i 's/^# *lv_LV.UTF-8/lv_LV.UTF-8/; s/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen 2>/dev/null || true
grep -q '^lv_LV.UTF-8' /etc/locale.gen 2>/dev/null || echo "lv_LV.UTF-8 UTF-8" >> /etc/locale.gen
grep -q '^en_US.UTF-8' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=lv_LV.UTF-8 LANGUAGE=lv:en
cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="lv,us"
XKBVARIANT="apostrophe,"
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF
ln -sf /usr/share/zoneinfo/Europe/Riga /etc/localtime
echo "Europe/Riga" > /etc/timezone

# --- Sistēmas nosaukums (ID paliek ubuntu, lai Ubuntu rīki strādā) ---
dpkg-divert --local --rename --add /usr/lib/os-release >/dev/null
cat > /usr/lib/os-release <<EOF
PRETTY_NAME="$OS_NAME $OS_VERSION"
NAME="$OS_NAME"
VERSION_ID="$UBUNTU_VERSION"
VERSION="$OS_VERSION (uz Ubuntu $UBUNTU_VERSION LTS bāzes)"
VERSION_CODENAME=$CODENAME
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://github.com/SerogaMaslo/seroga-os"
SUPPORT_URL="https://github.com/SerogaMaslo/seroga-os/issues"
UBUNTU_CODENAME=$CODENAME
LOGO=seroga-os
EOF
ln -sf ../usr/lib/os-release /etc/os-release
cat > /etc/lsb-release <<EOF
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=$UBUNTU_VERSION
DISTRIB_CODENAME=$CODENAME
DISTRIB_DESCRIPTION="$OS_NAME $OS_VERSION"
EOF
echo "$OS_NAME $OS_VERSION \\n \\l" > /etc/issue

# --- Live sesijas lietotājs ---
cat > /etc/casper.conf <<EOF
export USERNAME="$LIVE_USER"
export USERFULLNAME="$LIVE_USER_FULLNAME"
export HOST="$LIVE_HOSTNAME"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="Seroga"
EOF

# --- Tīkls: NetworkManager pārvalda visu (kā Ubuntu Desktop) ---
chmod 600 /etc/netplan/*.yaml 2>/dev/null || true

# --- Ātrdarbība ---
if [ -f /etc/default/zramswap ]; then
  sed -i 's/^#\?ALGO=.*/ALGO=zstd/; s/^#\?PERCENT=.*/PERCENT=50/' /etc/default/zramswap
fi
echo "vm.swappiness=100" > /etc/sysctl.d/90-seroga.conf
systemctl enable zramswap.service 2>/dev/null || true
systemctl enable earlyoom.service 2>/dev/null || true

# --- Android: konteineris ieslēdzas tikai pēc lietotāja izvēles Seroga Centrā ---
systemctl disable waydroid-container.service 2>/dev/null || true

# --- Flathub ---
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# --- Pieteikšanās ekrāns ---
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/seroga.conf <<'EOF'
[Theme]
Current=breeze

[General]
Numlock=on
EOF

# --- Seroga rīki ---
chmod +x /opt/seroga/bin/* 2>/dev/null || true
echo 'PATH="/opt/seroga/bin:$PATH"' > /etc/profile.d/seroga.sh
command -v update-desktop-database >/dev/null && update-desktop-database /usr/share/applications || true
