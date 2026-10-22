import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/challenges/balance_tracker.dart';

/// Simulasi HP rata sempurna (gravitasi lurus ke sumbu Z, tanpa rotasi).
void feedFlat(BalanceTracker t, int fromMs, int toMs, {int stepMs = 20}) {
  for (var ms = fromMs; ms <= toMs; ms += stepMs) {
    t.updateAccel(0, 0, 9.81);
    t.updateGyro(0, 0, ms);
  }
}

void main() {
  test('menunggu data accelerometer sebelum menghitung', () {
    final t = BalanceTracker();
    expect(t.updateGyro(0, 0, 0), isFalse);
    expect(t.heldMs, 0);
  });

  test('HP rata 5 detik menyelesaikan 1 ronde', () {
    final t = BalanceTracker();
    feedFlat(t, 0, 5100);
    expect(t.completedRounds, 1);
  });

  test('HP rata 20+ detik menyelesaikan 4 ronde', () {
    final t = BalanceTracker();
    feedFlat(t, 0, 20500);
    expect(t.isDone, isTrue);
    expect(t.completedRounds, 4);
  });

  test('HP miring keluar target mengulang hitungan ronde', () {
    final t = BalanceTracker();
    feedFlat(t, 0, 3000);
    expect(t.heldMs, greaterThan(2000));
    // Miring ~30 derajat (ay = g*sin30, az = g*cos30) selama beberapa saat.
    for (var ms = 3020; ms <= 4500; ms += 20) {
      t.updateAccel(0, 4.905, 8.495);
      t.updateGyro(0, 0, ms);
    }
    expect(t.isBalanced, isFalse);
    expect(t.heldMs, 0);
    expect(t.completedRounds, 0);
  });

  test('simpangan kecil (3 derajat) masih dianggap seimbang', () {
    final t = BalanceTracker();
    for (var ms = 0; ms <= 1000; ms += 20) {
      t.updateAccel(0, 0.514, 9.80); // ~3 derajat
      t.updateGyro(0, 0, ms);
    }
    expect(t.isBalanced, isTrue);
  });

  test('lonjakan waktu (dt besar) tidak melompatkan hitungan tahan', () {
    final t = BalanceTracker();
    feedFlat(t, 0, 100);
    final before = t.heldMs;
    t.updateAccel(0, 0, 9.81);
    t.updateGyro(0, 0, 60000); // 1 menit kemudian
    expect(t.heldMs - before, lessThanOrEqualTo(100));
  });
}
