#!/bin/bash
# Seroga OS neizmanto snap — programmas nāk kā parastas .deb pakotnes vai Flatpak.
set -e
cat > /etc/apt/preferences.d/seroga-bez-snap.pref <<'EOF'
# Seroga OS: snap ir bloķēts
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
