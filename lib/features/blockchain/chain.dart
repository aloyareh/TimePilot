import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash "sebelum blok pertama".
final String genesisHash = '0' * 64;

/// Satu blok = catatan satu sesi kerja yang selesai (PBI-21).
/// Hash dihitung dari semua field + hash blok sebelumnya, sehingga mengubah
/// data lama memutus rantai.
class Block {
  const Block({
    required this.index,
    required this.prevHash,
    required this.timestampMs,
    required this.sessionId,
    required this.taskId,
    required this.clientId,
    required this.durationSeconds,
    required this.lateMinutes,
    required this.currency,
    required this.netMinor,
    required this.hash,
  });

  final int index;
  final String prevHash;
  final int timestampMs;
  final String sessionId;
  final String taskId;
  final String clientId;
  final int durationSeconds;
  final int lateMinutes;
  final String currency;
  final int netMinor;
  final String hash;

  /// Teks kanonik yang di-hash. Urutan dan pemisah tidak boleh diubah.
  static String canonical({
    required int index,
    required String prevHash,
    required int timestampMs,
    required String sessionId,
    required String taskId,
    required String clientId,
    required int durationSeconds,
    required int lateMinutes,
    required String currency,
    required int netMinor,
  }) => [
    index,
    prevHash,
    timestampMs,
    sessionId,
    taskId,
    clientId,
    durationSeconds,
    lateMinutes,
    currency,
    netMinor,
  ].join('|');

  static String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();

  /// Hash yang seharusnya dimiliki blok ini berdasarkan isinya sekarang.
  String recompute() => _sha256(
    canonical(
      index: index,
      prevHash: prevHash,
      timestampMs: timestampMs,
      sessionId: sessionId,
      taskId: taskId,
      clientId: clientId,
      durationSeconds: durationSeconds,
      lateMinutes: lateMinutes,
      currency: currency,
      netMinor: netMinor,
    ),
  );

  factory Block.create({
    Block? prev,
    required DateTime endedAtUtc,
    required String sessionId,
    required String taskId,
    required String clientId,
    required int durationSeconds,
    required int lateMinutes,
    required String currency,
    required int netMinor,
  }) {
    final index = prev == null ? 0 : prev.index + 1;
    final prevHash = prev == null ? genesisHash : prev.hash;
    final ts = endedAtUtc.toUtc().millisecondsSinceEpoch;
    final hash = _sha256(
      canonical(
        index: index,
        prevHash: prevHash,
        timestampMs: ts,
        sessionId: sessionId,
        taskId: taskId,
        clientId: clientId,
        durationSeconds: durationSeconds,
        lateMinutes: lateMinutes,
        currency: currency,
        netMinor: netMinor,
      ),
    );
    return Block(
      index: index,
      prevHash: prevHash,
      timestampMs: ts,
      sessionId: sessionId,
      taskId: taskId,
      clientId: clientId,
      durationSeconds: durationSeconds,
      lateMinutes: lateMinutes,
      currency: currency,
      netMinor: netMinor,
      hash: hash,
    );
  }

  /// Salinan dengan isi diubah TANPA menghitung ulang hash (untuk demo manipulasi).
  Block tampered({int? durationSeconds, int? netMinor, String? prevHash}) => Block(
    index: index,
    prevHash: prevHash ?? this.prevHash,
    timestampMs: timestampMs,
    sessionId: sessionId,
    taskId: taskId,
    clientId: clientId,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    lateMinutes: lateMinutes,
    currency: currency,
    netMinor: netMinor ?? this.netMinor,
    hash: hash,
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'prev_hash': prevHash,
    'timestamp_ms': timestampMs,
    'session_id': sessionId,
    'task_id': taskId,
    'client_id': clientId,
    'duration_seconds': durationSeconds,
    'late_minutes': lateMinutes,
    'currency': currency,
    'net_minor': netMinor,
    'hash': hash,
  };

  factory Block.fromJson(Map<String, dynamic> j) => Block(
    index: j['index'] as int,
    prevHash: j['prev_hash'] as String,
    timestampMs: j['timestamp_ms'] as int,
    sessionId: j['session_id'] as String,
    taskId: j['task_id'] as String,
    clientId: j['client_id'] as String,
    durationSeconds: j['duration_seconds'] as int,
    lateMinutes: j['late_minutes'] as int,
    currency: j['currency'] as String,
    netMinor: j['net_minor'] as int,
    hash: j['hash'] as String,
  );
}

/// Memeriksa rantai berurutan dari blok pertama.
/// Mengembalikan index blok pertama yang bermasalah, atau null jika valid.
/// Yang diperiksa: nomor urut tanpa celah, tautan prevHash, dan hash cocok isi.
int? firstInvalidIndex(List<Block> blocks) {
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final expectedPrev = i == 0 ? genesisHash : blocks[i - 1].hash;
    if (b.index != i || b.prevHash != expectedPrev || b.hash != b.recompute()) {
      return i;
    }
  }
  return null;
}