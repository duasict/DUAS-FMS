import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Skeleton / Shimmer loading widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A generic shimmer box of given [width] and [height].
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2D3E) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF3A3D50) : const Color(0xFFF8FAFC);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A shimmer placeholder for a stat card (2-column grid item).
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonBox(width: 32, height: 32, radius: 8),
          const SizedBox(height: 10),
          SkeletonBox(width: 56, height: 22, radius: 6),
          const SizedBox(height: 6),
          SkeletonBox(width: 80, height: 12, radius: 4),
        ],
      ),
    );
  }
}

/// A shimmer placeholder for a mission card row.
class SkeletonMissionCard extends StatelessWidget {
  const SkeletonMissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
        SkeletonBox(width: 40, height: 40, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: double.infinity, height: 14, radius: 4),
            const SizedBox(height: 8),
            SkeletonBox(width: 160, height: 11, radius: 4),
            const SizedBox(height: 6),
            Row(children: [
              SkeletonBox(width: 70, height: 10, radius: 4),
              const SizedBox(width: 10),
              SkeletonBox(width: 50, height: 10, radius: 4),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        SkeletonBox(width: 16, height: 16, radius: 4),
      ]),
    );
  }
}

/// A full dashboard skeleton — 4 stat cards + 3 mission cards.
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: const [
            SkeletonStatCard(),
            SkeletonStatCard(),
            SkeletonStatCard(),
            SkeletonStatCard(),
          ],
        ),
        const SizedBox(height: 20),
        SkeletonBox(width: 120, height: 13, radius: 4),
        const SizedBox(height: 10),
        const SkeletonMissionCard(),
        const SkeletonMissionCard(),
        const SkeletonMissionCard(),
      ],
    );
  }
}

/// A missions-list skeleton — 5 mission card placeholders.
class SkeletonMissionList extends StatelessWidget {
  const SkeletonMissionList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonMissionCard(),
        SkeletonMissionCard(),
        SkeletonMissionCard(),
        SkeletonMissionCard(),
        SkeletonMissionCard(),
      ],
    );
  }
}
