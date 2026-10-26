import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/platform_check.dart';

/// Android-only placement. Failed requests collapse without blocking the UI.
class PortfolioBanner extends StatefulWidget {
  const PortfolioBanner({super.key});

  @override
  State<PortfolioBanner> createState() => _PortfolioBannerState();
}

class _PortfolioBannerState extends State<PortfolioBanner> {
  BannerAd? _ad;
  bool _ready = false;
  bool _started = false;
  bool _privacyRequired = false;
  bool _privacyOpen = false;
  bool _failed = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (!isAndroidPlatform) return;
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!mounted) return;
        ConsentForm.loadAndShowConsentFormIfRequired((_) => _load());
      },
      (_) => _load(),
    );
  }

  Future<void> _load() async {
    if (!mounted || _started || _privacyOpen) return;
    _started = true;
    final generation = _generation;
    try {
    final privacy = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    if (!mounted) return;
    setState(() => _privacyRequired =
        privacy == PrivacyOptionsRequirementStatus.required);
    final allowed = await ConsentInformation.instance.canRequestAds();
    if (!mounted || generation != _generation) return;
    if (!allowed) {
      _started = false;
      return;
    }
    await MobileAds.instance.initialize();
    if (!mounted || generation != _generation) return;
    final ad = BannerAd(
      adUnitId: kReleaseMode
          ? 'ca-app-pub-2085007206942111/8657501940'
          : 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || generation != _generation) {
            ad.dispose();
            return;
          }
          setState(() => _ready = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) debugPrint('Banner request failed: ${error.code} ${error.message}');
          if (mounted && generation == _generation) {
            setState(() {
              _ad = null;
              _ready = false;
              _started = false;
              _failed = true;
              _error = 'Fill unavailable (${error.domain}:${error.code})';
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
      _error = null;
      _failed = false;
    } catch (error) {
      if (kDebugMode) debugPrint('Ad initialization failed: $error');
      if (mounted && generation == _generation) {
        _ad?.dispose();
        setState(() { _ad = null; _ready = false; _started = false; });
      }
    }
  }

  void _privacyOptions() {
    if (_privacyOpen) return;
    _generation++;
    _ad?.dispose();
    setState(() { _ad = null; _ready = false; _started = false; _privacyOpen = true; });
    ConsentForm.showPrivacyOptionsForm((error) {
      if (!mounted) return;
      setState(() => _privacyOpen = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Privacy choices could not open. Please try again.'),
        ));
      }
      _load();
    });
  }

  @override
  void dispose() {
    _generation++;
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAndroidPlatform) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_ready && _ad != null) ...[
          const SizedBox(height: 16),
          Text('Advertisement', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < AdSize.banner.width) {
              return const SizedBox.shrink();
            }
            return Center(child: SizedBox(
              width: AdSize.banner.width.toDouble(),
              height: AdSize.banner.height.toDouble(),
              child: AdWidget(ad: _ad!),
            ));
          }),
        ],
        if (_privacyRequired)
          TextButton(onPressed: _privacyOpen ? null : _privacyOptions,
              child: const Text('Ad privacy choices')),
        if (!kReleaseMode && _failed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(
                'Ad fill unavailable${_error == null ? '' : ' · ${_error!}'}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              TextButton(
                onPressed: _privacyOpen ? null : () {
                  _generation++;
                  setState(() { _ad?.dispose(); _ad = null; _ready = false; _started = false; _failed = false; });
                  _load();
                },
                child: const Text('Retry ad'),
              ),
            ]),
          ),
      ],
    );
  }
}
