# nekios-school

Display TV jadwal sekolah SMKN 1 Ukui — bagian dari ekosistem
**Nekios** (Material You / Material 3, dark theme, landscape 1080p
untuk Android TV & desktop).

Bagian ekosistem (microrepo):

- `nekios-core` — protokol sync & utilitas bersama (menyusul)
- `nekios-school` — repo ini: UI TV + mesin jadwal
- `nekios-remote` — kontrol via WebSocket (menyusul)
- `nekios-mosque` — masjid-you

## Arsitektur singkat

Layer `domain/` (model + validasi + mesin jadwal, Dart murni) →
`state/` (DisplayStore + event) → `sources/` (asset sekarang,
WebSocket nekios-core nanti) → `ui/` (membaca state saja).
Detail: `docs/DECISIONS.md`. Data jadwal: `assets/jadwal-tkj.json`
(sumber: `data/jadwal-tkj.json`).

## Menjalankan test

```bash
flutter analyze
flutter test
```
