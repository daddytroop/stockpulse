import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';

/// Shows a lock screen while the app is "secure", when the user enabled
/// biometric lock. Re-locks whenever the app goes to the background.
/// Lives inside MaterialApp so authentication always has themed UI. Keeps the
/// navigator mounted behind the gate so unlocking preserves the current route.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // If the app was killed in the background, treat relaunch as fresh.
    _unlocked = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_checking && (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden)) {
      setState(() => _unlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final locked = provider.loaded && provider.lockEnabled && !_unlocked;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: locked,
          child: TickerMode(enabled: !locked, child: widget.child),
        ),
        if (locked) _lockScreen(context, provider),
      ],
    );
  }

  Widget _lockScreen(BuildContext context, PortfolioProvider provider) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 52, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('Stock Pulse is locked', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Authenticate to view your portfolio',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.fingerprint, size: 18),
              label: const Text('Unlock'),
              onPressed: _checking ? null : () => _unlock(provider),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _unlock(PortfolioProvider provider) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Stock Pulse',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      setState(() {
        _checking = false;
        if (ok) _unlocked = true;
        if (!ok) _error = 'Authentication cancelled. Tap unlock to retry.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'No biometric method available: $e';
      });
    }
  }
}
