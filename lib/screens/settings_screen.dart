import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../services/diagnostics.dart';
import '../services/export_service.dart';
import '../services/sync_service.dart';
import '../services/widget_service.dart';
import '../utils/formatters.dart';
import '../widgets/ui/section_header.dart';

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
                for (final mode in AppThemeId.values)
                  RadioAdaptiveTile(
                    groupValue: provider.themeMode,
                    value: mode,
                    title: mode.label,
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

          _section(context, 'Web build (browser)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kIsWeb
                        ? 'Yahoo blocks direct browser calls (no CORS), so the web build '
                            'needs the small Cloudflare Worker proxy included in the repo '
                            '(cloudflare/). Deploy it with `npx wrangler deploy` and enter '
                            'its URL here.'
                        : 'This section matters only for the Flutter web build; on this '
                            'platform Yahoo is contacted directly.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (provider.webProxyUrl.isNotEmpty)
                    Text('Current: ${provider.webProxyUrl}',
                        style: theme.textTheme.labelSmall),
                  const SizedBox(height: 6),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(provider.webProxyUrl.isEmpty
                        ? 'Enter proxy URL'
                        : 'Change proxy URL'),
                    onPressed: () async {
                      final url = await showDialog<String>(
                        context: context,
                        builder: (ctx) {
                          final ctl =
                              TextEditingController(text: provider.webProxyUrl);
                          return AlertDialog(
                            title: const Text('Yahoo proxy URL'),
                            content: TextField(
                              controller: ctl,
                              decoration: const InputDecoration(
                                hintText: 'https://yahoo-proxy.yourname.workers.dev',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (v) => Navigator.of(ctx).pop(v),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(ctl.text),
                                  child: const Text('Save')),
                            ],
                          );
                        },
                      );
                      if (url != null) await provider.setWebProxyUrl(url);
                    },
                  ),
                ],
              ),
            ),
          ),

          _section(context, 'Security'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Biometric lock'),
              subtitle: const Text(
                  'Require fingerprint/face or Windows Hello when the app opens '
                  'or returns from the background'),
              value: provider.lockEnabled,
              onChanged: (v) => _toggleLock(context, provider, v),
            ),
          ),

          _section(context, 'Cloud sync (private Gist)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.hasSyncConfig
                        ? 'Portfolios sync to a private GitHub Gist. PUSH overwrites '
                            'the gist with this device; PULL replaces this device with '
                            'the gist (no merging - pull carefully).'
                        : 'Back up & restore through a private GitHub Gist that you '
                            'own. Needs a GitHub token with the "gist" scope - the '
                            'token is stored only on this device.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link, size: 18),
                        label: Text(
                            provider.hasSyncConfig ? 'Change token / gist' : 'Set up sync'),
                        onPressed: () => _configureSync(context, provider),
                      ),
                      if (provider.hasSyncConfig) ...[
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: const Text('Push'),
                          onPressed: () => _syncPush(context, provider),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.cloud_download_outlined, size: 18),
                          label: const Text('Pull'),
                          onPressed: () => _syncPull(context, provider),
                        ),
                      ],
                    ],
                  ),
                  if (provider.hasSyncConfig && provider.lastSyncAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last synced: ${fmtDate(provider.lastSyncAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ],
              ),
            ),
          ),

          _section(context, 'Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.payments_outlined),
                  title: const Text('Dividend alerts'),
                  subtitle: const Text('When an ex-dividend date lands today'),
                  value: provider.notifyDividends,
                  onChanged: (v) => provider.setNotifyDividends(v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.query_stats_outlined),
                  title: const Text('Earnings alerts'),
                  subtitle: const Text('When a holding reports earnings today'),
                  value: provider.notifyEarnings,
                  onChanged: (v) => provider.setNotifyEarnings(v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Daily price-move alert'),
                  subtitle: const Text('When a holding moves at least this much in a day'),
                  trailing: DropdownButton<double>(
                    value: provider.priceAlertPct,
                    items: const [
                      DropdownMenuItem(value: 0.0, child: Text('Off')),
                      DropdownMenuItem(value: 3.0, child: Text('3%')),
                      DropdownMenuItem(value: 5.0, child: Text('5%')),
                      DropdownMenuItem(value: 8.0, child: Text('8%')),
                    ],
                    onChanged: (v) => provider.setPriceAlertPct(v ?? 0),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Checked hourly in the background on Android (works even '
                    'when the app is closed). Android may ask for notification '
                    'permission on first launch. Widgets refresh on the same '
                    'schedule and on every app open.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
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

          _section(context, 'Privacy & diagnostics'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.favorite_border),
                  title: const Text('Optional crash diagnostics'),
                  subtitle: const Text('Write a short, redacted local error log only '
                    'when this is enabled. It is never sent automatically; share it '
                    'only with a bug report if you want to.'),
                  value: provider.crashDiagnostics,
                  onChanged: provider.setCrashDiagnostics,
                ),
                if (Diagnostics.path != null)
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Diagnostics log'),
                    subtitle: Text(Diagnostics.path!),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Portfolio data is local. Optional Gist sync stores a backup in the '
                    'private Gist you own. Android advertising asks Google ad services for '
                    'a banner and consent status. Diagnostics never include symbols, '
                    'quantities, tokens, or account numbers when enabled.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          _section(context, 'About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stock Pulse v1.3.1', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'A free, open-source replacement for paid portfolio trackers. '
                    'Market data comes from Yahoo Finance\'s unofficial endpoints; '
                    'dividend and earnings dates may be estimated (marked with *).\n\n'
                    'This app is for tracking only and is not investment advice. '
                    'Prices are delayed; enabling a display currency applies Yahoo FX rates.',
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
    return SectionHeader(
      title: title,
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
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

  Future<void> _toggleLock(
      BuildContext context, PortfolioProvider provider, bool want) async {
    if (!want) {
      await provider.setLockEnabled(false);
      return;
    }
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Confirm biometric lock',
        options: const AuthenticationOptions(
            biometricOnly: true, stickyAuth: false),
      );
      if (!ok) return;
      await provider.setLockEnabled(true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Biometrics not available - lock not enabled: $e')));
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Biometric lock enabled.')));
    }
  }

  Future<void> _configureSync(
      BuildContext context, PortfolioProvider provider) async {
    final tokenCtl = TextEditingController(text: provider.gistToken);
    final gistCtl = TextEditingController(text: provider.gistId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub Gist sync'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Paste a personal access token with the "gist" scope '
                  '(github.com/settings/tokens).'),
              const SizedBox(height: 10),
              TextField(
                controller: tokenCtl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'GitHub token',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gistCtl,
                decoration: const InputDecoration(
                  labelText: 'Existing Gist ID (optional)',
                  hintText: 'leave empty to create one on first push',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.configureSync(token: tokenCtl.text, gistId: gistCtl.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync configuration saved.')));
    }
  }

  Future<void> _syncPush(
      BuildContext context, PortfolioProvider provider) async {
    try {
      final content =
          const JsonEncoder.withIndent('  ').convert(provider.exportBackup());
      final sync = SyncService();
      String gistId = provider.gistId;
      if (gistId.isEmpty) {
        gistId = await sync.createGist(token: provider.gistToken, content: content);
        await provider.setGistCreated(gistId);
      } else {
        await sync.push(token: provider.gistToken, gistId: gistId, content: content);
      }
      await provider.setLastSyncAt(DateTime.now());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pushed to your private Gist.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Push failed: $e')));
      }
    }
  }

  Future<void> _syncPull(
      BuildContext context, PortfolioProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pull from gist?'),
        content: const Text(
            'This REPLACES the portfolios on this device with the gist '
            'contents. Push your current data first if it matters.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Pull')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final sync = SyncService();
      final content = await sync.pull(token: provider.gistToken, gistId: provider.gistId);
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) throw 'Invalid backup payload.';
      final ok = await provider.restoreBackup(data);
      await provider.setLastSyncAt(DateTime.now());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Pulled and restored from gist.' : 'No portfolios found.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pull failed: $e')));
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