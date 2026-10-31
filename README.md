# Seroga OS

Mana operētājsistēma, kurā apvienots labākais no **Windows**, **Linux** un **Android** — un iebūvētas visas manas Seroga lietotnes.

Pamatā **Debian 13**, darbvirsma **KDE Plasma 6** Windows 11 stilā, instalējams ISO tiek būvēts automātiski caur **GitHub Actions**.

---

## Kas ir iekšā

| No kurienes | Ko Seroga OS dod |
|---|---|
| 🪟 **Windows** | Centrēta uzdevumjosla un Start izvēlne, pazīstami īsinājumtaustiņi (`Win+E`, `Win+D`, `Win+Shift+S`), `.exe` programmas caur **Wine** un **Bottles**, spēles caur **Steam + Proton**, sistēmas atjaunošanas punkti (**Timeshift**) |
| 🐧 **Linux** | Stabilitāte, ātrums, bez maksas, bez reklāmām un izsekošanas, **Flatpak/Flathub** lietotņu veikals, pilna kontrole |
| 🤖 **Android** | Android lietotnes caur **Waydroid** (ar Google Play), **KDE Connect** savienojums ar telefonu, **zram** atmiņas saspiešana kā Android |
| ⭐ **Seroga** | Visas manas lietotnes iebūvētas sistēmā savā Start izvēlnes sadaļā, **Seroga Centrs** vadībai, tumšā tēma ar Seroga tapeti, latviešu valoda pēc noklusējuma |

### Seroga Centrs
Atveras pirmajā palaišanā un vienmēr pieejams Start izvēlnē. Ar vienu klikšķi:
- 📱 ieslēgt Android lietotnes
- 🪟 instalēt Bottles Windows programmām
- 🎮 instalēt Steam
- 🔄 atjaunināt Seroga lietotnes no GitHub
- 🛟 izveidot sistēmas atjaunošanas punktu

---

## Kā iegūt ISO

### 1. Izveido repozitoriju
1. GitHub izveido jaunu repo `seroga-os`
2. Augšupielādē visus šīs mapes failus (ieskaitot slēpto `.github` mapi)

### 2. ISO uzbūvēsies pats
- Katrs `push` uz `main` → **Actions** cilnē parādās jauns ISO (artefakts `seroga-os-iso`, glabājas 14 dienas)
- Katru svētdienu automātiski jauns ISO ar svaigākajiem atjauninājumiem
- Būvēšana ilgst ~40–90 minūtes

### 3. Oficiāla versija
Izveido tagu, piem. `v1.0`:
```bash
git tag v1.0 && git push origin v1.0
```
→ ISO parādās **Releases** sadaļā. Ja tas ir lielāks par 2 GB, tiek sadalīts daļās (savienošanas instrukcija ir pie release).

### 4. Ieraksti USB un palaid
- Windows: **Rufus** vai **balenaEtcher**
- Palaiž no USB → darbojas "live" režīmā bez instalēšanas
- Lai instalētu uz diska — darbvirsmā **Install Debian** (Calamares instalētājs)

Live lietotājs: `seroga`, parole: `live`

---

## Manas lietotnes

Saraksts: [`config/includes.chroot/usr/share/seroga/lietotnes.conf`](config/includes.chroot/usr/share/seroga/lietotnes.conf)

Katra lietotne tiek paņemta no sava GitHub repo **jaunākā Release**. Atpazīst automātiski:
1. `.deb` fails
2. `.AppImage` fails
3. **Flutter Linux bundle** — `.tar.gz` vai `.zip` ar `linux` nosaukumā

Ja lietotnei vēl nav release ar Linux failu — tā tiek izlaista, ISO būvējas tālāk.

> ⚠️ **Svarīgi:** sarakstā ir pieņemti repo nosaukumi (piem. `SerogaMaslo/seroga-faili`). Pārbaudi un izlabo tos atbilstoši saviem repozitorijiem.

### Kā pievienot Linux build Flutter lietotnei
Lietotnes repo GitHub Actions darbplūsmā pievieno:
```yaml
  linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: sudo apt-get update && sudo apt-get install -y ninja-build libgtk-3-dev
      - run: flutter build linux --release
      - run: tar -czf app-linux-x64.tar.gz -C build/linux/x64/release bundle
      - uses: softprops/action-gh-release@v2
        if: startsWith(github.ref, 'refs/tags/')
        with: { files: app-linux-x64.tar.gz }
```

### Atjaunināšana gatavā sistēmā
Seroga Centrs → **Atjaunināt Seroga lietotnes**, vai terminālī:
```bash
sudo seroga-atjaunot-lietotnes
```

---

## Projekta struktūra

```
seroga-os/
├── .github/workflows/build-iso.yml   ← automātiska ISO būvēšana
├── build.sh                          ← būvēšanas skripts
├── auto/config                       ← sistēmas pamatiestatījumi (Debian 13, valoda, ISO nosaukums)
└── config/
    ├── package-lists/                ← kas tiek instalēts
    ├── hooks/normal/                 ← skripti būvēšanas laikā (Waydroid, latviešu valoda, ātrdarbība)
    └── includes.chroot/              ← faili, kas nonāk sistēmā
        ├── usr/share/plasma/look-and-feel/org.seroga.desktop/   ← Windows 11 stila izkārtojums
        ├── usr/share/seroga/lietotnes.conf                       ← TAVU LIETOTŅU SARAKSTS
        ├── usr/share/wallpapers/seroga-os.svg                   ← tapete
        └── opt/seroga/bin/                                      ← Seroga Centrs un atjauninātājs
```

### Būvēšana savā datorā (ja ir Linux + Docker)
```bash
docker run --rm --privileged -v "$PWD":/build -w /build debian:trixie ./build.sh
```
ISO būs mapē `out/`.

---

## Ierobežojumi (godīgi)
- **Windows programmas:** lielākā daļa strādā caur Wine/Bottles, bet ne visas (piem. dažas ar pretkrāpšanas aizsardzību spēlēs).
- **Android lietotnes:** Waydroid vislabāk darbojas ar Intel/AMD grafiku; ar NVIDIA var būt problēmas.
- **Telefoni:** šī versija ir datoriem (x86_64).
