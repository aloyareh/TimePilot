import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/work_session.dart';
import '../blockchain/chain_repository.dart';
import 'session_money.dart';
import 'session_providers.dart';

/// Ringkasan setelah sesi diakhiri: durasi, denda keterlambatan, pendapatan
/// bersih (mata uang klien dan IDR), dan blok blockchain yang mencatatnya.
class SessionSummaryPage extends ConsumerWidget {
  const SessionSummaryPage({super.key, required this.session, required this.client});

  final WorkSession session;
  final Client? client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );

    String two(int v) => v.toString().padLeft(2, '0');

    Widget idrRow() {
      if (money.currency == Currencies.idr) return const SizedBox.shrink();
      return rates.when(
        loading: () => row('Setara IDR', 'memuat kurs…'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Sesi selesai'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  row('Klien', c?.name ?? '-'),
                  row('Durasi', formatHms(Duration(seconds: session.durationSeconds))),
                  row(
                    'Terlambat',
                    session.lateMinutes > 0 ? '${session.lateMinutes} menit' : 'Tepat waktu',
                  ),
                  const Divider(),
                  row('Pendapatan kotor', formatMoney(money.gross, money.currency)),
                  row('Denda keterlambatan', '- ${formatMoney(money.penalty, money.currency)}'),
                  row('Pendapatan bersih', formatMoney(money.net, money.currency), bold: true),
                  idrRow(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: block == null
                  ? const Text('Belum tercatat di blockchain.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tercatat di blockchain, blok #${block.index}'),
                        const SizedBox(height: 4),
                        SelectableText(
                          block.hash,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}