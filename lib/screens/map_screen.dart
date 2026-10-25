import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/listing.dart';
import '../services/maps_launcher.dart';
import '../widgets/listing_image.dart';

/// Google Map of surplus listings around the user.
/// Needs a Maps API key in AndroidManifest.xml (see MAPS_SETUP.md).
class MapScreen extends StatelessWidget {
  final List<Listing> listings;
  final Position? position;
  final Future<void> Function(Listing) onClaim;

  const MapScreen({
    super.key,
    required this.listings,
    required this.position,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final pins = listings.where((l) => l.hasCoords).toList();
    final p = position;

    LatLng center;
    double zoom;
    if (p != null) {
      center = LatLng(p.latitude, p.longitude);
      zoom = 14;
    } else if (pins.isNotEmpty) {
      center = LatLng(pins.first.lat!, pins.first.lng!);
      zoom = 14;
    } else {
      center = const LatLng(20.5937, 78.9629); // India
      zoom = 4;
    }

    final markers = <Marker>{
      for (final l in pins)
        Marker(
          markerId: MarkerId(l.id),
          position: LatLng(l.lat!, l.lng!),
          onTap: () => _showDetails(context, l),
        ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Surplus on the map')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: zoom),
        markers: markers,
        // only draw the blue dot if we already have location permission
        myLocationEnabled: p != null,
        myLocationButtonEnabled: p != null,
        mapToolbarEnabled: false,
        onMapCreated: (controller) => _fit(controller, pins, p),
      ),
    );
  }

  /// Zoom so the user and every pin are visible (skipped when they all sit
  /// on one spot, e.g. a single emulator location).
  Future<void> _fit(
      GoogleMapController controller, List<Listing> pins, Position? p) async {
    final points = <LatLng>[
      if (p != null) LatLng(p.latitude, p.longitude),
      for (final l in pins) LatLng(l.lat!, l.lng!),
    ];
    if (points.length < 2) return;

    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final pt in points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }
    if ((maxLat - minLat) < 0.0005 && (maxLng - minLng) < 0.0005) return;

    try {
      await Future.delayed(const Duration(milliseconds: 300)); // let the map lay out
      await controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ));
    } catch (_) {
      // the map was closed or not laid out yet: keep the default view
    }
  }

  void _showDetails(BuildContext mapContext, Listing l) {
    showModalBottomSheet<void>(
      context: mapContext,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: ListingImage(listing: l),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title,
                          style: Theme.of(sheetContext).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('${l.vendorName} - ${l.location}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${l.price == 0 ? 'Free' : '₹${l.price.toStringAsFixed(0)}'}'
                '  |  ${l.remaining} left  |  ${l.timeLeftLabel}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openDirections(l.lat!, l.lng!),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext); // close sheet
                      Navigator.pop(mapContext); // close map
                      onClaim(l); // claim from the feed screen underneath
                    },
                    child: const Text('Claim'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Vendor taps the Google Map to choose the pickup point.
class PickLocationScreen extends StatefulWidget {
  final LatLng initial;
  final double initialZoom;
  const PickLocationScreen({
    super.key,
    required this.initial,
    this.initialZoom = 15,
  });

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  LatLng? _picked;

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap to set pickup point'),
        actions: [
          TextButton(
            onPressed: picked == null ? null : () => Navigator.pop(context, picked),
            child: const Text('Done'),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: widget.initial, zoom: widget.initialZoom),
        onTap: (point) => setState(() => _picked = point),
        markers: {
          if (picked != null)
            Marker(markerId: const MarkerId('picked'), position: picked),
        },
        mapToolbarEnabled: false,
      ),
    );
  }
}
