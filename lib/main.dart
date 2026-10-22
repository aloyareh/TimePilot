import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:time_pilot/data/local/hive_boxes.dart';

import 'core/env.dart';
import 'core/navigation.dart';
import 'core/navigation/main_shell.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/profile/persona_gate.dart';
import 'features/profile/profile_providers.dart';
import 'features/tasks/task_providers.dart';
import 'features/session/task_session_page.dart';

import 'data/local/models/profile.dart';
import 'features/challenges/balance_challenge_page.dart';
import 'features/challenges/shake_challenge_page.dart';
import 'features/session/challenge_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  challengeBuilders[ChallengeType.shake] = (context, difficulty) =>
      ShakeChallengePage(difficulty: difficulty);
  challengeBuilders[ChallengeType.balance] = (context, difficulty) =>
      BalanceChallengePage(difficulty: difficulty);
  runApp(const ProviderScope(child: MainApp()));
}


class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  /// Tujuan dari ketukan notifikasi yang menunggu sampai user sudah masuk.
  String? _pendingTaskId;

  /// Selesai saat NotificationService siap. Pendengar akun menunggu ini supaya
  /// init() pertama selalu membawa handler ketukan notifikasi.
  late final Future<void> _notifReady;

  @override
  void initState() {
    super.initState();
    _notifReady = ref
        .read(notificationServiceProvider)
        .init(onSelect: _openTask)
        .catchError((Object _) {});
    // Saat login selesai (mis. lewat biometrik), buka tujuan yang tertunda.
    ref.listenManual(authControllerProvider, (_, next) {
      if (next.value != null) _flushPending();
    });
    // Alarm milik satu akun tidak boleh berbunyi saat akun lain / tidak ada
    // yang login: batal semua saat keluar, jadwalkan ulang milik akun yang masuk.
    ref.listenManual<String?>(
      currentUserIdProvider,
      (prev, next) {
        _onUserChanged(prev, next);
      },
      fireImmediately: true,
    );
    _handleLaunch();
  }

  Future<void> _onUserChanged(String? prev, String? next) async {
    await _notifReady;
    final svc = ref.read(notificationServiceProvider);
    if (next == null) {
      if (prev != null) {
        try {
          await svc.cancelAll();
        } catch (_) {}
      }
      return;
    }
    final tasks = ref.read(tasksProvider);
    await ref.read(tasksProvider.notifier).resyncAlarms(tasks);
  }

  Future<void> _handleLaunch() async {
    await _notifReady;
    final launched = await ref
        .read(notificationServiceProvider)
        .launchPayload(); // app dibuka dari notifikasi
    if (launched != null) await _openTask(launched);
  }

  /// Ketukan notifikasi: simpan tujuannya, buka segera jika sudah masuk,
  /// kalau belum, tunggu sampai login selesai.
  Future<void> _openTask(String? taskId) async {
    if (taskId == null) return;
    _pendingTaskId = taskId;
    try {
      await ref.read(authControllerProvider.future);
    } catch (_) {}
    _flushPending();
  }

  void _flushPending() {
    final id = _pendingTaskId;
    if (id == null) return;
    if (ref.read(authControllerProvider).value == null) return; // belum masuk
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      // Navigator belum siap (cold start): coba lagi setelah frame berikutnya.
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPending());
      return;
    }
    _pendingTaskId = null;
    nav.push(
      MaterialPageRoute<void>(builder: (_) => TaskSessionPage(taskId: id, autoStart: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(child: PersonaGate(child: MainShell())),
    );
  }
}