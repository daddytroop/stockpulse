/// A single switch that hides every currency amount in the app.
///
/// The flag lives here rather than in the provider because the money
/// formatters are plain functions: this is the one place they can all
/// consult, so no screen can accidentally leak a balance.
class PrivacyMode {
  PrivacyMode._();

  /// When true, currency amounts are shown as dots.
  static bool hideBalances = false;
}
