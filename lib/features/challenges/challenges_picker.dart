import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/models/profile.dart';
import '../session/challenge_registry.dart';

/// Sumber angka acak (bisa di-override saat test).
final challengeRandomProvider = Provider<Random>((ref) => Random());

/// Jenis tantangan untuk sebuah tugas, dipilih ACAK dari tantangan yang sudah
/// terdaftar di [challengeBuilders] (saat ini Shake & Balance).
///
/// Pilihan di-cache per taskId selama app hidup, jadi membuka ulang halaman
/// sesi tidak mengganti tantangan (tidak bisa di-"reroll" sampai dapat yang
/// mudah). Saat Dev B mendaftarkan tantangan baru (memory/math) di main(),
/// otomatis ikut masuk ke undian tanpa mengubah kode ini.
final assignedChallengeProvider = Provider.family<String, String>((
  ref,
  taskId,
) {
  final pool = challengeBuilders.keys.toList()..sort();
  if (pool.isEmpty) return ChallengeType.shake; // belum ada yang terdaftar
  return pool[ref.read(challengeRandomProvider).nextInt(pool.length)];
});
