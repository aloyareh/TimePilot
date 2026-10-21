import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../tasks/task_providers.dart';

/// Dialog tambah / ubah klien (PBI-07). Mengembalikan [Client] atau null.
/// Klien wajib punya Zona Waktu (WIB/WITA/WIT/London) dan Tarif/Jam.
/// Memakai service PBI-09 untuk pratinjau jam klien & konversi tarif ke IDR.
class ClientFormDialog extends ConsumerStatefulWidget {
  const ClientFormDialog({super.key, this.initial, this.homeZone});

  final Client? initial;

  /// Zona waktu rumah untuk pratinjau. Default: dari profil tersimpan.
  final String? homeZone;

  @override
  ConsumerState<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _rate;
  late String _zone;
  late String _currency;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c?.name ?? '');
    _rate = TextEditingController(
      text: c == null ? '' : _fmtRate(c.hourlyRate),
    );
    _zone = c?.timezoneId ?? AppZones.london;
    _currency = c?.currency ?? Currencies.usd;
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  static String _fmtRate(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? get _rateValue =>
      double.tryParse(_rate.text.trim().replaceAll(',', '.'));

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      Client(
        id: widget.initial?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        timezoneId: _zone,
        hourlyRate: _rateValue!,
        currency: _currency,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Menjamin zona waktu rumah tidak pernah null, apa pun sumbernya.
  static String _zoneOrDefault(String? zone) => zone ?? AppZones.wib;

  Widget _preview() {
    final home = _zoneOrDefault(widget.homeZone ?? ref.watch(homeZoneProvider));
    final dual = TimeService.dual(
      DateTime.now().toUtc(),
      homeZone: home,
      clientZone: _zone,
    );
    final rates = ref.watch(ratesProvider).value;
    final rate = _rateValue;
    String? money;
    if (rates != null &&
        rate != null &&
        rate > 0 &&
        _currency != Currencies.idr) {
      final idr = rates.convert(rate, _currency, Currencies.idr);
      money = '≈ ${formatMoney(idr, Currencies.idr)} / jam';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sekarang', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text('Klien: ${dual.client}'),
          Text('Kamu:  ${dual.home}'),
          if (money != null) ...[const SizedBox(height: 6), Text(money)],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Ubah klien' : 'Klien baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama klien'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _zone,
                decoration: const InputDecoration(
                  labelText: 'Zona waktu klien',
                ),
                items: [
                  for (final z in AppZones.all)
                    DropdownMenuItem(value: z, child: Text(AppZones.label(z))),
                ],
                onChanged: (v) => setState(() => _zone = v ?? _zone),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Tarif/jam'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final n = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'),
                        );
                        return (n == null || n <= 0) ? 'Angka > 0.' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Mata uang'),
                      items: [
                        for (final c in Currencies.all)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) =>
                          setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _preview(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
