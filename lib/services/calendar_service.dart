import 'package:intl/intl.dart' show DateFormat;

import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';

/// Builds a calendar file (.ics) of the portfolio's upcoming events.
///
/// The file opens in any calendar app, so the dates land in the calendar
/// the user actually uses rather than only inside the app.
class CalendarService {
  CalendarService._();

  /// Builds an .ics document for the given events.
  ///
  /// Dividend events become all-day entries on the ex-dividend date, with
  /// the payment date in the description. Earnings become all-day entries
  /// on the reporting date.
  static String buildIcs({
    required List<UpcomingEvent> events,
    required String? currency,
    int horizonDays = 365,
  }) {
    final now = DateTime.now();
    final stamp = _stamp(now.toUtc());
    final limit = now.add(Duration(days: horizonDays));

    // The payment date belongs on the ex-dividend entry, not as a second
    // event of its own.
    final payDates = <String, DateTime>{};
    for (final e in events) {
      if (e.kind == 'dividend' && e.isPayDate) {
        payDates[e.symbol] = e.date;
      }
    }

    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Stock Pulse//Dividend and earnings calendar//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:Stock Pulse',
    ];

    var count = 0;
    for (final e in events) {
      if (e.isPayDate) continue;
      if (e.date.isBefore(now) || e.date.isAfter(limit)) continue;
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      final isDividend = e.kind == 'dividend';
      final summary = isDividend
          ? '${e.symbol} dividend'
          : '${e.symbol} earnings';
      final amount = isDividend && (e.amountPerShare ?? 0) > 0
          ? '${fmtMoney(e.amountPerShare, currency: currency)}/share'
          : '';
      final payDate = isDividend ? payDates[e.symbol] : null;
      final notes = isDividend
          ? 'Ex-dividend date'
              '${e.estimated ? ' (estimated from payment cadence)' : ''}'
              '${amount.isEmpty ? '' : ' · $amount'}'
              '${payDate == null ? '' : ' · pays ${DateFormat('d MMM yyyy').format(payDate)}'}'
          : 'Earnings report date';

      lines
        ..add('BEGIN:VEVENT')
        ..add('UID:stockpulse-${e.symbol}-${isDividend ? 'div' : 'earn'}-'
            '${_dayStamp(day)}@stockpulse')
        ..add('DTSTAMP:$stamp')
        ..add('DTSTART;VALUE=DATE:${_dayStamp(day)}')
        ..add('DTEND;VALUE=DATE:${_dayStamp(day.add(const Duration(days: 1)))}')
        ..add('SUMMARY:${_escape(summary)}')
        ..add('DESCRIPTION:${_escape(notes)}')
        ..add('END:VEVENT');
      count++;
    }

    lines.add('END:VCALENDAR');
    if (count == 0) {
      // A calendar file with no events is still valid, but the caller is
      // told so it can explain the empty result.
      return '';
    }
    return '${lines.join('\r\n')}\r\n';
  }

  /// A file name for the exported calendar.
  static String fileName() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'stock-pulse-dividends-$now$m$d.ics';
  }

  static String _dayStamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  static String _stamp(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';

  /// Escapes the characters that would break an iCalendar value.
  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');
}
