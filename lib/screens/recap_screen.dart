import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/pulse_logo.dart';

/// A shareable picture of how the portfolio did this month or this year.
///
/// Amounts are hidden by default, so a recap can be posted without showing
/// how much money is involved; only percentages appear.
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapData {
  final double returnPct;
  final double valueChange;
  final List<ChartPoint> points;
  final List<MapEntry<String, double>> movers;

  const _RecapData(this.returnPct, this.valueChange, this.points, this.movers);
}

class _RecapScreenState extends State<RecapScreen> {
  final _cardKey = GlobalKey();
  String _range = '1mo';
  bool _showAmounts = false;
  bool _sharing = false;
  Future<_RecapData?>? _data;
  String? _loadedFor;

  Future<_RecapData?> _load(PortfolioProvider provider) async {
    final p = provider.active;
    final results = await Future.wait([
      provider.portfolioHistory(p.id, _range),
      provider.symbolChanges(p, _range),
    ]);
    final points = results[0] as List<ChartPoint>;
    final changes = results[1] as Map<String, double>;
    if (points.length < 2 || points.first.close <= 0) return null;
    final movers = changes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _RecapData(
      (points.last.close / points.first.close - 1) * 100,
      points.last.close - points.first.close,
      points,
      movers,
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      final ok = await ExportService.shareImage(
        fileName: 'stock-pulse-recap.png',
        bytes: png.buffer.asUint8List(),
        text: 'My portfolio recap, made with Stock Pulse',
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share the picture.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final key = '${provider.active.id}|$_range';
    if (_loadedFor != key) {
      _loadedFor = key;
      _data = _load(provider);
    }
    final totals = provider.totalsFor(provider.active);
    final currency = totals.displayCurrency ??
        (provider.active.holdings.isEmpty ? null : provider.active.holdings.values.first.currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Share your recap')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Center(
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: '1mo', label: Text('Past 30 days')),
                ButtonSegment(value: 'ytd', label: Text('This year')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FutureBuilder<_RecapData?>(
              future: _data,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 450,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final data = snap.data;
                if (data == null) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('Not enough price history for a recap yet.')),
                  );
                }
                return RepaintBoundary(
                  key: _cardKey,
                  child: RecapCard(
                    title: _range == 'ytd'
                        ? '${DateTime.now().year} so far'
                        : 'Past 30 days',
                    returnPct: data.returnPct,
                    valueChange: _showAmounts ? data.valueChange : null,
                    currency: currency,
                    points: data.points,
                    best: data.movers.take(3).toList(),
                    worst: data.movers.length > 3
                        ? data.movers.reversed.take(2).toList()
                        : const [],
                    holdings: provider.active.holdings.length,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Show amounts'),
            subtitle: const Text('Off: only percentages appear on the picture'),
            value: _showAmounts,
            onChanged: (v) => setState(() => _showAmounts = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: _sharing
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
            label: const Text('Share picture'),
            onPressed: _sharing ? null : _share,
          ),
          const SizedBox(height: 8),
          Text(
            'The picture shows how today\'s holdings moved over the period. '
            'It is made on your device; nothing is uploaded.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}

/// The recap picture itself. Always drawn in the neon brand look, whatever
/// theme the app is in, so every shared recap is recognisably Stock Pulse.
class RecapCard extends StatelessWidget {
  final String title;
  final double returnPct;
  final double? valueChange;
  final String? currency;
  final List<ChartPoint> points;
  final List<MapEntry<String, double>> best;
  final List<MapEntry<String, double>> worst;
  final int holdings;

  const RecapCard({
    super.key,
    required this.title,
    required this.returnPct,
    required this.valueChange,
    required this.currency,
    required this.points,
    required this.best,
    required this.worst,
    required this.holdings,
  });

  @override
  Widget build(BuildContext context) {
    final up = returnPct >= 0;
    final mood = up ? const Color(0xFF00F5A0) : const Color(0xFFFF3B6B);
    const muted = AppTheme.neonMuted;

    Widget mover(MapEntry<String, double> e) {
      final c = e.value >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF3B6B);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(e.key,
                style: const TextStyle(
                    color: AppTheme.neonText, fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            Text(fmtPct(e.value),
                style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      width: 340,
      height: 440,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppTheme.neonBackground,
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [mood.withValues(alpha: .35), mood.withValues(alpha: 0)]),
              ),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -110,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.neonViolet.withValues(alpha: .28),
                  AppTheme.neonViolet.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.neonGradient),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PulseLogo(size: 22),
                    const SizedBox(width: 8),
                    const Text('Stock Pulse',
                        style: TextStyle(
                            color: AppTheme.neonText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const Spacer(),
                    Text(title.toUpperCase(),
                        style: const TextStyle(
                            color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('MY PORTFOLIO',
                    style: TextStyle(
                        color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                const SizedBox(height: 2),
                Text(
                  fmtPct(returnPct),
                  style: TextStyle(
                    color: mood,
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: 1.05,
                    shadows: [Shadow(color: mood.withValues(alpha: .6), blurRadius: 24)],
                  ),
                ),
                if (valueChange != null)
                  Text(fmtSignedMoney(valueChange, currency: currency),
                      style: TextStyle(color: mood, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: CustomPaint(painter: _RecapLine(points, mood)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOP MOVERS',
                                style: TextStyle(
                                    color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                            const SizedBox(height: 6),
                            for (final e in best) mover(e),
                          ],
                        ),
                      ),
                      if (worst.isNotEmpty) ...[
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('LAGGARDS',
                                  style: TextStyle(
                                      color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                              const SizedBox(height: 6),
                              for (final e in worst) mover(e),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text('$holdings holdings · tracked free with Stock Pulse',
                    style: const TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapLine extends CustomPainter {
  final List<ChartPoint> points;
  final Color color;

  _RecapLine(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var lo = points.first.close, hi = lo;
    for (final p in points) {
      if (p.close < lo) lo = p.close;
      if (p.close > hi) hi = p.close;
    }
    final span = hi - lo <= 0 ? 1 : hi - lo;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - (points[i].close - lo) / span * size.height;
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
          colors: [color.withValues(alpha: .3), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = color.withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RecapLine old) => old.points != points || old.color != color;
}
