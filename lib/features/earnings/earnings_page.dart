import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/biometric_service.dart';
import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/biometric_provider.dart';
import '../session/session_providers.dart';
import 'earnings_providers.dart';

class EarningsPage extends ConsumerStatefulWidget {
  const EarningsPage({super.key});

  @override
  ConsumerState<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends ConsumerState<EarningsPage> {
  bool _unlocked = false;
  bool _checking = true;
  bool _needsEnable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

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

  Widget _locked(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 44,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text('Halaman Terkunci', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _needsEnable
                  ? 'Halaman ini dikunci dengan biometrik. Aktifkan biometrik untuk membukanya. Pengaturan ini juga berlaku untuk login.'
                  : 'Halaman ini dikunci. Verifikasi sidik jari / wajah untuk melihat pendapatan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.s24),
            FilledButton.icon(
              onPressed: _needsEnable ? _enable : _check,
              icon: const Icon(Icons.fingerprint),
              label: Text(_needsEnable ? 'Aktifkan biometrik' : 'Buka kunci'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pendapatan')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : !_unlocked
          ? _locked(theme)
          : const _EarningsBody(),
    );
  }
}

class _EarningsBody extends ConsumerWidget {
  const _EarningsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(earningsProvider);
    final rates = ref.watch(ratesProvider);

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 56,
                color: AppColors.navInactive,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Belum ada sesi kerja yang selesai.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    Widget totalCard() => Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.blue],
        ),
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.medium,
      ),
      child: rates.when(
        loading: () => Text(
          'Menghitung total\u2026',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        error: (e, st) => Text(
          'Total IDR tidak tersedia (kurs gagal dimuat).',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        data: (table) {
          var total = 0.0;
          for (final r in rows) {
            total += table.convert(r.net, r.currency, Currencies.idr);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total pendapatan bersih',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                formatMoney(total, Currencies.idr),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (table.isFallback)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s4),
                  child: Text(
                    'Kurs perkiraan (offline).',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    Widget line(
      String label,
      String value, {
      Color? color,
      bool bold = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(
            value,
            style:
                (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                    ?.copyWith(color: color),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        totalCard(),
        const SizedBox(height: AppSpacing.s16),
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s12),
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                      ),
                      child: const Icon(
                        Icons.business_center_outlined,
                        color: AppColors.blue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.clientName, style: theme.textTheme.titleSmall),
                          Text(
                            '${r.sessionCount} sesi \u00B7 ${formatHms(Duration(seconds: r.totalSeconds))}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.s24),
                line(
                  'Terlambat total',
                  '${r.lateMinutes} menit',
                  color: r.lateMinutes > 0 ? AppColors.error : null,
                ),
                line('Kotor', formatMoney(r.gross, r.currency)),
                line(
                  'Denda',
                  '- ${formatMoney(r.penalty, r.currency)}',
                  color: r.penalty > 0 ? AppColors.error : null,
                ),
                line('Bersih', formatMoney(r.net, r.currency), bold: true),
                rates.when(
                  data: (t) => r.currency == Currencies.idr
                      ? const SizedBox.shrink()
                      : line(
                          'Setara IDR',
                          '\u2248 ${formatMoney(t.convert(r.net, r.currency, Currencies.idr), Currencies.idr)}',
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
