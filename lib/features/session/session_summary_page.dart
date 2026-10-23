import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/work_session.dart';
import '../blockchain/chain_repository.dart';
import 'session_money.dart';
import 'session_providers.dart';

class SessionSummaryPage extends ConsumerWidget {
  const SessionSummaryPage({
    super.key,
    required this.session,
    required this.client,
  });

  final WorkSession session;
  final Client? client;

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.r24),
    boxShadow: AppShadows.soft,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = client;
    final money = computeSessionMoney(
      durationSeconds: session.durationSeconds,
      lateMinutes: session.lateMinutes,
      hourlyRate: c?.hourlyRate ?? 0,
      currency: c?.currency ?? Currencies.idr,
    );
    final rates = ref.watch(ratesProvider);
    final chain = ref.watch(chainProvider).value;
    final block = chain?.where((b) => b.sessionId == session.id).firstOrNull;

    Widget row(String label, String value, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              const SizedBox(width: AppSpacing.s8),
              Text(
                value,
                style:
                    (bold
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(color: color),
              ),
            ],
          ),
        );

    String two(int v) => v.toString().padLeft(2, '0');

    Widget idrRow() {
      if (money.currency == Currencies.idr) return const SizedBox.shrink();
      return rates.when(
        loading: () => row('Setara IDR', 'memuat kurs\u2026'),
        error: (e, st) => row('Setara IDR', 'kurs tidak tersedia'),
        data: (table) {
          final idr = table.convert(money.net, money.currency, Currencies.idr);
          var label = 'Setara IDR';
          if (table.isFallback) {
            label = 'Setara IDR (perkiraan, offline)';
          } else {
            final at = table.fetchedAt?.toLocal();
            if (at != null &&
                DateTime.now().difference(at) > const Duration(hours: 12)) {
              label =
                  'Setara IDR (kurs ${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)})';
            }
          }
          return row(label, formatMoney(idr, Currencies.idr), bold: true);
        },
      );
    }

    final late = session.lateMinutes > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi selesai'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Center(
            child: Text('Kerja bagus!', style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: _cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row('Klien', c?.name ?? '-', bold: true),
                row(
                  'Durasi',
                  formatHms(Duration(seconds: session.durationSeconds)),
                ),
                row(
                  'Terlambat',
                  late ? '${session.lateMinutes} menit' : 'Tepat waktu',
                  color: late ? AppColors.error : AppColors.success,
                ),
                const Divider(height: AppSpacing.s24),
                row(
                  'Pendapatan kotor',
                  formatMoney(money.gross, money.currency),
                ),
                row(
                  'Denda keterlambatan',
                  '- ${formatMoney(money.penalty, money.currency)}',
                  color: money.penalty > 0 ? AppColors.error : null,
                ),
                row(
                  'Pendapatan bersih',
                  formatMoney(money.net, money.currency),
                  bold: true,
                ),
                idrRow(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: _cardDecoration,
            child: block == null
                ? Row(
                    children: [
                      const Icon(
                        Icons.link_off,
                        color: AppColors.navInactive,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          'Belum tercatat di blockchain.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.link,
                            color: AppColors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Text(
                            'Tercatat di blockchain, blok #${block.index}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      SelectableText(
                        block.hash,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}
