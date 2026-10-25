import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/listing.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../ui.dart';
import '../validators.dart';

/// Orders waiting for collection. No camera needed: type the customer's
/// 6-digit code, or just tap "Mark collected".
class VendorPickups extends StatefulWidget {
  final AppUser vendor;
  const VendorPickups({super.key, required this.vendor});

  @override
  State<VendorPickups> createState() => _VendorPickupsState();
}

class _VendorPickupsState extends State<VendorPickups> {
  final _codeForm = GlobalKey<FormState>();
  final _code = TextEditingController();
  late final Stream<List<Claim>> _stream =
      ListingService.instance.vendorClaims(widget.vendor.uid);
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Claim> Function() action) async {
    setState(() => _busy = true);
    String message;
    try {
      final c = await action();
      message = '${c.userName} collected "${c.listingTitle}"';
      _code.clear();
    } catch (e) {
      message = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _completeByCode() {
    final error = Validators.pickupCode(_code.text);
    if (error != null) {
      _codeForm.currentState?.validate();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    FocusScope.of(context).unfocus();
    _run(() => ListingService.instance.collectByCode(_code.text, widget.vendor.uid));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<List<Claim>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final pending = snap.data!.where((c) => !c.isCollected).toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Complete by code', style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text('Ask the customer for the 6-digit code on their pass.',
                        style: text.bodySmall),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Form(
                            key: _codeForm,
                            child: TextFormField(
                              controller: _code,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: 6,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: fieldDeco('Pickup code',
                                  hint: '6-digit code', icon: Icons.pin_outlined),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? null : Validators.pickupCode(v),
                              onFieldSubmitted: (_) {
                                if (!_busy) _completeByCode();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton(
                            onPressed: _busy ? null : _completeByCode,
                            child: const Text('Complete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('Waiting for pickup (${pending.length})',
                  style: text.titleMedium),
            ),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: EmptyState(
                  icon: Icons.hourglass_empty,
                  message: 'No orders waiting.\nClaims from customers appear here.',
                ),
              ),
            for (final c in pending)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.listingTitle, style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text('${c.userName}  |  code ${c.pickupCode}'),
                            if (c.isNoShow)
                              Text('Pickup window closed',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.error)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _run(() => ListingService.instance
                                .markCollected(c, widget.vendor.uid)),
                        child: const Text('Mark collected'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
