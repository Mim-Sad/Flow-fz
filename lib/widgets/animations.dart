import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FadeInOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;

  const FadeInOnce({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  @override
  State<FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<FadeInOnce> with AutomaticKeepAliveClientMixin {
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasAnimated || !widget.animate) return widget.child;

    // Cap the delay to 300ms to ensure a snappy feel even for items further down the list
    // This solves the issue where items scrolled into view had long delays
    final cappedDelay = widget.delay > 300.ms ? 300.ms : widget.delay;

    return widget.child
        .animate(onComplete: (controller) => _hasAnimated = true)
        .fadeIn(
          duration: 300.ms, 
          delay: cappedDelay,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.1, 
          end: 0, 
          duration: 400.ms,
          delay: cappedDelay,
          curve: Curves.easeOutBack, // Adds a nice little "pop" effect
        );
        // Removed blur for better performance on low-end devices during scroll
  }
}
