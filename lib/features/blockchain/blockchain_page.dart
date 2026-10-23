import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import 'chain.dart';
import '../sync/sync_service.dart';
import 'chain_repository.dart';

String _short(String h) => h.length <= 12
    ? h
    : '${h.substring(0, 6)}\u2026${h.substring(h.length - 4)}';

class BlockchainPage extends ConsumerStatefulWidget {
  const BlockchainPage({super.key});

  @override
  ConsumerState<BlockchainPage> createState() => _BlockchainPageState();
}

class _BlockchainPageState extends ConsumerState<BlockchainPage> {
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
          parts.add(
            'hash berbeda di blok #${c.mismatched.join(', #')} (kemungkinan dimanipulasi)',
          );
        }
        if (c.serverOnly.isNotEmpty) {
          parts.add(
            'blok #${c.serverOnly.join(', #')} ada di server tapi hilang di HP',
          );
        }
        if (c.missingOnServer.isNotEmpty) {
          parts.add(
            'blok #${c.missingOnServer.join(', #')} belum terkirim ke server',
          );
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

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.r24),
    boxShadow: AppShadows.soft,
  );

  Widget _statusChip(ThemeData theme) {
    final Color color;
    final IconData icon;
    final String text;
    if (_checked == null) {
      color = AppColors.navInactive;
      icon = Icons.help_outline;
      text = 'Belum diverifikasi';
    } else if (_checked!) {
      color = AppColors.success;
      icon = Icons.verified_outlined;
      text = 'Rantai valid';
    } else {
      color = AppColors.error;
      icon = Icons.gpp_bad_outlined;
      text = 'Rantai RUSAK mulai blok #$_badIndex';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        child: Text(text, style: theme.textTheme.bodySmall),
      ),
    );
  }

  Widget _summary(ThemeData theme, List<Block> blocks) {
    const compact = Size(0, 48);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: const Icon(Icons.link, color: AppColors.blue, size: 22),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text('${blocks.length} blok', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Align(alignment: Alignment.centerLeft, child: _statusChip(theme)),
          if (_demoNote != null) _note(theme, _demoNote!),
          if (_serverNote != null) _note(theme, _serverNote!),
          const SizedBox(height: AppSpacing.s16),
          FilledButton(
            onPressed: () => _verify(blocks),
            child: const Text('Verifikasi'),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: compact),
                  onPressed: () => _demoTamper(blocks),
                  child: const Text('Demo manipulasi'),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: compact),
                  onPressed: _serverBusy ? null : () => _checkServer(blocks),
                  child: Text(
                    _serverBusy ? 'Memeriksa\u2026' : 'Cek ke server',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _blockTile(ThemeData theme, Block b) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          title: Text('Blok #${b.index}', style: theme.textTheme.titleSmall),
          subtitle: Text(
            '${_short(b.hash)} \u00B7 ${formatMoney(b.netMinor / 100, b.currency)}',
            style: theme.textTheme.bodySmall,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            0,
            AppSpacing.s16,
            AppSpacing.s16,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Hash: ${b.hash}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.s4),
            SelectableText(
              'Hash sebelumnya: ${b.prevHash}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Waktu: ${DateTime.fromMillisecondsSinceEpoch(b.timestampMs, isUtc: true).toIso8601String()}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Durasi: ${b.durationSeconds} detik',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Terlambat: ${b.lateMinutes} menit',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Bersih: ${formatMoney(b.netMinor / 100, b.currency)}',
              style: theme.textTheme.bodySmall,
            ),
            Text('Sesi: ${b.sessionId}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_off,
                      size: 56,
                      color: AppColors.navInactive,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      'Belum ada blok. Setiap sesi kerja yang selesai dicatat di sini.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          final shown = blocks.reversed.toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              _summary(theme, blocks),
              const SizedBox(height: AppSpacing.s16),
              for (final b in shown) _blockTile(theme, b),
            ],
          );
        },
      ),
    );
  }
}
