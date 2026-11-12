import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The chart range picker: one segmented bar, the selected range lit up.
class RangeSelector extends StatelessWidget {
  /// Range keys to their labels, in display order (for example `3mo: 3M`).
  final Map<String, String> ranges;
  final String selected;
  final ValueChanged<String> onChanged;

  const RangeSelector({
    super.key,
    required this.ranges,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final e in ranges.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == e.key,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (selected == e.key) return;
                    HapticFeedback.selectionClick();
                    onChanged(e.key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: selected == e.key
                          ? scheme.primary.withValues(alpha: .16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected == e.key
                            ? scheme.primary.withValues(alpha: .5)
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected == e.key
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
