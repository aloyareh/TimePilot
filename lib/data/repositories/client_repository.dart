import 'package:hive_ce_flutter/hive_flutter.dart';

import '../local/hive_boxes.dart';
import '../local/models/client.dart';

class ClientRepository {
  Box<Client> get _box => Hive.box<Client>(HiveBoxes.clients);

  Future<void> save(Client client) => _box.put(client.id, client);

  Client? getById(String id) {
    final client = _box.get(id);
    if (client == null || client.isDeleted) return null;
    return client;
  }

  /// Hanya klien milik [ownerId] yang belum dihapus.
  List<Client> getAll(String ownerId) =>
      _box.values.where((c) => !c.isDeleted && c.ownerId == ownerId).toList();

  Future<void> delete(String id) async {
    final c = _box.get(id);
    if (c == null) return;
    await _box.put(
      id,
      Client(
        id: c.id,
        name: c.name,
        timezoneId: c.timezoneId,
        hourlyRate: c.hourlyRate,
        currency: c.currency,
        updatedAt: DateTime.now().toUtc(),
        isDeleted: true,
        ownerId: c.ownerId,
      ),
    );
  }
}
