import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import 'task_providers.dart';

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
    final client = _clientById(_clientId);
    final nowLocal = client == null
        ? DateTime.now()
        : TimeService.inZone(DateTime.now(), client.timezoneId);
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final existing = _date;
    final firstDate = (existing != null && existing.isBefore(today))
        ? existing
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? today,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 365 * 3)),
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
    final d = TimeService.dual(
      utc,
      homeZone: home,
      clientZone: client.timezoneId,
    );
    return client.timezoneId == home
        ? d.home
        : 'Klien: ${d.client}\nKamu: ${d.home}';
  }

  /// Pesan error jika waktu yang dipilih sudah lewat menurut zona klien.
  /// Saat mengubah tugas, hanya divalidasi bila deadline diubah.
  String? _pastError(Client? client) {
    if (client == null) return null;
    final utc = _deadlineUtc(client);
    if (utc == null) return null;
    if (_editing && utc == widget.task!.deadlineUtc) return null;
    if (!TimeService.isPast(utc)) return null;
    final zone = AppZones.label(client.timezoneId);
    final nowText = TimeService.formatHm(DateTime.now(), client.timezoneId);
    return 'Waktu $zone yang dipilih sudah lewat (sekarang $nowText). '
        'Pilih waktu yang akan datang.';
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
    final pastError = _pastError(client);
    if (pastError != null) {
      _snack(pastError);
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
      await svc.requestPermissions();
    } catch (_) {}
    await ref.read(tasksProvider.notifier).save(task);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _infoBox({
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: child),
        ],
      ),
    );
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
    final pastError = _pastError(client);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Ubah tugas' : 'Tugas baru')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              _FormSection(
                title: 'Detail Tugas',
                children: [
                  TextFormField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Judul tugas / meeting',
                      prefixIcon: Icon(Icons.assignment_outlined),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Judul wajib diisi.' : null,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_clientId),
                    isExpanded: true,
                    initialValue: clients.any((c) => c.id == _clientId)
                        ? _clientId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Klien',
                      prefixIcon: Icon(Icons.business_center_outlined),
                    ),
                    items: [
                      for (final c in clients)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.name} (${AppZones.label(c.timezoneId)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _clientId = v),
                  ),
                  if (clients.isEmpty) ...[
                    const SizedBox(height: AppSpacing.s12),
                    _infoBox(
                      icon: Icons.info_outline,
                      color: AppColors.warning,
                      child: Text(
                        'Belum ada klien. Tambahkan klien lewat Ubah persona '
                        'di tab Profile, lalu kembali ke sini.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              _FormSection(
                title: client == null
                    ? 'Jadwal (zona waktu klien)'
                    : 'Jadwal (waktu ${AppZones.label(client.timezoneId)})',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(dateText),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(timeText),
                        ),
                      ),
                    ],
                  ),
                  if (pastError != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    _infoBox(
                      icon: Icons.error_outline,
                      color: AppColors.error,
                      child: Text(
                        pastError,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                  if (preview != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    _infoBox(
                      icon: Icons.public,
                      color: AppColors.blue,
                      child: Text(preview, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ],
              ),
              if (_editing) ...[
                const SizedBox(height: AppSpacing.s16),
                _FormSection(
                  title: 'Status',
                  children: [
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.blue.withValues(
                          alpha: 0.12,
                        ),
                        selectedForegroundColor: AppColors.blue,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: TaskStatus.todo,
                          label: Text('Belum'),
                        ),
                        ButtonSegment(
                          value: TaskStatus.inProgress,
                          label: Text('Berjalan'),
                        ),
                        ButtonSegment(
                          value: TaskStatus.done,
                          label: Text('Selesai'),
                        ),
                      ],
                      selected: {_status},
                      onSelectionChanged: (s) =>
                          setState(() => _status = s.first),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan'),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s16),
          ...children,
        ],
      ),
    );
  }
}
