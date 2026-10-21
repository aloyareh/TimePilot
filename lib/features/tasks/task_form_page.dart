import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import 'task_providers.dart';

/// Tambah/ubah tugas. Jadwal diisi dalam zona waktu KLIEN lalu disimpan sebagai UTC.
class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();

  String? _clientId;
  DateTime? _date;
  TimeOfDay? _time;
  String _status = TaskStatus.todo;
  bool _busy = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _title.text = t.title;
      _clientId = t.clientId;
      _status = t.status;
      final client = _clientById(t.clientId);
      final local = TimeService.inZone(
        t.deadlineUtc,
        client?.timezoneId ?? AppZones.wib,
      );
      _date = DateTime(local.year, local.month, local.day);
      _time = TimeOfDay(hour: local.hour, minute: local.minute);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Client? _clientById(String? id) {
    if (id == null) return null;
    for (final c in ref.read(clientsProvider)) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  DateTime? _deadlineUtc(Client client) {
    final d = _date;
    final t = _time;
    if (d == null || t == null) return null;
    return TimeService.toUtc(
      year: d.year,
      month: d.month,
      day: d.day,
      hour: t.hour,
      minute: t.minute,
      zoneId: client.timezoneId,
    );
  }

  String? _preview() {
    final client = _clientById(_clientId);
    if (client == null) return null;
    final utc = _deadlineUtc(client);
    if (utc == null) return null;
    final home = ref.read(homeZoneProvider);
    final d = TimeService.dual(utc, homeZone: home, clientZone: client.timezoneId);
    return client.timezoneId == home
        ? d.home
        : 'Klien: ${d.client}\nKamu: ${d.home}';
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final client = _clientById(_clientId);
    if (client == null) {
      _snack('Pilih klien dulu.');
      return;
    }
    final utc = _deadlineUtc(client);
    if (utc == null) {
      _snack('Isi tanggal dan jam.');
      return;
    }

    setState(() => _busy = true);
    final now = DateTime.now().toUtc();
    final base = widget.task;
    final task = Task(
      id: base?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      clientId: client.id,
      deadlineUtc: utc,
      status: _status,
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.init();
      await svc.requestPermissions(); // dialog hanya muncul bila belum diizinkan
    } catch (_) {}
    await ref.read(tasksProvider.notifier).save(task);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final theme = Theme.of(context);
    final preview = _preview();
    final dateText = _date == null
        ? 'Pilih tanggal'
        : '${_date!.day.toString().padLeft(2, '0')}/'
              '${_date!.month.toString().padLeft(2, '0')}/${_date!.year}';
    final timeText = _time == null ? 'Pilih jam' : _time!.format(context);
    final client = _clientById(_clientId);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Ubah tugas' : 'Tugas baru')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Judul tugas / meeting'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Judul wajib diisi.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_clientId),
                // Nilai hanya dipakai bila klien masih ada di daftar (klien
                // bisa saja sudah dihapus dari Profile), kalau tidak dropdown error.
                initialValue: clients.any((c) => c.id == _clientId)
                    ? _clientId
                    : null,
                decoration: const InputDecoration(labelText: 'Klien'),
                items: [
                  for (final c in clients)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.name} (${AppZones.label(c.timezoneId)})'),
                    ),
                ],
                onChanged: (v) => setState(() => _clientId = v),
              ),
              if (clients.isEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum ada klien. Tambahkan klien di tab Profile '
                          '(menu User Persona), lalu kembali ke sini.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                client == null
                    ? 'Jadwal (dalam zona waktu klien)'
                    : 'Jadwal (dalam waktu ${AppZones.label(client.timezoneId)})',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(dateText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(timeText),
                    ),
                  ),
                ],
              ),
              if (preview != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.public, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(preview)),
                    ],
                  ),
                ),
              ],
              if (_editing) ...[
                const SizedBox(height: 16),
                Text('Status', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: TaskStatus.todo, label: Text('Belum')),
                    ButtonSegment(
                      value: TaskStatus.inProgress,
                      label: Text('Berjalan'),
                    ),
                    ButtonSegment(value: TaskStatus.done, label: Text('Selesai')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}