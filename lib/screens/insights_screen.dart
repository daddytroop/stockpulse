import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';
import '../utils/portfolio_health.dart';
import '../widgets/ui/sp_card.dart';

/// Pro: a diversification score with plain-language findings.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    // Sectors come from company profiles, fetched on demand.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PortfolioProvider>();
      provider.ensureProfiles(provider.active.symbols.toSet());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final report = checkHealth(provider.healthPositionsFor(provider.active));
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final scoreColor = report.score >= 70
        ? colors.gain
        : report.score >= 45
            ? colors.earnings
            : colors.loss;
    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio health')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SpCard(
                glow: scoreColor,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 22),
                child: Column(
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: report.score / 100),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => CustomPaint(
                          painter: _ScoreRing(progress: t, color: scoreColor,
                              track: theme.colorScheme.outlineVariant),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(t * 100).round()}',
                                  style: theme.textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: scoreColor,
                                  ),
                                ),
                                Text('out of 100',
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: theme.hintColor)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(report.grade, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'How spread out your money is. Higher means one bad pick hurts less.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                    if (provider.profilesLoading) ...[
                      const SizedBox(height: 10),
                      Text('Looking up sectors…',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Acts like',
                      value: '${report.effectivePositions.toStringAsFixed(1)} stocks',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'Biggest position',
                      value: report.largestSymbol == null
                          ? '–'
                          : '${report.largestSymbol} ${pct(report.largestWeight)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Top sector',
                      value: report.largestSector == null
                          ? 'Unknown'
                          : '${pct(report.largestSectorWeight)} ${report.largestSector}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'Top dividend payer',
                      value: report.topIncomeSymbol == null
                          ? 'No dividends'
                          : '${report.topIncomeSymbol} ${pct(report.topIncomeShare)}',
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                child: Text('What we noticed', style: theme.textTheme.titleMedium),
              ),
              for (var i = 0; i < report.findings.length; i++)
                _FindingTile(finding: report.findings[i])
                    .animate(delay: (70 * i).ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: .08, end: 0),
              const SizedBox(height: 12),
              Text(
                'A diversification check, not a rating of your investments or '
                'investment advice. The score: breadth (40), largest position (25), '
                'largest sector (20) and spread across types and markets (15).',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRing extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _ScoreRing({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke);
    const start = pi * 0.75;
    const sweep = pi * 1.5;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, start, sweep, false, base..color = track.withValues(alpha: .5));
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      start,
      sweep * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 8
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawArc(
      arcRect,
      start,
      sweep * progress,
      false,
      base
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [color.withValues(alpha: .6), color],
          transform: const GradientRotation(0),
        ).createShader(arcRect),
    );
  }

  @override
  bool shouldRepaint(_ScoreRing old) => old.progress != progress || old.color != color;
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SpCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  final HealthFinding finding;

  const _FindingTile({required this.finding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final (color, icon) = switch (finding.level) {
      HealthLevel.good => (colors.gain, Icons.check_circle_rounded),
      HealthLevel.watch => (colors.earnings, Icons.visibility_rounded),
      HealthLevel.risk => (colors.loss, Icons.warning_amber_rounded),
    };
    return SpCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(finding.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(finding.detail,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
