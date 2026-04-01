import 'package:flutter/material.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';

/// A single shimmer bone — the building block for skeleton screens.
class SkeletonBone extends StatefulWidget {
  const SkeletonBone({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 6,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final bool circle;

  @override
  State<SkeletonBone> createState() => _SkeletonBoneState();
}

class _SkeletonBoneState extends State<SkeletonBone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.circle ? widget.height : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.appColors.border,
          borderRadius: widget.circle
              ? null
              : BorderRadius.circular(widget.borderRadius),
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

/// Skeleton version of the dashboard screen.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        // Profile header
        Row(
          children: [
            const SkeletonBone(height: 48, circle: true),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBone(width: 100, height: 12),
                SizedBox(height: 8),
                SkeletonBone(width: 60, height: 18),
              ],
            ),
            const Spacer(),
            const SkeletonBone(height: 36, circle: true),
          ],
        ),
        const SizedBox(height: 24),
        // Stats grid
        Row(
          children: const [
            Expanded(child: _SkeletonCard(height: 140)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonCard(height: 140)),
          ],
        ),
        const SizedBox(height: 28),
        // Section header
        const _SkeletonSectionHeader(),
        const SizedBox(height: 14),
        // Dark card
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: context.appColors.ink,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 28),
        const _SkeletonSectionHeader(),
        const SizedBox(height: 14),
        const _SkeletonListItem(),
        const SizedBox(height: 10),
        const _SkeletonListItem(),
      ],
    );
  }
}

/// Skeleton version of a list screen (exercises, routines).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        // Title
        const SkeletonBone(width: 160, height: 28),
        const SizedBox(height: 18),
        // Search bar
        const SkeletonBone(height: 48, borderRadius: 16),
        const SizedBox(height: 14),
        // Chips
        Row(
          children: const [
            SkeletonBone(width: 50, height: 32, borderRadius: 99),
            SizedBox(width: 8),
            SkeletonBone(width: 70, height: 32, borderRadius: 99),
            SizedBox(width: 8),
            SkeletonBone(width: 60, height: 32, borderRadius: 99),
            SizedBox(width: 8),
            SkeletonBone(width: 80, height: 32, borderRadius: 99),
          ],
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < itemCount; i++) ...[
          const _SkeletonListItem(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Skeleton for a card container.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.appColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBone(width: 24, height: 24),
          SizedBox(height: 12),
          SkeletonBone(width: 80, height: 10),
          SizedBox(height: 8),
          SkeletonBone(width: 40, height: 24),
        ],
      ),
    );
  }
}

/// Skeleton for a section header with blue bar.
class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        const SkeletonBone(width: 130, height: 20),
      ],
    );
  }
}

/// Skeleton for a list item with avatar, text, and trailing.
class _SkeletonListItem extends StatelessWidget {
  const _SkeletonListItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.appColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SkeletonBone(height: 44, circle: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBone(width: 120, height: 14),
                SizedBox(height: 6),
                SkeletonBone(width: 160, height: 11),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              SkeletonBone(width: 60, height: 14),
              SizedBox(height: 6),
              SkeletonBone(width: 40, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}
