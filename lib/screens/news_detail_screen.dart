import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/ad_slot.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/ui/sp_card.dart';
import 'holding_detail_screen.dart';

/// A news story, read inside the app.
///
/// The full text of an article belongs to its publisher, so the app shows
/// what Yahoo publishes - the headline, the image, the tickers it is about -
/// and then offers a button to read the original. Nothing is scraped or
/// reprinted.
class NewsDetailScreen extends StatelessWidget {
  final NewsItem item;

  const NewsDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PortfolioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.publisher.isEmpty ? 'Story' : item.publisher,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openOriginal(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                    );
                  },
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 60.ms),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule,
                  size: 13, color: theme.hintColor),
              const SizedBox(width: 5),
              Text(
                timeAgo(item.publishedAt),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.hintColor),
              ),
              if (item.relatedTickers.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.tag, size: 13, color: theme.hintColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    item.relatedTickers.take(3).join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          if (item.relatedTickers.isNotEmpty) ...[
            Text('Mentioned in this story',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final symbol in item.relatedTickers.take(4))
              _RelatedCard(symbol: symbol),
            const SizedBox(height: 14),
          ],
          // A native ad sits inside the article, where a reader expects
          // content, and is labelled so it is never mistaken for a story.
          const AdSlot(
            placement: AdPlacement.newsArticle,
            native: true,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openOriginal(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Read the full story'),
          ),
          const SizedBox(height: 10),
          Text(
            'Headlines, images and tickers come from Yahoo Finance. The full '
            'article is published by ${item.publisher.isEmpty ? 'the source' : item.publisher}.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.hintColor, height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _openOriginal(BuildContext context) async {
    try {
      final uri = Uri.parse(item.link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}

/// A ticker mentioned in a story, with its live price.
class _RelatedCard extends StatelessWidget {
  final String symbol;

  const _RelatedCard({required this.symbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PortfolioProvider>();
    final quote = provider.quoteOf(symbol);
    final colors = AppColors.of(context);
    final up = (quote?.dayChangePercent ?? 0) >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SpCard(
        margin: EdgeInsets.zero,
        onTap: () => _open(context),
        child: Row(
          children: [
            SymbolAvatar(symbol: symbol, radius: 16, companyName: quote?.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    symbol,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if ((quote?.name ?? '').isNotEmpty)
                    Text(
                      quote!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                ],
              ),
            ),
            if (quote != null && quote.price > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtMoney(quote.price, currency: quote.currency),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    quote.dayChangePercent == null
                        ? ''
                        : fmtPct(quote.dayChangePercent),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: up ? colors.gain : colors.loss,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final provider = context.read<PortfolioProvider>();
    for (final p in provider.portfolios) {
      if (p.holdings.containsKey(symbol.toUpperCase())) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              HoldingDetailScreen(portfolioId: p.id, symbol: symbol.toUpperCase()),
        ));
        return;
      }
    }
    // Not held: show the quote on its own.
    final quote = provider.quoteOf(symbol);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(symbol,
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            if ((quote?.name ?? '').isNotEmpty)
              Text(quote!.name,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(ctx).hintColor)),
            const SizedBox(height: 12),
            if (quote != null && quote.price > 0)
              Text(
                '${fmtMoney(quote.price, currency: quote.currency)}  '
                '${quote.dayChangePercent == null ? '' : fmtPct(quote.dayChangePercent)}',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
            const SizedBox(height: 12),
            Text(
              'Add this symbol to a portfolio to track it here.',
              style: Theme.of(ctx)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(ctx).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
