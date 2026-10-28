import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import 'privacy.dart';

/// Number & date formatting helpers shared across screens.

/// The text shown instead of a currency amount while balances are hidden.
const String hiddenAmount = '••••';

String fmtMoney(num? v, {required String? currency, int decimals = 2}) {
  if (v == null) return '–';
  if (PrivacyMode.hideBalances) return hiddenAmount;
  final f = NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: decimals);
  final body = f.format(v);
  final sym = currencySymbol(currency);
  return sym.isEmpty ? body : '$sym$body';
}

String currencySymbol(String? code) {
  if (code == null || code.isEmpty || code == 'XX') return '';
  try {
    return NumberFormat.simpleCurrency(locale: 'en_US', name: code).currencySymbol.isNotEmpty
        ? NumberFormat.simpleCurrency(locale: 'en_US', name: code).currencySymbol
        : '$code ';
  } catch (_) {
    return '$code ';
  }
}

String fmtSignedMoney(num? v, {required String? currency}) {
  if (v == null) return '–';
  if (PrivacyMode.hideBalances) return hiddenAmount;
  final sign = v > 0 ? '+' : '';
  return '$sign${fmtMoney(v, currency: currency)}';
}

String fmtPct(num? v, {bool signed = true}) {
  if (v == null) return '–';
  final s = v.toStringAsFixed(2);
  if (!signed) return '$s%';
  return '${v > 0 ? '+' : ''}$s%';
}

String fmtQty(num v) {
  if (v == v.roundToDouble()) {
    return NumberFormat.decimalPattern().format(v.toInt());
  }
  return NumberFormat('#,##0.####').format(v);
}

String fmtDate(DateTime? d) {
  if (d == null) return '–';
  return DateFormat('d MMM yyyy').format(d);
}

String fmtShortDate(DateTime? d) {
  if (d == null) return '–';
  return DateFormat('d MMM').format(d);
}

/// Time of day, e.g. `4:05 PM`.
String fmtTime(DateTime? d) {
  if (d == null) return '–';
  return DateFormat('h:mm a').format(d);
}

/// Date and time, e.g. `26 Oct, 4:05 PM`.
String fmtDateTime(DateTime? d) {
  if (d == null) return '–';
  return DateFormat('d MMM, h:mm a').format(d);
}

String fmtMonthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return fmtShortDate(d);
}

/// Color for profit/loss numbers, using the app's semantic theme colors.
Color pnlColor(double v, BuildContext context) {
  final colors = AppColors.of(context);
  if (v > 0) return colors.gain;
  if (v < 0) return colors.loss;
  return Theme.of(context).hintColor;
}

/// Deterministic accent color index for a symbol (used by the letter avatar).
int colorIndexFor(String symbol) {
  var h = 0;
  for (final c in symbol.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return h % 16;
}