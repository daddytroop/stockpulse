import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../services/export_service.dart';
import '../services/widget_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> _currencyOptions = [
    'USD', 'CAD', 'EUR', 'GBP', 'AUD', 'NZD', 'CHF', 'JPY',
    'SEK', 'NOK', 'DKK', 'PLN', 'CZK', 'HUF', 'TRY', 'ZAR',
    'MXN', 'BRL', 'SGD', 'HKD', 'INR', 'MYR',
  ];

  static String _currencyLabel(String code) {
    if (code.isEmpty) return 'None (native currencies)';
    const names = {
      'USD': 'US Dollar (USD)', 'CAD': 'Canadian Dollar (CAD)', 'EUR': 'Euro (EUR)',
      'GBP': 'British Pound (GBP)', 'AUD': 'Australian Dollar (AUD)',
      'NZD': 'NZ Dollar (NZD)', 'CHF': 'Swiss Franc (CHF)', 'JPY': 'Japanese Yen (JPY)',
      'SEK': 'Swedish Krona (SEK)', 'NOK': 'Norwegian Krone (NOK)',
      'DKK': 'Danish Krone (DKK)', 'PLN': 'Polish Zloty (PLN)',
      'CZK': 'Czech Koruna (CZK)', 'HUF': 'Hungarian Forint (HUF)',
      'TRY': 'Turkish Lira (TRY)', 'ZAR': 'SA Rand (ZAR)', 'MXN': 'Mexican Peso (MXN)',
      'BRL': 'Brazilian Real (BRL)', 'SGD': 'Singapore Dollar (SGD)',
      'HKD': 'Hong Kong Dollar (HKD)', 'INR': 'Indian Rupee (INR)',
      'MYR': 'Malaysian Ringgit (MYR)',
    };
    return names[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          _section(context, 'Portfolios'),
          for (final p in provider.portfolios)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Icon(
                  p.id == provider.activeOrNull?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: theme.colorScheme.primary,
                ),
                title: Text(p.name),
                subtitle: Text('${p.holdings.length} holding(s)'),
                onTap: () {
                  final i = provider.portfolios.indexOf(p);
                  provider.setActiveIndex(i);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Rename',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () async {
                        final name = await _askText(context, 'Rename portfolio', p.name);
                        if (name != null && name.trim().isNotEmpty) {
                          provider.renamePortfolio(p.id, name);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: provider.portfolioCount > 1
                          ? () => provider.deletePortfolio(p.id)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.playlist_add),
                label: const Text('New portfolio'),
                onPressed: () async {
                  final name = await _askText(context, 'New portfolio', '');
                  if (name != null && name.trim().isNotEmpty) {
                    provider.addPortfolio(name);
                  }
                },
              ),
            ),
          ),

          _section(context, 'Display currency'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Convert all totals into one currency (FX rates from Yahoo, '
                    'fetched hourly). Leave as "None" to show each holding in '
                    'its native currency.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: provider.displayCurrency,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('None (native currencies)')),
                      for (final c in _currencyOptions)
                        DropdownMenuItem(value: c, child: Text(_currencyLabel(c))),
                    ],
                    onChanged: (v) => provider.setDisplayCurrency(v ?? ''),
                  ),
                  if (provider.fxLoading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (provider.converting && !provider.fxLoading) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Totals shown in ${_currencyLabel(provider.displayCurrency)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ],
              ),
            ),
          ),

          _section(context, 'Appearance'),
          Card(
            child: Column(
              children: [
                for (final mode in ThemeMode.values)
                  RadioAdaptiveTile(
                    groupValue: provider.themeMode,
                    value: mode,
                    title: switch (mode) {
                      ThemeMode.system => 'Follow system',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    },
                    onChanged: (v) => provider.setThemeMode(v),
                  ),
              ],
            ),
          ),

          _section(context, 'Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Export backup (JSON)'),
                  subtitle: const Text('Full backup including portfolios and settings'),
                  onTap: () => _exportBackup(context, provider),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('Restore backup'),
                  subtitle: const Text('Replaces current data with a backup file'),
                  onTap: () => _restoreBackup(context, provider),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_outlined),
                  title: const Text('Refresh quotes on start'),
                  value: provider.autoRefreshOnStart,
                  onChanged: (v) => provider.setAutoRefreshOnStart(v),
                ),
              ],
            ),
          ),

          _section(context, 'Android home-screen widgets'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    StockPulseWidgetService.supported
                        ? 'Two widgets are available in your launcher\'s widget picker:\n'
                            '• Stock Pulse — portfolio value + daily change + next dividend\n'
                            '• Stock Pulse (Next Dividend) — compact dividend countdown\n\n'
                            'Add them from the home screen: long-press wallpaper → Widgets → Stock Pulse.'
                        : 'Widgets are available on Android. On this platform the in-app '
                            'dashboards are your dashboard.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.update),
                    label: const Text('Push current values to widgets'),
                    onPressed: StockPulseWidgetService.supported
                        ? () async {
                            await provider.pushWidgets();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Widgets updated.')),
                              );
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),

          _section(context, 'About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock Pulse v1.0.0', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    'A free, open-source replacement for paid portfolio trackers. '
                    'Market data comes from Yahoo Finance\'s unofficial endpoints; '
                    'dividend and earnings dates may be estimated (marked with *).\n\n'
                    'This app is for tracking only and is not investment advice. '
                    'Prices are delayed and currency conversion between holdings is not applied.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, PortfolioProvider provider) async {
    final json = const JsonEncoder.withIndent('  ').convert(provider.exportBackup());
    final ok = await ExportService.saveOrShare(
      fileName:
          'stockpulse_backup_${DateTime.now().toIso8601String().substring(0, 10)}.json',
      content: json,
      mimeType: 'application/json',
    );
    if (context.mounted && ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Backup saved.')));
    }
  }

  Future<void> _restoreBackup(BuildContext context, PortfolioProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
            'This replaces all current portfolios with the backup file contents. '
            'Cached quotes and dividend history stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final picked = await ExportService.pickFile(extensions: ['json']);
      if (picked == null) return;
      final data = jsonDecode(picked.content);
      if (data is! Map<String, dynamic>) throw 'Not a valid backup file.';
      final ok = await provider.restoreBackup(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Backup restored.' : 'No portfolios found in that file.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}

Future<String?> _askText(BuildContext context, String title, String initial) async {
  final ctl = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('OK')),
      ],
    ),
  );
  return value;
}

class RadioAdaptiveTile extends StatelessWidget {
  final ThemeMode groupValue;
  final ThemeMode value;
  final String title;
  final void Function(ThemeMode) onChanged;
  const RadioAdaptiveTile({
    super.key,
    required this.groupValue,
    required this.value,
    required this.title,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}