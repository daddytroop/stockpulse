import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/platform_check.dart';
import '../services/store.dart';

/// Where an ad can appear.
///
/// Each placement has its own ad unit so the AdMob console reports revenue
/// per placement. That is what makes it possible to learn which placement
/// actually earns, instead of guessing.
enum AdPlacement {
  /// A native card inside the holdings list.
  holdingsNative('holdings_native'),

  /// A native card inside the news feed.
  newsNative('news_native'),

  /// A banner at the end of the portfolio screen.
  portfolioBanner('portfolio_banner'),

  /// A native card on the dividends screen.
  dividendsNative('dividends_native');

  const AdPlacement(this.id);

  /// Stable identifier used for reporting and the placement log.
  final String id;

  /// Human readable name.
  String get label => switch (this) {
        AdPlacement.holdingsNative => 'Holdings list',
        AdPlacement.newsNative => 'News feed',
        AdPlacement.portfolioBanner => 'Portfolio footer',
        AdPlacement.dividendsNative => 'Dividends screen',
      };
}

/// Ad unit identifiers.
///
/// Release units are configured in the AdMob console. The debug units below
/// are Google's public test units, so a debug build always exercises the same
/// code path without spending real impressions.
class AdUnits {
  AdUnits._();

  static const String _publisher = 'ca-app-pub-2085007206942111';

  /// Ad unit for each placement in release builds.
  static const Map<AdPlacement, String> release = {
    AdPlacement.holdingsNative: '$_publisher/8657501940',
    AdPlacement.newsNative: '$_publisher/8657501940',
    AdPlacement.portfolioBanner: '$_publisher/8657501940',
    AdPlacement.dividendsNative: '$_publisher/8657501940',
  };

  /// Google's test ad units, used in debug and profile builds.
  static const Map<AdPlacement, String> test = {
    AdPlacement.holdingsNative: 'ca-app-pub-3940256099942544/6300978111',
    AdPlacement.newsNative: 'ca-app-pub-3940256099942544/6300978111',
    AdPlacement.portfolioBanner: 'ca-app-pub-3940256099942544/6300978111',
    AdPlacement.dividendsNative: 'ca-app-pub-3940256099942544/6300978111',
  };

  static String forPlacement(AdPlacement placement) =>
      (kReleaseMode ? release : test)[placement] ??
      (kReleaseMode ? release : test)[AdPlacement.portfolioBanner]!;
}

/// A record of one ad impression, kept locally so the user can see how the
/// placements are performing without sending anything to a server.
class AdImpression {
  final AdPlacement placement;
  final DateTime at;
  final double revenueMicros;
  final bool clicked;

  const AdImpression({
    required this.placement,
    required this.at,
    this.revenueMicros = 0,
    this.clicked = false,
  });

  Map<String, dynamic> toMap() => {
        'placement': placement.id,
        'at': at.toIso8601String(),
        'revenueMicros': revenueMicros,
        'clicked': clicked,
      };

  static AdImpression fromMap(Map<String, dynamic> m) {
    final id = m['placement'] as String? ?? '';
    return AdImpression(
      placement: AdPlacement.values.firstWhere(
        (p) => p.id == id,
        orElse: () => AdPlacement.portfolioBanner,
      ),
      at: DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime.now(),
      revenueMicros: (m['revenueMicros'] as num?)?.toDouble() ?? 0,
      clicked: m['clicked'] as bool? ?? false,
    );
  }
}

/// What we know about one placement's performance.
class AdPlacementStats {
  final int impressions;
  final int clicks;
  final double revenueMicros;

  const AdPlacementStats({
    this.impressions = 0,
    this.clicks = 0,
    this.revenueMicros = 0,
  });

  double get ctr => impressions == 0 ? 0 : clicks / impressions;

  /// Estimated earnings in dollars.
  double get revenueDollars => revenueMicros / 1000000;
}

/// Owns ad loading, consent and a local log of how each placement performs.
///
/// The rules that keep ads from annoying people:
///  * ads never block content, and a failed ad collapses to nothing,
///  * a placement is only shown once the user has scrolled past the content
///    it follows, so an ad is never pushed at someone,
///  * native ads are labelled as ads,
///  * the user can turn ads off entirely in Settings.
class AdService extends ChangeNotifier {
  AdService({StockPulseStore? store})
      : _store = store ?? StockPulseStore();

  static const String _logFile = 'stockpulse_ads.json';
  static const int _maxLoggedImpressions = 400;

  final StockPulseStore _store;

  /// Latest impression per placement, used to avoid stacking two of the
  /// same ad in a row.
  final Map<AdPlacement, DateTime> _lastShown = {};

  final List<AdImpression> _log = [];

  bool _initialized = false;
  bool _adsAllowed = true;
  bool _privacyRequired = false;

  /// Set by the user in Settings.
  bool _enabled = true;

  AdPlacementStats statsFor(AdPlacement placement) {
    var impressions = 0, clicks = 0;
    var revenue = 0.0;
    for (final i in _log) {
      if (i.placement != placement) continue;
      impressions++;
      if (i.clicked) clicks++;
      revenue += i.revenueMicros;
    }
    return AdPlacementStats(
      impressions: impressions,
      clicks: clicks,
      revenueMicros: revenue,
    );
  }

  List<AdImpression> get log => List.unmodifiable(_log);

  /// Whether the user has switched ads off.
  bool get adsEnabled => _enabled;

  /// Whether the SDK currently allows ad requests.
  bool get canRequestAds => _adsAllowed && _enabled;

  /// Whether the user must be offered a privacy-options form.
  bool get privacyOptionsRequired => _privacyRequired;

  /// Whether ads are supported at all on this platform.
  bool get supported => isAndroidPlatform;

  Future<void> load() async {
    final data = await _store.load(_logFile);
    if (data != null) {
      _enabled = data['enabled'] as bool? ?? true;
      for (final raw in (data['log'] as List? ?? const [])) {
        if (raw is Map<String, dynamic>) _log.add(AdImpression.fromMap(raw));
      }
    }
    if (isAndroidPlatform) await _initAds();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.save(_logFile, {
      'enabled': _enabled,
      'log': [for (final i in _log) i.toMap()],
    });
  }

  Future<void> _initAds() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => _checkConsent(),
        (error) {
          if (kDebugMode) debugPrint('Consent update failed: ${error.message}');
          _checkConsent();
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Ad init failed: $e');
    }
  }

  Future<void> _checkConsent() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyRequired =
          status == PrivacyOptionsRequirementStatus.required;
      _adsAllowed = await ConsentInformation.instance.canRequestAds();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Consent check failed: $e');
    }
  }

  /// Opens the privacy options form so the user can change their choices.
  Future<void> showPrivacyOptions() async {
    if (!isAndroidPlatform) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null && kDebugMode) {
          debugPrint('Privacy options form failed: ${error.message}');
        }
        _checkConsent();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Privacy options unavailable: $e');
    }
  }

  /// Whether a placement may show right now.
  ///
  /// [minGap] keeps the same placement from appearing twice in quick
  /// succession, which is the fastest way to make an app feel ad-ridden.
  bool canShow(AdPlacement placement, {Duration minGap = const Duration(minutes: 3)}) {
    if (!supported || !canRequestAds) return false;
    final last = _lastShown[placement];
    if (last != null && DateTime.now().difference(last) < minGap) return false;
    return true;
  }

  /// Records that a placement was shown.
  void recordImpression(
    AdPlacement placement, {
    double revenueMicros = 0,
    bool clicked = false,
  }) {
    _lastShown[placement] = DateTime.now();
    _log.add(AdImpression(
      placement: placement,
      at: DateTime.now(),
      revenueMicros: revenueMicros,
      clicked: clicked,
    ));
    if (_log.length > _maxLoggedImpressions) {
      _log.removeRange(0, _log.length - _maxLoggedImpressions);
    }
    _persist();
    notifyListeners();
  }
}
