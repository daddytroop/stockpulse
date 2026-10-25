import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';

/// Shimmer loading placeholder. Prefer the named constructors below for
/// common shapes; they auto-adapt to light/dark themes.
class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  const ShimmerSkeleton.text({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 6,
  });

  const ShimmerSkeleton.circle({
    super.key,
    required double diameter,
  })  : width = diameter,
        height = diameter,
        borderRadius = 9999;

  const ShimmerSkeleton.card({
    super.key,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius = 18,
  });

  const ShimmerSkeleton.chart({
    super.key,
    this.width = double.infinity,
    this.height = 180,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A skeleton layout that mimics a metric card.
class SkeletonMetricCard extends StatelessWidget {
  const SkeletonMetricCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.of(context).shimmerBase,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerSkeleton.text(width: 80, height: 12),
          SizedBox(height: 10),
          ShimmerSkeleton.text(width: 120, height: 28),
          SizedBox(height: 6),
          ShimmerSkeleton.text(width: 60, height: 12),
        ],
      ),
    );
  }
}
