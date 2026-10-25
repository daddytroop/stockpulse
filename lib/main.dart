import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/portfolio_provider.dart';
import 'screens/lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final provider = PortfolioProvider();
  // First paint immediately; data loads + refreshes continue in background.
  unawaited(provider.warmStart());

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const LockGate(child: StockPulseApp()),
    ),
  );
}