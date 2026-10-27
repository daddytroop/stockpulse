import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/widgets/pulse_logo.dart';

void main() {
  group('PulseLogo', () {
    testWidgets('renders the tile and the mark', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PulseLogo(size: 64)),
      ));
      expect(find.byType(PulseLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('can render the bare mark without a tile', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PulseLogo(size: 64, tiled: false)),
      ));
      expect(find.byType(PulseLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('brand colours are the ones used for the launcher artwork', () {
      expect(PulseBrand.background, const Color(0xFF061D2B));
      expect(PulseBrand.mark, const Color(0xFF64EFAE));
    });
  });
}
