import 'package:flutter/material.dart';

import '../services/logo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Round avatar that shows the real company logo when one can be resolved,
/// and a stable coloured letter badge otherwise.
///
/// The letter badge is always painted underneath, so the avatar never shows
/// an empty circle while the logo loads and keeps working if the logo
/// cannot be downloaded.
class SymbolAvatar extends StatefulWidget {
  final String symbol;
  final double radius;

  /// Name of the company the symbol belongs to; used to pick the right logo
  /// when a ticker is shared by several issuers.
  final String? companyName;

  /// Overrides the logo lookup. Mainly useful for tests.
  final LogoService? logoService;

  const SymbolAvatar({
    super.key,
    required this.symbol,
    this.radius = 18,
    this.companyName,
    this.logoService,
  });

  static Color colorFor(BuildContext context, String symbol) {
    final palette = AppColors.of(context).allocationPalette;
    return palette[colorIndexFor(symbol) % palette.length];
  }

  @override
  State<SymbolAvatar> createState() => _SymbolAvatarState();
}

class _SymbolAvatarState extends State<SymbolAvatar> {
  static final LogoService _defaultLogos = LogoService();
  Future<String?>? _pending;

  LogoService get _logos => widget.logoService ?? _defaultLogos;

  @override
  void initState() {
    super.initState();
    _pending = _resolve();
  }

  @override
  void didUpdateWidget(SymbolAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.companyName != widget.companyName ||
        oldWidget.logoService != widget.logoService) {
      _pending = _resolve();
    }
  }

  Future<String?> _resolve() =>
      _logos.logoUrlFor(widget.symbol, companyName: widget.companyName);

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    return FutureBuilder<String?>(
      future: _pending,
      builder: (context, snapshot) {
        final url = snapshot.data;
        return ClipOval(
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _letterAvatar(context),
                if (url != null && url.isNotEmpty)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(2),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      semanticLabel: '${widget.symbol} logo',
                      // Fades in over the letter badge, so the avatar is
                      // never blank while the logo downloads.
                      frameBuilder: (context, child, frame, wasSyncLoaded) {
                        if (wasSyncLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: child,
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _letterAvatar(BuildContext context) {
    final color = SymbolAvatar.colorFor(context, widget.symbol);
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: color,
      child: Text(
        _initials(widget.symbol),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: widget.radius * 0.9,
        ),
      ),
    );
  }

  String _initials(String symbol) {
    final clean = symbol.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isEmpty) return '?';
    if (clean.length == 1) return clean;
    // Take letters from the start; crypto like BTC-USD -> BT.
    return clean.substring(0, 2);
  }
}

/// Small circular percentage/change chip, color-coded.
class ChangeChip extends StatelessWidget {
  final double? percent;
  final String label;
  const ChangeChip({super.key, required this.percent, required this.label});

  Color _color(BuildContext context) {
    final colors = AppColors.of(context);
    if (percent == null) return Theme.of(context).hintColor;
    if (percent! > 0) return colors.gain;
    if (percent! < 0) return colors.loss;
    return Theme.of(context).hintColor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (percent != null && percent! != 0)
            Icon(
              percent! > 0 ? Icons.trending_up : Icons.trending_down,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
