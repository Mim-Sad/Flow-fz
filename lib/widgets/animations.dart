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
  // Static set to track animated widgets globally by their keys
  // This ensures animations only play once even if widgets are recreated during scrolling
  static final Set<Object?> _animatedKeys = <Object?>{};
  
  bool _hasAnimated = false;
  Object? _widgetKey;

  @override
  void initState() {
    super.initState();
    // Extract key value - ValueKey has .value, otherwise use hashCode
    _widgetKey = widget.key is ValueKey 
        ? (widget.key as ValueKey).value 
        : (widget.key?.hashCode ?? widget.hashCode);
    // Check if this widget has already been animated
    _hasAnimated = _animatedKeys.contains(_widgetKey);
  }

  @override
  Widget build(BuildContext context) {
    // Check again in build in case key changed
    final currentKey = widget.key is ValueKey 
        ? (widget.key as ValueKey).value 
        : (widget.key?.hashCode ?? widget.hashCode);
    if (currentKey != _widgetKey) {
      _widgetKey = currentKey;
      _hasAnimated = _animatedKeys.contains(_widgetKey);
    }

    // If already animated or animation disabled, return child directly without wrapper
    if (_hasAnimated || !widget.animate) return widget.child;

    // Cap the delay to 200ms for better scroll performance
    final cappedDelay = widget.delay > 200.ms ? 200.ms : widget.delay;

    // Mark as animated immediately to prevent duplicate animations
    _animatedKeys.add(_widgetKey);
    _hasAnimated = true;

    // Optimized animation wrapped in RepaintBoundary
    var animation = widget.child
        .animate(
          onComplete: (controller) {
            // Ensure key is marked as animated
            if (mounted && _widgetKey != null) {
              _animatedKeys.add(_widgetKey!);
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
