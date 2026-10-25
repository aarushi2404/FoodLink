import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationResult {
  final Position? position;
  final String? error;
  const LocationResult({this.position, this.error});
}

class LocationService {
  LocationService._();
  static final instance = LocationService._();

  /// Current device position, or a readable error (never throws).
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(
            error: 'Location is switched off on this device.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const LocationResult(error: 'Location permission was denied.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult(position: pos);
    } on TimeoutException {
      return const LocationResult(
          error: 'No location fix. In the emulator: ... > Location > Send a point.');
    } catch (e) {
      return LocationResult(error: 'Could not get location ($e)');
    }
  }

  static double distanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }
}
