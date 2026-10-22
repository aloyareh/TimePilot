import 'dart:math';

/// Logika murni Balance Challenge (tanpa Flutter/sensor) agar mudah diuji.
///
/// Kemiringan HP diestimasi dengan complementary filter:
///  - Gyroscope (rad/s) diintegrasikan -> responsif, tapi lama-lama melenceng.
///  - Accelerometer (arah gravitasi) -> absolut, tapi berisik.
/// Hasilnya: sudut roll ([roll], kiri-kanan) dan pitch ([pitch], depan-belakang)
/// dalam radian, dengan 0 = HP rata (layar menghadap atas).
///
/// Tantangan: jaga HP tetap di dalam [tolerance] selama [holdMs] berturut-turut,
/// sebanyak [rounds] ronde. Keluar dari zona target mengulang hitungan ronde itu.
class BalanceTracker {
  BalanceTracker({
    this.rounds = 4,
    this.holdMs = 5000,
    this.tolerance = 8 * pi / 180,
    this.alpha = 0.98,
  }) : assert(rounds > 0 && holdMs > 0);

  final int rounds;
  final int holdMs;

  /// Batas simpangan (radian) agar dianggap seimbang. Default 8 derajat.
  final double tolerance;

  /// Bobot gyro pada filter (0..1). Makin besar makin percaya gyro.
  final double alpha;

  double _roll = 0; // rotasi sumbu Y -> bola ke kiri/kanan
  double _pitch = 0; // rotasi sumbu X -> bola ke atas/bawah
  double? _accRoll;
  double? _accPitch;
  int? _lastGyroMs;
  bool _initialized = false;

  int _heldMs = 0;
  int _completedRounds = 0;

  double get roll => _roll;
  double get pitch => _pitch;

  /// Simpangan total dari posisi rata (radian).
  double get deviation => sqrt(_roll * _roll + _pitch * _pitch);

  bool get isBalanced => deviation <= tolerance;
  int get heldMs => _heldMs;
  int get completedRounds => _completedRounds;
  bool get isDone => _completedRounds >= rounds;

  /// Sampel accelerometer (m/s², termasuk gravitasi). Hanya menyimpan sudut
  /// absolut; filter dijalankan di [updateGyro].
  void updateAccel(double ax, double ay, double az) {
    _accPitch = atan2(ay, az);
    _accRoll = atan2(-ax, az);
  }

  /// Sampel gyroscope (rad/s) pada waktu [nowMs]. Memperbarui sudut dan
  /// hitungan tahan. Mengembalikan true jika sebuah ronde baru selesai.
  bool updateGyro(double gx, double gy, int nowMs) {
    if (isDone) return false;
    final accRoll = _accRoll;
    final accPitch = _accPitch;
    if (accRoll == null || accPitch == null) return false; // tunggu accel

    if (!_initialized) {
      _roll = accRoll;
      _pitch = accPitch;
      _initialized = true;
      _lastGyroMs = nowMs;
      return false;
    }

    // Batasi dt agar lonjakan (app di-pause dll.) tidak merusak integrasi.
    final dtMs = (nowMs - (_lastGyroMs ?? nowMs)).clamp(0, 100).toInt();
    _lastGyroMs = nowMs;
    final dt = dtMs / 1000.0;

    _pitch = alpha * (_pitch + gx * dt) + (1 - alpha) * accPitch;
    _roll = alpha * (_roll + gy * dt) + (1 - alpha) * accRoll;

    if (isBalanced) {
      _heldMs += dtMs;
      if (_heldMs >= holdMs) {
        _completedRounds++;
        _heldMs = 0;
        return true;
      }
    } else {
      _heldMs = 0;
    }
    return false;
  }

  /// Hanya untuk simulasi saat debug di emulator.
  void debugCompleteRound() {
    if (isDone) return;
    _completedRounds++;
    _heldMs = 0;
  }
}
