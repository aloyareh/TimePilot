import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'cafe_llm_service.dart';
import 'cafe_providers.dart';
import 'location_service.dart';

/// Rekomendasi kafe/coworking terdekat (PBI-25): GPS + Gemini.
class CafeRecommendationPage extends ConsumerWidget {
  const CafeRecommendationPage({super.key});

  Future<void> _openMaps(BuildContext context, Cafe c) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${c.name} ${c.area}'.trim(),
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka Google Maps.')),
      );
    }
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required List<Widget> actions,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cafeRecommendationProvider);
    final notifier = ref.read(cafeRecommendationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tempat Kerja Terdekat'),
        actions: [
          if (state.value != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Cari ulang',
              onPressed: notifier.fetch,
            ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            final action = e is LocationException ? e.action : null;
            final msg = e is LocationException
                ? e.message
                : 'Gagal memuat rekomendasi. Periksa koneksi internet lalu coba lagi.\n($e)';
            return _message(
              context,
              icon: Icons.error_outline,
              color: AppColors.error,
              title: 'Tidak bisa mencari',
              body: msg,
              actions: [
                if (action != null)
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(locationServiceProvider).openSettings(action),
                    child: const Text('Buka pengaturan'),
                  ),
                FilledButton(
                  onPressed: notifier.fetch,
                  child: const Text('Coba lagi'),
                ),
              ],
            );
          },
          data: (result) {
            if (result == null) {
              return _message(
                context,
                icon: Icons.local_cafe_outlined,
                color: AppColors.orange,
                title: 'Cari tempat kerja',
                body:
                    'Temukan kafe atau coworking space di sekitarmu '
                    'berdasarkan lokasi GPS dan rekomendasi AI.',
                actions: [
                  FilledButton.icon(
                    onPressed: notifier.fetch,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Cari sekitar saya'),
                  ),
                ],
              );
            }
            if (result.cafes.isEmpty) {
              return _message(
                context,
                icon: Icons.search_off,
                color: AppColors.navInactive,
                title: 'Belum ada rekomendasi',
                body:
                    'AI belum menemukan tempat yang cocok di sekitar lokasimu.',
                actions: [
                  FilledButton(
                    onPressed: notifier.fetch,
                    child: const Text('Coba lagi'),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: result.cafes.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    'Perkiraan AI untuk '
                    '${result.latitude.toStringAsFixed(4)}, '
                    '${result.longitude.toStringAsFixed(4)}. '
                    'Cek ulang di Google Maps sebelum berangkat.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                final c = result.cafes[i - 1];
                return Card(
                  child: ListTile(
                    isThreeLine: true,
                    leading: Icon(
                      c.type.toLowerCase().contains('cowork')
                          ? Icons.business_center_outlined
                          : Icons.local_cafe_outlined,
                      color: AppColors.navy,
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        '${c.type}${c.area.isEmpty ? '' : ' • ${c.area}'}',
                        if (c.note.isNotEmpty) c.note,
                      ].join('\n'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.map_outlined),
                      tooltip: 'Buka di Google Maps',
                      onPressed: () => _openMaps(context, c),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
