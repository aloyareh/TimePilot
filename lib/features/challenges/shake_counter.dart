import 'dart:math';

/// Logika murni penghitung kocokan (tanpa Flutter/sensor) agar mudah diuji.
///
/// Satu kocokan terhitung jika besar percepatan (m/s², tanpa gravitasi)
/// melewati [threshold] dan sudah lewat [minGap] sejak kocokan sebelumnya.
/// Jeda minimum mencegah satu ayunan terhitung berkali-kali.
class ShakeCounter {
  ShakeCounter({
    required this.target,
    this.threshold = 12.0,
    this.minGap = const Duration(milliseconds: 300),
  }) : assert(target > 0);

  static const minTarget = 10;
  static const maxTarget = 25;

  /// Target acak 10..25 (inklusif).
  static int randomTarget([Random? random]) =>
      minTarget + (random ?? Random()).nextInt(maxTarget - minTarget + 1);

  final int target;
  final double threshold;
  final Duration minGap;

  int _count = 0;
  int? _lastShakeMs;

  int get count => _count;
  bool get isDone => _count >= target;

  /// Memproses satu sampel. Mengembalikan true jika sampel ini menambah hitungan.
  bool addSample({
    required double x,
    required double y,
    required double z,
    required int timestampMs,
  }) {
    if (isDone) return false;
    final magnitude = sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return false;
    final last = _lastShakeMs;
    if (last != null && timestampMs - last < minGap.inMilliseconds) {
      return false;
    }
    _lastShakeMs = timestampMs;
    _count++;
    return true;
  }
}
