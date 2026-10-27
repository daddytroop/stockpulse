import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/widgets/ui/kpi_tile.dart';

void main() {
  group('KpiTile', () {
    testWidgets('shows the label and the value', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KpiTile(
            label: 'Annual income',
            value: 1234.5,
            formatter: (v) => '\$${v.toStringAsFixed(2)}',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Annual income'), findsOneWidget);
      expect(find.textContaining('1234'), findsOneWidget);
    });

    testWidgets('shows the sub line when given', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KpiTile(
            label: 'Today',
            value: 10,
            formatter: (v) => '\$$v',
            sub: 'up 2% vs yesterday',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('up 2% vs yesterday'), findsOneWidget);
    });

    testWidgets('renders a sparkline without error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KpiTile(
            label: 'Trend',
            value: 1,
            formatter: (v) => '$v',
            spark: const [1, 3, 2, 5, 4, 8],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('KpiRow', () {
    testWidgets('lays tiles out without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KpiRow(
            tiles: [
              for (final label in ['A', 'B', 'C', 'D', 'E'])
                KpiTile(
                  label: label,
                  value: 1,
                  formatter: (v) => '$v',
                  sub: 'detail',
                ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(KpiTile), findsNWidgets(5));
    });
  });
}
