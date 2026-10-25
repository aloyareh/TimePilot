import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_providers.dart';
import '../sync/sync_service.dart';
import 'anchor_section.dart';
import 'anchor_service.dart';
import 'chain.dart';
import 'chain_repository.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _fmt(DateTime t) =>
    '${_two(t.day)}/${_two(t.month)}/${t.year} ${_two(t.hour)}:${_two(t.minute)}';

String _dateTime(int timestampMs) =>
    _fmt(DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true).toLocal());

String _duration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h == 0 ? '$m menit' : '$h jam $m menit';
}

String _short(String h) => h.length <= 12
    ? h
    : '${h.substring(0, 6)}…${h.substring(h.length - 4)}';

enum _Level { safe, waiting, broken }

class BlockchainPage extends ConsumerStatefulWidget {
  const BlockchainPage({super.key});

  @override
  ConsumerState<BlockchainPage> createState() => _BlockchainPageState();
}

class _BlockchainPageState extends ConsumerState<BlockchainPage> {
  static const _previewCount = 5;
  static const _wide = Size(0, 52);

  List<Anchor>? _anchors;
  bool _loadFailed = false;
  bool _busy = false;
  bool _checking = false;
  bool _showAll = false;
  String? _message; // hasil mengunci
  String? _checkText;
  bool? _checkOk; // null = netral

  Anchor? get _latest =>
      (_anchors == null || _anchors!.isEmpty) ? null : _anchors!.first;

  @override
  void initState() {
    super.initState();
    _loadAnchors();
  }

  Future<void> _loadAnchors() async {
    try {
      final list = await ref.read(anchorServiceProvider).list();
      if (!mounted) return;
      setState(() {
        _anchors = list;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _lockNow() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String msg;
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        try {
          await ref
              .read(syncServiceProvider)
              .run(uid)
              .timeout(const Duration(seconds: 30));
        } catch (e) {
          throw AnchorException('Sinkronisasi gagal: ${describeSyncError(e)}');
        }
      }
      await ref
          .read(anchorServiceProvider)
          .anchorNow()
          .timeout(const Duration(seconds: 45));
      msg = 'Terkirim. Pengunciannya selesai dalam sekitar setengah menit.';
      await _loadAnchors();
    } on AnchorException catch (e) {
      msg = e.code.startsWith('Sinkronisasi') ? e.code : e.message;
    } catch (_) {
      msg = 'Permintaan terlalu lama. Cek koneksi lalu coba lagi.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = msg;
    });
  }

  Future<void> _check(List<Block> blocks) async {
    setState(() {
      _checking = true;
      _checkText = null;
      _checkOk = null;
    });
    String text;
    bool? ok;
    final bad = firstInvalidIndex(blocks);
    if (bad != null) {
      text =
          'Ada catatan yang tidak cocok, mulai sesi ke-${bad + 1}. Data di HP '
          'ini sudah berubah dari aslinya.';
      ok = false;
    } else if (_latest == null) {
      text = 'Belum ada catatan yang dikunci. Tekan "Kunci sekarang" dulu.';
    } else {
      final a = _latest!;
      try {
        final check = await ref.read(anchorServiceProvider).verifyOnChain(a);
        final local = localChainMatchesAnchor(a, blocks);
        switch (check.status) {
          case AnchorStatus.confirmed:
            ok = local;
            text = local
                ? 'Aman. Catatan ${a.uptoIdx + 1} sesi kerja pertamamu sama '
                      'persis dengan yang terkunci di blockchain.'
                : 'Tidak cocok. Catatan di HP berbeda dari yang terkunci di '
                      'blockchain.';
          case AnchorStatus.pending:
            text = 'Pengunciannya masih diproses jaringan. Coba lagi sebentar lagi.';
          case AnchorStatus.notFound:
            text = 'Belum ditemukan di jaringan. Tunggu sebentar lalu coba lagi.';
          case AnchorStatus.mismatch:
            ok = false;
            text = 'Isi yang terkunci di blockchain berbeda dari catatanmu.';
        }
      } on AnchorException catch (e) {
        text = e.message;
      } catch (_) {
        text = 'Pemeriksaan gagal. Coba lagi.';
      }
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checkText = text;
      _checkOk = ok;
    });
  }

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bagaimana cara kerjanya?'),
        content: const Text(
          'Setiap sesi kerja yang selesai dicatat. Ringkasan catatan itu lalu '
          'dikunci di blockchain publik (Ethereum Sepolia), sehingga jam kerja '
          'dan nilai tagihanmu tidak bisa diubah diam-diam setelahnya. '
          'Klienmu juga bisa memeriksanya sendiri.\n\n'
          'Pengunciannya otomatis saat HP terhubung internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTech(List<Block> blocks) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (ctx, controller) => _TechSheet(
          controller: controller,
          blocks: blocks,
        ),
      ),
    );
    if (mounted) _loadAnchors();
  }

  void _showSession(Block b, bool locked) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detail sesi', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s12),
              _detailRow(theme, 'Waktu selesai', _dateTime(b.timestampMs)),
              _detailRow(theme, 'Lama kerja', _duration(b.durationSeconds)),
              _detailRow(theme, 'Terlambat', '${b.lateMinutes} menit'),
              _detailRow(
                theme,
                'Pendapatan bersih',
                formatMoney(b.netMinor / 100, b.currency),
              ),
              _detailRow(
                theme,
                'Status',
                locked ? 'Terkunci di blockchain' : 'Menunggu dikunci',
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Kode catatan: ${_short(b.hash)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    ),
  );

  BoxDecoration get _card => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.r24),
    boxShadow: AppShadows.soft,
  );

  Widget _statusCard(ThemeData theme, List<Block> blocks) {
    final bad = firstInvalidIndex(blocks);
    final covered = _latest?.uptoIdx ?? -1;
    final pending = blocks.length - 1 - covered;
    final _Level level = bad != null
        ? _Level.broken
        : (_anchors != null && pending <= 0 ? _Level.safe : _Level.waiting);

    final lastLocked = _latest == null ? '' : '\nTerakhir dikunci ${_fmt(_latest!.createdAt)}';
    final (IconData icon, Color color, String title, String body) = switch (level) {
      _Level.safe => (
        Icons.verified_user_outlined,
        AppColors.success,
        'Catatan kerjamu aman',
        'Semua ${blocks.length} sesi kerja sudah dikunci di blockchain dan tidak '
            'bisa diubah diam-diam.$lastLocked',
      ),
      _Level.waiting when _anchors == null && _loadFailed => (
        Icons.cloud_off_outlined,
        AppColors.navInactive,
        'Status belum bisa dimuat',
        'Periksa koneksi internet, lalu tarik layar ke bawah untuk memuat ulang.',
      ),
      _Level.waiting => (
        Icons.hourglass_top_rounded,
        AppColors.orange,
        _anchors == null
            ? 'Memeriksa\u2026'
            : '${pending > 0 ? pending : 0} sesi menunggu dikunci',
        'Pengunciannya otomatis saat HP terhubung internet. Kamu juga bisa '
            'menguncinya sekarang.',
      ),
      _Level.broken => (
        Icons.gpp_maybe_outlined,
        AppColors.error,
        'Ada catatan yang berubah',
        'Data sesi di HP ini berbeda dari aslinya, mulai sesi ke-${(bad ?? 0) + 1}.',
      ),
    };
    final canLock = level == _Level.waiting && _anchors != null && pending > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: _card,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.s24),
          if (canLock)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: _wide),
                onPressed: _busy ? null : _lockNow,
                child: Text(_busy ? 'Mengunci…' : 'Kunci sekarang'),
              ),
            ),
          if (canLock) const SizedBox(height: AppSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: canLock
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: _wide),
                    onPressed: _checking ? null : () => _check(blocks),
                    child: Text(_checking ? 'Memeriksa…' : 'Periksa keaslian'),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(minimumSize: _wide),
                    onPressed: _checking ? null : () => _check(blocks),
                    child: Text(_checking ? 'Memeriksa…' : 'Periksa keaslian'),
                  ),
          ),
          if (_message != null) _resultBox(theme, _message!, null),
          if (_checkText != null) _resultBox(theme, _checkText!, _checkOk),
        ],
      ),
    );
  }

  Widget _resultBox(ThemeData theme, String text, bool? ok) {
    final color = ok == null
        ? AppColors.navInactive
        : (ok ? AppColors.success : AppColors.error);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        child: Text(text, style: theme.textTheme.bodySmall),
      ),
    );
  }

  Widget _sessionRow(ThemeData theme, Block b, int covered) {
    final locked = b.index <= covered;
    return InkWell(
      onTap: () => _showSession(b, locked),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          children: [
            Icon(
              locked ? Icons.lock_outline : Icons.schedule,
              size: 20,
              color: locked ? AppColors.success : AppColors.navInactive,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMoney(b.netMinor / 100, b.currency),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '${_dateTime(b.timestampMs)} · ${_duration(b.durationSeconds)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.navInactive),
          ],
        ),
      ),
    );
  }

  Widget _history(ThemeData theme, List<Block> blocks) {
    final covered = _latest?.uptoIdx ?? -1;
    final all = blocks.reversed.toList();
    final shown = _showAll ? all : all.take(_previewCount).toList();
    return Container(
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s4,
            ),
            child: Text('Riwayat sesi', style: theme.textTheme.titleMedium),
          ),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: AppSpacing.s16, endIndent: AppSpacing.s16),
            _sessionRow(theme, shown[i], covered),
          ],
          if (all.length > _previewCount)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll ? 'Tampilkan lebih sedikit' : 'Lihat semua (${all.length})',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chainProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bukti sesi kerja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Cara kerja',
            onPressed: _showInfo,
          ),
        ],
      ),
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
                      'Belum ada sesi kerja.\nSetiap sesi yang selesai dicatat dan dikunci di sini.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _loadAnchors,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                _statusCard(theme, blocks),
                const SizedBox(height: AppSpacing.s16),
                _history(theme, blocks),
                const SizedBox(height: AppSpacing.s8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showTech(blocks),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Detail teknis'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Alat untuk yang ingin tahu detailnya: jangkar blockchain, verifikasi rantai,
/// demo manipulasi, dan perbandingan dengan server.
class _TechSheet extends ConsumerStatefulWidget {
  const _TechSheet({required this.controller, required this.blocks});

  final ScrollController controller;
  final List<Block> blocks;

  @override
  ConsumerState<_TechSheet> createState() => _TechSheetState();
}

class _TechSheetState extends ConsumerState<_TechSheet> {
  static final _outlined = OutlinedButton.styleFrom(minimumSize: const Size(0, 48));

  String? _note;
  bool _serverBusy = false;

  void _verifyLocal() {
    final bad = firstInvalidIndex(widget.blocks);
    setState(
      () => _note = bad == null
          ? 'Rantai valid: ${widget.blocks.length} blok saling terhubung dan hash-nya cocok.'
          : 'Rantai RUSAK mulai blok #$bad.',
    );
  }

  void _demoTamper() {
    final blocks = widget.blocks;
    final copy = [...blocks];
    copy[0] = blocks[0].tampered(durationSeconds: blocks[0].durationSeconds + 600);
    final bad = firstInvalidIndex(copy);
    setState(
      () => _note = bad == null
          ? 'Demo: manipulasi tidak terdeteksi (seharusnya tidak mungkin).'
          : 'Demo: durasi blok #0 diubah +10 menit di memori. Verifikasi menemukan '
                'blok #$bad rusak. Data asli tidak berubah.',
    );
  }

  Future<void> _checkServer() async {
    setState(() {
      _serverBusy = true;
      _note = null;
    });
    String note;
    try {
      final c = await ref.read(syncServiceProvider).compareChain(widget.blocks);
      if (c.consistent) {
        note = 'Cocok dengan server: ${c.serverCount} blok identik.';
      } else {
        final parts = <String>[];
        if (c.mismatched.isNotEmpty) {
          parts.add('hash berbeda di blok #${c.mismatched.join(', #')}');
        }
        if (c.serverOnly.isNotEmpty) {
          parts.add('blok #${c.serverOnly.join(', #')} hilang di HP');
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
      _note = note;
      _serverBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        Text('Detail teknis', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s16),
        AnchorSection(blocks: widget.blocks),
        const SizedBox(height: AppSpacing.s16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.r24),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alat uji', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: _outlined,
                  onPressed: _verifyLocal,
                  child: const Text('Verifikasi rantai'),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: _outlined,
                  onPressed: _demoTamper,
                  child: const Text('Demo manipulasi'),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: _outlined,
                  onPressed: _serverBusy ? null : _checkServer,
                  child: Text(_serverBusy ? 'Memeriksa…' : 'Cek ke server'),
                ),
              ),
              if (_note != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                    child: Text(_note!, style: theme.textTheme.bodySmall),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}