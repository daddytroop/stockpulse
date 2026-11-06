import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/pro_screen.dart';
import '../services/app_icon_service.dart';
import '../services/pro_service.dart';
import 'pulse_logo.dart';

/// Picks the home-screen icon (Android). The alternate icons are Pro.
class AppIconPicker extends StatefulWidget {
  const AppIconPicker({super.key});

  @override
  State<AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends State<AppIconPicker> {
  AppIconStyle? _current;

  @override
  void initState() {
    super.initState();
    AppIconService.current().then((s) {
      if (mounted) setState(() => _current = s);
    });
  }

  Future<void> _choose(AppIconStyle style) async {
    if (style == _current) return;
    if (style.isPremium && !context.read<ProService>().has(ProFeature.themes)) {
      final unlocked = await showProPaywall(context, feature: ProFeature.themes);
      if (!unlocked || !mounted) return;
    }
    final ok = await AppIconService.set(style);
    if (!mounted) return;
    if (ok) setState(() => _current = style);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Icon changed. Some launchers take a moment, and may move it off your home screen.'
          : 'This launcher did not accept the new icon.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!AppIconService.supported) return const SizedBox.shrink();
    final unlocked = context.watch<ProService>().has(ProFeature.themes);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('App icon',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (!unlocked) const ProBadge(locked: true),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                for (final s in AppIconStyle.values)
                  GestureDetector(
                    onTap: () => _choose(s),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: s.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              width: 2.5,
                              color: _current == s
                                  ? theme.colorScheme.primary
                                  : Colors.white.withValues(alpha: .08),
                            ),
                            boxShadow: [
                              if (_current == s)
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: .4),
                                  blurRadius: 12,
                                ),
                            ],
                          ),
                          child: Center(
                            child: PulseLogo(size: 40, tiled: false, markColor: s.mark),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(s.label, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
