import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
    final colors = AppColors.of(context);
    // The neon theme recolours the slices from its own glowing palette.
    final neon = AppTheme.isNeon(theme);
    // Cap tiny slices so the ring stays readable.
    final shown = <AllocationSlice>[
      for (var i = 0; i < slices.length && i < 6; i++)
        neon
            ? AllocationSlice(
                label: slices[i].label,
                value: slices[i].value,
                color: colors.allocationPalette[i % colors.allocationPalette.length],
              )
            : slices[i],
    ];
    if (slices.length > 6) {
      final rest = slices.skip(6).fold<double>(0, (s, x) => s + x.value);
      shown.add(AllocationSlice(label: 'Other', value: rest, color: colors.other));
    }
    String pct(double v) => '${(total > 0 ? v / total * 100 : 0).round()}%';

    return Column(
      children: [
        SizedBox(
          height: 180,
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
                        radius: 20,
                        showTitle: false,
                        borderSide: BorderSide(
                          color: s.color.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                  ],
                  sectionsSpace: 3,
                  centerSpaceRadius: 64,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmtMoney(total, currency: currency),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // The legend doubles as the breakdown: share and value per slice.
        for (final s in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: s.color.withValues(alpha: 0.6), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  fmtMoney(s.value, currency: currency),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    pct(s.value),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}