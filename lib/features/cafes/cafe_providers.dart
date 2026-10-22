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
  });

  final double latitude;
  final double longitude;
  final List<Cafe> cafes;

  /// Terisi bila AI gagal menambah catatan; daftar tempat dari peta tetap valid.
  final String? aiError;
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

  Future<void> fetch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final pos = await ref.read(locationServiceProvider).currentPosition();
      var cafes = await ref
          .read(nearbyPlacesServiceProvider)
          .search(latitude: pos.latitude, longitude: pos.longitude);

      String? aiError;
      if (cafes.isNotEmpty) {
        try {
          final notes = await ref.read(cafeLlmServiceProvider).annotate(cafes);
          cafes = [
            for (var i = 0; i < cafes.length; i++)
              notes[i].isEmpty
                  ? cafes[i]
                  : cafes[i].withNote(
                      [notes[i], if (cafes[i].note.isNotEmpty) cafes[i].note].join('\n'),
                    ),
          ];
        } catch (e) {
          aiError = e.toString();
        }
      }
      return CafeResult(
        latitude: pos.latitude,
        longitude: pos.longitude,
        cafes: cafes,
        aiError: aiError,
      );
    });
  }
}

final cafeRecommendationProvider =
    AsyncNotifierProvider<CafeRecommendationNotifier, CafeResult?>(
      CafeRecommendationNotifier.new,
    );