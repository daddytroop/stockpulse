import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/portfolio_provider.dart';
import 'services/ad_service.dart';
import 'services/app_navigation.dart';
import 'services/diagnostics.dart';
import 'services/pro_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final provider = PortfolioProvider();
  final ads = AdService();
  final pro = ProService();
  final nav = AppNavigation();
  // Pro removes the ads and switches on watchlist target alerts. A trial
  // earned from a rewarded ad counts too, and expires on its own.
  void applyPro() {
    ads.setAdFree(pro.isPro);
    provider.setWatchAlertsEnabled(pro.has(ProFeature.watchlist));
  }
  pro.addListener(applyPro);
  Diagnostics.setEnabled(provider.crashDiagnostics);
  await Diagnostics.install(enabled: provider.crashDiagnostics);
  // First paint immediately; data loads + refreshes continue in background.
  unawaited(provider.warmStart());
  unawaited(ads.load());
  unawaited(pro.load().then((_) => applyPro()));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PortfolioProvider>.value(value: provider),
        ChangeNotifierProvider<AdService>.value(value: ads),
        ChangeNotifierProvider<ProService>.value(value: pro),
        ChangeNotifierProvider<AppNavigation>.value(value: nav),
      ],
      child: const StockPulseApp(),
    ),
  );
}
