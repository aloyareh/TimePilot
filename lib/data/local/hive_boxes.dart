import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../hive_registrar.g.dart';
import 'models/client.dart';
import 'models/profile.dart';
import 'models/task.dart';
import 'models/work_session.dart';

class HiveBoxes {
  static const profile = 'profile';
  static const clients = 'clients';
  static const tasks = 'tasks';
  static const sessions = 'sessions';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapters(); // dari hive_registrar.g.dart
    await Hive.openBox<Profile>(profile);
    await Hive.openBox<Client>(clients);
    await Hive.openBox<Task>(tasks);
    await Hive.openBox<WorkSession>(sessions);
  }
}