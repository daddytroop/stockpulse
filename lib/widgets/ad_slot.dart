import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';

/// Renders an ad for a given [AdPlacement].
///
/// The widget is deliberately forgiving: if the ad fails to load, is not
/// permitted by consent, or the user turned ads off, it renders nothing
/// rather than an empty box. An ad must never push content around or look
/// broken.
class AdSlot extends StatefulWidget {
  final AdPlacement placement;

  /// Uses a native ad (blends into content) instead of a banner.
  final bool native;

  /// Minimum height reserved so the layout does not jump when the ad
  /// arrives.
  final double minHeight;

  const AdSlot({
    super.key,
    required this.placement,
    this.native = false,
    this.minHeight = 0,
  });

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  AdWithView? _ad;
  bool _ready = false;
  int _generation = 0;

  /// The shared ad service.
  ///
  /// It is read from the app-wide provider rather than an inherited
  /// widget, because a pushed route (a story, a holding) sits above the
  /// app shell in the navigator and would otherwise be outside the scope.
  AdService get _service => context.read<AdService>();

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(AdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _disposeAd();
      _request();
    }
  }

  @override
  void dispose() {
    _generation++;
    _disposeAd();
    super.dispose();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    if (mounted) setState(() => _ready = false);
  }

  Future<void> _request() async {
    if (!_service.supported) return;
    if (!_service.canRequestAds) return;
    if (!_service.canShow(widget.placement)) return;

    final unitId = _service.adUnitFor(widget.placement);
    if (unitId.isEmpty) return;

    final generation = ++_generation;
    try {
      if (widget.native) {
        final ad = NativeAd(
          adUnitId: unitId,
          request: const AdRequest(),
          nativeTemplateStyle: _templateStyle(),
          listener: NativeAdListener(
            onAdLoaded: (ad) {
              if (!mounted || generation != _generation) {
                ad.dispose();
                return;
              }
              setState(() {
                _ad = ad as AdWithView;
                _ready = true;
              });
              _service.recordImpression(widget.placement);
            },
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
              if (kDebugMode) {
                debugPrint('Native ad failed (${widget.placement.id}): '
                    '${error.code} ${error.message}');
              }
            },
            onAdClicked: (ad) => _service.recordImpression(
              widget.placement,
              clicked: true,
            ),
            onPaidEvent: (ad, valueMicros, precision, currencyCode) =>
                _service.recordImpression(
              widget.placement,
              revenueMicros: valueMicros,
            ),
          ),
        );
        await ad.load();
      } else {
        final ad = BannerAd(
          adUnitId: unitId,
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              if (!mounted || generation != _generation) {
                ad.dispose();
                return;
              }
              setState(() {
                _ad = ad as AdWithView;
                _ready = true;
              });
              _service.recordImpression(widget.placement);
            },
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
              if (kDebugMode) {
                debugPrint('Banner failed (${widget.placement.id}): '
                    '${error.code} ${error.message}');
              }
            },
            onAdClicked: (ad) => _service.recordImpression(
              widget.placement,
              clicked: true,
            ),
            onPaidEvent: (ad, valueMicros, precision, currencyCode) =>
                _service.recordImpression(
              widget.placement,
              revenueMicros: valueMicros,
            ),
          ),
        );
        await ad.load();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Ad request error: $e');
    }
  }

  NativeTemplateStyle _templateStyle() {
    final theme = Theme.of(context);
    return NativeTemplateStyle(
      templateType: TemplateType.medium,
      mainBackgroundColor: theme.colorScheme.surface,
      cornerRadius: 18,
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: theme.colorScheme.onSurface,
        backgroundColor: Colors.transparent,
        size: 15,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: theme.hintColor,
        backgroundColor: Colors.transparent,
        size: 12,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: theme.hintColor,
        backgroundColor: Colors.transparent,
        size: 11,
      ),
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: theme.colorScheme.primary,
        backgroundColor: Colors.transparent,
        size: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watching the service means the slot reacts when ads are switched off
    // or consent changes.
    final ads = context.watch<AdService>();
    if (!_ready || _ad == null) return const SizedBox.shrink();
    if (!ads.adsEnabled) return const SizedBox.shrink();
    final theme = Theme.of(context);

    if (widget.native) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(theme),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.08),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(4),
              child: AdWidget(ad: _ad!),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _label(theme),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: AdSize.banner.width.toDouble(),
              height: AdSize.banner.height.toDouble(),
              child: AdWidget(ad: _ad!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(ThemeData theme) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.ads_click, size: 12, color: theme.hintColor),
          const SizedBox(width: 5),
          Text(
            'Sponsored',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              letterSpacing: 0.4,
            ),
          ),
        ],
      );
}
