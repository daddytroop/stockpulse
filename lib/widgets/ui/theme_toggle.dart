import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/portfolio_provider.dart';
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
      icon: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
      onPressed: () => showThemeSheet(context),
    );
  }
}

/// Opens the theme picker.
Future<void> showThemeSheet(BuildContext context) async {
  final provider = context.read<PortfolioProvider>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        // The sheet is scrollable so it never overflows on a short screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Theme',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final mode in AppThemeId.values)
                RadioListTile<AppThemeId>(
                  value: mode,
                  groupValue: provider.themeMode,
                  title: Text(mode.label),
                  secondary: _Preview(mode: mode),
                  onChanged: (v) {
                    if (v == null) return;
                    // Close first: applying the theme rebuilds the tree, and
                    // the sheet's context would be gone by then.
                    Navigator.of(ctx).pop();
                    provider.setThemeMode(v);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A small colour chip that shows what a theme looks like.
class _Preview extends StatelessWidget {
  final AppThemeId mode;

  const _Preview({required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.themeFor(mode, Brightness.light);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
      child: Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
