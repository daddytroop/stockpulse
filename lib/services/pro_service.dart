import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'platform_check.dart';
import 'store.dart';

/// Something Stock Pulse Pro unlocks.
///
/// Everything the app did before Pro existed stays free. Pro adds new
/// things on top, and removes the ads.
enum ProFeature {
  snowball('snowball'),
  insights('insights'),
  watchlist('watchlist'),
  themes('themes');

  const ProFeature(this.id);

  /// Stable identifier used when saving trials.
  final String id;

  String get title => switch (this) {
        ProFeature.snowball => 'Dividend snowball',
        ProFeature.insights => 'Portfolio health',
        ProFeature.watchlist => 'Unlimited watchlist & target alerts',
        ProFeature.themes => 'Exclusive themes & app icons',
      };

  String get blurb => switch (this) {
        ProFeature.snowball =>
          'See your dividend income 5, 10 or 30 years out, with reinvestment and growth.',
        ProFeature.insights =>
          'A diversification score and plain-language warnings about concentration risk.',
        ProFeature.watchlist =>
          'Follow any number of stocks and get a notification when they hit your price.',
        ProFeature.themes =>
          'Gold, Aurora and Sakura themes, plus alternate home-screen icons.',
      };

  IconData get icon => switch (this) {
        ProFeature.snowball => Icons.ac_unit_rounded,
        ProFeature.insights => Icons.health_and_safety_outlined,
        ProFeature.watchlist => Icons.notifications_active_outlined,
        ProFeature.themes => Icons.palette_outlined,
      };
}

/// Forces the locked (free) experience on platforms where Pro is normally
/// included, so the paywall can be previewed in a web or desktop build:
/// `--dart-define=PRO_LOCKED=true`.
const bool kProLocked = bool.fromEnvironment('PRO_LOCKED');

/// Whether this build carries the "See the app as a Pro user" switch.
///
/// Only debug builds and test builds made with `--dart-define=DEV_TOOLS=true`
/// (CI does this for pull-request APKs) have it. Store builds never do, so
/// nobody can unlock Pro for free through the hidden developer panel.
const bool kDevTools = kDebugMode || bool.fromEnvironment('DEV_TOOLS');

/// Owns the one-time Pro unlock and the 24-hour trials earned by watching
/// a rewarded ad.
///
/// Pro is a single non-consumable Play product. Google Play is the record
/// of who owns it: the app restores it quietly on every start, and keeps a
/// local copy so Pro works offline.
///
/// Builds without Google Play (Windows, web) cannot sell anything and show
/// no ads, so they include Pro rather than showing a paywall that cannot be
/// paid.
class ProService extends ChangeNotifier {
  ProService({
    StockPulseStore? store,
    InAppPurchase? iap,
    @visibleForTesting bool? sellsProForTest,
    @visibleForTesting bool devToolsForTest = kDevTools,
  })  : _store = store ?? StockPulseStore(),
        _iapOverride = iap,
        _sellsOverride = sellsProForTest,
        devTools = devToolsForTest;

  final bool? _sellsOverride;

  /// Whether the developer Pro switch exists in this build. A switch turned
  /// on in a test build is ignored by a store build installed over it.
  final bool devTools;

  /// The Play Console product id. Create a one-time product with this id.
  static const productId = 'stockpulse_pro_lifetime';

  /// How long one rewarded ad unlocks a feature for.
  static const trialLength = Duration(hours: 24);

  static const _file = 'stockpulse_pro.json';

  final StockPulseStore _store;
  final InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _owned = false;
  bool _devPro = false;
  final Map<ProFeature, DateTime> _trials = {};
  ProductDetails? _product;
  bool _storeAvailable = false;
  bool _purchasing = false;
  String? _error;

  /// Whether this build sells Pro through Google Play.
  bool get sellsPro => !_includedHere;

  /// Pro is part of builds that cannot sell it.
  bool get _includedHere =>
      _sellsOverride != null ? !_sellsOverride : (!isAndroidPlatform && !kProLocked);

  /// Whether the user has Pro for good.
  bool get isPro => _owned || devPro || _includedHere;

  /// Whether the user bought Pro (as opposed to it being included).
  bool get owned => _owned;

  /// Developer override, from the hidden developer panel.
  bool get devPro => devTools && _devPro;

  /// Whether [feature] is unlocked, permanently or by a trial.
  bool has(ProFeature feature) {
    if (isPro) return true;
    final until = _trials[feature];
    return until != null && until.isAfter(DateTime.now());
  }

  /// When the trial for [feature] ends, if one is running.
  DateTime? trialEndsAt(ProFeature feature) {
    final until = _trials[feature];
    if (until == null || !until.isAfter(DateTime.now())) return null;
    return until;
  }

  /// The localised price from Google Play, once it has loaded.
  String? get price => _product?.price;

  /// Whether Google Play answered and the product can be bought.
  bool get canBuy => _storeAvailable && _product != null;

  bool get purchasing => _purchasing;

  /// The last purchase problem, in words the user can act on.
  String? get error => _error;

  Future<void> load() async {
    final data = await _store.load(_file);
    if (data != null) {
      _owned = data['owned'] as bool? ?? false;
      _devPro = data['devPro'] as bool? ?? false;
      final trials = data['trials'] as Map<String, dynamic>? ?? const {};
      for (final f in ProFeature.values) {
        final at = DateTime.tryParse(trials[f.id]?.toString() ?? '');
        if (at != null && at.isAfter(DateTime.now())) _trials[f] = at;
      }
    }
    notifyListeners();
    if (isAndroidPlatform) await _connect();
  }

  Future<void> _persist() => _store.save(_file, {
        'owned': _owned,
        'devPro': _devPro,
        'trials': {for (final e in _trials.entries) e.key.id: e.value.toIso8601String()},
      });

  Future<void> _connect() async {
    try {
      _sub ??= _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          _purchasing = false;
          _error = 'Google Play reported a problem. Please try again.';
          notifyListeners();
        },
      );
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) {
        notifyListeners();
        return;
      }
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
      }
      notifyListeners();
      // Quietly re-applies a purchase made earlier or on another device.
      await _iap.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('Billing unavailable: $e');
    }
  }

  /// Starts the Google Play purchase sheet.
  Future<void> buy() async {
    _error = null;
    final product = _product;
    if (product == null) {
      _error = _storeAvailable
          ? 'Pro is not available in your Play Store region yet.'
          : 'Google Play is not available on this device.';
      notifyListeners();
      return;
    }
    _purchasing = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      _purchasing = false;
      _error = 'The purchase could not be started. Please try again.';
      notifyListeners();
    }
  }

  /// Asks Google Play for purchases made earlier.
  Future<void> restore() async {
    _error = null;
    notifyListeners();
    if (!isAndroidPlatform) return;
    try {
      await _iap.restorePurchases();
    } catch (_) {
      _error = 'Could not reach Google Play to restore your purchase.';
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await grantOwnership();
        case PurchaseStatus.pending:
          _purchasing = true;
        case PurchaseStatus.error:
          _purchasing = false;
          _error = 'The purchase did not go through. You have not been charged.';
        case PurchaseStatus.canceled:
          _purchasing = false;
      }
      // Google Play refunds a purchase that is never acknowledged.
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// Records that the user owns Pro.
  @visibleForTesting
  Future<void> grantOwnership() async {
    _owned = true;
    _purchasing = false;
    _error = null;
    await _persist();
    notifyListeners();
  }

  /// Unlocks [feature] for [trialLength], after a rewarded ad was watched.
  ///
  /// A second ad while a trial runs extends it from its current end, so an
  /// ad is never wasted.
  Future<void> grantTrial(ProFeature feature) async {
    final now = DateTime.now();
    final current = _trials[feature];
    final from = current != null && current.isAfter(now) ? current : now;
    _trials[feature] = from.add(trialLength);
    await _persist();
    notifyListeners();
  }

  /// Developer-only switch to see the app as a Pro user.
  Future<void> setDevPro(bool value) async {
    if (!devTools) return;
    _devPro = value;
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
