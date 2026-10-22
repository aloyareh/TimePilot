import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationAction { appSettings, locationSettings }

class LocationException implements Exception {
  const LocationException(this.message, {this.action});

  final String message;
  final LocationAction? action;

  @override
  String toString() => message;
}

/// Membaca koordinat GPS (PBI-25) dengan penanganan izin & GPS mati.
class LocationService {
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'GPS belum aktif. Aktifkan lokasi lalu coba lagi.',
        action: LocationAction.locationSettings,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
        action: LocationAction.appSettings,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw const LocationException(
        'Lokasi belum terdeteksi. Coba lagi di tempat terbuka.',
      );
    }
  }

  Future<void> openSettings(LocationAction action) async {
    switch (action) {
      case LocationAction.appSettings:
        await Geolocator.openAppSettings();
      case LocationAction.locationSettings:
        await Geolocator.openLocationSettings();
    }
  }
}
