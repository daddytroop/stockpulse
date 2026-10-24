import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';
import '../widgets/month_calendar.dart';
import '../widgets/stat_cards.dart';

class DividendsScreen extends StatefulWidget {
  const DividendsScreen({super.key});

  @override
  State<DividendsScreen> createState() => _DividendsScreenState();
}

class _DividendsScreenState extends State<DividendsScreen> {
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
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
    final currency =
        portfolio.holdings.isEmpty ? null : portfolio.holdings.values.first.currency;
    final events = provider.upcomingEventsFor([portfolio], horizonDays: 120);
    final next30 = provider.incomeWithinDays(30);

    // Aggregate events per day of the CURRENT calendar month.
    final now = DateTime.now();
    final eventsByDay = <int, CalendarDay>{};
    for (final e in events) {
      if (e.date.year != now.year || e.date.month != now.month) continue;
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

    final upcoming = [
      for (final up in provider.upcomingDividendsFor(portfolio, horizonDays: 120)) up
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Dividends · ${portfolio.name}'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            children: [
              if (provider.dividendsLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(value: provider.dividendsProgress, minHeight: 3),
                ),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Annual income (est.)',
                      value: fmtMoney(totals.annualIncome, currency: currency),
                      valueColor: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Next 30 days',
                      value: fmtMoney(next30, currency: currency),
                      sub: upcoming.isNotEmpty
                          ? 'next: ${upcoming.first.symbol}'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Portfolio yield',
                      value: fmtPct(totals.incomeYield, signed: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Yield on cost',
                      value: fmtPct(totals.yieldOnCost, signed: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: MonthCalendar(
                    eventsByDay: eventsByDay,
                    formatAmount: (a) => fmtMoney(a, currency: currency),
                    selectedDay: _selectedDay,
                    onSelectDay: (d) => setState(() => _selectedDay = d),
                  ),
                ),
              ),
              if (_selectedDay != null) ...[
                const SizedBox(height: 10),
                _sectionTitle(context, 'Events on ${fmtDate(_selectedDay)}'),
                ..._eventsOn(events, _selectedDay!, currency),
              ],
              if (_selectedDay == null) ...[
                const SizedBox(height: 10),
                _sectionTitle(context, 'Upcoming dividends'),
              ],
              ..._upcomingTiles(context, upcoming, currency),
              if (!provider.dividendsLoading && upcoming.isEmpty)
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
              if (upcoming.isNotEmpty)
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
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _eventsOn(List<UpcomingEvent> events, DateTime day, String? currency) {
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
        ListTile(
          dense: true,
          leading: Icon(
            e.kind == 'dividend' ? Icons.payments_outlined : Icons.query_stats_outlined,
            color: e.kind == 'dividend' ? const Color(0xFF2E7D32) : const Color(0xFFF57C00),
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
                  style: const TextStyle(
                      color: Color(0xFF2E7D32), fontWeight: FontWeight.w700),
                )
              : null,
        ),
    ];
  }

  List<Widget> _upcomingTiles(
      BuildContext context, List<dynamic> upcoming, String? currency) {
    final theme = Theme.of(context);
    return [
      for (final up in upcoming.take(10))
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.event_available_outlined, color: Color(0xFF2E7D32)),
            title: Row(
              children: [
                Text(up.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (up.estimated) ...[
                  const SizedBox(width: 6),
                  Text('*est.', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                ],
              ],
            ),
            subtitle: Text(
              'ex ${fmtShortDate(up.exDate)} · pays ${fmtShortDate(up.payDate)}'
              ' · ${fmtMoney(up.amountPerShare, currency: currency)}/unit',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              fmtMoney(up.total, currency: currency),
              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700),
            ),
          ),
        ),
    ];
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}