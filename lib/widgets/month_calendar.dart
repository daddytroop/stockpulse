import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Data for one calendar day: aggregated dividends/earnings markers.
class CalendarDay {
  final double dividendTotal;
  final int earningsCount;
  final int eventCount;
  const CalendarDay({required this.dividendTotal, required this.earningsCount, required this.eventCount});
}

/// Month-view calendar with green dots on dividend days and orange dots on
/// earnings days. Parents render the selected day's details below.
class MonthCalendar extends StatefulWidget {
  final Map<int, CalendarDay> eventsByDay; // day-of-month -> data
  final String Function(double amount) formatAmount;
  final void Function(DateTime day)? onSelectDay;
  final DateTime? selectedDay;
  const MonthCalendar({
    super.key,
    required this.eventsByDay,
    required this.formatAmount,
    this.onSelectDay,
    this.selectedDay,
  });

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
    });
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(_month.year, _month.month, 1);
    // Monday-based offset
    final lead = (first.weekday - 1) % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: Text(fmtMonthYear(_month), style: theme.textTheme.titleSmall),
              ),
            ),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
            final data = widget.eventsByDay[dayNum];
            final date = DateTime(_month.year, _month.month, dayNum);
            final isToday = date == today;
            final isSelected = widget.selectedDay != null &&
                widget.selectedDay!.year == date.year &&
                widget.selectedDay!.month == date.month &&
                widget.selectedDay!.day == date.day;

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: data == null ? null : () => widget.onSelectDay?.call(date),
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
                    Text('$dayNum', style: theme.textTheme.bodySmall),
                    if (data != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (data.dividendTotal > 0)
                            _dot(const Color(0xFF2E7D32))
                          else if (data.eventCount > 0)
                            _dot(const Color(0xFFF57C00))
                          else
                            _dot(theme.hintColor),
                          if (data.earningsCount > 0) _dot(const Color(0xFFF57C00)),
                        ],
                      ),
                      if (data.dividendTotal > 0)
                        Text(
                          widget.formatAmount(data.dividendTotal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: const Color(0xFF2E7D32),
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
            _dot(const Color(0xFF2E7D32)),
            Text(' dividend  ', style: theme.textTheme.labelSmall),
            _dot(const Color(0xFFF57C00)),
            Text(' earnings', style: theme.textTheme.labelSmall),
          ],
        ),
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