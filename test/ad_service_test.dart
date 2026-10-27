import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/services/ad_service.dart';

void main() {
  group('AdPlacement', () {
    test('each placement has a unique id', () {
      final ids = AdPlacement.values.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every placement has a human readable label', () {
      for (final p in AdPlacement.values) {
        expect(p.label, isNotEmpty);
      }
    });
  });

  group('AdUnits', () {
    test('every placement resolves to an ad unit', () {
      for (final p in AdPlacement.values) {
        expect(AdUnits.forPlacement(p), isNotEmpty);
        expect(AdUnits.forPlacement(p), contains('ca-app-pub-'));
      }
    });

    test('test units are the Google sample units', () {
      expect(
        AdUnits.test[AdPlacement.holdingsNative],
        startsWith('ca-app-pub-3940256099942544/'),
      );
    });
  });

  group('AdImpression', () {
    test('roundtrips through a map', () {
      final impression = AdImpression(
        placement: AdPlacement.newsNative,
        at: DateTime(2026, 10, 27, 12),
        revenueMicros: 1234,
        clicked: true,
      );
      final back = AdImpression.fromMap(impression.toMap());
      expect(back.placement, AdPlacement.newsNative);
      expect(back.revenueMicros, 1234);
      expect(back.clicked, isTrue);
      expect(back.at, impression.at);
    });

    test('an unknown placement falls back rather than throwing', () {
      final back = AdImpression.fromMap({
        'placement': 'something_new',
        'at': '2026-10-27T12:00:00.000',
      });
      expect(back.placement, isNotNull);
    });
  });

  group('AdPlacementStats', () {
    test('click-through rate is impressions based', () {
      const stats = AdPlacementStats(impressions: 200, clicks: 5);
      expect(stats.ctr, closeTo(0.025, 0.0001));
    });

    test('no impressions means no click-through rate', () {
      const stats = AdPlacementStats();
      expect(stats.ctr, 0);
    });

    test('revenue converts from micros to dollars', () {
      const stats = AdPlacementStats(impressions: 1, revenueMicros: 1500000);
      expect(stats.revenueDollars, closeTo(1.5, 0.0001));
    });
  });
}
