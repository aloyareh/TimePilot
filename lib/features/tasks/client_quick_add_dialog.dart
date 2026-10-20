import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency/currency_service.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';

/// Dialog tambah klien cepat dari form tugas. Mengembalikan [Client] atau null.
/// Halaman kelola klien lengkap (ubah/hapus) tetap bagian PBI-07.
class ClientQuickAddDialog extends StatefulWidget {
  const ClientQuickAddDialog({super.key});

  @override
  State<ClientQuickAddDialog> createState() => _ClientQuickAddDialogState();
}

class _ClientQuickAddDialogState extends State<ClientQuickAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rate = TextEditingController();
  String _zone = AppZones.london;
  String _currency = Currencies.usd;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rate = double.parse(_rate.text.trim().replaceAll(',', '.'));
    Navigator.of(context).pop(
      Client(
        id: const Uuid().v4(),
        name: _name.text.trim(),
        timezoneId: _zone,
        hourlyRate: rate,
        currency: _currency,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Klien baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nama klien'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _zone,
                decoration: const InputDecoration(labelText: 'Zona waktu klien'),
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
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
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
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}