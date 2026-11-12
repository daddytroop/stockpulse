import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/ad_service.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';
import '../widgets/ad_slot.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/shimmer_skeleton.dart';
import '../widgets/ui/sp_card.dart';
import '../widgets/ui/theme_toggle.dart';
import 'news_detail_screen.dart';

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
        title: const Text('News'),
        actions: [
          const ThemeToggleButton(),
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
          ? const EmptyState(
              icon: Icons.newspaper_outlined,
              title: 'No holdings yet',
              subtitle: 'Add holdings to see news about them here.',
            )
          : (_future == null)
              ? const _NewsSkeleton()
              : FutureBuilder<List<NewsItem>>(
                  key: ValueKey(_reloadAt?.millisecondsSinceEpoch ?? 0),
                  future: _future,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const _NewsSkeleton();
                    }
                    final items = snap.data!;
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No recent stories',
                        subtitle: 'No recent news for your holdings. Pull to refresh.',
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
                        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 24),
                        itemCount: items.length + 1,
                        itemBuilder: (context, i) {
                          // A native ad every few stories, so it reads as part
                          // of the feed rather than an interruption.
                          if (i == items.length) {
                            return const AdSlot(
                              placement: AdPlacement.newsNative,
                              native: true,
                            );
                          }
                          if (i > 0 && i % 6 == 0) {
                            return const AdSlot(
                              placement: AdPlacement.newsNative,
                              native: true,
                            );
                          }
                          final n = items[i];
                          return _StoryCard(item: n, onTap: () => _openStory(context, n));
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _openStory(BuildContext context, NewsItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewsDetailScreen(item: item)),
    );
  }
}

/// One story: headline, where and when, and which holdings it is about.
class _StoryCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _StoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(color: theme.hintColor);
    final image = item.imageUrl;
    return SpCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final s in item.relatedTickers.take(2))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Ticker(symbol: s),
                      ),
                    Flexible(
                      child: Text(
                        '${item.publisher} · ${timeAgo(item.publishedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(Sp.radiusSmall),
              child: Image.network(
                image,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                // Decoded at the size it is shown, not the size it was sent.
                cacheWidth: 216,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A holding's symbol as a small tag.
class _Ticker extends StatelessWidget {
  final String symbol;

  const _Ticker({required this.symbol});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

/// Placeholder stories while the feed loads.
class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 24),
      children: [
        for (var i = 0; i < 6; i++) ...const [
          ShimmerSkeleton.card(height: 96),
          SizedBox(height: 8),
        ],
      ],
    );
  }
}
