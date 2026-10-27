import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/screens/onboarding_screen.dart';
import 'package:stock_pulse/services/logo_service.dart';
import 'package:stock_pulse/widgets/symbol_avatar.dart';
import 'package:stock_pulse/widgets/ui/pulse_indicator.dart';

void main() {
  testWidgets('Onboarding highlights the first-run actions', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: OnboardingScreen(onAction: (_) {}, onDone: () {}),
    ));
    // Run the entrance animation through so no timers are left pending.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Welcome to your money dashboard'), findsOneWidget);
    expect(find.text('Add your first holding'), findsOneWidget);
    expect(find.text('Or import everything at once'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-start')), findsOneWidget);
  });

  testWidgets('Navigation bar keeps labels readable', (tester) async {
    final widget = MaterialApp(home: Scaffold(
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        ],
      ),
    ));
    await tester.pumpWidget(widget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('PulseIndicator becomes static with reduced motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: PulseIndicator(size: 6)),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChangeChip renders up and down labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ChangeChip(percent: 1.23, label: '+1.23%'),
      ),
    ));
    expect(find.text('+1.23%'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ChangeChip(percent: -4.5, label: '-4.50%'),
      ),
    ));
    expect(find.text('-4.50%'), findsOneWidget);
  });

  testWidgets('ChangeChip handles unknown values', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ChangeChip(percent: null, label: '–'),
      ),
    ));
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('SymbolAvatar shows stable initials and colors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SymbolAvatar(symbol: 'AAPL'),
      ),
    ));
    expect(find.text('AA'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SymbolAvatar(symbol: 'BTC-USD'),
      ),
    ));
    expect(find.text('BT'), findsOneWidget);
  });

  testWidgets('SymbolAvatar keeps the letter badge when no logo exists',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SymbolAvatar(
          symbol: 'ZZZZ',
          logoService: _NoLogoService(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('ZZ'), findsOneWidget);
  });
}

/// A logo service that never finds a logo, so the fallback can be tested
/// without touching the network.
class _NoLogoService extends LogoService {
  @override
  Future<String?> logoUrlFor(String symbol, {String? companyName}) async =>
      null;
}