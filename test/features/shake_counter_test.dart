import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/challenges/shake_counter.dart';

void main() {
  group('ShakeCounter.randomTarget', () {
    test('selalu di rentang 10..25 dan mencapai kedua ujung', () {
      final rnd = Random(42);
      final seen = <int>{};
      for (var i = 0; i < 2000; i++) {
        final t = ShakeCounter.randomTarget(rnd);
        expect(t, inInclusiveRange(10, 25));
        seen.add(t);
      }
      expect(seen, containsAll([10, 25]));
    });
  });

  group('ShakeCounter.addSample', () {
    test('HP diam (percepatan kecil) tidak terhitung', () {
      final c = ShakeCounter(target: 10);
      for (var i = 0; i < 100; i++) {
        c.addSample(x: 0.1, y: 0.2, z: 0.1, timestampMs: i * 20);
      }
      expect(c.count, 0);
    });

    test('kocokan kuat terhitung', () {
      final c = ShakeCounter(target: 10);
      expect(c.addSample(x: 15, y: 0, z: 0, timestampMs: 1000), isTrue);
      expect(c.count, 1);
    });

    test('sampel beruntun dalam jeda minimum dihitung satu kali', () {
      final c = ShakeCounter(target: 10);
      c.addSample(x: 15, y: 0, z: 0, timestampMs: 1000);
      c.addSample(x: 15, y: 0, z: 0, timestampMs: 1100);
      c.addSample(x: 15, y: 0, z: 0, timestampMs: 1250);
      expect(c.count, 1);
      c.addSample(x: 15, y: 0, z: 0, timestampMs: 1300);
      expect(c.count, 2);
    });

    test('selesai tepat di target dan tidak menghitung lagi', () {
      final c = ShakeCounter(target: 3);
      for (var i = 0; i < 10; i++) {
        c.addSample(x: 20, y: 0, z: 0, timestampMs: i * 400);
      }
      expect(c.isDone, isTrue);
      expect(c.count, 3);
    });
  });
}
