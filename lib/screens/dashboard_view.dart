import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/listing.dart';
import '../services/impact.dart';
import '../services/listing_service.dart';
import '../ui.dart';

const _cCollected = Color(0xFF3FA66A);
const _cAwaiting = Color(0xFF2F3C7E);
const _cNoShow = Color(0xFFF9A825);
const _cUnclaimed = Color(0xFFF96167);

/// Food-waste impact dashboard. [vendorId] = one vendor's numbers;
/// null = the whole platform (admin).
class DashboardView extends StatefulWidget {
  final String? vendorId;
  const DashboardView({super.key, required this.vendorId});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final Stream<List<Listing>> _listings = widget.vendorId == null
      ? ListingService.instance.allListings()
      : ListingService.instance.vendorListings(widget.vendorId!);
  late final Stream<List<Claim>> _claims = widget.vendorId == null
      ? ListingService.instance.allClaims()
      : ListingService.instance.vendorClaims(widget.vendorId!);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Listing>>(
      stream: _listings,
      builder: (context, ls) {
        return StreamBuilder<List<Claim>>(
          stream: _claims,
          builder: (context, cs) {
            final err = ls.error ?? cs.error;
            if (err != null) return Center(child: Text('Error: $err'));
            if (!ls.hasData || !cs.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = ImpactStats.compute(ls.data!, cs.data!);
            return _Body(stats: stats, platformWide: widget.vendorId == null);
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  final ImpactStats stats;
  final bool platformWide;
  const _Body({required this.stats, required this.platformWide});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.restaurant,
                value: '${s.collected}',
                label: 'Meals rescued',
                color: _cCollected,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                icon: Icons.scale,
                value: '${s.kgSaved.toStringAsFixed(1)} kg',
                label: 'Food saved (estimate)',
                color: _cAwaiting,
              ),
            ),
          ],
        )),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.percent,
                value: '${(s.rescueRate * 100).round()}%',
                label: 'Of posted portions rescued',
                color: _cNoShow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                icon: Icons.delete_outline,
                value: '${s.unclaimedExpired}',
                label: 'Portions expired unclaimed',
                color: _cUnclaimed,
              ),
            ),
          ],
        )),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Meals collected, last 7 days',
          child: SizedBox(height: 190, child: _WeekBars(stats: s)),
        ),
        _ChartCard(
          title: 'Where portions went',
          child: _OutcomePie(stats: s),
        ),
        if (s.topUnclaimed.isNotEmpty)
          _ChartCard(
            title: 'Most often left unclaimed',
            child: Column(
              children: [
                for (final e in s.topUnclaimed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        Text('${e.value} portions',
                            style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (platformWide) _ChartCard(title: 'Rescued by vendor type', child: _TypeBars(stats: s)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Text(
            'Food saved assumes about ${(kgPerPortion * 1000).round()} g per portion.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  final ImpactStats stats;
  const _WeekBars({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final maxV = s.collectedPerDay.fold<int>(0, (a, b) => a > b ? a : b);
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return BarChart(
      BarChartData(
        maxY: (maxV + 1).toDouble(),
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: hidden,
          topTitles: hidden,
          rightTitles: hidden,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= s.days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${DateFormat('E').format(s.days[i])}\n${s.collectedPerDay[i]}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < s.days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: s.collectedPerDay[i].toDouble(),
                  width: 18,
                  color: _cCollected,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Slice {
  final String label;
  final int count;
  final Color color;
  const _Slice(this.label, this.count, this.color);
}

class _OutcomePie extends StatelessWidget {
  final ImpactStats stats;
  const _OutcomePie({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s.pieTotal == 0) {
      return const SizedBox(
        height: 120,
        child: EmptyState(icon: Icons.pie_chart_outline, message: 'No data yet.'),
      );
    }
    final slices = [
      _Slice('Collected', s.collected, _cCollected),
      _Slice('Awaiting pickup', s.awaiting, _cAwaiting),
      _Slice('Claimed, not collected', s.noShow, _cNoShow),
      _Slice('Expired unclaimed', s.unclaimedExpired, _cUnclaimed),
    ];
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (final sl in slices)
                  if (sl.count > 0)
                    PieChartSectionData(
                      value: sl.count.toDouble(),
                      color: sl.color,
                      title: '${sl.count}',
                      radius: 52,
                      titleStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final sl in slices)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: sl.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('${sl.label} (${sl.count})',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _TypeBars extends StatelessWidget {
  final ImpactStats stats;
  const _TypeBars({required this.stats});

  static const _labels = {
    'canteen': 'Canteens',
    'restaurant': 'Restaurants',
    'bakery': 'Bakeries',
    'dairy': 'Dairies',
  };

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final k in _labels.keys) k: stats.collectedByType[k] ?? 0,
    };
    final maxV = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final e in counts.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 92, child: Text(_labels[e.key]!)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: maxV == 0 ? 0 : e.value / maxV,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    color: _cCollected,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 28,
                  child: Text('${e.value}', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
