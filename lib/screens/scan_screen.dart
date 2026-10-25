import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/auth_service.dart';
import '../services/listing_service.dart';

/// Vendor scans a customer's QR to mark the claim as collected.
/// (On an emulator use the "Pickups" tab instead: type the 6-digit code
/// or tap "Mark collected".)
class ScanScreen extends StatefulWidget {
  final AppUser vendor;
  const ScanScreen({super.key, required this.vendor});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController();
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return; // ignore repeated frames of the same code
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;

    _handling = true;
    String title;
    String message;
    bool ok;
    try {
      final claim =
          await ListingService.instance.verifyAndCollect(raw, widget.vendor.uid);
      ok = true;
      title = 'Pickup confirmed';
      message = '${claim.userName} collected "${claim.listingTitle}".';
    } catch (e) {
      ok = false;
      title = 'Cannot confirm';
      message = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(ok ? Icons.check_circle : Icons.error,
            color: ok ? Colors.green : Colors.red, size: 40),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    _handling = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan pickup QR')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Point the camera at the customer\'s QR code',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
