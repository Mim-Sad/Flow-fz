import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum FlowToastType { info, success, error, warning }

class FlowToast {
  static OverlayEntry? _currentEntry;

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

    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _FlowToastWidget(
            message: message,
            icon: finalIcon,
            iconColor: iconColor,
            displayDuration: duration,
            onDismiss: () {
              _currentEntry?.remove();
              _currentEntry = null;
            },
          ),
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }
}

class _FlowToastWidget extends StatelessWidget {
  final String message;
  final dynamic icon;
  final Color iconColor;
  final Duration displayDuration;
  final VoidCallback onDismiss;

  const _FlowToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.displayDuration,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exitDelay = displayDuration.inMilliseconds - 600;

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                    child: Text(
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
                        .fadeIn(delay: 200.ms, duration: 400.ms),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDismiss,
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Progress Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 2,
                  color: iconColor.withValues(alpha: 0.5),
                )
                    .animate()
                    .scaleX(
                      duration: displayDuration,
                      begin: 1,
                      end: 0,
                      alignment: Alignment.centerRight,
                      curve: Curves.linear,
                    ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        // Entrance: Slide Down + Fade In
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.4, end: 0, curve: Curves.easeOutBack, duration: 600.ms)
        // Mid-life: Subtle Shimmer
        .shimmer(
          delay: 1200.ms,
          duration: 1000.ms,
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        )
        // Exit: Slide Up + Fade Out (Synchronized with display duration)
        .slideY(
          delay: exitDelay.ms,
          begin: 0,
          end: -0.4,
          curve: Curves.easeInBack,
          duration: 500.ms,
        )
        .fadeOut(delay: exitDelay.ms, duration: 400.ms);
  }
}
