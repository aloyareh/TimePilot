import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/biometric_service.dart';
import '../../core/currency/currency_service.dart';
import '../auth/biometric_provider.dart';
import '../session/session_providers.dart';
import 'earnings_providers.dart';

/// Halaman Pendapatan (PBI-20), dikunci sidik jari/wajah setiap dibuka.
class EarningsPage extends ConsumerStatefulWidget {
  const EarningsPage({super.key});

  @override
  ConsumerState<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends ConsumerState<EarningsPage> {
  bool _unlocked = false;
  bool _checking = true;

  /// true = biometrik belum didaftarkan di aplikasi (saklar Profil mati).
  bool _needsEnable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  /// Biometrik sudah didaftarkan: verifikasi. Belum: tawarkan pendaftaran.
  Future<void> _check() async {
    setState(() => _checking = true);
    final enabled = await ref.read(biometricEnabledProvider.future);
    if (!enabled) {
      if (!mounted) return;
      setState(() {
        _needsEnable = true;
        _unlocked = false;
        _checking = false;
      });
      return;
    }
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate('Verifikasi identitas untuk melihat pendapatan');
    if (!mounted) return;
    setState(() {
      _needsEnable = false;
      _unlocked = ok;
      _checking = false;
    });
  }

  /// Mendaftarkan biometrik dari sini: saklar di Profil ikut aktif.
  Future<void> _enable() async {
    final ok = await ref.read(biometricEnabledProvider.notifier).enable();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _needsEnable = false;
        _unlocked = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometrik tidak tersedia, belum didaftarkan di HP, atau dibatalkan.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendapatan')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : !_unlocked
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      _needsEnable
                          ? 'Halaman ini dikunci dengan biometrik. Aktifkan biometrik untuk membukanya. Pengaturan ini juga berlaku untuk login.'
                          : 'Halaman ini dikunci. Verifikasi sidik jari / wajah untuk melihat pendapatan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _needsEnable ? _enable : _check,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(
                        _needsEnable ? 'Aktifkan biometrik' : 'Buka kunci',
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const _EarningsBody(),
    );
  }
}

class _EarningsBody extends ConsumerWidget {
  const _EarningsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(earningsProvider);
    final rates = ref.watch(ratesProvider);

    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada sesi kerja yang selesai.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Widget totalCard() => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: rates.when(
          loading: () => const Text('Menghitung total…'),
          error: (e, st) => const Text('Total IDR tidak tersedia (kurs gagal dimuat).'),
          data: (table) {
            var total = 0.0;
            for (final r in rows) {
              total += table.convert(r.net, r.currency, Currencies.idr);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total pendapatan bersih'),
                const SizedBox(height: 4),
                Text(
                  formatMoney(total, Currencies.idr),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (table.isFallback)
                  const Text('Kurs perkiraan (offline).'),
              ],
            );
          },
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        totalCard(),
        for (final r in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text('${r.sessionCount} sesi · ${formatHms(Duration(seconds: r.totalSeconds))}'),
                  Text('Terlambat total: ${r.lateMinutes} menit'),
                  const SizedBox(height: 8),
                  Text('Kotor: ${formatMoney(r.gross, r.currency)}'),
                  Text('Denda: - ${formatMoney(r.penalty, r.currency)}'),
                  Text(
                    'Bersih: ${formatMoney(r.net, r.currency)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  rates.when(
                    data: (t) => r.currency == Currencies.idr
                        ? const SizedBox.shrink()
                        : Text(
                            '≈ ${formatMoney(t.convert(r.net, r.currency, Currencies.idr), Currencies.idr)}',
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}