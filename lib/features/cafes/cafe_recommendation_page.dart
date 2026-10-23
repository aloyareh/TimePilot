import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'cafe_llm_service.dart';
import 'cafe_map.dart';
import 'cafe_providers.dart';
import 'location_service.dart';

/// Rekomendasi kafe/coworking terdekat (PBI-25): GPS + Gemini.
class CafeRecommendationPage extends ConsumerStatefulWidget {
  const CafeRecommendationPage({super.key});

  @override
  ConsumerState<CafeRecommendationPage> createState() =>
      _CafeRecommendationPageState();
}

class _CafeRecommendationPageState
    extends ConsumerState<CafeRecommendationPage> {
  /// Indeks tempat yang sedang dipilih (marker di peta dan kartu di daftar).
  int? _selected;

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

  /// Rincian satu tempat yang dipilih dari peta atau daftar.
  Widget _detail(BuildContext context, CafeResult result, Cafe c) {
    final theme = Theme.of(context);
    final cowork = c.type.toLowerCase().contains('cowork');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _selected = null),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Lihat semua tempat'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      cowork
                          ? Icons.business_center_outlined
                          : Icons.local_cafe_outlined,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${c.type}${c.area.isEmpty ? '' : ' • ${c.area}'}'),
                const Divider(height: 24),
                if (result.aiPending)
                  const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Menyiapkan saran…'),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.note.isNotEmpty
                              ? c.note
                              : 'Belum ada informasi tambahan untuk tempat ini. '
                                    'Cek langsung di lokasi.',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openMaps(context, c),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Buka di Google Maps'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                setState(() => _selected = null);
                notifier.fetch();
              },
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
                : 'Gagal memuat tempat di sekitarmu. Periksa koneksi internet lalu coba lagi.';
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
                    'berdasarkan lokasi GPS, lengkap dengan saran dari AI.',
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
                    'Belum ada kafe atau coworking yang tercatat dalam radius 1,5 km dari lokasimu.',
                actions: [
                  FilledButton(
                    onPressed: notifier.fetch,
                    child: const Text('Coba lagi'),
                  ),
                ],
              );
            }
            final sel = _selected != null && _selected! < result.cafes.length
                ? _selected
                : null;
            final mapHeight = (MediaQuery.sizeOf(context).height * 0.32)
                .clamp(220.0, 320.0);
            return Column(
              children: [
                SizedBox(
                  height: mapHeight,
                  child: CafeMap(
                    userLat: result.latitude,
                    userLon: result.longitude,
                    cafes: result.cafes,
                    selected: sel,
                    onSelect: (i) => setState(() => _selected = i),
                    onClear: () => setState(() => _selected = null),
                  ),
                ),
                Expanded(
                  child: sel != null
                      ? _detail(context, result, result.cafes[sel])
                      : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: result.cafes.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (result.aiSummary.isNotEmpty)
                              Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.auto_awesome,
                                    color: AppColors.orange,
                                  ),
                                  title: const Text(
                                    'Saran AI',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(result.aiSummary),
                                ),
                              ),
                            if (result.aiPending)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Menyiapkan saran…'),
                                  ],
                                ),
                              )
                            else if (result.aiSummary.isEmpty && result.aiError != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Saran belum tersedia saat ini.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Text(
                                'Cek ulang di Google Maps sebelum berangkat.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        );
                      }
                      final c = result.cafes[i - 1];
                      final isSel = sel == i - 1;
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSel
                              ? const BorderSide(color: AppColors.navy, width: 2)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          onTap: () => setState(() => _selected = i - 1),
                          isThreeLine: c.note.isNotEmpty,
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
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}