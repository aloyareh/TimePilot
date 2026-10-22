import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cafe_llm_service.dart';
import 'location_service.dart';

class CafeResult {
  const CafeResult({
    required this.latitude,
    required this.longitude,
    required this.cafes,
  });

  final double latitude;
  final double longitude;
  final List<Cafe> cafes;
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
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
      final cafes = await ref
          .read(cafeLlmServiceProvider)
          .recommend(latitude: pos.latitude, longitude: pos.longitude);
      return CafeResult(
        latitude: pos.latitude,
        longitude: pos.longitude,
        cafes: cafes,
      );
    });
  }
}

final cafeRecommendationProvider =
    AsyncNotifierProvider<CafeRecommendationNotifier, CafeResult?>(
      CafeRecommendationNotifier.new,
    );
