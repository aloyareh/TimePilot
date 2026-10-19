import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

abstract class Currencies {
  static const idr = 'IDR';
  static const usd = 'USD';
  static const gbp = 'GBP';
  static const eur = 'EUR';

  static const all = [idr, usd, gbp, eur];

  static String symbol(String code) => switch (code) {
    Currencies.idr => 'Rp ',
    Currencies.usd => r'$',
    Currencies.gbp => '£',
    Currencies.eur => '€',
    _ => '$code ',
  };
}

class RateTable {
  const RateTable(this.perUsd, {this.fetchedAt, this.isFallback = false});

  final Map<String, double> perUsd;
  final DateTime? fetchedAt;

  final bool isFallback;

  static const fallback = RateTable({
    'USD': 1.0,
    'IDR': 16000.0,
    'GBP': 0.78,
    'EUR': 0.92,
  }, isFallback: true);

  factory RateTable.fromJson(Map<String, dynamic> json, {DateTime? fetchedAt}) {
    final raw = json['rates'];
    if (raw is! Map) throw const FormatException('Kunci "rates" tidak ada.');
    final out = <String, double>{'USD': 1.0};
    for (final code in Currencies.all) {
      final v = raw[code];
      if (v is num && v > 0) out[code] = v.toDouble();
    }
    for (final code in Currencies.all) {
      if (!out.containsKey(code)) throw FormatException('Kurs $code tidak ada.');
    }
    return RateTable(out, fetchedAt: fetchedAt);
  }

  factory RateTable.fromCache(Map<String, dynamic> json) {
    final at = json['fetched_at'];
    return RateTable.fromJson(
      json,
      fetchedAt: at is String ? DateTime.tryParse(at) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'rates': perUsd,
    'fetched_at': fetchedAt?.toIso8601String(),
  };

  double convert(double amount, String from, String to) {
    final f = perUsd[from];
    final t = perUsd[to];
    if (f == null || t == null) {
      throw ArgumentError('Mata uang tidak didukung: $from -> $to');
    }
    return amount / f * t;
  }
}

String formatMoney(double amount, String currency) {
  final isIdr = currency == Currencies.idr;
  final sign = amount < 0 ? '-' : '';
  final fixed = amount.abs().toStringAsFixed(isIdr ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => isIdr ? '.' : ',',
  );
  final decimals = parts.length > 1 ? '${isIdr ? ',' : '.'}${parts[1]}' : '';
  return '$sign${Currencies.symbol(currency)}$grouped$decimals';
}

class CurrencyService {
  CurrencyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _boxName = 'rates';
  static const _cacheKey = 'latest';
  static const _url = 'https://open.er-api.com/v6/latest/USD';
  static const _maxAge = Duration(hours: 12);

  Future<Box<String>> _box() async => Hive.isBoxOpen(_boxName)
      ? Hive.box<String>(_boxName)
      : await Hive.openBox<String>(_boxName);

  Future<RateTable?> _readCache() async {
    try {
      final raw = (await _box()).get(_cacheKey);
      if (raw == null) return null;
      return RateTable.fromCache(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; 
    }
  }

  Future<RateTable> getRates({bool forceRefresh = false}) async {
    final cached = await _readCache();
    final at = cached?.fetchedAt;
    final fresh = at != null && DateTime.now().difference(at) < _maxAge;
    if (cached != null && fresh && !forceRefresh) return cached;

    try {
      final res = await _client
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final table = RateTable.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        fetchedAt: DateTime.now(),
      );
      await (await _box()).put(_cacheKey, jsonEncode(table.toJson()));
      return table;
    } catch (_) {
      return cached ?? RateTable.fallback;
    }
  }
}

final currencyServiceProvider = Provider<CurrencyService>(
  (ref) => CurrencyService(),
);

final ratesProvider = FutureProvider<RateTable>(
  (ref) => ref.read(currencyServiceProvider).getRates(),
);