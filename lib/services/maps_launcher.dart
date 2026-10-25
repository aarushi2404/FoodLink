import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps (the app if installed, otherwise the browser) with
/// directions to a point. Returns false if nothing could open it.
Future<bool> openDirections(double lat, double lng) async {
  final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not open directions: $e');
    return false;
  }
}
