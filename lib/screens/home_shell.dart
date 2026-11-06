import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../services/app_navigation.dart';
import '../services/review_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/page_transitions.dart';
import 'add_edit_holding_sheet.dart';
import 'dividends_screen.dart';
import 'import_screen.dart';
import 'markets_screen.dart';
import 'news_screen.dart';
import 'portfolio_screen.dart';
import 'settings_screen.dart';
import 'whats_new_sheet.dart';

/// Adaptive navigation shell: bottom nav on phones, a navigation rail on
/// wide desktop windows.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Plays a short fade-through whenever the tab changes.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  late final Animation<double> _tabOpacity =
      CurvedAnimation(parent: _tabFade, curve: Curves.easeOut);
  late final Animation<double> _tabScale = Tween(begin: .985, end: 1.0)
      .animate(CurvedAnimation(parent: _tabFade, curve: Curves.easeOutCubic));

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    _tabFade.forward(from: 0);
  }

  static const _labels = AppNavigation.labels;
  static const _icons = [
    Icons.account_balance_wallet_outlined,
    Icons.event_outlined,
    Icons.newspaper_outlined,
    Icons.candlestick_chart_outlined,
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
      final provider = context.read<PortfolioProvider>();
      provider.ensureDividendInfo();
      provider.countAppOpen();
      _runPendingAction();
      _maybeShowWhatsNew();
      _maybeAskForReview();
    });
    // Follow tab requests made from anywhere in the app.
    _nav = context.read<AppNavigation>();
    _nav.addListener(_onNavChanged);
  }

  late final AppNavigation _nav;

  /// Shows the release highlights once to people who updated.
  Future<void> _maybeShowWhatsNew() async {
    final provider = context.read<PortfolioProvider>();
    if (!provider.whatsNewDue || provider.backupReminderDue) return;
    await provider.markWhatsNewSeen();
    if (!mounted) return;
    await showWhatsNewSheet(context,
        onOpenMarkets: () => _select(AppNavigation.marketsTab));
  }

  /// Asks for a rating once, a little after opening the app on a good day.
  void _maybeAskForReview() {
    _reviewTimer = Timer(const Duration(seconds: 8), () async {
      if (!mounted) return;
      final provider = context.read<PortfolioProvider>();
      // Never on top of another sheet or dialog.
      if (!provider.reviewDue || ModalRoute.of(context)?.isCurrent != true) return;
      await provider.markReviewAsked();
      await ReviewService.request();
    });
  }

  Timer? _reviewTimer;

  /// Carries out what was picked on the first-run screen.
  void _runPendingAction() {
    final action = _nav.pendingAction;
    _nav.pendingAction = null;
    final provider = context.read<PortfolioProvider>();
    switch (action) {
      case 'add':
        showAddEditHoldingSheet(context, provider, provider.active.id);
      case 'import':
        pushSharedAxis(context, const ImportScreen());
      case 'markets':
        _select(AppNavigation.marketsTab);
      case 'settings':
        _select(AppNavigation.settingsTab);
    }
  }

  void _onNavChanged() {
    if (!mounted) return;
    if (_nav.index != _index) _select(_nav.index);
  }

  @override
  void dispose() {
    _nav.removeListener(_onNavChanged);
    _reviewTimer?.cancel();
    _tabFade.dispose();
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
        return const MarketsScreen();
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
      child: FadeTransition(
        opacity: _tabOpacity,
        child: ScaleTransition(
          scale: _tabScale,
          child: IndexedStack(
            index: _index,
            children: [for (var i = 0; i < _labels.length; i++)
              TickerMode(enabled: i == _index, child: _screen(i))],
          ),
        ),
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
                onDestinationSelected: _select,
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
          onSelected: _select,
        ),
      ),
    );
  }

  static const _selectedIcons = [
    Icons.account_balance_wallet,
    Icons.event,
    Icons.newspaper,
    Icons.candlestick_chart,
    Icons.settings,
  ];
}

/// Soft coloured light behind every screen, so the surfaces read as depth
/// rather than a flat fill. The light drifts very slowly, like a living
/// background; it holds still when the device asks for reduced motion.
class AmbientBackground extends StatefulWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glow = AppColors.of(context).accentGradient;
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, _) {
                  final t = _drift.value * 2 * pi;
                  return CustomPaint(
                    painter: _GlowPainter(
                      blobs: [
                        (
                          Alignment(-1.0 + .25 * sin(t), -1.1 + .15 * cos(t)),
                          1.1,
                          glow.first.withValues(alpha: isDark ? .17 : .12),
                        ),
                        (
                          Alignment(1.15 + .2 * cos(t * 1.3), -.65 + .2 * sin(t)),
                          .9,
                          glow.last.withValues(alpha: isDark ? .14 : .08),
                        ),
                        (
                          Alignment(-.4 + .4 * sin(t * .7), 1.1),
                          .8,
                          glow[1].withValues(alpha: isDark ? .07 : .05),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final List<(Alignment, double, Color)> blobs;
  _GlowPainter({required this.blobs});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final (center, radius, color) in blobs) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: center,
            radius: radius,
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => true;
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
                      // The chosen icon pops in with a little spring.
                      selectedIcon: TweenAnimationBuilder<double>(
                        key: ValueKey('sel-$i-$index'),
                        tween: Tween(begin: .7, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.elasticOut,
                        builder: (context, s, child) =>
                            Transform.scale(scale: s, child: child),
                        child: Icon(selectedIcons[i], size: 23),
                      ),
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
