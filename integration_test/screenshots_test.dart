import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_pulse/app.dart';
import 'package:stock_pulse/providers/portfolio_provider.dart';

/// Drives the app through every tab and captures a screenshot per tab.
/// Run by .github/workflows/screenshots.yml with:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart --screenshot=docs/screenshots
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(String name) async {
    await binding.takeScreenshot(name);
  }

  testWidgets('capture all tabs with seeded demo data', (tester) async {
    final provider = PortfolioProvider();
    await provider.load();
    provider.seedDemoData();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const StockPulseApp()),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await shot('01_portfolio');

    Future<void> go(IconData icon, String file) async {
      await tester.tap(find.byIcon(icon).last);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await shot(file);
    }

    // News + import tabs are empty-state on demo data unless network ran;
    // still capture them for completeness.
    await go(Icons.event_outlined, '02_dividends');
    await go(Icons.newspaper_outlined, '03_news');
    await go(Icons.upload_file_outlined, '04_import');
    await go(Icons.settings_outlined, '05_settings');
  });
}