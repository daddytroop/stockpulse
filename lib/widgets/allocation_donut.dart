import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';

/// Donut of portfolio value grouped by asset type or currency (Phase 3:
/// allocation analysis). Values are FX-converted when a display currency
/// is active; labels show the slice share when it is large enough.
class AllocationDonut extends StatelessWidget {
  final List<AllocationSlice> slices;
  final String? currency;
  const AllocationDonut({super.key, required this.slices, this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (slices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Add holdings to see allocation',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    final total = slices.fold<double>(0, (s, x) => s + x.value);
    // Cap tiny slices so the ring stays readable.
    final shown = slices.take(6).toList();
    if (slices.length > 6) {
      final rest = slices.skip(6).fold<double>(0, (s, x) => s + x.value);
      shown.add(AllocationSlice(label: 'Other', value: rest, color: const Color(0xFF90A4AE)));
    }

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    for (final s in shown)
                      PieChartSectionData(
                        value: s.value,
                        color: s.color,
                        radius: 52,
                        showTitle: total > 0 && s.value / total > 0.07,
                        title: '${(total > 0 ? s.value / total * 100 : 0).round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: theme.textTheme.labelSmall),
                  Text(
                    fmtMoney(total, currency: currency),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final s in shown)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${s.label} · ${fmtMoney(s.value, currency: currency)}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}