import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/listing.dart';
import '../services/auth_service.dart';
import '../services/impact.dart';
import '../services/listing_service.dart';
import '../services/location_service.dart';
import '../services/maps_launcher.dart';
import '../services/notification_service.dart';
import '../ui.dart';
import '../widgets/listing_image.dart';
import 'map_screen.dart';
import 'qr_screen.dart';

class UserHome extends StatefulWidget {
  final AppUser user;
  const UserHome({super.key, required this.user});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.startForConsumer(widget.user);
  }

  @override
  void dispose() {
    NotificationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.user.name.trim().split(' ').first;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: _tab == 0 ? 'Surplus near you' : 'My claims',
            subtitle: first.isEmpty ? 'Rescue food, save money' : 'Hi $first, rescue some food today',
            actions: [
              HeaderIconButton(
                icon: Icons.notifications_active_outlined,
                tooltip: 'Test notification',
                onPressed: () async {
                  try {
                    await NotificationService.instance.showTestNotification();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Test notification requested. Check your notification shade.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Notification test failed: $e'),
                      ),
                    );
                  }
                },
              ),
              AvatarMenu(
                name: widget.user.name,
                onSignOut: AuthService.instance.signOut,
              ),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _FeedTab(user: widget.user),
                _ClaimsTab(user: widget.user),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), label: 'My claims'),
        ],
      ),
    );
  }
}

String _fmtKm(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

class _Row {
  final Listing listing;
  final double? km;
  const _Row(this.listing, this.km);
}

// -------------------------------------------------------------------- feed

class _FeedTab extends StatefulWidget {
  final AppUser user;
  const _FeedTab({required this.user});

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  late final Stream<List<Listing>> _stream = ListingService.instance.activeListings();
  Timer? _ticker;

  Position? _pos;
  String? _locError;
  bool _locating = true;
  double? _radiusKm = 5; // null = any distance
  String _type = 'all'; // all | canteen | restaurant | bakery | dairy
  bool _vegOnly = false;

  @override
  void initState() {
    super.initState();
    _locate();
    // keep "x min left" labels fresh and drop listings that just closed
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final res = await LocationService.instance.current();
    if (!mounted) return;
    setState(() {
      _pos = res.position;
      _locError = res.error;
      _locating = false;
    });
  }

  List<_Row> _rows(List<Listing> items) {
    final out = <_Row>[];
    final p = _pos;
    for (final l in items) {
      if (!l.isAvailable) continue;
      if (_type != 'all' && l.vendorType != _type) continue;
      if (_vegOnly && !l.isVeg) continue;
      double? d;
      if (p != null && l.hasCoords) {
        d = LocationService.distanceKm(p.latitude, p.longitude, l.lat!, l.lng!);
      }
      if (_radiusKm != null && d != null && d > _radiusKm!) continue;
      out.add(_Row(l, d));
    }
    out.sort((a, b) {
      final x = a.km;
      final y = b.km;
      if (x == null && y == null) {
        return a.listing.pickupBy.compareTo(b.listing.pickupBy);
      }
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return out;
  }

  Future<void> _claim(Listing l) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final claimId = await ListingService.instance.claim(l, widget.user);
      nav.push(MaterialPageRoute(builder: (_) => QrScreen(claimId: claimId)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openMap(List<Listing> available) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          listings: available,
          position: _pos,
          onClaim: _claim,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Listing>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final available = snap.data!.where((l) => l.isAvailable).toList();
        final rows = _rows(snap.data!);

        return Column(
          children: [
            if (_locating) const LinearProgressIndicator(minHeight: 2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Map'),
                    onPressed: () => _openMap(available),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const VegBadge(isVeg: true),
                    label: const Text('Veg only'),
                    selected: _vegOnly,
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _vegOnly = v),
                  ),
                  const SizedBox(width: 8),
                  for (final km in const [1.0, 3.0, 5.0, 10.0])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${km.toInt()} km'),
                        selected: _radiusKm == km,
                        onSelected: (_) => setState(() => _radiusKm = km),
                      ),
                    ),
                  ChoiceChip(
                    label: const Text('Any'),
                    selected: _radiusKm == null,
                    onSelected: (_) => setState(() => _radiusKm = null),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  for (final t in const ['all', 'canteen', 'restaurant', 'bakery', 'dairy'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t == 'all' ? 'All' : typeStyle(t).label),
                        avatar: t == 'all' ? null : Text(typeStyle(t).emoji),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                    ),
                ],
              ),
            ),
            if (_pos == null && _locError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_locError Showing all listings.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(onPressed: _locate, child: const Text('Retry')),
                  ],
                ),
              ),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      message:
                          'No surplus food in this range right now.\nTry a bigger radius or check back soon.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _ListingCard(
                        row: rows[i],
                        onClaim: () => _claim(rows[i].listing),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ListingCard extends StatelessWidget {
  final _Row row;
  final VoidCallback onClaim;
  const _ListingCard({required this.row, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final l = row.listing;
    final km = row.km;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final style = typeStyle(l.vendorType);
    final until = DateFormat('h:mm a').format(l.pickupBy);
    final urgent = l.pickupBy.difference(DateTime.now()).inMinutes < 30;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                Positioned.fill(child: ListingImage(listing: l)),
                Positioned(
                  left: 10,
                  top: 10,
                  child: InfoPill(
                    text: style.label,
                    icon: style.icon,
                    background: Colors.white.withValues(alpha: 0.92),
                    foreground: style.color,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: InfoPill(
                    text: l.price == 0 ? 'FREE' : '₹${l.price.toStringAsFixed(0)}',
                    background: l.price == 0 ? kGreen : Colors.white.withValues(alpha: 0.92),
                    foreground: l.price == 0 ? Colors.white : Colors.black87,
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: InfoPill(
                    text: l.timeLeftLabel,
                    icon: Icons.timer_outlined,
                    background: urgent ? scheme.error : Colors.black.withValues(alpha: 0.6),
                    foreground: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VegBadge(isVeg: l.isVeg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${l.vendorName}${km != null ? '  •  ${_fmtKm(km)} away' : ''}',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (l.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(child: Text(l.location, style: text.bodySmall)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Until $until  •  ${l.remaining} left', style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (l.hasCoords)
                      OutlinedButton.icon(
                        onPressed: () => openDirections(l.lat!, l.lng!),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Directions'),
                      ),
                    const Spacer(),
                    FilledButton(onPressed: onClaim, child: const Text('Claim')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ claims

class _ClaimsTab extends StatefulWidget {
  final AppUser user;
  const _ClaimsTab({required this.user});

  @override
  State<_ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<_ClaimsTab> {
  late final Stream<List<Claim>> _stream =
      ListingService.instance.userClaims(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Claim>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final claims = snap.data!;
        if (claims.isEmpty) {
          return const EmptyState(
            icon: Icons.qr_code_2,
            message: 'You haven\'t claimed anything yet.\nHead to the Feed to rescue some food.',
          );
        }
        final rescued = claims.where((c) => c.isCollected).length;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppCard(
              color: scheme.primaryContainer,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.volunteer_activism, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'ve rescued $rescued ${rescued == 1 ? 'meal' : 'meals'}'
                      ' (about ${(rescued * kgPerPortion).toStringAsFixed(1)} kg of food).',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            for (final c in claims) _ClaimTile(claim: c, fmt: fmt),
          ],
        );
      },
    );
  }
}

class _ClaimTile extends StatelessWidget {
  final Claim claim;
  final DateFormat fmt;
  const _ClaimTile({required this.claim, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c = claim;
    final style = typeStyle(c.vendorType);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final InfoPill pill = c.isCollected
        ? const InfoPill(
            text: 'Collected',
            icon: Icons.check,
            background: Color(0xFFDFF3E7),
            foreground: Color(0xFF1F7A47),
          )
        : c.isNoShow
            ? InfoPill(
                text: 'Expired',
                background: scheme.errorContainer,
                foreground: scheme.onErrorContainer,
              )
            : InfoPill(
                text: 'Show pass',
                icon: Icons.qr_code_2,
                background: scheme.primaryContainer,
                foreground: scheme.onPrimaryContainer,
              );

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QrScreen(claimId: c.id)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(style.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.listingTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(c.vendorName, style: text.bodySmall),
                Text(fmt.format(c.createdAt),
                    style: text.bodySmall?.copyWith(color: scheme.outline)),
              ],
            ),
          ),
          pill,
        ],
      ),
    );
  }
}
