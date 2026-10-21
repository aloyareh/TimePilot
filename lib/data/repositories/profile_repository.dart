import 'package:hive_ce_flutter/hive_flutter.dart';

import '../local/hive_boxes.dart';
import '../local/models/profile.dart';

class ProfileRepository {
  Box<Profile> get _box => Hive.box<Profile>(HiveBoxes.profile);
  Future<void> save(Profile profile) => _box.put(profile.id, profile);
  Profile? getByUserId(String userId) => _box.get(userId);
  Future<void> clear() => _box.clear();
}