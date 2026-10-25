import '../models/listing.dart';

/// Assumed average food per portion, used for the "kg saved" estimate.
/// Say in your viva that this is an assumption, not a measurement.
const double kgPerPortion = 0.4;

class ImpactStats {
  final int portionsPosted;
  final int collected; // picked up (rescued)
  final int awaiting; // claimed, window still open
  final int noShow; // claimed, never collected
  final int unclaimedExpired; // portions nobody claimed before closing
  final List<DateTime> days; // last 7 days, oldest first
  final List<int> collectedPerDay;
  final Map<String, int> collectedByType;
  final List<MapEntry<String, int>> topUnclaimed;

  const ImpactStats({
    required this.portionsPosted,
    required this.collected,
    required this.awaiting,
    required this.noShow,
    required this.unclaimedExpired,
    required this.days,
    required this.collectedPerDay,
    required this.collectedByType,
    required this.topUnclaimed,
  });

  double get kgSaved => collected * kgPerPortion;
  double get rescueRate => portionsPosted == 0 ? 0 : collected / portionsPosted;
  int get pieTotal => collected + awaiting + noShow + unclaimedExpired;

  static ImpactStats compute(List<Listing> listings, List<Claim> claims) {
    final now = DateTime.now();

    var posted = 0;
    var unclaimed = 0;
    final unclaimedByTitle = <String, int>{};
    for (final l in listings) {
      posted += l.quantity;
      if (l.isExpired && l.remaining > 0) {
        unclaimed += l.remaining;
        final key = l.title.trim();
        unclaimedByTitle[key] = (unclaimedByTitle[key] ?? 0) + l.remaining;
      }
    }

    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final perDay = List<int>.filled(7, 0);
    final byType = <String, int>{};
    var collected = 0;
    var awaiting = 0;
    var noShow = 0;

    for (final c in claims) {
      if (c.isCollected) {
        collected++;
        byType[c.vendorType] = (byType[c.vendorType] ?? 0) + 1;
        final at = c.collectedAt ?? now;
        final d = DateTime(at.year, at.month, at.day);
        final idx = days.indexWhere((x) => x == d);
        if (idx >= 0) perDay[idx]++;
      } else if (c.isNoShow) {
        noShow++;
      } else {
        awaiting++;
      }
    }

    final top = unclaimedByTitle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ImpactStats(
      portionsPosted: posted,
      collected: collected,
      awaiting: awaiting,
      noShow: noShow,
      unclaimedExpired: unclaimed,
      days: days,
      collectedPerDay: perDay,
      collectedByType: byType,
      topUnclaimed: top.take(3).toList(),
    );
  }
}
