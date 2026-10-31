#!/bin/bash
# Android lietotnes — Waydroid oficiālā krātuve.
# Ja jaunajai Ubuntu versijai krātuves vēl nav, ņem tuvāko LTS (noble).
set -e
. /etc/os-release
CODE="${VERSION_CODENAME:-resolute}"
if ! curl -fsI "https://repo.waydro.id/dists/$CODE/Release" >/dev/null 2>&1; then
  echo "Waydroid krātuvē nav '$CODE' — izmantoju 'noble'"
  CODE=noble
fi
curl -fsSL https://repo.waydro.id/waydroid.gpg -o /usr/share/keyrings/waydroid.gpg || {
  echo "BRĪDINĀJUMS: Waydroid krātuve nav pieejama — Android atbalsts tiks izlaists"; exit 0; }
echo "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ $CODE main" \
  > /etc/apt/sources.list.d/waydroid.list
