import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/challenges/balance_tracker.dart';

const g = 9.81;

/// Simulasi HP pada sudut (roll, pitch) tertentu, tanpa rotasi gyro.
/// accPitch = atan2(ay, az), accRoll = atan2(-ax, az).
void feedAt(
  BalanceTracker t,
  double roll,
  double pitch,
  int fromMs,
  int toMs, {
  int stepMs = 20,
}) {
  for (var ms = fromMs; ms <= toMs; ms += stepMs) {
    t.updateAccel(-g * tan(roll), g * tan(pitch), g);
    t.updateGyro(0, 0, ms);
  }
}

double deg(double d) => d * pi / 180;

void main() {
  test('menunggu data accelerometer sebelum menghitung', () {
    final t = BalanceTracker(random: Random(1));
    expect(t.updateGyro(0, 0, 0), isFalse);
    expect(t.heldMs, 0);
  });

  test('HP diam rata (di meja) tidak pernah menyelesaikan ronde', () {
    for (var seed = 0; seed < 200; seed++) {
      final t = BalanceTracker(random: Random(seed));
      feedAt(t, 0, 0, 0, 60000);
      expect(t.completedRounds, 0, reason: 'seed $seed');
      expect(t.isBalanced, isFalse, reason: 'seed $seed');
    }
  });

  test('target selalu miring 14-24 derajat dari rata', () {
    for (var seed = 0; seed < 500; seed++) {
      final t = BalanceTracker(random: Random(seed));
      final tilt = sqrt(t.targetRoll * t.targetRoll + t.targetPitch * t.targetPitch);
      expect(tilt, inInclusiveRange(deg(14) - 1e-9, deg(24) + 1e-9));
    }
  });

  test('target berbeda antar-seed (benar-benar acak)', () {
    final targets = {
      for (var seed = 0; seed < 50; seed++)
        BalanceTracker(random: Random(seed)).targetRoll.toStringAsFixed(3),
    };
    expect(targets.length, greaterThan(40));
  });

  test('menahan HP di target 3 detik menyelesaikan ronde dan mengacak target baru', () {
    final t = BalanceTracker(random: Random(7));
    final r0 = t.targetRoll, p0 = t.targetPitch;
    // Beri waktu filter converge ke sudut target, lalu cek ronde selesai.
    var ms = 0;
    var done = false;
    while (ms < 20000 && !done) {
      t.updateAccel(-g * tan(r0), g * tan(p0), g);
      done = t.updateGyro(0, 0, ms);
      ms += 20;
    }
    expect(done, isTrue);
    expect(t.completedRounds, 1);
    final moved = sqrt(pow(t.targetRoll - r0, 2) + pow(t.targetPitch - p0, 2));
    expect(moved, greaterThanOrEqualTo(deg(12) - 1e-9));
  });

  test('keluar dari target mengulang hitungan tahan', () {
    final t = BalanceTracker(random: Random(3));
    final r = t.targetRoll, p = t.targetPitch;
    feedAt(t, r, p, 0, 2200); // filter converge, sedang menahan (belum 3 detik)
    expect(t.isBalanced, isTrue);
    expect(t.heldMs, greaterThan(0));
    expect(t.completedRounds, 0);
    feedAt(t, 0, 0, 2220, 3700); // kembali rata, jauh dari target
    expect(t.isBalanced, isFalse);
    expect(t.heldMs, 0);
  });

  test('4 ronde dengan mengikuti target tiap ronde menyelesaikan tantangan', () {
    final t = BalanceTracker(random: Random(11));
    var ms = 0;
    while (!t.isDone && ms < 120000) {
      t.updateAccel(-g * tan(t.targetRoll), g * tan(t.targetPitch), g);
      t.updateGyro(0, 0, ms);
      ms += 20;
    }
    expect(t.isDone, isTrue);
    expect(t.completedRounds, 4);
  });

  test('lonjakan waktu (dt besar) tidak melompatkan hitungan tahan', () {
    final t = BalanceTracker(random: Random(5));
    final r = t.targetRoll, p = t.targetPitch;
    feedAt(t, r, p, 0, 2200);
    expect(t.completedRounds, 0);
    final before = t.heldMs;
    t.updateAccel(-g * tan(r), g * tan(p), g);
    t.updateGyro(0, 0, 600000);
    expect(t.heldMs - before, lessThanOrEqualTo(100));
  });
}