import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
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

  static const _labels = ['Portfolio', 'Dividends', 'News', 'Import', 'Settings'];
  static const _icons = [
    Icons.account_balance_wallet_outlined,
    Icons.event_outlined,
    Icons.newspaper_outlined,
    Icons.upload_file_outlined,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    // Seed dividend data in the background once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PortfolioProvider>().ensureDividendInfo();
    });
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
    final content = IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _labels.length; i++)
          TickerMode(enabled: i == _index, child: _screen(i))],
    );

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
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
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
