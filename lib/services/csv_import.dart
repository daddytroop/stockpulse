/// Pure-Dart CSV/TSV import parser used by the bulk portfolio import.
///
/// Goals:
///  * No external dependencies (easy to unit test).
///  * Auto-detect delimiter (comma / semicolon / tab) and header row.
///  * Flexible column matching so broker exports "just work".
///  * Aggregate duplicate symbols into one weighted-average position.
library;

class ParsedHolding {
  final String symbol;
  final String? name;
  final double quantity;
  final double? avgCost;
  const ParsedHolding({required this.symbol, required this.quantity, this.avgCost, this.name});
}

class ImportResult {
  final List<ParsedHolding> holdings;
  final List<String> firstRow;
  final List<String> warnings;
  final bool hadHeader;
  final String delimiter;
  final int? symbolColumn;
  final int? quantityColumn;
  final int? costColumn;
  final int? nameColumn;
  final int skipped;

  const ImportResult({
    required this.holdings,
    required this.warnings,
    required this.hadHeader,
    required this.delimiter,
    required this.skipped,
    this.firstRow = const [],
    this.symbolColumn,
    this.quantityColumn,
    this.costColumn,
    this.nameColumn,
  });
}

/// Candidate header names for each field (lowercase).
const _symbolCandidates = [
  'symbol', 'ticker', 'sym', 'instrument', 'security', 'code', 'asset', 'stock symbol',
];
const _nameCandidates = [
  'name', 'stock name', 'company', 'company name', 'description', 'security name', 'asset name', 'label',
];
const _quantityCandidates = [
  'quantity', 'qty', 'shares', 'units', 'count', 'amount', 'number of shares', 'position', 'size', 'share count',
];
const _costCandidates = [
  'avg cost', 'average cost', 'avg price', 'average price', 'average purchase price',
  'purchase price', 'buy price', 'price', 'cost basis', 'cost', 'basis', 'unit cost',
  'acquisition price', 'book cost', 'avg. cost', 'avg. price', 'cost per share', 'value per share',
];

/// Parses a pasted or file-based portfolio import.
///
/// [symbolCol], [quantityCol], [costCol], [nameCol] override the detected
/// column mapping when non-null (set from the mapping UI).
ImportResult parseImport(
  String content, {
  int? symbolCol,
  int? quantityCol,
  int? costCol,
  int? nameCol,
  bool? forceHeader,
}) {
  final warnings = <String>[];

  // Normalize.
  var text = content;
  if (text.startsWith('\uFEFF')) text = text.substring(1); // BOM
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  if (text.isEmpty) {
    return ImportResult(
      holdings: const [], warnings: ['Nothing to import.'], hadHeader: false,
      delimiter: ',', skipped: 0,
    );
  }

  final delimiter = _sniffDelimiter(text);
  final rawRows = _splitRows(text);
  final rows = <List<String>>[];
  for (final line in rawRows) {
    final cells = _parseLine(line, delimiter);
    if (cells.any((c) => c.trim().isNotEmpty)) rows.add(cells);
  }
  if (rows.isEmpty) {
    return ImportResult(
      holdings: const [], warnings: ['Nothing to import.'], hadHeader: false,
      delimiter: delimiter, skipped: 0,
    );
  }

  // Header detection.
  var hadHeader = forceHeader ?? _looksLikeHeader(rows.first);
  int symbolIndex, quantityIndex, costIndex, nameIndex;

  if (hadHeader) {
    final header = rows.first.map((c) => c.trim().toLowerCase()).toList();
    symbolIndex = symbolCol ?? _findColumn(header, _symbolCandidates);
    quantityIndex = quantityCol ?? _findColumn(header, _quantityCandidates);
    costIndex = costCol ?? _findColumn(header, _costCandidates);
    nameIndex = nameCol ?? _findColumn(header, _nameCandidates);
  } else {
    symbolIndex = symbolCol ?? 0;
    quantityIndex = quantityCol ?? (rows.first.length >= 2 ? 1 : -1);
    costIndex = costCol ?? (rows.first.length >= 3 ? 2 : -1);
    nameIndex = nameCol ?? (rows.first.length >= 4 ? 3 : -1);
  }

  if (symbolIndex < 0 || quantityIndex < 0) {
    return ImportResult(
      holdings: const [],
      warnings: const ['Could not find symbol and quantity columns. Use the column mapping to pick them manually.'],
      hadHeader: hadHeader,
      delimiter: delimiter,
      skipped: hadHeader ? rows.length - 1 : rows.length,
      firstRow: rows.first,
    );
  }

  // Parse data rows.
  final dataRows = hadHeader ? rows.sublist(1) : rows;
  final merged = <String, _MutableParsed>{};
  var skipped = 0;

  for (var i = 0; i < dataRows.length; i++) {
    final row = dataRows[i];
    final rowNo = (hadHeader ? i + 2 : i + 1); // 1-based, header counts
    final rawSymbol = row.length > symbolIndex ? row[symbolIndex].trim() : '';
    if (rawSymbol.isEmpty) continue; // silently skip empty rows

    final symbol = rawSymbol.toUpperCase().replaceAll('\$', '');
    final qty = parseFlexibleDouble(row[quantityIndex]);
    if (qty == null || qty == 0) {
      warnings.add('Row $rowNo: could not read quantity for "$rawSymbol" - skipped');
      skipped++;
      continue;
    }
    final cost = costIndex >= 0 && row.length > costIndex ? parseFlexibleDouble(row[costIndex]) : null;
    final name = nameIndex >= 0 && row.length > nameIndex && row[nameIndex].trim().isNotEmpty
        ? row[nameIndex].trim()
        : null;

    final existing = merged[symbol];
    if (existing == null) {
      merged[symbol] = _MutableParsed(symbol: symbol, name: name, quantity: qty, cost: cost);
    } else {
      existing.add(quantity: qty, cost: cost);
      if (existing.name == null && name != null) existing.name = name;
    }
  }

  final holdings = [
    for (final m in merged.values)
      ParsedHolding(
          symbol: m.symbol, name: m.name, quantity: m.quantity, avgCost: m.weightedCost),
  ]..sort((a, b) => a.symbol.compareTo(b.symbol));

  return ImportResult(
    holdings: holdings,
    warnings: warnings,
    hadHeader: hadHeader,
    delimiter: delimiter,
    skipped: skipped,
    firstRow: rows.first,
    symbolColumn: symbolIndex,
    quantityColumn: quantityIndex,
    costColumn: costIndex,
    nameColumn: nameIndex,
  );
}

class _MutableParsed {
  final String symbol;
  String? name;
  double quantity = 0;
  double costSum = 0;
  double costQty = 0;
  double? firstCost;

  _MutableParsed({required this.symbol, this.name, required double quantity, double? cost}) {
    add(quantity: quantity, cost: cost);
  }

  void add({required double quantity, double? cost}) {
    this.quantity += quantity;
    if (cost != null && cost > 0) {
      costQty += quantity;
      costSum += cost * quantity;
      firstCost ??= cost;
    }
  }

  double? get weightedCost => costQty > 0 ? costSum / costQty : firstCost;
}

// -----------------------------------------------------------------------------
// Delimiter & header detection
// -----------------------------------------------------------------------------

String _sniffDelimiter(String text) {
  final sample = text.split('\n').take(8).join('\n');
  int comma = sample.split(',').length - 1;
  int semi = sample.split(';').length - 1;
  int tab = sample.split('\t').length - 1;
  if (tab >= comma && tab >= semi && tab > 0) return '\t';
  if (semi > comma) return ';';
  return ',';
}

List<String> _splitRows(String text) {
  // Split on newlines that are not inside quoted fields.
  final rows = <String>[];
  final cur = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == '"') {
      // doubled quote inside quotes stays part of the field
      if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
        cur.write('"');
        i++;
        continue;
      }
      inQuotes = !inQuotes;
      cur.write(ch);
    } else if (ch == '\n' && !inQuotes) {
      rows.add(cur.toString());
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  if (cur.isNotEmpty) rows.add(cur.toString());
  return rows;
}

List<String> _parseLine(String line, String delimiter) {
  final cells = <String>[];
  final cur = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
        continue;
      }
      inQuotes = !inQuotes;
    } else if (ch == delimiter && !inQuotes) {
      cells.add(cur.toString());
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  cells.add(cur.toString());
  return cells;
}

bool _looksLikeHeader(List<String> cells) {
  final lower = cells.map((c) => c.trim().toLowerCase()).toList();
  int hits = 0;
  for (final c in lower) {
    if (_symbolCandidates.contains(c) ||
        _quantityCandidates.contains(c) ||
        _costCandidates.contains(c) ||
        _nameCandidates.contains(c)) {
      hits++;
    }
  }
  if (hits >= 2) return true;
  // A single exact hit like a "Ticker" column header.
  if (hits == 1 && lower.any((c) => c == 'symbol' || c == 'ticker')) return true;
  return false;
}

int _findColumn(List<String> header, List<String> candidates) {
  for (final cand in candidates) {
    final idx = header.indexOf(cand);
    if (idx >= 0) return idx;
  }
  // Contains-match fallback (e.g. "Average Cost (USD)").
  for (final cand in candidates) {
    final idx = header.indexWhere((c) => c.contains(cand));
    if (idx >= 0) return idx;
  }
  return -1;
}

/// Parses numbers written by humans or brokers:
/// "10", "1,234.5", "1.234,5", "10.5 ", "USD 10.50", "$1,500".
double? parseFlexibleDouble(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll('\u00A0', ' '); // nbsp
  s = s.replaceAll(' ', '');
  s = s.replaceAll(RegExp(r'[\$£€¥₹]'), '');
  s = s.toUpperCase().replaceAll(RegExp(r'[A-Z]{2,}'), ''); // ISO codes like USD
  s = s.replaceAll('-', ''); // dashes like "10-05-2026" -> invalid anyway

  final hasComma = s.contains(',');
  final hasDot = s.contains('.');
  if (hasComma && hasDot) {
    // Whichever separator appears last is the decimal separator.
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (hasComma) {
    // Single comma followed by != 3 digits -> decimal comma ("1,5").
    final parts = s.split(',');
    final isDecimalComma = parts.length == 2 && parts[1].length != 3;
    if (isDecimalComma) {
      s = parts.join('.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (hasDot) {
    // Multiple dots -> thousands separators ("1.234.567").
    if (RegExp(r'\..*\.').hasMatch(s)) s = s.replaceAll('.', '');
  }

  s = s.replaceAll(RegExp(r'[^0-9.]'), '');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Column detection used by the mapping UI: returns whether the given header
/// row can be auto-resolved. (Also exported for tests.)
bool canDetectColumns(List<String> headerCells) {
  final header = headerCells.map((c) => c.trim().toLowerCase()).toList();
  return _findColumn(header, _symbolCandidates) >= 0 && _findColumn(header, _quantityCandidates) >= 0;
}