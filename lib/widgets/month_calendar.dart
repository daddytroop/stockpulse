import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Data for one calendar day: aggregated dividends/earnings markers.
class CalendarDay {
  final double dividendTotal;
  final int earningsCount;
  final int eventCount;
  const CalendarDay({
    required this.dividendTotal,
    required this.earningsCount,
    required this.eventCount,
  });
}

/// Month-view calendar with green dots on dividend days and orange dots on
/// earnings days.
///
/// The month is controlled by the parent, so the dots always match the
/// month that is on screen.
class MonthCalendar extends StatelessWidget {
  /// Events for the displayed month, keyed by day of the month.
  final Map<int, CalendarDay> eventsByDay;

  /// Formats the dividend amount shown inside a day cell.
  final String Function(double amount) formatAmount;

  /// Called when a day with events is tapped.
  final void Function(DateTime day)? onSelectDay;

  /// The day that is currently highlighted.
  final DateTime? selectedDay;

  /// The month on screen. Always the first day of that month.
  final DateTime month;

  /// Called when the user moves to another month.
  final void Function(DateTime month)? onMonthChanged;

  const MonthCalendar({
    super.key,
    required this.eventsByDay,
    required this.formatAmount,
    required this.month,
    this.onSelectDay,
    this.selectedDay,
    this.onMonthChanged,
  });

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(month.year, month.month, 1);
    // Monday-based offset
    final lead = (first.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => onMonthChanged?.call(
                  DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Center(
                child: Text(fmtMonthYear(month), style: theme.textTheme.titleSmall),
              ),
            ),
            IconButton(
              onPressed: () => onMonthChanged?.call(
                  DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ],
        ),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text(
                      w,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.95,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: rows * 7,
          itemBuilder: (context, i) {
            final dayNum = i - lead + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox();
            }
            final data = eventsByDay[dayNum];
            final date = DateTime(month.year, month.month, dayNum);
            final isToday = date == today;
            final isSelected = selectedDay != null &&
                selectedDay!.year == date.year &&
                selectedDay!.month == date.month &&
                selectedDay!.day == date.day;

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: data == null ? null : () => onSelectDay?.call(date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.18)
                      : (data != null
                          ? theme.colorScheme.primary.withValues(alpha: 0.06)
                          : null),
                  borderRadius: BorderRadius.circular(10),
                  border: isToday
                      ? Border.all(color: theme.colorScheme.primary, width: 1.4)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isToday ? FontWeight.w800 : null,
                        color: isToday ? theme.colorScheme.primary : null,
                      ),
                    ),
                    if (data != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (data.dividendTotal > 0)
                            _dot(colors.dividend)
                          else if (data.eventCount > 0)
                            _dot(colors.earnings)
                          else
                            _dot(theme.hintColor),
                          if (data.earningsCount > 0) _dot(colors.earnings),
                        ],
                      ),
                      if (data.dividendTotal > 0)
                        Text(
                          formatAmount(data.dividendTotal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: colors.dividend,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(colors.dividend),
            Text(' dividend  ', style: theme.textTheme.labelSmall),
            _dot(colors.earnings),
            Text(' earnings', style: theme.textTheme.labelSmall),
          ],
        ),
        if (!isCurrentMonth) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () =>
                onMonthChanged?.call(DateTime(now.year, now.month)),
            child: const Text('Back to this month'),
          ),
        ],
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
