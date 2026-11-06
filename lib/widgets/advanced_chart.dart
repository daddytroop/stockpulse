import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/quote.dart';
import '../theme/app_colors.dart';
import '../utils/indicators.dart';

/// How prices are drawn.
enum ChartStyle { line, candles }

/// Studies that can be laid over (or under) the price.
enum Study {
  volume('Volume', 'Bars along the bottom'),
  sma20('SMA 20', 'Simple moving average, 20 bars'),
  sma50('SMA 50', 'Simple moving average, 50 bars'),
  sma200('SMA 200', 'Simple moving average, 200 bars'),
  ema20('EMA 20', 'Exponential moving average, 20 bars'),
  bollinger('Bollinger bands', '20 bars, 2 standard deviations'),
  rsi('RSI', 'Relative strength, 14 bars'),
  macd('MACD', '12 / 26 / 9');

  const Study(this.label, this.detail);
  final String label;
  final String detail;

  /// Studies drawn in their own pane under the price.
  bool get hasPane => this == Study.rsi || this == Study.macd;

  /// Studies that are part of Pro.
  bool get isPro => this == Study.bollinger || this == Study.rsi || this == Study.macd;
}

/// A full-featured price chart: candles or a line, moving averages,
/// Bollinger bands, volume, RSI and MACD.
///
/// Drag (or hover with a mouse) to read any bar, pinch or scroll the mouse
/// wheel to zoom, drag with two fingers to pan, double-tap to reset.
class AdvancedChart extends StatefulWidget {
  final List<ChartPoint> points;
  final ChartStyle style;
  final Set<Study> studies;

  /// Whether the bars are intraday (time labels instead of dates).
  final bool intraday;
  final String Function(double) formatPrice;

  /// The bar under the finger, or null when nothing is being read.
  final ValueChanged<ChartPoint?>? onScrub;

  const AdvancedChart({
    super.key,
    required this.points,
    required this.formatPrice,
    this.style = ChartStyle.candles,
    this.studies = const {Study.volume},
    this.intraday = false,
    this.onScrub,
  });

  @override
  State<AdvancedChart> createState() => _AdvancedChartState();
}

class _AdvancedChartState extends State<AdvancedChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  /// The visible window, in bar indexes (fractional while zooming).
  double _start = 0;
  double _end = 0;
  int? _hover;

  late _Series _series;

  // Gesture bookkeeping.
  double _scaleStartSpan = 0;
  double _scaleStartStart = 0;
  double _scaleStartEnd = 0;
  double _scaleStartFocal = 0;
  int _pointers = 0;

  @override
  void initState() {
    super.initState();
    _series = _Series(widget.points, widget.studies);
    _resetWindow();
  }

  @override
  void didUpdateWidget(AdvancedChart old) {
    super.didUpdateWidget(old);
    final newData = !identical(old.points, widget.points);
    if (newData || old.studies.length != widget.studies.length ||
        !old.studies.containsAll(widget.studies)) {
      _series = _Series(widget.points, widget.studies);
    }
    if (newData) {
      _resetWindow();
      _hover = null;
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _resetWindow() {
    _start = 0;
    _end = widget.points.length.toDouble();
  }

  double get _span => max(1, _end - _start);

  /// The smallest window: a handful of bars.
  double get _minSpan => min(12, widget.points.length.toDouble());

  void _zoom(double factor, double focalFraction) {
    final n = widget.points.length.toDouble();
    if (n < 2) return;
    final span = (_span * factor).clamp(_minSpan, n);
    final focus = _start + _span * focalFraction;
    var start = focus - span * focalFraction;
    start = start.clamp(0, n - span);
    setState(() {
      _start = start;
      _end = start + span;
    });
  }

  void _setHover(Offset local, Size size) {
    if (widget.points.isEmpty) return;
    final plotWidth = size.width - _Layout.axisWidth;
    final fraction = (local.dx / plotWidth).clamp(0.0, 1.0);
    final first = _start.floor();
    final last = min(widget.points.length - 1, _end.ceil() - 1);
    final i = (_start + fraction * _span - .5).round().clamp(first, last);
    if (i != _hover) {
      HapticFeedback.selectionClick();
      setState(() => _hover = i);
      widget.onScrub?.call(widget.points[i]);
    }
  }

  void _clearHover() {
    if (_hover == null) return;
    setState(() => _hover = null);
    widget.onScrub?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    if (widget.points.length < 2) {
      return Center(
        child: Text('No chart data for this range',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers = max(0, _pointers - 1),
        onPointerCancel: (_) => _pointers = max(0, _pointers - 1),
        // Mouse wheel / trackpad: zoom around the pointer.
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            final f = (e.localPosition.dx / (size.width - _Layout.axisWidth)).clamp(0.0, 1.0);
            _zoom(e.scrollDelta.dy > 0 ? 1.12 : 1 / 1.12, f);
          }
        },
        child: MouseRegion(
          onHover: (e) => _setHover(e.localPosition, size),
          onExit: (_) => _clearHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => setState(_resetWindow),
            onScaleStart: (d) {
              _scaleStartSpan = _span;
              _scaleStartStart = _start;
              _scaleStartEnd = _end;
              _scaleStartFocal = d.localFocalPoint.dx;
              if (_pointers <= 1) _setHover(d.localFocalPoint, size);
            },
            onScaleUpdate: (d) {
              if (d.pointerCount >= 2) {
                _clearHover();
                final plot = size.width - _Layout.axisWidth;
                final n = widget.points.length.toDouble();
                final span = (_scaleStartSpan / d.horizontalScale).clamp(_minSpan, n);
                final focalFraction = (_scaleStartFocal / plot).clamp(0.0, 1.0);
                final focusBar = _scaleStartStart +
                    (_scaleStartEnd - _scaleStartStart) * focalFraction;
                // Two-finger drag pans as well.
                final panBars = -(d.localFocalPoint.dx - _scaleStartFocal) / plot * span;
                var start = focusBar - span * focalFraction + panBars;
                start = start.clamp(0, n - span);
                setState(() {
                  _start = start;
                  _end = start + span;
                });
              } else {
                _setHover(d.localFocalPoint, size);
              }
            },
            onScaleEnd: (_) => _clearHover(),
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _ChartPainter(
                  series: _series,
                  style: widget.style,
                  studies: widget.studies,
                  start: _start,
                  end: _end,
                  hover: _hover,
                  reveal: Curves.easeOutCubic.transform(_reveal.value),
                  intraday: widget.intraday,
                  formatPrice: widget.formatPrice,
                  colors: colors,
                  scheme: theme.colorScheme,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// The price series and every study computed over the whole history, so a
/// 200-bar average is right even when zoomed in on the last few bars.
class _Series {
  final List<ChartPoint> points;
  final List<double> closes;
  final Map<Study, List<double?>> lines = {};
  ({List<double?> middle, List<double?> upper, List<double?> lower})? bands;
  List<double?>? rsiLine;
  ({List<double?> macd, List<double?> signal, List<double?> histogram})? macdLines;

  _Series(this.points, Set<Study> studies)
      : closes = [for (final p in points) p.close] {
    if (studies.contains(Study.sma20)) lines[Study.sma20] = sma(closes, 20);
    if (studies.contains(Study.sma50)) lines[Study.sma50] = sma(closes, 50);
    if (studies.contains(Study.sma200)) lines[Study.sma200] = sma(closes, 200);
    if (studies.contains(Study.ema20)) lines[Study.ema20] = ema(closes, 20);
    if (studies.contains(Study.bollinger)) bands = bollinger(closes);
    if (studies.contains(Study.rsi)) rsiLine = rsi(closes);
    if (studies.contains(Study.macd)) macdLines = macd(closes);
  }
}

/// Colours of the overlay lines, readable on light and dark themes.
const studyColors = {
  Study.sma20: Color(0xFFF59E0B),
  Study.sma50: Color(0xFF8B5CF6),
  Study.sma200: Color(0xFF3B82F6),
  Study.ema20: Color(0xFFEC4899),
};

class _Layout {
  static const axisWidth = 58.0;
  static const timeAxisHeight = 20.0;
  static const paneGap = 10.0;
}

class _ChartPainter extends CustomPainter {
  final _Series series;
  final ChartStyle style;
  final Set<Study> studies;
  final double start;
  final double end;
  final int? hover;
  final double reveal;
  final bool intraday;
  final String Function(double) formatPrice;
  final AppColors colors;
  final ColorScheme scheme;

  _ChartPainter({
    required this.series,
    required this.style,
    required this.studies,
    required this.start,
    required this.end,
    required this.hover,
    required this.reveal,
    required this.intraday,
    required this.formatPrice,
    required this.colors,
    required this.scheme,
  });

  List<ChartPoint> get pts => series.points;

  @override
  void paint(Canvas canvas, Size size) {
    final plotRight = size.width - _Layout.axisWidth;
    final panes = studies.where((s) => s.hasPane).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final paneHeight = panes.isEmpty ? 0.0 : size.height * .2;
    final mainBottom = size.height -
        _Layout.timeAxisHeight -
        panes.length * (paneHeight + _Layout.paneGap);
    final main = Rect.fromLTRB(0, 6, plotRight, mainBottom);

    final first = start.floor().clamp(0, pts.length - 1);
    final last = (end.ceil() - 1).clamp(first, pts.length - 1);
    final span = max(1.0, end - start);
    final slot = main.width / span;
    double xOf(int i) => main.left + (i - start + .5) * slot;

    // Price range over the visible bars, overlays included.
    var lo = double.infinity, hi = -double.infinity;
    for (var i = first; i <= last; i++) {
      final p = pts[i];
      lo = min(lo, style == ChartStyle.candles ? p.low : p.close);
      hi = max(hi, style == ChartStyle.candles ? p.high : p.close);
      for (final line in series.lines.values) {
        final v = line[i];
        if (v != null) {
          lo = min(lo, v);
          hi = max(hi, v);
        }
      }
      final b = series.bands;
      if (b != null && b.upper[i] != null) {
        lo = min(lo, b.lower[i]!);
        hi = max(hi, b.upper[i]!);
      }
    }
    if (hi <= lo) {
      hi = lo + 1;
      lo = lo - 1;
    }
    final pad = (hi - lo) * .08;
    lo -= pad;
    hi += pad;
    final volumeBand = studies.contains(Study.volume) ? main.height * .18 : 0.0;
    final priceRect = Rect.fromLTRB(main.left, main.top, main.right, main.bottom - volumeBand);
    double yOf(double v) => priceRect.bottom - (v - lo) / (hi - lo) * priceRect.height;

    final muted = scheme.onSurfaceVariant;
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: .6)
      ..strokeWidth = 1;

    // Grid and price axis.
    for (var g = 0; g <= 4; g++) {
      final v = lo + (hi - lo) * g / 4;
      final y = yOf(v);
      _dashed(canvas, Offset(0, y), Offset(plotRight, y), grid);
      _text(canvas, formatPrice(v), Offset(plotRight + 6, y - 7), muted, 10);
    }

    // Reveal the series from the left on load.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, main.left + main.width * reveal, size.height));
    canvas.clipRect(Rect.fromLTRB(main.left, 0, main.right, size.height));

    // Volume.
    if (volumeBand > 0) {
      var maxVol = 0.0;
      for (var i = first; i <= last; i++) {
        maxVol = max(maxVol, pts[i].volume);
      }
      if (maxVol > 0) {
        final w = max(1.0, slot * .6);
        for (var i = first; i <= last; i++) {
          final h = pts[i].volume / maxVol * (volumeBand - 4);
          final c = pts[i].isUp ? colors.gain : colors.loss;
          canvas.drawRect(
            Rect.fromLTWH(xOf(i) - w / 2, main.bottom - h, w, h),
            Paint()..color = c.withValues(alpha: .28),
          );
        }
      }
    }

    // Bollinger bands.
    final b = series.bands;
    if (b != null) {
      final upper = _path(b.upper, first, last, xOf, yOf);
      final lower = _path(b.lower, first, last, xOf, yOf);
      final fill = Path();
      var started = false;
      for (var i = first; i <= last; i++) {
        final u = b.upper[i];
        if (u == null) continue;
        final o = Offset(xOf(i), yOf(u));
        started ? fill.lineTo(o.dx, o.dy) : fill.moveTo(o.dx, o.dy);
        started = true;
      }
      for (var i = last; i >= first; i--) {
        final l = b.lower[i];
        if (l == null) continue;
        fill.lineTo(xOf(i), yOf(l));
      }
      canvas.drawPath(fill, Paint()..color = scheme.secondary.withValues(alpha: .07));
      final band = Paint()
        ..color = scheme.secondary.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawPath(upper, band);
      canvas.drawPath(lower, band);
      _dashedPath(canvas, _path(b.middle, first, last, xOf, yOf), band);
    }

    // Price.
    final up = pts[last].close >= pts[first].close;
    final trend = up ? colors.gain : colors.loss;
    if (style == ChartStyle.candles) {
      final bodyW = (slot * .62).clamp(1.0, 14.0);
      for (var i = first; i <= last; i++) {
        final p = pts[i];
        final c = p.isUp ? colors.gain : colors.loss;
        final x = xOf(i);
        canvas.drawLine(Offset(x, yOf(p.high)), Offset(x, yOf(p.low)),
            Paint()
              ..color = c
              ..strokeWidth = max(1.0, min(1.6, slot * .12)));
        final top = yOf(max(p.open, p.close));
        final bottom = yOf(min(p.open, p.close));
        final body = Rect.fromLTRB(x - bodyW / 2, top, x + bodyW / 2, max(bottom, top + 1));
        canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(1.5)),
            Paint()..color = c);
      }
    } else {
      final line = _path(series.closes, first, last, xOf, yOf);
      final area = Path.from(line)
        ..lineTo(xOf(last), priceRect.bottom)
        ..lineTo(xOf(first), priceRect.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [trend.withValues(alpha: .26), trend.withValues(alpha: 0)],
          ).createShader(priceRect),
      );
      if (colors.glow) {
        canvas.drawPath(
          line,
          Paint()
            ..color = trend.withValues(alpha: .45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = trend
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Moving averages.
    for (final e in series.lines.entries) {
      canvas.drawPath(
        _path(e.value, first, last, xOf, yOf),
        Paint()
          ..color = studyColors[e.key]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    canvas.restore();

    // Last price marker.
    final lastPrice = pts.last.close;
    final ly = yOf(lastPrice);
    if (ly >= priceRect.top && ly <= priceRect.bottom) {
      _dashed(canvas, Offset(0, ly), Offset(plotRight, ly),
          Paint()
            ..color = trend.withValues(alpha: .7)
            ..strokeWidth = 1);
      _tag(canvas, formatPrice(lastPrice), Offset(plotRight + 2, ly), trend,
          _onColor(trend));
    }

    // Study panes.
    var top = mainBottom + _Layout.paneGap;
    for (final pane in panes) {
      final rect = Rect.fromLTWH(0, top, plotRight, paneHeight);
      canvas.drawLine(rect.topLeft, rect.topRight, grid);
      if (pane == Study.rsi && series.rsiLine != null) {
        _rsiPane(canvas, rect, first, last, xOf, muted, plotRight);
      } else if (pane == Study.macd && series.macdLines != null) {
        _macdPane(canvas, rect, first, last, xOf, muted, plotRight, slot);
      }
      top += paneHeight + _Layout.paneGap;
    }

    // Time axis.
    final axisY = size.height - _Layout.timeAxisHeight + 4;
    const labels = 4;
    for (var k = 0; k <= labels; k++) {
      final i = (first + (last - first) * k / labels).round();
      final label = _timeLabel(pts[i].time);
      final x = xOf(i).clamp(18.0, plotRight - 18);
      _text(canvas, label, Offset(x, axisY), muted, 10, center: true);
    }

    // Crosshair.
    final h = hover;
    if (h != null && h >= first && h <= last) {
      final x = xOf(h);
      final cross = Paint()
        ..color = scheme.onSurface.withValues(alpha: .55)
        ..strokeWidth = 1;
      _dashed(canvas, Offset(x, 0), Offset(x, size.height - _Layout.timeAxisHeight), cross);
      final p = pts[h];
      final y = yOf(p.close);
      _dashed(canvas, Offset(0, y), Offset(plotRight, y), cross);
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = scheme.surface);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = scheme.primary);
      _tag(canvas, formatPrice(p.close), Offset(plotRight + 2, y), scheme.onSurface,
          scheme.surface);
      final tl = _timeLabel(p.time, long: true);
      final tp = _layout(tl, scheme.surface, 10, bold: true);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x.clamp(tp.width / 2 + 6, plotRight - tp.width / 2 - 6),
              size.height - _Layout.timeAxisHeight / 2),
          width: tp.width + 12,
          height: 18,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(r, Paint()..color = scheme.onSurface);
      tp.paint(canvas, Offset(r.left + 6, r.top + (18 - tp.height) / 2));
    }
  }

  void _rsiPane(Canvas canvas, Rect rect, int first, int last, double Function(int) xOf,
      Color muted, double plotRight) {
    double y(double v) => rect.bottom - v / 100 * rect.height;
    final zone = Rect.fromLTRB(rect.left, y(70), rect.right, y(30));
    canvas.drawRect(zone, Paint()..color = scheme.primary.withValues(alpha: .06));
    final guide = Paint()
      ..color = muted.withValues(alpha: .5)
      ..strokeWidth = 1;
    _dashed(canvas, Offset(rect.left, y(70)), Offset(rect.right, y(70)), guide);
    _dashed(canvas, Offset(rect.left, y(30)), Offset(rect.right, y(30)), guide);
    _text(canvas, 'RSI', Offset(4, rect.top + 2), muted, 10, bold: true);
    _text(canvas, '70', Offset(plotRight + 6, y(70) - 7), muted, 10);
    _text(canvas, '30', Offset(plotRight + 6, y(30) - 7), muted, 10);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left, rect.top, rect.left + rect.width * reveal, rect.bottom));
    canvas.drawPath(
      _path(series.rsiLine!, first, last, xOf, y),
      Paint()
        ..color = const Color(0xFF8B5CF6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
    final v = series.rsiLine![hover ?? last];
    if (v != null) {
      _text(canvas, v.toStringAsFixed(1), Offset(30, rect.top + 2), const Color(0xFF8B5CF6), 10,
          bold: true);
    }
  }

  void _macdPane(Canvas canvas, Rect rect, int first, int last, double Function(int) xOf,
      Color muted, double plotRight, double slot) {
    final m = series.macdLines!;
    var lo = 0.0, hi = 0.0;
    for (var i = first; i <= last; i++) {
      for (final v in [m.macd[i], m.signal[i], m.histogram[i]]) {
        if (v == null) continue;
        lo = min(lo, v);
        hi = max(hi, v);
      }
    }
    if (hi - lo == 0) hi = lo + 1;
    double y(double v) => rect.bottom - 2 - (v - lo) / (hi - lo) * (rect.height - 14);
    _text(canvas, 'MACD', Offset(4, rect.top + 2), muted, 10, bold: true);
    canvas.drawLine(Offset(rect.left, y(0)), Offset(rect.right, y(0)),
        Paint()
          ..color = muted.withValues(alpha: .4)
          ..strokeWidth = 1);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left, rect.top, rect.left + rect.width * reveal, rect.bottom));
    final w = max(1.0, slot * .6);
    for (var i = first; i <= last; i++) {
      final hv = m.histogram[i];
      if (hv == null) continue;
      final c = hv >= 0 ? colors.gain : colors.loss;
      canvas.drawRect(Rect.fromPoints(Offset(xOf(i) - w / 2, y(0)), Offset(xOf(i) + w / 2, y(hv))),
          Paint()..color = c.withValues(alpha: .5));
    }
    canvas.drawPath(
        _path(m.macd, first, last, xOf, y),
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.drawPath(
        _path(m.signal, first, last, xOf, y),
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.restore();
  }

  Path _path(List<double?> values, int first, int last, double Function(int) xOf,
      double Function(double) yOf) {
    final path = Path();
    var started = false;
    for (var i = first; i <= last; i++) {
      final v = values[i];
      if (v == null) continue;
      final o = Offset(xOf(i), yOf(v));
      if (started) {
        path.lineTo(o.dx, o.dy);
      } else {
        path.moveTo(o.dx, o.dy);
        started = true;
      }
    }
    return path;
  }

  String _timeLabel(DateTime t, {bool long = false}) {
    if (intraday) {
      return long ? DateFormat('EEE d MMM, HH:mm').format(t) : DateFormat('HH:mm').format(t);
    }
    final spanDays = pts.last.time.difference(pts.first.time).inDays;
    if (long) return DateFormat('EEE d MMM yyyy').format(t);
    return spanDays > 500 ? DateFormat("MMM ''yy").format(t) : DateFormat('d MMM').format(t);
  }

  Color _onColor(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black;

  void _tag(Canvas canvas, String text, Offset leftCenter, Color bg, Color fg) {
    final tp = _layout(text, fg, 10, bold: true);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftCenter.dx, leftCenter.dy - 9, tp.width + 10, 18),
      const Radius.circular(5),
    );
    canvas.drawRRect(r, Paint()..color = bg);
    tp.paint(canvas, Offset(r.left + 5, r.top + (18 - tp.height) / 2));
  }

  TextPainter _layout(String text, Color color, double size, {bool bold = false}) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _text(Canvas canvas, String text, Offset at, Color color, double size,
      {bool center = false, bool bold = false}) {
    final tp = _layout(text, color, size, bold: bold);
    tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * min(d + dash, total), paint);
    }
  }

  void _dashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, min(d + 4, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.series != series ||
      old.style != style ||
      old.start != start ||
      old.end != end ||
      old.hover != hover ||
      old.reveal != reveal ||
      old.colors != colors ||
      old.scheme != scheme;
}
