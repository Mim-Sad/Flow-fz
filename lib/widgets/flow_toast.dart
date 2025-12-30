import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum FlowToastType { info, success, error, warning }

class FlowToast {
  static void show(
    BuildContext context, {
    required String message,
    FlowToastType type = FlowToastType.info,
    dynamic icon,
    Duration duration = const Duration(seconds: 5),
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Color iconColor;
    dynamic finalIcon = icon;

    switch (type) {
      case FlowToastType.success:
        iconColor = Colors.green;
        finalIcon ??= HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
      case FlowToastType.error:
        iconColor = Colors.red;
        finalIcon ??= HugeIcons.strokeRoundedAlertCircle;
        break;
      case FlowToastType.warning:
        iconColor = Colors.orange;
        finalIcon ??= HugeIcons.strokeRoundedAlert01;
        break;
      case FlowToastType.info:
        iconColor = colorScheme.primary;
        finalIcon ??= HugeIcons.strokeRoundedInformationCircle;
        break;
    }

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: EdgeInsets.zero,
        content: _FlowToastWidget(
          message: message,
          icon: finalIcon,
          iconColor: iconColor,
          displayDuration: duration,
        ),
      ),
    );
  }
}

class _FlowToastWidget extends StatelessWidget {
  final String message;
  final dynamic icon;
  final Color iconColor;
  final Duration displayDuration;

  const _FlowToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.displayDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exitDelay = displayDuration.inMilliseconds - 600;

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.95,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, size: 18, color: iconColor),
              ).animate().scale(
                duration: 600.ms,
                delay: 100.ms,
                curve: Curves.elasticOut,
                begin: const Offset(0.3, 0.3),
              ),
              const SizedBox(width: 14),
              Expanded(
                child:
                    Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'IRANSansX',
                          ),
                          textDirection: TextDirection.rtl,
                        )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          delay: 200.ms,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        ),
              ),
            ],
          ),
        )
        .animate()
        // Entrance: Slide Up + Fade In
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack, duration: 600.ms)
        // Mid-life: Subtle Shimmer
        .shimmer(
          delay: 1200.ms,
          duration: 1000.ms,
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        )
        // Exit: Slide Down + Fade Out (Synchronized with display duration)
        .slideY(
          delay: exitDelay.ms,
          begin: 0,
          end: 0.4,
          curve: Curves.easeInBack,
          duration: 500.ms,
        )
        .fadeOut(delay: exitDelay.ms, duration: 400.ms);
  }
}
