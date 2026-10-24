import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

abstract class AppZones {
  static const wib = 'Asia/Jakarta';
  static const wita = 'Asia/Makassar';
  static const wit = 'Asia/Jayapura';
  static const london = 'Europe/London';

  static const all = [wib, wita, wit, london];

  static String label(String zoneId) => switch (zoneId) {
    AppZones.wib => 'WIB',
    AppZones.wita => 'WITA',
    AppZones.wit => 'WIT',
    AppZones.london => 'London',
    _ => zoneId,
  };
}

class DualTimeText {
  const DualTimeText({required this.home, required this.client});

  final String home;
  final String client;
}

class TimeService {
  static bool _ready = false;

  static void init() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  static tz.Location _loc(String zoneId) {
    init();
    return tz.getLocation(zoneId);
  }

  static tz.TZDateTime inZone(DateTime instant, String zoneId) =>
      tz.TZDateTime.from(instant.toUtc(), _loc(zoneId));

  static DateTime toUtc({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required String zoneId,
  }) {
    final t = tz.TZDateTime(_loc(zoneId), year, month, day, hour, minute);
    return DateTime.fromMillisecondsSinceEpoch(
      t.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  static String zoneLabel(String zoneId, DateTime instant) {
    if (zoneId == AppZones.london) {
      return inZone(instant, zoneId).timeZoneOffset.inMinutes == 0
          ? 'GMT'
          : 'BST';
    }
    return AppZones.label(zoneId);
  }

  static String formatHm(DateTime instant, String zoneId) {
    final t = inZone(instant, zoneId);
    return '${_two(t.hour)}:${_two(t.minute)} ${zoneLabel(zoneId, instant)}';
  }

  static String formatDateHm(DateTime instant, String zoneId) {
    final t = inZone(instant, zoneId);
    return '${_two(t.day)}/${_two(t.month)} ${formatHm(instant, zoneId)}';
  }

  static DualTimeText dual(
    DateTime instant, {
    required String homeZone,
    required String clientZone,
  }) => DualTimeText(
    home: formatDateHm(instant, homeZone),
    client: formatDateHm(instant, clientZone),
  );

  /// True jika [instant] sudah lewat (atau sama dengan) [now].
  static bool isPast(DateTime instant, {DateTime? now}) =>
      !instant.toUtc().isAfter((now ?? DateTime.now()).toUtc());

  static String _two(int v) => v.toString().padLeft(2, '0');
}
