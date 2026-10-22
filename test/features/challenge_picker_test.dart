import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/data/local/models/profile.dart';
import 'package:time_pilot/features/challenges/challenges_picker.dart';
import 'package:time_pilot/features/session/challenge_registry.dart';

Widget _dummy(BuildContext c, int d) => const SizedBox();

void main() {
  setUp(challengeBuilders.clear);
  tearDown(challengeBuilders.clear);

  test('hanya memilih dari tantangan yang terdaftar', () {
    challengeBuilders[ChallengeType.shake] = _dummy;
    challengeBuilders[ChallengeType.balance] = _dummy;
    final c = ProviderContainer(
      overrides: [challengeRandomProvider.overrideWithValue(Random(7))],
    );
    addTearDown(c.dispose);

    final seen = <String>{};
    for (var i = 0; i < 100; i++) {
      seen.add(c.read(assignedChallengeProvider('task-$i')));
    }
    expect(seen, {ChallengeType.shake, ChallengeType.balance});
    expect(seen.contains(ChallengeType.memory), isFalse);
  });

  test('pilihan untuk satu tugas tidak berubah saat dibaca ulang', () {
    challengeBuilders[ChallengeType.shake] = _dummy;
    challengeBuilders[ChallengeType.balance] = _dummy;
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final first = c.read(assignedChallengeProvider('t1'));
    for (var i = 0; i < 20; i++) {
      expect(c.read(assignedChallengeProvider('t1')), first);
    }
  });

  test('registry kosong -> fallback shake', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(assignedChallengeProvider('t1')), ChallengeType.shake);
  });

  test('tantangan baru yang didaftarkan otomatis ikut undian', () {
    challengeBuilders[ChallengeType.shake] = _dummy;
    challengeBuilders[ChallengeType.balance] = _dummy;
    challengeBuilders[ChallengeType.memory] = _dummy;
    final c = ProviderContainer(
      overrides: [challengeRandomProvider.overrideWithValue(Random(3))],
    );
    addTearDown(c.dispose);

    final seen = {
      for (var i = 0; i < 200; i++) c.read(assignedChallengeProvider('t$i')),
    };
    expect(seen, {
      ChallengeType.shake,
      ChallengeType.balance,
      ChallengeType.memory,
    });
  });
}
