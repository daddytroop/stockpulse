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

  @override
  void initState() {
    super.initState();
    if (!isAndroidPlatform) return;
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => _load()),
      (_) => _load(),
    );
  }

  Future<void> _load() async {
    final privacy = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    if (!mounted) return;
    setState(() => _privacyRequired =
        privacy == PrivacyOptionsRequirementStatus.required);
    if (_started || !await ConsentInformation.instance.canRequestAds()) return;
    if (!mounted) return;
    _started = true;
    await MobileAds.instance.initialize();
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: kReleaseMode
          ? 'ca-app-pub-2085007206942111/8657501940'
          : 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _ready = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() { _ad = null; _ready = false; });
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  void _privacyOptions() {
    _ad?.dispose();
    setState(() { _ad = null; _ready = false; _started = false; });
    ConsentForm.showPrivacyOptionsForm((_) => _load());
  }

  @override
  void dispose() {
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
          TextButton(onPressed: _privacyOptions,
              child: const Text('Ad privacy choices')),
      ],
    );
  }
}
