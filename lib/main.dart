import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/portfolio_provider.dart';
import 'services/ad_service.dart';
import 'services/app_navigation.dart';
import 'services/diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final provider = PortfolioProvider();
  final ads = AdService();
  final nav = AppNavigation();
  Diagnostics.setEnabled(provider.crashDiagnostics);
  await Diagnostics.install(enabled: provider.crashDiagnostics);
  // First paint immediately; data loads + refreshes continue in background.
  unawaited(provider.warmStart());
  unawaited(ads.load());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PortfolioProvider>.value(value: provider),
        ChangeNotifierProvider<AdService>.value(value: ads),
        ChangeNotifierProvider<AppNavigation>.value(value: nav),
      ],
      child: const StockPulseApp(),
    ),
  );
}
