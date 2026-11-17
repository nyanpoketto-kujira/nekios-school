/// Model data jadwal nekios-school.
///
/// Model ini cerminan persis dari berkas `assets/jadwal-tkj.json`
/// (lihat dokumen arsitektur data §3–§5). Semua kelas immutable dan
/// mendukung round-trip JSON (`fromJson`/`toJson`) karena format yang
/// sama kelak dipakai sebagai payload packet nekios-core.
library;

/// Tipe slot dalam satu hari. Status tampilan (sedang berlangsung,
/// istirahat, dst.) TIDAK disimpan — diturunkan dari jam di mesin
/// jadwal (Fase 2).
enum SlotTipe {
  pelajaran,
  istirahat,
  isoma,
  upacara,
  khusus;

  static SlotTipe fromString(String nilai) {
    return SlotTipe.values.firstWhere(
      (t) => t.name == nilai,
      orElse: () => throw FormatException('Tipe slot tidak dikenal: $nilai'),
    );
  }
}

/// Guru, dikunci oleh kode guru (KG) dari jadwal induk cetak.
class Guru {
  const Guru({required this.kg, required this.nama, required this.terverifikasi});

  final int kg;
  final String nama;
  final bool terverifikasi;

  factory Guru.fromJson(Map<String, dynamic> json) => Guru(
        kg: json['kg'] as int,
        nama: json['nama'] as String,
        terverifikasi: json['terverifikasi'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'kg': kg,
        'nama': nama,
        'terverifikasi': terverifikasi,
      };
}

/// Mata pelajaran: kode singkat (tampilan grid), nama panjang
/// (tampilan kartu Sekarang), dan warna identitas dari kertas.
class Mapel {
  const Mapel({required this.kode, required this.namaPanjang, required this.warna});

  final String kode;
  final String namaPanjang;
  final String warna;

  factory Mapel.fromJson(Map<String, dynamic> json) => Mapel(
        kode: json['kode'] as String,
        namaPanjang: json['namaPanjang'] as String,
        warna: json['warna'] as String,
      );

  Map<String, dynamic> toJson() => {
        'kode': kode,
        'namaPanjang': namaPanjang,
        'warna': warna,
      };
}

/// Kelas (ruang) yang jadi kolom jadwal, mis. X-TKJ-A.
class Kelas {
  const Kelas({required this.id, required this.nama, required this.urutan});

  final String id;
  final String nama;
  final int urutan;

  factory Kelas.fromJson(Map<String, dynamic> json) => Kelas(
        id: json['id'] as String,
        nama: json['nama'] as String,
        urutan: json['urutan'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'urutan': urutan,
      };
}

/// Isi satu sel jadwal: pasangan mapel + guru (foreign key).
class Entri {
  const Entri({required this.mapel, required this.kg});

  final String mapel;
  final int kg;

  factory Entri.fromJson(Map<String, dynamic> json) => Entri(
        mapel: json['mapel'] as String,
        kg: json['kg'] as int,
      );

  Map<String, dynamic> toJson() => {
        'mapel': mapel,
        'kg': kg,
      };
}

/// Ubah format jam "JJ.MM" menjadi menit sejak tengah malam.
int menitDariJam(String jam) {
  final bagian = jam.split('.');
  if (bagian.length != 2) {
    throw FormatException('Format jam tidak valid: "$jam" (harus JJ.MM)');
  }
  final j = int.parse(bagian[0]);
  final m = int.parse(bagian[1]);
  return j * 60 + m;
}

/// Satu baris waktu dalam sehari. Slot menempel pada hari karena
/// pola jam berbeda per hari (Jumat jauh lebih pendek, dst.).
class Slot {
  const Slot({
    required this.mulai,
    required this.selesai,
    required this.tipe,
    this.label,
    this.entri = const {},
  });

  final String mulai;
  final String selesai;
  final SlotTipe tipe;
  final String? label;
  final Map<String, Entri> entri;

  int get mulaiMenit => menitDariJam(mulai);
  int get selesaiMenit => menitDariJam(selesai);
  int get durasiMenit => selesaiMenit - mulaiMenit;
  bool get adalahPelajaran => tipe == SlotTipe.pelajaran;

  factory Slot.fromJson(Map<String, dynamic> json) {
    final entriJson = json['entri'] as Map<String, dynamic>? ?? const {};
    return Slot(
      mulai: json['mulai'] as String,
      selesai: json['selesai'] as String,
      tipe: SlotTipe.fromString(json['tipe'] as String),
      label: json['label'] as String?,
      entri: entriJson.map(
        (kelasId, nilai) => MapEntry(
          kelasId,
          Entri.fromJson(nilai as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'mulai': mulai,
        'selesai': selesai,
        'tipe': tipe.name,
        if (label != null) 'label': label,
        if (entri.isNotEmpty)
          'entri': entri.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Jadwal satu hari (Senin–Jumat).
class HariJadwal {
  const HariJadwal({required this.nama, required this.slots});

  final String nama;
  final List<Slot> slots;

  factory HariJadwal.fromJson(Map<String, dynamic> json) => HariJadwal(
        nama: json['nama'] as String,
        slots: (json['slots'] as List<dynamic>)
            .map((s) => Slot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'slots': slots.map((s) => s.toJson()).toList(),
      };
}

/// Akar data jadwal: metadata + tabel referensi + jadwal per hari.
class JadwalData {
  const JadwalData({
    required this.sekolah,
    required this.judul,
    required this.tahunPelajaran,
    required this.jurusan,
    required this.kelas,
    required this.guru,
    required this.mapel,
    required this.hari,
  });

  final String sekolah;
  final String judul;
  final String tahunPelajaran;
  final String jurusan;
  final List<Kelas> kelas;
  final List<Guru> guru;
  final List<Mapel> mapel;
  final List<HariJadwal> hari;

  Guru? guruByKg(int kg) {
    for (final g in guru) {
      if (g.kg == kg) return g;
    }
    return null;
  }

  Mapel? mapelByKode(String kode) {
    for (final m in mapel) {
      if (m.kode == kode) return m;
    }
    return null;
  }

  HariJadwal? hariByNama(String nama) {
    for (final h in hari) {
      if (h.nama == nama) return h;
    }
    return null;
  }

  factory JadwalData.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return JadwalData(
      sekolah: meta['sekolah'] as String,
      judul: meta['judul'] as String,
      tahunPelajaran: meta['tahunPelajaran'] as String,
      jurusan: meta['jurusan'] as String,
      kelas: (json['kelas'] as List<dynamic>)
          .map((k) => Kelas.fromJson(k as Map<String, dynamic>))
          .toList(),
      guru: (json['guru'] as List<dynamic>)
          .map((g) => Guru.fromJson(g as Map<String, dynamic>))
          .toList(),
      mapel: (json['mapel'] as List<dynamic>)
          .map((m) => Mapel.fromJson(m as Map<String, dynamic>))
          .toList(),
      hari: (json['hari'] as List<dynamic>)
          .map((h) => HariJadwal.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'meta': {
          'sekolah': sekolah,
          'judul': judul,
          'tahunPelajaran': tahunPelajaran,
          'jurusan': jurusan,
        },
        'kelas': kelas.map((k) => k.toJson()).toList(),
        'guru': guru.map((g) => g.toJson()).toList(),
        'mapel': mapel.map((m) => m.toJson()).toList(),
        'hari': hari.map((h) => h.toJson()).toList(),
      };
}
