import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/providers/portfolio_provider.dart';
import 'package:stock_pulse/services/calendar_service.dart';

UpcomingEvent _event({
  String symbol = 'RY.TO',
  String kind = 'dividend',
  DateTime? date,
  double? amountPerShare = 0.85,
  bool estimated = true,
  bool isPayDate = false,
}) {
  final now = DateTime.now();
  return UpcomingEvent(
    symbol: symbol,
    kind: kind,
    date: date ?? DateTime(now.year, now.month, now.day + 5),
    amountPerShare: amountPerShare,
    total: amountPerShare == null ? null : amountPerShare * 10,
    estimated: estimated,
    isPayDate: isPayDate,
  );
}

void main() {
  group('calendar export', () {
    test('an empty list produces no file', () {
      expect(CalendarService.buildIcs(events: const [], currency: 'CAD'), '');
    });

    test('past events are left out', () {
      final past = _event(date: DateTime.now().subtract(const Duration(days: 10)));
      expect(CalendarService.buildIcs(events: [past], currency: 'CAD'), '');
    });

    test('a dividend becomes an all-day event', () {
      final ics = CalendarService.buildIcs(
        events: [_event(date: DateTime(2026, 11, 5))],
        currency: 'CAD',
      );
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261105'));
      expect(ics, contains('DTEND;VALUE=DATE:20261106'));
      expect(ics, contains('SUMMARY:RY.TO dividend'));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('earnings are included as their own event', () {
      final ics = CalendarService.buildIcs(
        events: [
          _event(symbol: 'AAPL', kind: 'earnings', date: DateTime(2026, 11, 6)),
        ],
        currency: 'USD',
      );
      expect(ics, contains('SUMMARY:AAPL earnings'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261106'));
    });

    test('a payment date is not a second event', () {
      final ics = CalendarService.buildIcs(
        events: [
          _event(date: DateTime(2026, 11, 5)),
          _event(date: DateTime(2026, 11, 20), isPayDate: true),
        ],
        currency: 'CAD',
      );
      expect('BEGIN:VEVENT'.allMatches(ics).length, 1);
      // The payment date is described on the ex-dividend entry.
      expect(ics, contains('pays 20 Nov 2026'));
    });

    test('special characters are escaped', () {
      final ics = CalendarService.buildIcs(
        events: [_event(symbol: 'A,B;C')],
        currency: 'USD',
      );
      expect(ics, contains('SUMMARY:A\\,B\\;C dividend'));
    });

    test('the file name ends in .ics', () {
      expect(CalendarService.fileName().endsWith('.ics'), isTrue);
    });
  });
}
