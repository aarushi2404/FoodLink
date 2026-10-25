import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/listing.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../services/notification_service.dart';
import '../ui.dart';
import '../widgets/listing_image.dart';
import 'dashboard_view.dart';
import 'post_listing_screen.dart';
import 'scan_screen.dart';
import 'vendor_pickups.dart';

class VendorHome extends StatefulWidget {
  final AppUser vendor;

  const VendorHome({super.key, required this.vendor});

  @override
  State<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<VendorHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.startForVendor(widget.vendor);
  }

  @override
  void dispose() {
    NotificationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _ListingsTab(vendor: widget.vendor),
      VendorPickups(vendor: widget.vendor),
      DashboardView(vendorId: widget.vendor.uid),
    ];

    final titles = ['My listings', 'Pickups', 'Impact'];

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: titles[_tab],
            subtitle:
            '${widget.vendor.name}  •  ${typeStyle(widget.vendor.vendorType).label}',
            actions: [
              HeaderIconButton(
                icon: Icons.qr_code_scanner,
                tooltip: 'Scan pickup QR (needs a camera)',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanScreen(vendor: widget.vendor),
                  ),
                ),
              ),
              AvatarMenu(
                name: widget.vendor.name,
                onSignOut: AuthService.instance.signOut,
              ),
            ],
          ),
          Expanded(child: tabs[_tab]),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Post surplus'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostListingScreen(vendor: widget.vendor),
          ),
        ),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Listings',
          ),
          NavigationDestination(
            icon: Icon(Icons.how_to_reg),
            label: 'Pickups',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights),
            label: 'Impact',
          ),
        ],
      ),
    );
  }
}

class _ListingsTab extends StatefulWidget {
  final AppUser vendor;

  const _ListingsTab({required this.vendor});

  @override
  State<_ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends State<_ListingsTab> {
  late final Stream<List<Listing>> _stream =
  ListingService.instance.vendorListings(widget.vendor.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Listing>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load listings:\n${snap.error}'),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data!;

        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.restaurant_menu,
            message:
            'No listings yet.\nTap "Post surplus" to share food before it goes to waste.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: items.length,
          itemBuilder: (_, i) => _VendorListingCard(listing: items[i]),
        );
      },
    );
  }
}

class _VendorListingCard extends StatelessWidget {
  final Listing listing;

  const _VendorListingCard({required this.listing});

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing?'),
        content: const Text(
          'Existing claims will still be honoured at pickup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ListingService.instance.deleteListing(listing);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    final live = listing.isAvailable;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            height: 125,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ListingImage(listing: listing),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VegBadge(isVeg: listing.isVeg),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete listing',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context),
                      ),
                    ],
                  ),
                  Text(
                    '${listing.remaining}/${listing.quantity} left  •  '
                        '${listing.price == 0 ? 'Free' : '₹${listing.price.toStringAsFixed(0)}'}',
                    style: text.bodySmall,
                  ),
                  Text(
                    'By ${fmt.format(listing.pickupBy)}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InfoPill(
                    text: live ? 'Live' : 'Closed',
                    background: live
                        ? const Color(0xFFDFF3E7)
                        : scheme.surfaceContainerHighest,
                    foreground: live
                        ? const Color(0xFF1F7A47)
                        : scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
