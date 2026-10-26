import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/models/quote.dart';
import 'package:stock_pulse/theme/app_theme.dart';
import 'package:stock_pulse/widgets/portfolio_chart.dart';

void main() {
  testWidgets('comparison legend fits a narrow panel with larger text', (tester) async {
    final points = [
      ChartPoint(DateTime(2026, 1, 1), 100),
      ChartPoint(DateTime(2026, 1, 2), 104),
      ChartPoint(DateTime(2026, 1, 3), 102),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Center(child: SizedBox(width: 260, child: PortfolioChart(
          points: points, benchmark: points, title: 'Relative growth',
        ))),
      )),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('SPY'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });
}
