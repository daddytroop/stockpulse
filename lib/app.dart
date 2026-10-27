import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/portfolio_provider.dart';
import 'screens/home_shell.dart';
import 'screens/lock_gate.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    return MaterialApp(
      title: 'Stock Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(provider.themeMode, Brightness.light,
          accent: AppTheme.accents[provider.accentIndex]),
      darkTheme: AppTheme.themeFor(provider.themeMode, Brightness.dark,
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
