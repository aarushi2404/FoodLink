import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../services/image_service.dart';
import '../ui.dart';

/// The listing's photo, or a tinted emoji placeholder (by vendor type) when
/// it has none. Fills whatever box it is placed in: wrap it in a SizedBox,
/// AspectRatio or Positioned.fill.
class ListingImage extends StatelessWidget {
  final Listing listing;
  final BoxFit fit;

  const ListingImage({super.key, required this.listing, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (!listing.hasImage) {
      return _FoodPlaceholder(vendorType: listing.vendorType);
    }
    return FutureBuilder<Uint8List?>(
      future: ImageService.instance.load(listing.id),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return _FoodPlaceholder(
            vendorType: listing.vendorType,
            loading: snap.connectionState != ConnectionState.done,
          );
        }
        return Image.memory(
          bytes,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _FoodPlaceholder extends StatelessWidget {
  final String vendorType;
  final bool loading;
  const _FoodPlaceholder({required this.vendorType, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final style = typeStyle(vendorType);
    return Container(
      color: style.color.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(style.emoji, style: const TextStyle(fontSize: 44)),
    );
  }
}
