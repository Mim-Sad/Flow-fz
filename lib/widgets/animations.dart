import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FadeInOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;
  final bool useScale; // Added useScale option

  const FadeInOnce({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
    this.useScale = false, // Default to false
  });

  @override
  State<FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<FadeInOnce> {
  bool _hasAnimated = false;

  @override
  Widget build(BuildContext context) {
    // If already animated or animation disabled, return child directly without wrapper
    if (_hasAnimated || !widget.animate) return widget.child;

    // Cap the delay to 200ms for better scroll performance
    final cappedDelay = widget.delay > 200.ms ? 200.ms : widget.delay;

    // Optimized animation wrapped in RepaintBoundary
    var animation = widget.child
        .animate(
          onComplete: (controller) {
            if (mounted) {
              setState(() => _hasAnimated = true);
            }
          },
        )
        .fadeIn(
          duration: 250.ms,
          delay: cappedDelay,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 300.ms,
          delay: cappedDelay,
          curve: Curves.easeOutCubic,
        )
        .blur(
          begin: const Offset(2, 2),
          end: Offset.zero,
          duration: 300.ms,
          delay: cappedDelay,
          curve: Curves.easeOut,
        );

    // Add scale effect if requested
    if (widget.useScale) {
      animation = animation.scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1, 1),
        duration: 500.ms,
        delay: cappedDelay,
        curve: Curves.easeOutBack,
      );
    }

    return RepaintBoundary(child: animation);
  }
}
