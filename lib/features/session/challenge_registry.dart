import 'package:flutter/widgets.dart';

import '../../data/local/models/profile.dart';

/// Kontrak untuk halaman tantangan (PBI-14, 15, 16).
///
/// Setiap halaman tantangan harus memanggil `Navigator.of(context).pop(true)`
/// saat tantangan BERHASIL (dan pop(false)/kembali jika dibatalkan).
/// Daftarkan di main() sebelum runApp, contoh:
///
///   challengeBuilders[ChallengeType.shake] =
///       (context, difficulty) => ShakeChallengePage(difficulty: difficulty);
typedef ChallengeBuilder = Widget Function(
  BuildContext context,
  int difficulty,
);

final Map<String, ChallengeBuilder> challengeBuilders = {};

String challengeLabel(String type) => switch (type) {
  ChallengeType.shake => 'Shake to Wake',
  ChallengeType.balance => 'Balance Challenge',
  ChallengeType.memory => 'Memory Puzzle',
  ChallengeType.math => 'Soal Matematika',
  ChallengeType.puzzle => 'Puzzle Gambar',
  _ => type,
};
