import 'package:flutter/material.dart';

import '../../models/portfolio.dart';
import '../../providers/portfolio_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../ui/sp_card.dart';

/// A short summary of what changed and what is coming.
///
/// Four things worth knowing at a glance: what the dividends paid out
/// this month, what they have paid out this year, the biggest mover
/// today, and the next event on the calendar.
class WhatsNewCard extends StatelessWidget {
  final PortfolioProvider provider;
  final Portfolio portfolio;
  final String? currency;

  const WhatsNewCard({
    super.key,
    required this.provider,
    required this.portfolio,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final thisMonth = provider.withholdingCountry.isNotEmpty
        ? provider.netDividendsReceivedBetween(portfolio, monthStart, monthEnd)
        : provider.dividendsReceivedBetween(portfolio, monthStart, monthEnd);
    final thisYear = provider.withholdingCountry.isNotEmpty
        ? provider.netDividendsReceivedBetween(
            portfolio, DateTime(now.year, 1, 1), DateTime(now.year, 12, 31, 23, 59, 59))
        : provider.dividendsReceivedThisYear(portfolio);
    final mover = provider.biggestMoverToday(portfolio);
    final next = provider.nextUpcomingAcrossAll();

    return SpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "What's new",
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Block(
                  label: 'Paid this month',
                  value: fmtMoney(thisMonth, currency: currency),
                  hint: provider.withholdingCountry.isNotEmpty
                      ? 'after withholding tax'
                      : (thisMonth > 0 ? 'dividends received' : 'nothing received yet'),
                  color: colors.dividend,
                ),
              ),
              Expanded(
                child: _Block(
                  label: 'Paid this year',
                  value: fmtMoney(thisYear, currency: currency),
                  hint: 'since 1 January',
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (mover != null)
            _Line(
              icon: mover.percent >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: mover.percent >= 0 ? colors.gain : colors.loss,
              label: 'Biggest mover',
              value: '${mover.symbol} ${fmtPct(mover.percent)}',
            ),
          if (next != null) ...[
            const SizedBox(height: 8),
            _Line(
              icon: Icons.event_available_outlined,
              color: colors.dividend,
              label: 'Next dividend',
              value: '${next.symbol} · ${fmtShortDate(next.exDate)}'
                  '${next.estimated ? '*' : ''}',
            ),
          ],
          if (mover == null && next == null)
            Text(
              'Add holdings to see what is moving and what is next.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _Block({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _Line({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
