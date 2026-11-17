/// Mesin jadwal nekios-school (Fase 2).
///
/// Semua fungsi di sini murni dan menerima `DateTime now` sebagai
/// parameter — tidak pernah membaca jam sistem sendiri. Itulah yang
/// membuat simulasi jam/bel dari nekios-remote kelak cukup menjadi
/// event state, bukan hack: remote mengirim `now` versi simulasi,
/// mesin menghitung ulang, UI menggambar ulang.
library;

import 'models.dart';

/// Status tampilan yang diturunkan dari jam (dokumen arsitektur §5).
/// Tidak pernah disimpan di model/data.
enum StatusSekolah {
  /// Sebelum slot pertama hari ini dimulai.
  sebelumMasuk,

  /// Slot pelajaran sedang berlangsung.
  pelajaran,

  /// Slot istirahat sedang berlangsung.
  istirahat,

  /// Slot ISOMA (istirahat, sholat, makan) sedang berlangsung.
  isoma,

  /// Slot khusus (upacara/apel, ROHIS/ROKRIS, kokurikuler, dst.)
  /// sedang berlangsung — semua memakai pola hero yang sama.
  khusus,

  /// Slot terakhir hari ini sudah selesai.
  pulang,

  /// Hari ini tidak ada jadwal (akhir pekan / libur / data kosong).
  tidakAdaJadwal,
}

/// Keadaan satu slot relatif terhadap `now`, untuk jendela timeline.
enum KeadaanSlot {
  selesai,
  aktif,
  berikutnya,
  akanDatang,
}

/// Satu slot di jendela timeline, lengkap dengan keadaannya.
class SlotBingkai {
  const SlotBingkai({
    required this.slot,
    required this.indeks,
    required this.keadaan,
    this.jamKe,
  });

  final Slot slot;
  final int indeks;
  final KeadaanSlot keadaan;

  /// Nomor "Jam ke-N" bila slot ini pelajaran; null selain itu.
  final int? jamKe;
}

/// Snapshot lengkap keadaan tampilan pada satu momen `now`.
///
/// Inilah yang kelak disimpan DisplayStore (Fase 2.5) dan dibaca UI:
/// UI tidak menghitung apa pun, hanya menggambar snapshot ini.
class KeadaanTampilan {
  const KeadaanTampilan({
    required this.status,
    required this.sekarang,
    this.hariIni,
    this.slotAktif,
    this.indeksAktif = -1,
    this.jamKeAktif,
    this.progresSlot,
    this.slotBerikutnya,
    this.belBerikutnya,
    this.sisaKeBel,
    this.jendela = const [],
    this.hariBerikutnya,
  });

  final StatusSekolah status;

  /// Momen yang dipakai menghitung snapshot ini.
  final DateTime sekarang;

  /// Jadwal hari ini; null bila hari ini tanpa jadwal.
  final HariJadwal? hariIni;

  /// Slot yang sedang berlangsung; null di luar jam slot.
  final Slot? slotAktif;

  /// Indeks [slotAktif] dalam daftar slot hari ini; -1 bila tidak ada.
  final int indeksAktif;

  /// "Jam ke-N" bila slot aktif adalah pelajaran.
  final int? jamKeAktif;

  /// Progres slot aktif 0.0–1.0; null bila tidak ada slot aktif.
  final double? progresSlot;

  /// Slot sesudah slot aktif (atau slot pertama saat sebelum masuk).
  final Slot? slotBerikutnya;

  /// Kapan bel berikutnya berbunyi: akhir slot aktif, atau awal slot
  /// berikutnya saat menunggu, atau awal slot pertama hari sekolah
  /// berikutnya saat pulang/libur. Null hanya bila tidak ada jadwal
  /// sama sekali dalam data.
  final DateTime? belBerikutnya;

  /// Sisa waktu menuju [belBerikutnya].
  final Duration? sisaKeBel;

  /// Jendela timeline: maksimal 5 slot di sekitar posisi sekarang
  /// (2 sebelum, aktif, 2 sesudah — pola Varian H/J yang dipilih).
  final List<SlotBingkai> jendela;

  /// Hari sekolah berikutnya yang punya jadwal (untuk status pulang:
  /// "Sampai jumpa besok, masuk 07.30").
  final HariJadwal? hariBerikutnya;
}

const _namaHari = {
  DateTime.monday: 'senin',
  DateTime.tuesday: 'selasa',
  DateTime.wednesday: 'rabu',
  DateTime.thursday: 'kamis',
  DateTime.friday: 'jumat',
  DateTime.saturday: 'sabtu',
  DateTime.sunday: 'minggu',
};

DateTime _padaMenit(DateTime hari, int menit) =>
    DateTime(hari.year, hari.month, hari.day).add(Duration(minutes: menit));

/// Nomor "Jam ke-N" untuk slot pada [indeks]: menghitung hanya slot
/// pelajaran sampai indeks itu. Null bila slotnya bukan pelajaran.
int? jamKePada(HariJadwal hari, int indeks) {
  if (indeks < 0 || indeks >= hari.slots.length) return null;
  if (!hari.slots[indeks].adalahPelajaran) return null;
  var n = 0;
  for (var i = 0; i <= indeks; i++) {
    if (hari.slots[i].adalahPelajaran) n++;
  }
  return n;
}

StatusSekolah _statusDariTipe(SlotTipe tipe) => switch (tipe) {
      SlotTipe.pelajaran => StatusSekolah.pelajaran,
      SlotTipe.istirahat => StatusSekolah.istirahat,
      SlotTipe.isoma => StatusSekolah.isoma,
      SlotTipe.upacara || SlotTipe.khusus => StatusSekolah.khusus,
    };

List<SlotBingkai> _jendela(
  HariJadwal hari,
  int dari,
  int sampai,
  KeadaanSlot Function(int indeks) keadaan,
) {
  final hasil = <SlotBingkai>[];
  for (var i = dari; i <= sampai && i < hari.slots.length; i++) {
    if (i < 0) continue;
    hasil.add(SlotBingkai(
      slot: hari.slots[i],
      indeks: i,
      keadaan: keadaan(i),
      jamKe: jamKePada(hari, i),
    ));
  }
  return hasil;
}

/// Cari hari sekolah berikutnya (1–7 hari ke depan) yang punya slot.
({HariJadwal hari, DateTime tanggal})? _hariSekolahBerikutnya(
  JadwalData data,
  DateTime dari,
) {
  for (var geser = 1; geser <= 7; geser++) {
    final tanggal = dari.add(Duration(days: geser));
    final nama = _namaHari[tanggal.weekday];
    final hari = nama == null ? null : data.hariByNama(nama);
    if (hari != null && hari.slots.isNotEmpty) {
      return (hari: hari, tanggal: tanggal);
    }
  }
  return null;
}

/// Hitung keadaan tampilan untuk momen [now] dari data [data].
KeadaanTampilan hitungKeadaan(JadwalData data, DateTime now) {
  final namaIni = _namaHari[now.weekday];
  final hariIni = namaIni == null ? null : data.hariByNama(namaIni);

  // Hari tanpa jadwal: akhir pekan / libur.
  if (hariIni == null || hariIni.slots.isEmpty) {
    final berikut = _hariSekolahBerikutnya(data, now);
    final bel = berikut == null
        ? null
        : _padaMenit(berikut.tanggal, berikut.hari.slots.first.mulaiMenit);
    return KeadaanTampilan(
      status: StatusSekolah.tidakAdaJadwal,
      sekarang: now,
      belBerikutnya: bel,
      sisaKeBel: bel?.difference(now),
      hariBerikutnya: berikut?.hari,
    );
  }

  final slots = hariIni.slots;
  final mulaiPertama = _padaMenit(now, slots.first.mulaiMenit);
  final selesaiTerakhir = _padaMenit(now, slots.last.selesaiMenit);

  // Sebelum masuk: menunggu bel slot pertama.
  if (now.isBefore(mulaiPertama)) {
    return KeadaanTampilan(
      status: StatusSekolah.sebelumMasuk,
      sekarang: now,
      hariIni: hariIni,
      slotBerikutnya: slots.first,
      belBerikutnya: mulaiPertama,
      sisaKeBel: mulaiPertama.difference(now),
      jendela: _jendela(hariIni, 0, 4,
          (i) => i == 0 ? KeadaanSlot.berikutnya : KeadaanSlot.akanDatang),
    );
  }

  // Pulang: slot terakhir sudah lewat.
  if (!now.isBefore(selesaiTerakhir)) {
    final berikut = _hariSekolahBerikutnya(data, now);
    final bel = berikut == null
        ? null
        : _padaMenit(berikut.tanggal, berikut.hari.slots.first.mulaiMenit);
    final dari = slots.length > 5 ? slots.length - 5 : 0;
    return KeadaanTampilan(
      status: StatusSekolah.pulang,
      sekarang: now,
      hariIni: hariIni,
      belBerikutnya: bel,
      sisaKeBel: bel?.difference(now),
      jendela: _jendela(hariIni, dari, slots.length - 1,
          (_) => KeadaanSlot.selesai),
      hariBerikutnya: berikut?.hari,
    );
  }

  // Di dalam rentang hari: cari slot aktif.
  for (var i = 0; i < slots.length; i++) {
    final slot = slots[i];
    final mulai = _padaMenit(now, slot.mulaiMenit);
    final selesai = _padaMenit(now, slot.selesaiMenit);
    if (!now.isBefore(mulai) && now.isBefore(selesai)) {
      final total = selesai.difference(mulai);
      final berjalan = now.difference(mulai);
      return KeadaanTampilan(
        status: _statusDariTipe(slot.tipe),
        sekarang: now,
        hariIni: hariIni,
        slotAktif: slot,
        indeksAktif: i,
        jamKeAktif: jamKePada(hariIni, i),
        progresSlot:
            (berjalan.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0),
        slotBerikutnya: i + 1 < slots.length ? slots[i + 1] : null,
        belBerikutnya: selesai,
        sisaKeBel: selesai.difference(now),
        jendela: _jendela(
          hariIni,
          i - 2,
          i + 2,
          (j) => switch (j) {
            _ when j < i => KeadaanSlot.selesai,
            _ when j == i => KeadaanSlot.aktif,
            _ when j == i + 1 => KeadaanSlot.berikutnya,
            _ => KeadaanSlot.akanDatang,
          },
        ),
      );
    }
    // Celah antar slot (data tervalidasi seharusnya rapat; jaga-jaga):
    // perlakukan sebagai menunggu slot berikutnya.
    if (now.isBefore(mulai)) {
      return KeadaanTampilan(
        status: StatusSekolah.sebelumMasuk,
        sekarang: now,
        hariIni: hariIni,
        slotBerikutnya: slot,
        belBerikutnya: mulai,
        sisaKeBel: mulai.difference(now),
        jendela: _jendela(
          hariIni,
          i - 2,
          i + 2,
          (j) => switch (j) {
            _ when j < i => KeadaanSlot.selesai,
            _ when j == i => KeadaanSlot.berikutnya,
            _ => KeadaanSlot.akanDatang,
          },
        ),
      );
    }
  }

  // Tidak tercapai pada data yang valid; kembalikan pulang sebagai
  // keadaan paling aman.
  return KeadaanTampilan(
    status: StatusSekolah.pulang,
    sekarang: now,
    hariIni: hariIni,
  );
}

/// Bagi daftar kelas menjadi halaman rotasi (pola desain Rotasi 1/2:
/// 3 kelas per halaman → 2 halaman untuk 6 kelas TKJ).
List<List<Kelas>> halamanRotasi(List<Kelas> kelas, {int perHalaman = 3}) {
  final terurut = [...kelas]..sort((a, b) => a.urutan.compareTo(b.urutan));
  final halaman = <List<Kelas>>[];
  for (var i = 0; i < terurut.length; i += perHalaman) {
    final akhir = i + perHalaman > terurut.length ? terurut.length : i + perHalaman;
    halaman.add(terurut.sublist(i, akhir));
  }
  return halaman;
}
