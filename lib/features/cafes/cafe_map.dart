import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import 'cafe_llm_service.dart';

/// Peta lokasi pengguna (titik biru) dan tempat-tempat rekomendasi (pin oranye).
/// Ketuk pin untuk memilih tempat; pin terpilih berwarna biru tua dan namanya
/// tampil di pojok bawah peta.
class CafeMap extends StatelessWidget {
  const CafeMap({
    super.key,
    required this.userLat,
    required this.userLon,
    required this.cafes,
    required this.selected,
    required this.onSelect,
    this.onClear,
  });

  final double userLat;
  final double userLon;
  final List<Cafe> cafes;
  final int? selected;
  final ValueChanged<int> onSelect;

  /// Dipanggil saat peta (bukan pin) diketuk.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final user = LatLng(userLat, userLon);
    final pins = <int, LatLng>{
      for (var i = 0; i < cafes.length; i++)
        if (cafes[i].latitude != null && cafes[i].longitude != null)
          i: LatLng(cafes[i].latitude!, cafes[i].longitude!),
    };
    final points = [user, ...pins.values];
    final sel = selected != null && selected! < cafes.length ? cafes[selected!] : null;

    return Stack(
      children: [
        FlutterMap(
          // Peta dibuat ulang (dan dipas ulang) tiap hasil pencarian berganti.
          key: ValueKey('$userLat,$userLon,${cafes.length}'),
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(48),
              maxZoom: 17,
            ),
            onTap: (_, _) => onClear?.call(),
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.time_pilot',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: user,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
                for (final e in pins.entries)
                  Marker(
                    point: e.value,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => onSelect(e.key),
                      child: Icon(
                        Icons.location_on,
                        size: selected == e.key ? 44 : 34,
                        color: selected == e.key
                            ? AppColors.navy
                            : AppColors.orange,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        if (sel != null)
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    sel.area.isEmpty ? sel.name : '${sel.name} • ${sel.area.split(' • ').first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}