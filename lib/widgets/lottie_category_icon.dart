import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../providers/theme_provider.dart';

/// A widget that displays a Lottie animation for category icons.
/// In power saving mode, the animation is paused (shows static frame).
class LottieCategoryIcon extends ConsumerStatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool repeat;

  const LottieCategoryIcon({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = false,
  });

  @override
  ConsumerState<LottieCategoryIcon> createState() => _LottieCategoryIconState();
}

class _LottieCategoryIconState extends ConsumerState<LottieCategoryIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final powerSavingMode = ref.watch(themeProvider).powerSavingMode;

    return Lottie.asset(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      repeat: widget.repeat,
      controller: _controller,
      onLoaded: (composition) {
        if (!_isInitialized) {
          _controller.duration = composition.duration;
          _isInitialized = true;
        }
        
        // In power saving mode, stop animation and show static frame (frame 0)
        if (powerSavingMode) {
          _controller.stop();
          _controller.value = 0;
        } else {
          // In normal mode, play the animation once
          if (!_controller.isAnimating && _controller.value == 0) {
            _controller.reset();
            _controller.forward();
          }
        }
      },
    );
  }
}

