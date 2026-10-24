import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/widgets/symbol_avatar.dart';

void main() {
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
}