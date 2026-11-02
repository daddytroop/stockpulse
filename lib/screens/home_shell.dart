import 'dart:ui';

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
    // The tabs draw on the shell's ambient background, so their own
    // scaffolds are see-through. Pushed routes keep a solid background.
    final theme = Theme.of(context);
    final content = Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        // Clear at rest so the glow shows; solid once content scrolls under.
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.scrolledUnder)
                  ? theme.scaffoldBackgroundColor.withValues(alpha: .96)
                  : Colors.transparent),
        ),
      ),
      child: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _labels.length; i++)
          TickerMode(enabled: i == _index, child: _screen(i))],
      ),
    );

    // The ad service is app-wide, so every placement shares one consent
    // state and one frequency budget. Ad slots read it from the provider,
    // which also covers routes pushed above this shell.
    final body = content;

    if (wide) {
      return AmbientBackground(
        child: Scaffold(
        backgroundColor: Colors.transparent,
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
      ),
      );
    }

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: body,
        bottomNavigationBar: _FloatingNavBar(
          index: _index,
          icons: _icons,
          selectedIcons: _selectedIcons,
          labels: _labels,
          onSelected: (i) => setState(() => _index = i),
        ),
      ),
    );
  }

  static const _selectedIcons = [
    Icons.account_balance_wallet,
    Icons.event,
    Icons.newspaper,
    Icons.upload_file,
    Icons.settings,
  ];
}

/// Soft coloured light behind every screen, so the dark surfaces read as
/// depth rather than as a flat fill.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1.1, -1.15),
                  radius: 1.1,
                  colors: [
                    scheme.primary.withValues(alpha: isDark ? .16 : .12),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.2, -0.7),
                  radius: 0.9,
                  colors: [
                    scheme.tertiary.withValues(alpha: isDark ? .14 : .08),
                    scheme.tertiary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// A frosted, rounded navigation bar that floats above the content.
class _FloatingNavBar extends StatelessWidget {
  final int index;
  final List<IconData> icons;
  final List<IconData> selectedIcons;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  const _FloatingNavBar({
    required this.index,
    required this.icons,
    required this.selectedIcons,
    required this.labels,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? .45 : .10),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: scheme.primary.withValues(alpha: isDark ? .10 : .06),
              blurRadius: 24,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: isDark ? .72 : .86),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: .08)
                      : scheme.outline.withValues(alpha: .12),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onSelected,
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(
                      icon: Icon(icons[i], size: 22),
                      selectedIcon: Icon(selectedIcons[i], size: 23),
                      label: labels[i],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
