import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/portfolio_provider.dart';
import 'screens/home_shell.dart';

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  static const Color seed = Color(0xFF009688); // teal

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final light = ColorScheme.fromSeed(seedColor: seed);
    final dark = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp(
      title: 'Stock Pulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: light,
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: dark,
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 0),
      ),
      themeMode: provider.themeMode,
      home: const HomeShell(),
    );
  }
}