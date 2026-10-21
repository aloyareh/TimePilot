/// Hitungan uang untuk satu sesi kerja (PBI-18). Fungsi murni, mudah diuji.
///
/// Aturan (asumsi yang perlu disetujui tim, lihat README):
///   kotor = durasi (jam) x tarif per jam
///   denda = menit terlambat / 60 x tarif per jam
///   bersih = max(0, kotor - denda)
/// Semua dalam mata uang klien; konversi ke IDR dilakukan terpisah dengan kurs.
class SessionMoney {
  const SessionMoney({
    required this.gross,
    required this.penalty,
    required this.net,
    required this.currency,
  });

  final double gross;
  final double penalty;
  final double net;
  final String currency;

  /// Bersih dalam satuan terkecil (sen), bulat, dipakai agar hash blockchain
  /// deterministik (tidak bergantung format desimal).
  int get netMinor => (net * 100).round();
}

SessionMoney computeSessionMoney({
  required int durationSeconds,
  required int lateMinutes,
  required double hourlyRate,
  required String currency,
}) {
  final gross = durationSeconds < 0 ? 0.0 : durationSeconds / 3600 * hourlyRate;
  final penalty = lateMinutes <= 0 ? 0.0 : lateMinutes / 60 * hourlyRate;
  final net = gross - penalty;
  return SessionMoney(
    gross: gross,
    penalty: penalty,
    net: net < 0 ? 0 : net,
    currency: currency,
  );
}