import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/services/csv_import.dart';

void main() {
  group('parseFlexibleDouble', () {
    test('parses plain numbers', () {
      expect(parseFlexibleDouble('10'), 10.0);
      expect(parseFlexibleDouble('10.55'), 10.55);
    });
    test('parses thousands separators', () {
      expect(parseFlexibleDouble('1,234'), 1234.0);
      expect(parseFlexibleDouble('1,234.56'), 1234.56);
      expect(parseFlexibleDouble('1.234.567'), 1234567.0);
    });
    test('parses decimal comma', () {
      expect(parseFlexibleDouble('1,5'), 1.5);
      expect(parseFlexibleDouble('1.234,56'), 1234.56);
    });
    test('strips currency symbols and codes', () {
      expect(parseFlexibleDouble('USD 10.50'), 10.5);
      expect(parseFlexibleDouble('\$1,500.00'), 1500.0);
      expect(parseFlexibleDouble('CAD 12.5'), 12.5);
    });
    test('handles whitespace and rejects junk', () {
      expect(parseFlexibleDouble(' 10 '), 10.0);
      expect(parseFlexibleDouble(''), isNull);
      expect(parseFlexibleDouble(null), isNull);
      expect(parseFlexibleDouble('abc'), isNull);
    });
  });

  group('parseImport', () {
    test('auto-detects header columns', () {
      final r = parseImport('Ticker,Quantity,Avg Cost\nAAPL,10,101.5\nMSFT,4,243.2\n');
      expect(r.hadHeader, isTrue);
      expect(r.holdings.length, 2);
      expect(r.holdings.first.symbol, 'AAPL');
      expect(r.holdings.first.quantity, 10);
      expect(r.holdings.first.avgCost, 101.5);
    });

    test('parses semicolon-separated exports', () {
      final r = parseImport('Symbol;Shares;Price\nSCHD;55;28.10\n');
      expect(r.delimiter, ';');
      expect(r.holdings.first.quantity, 55);
    });

    test('parses tab-separated exports', () {
      final r = parseImport('Symbol\tShares\nMSFT\t4\n');
      expect(r.delimiter, '\t');
      expect(r.holdings.first.symbol, 'MSFT');
    });

    test('assumes default columns when no header', () {
      final r = parseImport('AAPL,10,101.5\nSHOP.TO,15,\n');
      expect(r.hadHeader, isFalse);
      expect(r.holdings.first.avgCost, 101.5);
      expect(r.holdings[1].symbol, 'SHOP.TO');
      expect(r.holdings[1].avgCost, isNull);
    });

    test('aggregates duplicate symbols with weighted average', () {
      final r = parseImport('Symbol,Quantity,Price\nAAPL,10,100\nAAPL,10,200\n');
      expect(r.holdings.length, 1);
      expect(r.holdings.first.quantity, 20);
      expect(r.holdings.first.avgCost, 150.0);
    });

    test('handles quoted fields containing separators', () {
      final r =
          parseImport('Symbol,Name,Quantity,Price\n"MSFT","Company, Inc.",4,"1,234.50"\n');
      expect(r.holdings.first.name, 'Company, Inc.');
      expect(r.holdings.first.quantity, 4);
      expect(r.holdings.first.avgCost, 1234.5);
    });

    test('handles quoted multiline fields', () {
      final r = parseImport('Symbol,Name,Quantity\n"MSFT","Company\nwith newline",4\n');
      expect(r.holdings.first.name, 'Company\nwith newline');
      expect(r.holdings.first.quantity, 4);
    });

    test('warns on unparseable quantities', () {
      final r = parseImport('Symbol,Quantity\nAAPL,ten\nMSFT,4\n');
      expect(r.holdings.length, 1);
      expect(r.warnings, isNotEmpty);
      expect(r.skipped, 1);
    });

    test('normalizes symbols to upper case', () {
      final r = parseImport('Symbol,Quantity\naapl,10\n');
      expect(r.holdings.first.symbol, 'AAPL');
    });

    test('overrides mapping when columns provided', () {
      final r = parseImport(
        'AAPL,101.5,10\n', // symbol, price, quantity (non-standard order)
        symbolCol: 0,
        quantityCol: 2,
        costCol: 1,
        forceHeader: false,
      );
      expect(r.holdings.first.quantity, 10);
      expect(r.holdings.first.avgCost, 101.5);
    });
  });

  group('canDetectColumns', () {
    test('accepts a header row', () {
      expect(canDetectColumns(['Ticker', 'Qty', 'Price']), isTrue);
    });
    test('rejects a data row', () {
      expect(canDetectColumns(['AAPL', '10', '101.5']), isFalse);
    });
  });
}