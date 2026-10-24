import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../services/csv_import.dart';
import '../services/export_service.dart';
import '../utils/formatters.dart';

class ImportScreen extends StatefulWidget {
  final bool embedded;
  const ImportScreen({super.key, this.embedded = false});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _pasteCtl = TextEditingController();
  ImportResult? _result;
  int? _symbolCol;
  int? _qtyCol;
  int? _costCol;
  int? _nameCol;
  bool _replace = false;
  String _targetMode = 'active'; // 'active' | 'new'
  final _newNameCtl = TextEditingController(text: 'Imported');
  bool _importing = false;

  static const _template = 'Symbol,Quantity,AvgCost\n'
      'AAPL,10,101.50\n'
      'SCHD,55,\n'
      'MSFT,4,243.20\n'
      'SHOP.TO,15,\n'
      'BTC-USD,0.25,58000\n';

  @override
  void dispose() {
    _pasteCtl.dispose();
    _newNameCtl.dispose();
    super.dispose();
  }

  void _parse(String content) {
    final result = parseImport(content);
    setState(() {
      _result = result;
      _symbolCol = result.symbolColumn;
      _qtyCol = result.quantityColumn;
      _costCol = result.costColumn;
      _nameCol = result.nameColumn;
    });
  }

  void _reparseWithMapping() {
    setState(() {
      _result = parseImport(_pasteCtl.text,
          symbolCol: _symbolCol,
          quantityCol: _qtyCol,
          costCol: _costCol,
          nameCol: _nameCol);
    });
  }

  Future<void> _pickFile() async {
    try {
      final picked = await ExportService.pickFile(extensions: ['csv', 'tsv', 'txt']);
      if (picked == null) return;
      _pasteCtl.text = picked.content.length > 20000
          ? picked.content.substring(0, 20000)
          : picked.content;
      _parse(_pasteCtl.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read file: $e')));
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _pasteCtl.text = data.text!;
      _parse(data.text!);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Clipboard is empty.')));
    }
  }

  Future<void> _doImport() async {
    final provider = context.read<PortfolioProvider>();
    final result = _result;
    if (result == null || result.holdings.isEmpty) return;
    setState(() => _importing = true);

    String targetId;
    if (_targetMode == 'new') {
      provider.addPortfolio(_newNameCtl.text.trim().isEmpty ? 'Imported' : _newNameCtl.text.trim());
      targetId = provider.active.id;
    } else {
      targetId = provider.active.id;
    }

    final count = await provider.importHoldings(
      portfolioId: targetId,
      parsed: result.holdings,
      replaceExisting: _replace,
    );

    if (!mounted) return;
    setState(() => _importing = false);
    final msg = _replace
        ? 'Imported: portfolio now has $count holding(s).'
        : 'Merged $count row(s) into the portfolio.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    // Kick off dividend seeding in background for the new symbols.
    provider.ensureDividendInfo(force: true).then((_) {
      if (mounted) setState(() {});
    });
    if (!widget.embedded && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _exportCurrentCsv() async {
    final provider = context.read<PortfolioProvider>();
    final p = provider.active;
    final rows = provider.holdingsCsvRows(p);
    final csv = [
      for (final r in rows)
        [for (final c in r) '"${c.replaceAll('"', '""')}"'].join(','),
    ].join('\n');
    final ok = await ExportService.saveOrShare(
      fileName: '${p.name.replaceAll(' ', '_')}_holdings.csv',
      content: csv,
      mimeType: 'text/csv',
    );
    if (mounted && ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Holdings exported.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PortfolioProvider>();
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import holdings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.map_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('How it works', style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Paste rows or open a CSV file exported from your broker. '
                      'Stock Pulse detects the columns automatically - Symbol, Quantity and '
                      'Average Cost (optional) are the only fields it needs. You can also '
                      'remap them yourself below.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Open CSV file'),
                            onPressed: _pickFile,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.content_paste, size: 18),
                            label: const Text('Paste clipboard'),
                            onPressed: _pasteFromClipboard,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pasteCtl,
              maxLines: 8,
              onChanged: (v) {
                if (v.trim().contains('\n') || v.trim().contains(',')) {
                  // Live-parse once we plausibly have rows.
                  _parse(v);
                } else if (v.trim().isEmpty) {
                  setState(() => _result = null);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Paste rows here',
                hintText: 'e.g.\nAAPL, 10, 101.50\nSCHD, 55, 28.10',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: const Text('Copy template'),
                  onPressed: () => Clipboard.setData(const ClipboardData(text: _template)),
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _pasteCtl.text.trim().isEmpty ? null : () => _parse(_pasteCtl.text),
                  child: const Text('Parse'),
                ),
              ],
            ),

          if (result != null) ...[
            const SizedBox(height: 12),
            _mappingSection(context, result),
            const SizedBox(height: 12),
            _previewSection(context, result),
            const SizedBox(height: 12),
            _targetSection(context, provider),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes & skipped rows',
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: 6),
                      for (final w in result.warnings.take(6))
                        Text('• $w', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: _importing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_done_outlined),
              label: Text(
                  _importing ? 'Importing...' : 'Import ${result.holdings.length} holding(s)'),
              onPressed: _importing || result.holdings.isEmpty ? null : _doImport,
            ),
            if (result.holdings.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text('Nothing importable was found in the text above.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                ),
              ),
          ],

          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Export current portfolio as CSV'),
              subtitle: Text(
                'Backup or migrate between devices. Portfolio: ${provider.active.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: _exportCurrentCsv,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Tip: copy the table straight out of your broker web page -\n'
              'semicolon, tab and comma separated data all work.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  static String _costText(double? v) {
    if (v == null || v <= 0) return '–';
    var s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  Widget _mappingSection(BuildContext context, ImportResult result) {
    final theme = Theme.of(context);
    final nCols = result.firstRow.length;
    final cells = result.firstRow;

    String label(int? col) {
      if (col == null || col < 0 || col >= cells.length) return 'Column $col';
      final c = cells[col].trim();
      return c.isEmpty ? 'Column ${col + 1}' : '"$c" (col ${col + 1})';
    }

    Widget dropdown(
        String title, int? value, bool required, void Function(int?) onChanged) {
      return DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          if (!required) const DropdownMenuItem(value: null, child: Text('(none)')),
          for (var i = 0; i < nCols; i++)
            DropdownMenuItem(value: i, child: Text(label(i), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.rule, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Column mapping',
                  style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                result.hadHeader ? 'header detected' : 'no header',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ]),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              final twoCols = c.maxWidth > 520;
              final w = twoCols ? (c.maxWidth - 12) / 2 : c.maxWidth;
              return SizedBox(
                height: twoCols ? 150 : 300,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                        width: w,
                        child: dropdown('Symbol column', _symbolCol, true, (v) {
                          _symbolCol = v;
                          _reparseWithMapping();
                        })),
                    SizedBox(
                        width: w,
                        child: dropdown('Quantity column', _qtyCol, true, (v) {
                          _qtyCol = v;
                          _reparseWithMapping();
                        })),
                    SizedBox(
                        width: w,
                        child: dropdown('Avg cost column', _costCol, false, (v) {
                          _costCol = v;
                          _reparseWithMapping();
                        })),
                    SizedBox(
                        width: w,
                        child: dropdown('Name column', _nameCol, false, (v) {
                          _nameCol = v;
                          _reparseWithMapping();
                        })),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _previewSection(BuildContext context, ImportResult result) {
    final theme = Theme.of(context);
    final preview = result.holdings.take(8).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preview (${result.holdings.length} holdings${result.skipped > 0 ? ', ${result.skipped} skipped' : ''})',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            DataTable(
              columnSpacing: 24,
              headingRowHeight: 32,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 34,
              columns: const [
                DataColumn(label: Text('Symbol')),
                DataColumn(label: Text('Quantity'), numeric: true),
                DataColumn(label: Text('Avg cost'), numeric: true),
              ],
              rows: [
                for (final h in preview)
                  DataRow(cells: [
                    DataCell(Text(h.symbol, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(fmtQty(h.quantity))),
                    DataCell(Text(_costText(h.avgCost))),
                  ]),
              ],
            ),
            if (result.holdings.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${result.holdings.length - 8} more...',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _targetSection(BuildContext context, PortfolioProvider provider) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destination', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Current portfolio')),
                ButtonSegment(value: 'new', label: Text('New portfolio')),
              ],
              selected: {_targetMode},
              onSelectionChanged: (s) => setState(() => _targetMode = s.first),
            ),
            if (_targetMode == 'new') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _newNameCtl,
                decoration: const InputDecoration(
                  labelText: 'New portfolio name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Goes into: ${provider.active.name}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Replace existing holdings'),
              subtitle: Text(
                'Off = merge with what is already there (quantities add, avg cost re-weights).',
                style: theme.textTheme.bodySmall,
              ),
              value: _replace,
              onChanged: (v) => setState(() => _replace = v),
            ),
          ],
        ),
      ),
    );
  }
}