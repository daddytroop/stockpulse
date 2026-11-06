import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/portfolio_provider.dart';
import '../../screens/pro_screen.dart';
import '../../services/pro_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// A button that opens the theme picker.
///
/// The theme used to live only in Settings, a long way down a long list,
/// which made it easy to think it could not be changed. It is now one tap
/// away on every screen.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return IconButton(
      tooltip: 'Change the theme',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween(begin: .75, end: 1.0).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          key: ValueKey(isDark),
        ),
      ),
      onPressed: () => showThemeSheet(context),
    );
  }
}

/// Opens the theme picker. The sheet stays open while themes are tried, so
/// the whole app can be seen changing behind it.
Future<void> showThemeSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        // The sheet is scrollable so it never overflows on a short screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap one to try it. The app changes right behind this sheet.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(ctx).hintColor),
              ),
              const SizedBox(height: 14),
              const ThemeGrid(),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Applies [mode], asking for Pro first when it is a locked Pro theme.
Future<void> chooseTheme(BuildContext context, AppThemeId mode) async {
  final provider = context.read<PortfolioProvider>();
  if (mode.isPremium && !context.read<ProService>().has(ProFeature.themes)) {
    final unlocked = await showProPaywall(context, feature: ProFeature.themes);
    if (!unlocked) return;
  }
  HapticFeedback.selectionClick();
  await provider.setThemeMode(mode);
}

/// Every theme as a live mini preview, two or three to a row.
class ThemeGrid extends StatelessWidget {
  const ThemeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.select<PortfolioProvider, AppThemeId>((p) => p.themeMode);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 3 : 2;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final mode in AppThemeId.pickerOrder)
            SizedBox(
              width: width,
              child: ThemePreviewCard(
                mode: mode,
                selected: mode == current,
                onTap: () => chooseTheme(context, mode),
              ),
            ),
        ],
      );
    });
  }
}

/// A theme's name, with a PRO tag on the Pro themes.
class ThemeLabel extends StatelessWidget {
  final AppThemeId mode;

  const ThemeLabel({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (!mode.isPremium) return Text(mode.label);
    final locked = !context.watch<ProService>().has(ProFeature.themes);
    return Row(
      children: [
        Flexible(child: Text(mode.label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        ProBadge(locked: locked),
      ],
    );
  }
}

/// One theme, drawn in its own colours: a tiny balance card with a chart
/// and gain/loss pills, then its name.
class ThemePreviewCard extends StatelessWidget {
  final AppThemeId mode;
  final bool selected;
  final VoidCallback onTap;

  const ThemePreviewCard({
    super.key,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outer = Theme.of(context);
    final t = AppTheme.themeFor(mode, MediaQuery.platformBrightnessOf(context));
    final s = t.colorScheme;
    final c = t.extension<AppColors>()!;
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} theme',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.0 : .97,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: selected ? LinearGradient(colors: c.accentGradient) : null,
              color: selected ? null : outer.colorScheme.outlineVariant,
              boxShadow: selected
                  ? [BoxShadow(color: s.primary.withValues(alpha: .35), blurRadius: 18)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Container(
                color: t.scaffoldBackgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The mini balance card.
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                      decoration: BoxDecoration(
                        color: s.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: s.outlineVariant),
                        boxShadow: c.glow
                            ? [BoxShadow(color: s.primary.withValues(alpha: .18), blurRadius: 14)]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 3,
                            width: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              gradient: LinearGradient(colors: c.accentGradient),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text('\$12,480',
                              style: TextStyle(
                                  color: s.onSurface,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: -.4)),
                          SizedBox(
                            height: 26,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _MiniChartPainter(c.gain),
                            ),
                          ),
                          Row(children: [
                            _pill('+2.4%', c.gain, c.gainContainer),
                            const SizedBox(width: 4),
                            _pill('-0.8%', c.loss, c.lossContainer),
                          ]),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DefaultTextStyle(
                                  style: TextStyle(
                                      color: s.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13),
                                  child: ThemeLabel(mode: mode),
                                ),
                                Text(mode.blurb,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: s.onSurfaceVariant, fontSize: 10.5)),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, a) =>
                                ScaleTransition(scale: a, child: child),
                            child: selected
                                ? Icon(Icons.check_circle_rounded,
                                    key: const ValueKey(true), color: s.primary, size: 20)
                                : const SizedBox(key: ValueKey(false), width: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

class _MiniChartPainter extends CustomPainter {
  final Color color;
  _MiniChartPainter(this.color);

  static const _points = [.55, .62, .5, .58, .45, .5, .36, .42, .3, .34, .18, .22, .1];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final x = size.width * i / (_points.length - 1);
      final y = size.height * _points[i];
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MiniChartPainter old) => old.color != color;
}
