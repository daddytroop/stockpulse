import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../services/pro_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/page_transitions.dart';

/// Opens [feature]'s screen when it is unlocked, and the Pro page when not.
///
/// This is the only way the paywall appears: when someone reaches for a Pro
/// feature. There are no pop-ups and no nagging.
Future<void> openProFeature(
  BuildContext context,
  ProFeature feature,
  Widget Function() screen,
) async {
  final pro = context.read<ProService>();
  if (pro.has(feature)) {
    pushSharedAxis(context, screen());
    return;
  }
  final unlocked = await showProPaywall(context, feature: feature);
  if (unlocked && context.mounted) pushSharedAxis(context, screen());
}

/// Shows the Pro page. Completes with true when [feature] (or Pro as a
/// whole, when no feature is given) is unlocked on return.
Future<bool> showProPaywall(BuildContext context, {ProFeature? feature}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ProScreen(feature: feature),
    ),
  );
  if (!context.mounted) return false;
  final pro = context.read<ProService>();
  return feature == null ? pro.isPro : pro.has(feature);
}

/// The Stock Pulse Pro page.
class ProScreen extends StatefulWidget {
  /// The feature the user reached for, shown first and offered as a trial.
  final ProFeature? feature;

  const ProScreen({super.key, this.feature});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  bool _watching = false;
  String? _adMessage;

  Future<void> _watchAd() async {
    final feature = widget.feature;
    if (feature == null) return;
    setState(() {
      _watching = true;
      _adMessage = null;
    });
    final ads = context.read<AdService>();
    final pro = context.read<ProService>();
    final earned = await ads.showRewarded();
    if (!mounted) return;
    if (earned) {
      await pro.grantTrial(feature);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _watching = false;
      _adMessage = 'No ad was available just now. Please try again in a little while.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProService>();
    final ads = context.watch<AdService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final feature = widget.feature;

    if (pro.isPro) return _Welcome(onDone: () => Navigator.of(context).pop());

    final features = [
      if (feature != null) feature,
      for (final f in ProFeature.values)
        if (f != feature) f,
    ];
    final trialEnds = feature == null ? null : pro.trialEndsAt(feature);
    final buyLabel = pro.price == null ? 'Unlock Pro' : 'Unlock Pro · ${pro.price}';

    return Scaffold(
      backgroundColor: AppTheme.neonBackground,
      body: Theme(
        data: AppTheme.neon(),
        child: Builder(builder: (context) {
          final theme = Theme.of(context);
          return Stack(
            children: [
              const Positioned.fill(child: _Aurora()),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        children: [
                          const _ProWordmark(),
                          const SizedBox(height: 14),
                          Text(
                            feature == null
                                ? 'Everything in Stock Pulse, plus the tools that '
                                    'help you grow your income. No ads.'
                                : '${feature.title} is part of Pro.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.neonText,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),
                          for (var i = 0; i < features.length; i++)
                            _FeatureRow(
                              icon: features[i].icon,
                              title: features[i].title,
                              blurb: features[i].blurb,
                              highlighted: features[i] == feature,
                            )
                                .animate(delay: (80 * i).ms)
                                .fadeIn(duration: 350.ms)
                                .slideX(begin: 0.06, end: 0, curve: Curves.easeOut),
                          _FeatureRow(
                            icon: Icons.block_rounded,
                            title: 'No ads, ever',
                            blurb: 'Every banner and sponsored card disappears.',
                            highlighted: false,
                          )
                              .animate(delay: (80 * features.length).ms)
                              .fadeIn(duration: 350.ms)
                              .slideX(begin: 0.06, end: 0, curve: Curves.easeOut),
                          const SizedBox(height: 8),
                          Text(
                            'Everything that is free today stays free.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppTheme.neonMuted),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (pro.error != null || _adMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                pro.error ?? _adMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          _GlowButton(
                            label: pro.purchasing ? 'Waiting for Google Play…' : buyLabel,
                            busy: pro.purchasing,
                            onPressed: pro.purchasing ? null : pro.buy,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'One payment through Google Play. No subscription.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppTheme.neonMuted),
                          ),
                          if (feature != null && ads.rewardedAvailable) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.neonText,
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: .16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: _watching
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.play_circle_outline),
                              label: Text(trialEnds == null
                                  ? 'Watch a short ad · try it free for 24 hours'
                                  : 'Watch an ad · add 24 more hours'),
                              onPressed: _watching ? null : _watchAd,
                            ),
                          ],
                          TextButton(
                            onPressed: pro.restore,
                            child: const Text('Restore purchase'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// "Stock Pulse PRO" with a shimmering gradient.
class _ProWordmark extends StatelessWidget {
  const _ProWordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.neonGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonMint.withValues(alpha: .45),
                blurRadius: 36,
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, size: 36, color: Color(0xFF04110C)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.06, duration: 1600.ms, curve: Curves.easeInOut),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Stock Pulse ',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppTheme.neonText,
                letterSpacing: -0.8,
              ),
            ),
            ShaderMask(
              shaderCallback: (rect) =>
                  const LinearGradient(colors: AppTheme.neonGradient).createShader(rect),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String blurb;
  final bool highlighted;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.neonMint.withValues(alpha: .08)
            : Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? AppTheme.neonMint.withValues(alpha: .5)
              : Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: [
                AppTheme.neonMint.withValues(alpha: .22),
                AppTheme.neonViolet.withValues(alpha: .22),
              ]),
            ),
            child: Icon(icon, color: AppTheme.neonMint, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.neonText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  blurb,
                  style: const TextStyle(color: AppTheme.neonMuted, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The main call to action: a glowing gradient button.
class _GlowButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  const _GlowButton({required this.label, required this.busy, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [AppTheme.neonMint, AppTheme.neonCyan]),
        boxShadow: [
          BoxShadow(color: AppTheme.neonMint.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF04110C)),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF04110C),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slow-moving coloured light behind the Pro page.
class _Aurora extends StatelessWidget {
  const _Aurora();

  @override
  Widget build(BuildContext context) {
    Widget orb(Color color, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              color.withValues(alpha: .30),
              color.withValues(alpha: 0),
            ]),
          ),
        );
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: orb(AppTheme.neonMint, 380)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .move(begin: Offset.zero, end: const Offset(40, 30), duration: 6.seconds),
          ),
          Positioned(
            top: 80,
            right: -140,
            child: orb(AppTheme.neonViolet, 420)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .move(begin: Offset.zero, end: const Offset(-30, 50), duration: 7.seconds),
          ),
          Positioned(
            bottom: -160,
            left: 40,
            child: orb(AppTheme.neonCyan, 360)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .move(begin: Offset.zero, end: const Offset(30, -30), duration: 8.seconds),
          ),
        ],
      ),
    );
  }
}

/// Shown the moment Pro is unlocked.
class _Welcome extends StatelessWidget {
  final VoidCallback onDone;

  const _Welcome({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neonBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: _Aurora()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _ProWordmark(),
                    const SizedBox(height: 20),
                    const Text(
                      'You\'re Pro. Thank you!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.neonText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: .3, end: 0),
                    const SizedBox(height: 10),
                    const Text(
                      'Ads are gone and every Pro tool is unlocked, for good.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.neonMuted, height: 1.4),
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 28),
                    _GlowButton(label: 'Let\'s go', busy: false, onPressed: onDone)
                        .animate()
                        .fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Pro card at the top of Settings: status, upgrade and restore.
class ProSettingsCard extends StatelessWidget {
  const ProSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProService>();
    final String title;
    final String subtitle;
    if (pro.owned) {
      title = 'You have Stock Pulse Pro';
      subtitle = 'No ads, and every Pro tool unlocked. Thank you!';
    } else if (pro.isPro && !pro.sellsPro) {
      title = 'Pro is included';
      subtitle = 'This version has every Pro tool and no ads.';
    } else if (pro.isPro) {
      title = 'Pro preview is on';
      subtitle = 'Developer preview on this device.';
    } else {
      title = 'Get Stock Pulse Pro';
      subtitle = 'Dividend snowball, portfolio health, unlimited watchlist with '
          'alerts, exclusive themes and no ads. One payment, yours forever.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.neonMint.withValues(alpha: .22),
              AppTheme.neonViolet.withValues(alpha: .22),
            ],
          ),
          border: Border.all(color: AppTheme.neonMint.withValues(alpha: .35)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: pro.isPro ? null : () => showProPaywall(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: AppTheme.neonGradient),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF04110C)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                        if (!pro.isPro && pro.sellsPro)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: pro.restore,
                              child: const Text('Restore purchase'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!pro.isPro) const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small gradient "PRO" tag.
class ProBadge extends StatelessWidget {
  /// Shows a lock instead of the word, for locked features.
  final bool locked;

  const ProBadge({super.key, this.locked = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(colors: AppTheme.neonGradient),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) ...[
            const Icon(Icons.lock_rounded, size: 10, color: Color(0xFF04110C)),
            const SizedBox(width: 3),
          ],
          const Text(
            'PRO',
            style: TextStyle(
              color: Color(0xFF04110C),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
