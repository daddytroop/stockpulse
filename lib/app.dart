import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/portfolio_provider.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    return MaterialApp(
      title: 'Stock Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: provider.themeMode,
      home: const HomeShell(),
    );
  }
}