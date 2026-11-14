# Seroga OS

Mana operētājsistēma, kurā apvienots labākais no **Windows**, **Linux** un **Android** — un iebūvētas visas manas Seroga lietotnes.

Pamatā **Ubuntu 26.04 LTS "Resolute Raccoon"** (atbalsts līdz 2031. gadam), darbvirsma **KDE Plasma 6** Windows 11 stilā. Instalējams ISO tiek būvēts automātiski caur **GitHub Actions**.

---

## Kas ir iekšā

| No kurienes | Ko Seroga OS dod |
|---|---|
| 🪟 **Windows** | Centrēta uzdevumjosla un Start izvēlne, pazīstami īsinājumtaustiņi (`Win+E`, `Win+D`, `Win+Shift+S`), `.exe` programmas caur **Wine** un **Bottles**, spēles caur **Steam + Proton**, sistēmas atjaunošanas punkti (**Timeshift**), **Secure Boot** — palaižas uz Windows 11 datoriem bez BIOS iestatījumu maiņas |
| 🐧 **Linux** | Ubuntu stabilitāte un milzīga programmu izvēle, bez maksas, bez reklāmām, **Flatpak/Flathub** lietotņu veikals, **bez snap** — programmas ir parastas un ātras |
| 🤖 **Android** | Android lietotnes caur **Waydroid** (ar Google Play), **KDE Connect** savienojums ar telefonu, **zram** atmiņas saspiešana kā Android |
| ⭐ **Seroga** | Visas manas lietotnes iebūvētas savā Start izvēlnes sadaļā, **Seroga Centrs** vadībai, tumšā tēma ar Seroga tapeti, latviešu valoda pēc noklusējuma |

### Seroga Centrs
Atveras pirmajā palaišanā un vienmēr pieejams Start izvēlnē:
- 💿 instalēt Seroga OS uz datora (kad palaists no USB)
- 📱 ieslēgt Android lietotnes
- 🪟 instalēt Bottles Windows programmām
- 🎮 instalēt Steam
- 🔄 atjaunināt Seroga lietotnes no GitHub
- 🛟 izveidot sistēmas atjaunošanas punktu

---

## Kā iegūt ISO

### 1. Ieliec savas lietotnes (vienreiz, un katru reizi, kad tās atjauno)
1. Atver **Releases → „Seroga lietotnes (Linux)”** (tags `lietotnes-linux`) → ✏️ **Edit**
2. Ievelc visus 9 failus no `Downloads\Seroga_Linux`:
   `Seroga_Linux_1_Sistemas_riki.zip` … `Seroga_Linux_9_Auto.zip`
3. **Update release** → tad **Actions → Būvēt Seroga OS ISO → Run workflow**

Atjauninātu paku vienkārši aizvieto ar jaunu tāda paša nosaukuma failu (vecā jāizdzēš).

### 2. ISO uzbūvēsies pats
- Katrs `push` uz `main` → jauns ISO
- Katru svētdienu automātiski jauns ISO ar svaigākajiem atjauninājumiem
- Būvēšana ilgst ~1–2 stundas; ISO tiek publicēts **Releases → jaunākais**

### 3. Oficiāla versija
Izveido tagu, piem. `v2.0` (GitHub: **Releases → Draft a new release → Choose a tag**). ISO parādās **Releases** sadaļā. Ja tas ir lielāks par 2 GB, tiek sadalīts daļās — savienošanas instrukcija ir pie release.

### 4. Ieraksti USB un palaid
- Windows: **Rufus** (izvēlies "DD režīms", ja jautā) vai **balenaEtcher**
- Palaiž no USB → darbojas live režīmā bez instalēšanas
- Instalēšana: Seroga Centrs → **Instalēt Seroga OS** (Calamares instalētājs)

Live lietotājs: `seroga` (bez paroles)

---

## Manas lietotnes

Galvenais avots — tavas **Seroga_Linux pakas** (zip arhīvi Release `lietotnes-linux`). Būvēšanas laikā
[`seroga-iebuvet-pakas`](config/includes/opt/seroga/bin/seroga-iebuvet-pakas) izpako katru paku un pats atrod visas lietotnes:

| Arhīvā atrastais | Ko ar to dara |
|---|---|
| `.deb` | instalē ar apt |
| `.AppImage` | izpako (strādā bez FUSE), nosaukumu un ikonu ņem no AppImage |
| mape ar Linux programmu (Flutter `bundle/`, Qt, Electron, `bin/…`) | kopē uz `/opt/seroga/apps/<nosaukums>` |
| iekšēji `.zip` / `.tar.gz` / `.7z` | izpako un meklē tālāk |
| `.jar`, `run.sh`, `main.py` | palaiž ar Java / bash / Python |
| `.flatpak` | instalējas pirmajā palaišanā (vajag internetu) |

Start izvēlnē: **Seroga → Sistēmas rīki / Internets / DJ / Audio / Video un foto / Izskats / Spēles un emulatori / Multivide / Auto** — kategorija nāk no zip nosaukuma (`Seroga_Linux_<nr>_<Kategorija>.zip`).
Pilns saraksts: Seroga Centrs → **Manas lietotnes**, vai `/opt/seroga/apps/pakas.txt`.
Būvēšanas žurnālā (Actions) katra iebūvētā lietotne redzama ar ✓.

**Lokālai būvēšanai** ieliec zip failus mapē `lietotnes/` repo saknē (tā netiek augšupielādēta GitHub).

Papildus var lietot [`lietotnes.conf`](config/includes/usr/share/seroga/lietotnes.conf) — lietotnēm, kurām ir savs GitHub Release ar Linux failu.

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
├── build.sh                          ← viss būvēšanas process (9 soļi)
└── config/
    ├── seroga.conf                   ← versija, Ubuntu bāze, live lietotājs
    ├── package-lists/
    │   ├── 01–04-*.list              ← obligātās pakotnes
    │   └── 99-ja-pieejams.list       ← pakotnes, ko instalē, ja tās eksistē
    ├── hooks/
    │   ├── pirms/                    ← pirms pakotnēm (snap bloķēšana, Firefox, Waydroid krātuves)
    │   └── pec/                      ← pēc pakotnēm (valoda, nosaukums, ātrdarbība)
    ├── grub/                         ← ielādes izvēlne
    └── includes/                     ← faili, kas nonāk sistēmā
        ├── usr/share/seroga/lietotnes.conf                     ← papildu lietotnes no GitHub Release
        ├── opt/seroga/bin/seroga-iebuvet-pakas                 ← iebūvē tavas Seroga_Linux pakas
        ├── usr/share/plasma/look-and-feel/org.seroga.desktop/  ← Windows 11 stila izkārtojums
        ├── usr/share/wallpapers/seroga-os.svg                  ← tapete
        └── opt/seroga/bin/                                     ← Seroga Centrs, instalētājs, atjauninātājs
```

### Būvēšana savā datorā (Linux + Docker)
```bash
docker run --rm --privileged -v "$PWD":/build -w /build ubuntu:26.04 bash ./build.sh
```
ISO būs mapē `out/`.

---

## Ierobežojumi (godīgi)
- **Windows programmas:** lielākā daļa strādā caur Wine/Bottles, bet ne visas (piem. dažas spēles ar pretkrāpšanas aizsardzību).
- **Android lietotnes:** Waydroid vislabāk darbojas ar Intel/AMD grafiku; ar NVIDIA var būt problēmas.
- **Instalētājs** izmanto Kubuntu Calamares iestatījumus, tāpēc instalēšanas logā var redzēt Kubuntu logo.
- **Telefoni:** šī versija ir datoriem (x86_64).
