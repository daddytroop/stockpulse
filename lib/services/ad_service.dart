import 'dart:async';

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

  /// A native card inside an opened news story.
  newsArticle('news_article'),

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
        AdPlacement.newsArticle => 'Article view',
        AdPlacement.portfolioBanner => 'Portfolio footer',
        AdPlacement.dividendsNative => 'Dividends screen',
      };
}

/// Whether a release build should serve live ads.
///
/// Live ads are the default, because AdMob does not serve ads to an app it
/// has not approved yet - the real ad units simply come back empty until
/// the review passes, and then they start working on their own with no new
/// build.
///
/// The one thing to avoid is clicking a real ad on your own phone. Either
/// register the device in AdMob (AdMob → Device management → Register
/// device), which makes the SDK serve test ads to it automatically, or use
/// the "test ads on this device" switch in the developer panel.
const bool kAdsLive = bool.fromEnvironment('ADS_LIVE', defaultValue: true);

/// Ad unit identifiers.
///
/// The banner and the native unit below belong to this app's AdMob
/// account. A different unit can be pointed at any placement from the
/// hidden developer panel in Settings, which is how a new placement is
/// tested without a rebuild.
///
/// An empty unit simply means that placement shows nothing - it never
/// causes a failed request.
class AdUnits {
  AdUnits._();

  static const String _publisher = 'ca-app-pub-2085007206942111';

  /// The banner ad unit that ships with the app.
  static const String defaultBanner = '$_publisher/8657501940';

  /// The native ad unit used by every native placement.
  ///
  /// One unit can serve several placements; AdMob then reports them
  /// together, while the app's own placement report still separates them.
  /// Separate units per placement are better for ranking them, so create
  /// more in the console and point the placements at them when you have
  /// them.
  static const String defaultNative = '$_publisher/4150586198';

  /// The rewarded unit behind "watch an ad to try a Pro feature for 24
  /// hours". Create a Rewarded ad unit in AdMob and paste its id here; while
  /// it is empty, release builds simply do not offer the ad.
  static const String rewarded = '';

  /// Google's public rewarded test unit.
  static const String rewardedTest = 'ca-app-pub-3940256099942544/5224354917';

  /// Google's public test units, used in debug and profile builds.
  /// The native placements need Google's *native* test unit: a banner
  /// unit cannot serve a native ad, so test ads would never appear.
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testNative = 'ca-app-pub-3940256099942544/2247696110';

  static const Map<AdPlacement, String> test = {
    AdPlacement.holdingsNative: _testNative,
    AdPlacement.newsNative: _testNative,
    AdPlacement.newsArticle: _testNative,
    AdPlacement.portfolioBanner: _testBanner,
    AdPlacement.dividendsNative: _testNative,
  };

  /// The ad unit used for a placement in release builds.
  static String forPlacement(
    AdPlacement placement,
    Map<AdPlacement, String> configured,
  ) {
    if (!kReleaseMode || !kAdsLive) {
      return test[placement] ?? test[AdPlacement.portfolioBanner]!;
    }
    return releaseUnitFor(placement, configured);
  }

  /// The release-build unit for a placement.
  ///
  /// A configured unit always wins, so a placement can be pointed at a
  /// different ad unit without a rebuild.
  static String releaseUnitFor(
    AdPlacement placement,
    Map<AdPlacement, String> configured,
  ) {
    final custom = configured[placement];
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    switch (placement) {
      case AdPlacement.portfolioBanner:
        return defaultBanner;
      case AdPlacement.holdingsNative:
      case AdPlacement.newsNative:
      case AdPlacement.newsArticle:
      case AdPlacement.dividendsNative:
        return defaultNative;
    }
  }
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
///  * a placement is capped per day and per session, so the app cannot
///    turn into a slot machine,
///  * native ads are labelled as ads,
///  * the user can turn ads off entirely in Settings.
class AdService extends ChangeNotifier {
  AdService({StockPulseStore? store})
      : _store = store ?? StockPulseStore();

  static const String _logFile = 'stockpulse_ads.json';
  static const int _maxLoggedImpressions = 400;

  /// How many impressions a single placement may serve in one day.
  ///
  /// Native placements are capped lower because they are larger and more
  /// noticeable than a small banner.
  static const Map<AdPlacement, int> dailyCap = {
    AdPlacement.holdingsNative: 4,
    AdPlacement.newsNative: 6,
    AdPlacement.newsArticle: 4,
    AdPlacement.dividendsNative: 3,
    AdPlacement.portfolioBanner: 8,
  };

  /// How many impressions any placement may serve in one app session.
  static const int sessionCap = 10;

  final StockPulseStore _store;

  /// Latest impression per placement, used to avoid stacking two of the
  /// same ad in a row.
  final Map<AdPlacement, DateTime> _lastShown = {};

  final List<AdImpression> _log = [];

  bool _initialized = false;
  bool _adsAllowed = true;
  bool _privacyRequired = false;

  /// Impressions served during this app session.
  int _sessionImpressions = 0;

  /// Ad units the user has configured per placement.
  final Map<AdPlacement, String> _adUnits = {};

  /// The last load failure per placement, for the developer panel.
  final Map<AdPlacement, String> _lastErrors = {};

  /// The ad unit configured for a placement, if any.
  String adUnitFor(AdPlacement placement) {
    if (useTestAds) return AdUnits.test[placement] ?? AdUnits.test[AdPlacement.portfolioBanner]!;
    return AdUnits.forPlacement(placement, _adUnits);
  }

  /// Whether this device is served Google's test ads instead of live ones.
  ///
  /// Useful on the developer's own phone: it means a real ad can never be
  /// clicked by accident, which is the one thing that can get an AdMob
  /// account flagged. Other devices are unaffected.
  bool get useTestAds => _useTestAds;
  bool _useTestAds = false;

  /// Turns the test ads on or off for this device only.
  Future<void> setUseTestAds(bool value) async {
    if (_useTestAds == value) return;
    _useTestAds = value;
    await _persist();
    notifyListeners();
  }

  /// The last error a placement reported, if any.
  String? lastErrorFor(AdPlacement placement) => _lastErrors[placement];

  /// Records a load failure so the developer panel can explain a blank slot.
  void reportError(AdPlacement placement, String message) {
    _lastErrors[placement] = message;
    if (kDebugMode) debugPrint('Ad failed (${placement.id}): $message');
  }

  /// Clears the recorded failure for a placement.
  void clearError(AdPlacement placement) => _lastErrors.remove(placement);

  /// Configures the ad unit for a placement. An empty value clears it.
  Future<void> setAdUnit(AdPlacement placement, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _adUnits.remove(placement);
    } else {
      _adUnits[placement] = trimmed;
    }
    _lastErrors.remove(placement);
    await _persist();
    notifyListeners();
  }

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

  /// Whether the SDK currently allows ad requests.
  ///
  /// There is no switch to turn ads off: the free app is paid for by ads,
  /// and buying Pro is how to remove them ([setAdFree]). What every user
  /// *can* control is consent - the privacy options form - which is a
  /// different thing and is required.
  bool get canRequestAds => _adsAllowed;

  /// Whether the user has Pro, which removes every ad.
  bool get adFree => _adFree;
  bool _adFree = false;

  /// Follows the Pro status. Slots already on screen collapse at once.
  void setAdFree(bool value) {
    if (_adFree == value) return;
    _adFree = value;
    notifyListeners();
  }

  /// The rewarded ad unit for this build, or empty when there is none.
  String get rewardedUnit {
    if (useTestAds || !kReleaseMode || !kAdsLive) return AdUnits.rewardedTest;
    return AdUnits.rewarded;
  }

  /// Rewarded ads watched to the end, and what they earned, for the
  /// developer panel. Kept apart from the placement log because a rewarded
  /// ad is chosen by the user rather than placed in the layout.
  int get rewardedViews => _rewardedViews;
  int _rewardedViews = 0;
  double get rewardedRevenueDollars => _rewardedRevenueMicros / 1000000;
  double _rewardedRevenueMicros = 0;

  /// Whether a "watch an ad to unlock" offer can be made.
  bool get rewardedAvailable =>
      supported && canRequestAds && rewardedUnit.isNotEmpty;

  /// Loads and shows a rewarded ad. Completes with true only when the
  /// user watched it to the end and earned the reward.
  Future<bool> showRewarded() async {
    if (!rewardedAvailable) return false;
    final result = Completer<bool>();
    var earned = false;
    try {
      await RewardedAd.load(
        adUnitId: rewardedUnit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!result.isCompleted) result.complete(earned);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (!result.isCompleted) result.complete(false);
              },
            );
            ad.onPaidEvent = (ad, valueMicros, precision, currency) {
              _rewardedRevenueMicros += valueMicros;
              _persist();
            };
            ad.show(onUserEarnedReward: (ad, reward) {
              earned = true;
              _rewardedViews++;
              _persist();
            });
          },
          onAdFailedToLoad: (error) {
            if (kDebugMode) debugPrint('Rewarded ad failed: ${error.message}');
            if (!result.isCompleted) result.complete(false);
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Rewarded ad error: $e');
      if (!result.isCompleted) result.complete(false);
    }
    return result.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => earned,
    );
  }

  /// Whether the user must be offered a privacy-options form.
  bool get privacyOptionsRequired => _privacyRequired;

  /// Whether ads are supported at all on this platform.
  bool get supported => isAndroidPlatform;

  /// Impressions served in this app session.
  int get sessionImpressions => _sessionImpressions;

  /// How many impressions each placement may still serve today.
  int remainingToday(AdPlacement placement) {
    final now = DateTime.now();
    var served = 0;
    for (final i in _log) {
      if (i.placement != placement) continue;
      if (i.at.year == now.year &&
          i.at.month == now.month &&
          i.at.day == now.day) {
        served++;
      }
    }
    final cap = dailyCap[placement] ?? 4;
    final left = cap - served;
    return left < 0 ? 0 : left;
  }

  Future<void> load() async {
    final data = await _store.load(_logFile);
    if (data != null) {
      // An old "enabled" flag is ignored on purpose: ads are part of the
      // app, and a file written by an earlier build must not be able to
      // switch them off.
      _useTestAds = data['useTestAds'] as bool? ?? false;
      _rewardedViews = (data['rewardedViews'] as num?)?.toInt() ?? 0;
      _rewardedRevenueMicros =
          (data['rewardedRevenueMicros'] as num?)?.toDouble() ?? 0;
      for (final raw in (data['log'] as List? ?? const [])) {
        if (raw is Map<String, dynamic>) _log.add(AdImpression.fromMap(raw));
      }
      final units = data['adUnits'] as Map<String, dynamic>?;
      if (units != null) {
        for (final entry in units.entries) {
          final placement = AdPlacement.values.where((p) => p.id == entry.key);
          if (placement.isEmpty) continue;
          final value = entry.value as String?;
          if (value != null && value.trim().isNotEmpty) {
            _adUnits[placement.first] = value.trim();
          }
        }
      }
    }
    // A new session starts with a fresh impression budget.
    _sessionImpressions = 0;
    if (isAndroidPlatform) {
      await _initAds();
    } else {
      _markReady();
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.save(_logFile, {
      'useTestAds': _useTestAds,
      'adUnits': {for (final e in _adUnits.entries) e.key.id: e.value},
      'log': [for (final i in _log) i.toMap()],
      'rewardedViews': _rewardedViews,
      'rewardedRevenueMicros': _rewardedRevenueMicros,
    });
  }

  final Completer<void> _readyCompleter = Completer<void>();

  /// Completes once the SDK has started and consent is known, so ad slots
  /// never ask before ads are allowed (and never ask too early to count).
  /// Off Android, and if start-up hangs, it completes anyway.
  Future<void> get ready => _readyCompleter.future;

  void _markReady() {
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    notifyListeners();
  }

  /// Google's consent flow, then the SDK:
  ///  1. refresh the consent status,
  ///  2. show the consent form if this user needs one (EEA, UK and
  ///     Switzerland; Google requires it there before any ad),
  ///  3. start the SDK and let the slots load.
  Future<void> _initAds() async {
    if (_initialized) return;
    _initialized = true;
    // Never leave the slots waiting forever.
    Timer(const Duration(seconds: 10), _markReady);
    final consent = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null && kDebugMode) {
                debugPrint('Consent form failed: ${formError.message}');
              }
              if (!consent.isCompleted) consent.complete();
              // People take longer than the start-up wait to read the
              // form, so the answer is always re-read when it closes; the
              // change lets every waiting ad slot try again.
              _checkConsent();
            });
          } catch (_) {
            if (!consent.isCompleted) consent.complete();
          }
        },
        (error) {
          if (kDebugMode) debugPrint('Consent update failed: ${error.message}');
          if (!consent.isCompleted) consent.complete();
        },
      );
      await consent.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      await _checkConsent();
      await MobileAds.instance.initialize();
    } catch (e) {
      if (kDebugMode) debugPrint('Ad init failed: $e');
    }
    _markReady();
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
  /// The daily and session caps stop the app from showing ads on every
  /// visit.
  bool canShow(
    AdPlacement placement, {
    Duration minGap = const Duration(minutes: 3),
  }) {
    if (!supported || !canRequestAds || _adFree) return false;
    if (_sessionImpressions >= sessionCap) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var servedToday = 0;
    for (final i in _log) {
      if (i.placement != placement) continue;
      final at = i.at;
      if (at.year == today.year && at.month == today.month && at.day == today.day) {
        servedToday++;
      }
    }
    if (servedToday >= (dailyCap[placement] ?? 4)) return false;

    final last = _lastShown[placement];
    if (last != null && now.difference(last) < minGap) return false;
    return true;
  }

  /// Records that a placement was shown.
  void recordImpression(
    AdPlacement placement, {
    double revenueMicros = 0,
    bool clicked = false,
  }) {
    _lastShown[placement] = DateTime.now();
    _sessionImpressions++;
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
