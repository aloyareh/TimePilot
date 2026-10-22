import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/local/models/task.dart';
import '../../data/local/models/work_session.dart';
import '../../data/remote/session_storage.dart';
import '../blockchain/chain.dart';
import '../blockchain/chain_repository.dart';
import '../profile/profile_providers.dart';
import '../session/session_providers.dart';
import '../tasks/task_providers.dart';
import 'sync_mappers.dart';

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SyncResult {
  const SyncResult({
    this.pushedTasks = 0,
    this.pushedSessions = 0,
    this.pushedBlocks = 0,
    this.pulledTasks = 0,
    this.pulledSessions = 0,
    this.pulledBlocks = 0,
    this.chainConflicts = const [],
    this.staleAlarmTaskIds = const [],
  });

  final int pushedTasks;
  final int pushedSessions;
  final int pushedBlocks;
  final int pulledTasks;
  final int pulledSessions;
  final int pulledBlocks;

  /// Blok lokal yang berbeda dengan salinan server (kemungkinan manipulasi).
  final List<int> chainConflicts;

  /// Tugas yang dari server sudah selesai/dihapus: alarm lokalnya harus dibatalkan.
  final List<String> staleAlarmTaskIds;

  int get pushed => pushedTasks + pushedSessions + pushedBlocks;
  int get pulled => pulledTasks + pulledSessions + pulledBlocks;
}

/// Sinkronisasi local-first (PBI-22): Hive = sumber utama, Supabase = salinan online.
///
/// Tugas dan sesi: dorong baris yang berubah sejak push terakhir, tarik baris yang
/// berubah di server sejak kursor terakhir, konflik diselesaikan last-write-wins
/// (updated_at). Blockchain: dorong blok yang belum ada di server (server memverifikasi
/// hash dan tautannya), dan pulihkan rantai dari server bila rantai lokal kosong.
///
/// Belum disinkronkan: profil dan klien (dikerjakan lewat PersonaRemote, hanya dorong).
class SyncService {
  SyncService({SupabaseClient? client, SessionStorage? storage})
    : _clientOverride = client,
      _storage = storage ?? const SessionStorage();

  final SupabaseClient? _clientOverride;
  final SessionStorage _storage;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const _metaBox = 'sync_meta';
  static const _chunk = 200;

  Future<Box<String>> _meta() async => Hive.isBoxOpen(_metaBox)
      ? Hive.box<String>(_metaBox)
      : await Hive.openBox<String>(_metaBox);

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw SyncException(e.message);
    } catch (_) {
      throw const SyncException('OFFLINE');
    }
  }

  List<Map<String, dynamic>> _rows(dynamic raw) =>
      (raw as List).cast<Map<String, dynamic>>();

  Future<SyncResult> run(String uid) async {
    final token = await _storage.readToken();
    if (token == null) throw const SyncException('SESSION_INVALID');
    final meta = await _meta();
    String k(String name) => '$uid:$name';

    // ------------------------------------------------------------ tugas: dorong
    final tasksBox = Hive.box<Task>(HiveBoxes.tasks);
    final pushTaskCursor = int.tryParse(meta.get(k('push_tasks')) ?? '');
    final dirtyTasks = tasksBox.values
        .where(
          (t) =>
              t.ownerId == uid &&
              (pushTaskCursor == null ||
                  t.updatedAt.toUtc().millisecondsSinceEpoch > pushTaskCursor),
        )
        .toList();
    for (var i = 0; i < dirtyTasks.length; i += _chunk) {
      final part = dirtyTasks.skip(i).take(_chunk).map(taskToJson).toList();
      await _rpc('app_sync_push_tasks', {'p_token': token, 'p_items': part});
    }
    if (dirtyTasks.isNotEmpty) {
      final maxMs = dirtyTasks
          .map((t) => t.updatedAt.toUtc().millisecondsSinceEpoch)
          .reduce((a, b) => a > b ? a : b);
      await meta.put(k('push_tasks'), maxMs.toString());
    }

    // ------------------------------------------------------------ tugas: tarik
    var pulledTasks = 0;
    final staleAlarms = <String>[];
    final taskRows = _rows(
      await _rpc('app_sync_pull_tasks', {
        'p_token': token,
        'p_since': meta.get(k('pull_tasks')),
      }),
    );
    for (final row in taskRows) {
      final id = row['id'] as String;
      final local = tasksBox.get(id);
      if (local != null && local.ownerId != uid) continue; // bukan milik akun ini
      final remote = taskFromJson(row, uid);
      if (shouldApplyRemote(local?.updatedAt, remote.updatedAt)) {
        await tasksBox.put(id, remote);
        pulledTasks++;
        if (remote.isDeleted || remote.status != TaskStatus.todo) staleAlarms.add(id);
      }
    }
    if (taskRows.isNotEmpty) {
      await meta.put(k('pull_tasks'), taskRows.last['server_updated_at'] as String);
    }

    // ------------------------------------------------------------ sesi: dorong
    // Hanya sesi SELESAI; kepemilikan diturunkan dari tugasnya.
    final sessionsBox = Hive.box<WorkSession>(HiveBoxes.sessions);
    bool mine(WorkSession s) => tasksBox.get(s.taskId)?.ownerId == uid;
    final pushSessionCursor = int.tryParse(meta.get(k('push_sessions')) ?? '');
    final dirtySessions = sessionsBox.values
        .where(
          (s) =>
              s.endedAtUtc != null &&
              mine(s) &&
              (pushSessionCursor == null ||
                  s.updatedAt.toUtc().millisecondsSinceEpoch > pushSessionCursor),
        )
        .toList();
    for (var i = 0; i < dirtySessions.length; i += _chunk) {
      final part = dirtySessions.skip(i).take(_chunk).map(sessionToJson).toList();
      await _rpc('app_sync_push_sessions', {'p_token': token, 'p_items': part});
    }
    if (dirtySessions.isNotEmpty) {
      final maxMs = dirtySessions
          .map((s) => s.updatedAt.toUtc().millisecondsSinceEpoch)
          .reduce((a, b) => a > b ? a : b);
      await meta.put(k('push_sessions'), maxMs.toString());
    }

    // ------------------------------------------------------------ sesi: tarik
    var pulledSessions = 0;
    final sessionRows = _rows(
      await _rpc('app_sync_pull_sessions', {
        'p_token': token,
        'p_since': meta.get(k('pull_sessions')),
      }),
    );
    for (final row in sessionRows) {
      final remote = sessionFromJson(row);
      final local = sessionsBox.get(remote.id);
      if (local != null && !mine(local)) continue;
      if (shouldApplyRemote(local?.updatedAt, remote.updatedAt)) {
        await sessionsBox.put(remote.id, remote);
        pulledSessions++;
      }
    }
    if (sessionRows.isNotEmpty) {
      await meta.put(k('pull_sessions'), sessionRows.last['server_updated_at'] as String);
    }

    // ------------------------------------------------------------ blockchain
    final chainRepo = ChainRepository(uid);
    var local = await chainRepo.all();
    final remoteBlocks = _rows(
      await _rpc('app_sync_pull_blocks', {'p_token': token}),
    ).map(Block.fromJson).toList();

    var pulledBlocks = 0;
    if (local.isEmpty && remoteBlocks.isNotEmpty) {
      // Perangkat baru / data lokal hilang: pulihkan dari server bila rantainya valid.
      if (firstInvalidIndex(remoteBlocks) == null) {
        for (final b in remoteBlocks) {
          await chainRepo.put(b);
        }
        local = remoteBlocks;
        pulledBlocks = remoteBlocks.length;
      }
    }

    final onServer = {for (final b in remoteBlocks) b.index};
    final toPush = local.where((b) => !onServer.contains(b.index)).toList();
    var conflicts = const <int>[];
    var pushedBlocks = 0;
    for (var i = 0; i < toPush.length; i += _chunk) {
      final part = toPush.skip(i).take(_chunk).map((b) => b.toJson()).toList();
      final res = (await _rpc('app_sync_push_blocks', {
        'p_token': token,
        'p_items': part,
      })) as Map<String, dynamic>;
      pushedBlocks += (res['inserted'] as num).toInt();
      conflicts = [...conflicts, ...(res['conflicts'] as List).cast<int>()];
    }
    // Blok yang hash-nya berbeda dengan server (bukan hanya yang baru dikirim).
    final diff = diffChains(local, remoteBlocks);
    conflicts = {...conflicts, ...diff.mismatched}.toList()..sort();

    return SyncResult(
      pushedTasks: dirtyTasks.length,
      pushedSessions: dirtySessions.length,
      pushedBlocks: pushedBlocks,
      pulledTasks: pulledTasks,
      pulledSessions: pulledSessions,
      pulledBlocks: pulledBlocks,
      chainConflicts: conflicts,
      staleAlarmTaskIds: staleAlarms,
    );
  }

  /// Membandingkan rantai lokal dengan salinan server (untuk tombol "Cek ke server").
  Future<ChainCheck> compareChain(List<Block> local) async {
    final token = await _storage.readToken();
    if (token == null) throw const SyncException('SESSION_INVALID');
    final server = _rows(
      await _rpc('app_sync_pull_blocks', {'p_token': token}),
    ).map(Block.fromJson).toList();
    return diffChains(local, server);
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

class SyncState {
  const SyncState({this.syncing = false, this.lastSyncAt, this.error, this.last});

  final bool syncing;
  final DateTime? lastSyncAt;
  final String? error;
  final SyncResult? last;
}

/// Pesan galat yang mudah dibaca dari kode server / jaringan.
String describeSyncError(Object e) {
  final m = e is SyncException ? e.message : e.toString();
  return switch (m) {
    'OFFLINE' => 'Tidak bisa terhubung ke server. Data tetap aman di HP.',
    'SESSION_INVALID' => 'Sesi login kedaluwarsa. Keluar lalu masuk lagi.',
    'CHAIN_BREAK' => 'Server menolak blok: rantai tidak tersambung.',
    'BLOCK_HASH_INVALID' => 'Server menolak blok: hash tidak cocok dengan isinya.',
    'BLOCK_INVALID' => 'Server menolak blok: format tidak valid.',
    _ => 'Sinkronisasi gagal: $m',
  };
}

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    ref.watch(currentUserIdProvider); // reset saat akun berganti
    return const SyncState();
  }

  /// Aman dipanggil kapan saja; panggilan saat sedang berjalan diabaikan.
  Future<void> sync() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || state.syncing) return;
    state = SyncState(syncing: true, lastSyncAt: state.lastSyncAt, last: state.last);
    try {
      final r = await ref.read(syncServiceProvider).run(uid);
      if (ref.read(currentUserIdProvider) != uid) return; // akun berganti saat sinkron
      if (r.pulledTasks > 0 || r.pulledSessions > 0 || r.pulledBlocks > 0) {
        ref.invalidate(tasksProvider);
        ref.invalidate(sessionProvider);
        ref.invalidate(chainProvider);
        if (r.staleAlarmTaskIds.isNotEmpty) {
          try {
            final svc = ref.read(notificationServiceProvider);
            await svc.init();
            for (final id in r.staleAlarmTaskIds) {
              await svc.cancel(taskAlarmId(id));
            }
          } catch (_) {}
        }
        if (r.pulledTasks > 0) {
          await ref
              .read(tasksProvider.notifier)
              .resyncAlarms(ref.read(tasksProvider));
        }
      }
      state = SyncState(
        lastSyncAt: DateTime.now(),
        last: r,
        error: r.chainConflicts.isEmpty
            ? null
            : 'Blok #${r.chainConflicts.join(', #')} berbeda dengan server.',
      );
    } catch (e) {
      debugPrint('Sync gagal: $e');
      state = SyncState(
        lastSyncAt: state.lastSyncAt,
        last: state.last,
        error: describeSyncError(e),
      );
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);