/// Layer state nekios-school.
///
/// Berisi `DisplayStore` (snapshot state tampilan: data jadwal, teks
/// mading, offset jam simulasi, status koneksi) dan tipe-tipe event
/// yang mengubahnya. Diisi pada Fase 2.5 — lihat docs/DECISIONS.md
/// ADR-001. UI hanya membaca layer ini; UI tidak pernah menyentuh
/// sumber data secara langsung.
library;
