import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/portfolio_provider.dart';
import 'screens/home_shell.dart';
import 'screens/lock_gate.dart';
import 'screens/onboarding_screen.dart';
import 'services/pro_service.dart';
import 'theme/app_theme.dart';

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final pro = context.watch<ProService>();
    // A Pro theme shows as Neon while it is locked (say, after a trial ran
    // out). The choice itself is kept, so it comes back with Pro.
    final themeId = provider.themeMode.isPremium && !pro.has(ProFeature.themes)
        ? AppThemeId.neon
        : provider.themeMode;

    return MaterialApp(
      title: 'Stock Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(themeId, Brightness.light,
          accent: AppTheme.accents[provider.accentIndex]),
      darkTheme: AppTheme.themeFor(themeId, Brightness.dark,
          accent: AppTheme.accents[provider.accentIndex]),
      // Theme selection is handled explicitly so every surface uses the
      // selected palette instead of only swapping light/dark shells.
      themeMode: ThemeMode.light,
      builder: (context, child) => LockGate(child: child!),
      home: const RootScreen(),
    );
  }
}

/// Chooses the onboarding shell or main navigation from persisted state.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    if (!provider.showsOnboarding) {
      return OnboardingScreen(
        onAction: (_) => provider.completeOnboarding(),
        onDone: provider.completeOnboarding,
      );
    }
    return const HomeShell();
  }
}
