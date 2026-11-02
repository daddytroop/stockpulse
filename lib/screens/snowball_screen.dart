import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/snowball.dart';
import '../widgets/ui/animated_number.dart';
import '../widgets/ui/sp_card.dart';

/// Pro: projects the portfolio's dividend income years ahead.
class SnowballScreen extends StatefulWidget {
  const SnowballScreen({super.key});

  @override
  State<SnowballScreen> createState() => _SnowballScreenState();
}

class _SnowballScreenState extends State<SnowballScreen> {
  int _years = 10;
  double _monthly = 0;
  double _divGrowth = 0.06;
  double _priceGrowth = 0.05;
  bool _reinvest = true;

  /// The yield the user dialled in; null follows the portfolio's own.
  double? _yield;

  /// Used when the portfolio pays nothing yet, so contributions still have
  /// something to compound.
  static const _fallbackYield = 0.03;

  /// Everyday costs the income grows into, smallest first.
  static const _milestones = [
    (label: 'Your streaming subscriptions', icon: Icons.live_tv_rounded, monthly: 30.0),
    (label: 'Your phone bill', icon: Icons.smartphone_rounded, monthly: 75.0),
    (label: 'Your groceries', icon: Icons.shopping_basket_rounded, monthly: 500.0),
    (label: 'Your rent or mortgage', icon: Icons.home_rounded, monthly: 1500.0),
    (label: 'A modest salary', icon: Icons.beach_access_rounded, monthly: 4000.0),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final portfolio = provider.active;
    final totals = provider.totalsFor(portfolio);
    final currency = totals.displayCurrency ??
        (portfolio.holdings.isEmpty ? null : portfolio.holdings.values.first.currency);
    final gross = totals.annualIncome;
    final net = provider.withholdingCountry.isNotEmpty
        ? provider.netAnnualIncomeFor(portfolio)
        : gross;
    final tax = gross > 0 ? (1 - net / gross).clamp(0.0, 1.0) : 0.0;
    final actualYield = totals.marketValue > 0 ? gross / totals.marketValue : 0.0;
    final yieldUsed = _yield ?? (actualYield > 0 ? actualYield : _fallbackYield);

    final years = projectSnowball(SnowballInputs(
      startValue: totals.marketValue,
      startIncome: gross,
      years: _years,
      dividendGrowth: _divGrowth,
      priceGrowth: _priceGrowth,
      reinvest: _reinvest,
      monthlyContribution: _monthly,
      taxRate: tax,
      yieldOverride: yieldUsed,
    ));
    final end = years.last;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    String money(num v) => fmtMoney(v, currency: currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Dividend snowball')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (gross <= 0 && _yield == null)
                SpCard(
                  child: Text(
                    'Your holdings do not pay dividends yet, so this assumes a '
                    '${(_fallbackYield * 100).toStringAsFixed(0)}% yield. Change it under '
                    'Your assumptions to see what dividend payers could grow into.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              SpCard(
                glow: colors.dividend,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IN $_years YEARS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AnimatedNumber(
                              value: end.monthlyIncome,
                              formatter: money,
                              style: theme.textTheme.displayMedium?.copyWith(
                                color: colors.dividend,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 8),
                          child: Text('/ month', style: theme.textTheme.titleMedium),
                        ),
                      ],
                    ),
                    Text(
                      'from ${money(gross / 12)} a month today'
                      '${tax > 0 ? ' · after withholding tax' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(height: 180, child: _IncomeBars(years: years, money: money)),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Portfolio value', value: money(end.value))),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(label: 'You put in', value: money(end.contributed))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      label: _reinvest ? 'Reinvested' : 'Paid out',
                      value: money(_reinvest
                          ? end.reinvested
                          : years.skip(1).fold<double>(0, (s, y) => s + y.income)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your assumptions', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5 yrs')),
                        ButtonSegment(value: 10, label: Text('10 yrs')),
                        ButtonSegment(value: 20, label: Text('20 yrs')),
                        ButtonSegment(value: 30, label: Text('30 yrs')),
                      ],
                      selected: {_years},
                      onSelectionChanged: (s) => setState(() => _years = s.first),
                    ),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: 'Add each month',
                      value: _monthly,
                      display: money(_monthly),
                      max: 2000,
                      divisions: 40,
                      onChanged: (v) => setState(() => _monthly = v),
                    ),
                    _SliderRow(
                      label: _yield == null && actualYield > 0
                          ? 'Dividend yield (yours today)'
                          : 'Dividend yield',
                      value: yieldUsed * 100,
                      display: '${(yieldUsed * 100).toStringAsFixed(1)}%',
                      max: 10,
                      divisions: 100,
                      onChanged: (v) => setState(() => _yield = v / 100),
                    ),
                    _SliderRow(
                      label: 'Dividend growth per year',
                      value: _divGrowth * 100,
                      display: '${(_divGrowth * 100).toStringAsFixed(0)}%',
                      max: 15,
                      divisions: 15,
                      onChanged: (v) => setState(() => _divGrowth = v / 100),
                    ),
                    _SliderRow(
                      label: 'Share price growth per year',
                      value: _priceGrowth * 100,
                      display: '${(_priceGrowth * 100).toStringAsFixed(0)}%',
                      max: 12,
                      divisions: 12,
                      onChanged: (v) => setState(() => _priceGrowth = v / 100),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reinvest dividends'),
                      subtitle: const Text('Buy more shares with every payout'),
                      value: _reinvest,
                      onChanged: (v) => setState(() => _reinvest = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                child: Text('Milestones', style: theme.textTheme.titleMedium),
              ),
              for (final m in _milestones)
                _Milestone(
                  icon: m.icon,
                  label: m.label,
                  monthly: money(m.monthly),
                  reached: firstYearReaching(years, m.monthly),
                  alreadyNow: gross / 12 >= m.monthly,
                  horizon: _years,
                ),
              const SizedBox(height: 12),
              Text(
                'A projection under the fixed assumptions above, starting from today\'s '
                'yield. Real dividends get cut and raised and prices move; this is not '
                'a forecast or investment advice.',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yearly income as glowing bars that rise like a snowball.
class _IncomeBars extends StatelessWidget {
  final List<SnowballYear> years;
  final String Function(num) money;

  const _IncomeBars({required this.years, required this.money});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final shown = years.skip(1).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final maxY = shown.fold<double>(0, (m, y) => max(m, y.income));
    final now = DateTime.now().year;
    final labelEvery = shown.length > 10 ? (shown.length / 5).ceil() : 1;

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY * 1.12,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${now + shown[group.x].year}\n${money(rod.toY)} / yr',
              TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i % labelEvery != labelEvery - 1 && i != shown.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${now + shown[i].year}',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < shown.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: shown[i].income,
                  width: shown.length > 20 ? 6 : 12,
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      colors.dividend.withValues(alpha: .35),
                      colors.dividend,
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SpCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final String display;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.display,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(display,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  )),
            ],
          ),
          Slider(
            value: value.clamp(0, max),
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Milestone extends StatelessWidget {
  final IconData icon;
  final String label;
  final String monthly;
  final SnowballYear? reached;
  final bool alreadyNow;
  final int horizon;

  const _Milestone({
    required this.icon,
    required this.label,
    required this.monthly,
    required this.reached,
    required this.alreadyNow,
    required this.horizon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final done = alreadyNow || reached != null;
    final when = alreadyNow
        ? 'Covered today'
        : reached != null
            ? 'Covered by ${DateTime.now().year + reached!.year}'
            : 'Beyond $horizon years';
    return SpCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (done ? colors.dividend : theme.hintColor).withValues(alpha: .14),
            ),
            child: Icon(icon, size: 19, color: done ? colors.dividend : theme.hintColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('$monthly a month',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
          Text(
            when,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: done ? colors.dividend : theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}
