import 'package:flutter/material.dart';

/// Compact statistic card used across screens.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  const StatCard({super.key, required this.label, required this.value, this.sub, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grid of stat cards (2 per row, filling any remainder).
class StatGrid extends StatelessWidget {
  final List<StatCard> cards;
  const StatGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final rows = <TableRow>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.only(right: 8, bottom: 8), child: cards[i]),
        if (i + 1 < cards.length)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: cards[i + 1])
        else
          const SizedBox(),
      ]));
    }
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
      children: rows,
    );
  }
}
