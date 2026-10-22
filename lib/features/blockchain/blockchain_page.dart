import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import 'chain.dart';
import '../sync/sync_service.dart';
import 'chain_repository.dart';

String _short(String h) => h.length <= 12 ? h : '${h.substring(0, 6)}…${h.substring(h.length - 4)}';

class BlockchainPage extends ConsumerStatefulWidget {
  const BlockchainPage({super.key});

  @override
  ConsumerState<BlockchainPage> createState() => _BlockchainPageState();
}

class _BlockchainPageState extends ConsumerState<BlockchainPage> {
  /// Hasil verifikasi terakhir; null = belum diperiksa.
  bool? _checked;
  int? _badIndex;
  String? _demoNote;
  String? _serverNote;
  bool _serverBusy = false;

  void _verify(List<Block> blocks) {
    final bad = firstInvalidIndex(blocks);
    setState(() {
      _checked = bad == null;
      _badIndex = bad;
      _demoNote = null;
    });
  }

  /// Demo untuk presentasi: mengubah satu blok DI MEMORI (data asli tidak disentuh)
  /// lalu memverifikasi, supaya terlihat rantai terdeteksi rusak.
  void _demoTamper(List<Block> blocks) {
    if (blocks.isEmpty) return;
    const target = 0;
    final copy = [...blocks];
    copy[target] = blocks[target].tampered(
      durationSeconds: blocks[target].durationSeconds + 600,
    );
    final bad = firstInvalidIndex(copy);
    setState(() {
      _demoNote = bad == null
          ? 'Demo: manipulasi tidak terdeteksi (seharusnya tidak mungkin).'
          : 'Demo: durasi blok #$target diubah +10 menit di memori. '
              'Verifikasi menemukan blok #$bad rusak. Data asli tidak berubah.';
    });
  }

  /// Membandingkan hash tiap blok dengan salinan di server (jangkar manipulasi).
  Future<void> _checkServer(List<Block> blocks) async {
    setState(() {
      _serverBusy = true;
      _serverNote = null;
    });
    String note;
    try {
      final c = await ref.read(syncServiceProvider).compareChain(blocks);
      if (c.consistent) {
        note = 'Cocok dengan server: ${c.serverCount} blok identik.';
      } else {
        final parts = <String>[];
        if (c.mismatched.isNotEmpty) {
          parts.add('hash berbeda di blok #${c.mismatched.join(', #')} (kemungkinan dimanipulasi)');
        }
        if (c.serverOnly.isNotEmpty) {
          parts.add('blok #${c.serverOnly.join(', #')} ada di server tapi hilang di HP');
        }
        if (c.missingOnServer.isNotEmpty) {
          parts.add('blok #${c.missingOnServer.join(', #')} belum terkirim ke server');
        }
        note = 'Tidak cocok dengan server: ${parts.join('; ')}.';
      }
    } catch (e) {
      note = describeSyncError(e);
    }
    if (!mounted) return;
    setState(() {
      _serverNote = note;
      _serverBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chainProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Blockchain sesi')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (blocks) {
          if (blocks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada blok. Setiap sesi kerja yang selesai dicatat di sini.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final shown = blocks.reversed.toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${blocks.length} blok'),
                      const SizedBox(height: 8),
                      if (_checked == null)
                        const Text('Belum diverifikasi.')
                      else if (_checked!)
                        Text(
                          'Rantai valid.',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          'Rantai RUSAK mulai blok #$_badIndex.',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (_demoNote != null) ...[
                        const SizedBox(height: 8),
                        Text(_demoNote!),
                      ],
                      if (_serverNote != null) ...[
                        const SizedBox(height: 8),
                        Text(_serverNote!),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () => _verify(blocks),
                            child: const Text('Verifikasi'),
                          ),
                          OutlinedButton(
                            onPressed: () => _demoTamper(blocks),
                            child: const Text('Demo manipulasi'),
                          ),
                          OutlinedButton(
                            onPressed: _serverBusy ? null : () => _checkServer(blocks),
                            child: Text(_serverBusy ? 'Memeriksa…' : 'Cek ke server'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              for (final b in shown)
                Card(
                  child: ExpansionTile(
                    title: Text('Blok #${b.index}'),
                    subtitle: Text(
                      '${_short(b.hash)} · ${formatMoney(b.netMinor / 100, b.currency)}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText('Hash: ${b.hash}'),
                      SelectableText('Hash sebelumnya: ${b.prevHash}'),
                      Text(
                        'Waktu: ${DateTime.fromMillisecondsSinceEpoch(b.timestampMs, isUtc: true).toIso8601String()}',
                      ),
                      Text('Durasi: ${b.durationSeconds} detik'),
                      Text('Terlambat: ${b.lateMinutes} menit'),
                      Text('Bersih: ${formatMoney(b.netMinor / 100, b.currency)}'),
                      Text('Sesi: ${b.sessionId}'),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}