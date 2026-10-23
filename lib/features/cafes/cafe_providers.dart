import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cafe_llm_service.dart';
import 'location_service.dart';
import 'nearby_places_service.dart';

class CafeResult {
  const CafeResult({
    required this.latitude,
    required this.longitude,
    required this.cafes,
    this.aiError,
    this.aiPending = false,
    this.aiSummary = '',
  });

  final double latitude;
  final double longitude;
  final List<Cafe> cafes;

  /// Terisi bila AI gagal menambah catatan; daftar tempat dari peta tetap valid.
  final String? aiError;

  /// AI masih menulis catatan; daftar sudah bisa dipakai.
  final bool aiPending;

  /// Rekomendasi singkat dari AI (kosong bila belum/tidak ada).
  final String aiSummary;
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final nearbyPlacesServiceProvider = Provider<NearbyPlacesService>(
  (ref) => NearbyPlacesService(),
);

final cafeLlmServiceProvider = Provider<CafeLlmService>(
  (ref) => CafeLlmService(),
);

/// null = belum pernah dicari. Pencarian dipicu manual lewat [fetch].
class CafeRecommendationNotifier extends AsyncNotifier<CafeResult?> {
  @override
  Future<CafeResult?> build() async => null;

  int _run = 0;

  Future<void> fetch() async {
    final run = ++_run;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final pos = await ref.read(locationServiceProvider).currentPosition();
      final cafes = await ref
          .read(nearbyPlacesServiceProvider)
          .search(latitude: pos.latitude, longitude: pos.longitude);
      return CafeResult(
        latitude: pos.latitude,
        longitude: pos.longitude,
        cafes: cafes,
        aiPending: cafes.isNotEmpty,
      );
    });

    // Daftar dari peta sudah tampil; catatan AI menyusul tanpa menahan layar.
    final base = state.value;
    if (base == null || !base.aiPending) return;
    CafeResult done;
    try {
      final ai = await ref.read(cafeLlmServiceProvider).annotate(base.cafes);
      final notes = ai.notes;
      done = CafeResult(
        latitude: base.latitude,
        longitude: base.longitude,
        aiSummary: ai.summary,
        cafes: [
          for (var i = 0; i < base.cafes.length; i++)
            notes[i].isEmpty
                ? base.cafes[i]
                : base.cafes[i].withNote(
                    [notes[i], if (base.cafes[i].note.isNotEmpty) base.cafes[i].note]
                        .join('\n'),
                  ),
        ],
      );
    } catch (e) {
      done = CafeResult(
        latitude: base.latitude,
        longitude: base.longitude,
        cafes: base.cafes,
        aiError: e.toString(),
      );
    }
    // Abaikan bila pengguna sudah memulai pencarian baru.
    if (run == _run && ref.mounted) state = AsyncData(done);
  }
}

final cafeRecommendationProvider =
    AsyncNotifierProvider<CafeRecommendationNotifier, CafeResult?>(
      CafeRecommendationNotifier.new,
    );