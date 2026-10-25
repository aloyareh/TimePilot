import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../profile/profile_providers.dart';
import '../sync/sync_service.dart';
import 'anchor_service.dart';
import 'chain.dart';
import 'chain_config.dart';

final anchorServiceProvider = Provider<AnchorService>((ref) => AnchorService());

String _shortTx(String h) =>
    h.length <= 14 ? h : '${h.substring(0, 8)}…${h.substring(h.length - 6)}';

/// Kartu "Jangkar blockchain" untuk halaman Blockchain sesi: mencatat hash blok
/// terbaru ke blockchain publik dan memverifikasinya langsung dari node.
class AnchorSection extends ConsumerStatefulWidget {
  const AnchorSection({super.key, required this.blocks});

  final List<Block> blocks;

  @override
  ConsumerState<AnchorSection> createState() => _AnchorSectionState();
}

class _AnchorSectionState extends ConsumerState<AnchorSection> {
  // Tema aplikasi memberi tombol lebar minimum tak hingga; di sini tombol harus
  // bisa berdampingan dalam Row, jadi lebar minimumnya dinolkan.
  static final _filledStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 48),
  );
  static final _outlinedStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
  );
  static final _textStyle = TextButton.styleFrom(minimumSize: const Size(0, 40));

  List<Anchor>? _anchors;
  String? _loadError;
  String? _message;
  bool _busy = false;
  final Map<String, String> _results = {};
  final Set<String> _verifying = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(anchorServiceProvider).list();
      if (!mounted) return;
      setState(() {
        _anchors = list;
        _loadError = null;
      });
    } on AnchorException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Gagal memuat daftar jangkar.');
    }
  }

  Future<void> _anchorNow() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String msg;
    try {
      // Blok harus sudah ada di server sebelum dijangkarkan.
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
      final a = await ref
          .read(anchorServiceProvider)
          .anchorNow()
          .timeout(const Duration(seconds: 45));
      msg =
          'Terkirim ke ${ChainConfig.name}. Hash blok #${a.uptoIdx} dicatat di '
          'transaksi ${_shortTx(a.txHash)}. Konfirmasi butuh sekitar 15–30 detik.';
      await _load();
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

  Future<void> _verify(Anchor a) async {
    setState(() => _verifying.add(a.txHash));
    String text;
    try {
      final check = await ref.read(anchorServiceProvider).verifyOnChain(a);
      final local = localChainMatchesAnchor(a, widget.blocks);
      switch (check.status) {
        case AnchorStatus.confirmed:
          text = local
              ? 'TERVERIFIKASI. Hash blok #${a.uptoIdx} di HP sama dengan yang '
                    'tercatat di blockchain (blok Ethereum ${check.blockNumber ?? '?'}).'
              : 'TIDAK COCOK. Transaksi ada di blockchain, tetapi rantai di HP '
                    'berbeda dari yang dijangkarkan (data diubah atau hilang).';
        case AnchorStatus.pending:
          text = 'Transaksi belum masuk blok. Coba lagi sebentar lagi.';
        case AnchorStatus.notFound:
          text = 'Transaksi belum ditemukan node. Tunggu sebentar lalu coba lagi.';
        case AnchorStatus.mismatch:
          text = 'Isi transaksi di blockchain berbeda dari hash yang dijangkarkan.';
      }
    } on AnchorException catch (e) {
      text = e.message;
    } catch (_) {
      text = 'Verifikasi gagal. Coba lagi.';
    }
    if (!mounted) return;
    setState(() {
      _results[a.txHash] = text;
      _verifying.remove(a.txHash);
    });
  }

  /// Demo: ubah satu nilai blok #0 di salinan memori, lalu cocokkan dengan hash
  /// yang dijangkarkan. Data asli tidak berubah.
  void _tamperDemo(Anchor a) {
    final copy = [...widget.blocks];
    if (copy.isEmpty) return;
    copy[0] = copy[0].tampered(netMinor: copy[0].netMinor + 1);
    final ok = localChainMatchesAnchor(a, copy);
    setState(() {
      _results[a.txHash] = ok
          ? 'Demo: manipulasi tidak terdeteksi (seharusnya tidak mungkin).'
          : 'Demo: nilai blok #0 diubah di memori. Hash tidak lagi sama dengan '
                'yang tercatat di blockchain, jadi TIDAK COCOK. Data asli tidak berubah.';
    });
  }

  Future<void> _open(Anchor a) async {
    try {
      await launchUrl(
        Uri.parse(a.explorerUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Tidak bisa membuka browser.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anchors = _anchors;
    final lastIdx = widget.blocks.length - 1;
    final latestAnchored = (anchors == null || anchors.isEmpty)
        ? -1
        : anchors.first.uptoIdx;
    final pending = lastIdx - latestAnchored;
    final canAnchor = !_busy && widget.blocks.isNotEmpty && pending > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: AppColors.blue),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Jangkar blockchain',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Hash blok terbaru dicatat otomatis sebagai transaksi di ${ChainConfig.name} '
            'setelah sinkronisasi, sehingga catatan tidak bisa diubah diam-diam. '
            'Karena tiap blok memuat hash sebelumnya, seluruh riwayat ikut terkunci. '
            'Tombol di bawah untuk mencatat manual.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.s16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: _filledStyle,
              onPressed: canAnchor ? _anchorNow : null,
              child: Text(
                _busy
                    ? 'Mengirim…'
                    : (pending > 0
                          ? 'Catat ke blockchain ($pending blok baru)'
                          : 'Semua blok sudah dijangkarkan'),
              ),
            ),
          ),
          if (_message != null) _note(theme, _message!),
          if (_loadError != null) _note(theme, _loadError!),
          if (anchors != null && anchors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            for (final a in anchors) _anchorTile(theme, a),
          ],
        ],
      ),
    );
  }

  Widget _note(ThemeData theme, String text) => Padding(
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

  Widget _anchorTile(ThemeData theme, Anchor a) {
    final result = _results[a.txHash];
    final busy = _verifying.contains(a.txHash);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.surfaceGray),
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blok #0–#${a.uptoIdx} dijangkarkan',
            style: theme.textTheme.titleSmall,
          ),
          Text(
            'Tx ${_shortTx(a.txHash)} · ${a.createdAt.toString().substring(0, 16)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: _outlinedStyle,
                  onPressed: busy ? null : () => _verify(a),
                  child: Text(busy ? 'Memeriksa…' : 'Verifikasi di chain'),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              OutlinedButton(
                style: _outlinedStyle,
                onPressed: () => _open(a),
                child: const Text('Etherscan'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          TextButton(
            style: _textStyle,
            onPressed: () => _tamperDemo(a),
            child: const Text('Demo manipulasi'),
          ),
          if (result != null) _note(theme, result),
        ],
      ),
    );
  }
}