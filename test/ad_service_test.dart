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
    test('every placement resolves to a test unit in debug', () {
      for (final p in AdPlacement.values) {
        expect(AdUnits.forPlacement(p, const {}), isNotEmpty);
        expect(AdUnits.forPlacement(p, const {}), contains('ca-app-pub-'));
      }
    });

    test('test units are the Google sample units', () {
      expect(
        AdUnits.test[AdPlacement.holdingsNative],
        startsWith('ca-app-pub-3940256099942544/'),
      );
    });

    test('the default banner unit is set', () {
      expect(AdUnits.defaultBanner, contains('ca-app-pub-'));
    });

    test('the default native unit is set', () {
      expect(AdUnits.defaultNative, contains('ca-app-pub-'));
    });

    test('every placement has a release unit', () {
      for (final p in AdPlacement.values) {
        final unit = AdUnits.releaseUnitFor(p, const {});
        expect(unit, isNotEmpty, reason: '${p.id} has no release ad unit');
        expect(unit, contains('ca-app-pub-'));
        // An ad unit is publisher/slash-id, never the app id form.
        expect(unit, isNot(contains('~')));
      }
    });

    test('native placements use the native unit', () {
      for (final p in [
        AdPlacement.holdingsNative,
        AdPlacement.newsNative,
        AdPlacement.newsArticle,
        AdPlacement.dividendsNative,
      ]) {
        expect(AdUnits.releaseUnitFor(p, const {}), AdUnits.defaultNative);
      }
      expect(
        AdUnits.releaseUnitFor(AdPlacement.portfolioBanner, const {}),
        AdUnits.defaultBanner,
      );
    });

    test('a configured unit overrides the default', () {
      const custom = 'ca-app-pub-1234567890/1111111111';
      expect(
        AdUnits.releaseUnitFor(
            AdPlacement.newsArticle, const {AdPlacement.newsArticle: custom}),
        custom,
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

  group('frequency caps', () {
    test('every placement has a daily cap', () {
      for (final p in AdPlacement.values) {
        expect(AdService.dailyCap[p], isNotNull);
        expect(AdService.dailyCap[p]!, greaterThan(0));
      }
    });

    test('native placements are capped lower than banners', () {
      expect(
        AdService.dailyCap[AdPlacement.holdingsNative]!,
        lessThan(AdService.dailyCap[AdPlacement.portfolioBanner]!),
      );
    });

    test('the session cap is a positive number', () {
      expect(AdService.sessionCap, greaterThan(0));
    });
  });
}
