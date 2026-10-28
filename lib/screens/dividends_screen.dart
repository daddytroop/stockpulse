import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/portfolio.dart';
import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/ad_service.dart';
import '../services/calendar_service.dart';
import '../services/export_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/ad_slot.dart';
import '../widgets/month_calendar.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/ui/animated_number.dart';
import '../widgets/ui/kpi_tile.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/sp_card.dart';
import 'holding_detail_screen.dart';

class _SampleCallout extends StatelessWidget {
  const _SampleCallout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF3A2E10) : const Color(0xFFFFF7D8);
    final fg = isDark ? const Color(0xFFFFE9B3) : const Color(0xFF78350F);
    return SpCard(
      backgroundColor: bg,
      child: Row(children: [
        Icon(Icons.auto_awesome, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'This is demo data. Add or import your holdings to replace it.',
          style: theme.textTheme.bodySmall?.copyWith(color: fg),
        )),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final String value;
  const _HeroPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class DividendsScreen extends StatefulWidget {
  const DividendsScreen({super.key});

  @override
  State<DividendsScreen> createState() => _DividendsScreenState();
}

class _DividendsScreenState extends State<DividendsScreen> {
  DateTime? _selectedDay;

  /// The month the calendar is showing.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PortfolioProvider>().ensureDividendInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final portfolio = provider.active;
    final totals = provider.totalsFor(portfolio);
    final currency = totals.displayCurrency ??
        (portfolio.holdings.isEmpty ? null : portfolio.holdings.values.first.currency);
    final events = provider.upcomingEventsFor([portfolio], horizonDays: 120);
    final next30 = provider.incomeWithinDays(30);
    final colors = AppColors.of(context);

    // Aggregate events per day of the calendar month on screen.
    final eventsByDay = <int, CalendarDay>{};
    for (final e in events) {
      if (e.date.year != _month.year || e.date.month != _month.month) continue;
      final d = eventsByDay[e.date.day] ??
          const CalendarDay(dividendTotal: 0, earningsCount: 0, eventCount: 0);
      if (e.kind == 'dividend' && !e.isPayDate) {
        eventsByDay[e.date.day] = CalendarDay(
          dividendTotal: d.dividendTotal + (e.total ?? 0),
          earningsCount: d.earningsCount,
          eventCount: d.eventCount + 1,
        );
      } else if (e.kind == 'earnings') {
        eventsByDay[e.date.day] = CalendarDay(
          dividendTotal: d.dividendTotal,
          earningsCount: d.earningsCount + 1,
          eventCount: d.eventCount + 1,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        titleSpacing: 20,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Income dashboard', style: Theme.of(context).textTheme.labelSmall),
          Text(portfolio.name),
        ]),
      ),
      body: Stack(
        children: [
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (portfolio.name.startsWith('Sample'))
                const _SampleCallout(),
              if (provider.dividendsLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(value: provider.dividendsProgress, minHeight: 3),
                ),
              _incomeHero(context, provider, portfolio, totals, next30, currency, colors),
              const SizedBox(height: 12),
              _incomeFrequencyGrid(context, provider, portfolio, totals, currency),
              const SizedBox(height: 12),
              SpCard(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: MonthCalendar(
                  eventsByDay: eventsByDay,
                  formatAmount: (a) => fmtMoney(a, currency: currency),
                  selectedDay: _selectedDay,
                  month: _month,
                  onMonthChanged: (m) => setState(() => _month = m),
                  onSelectDay: (d) => _showDay(context, d, events, currency, colors),
                ),
              ),
              const SizedBox(height: 14),
              SectionHeader(
                title: 'Upcoming events',
                subtitle: 'Dividends and earnings · next 120 days',
              ),
              if (events.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Add to my calendar'),
                    onPressed: () => _exportCalendar(context, events, currency),
                  ),
                ),
              ..._upcomingEventList(context, events, currency, colors),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      portfolio.holdings.isEmpty
                          ? 'Add holdings to start tracking dividends.'
                          : 'No dividend payers detected in this portfolio yet.\nOpen a holding to force a dividend data refresh.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  ),
                ),
              if (events.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: Text(
                      '* Estimated from payment cadence. Exact dates are shown when Yahoo publishes them.\n'
                      'Amounts assume current share counts.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              _growthCard(context, provider, portfolio, currency),
              const SizedBox(height: 10),
              _incomeByYear(context, provider, portfolio, currency),
              const AdSlot(
                placement: AdPlacement.dividendsNative,
                native: true,
              ),
            ],
          ),
          )),
        ],
      ),
    );
  }

  Widget _incomeHero(BuildContext context, PortfolioProvider provider, Portfolio portfolio,
      PortfolioTotals totals, double next30, String? currency, AppColors colors) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final monthly = provider.monthlyDividendRateFor(portfolio);
    return SpCard(
      padding: const EdgeInsets.all(22),
      gradient: isDark
          ? [const Color(0xFF06362E), const Color(0xFF101820)]
          : [const Color(0xFFDDF7EA), const Color(0xFFFFFFFF)],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Estimated annual income', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          const Spacer(),
          Icon(Icons.eco_outlined, color: colors.dividend),
        ]),
        const SizedBox(height: 6),
        AnimatedNumber(
          value: totals.annualIncome,
          formatter: (v) => fmtMoney(v, currency: currency),
          duration: const Duration(milliseconds: 900),
          style: theme.textTheme.displayLarge?.copyWith(
            color: colors.dividend,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${fmtPct(totals.incomeYield, signed: false)} yield · about ${fmtMoney(monthly, currency: currency)} each month',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _HeroPill(label: 'Next 30 days', value: fmtMoney(next30, currency: currency)),
          _HeroPill(label: 'Yield on cost', value: fmtPct(totals.yieldOnCost, signed: false)),
          _HeroPill(label: 'Reinvested in 5 years', value: fmtMoney(provider.dripProjectionFor(portfolio), currency: currency)),
        ]),
      ]),
    );
  }

  Widget _incomeFrequencyGrid(BuildContext context, PortfolioProvider provider, Portfolio portfolio,
      PortfolioTotals totals, String? currency) {
    final colors = AppColors.of(context);
    return KpiRow(
      tiles: [
        KpiTile(
          label: 'Annual',
          value: totals.annualIncome,
          formatter: (v) => fmtMoney(v, currency: currency),
          valueColor: colors.dividend,
          icon: Icons.calendar_month_outlined,
          sub: 'Per year, all payers',
        ),
        KpiTile(
          label: 'Quarterly',
          value: provider.quarterlyDividendRateFor(portfolio),
          formatter: (v) => fmtMoney(v, currency: currency),
          icon: Icons.view_week_outlined,
          sub: 'Every 3 months',
        ),
        KpiTile(
          label: 'Monthly',
          value: provider.monthlyDividendRateFor(portfolio),
          formatter: (v) => fmtMoney(v, currency: currency),
          icon: Icons.today_outlined,
          sub: 'Spread monthly',
        ),
        KpiTile(
          label: 'Daily equivalent',
          value: provider.dailyDividendRateFor(portfolio),
          formatter: (v) => fmtMoney(v, currency: currency),
          icon: Icons.bolt_outlined,
          sub: 'If paid daily',
        ),
      ],
    );
  }

  List<Widget> _eventsOn(List<UpcomingEvent> events, DateTime day, String? currency, AppColors colors) {
    final list = [
      for (final e in events)
        if (e.date.year == day.year && e.date.month == day.month && e.date.day == day.day) e
    ];
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            'Nothing scheduled.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ),
      ];
    }
    return [
      for (final e in list)
        SpCard(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: Icon(
              e.kind == 'dividend' ? Icons.payments_outlined : Icons.query_stats_outlined,
              color: e.kind == 'dividend' ? colors.dividend : colors.earnings,
            ),
            title: Text(
              e.symbol,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              e.kind == 'dividend'
                  ? '${e.isPayDate ? 'Payment date' : 'Ex-dividend'}${e.estimated ? ' (est.)' : ''} · ${fmtMoney(e.amountPerShare ?? 0, currency: currency)}/unit'
                  : 'Quarterly earnings report',
            ),
            trailing: e.kind == 'dividend' && (e.total ?? 0) > 0
                ? Text(
                    fmtMoney(e.total, currency: currency),
                    style: TextStyle(
                        color: colors.dividend, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
        ),
    ];
  }

  /// Shows everything scheduled on one calendar day.
  ///
  /// Tapping a day used to change a list far below the fold, so the answer
  /// now appears right where the user tapped.
  void _showDay(BuildContext context, DateTime day, List<UpcomingEvent> events,
      String? currency, AppColors colors) {
    setState(() => _selectedDay = day);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              fmtDate(day),
              style: Theme.of(ctx)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'What is scheduled on this day',
              style: Theme.of(ctx)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(ctx).hintColor),
            ),
            const SizedBox(height: 12),
            ..._eventsOn(events, day, currency, colors),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedDay = null);
    });
  }

  /// The upcoming timeline: dividends and earnings, grouped by month.
  List<Widget> _upcomingEventList(BuildContext context, List<UpcomingEvent> events,
      String? currency, AppColors colors) {
    final theme = Theme.of(context);
    final groups = <String, List<UpcomingEvent>>{};
    final order = <String>[];
    for (final e in events) {
      // The payment date is shown on the ex-dividend row, so it does not
      // need its own entry.
      if (e.kind == 'dividend' && e.isPayDate) continue;
      final key = fmtMonthYear(DateTime(e.date.year, e.date.month));
      groups.putIfAbsent(key, () => []).add(e);
      if (!order.contains(key)) order.add(key);
    }
    if (groups.isEmpty) return const [];

    final widgets = <Widget>[];
    for (final key in order) {
      final list = groups[key]!..sort((a, b) => a.date.compareTo(b.date));
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4, left: 2),
        child: Text(
          key,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ));
      for (final e in list) {
        // The matching payment date, so both dates fit on one row.
        DateTime? payDate;
        if (e.kind == 'dividend') {
          for (final other in events) {
            if (other.kind == 'dividend' &&
                other.isPayDate &&
                other.symbol == e.symbol) {
              payDate = other.date;
              break;
            }
          }
        }
        final isDividend = e.kind == 'dividend';
        widgets.add(SpCard(
          margin: const EdgeInsets.only(bottom: 6),
          onTap: () => _openHolding(context, e.symbol),
          child: Row(
            children: [
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: (isDividend ? colors.dividend : colors.earnings)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${e.date.day}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDividend ? colors.dividend : colors.earnings,
                      ),
                    ),
                    Text(
                      _shortMonth(e.date.month),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(e.symbol,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Icon(
                          isDividend
                              ? Icons.payments_outlined
                              : Icons.query_stats_outlined,
                          size: 13,
                          color: isDividend ? colors.dividend : colors.earnings,
                        ),
                        if (e.estimated) ...[
                          const SizedBox(width: 4),
                          Text('*',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.hintColor)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDividend
                          ? 'Ex-dividend'
                              '${payDate != null ? ' · pays ${fmtShortDate(payDate)}' : ''}'
                              ' · ${fmtMoney(e.amountPerShare ?? 0, currency: currency)}/unit'
                          : 'Earnings report',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (isDividend && (e.total ?? 0) > 0)
                Text(
                  fmtMoney(e.total, currency: currency),
                  style: TextStyle(
                      color: colors.dividend, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ));
      }
    }
    return widgets.animate(
      interval: 30.ms,
      effects: [
        FadeEffect(duration: 250.ms),
        SlideEffect(
            begin: const Offset(0, 0.05), end: Offset.zero, duration: 250.ms),
      ],
    );
  }

  /// Writes the upcoming events to a calendar file the user can open with
  /// their own calendar app.
  Future<void> _exportCalendar(BuildContext context, List<UpcomingEvent> events,
      String? currency) async {
    final ics = CalendarService.buildIcs(events: events, currency: currency);
    if (ics.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No upcoming events to export.'),
      ));
      return;
    }
    final ok = await ExportService.saveOrShare(
      fileName: CalendarService.fileName(),
      content: ics,
      mimeType: 'text/calendar',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (ExportService.clipboardFallbackUsed
              ? 'Calendar copied to the clipboard - paste it into a .ics file.'
              : 'Calendar file ready - open it with your calendar app.')
          : 'Could not export the calendar file.'),
    ));
  }

  void _openHolding(BuildContext context, String symbol) {
    final provider = context.read<PortfolioProvider>();
    for (final p in provider.portfolios) {
      if (p.holdings.containsKey(symbol.toUpperCase())) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HoldingDetailScreen(
              portfolioId: p.id, symbol: symbol.toUpperCase()),
        ));
        return;
      }
    }
  }

  static String _shortMonth(int month) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][(month - 1).clamp(0, 11)];

  Widget _growthCard(
      BuildContext context, PortfolioProvider provider, Portfolio portfolio, String? currency) {
    final theme = Theme.of(context);
    final rows = provider.dividendGrowthRows(portfolio);
    if (rows.isEmpty) return const SizedBox.shrink();
    return SpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Dividend growth (per share, YoY)', padding: const EdgeInsets.only(bottom: 8)),
          const SizedBox(height: 4),
            for (final r in rows.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(r.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      fmtMoney(r.ttmIncome, currency: currency),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 62,
                      child: Text(
                        r.growthPct == null
                            ? '–'
                            : '${r.growthPct! > 0 ? '+' : ''}${r.growthPct!.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: r.growthPct == null
                              ? theme.hintColor
                              : pnlColor(r.growthPct!, context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
    );
  }

  Widget _incomeByYear(BuildContext context, PortfolioProvider provider, Portfolio portfolio,
      String? currency) {
    final byYear = provider.annualIncomeByYearFor(portfolio);
    if (byYear.length < 2) return const SizedBox.shrink();
    return SpCard(
      child: PortfolioChart(
        points: [
          for (final e in byYear.entries) ChartPoint(DateTime(e.key), e.value),
        ],
        title: 'Dividend income by year (est. · current holdings)',
      ),
    );
  }
}