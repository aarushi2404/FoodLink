import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/listing.dart';
import '../services/listing_service.dart';

/// The customer's pickup pass: QR + 6-digit code. It updates live and turns
/// into a "Pickup complete" screen as soon as the vendor completes the order.
class QrScreen extends StatefulWidget {
  final String claimId;
  const QrScreen({super.key, required this.claimId});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late final Stream<Claim?> _stream =
      ListingService.instance.claimById(widget.claimId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup pass')),
      body: StreamBuilder<Claim?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final claim = snap.data;
          if (claim == null) {
            return const Center(child: Text('This claim no longer exists.'));
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: claim.isCollected ? _done(context, claim) : _pass(context, claim),
            ),
          );
        },
      ),
    );
  }

  Widget _done(BuildContext context, Claim c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 96, color: Color(0xFF3FA66A)),
        const SizedBox(height: 16),
        Text('Pickup complete',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Enjoy your ${c.listingTitle} from ${c.vendorName}.',
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('Thank you for helping cut food waste.'),
      ],
    );
  }

  Widget _pass(BuildContext context, Claim c) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.listingTitle, textAlign: TextAlign.center, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text('at ${c.vendorName}'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(data: c.id, version: QrVersions.auto, size: 220),
        ),
        const SizedBox(height: 20),
        Text('or give the vendor this code', style: text.bodyMedium),
        const SizedBox(height: 4),
        Text(
          c.pickupCode,
          style: text.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 16),
        if (c.isNoShow)
          Text('The pickup window has closed.',
              style: TextStyle(color: Theme.of(context).colorScheme.error))
        else
          const Text('Works once. This screen updates when the vendor confirms.',
              textAlign: TextAlign.center),
      ],
    );
  }
}
