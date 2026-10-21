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
import 'features/session/task_session_page.dart';

import 'data/local/models/profile.dart';
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

  challengeBuilders[ChallengeType.shake] =
    (context, difficulty) => ShakeChallengePage(difficulty: difficulty);

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

  @override
  void initState() {
    super.initState();
    // Saat login selesai (mis. lewat biometrik), buka tujuan yang tertunda.
    ref.listenManual(authControllerProvider, (_, next) {
      if (next.value != null) _flushPending();
    });
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final svc = ref.read(notificationServiceProvider);
    await svc.init(onSelect: _openTask);
    final launched = await svc.launchPayload(); // app dibuka dari notifikasi
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
      MaterialPageRoute<void>(builder: (_) => TaskSessionPage(taskId: id)),
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