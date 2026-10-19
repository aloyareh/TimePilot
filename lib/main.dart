import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:time_pilot/data/local/hive_boxes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/env.dart';
import 'data/repositories/auth_repository.dart';

// import 'package:time_pilot/core/theme/app_theme.dart'; // sesuaikan dengan file tema PBI-01

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
    
  );
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      // theme: AppTheme.light,
      home: Scaffold(body: Center(child: Text('Time Pilot'))),
    );
  }
}
