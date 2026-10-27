import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_pulse/providers/portfolio_provider.dart';
import 'package:stock_pulse/screens/lock_gate.dart';

class _LockProvider extends PortfolioProvider {
  bool enabled = false;
  @override
  bool get loaded => true;
  @override
  bool get lockEnabled => enabled;

  void enable() {
    enabled = true;
    notifyListeners();
  }
}

void main() {
  testWidgets('unlock preserves navigator and input, background locks again', (tester) async {
    final provider = _LockProvider();
    final authentication = Completer<bool>();
    const channel = MethodChannel('plugins.flutter.io/local_auth');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'authenticate') return authentication.future;
      if (call.method == 'getAvailableBiometrics') return ['fingerprint'];
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(ChangeNotifierProvider<PortfolioProvider>.value(
      value: provider,
      child: MaterialApp(
        builder: (context, child) => LockGate(child: child!),
        home: const Scaffold(body: TextField()),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'keep my screen');
    provider.enable();
    await tester.pumpAndSettle();
    expect(find.text('Stock Pulse is locked'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    authentication.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Stock Pulse is locked'), findsNothing);
    expect(find.text('keep my screen'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Stock Pulse is locked'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
