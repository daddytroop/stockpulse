import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';
import '../widgets/symbol_avatar.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  Future<List<NewsItem>>? _future;
  DateTime? _reloadAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final provider = context.read<PortfolioProvider>();
    provider.warmStart().then((_) {
      if (!mounted) return;
      setState(() {
        _reloadAt = DateTime.now();
        _future = provider.newsForAllHoldings();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final portfolio = provider.active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('News for your holdings'),
        actions: [
          if (provider.quotesLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload news',
              onPressed: () {
                setState(() {
                  _reloadAt = DateTime.now();
                  _future = provider.newsForAllHoldings();
                });
              },
            ),
        ],
      ),
      body: portfolio.holdings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Add holdings to see news about them here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
              ),
            )
          : (_future == null)
              ? SizedBox(
                  height: 64,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : FutureBuilder<List<NewsItem>>(
                  key: ValueKey(_reloadAt?.millisecondsSinceEpoch ?? 0),
                  future: _future,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }
                    final items = snap.data!;
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No recent stories for your holdings.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        final provider = context.read<PortfolioProvider>();
                        final f = provider.newsForAllHoldings();
                        await f;
                        if (mounted) {
                          setState(() {
                            _reloadAt = DateTime.now();
                            _future = f;
                          });
                        }
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final n = items[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              title: Text(
                                n.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(n.publisher,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.labelSmall),
                                  Text('· ${timeAgo(n.publishedAt)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: Theme.of(context).hintColor)),
                                  for (final s in n.relatedTickers.take(2))
                                    Chip(
                                      avatar: SizedBox(
                                        width: 16,
                                        child: SymbolAvatar(symbol: s, radius: 8),
                                      ),
                                      label: Text(s,
                                          style: Theme.of(context).textTheme.labelSmall),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                              onTap: () => _open(n.link),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}