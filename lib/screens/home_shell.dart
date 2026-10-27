import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../services/app_navigation.dart';
import 'dividends_screen.dart';
import 'import_screen.dart';
import 'news_screen.dart';
import 'portfolio_screen.dart';
import 'settings_screen.dart';

/// Adaptive navigation shell: bottom nav on phones, a navigation rail on
/// wide desktop windows.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _labels = AppNavigation.labels;
  static const _icons = [
    Icons.account_balance_wallet_outlined,
    Icons.event_outlined,
    Icons.newspaper_outlined,
    Icons.upload_file_outlined,
    Icons.settings_outlined,
  ];

  /// Switches tabs from anywhere in the app (used by the KPI tiles).
  void goToTab(int index) {
    if (index < 0 || index >= _labels.length) return;
    setState(() => _index = index);
  }

  @override
  void initState() {
    super.initState();
    // Seed dividend data in the background once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PortfolioProvider>().ensureDividendInfo();
    });
    // Follow tab requests made from anywhere in the app.
    _nav = context.read<AppNavigation>();
    _nav.addListener(_onNavChanged);
  }

  late final AppNavigation _nav;

  void _onNavChanged() {
    if (!mounted) return;
    if (_nav.index != _index) setState(() => _index = _nav.index);
  }

  @override
  void dispose() {
    _nav.removeListener(_onNavChanged);
    super.dispose();
  }
  Widget _screen(int i) {
    switch (i) {
      case 0:
        return const PortfolioScreen();
      case 1:
        return const DividendsScreen();
      case 2:
        return const NewsScreen();
      case 3:
        return const ImportScreen(embedded: true);
      case 4:
      default:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final provider = context.watch<PortfolioProvider>();
    if (provider.backupReminderDue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PortfolioProvider>().markBackupReminderShown();
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Back up your portfolio?'),
            content: const Text('Your data stays on this device unless you save '
              'a backup. Export JSON or CSV before reinstalling or switching phones.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Maybe later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _index = 4);
                },
                child: const Text('Open backup'),
              ),
            ],
          ),
        );
      });
    }
    final content = IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _labels.length; i++)
          TickerMode(enabled: i == _index, child: _screen(i))],
    );

    // The ad service is app-wide, so every placement shares one consent
    // state and one frequency budget. Ad slots read it from the provider,
    // which also covers routes pushed above this shell.
    final body = content;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.9,
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(_icons[i]),
                      selectedIcon: Icon(_icons[i]),
                      label: Text(_labels[i]),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.2),
            radius: 1.35,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: .10),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: body,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(
              icon: Icon(_icons[i], size: 22),
              selectedIcon: Icon(_icons[i], size: 24),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
