import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/local/models/work_session.dart';
import '../session/session_money.dart';
import 'chain.dart';

/// Penyimpanan rantai di Hive (box 'chain'), satu entri JSON per blok.
class ChainRepository {
  static const _boxName = 'chain';

  Future<Box<String>> _box() async => Hive.isBoxOpen(_boxName)
      ? Hive.box<String>(_boxName)
      : await Hive.openBox<String>(_boxName);

  Future<List<Block>> all() async {
    final box = await _box();
    final out = <Block>[];
    for (final raw in box.values) {
      try {
        out.add(Block.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Entri rusak dilewati; celah nomor urut akan terdeteksi saat verifikasi.
      }
    }
    out.sort((a, b) => a.index.compareTo(b.index));
    return out;
  }

  Future<void> put(Block b) async {
    final box = await _box();
    await box.put(b.index.toString().padLeft(8, '0'), jsonEncode(b.toJson()));
  }
}

final chainRepositoryProvider = Provider<ChainRepository>(
  (ref) => ChainRepository(),
);

class ChainNotifier extends AsyncNotifier<List<Block>> {
  ChainRepository get _repo => ref.read(chainRepositoryProvider);

  @override
  Future<List<Block>> build() => _repo.all();

  /// Menambah blok untuk sesi yang selesai. Idempotent: sesi yang sama tidak
  /// dicatat dua kali.
  Future<Block> addForSession(WorkSession s, SessionMoney money) async {
    await future; // pastikan build() awal selesai agar tidak menimpa state kita
    final blocks = await _repo.all();
    for (final b in blocks) {
      if (b.sessionId == s.id) return b;
    }
    final block = Block.create(
      prev: blocks.isEmpty ? null : blocks.last,
      endedAtUtc: s.endedAtUtc ?? DateTime.now().toUtc(),
      sessionId: s.id,
      taskId: s.taskId,
      clientId: s.clientId,
      durationSeconds: s.durationSeconds,
      lateMinutes: s.lateMinutes,
      currency: money.currency,
      netMinor: money.netMinor,
    );
    await _repo.put(block);
    state = AsyncData([...blocks, block]);
    return block;
  }

  Future<void> reload() async {
    state = AsyncData(await _repo.all());
  }
}

final chainProvider = AsyncNotifierProvider<ChainNotifier, List<Block>>(
  ChainNotifier.new,
);

void logChainError(Object e) => debugPrint('Blockchain: gagal mencatat blok: $e');