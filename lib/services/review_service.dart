import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import 'platform_check.dart';

/// Asks for a Play Store rating through Google's in-app review sheet.
///
/// Play policy forbids asking "do you like the app?" first and only
/// sending happy users to the store, so the sheet is shown directly. Google
/// also rate-limits it, so a call may show nothing; that is expected.
class ReviewService {
  ReviewService._();

  static Future<void> request() async {
    if (!isAndroidPlatform || kIsWeb) return;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {
      // Never let a rating prompt get in the way.
    }
  }
}
