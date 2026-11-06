import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/services/store.dart';

void main() {
  test('overlapping saves of one file never lose it', () async {
    final dir = await Directory.systemTemp.createTemp('stockpulse_store');
    addTearDown(() => dir.delete(recursive: true));
    final store = StockPulseStore(directory: dir.path);

    // Several parts of the app save the same file at once on start-up.
    await Future.wait([
      for (var i = 0; i < 20; i++) store.save('data.json', {'n': i}),
    ]);

    final loaded = await store.load('data.json');
    expect(loaded, isNotNull, reason: 'the data file must still exist');
    expect(loaded!['n'], 19, reason: 'the last save wins');
    expect(File('${dir.path}/data.json.tmp').existsSync(), isFalse);
  });

  test('data that cannot be encoded is skipped, not thrown', () async {
    final dir = await Directory.systemTemp.createTemp('stockpulse_store');
    addTearDown(() => dir.delete(recursive: true));
    final store = StockPulseStore(directory: dir.path);
    await store.save('data.json', {'ok': 1});
    await store.save('data.json', {'bad': double.nan});
    expect((await store.load('data.json'))!['ok'], 1);
  });
}
