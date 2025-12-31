import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class FlowBottomSheet extends StatelessWidget {
  final String title;
  final dynamic icon;
  final Widget child;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final dynamic buttonIcon;
  final bool showButton;
  final List<Widget>? headerActions;
  final double? maxHeight;
  final EdgeInsets? padding;

  const FlowBottomSheet({
    super.key,
    required this.title,
    this.icon,
    required this.child,
    this.buttonLabel,
    this.onButtonPressed,
    this.buttonIcon,
    this.showButton = true,
    this.headerActions,
    this.maxHeight,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HugeIcon(
                      icon: icon!,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (headerActions != null) ...headerActions!,
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable Content
          Flexible(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding:
                      padding ??
                      EdgeInsets.fromLTRB(
                        24,
                        8,
                        24,
                        (showButton && buttonLabel != null) ? 100 : 24,
                      ),
                  child: child,
                ),
                // Sticky Button with Faded Background
                if (showButton && buttonLabel != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            theme.colorScheme.surface,
                            theme.colorScheme.surface.withValues(alpha: 0.8),
                            theme.colorScheme.surface.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.6, 1.0],
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: onButtonPressed,
                          icon: buttonIcon != null
                              ? HugeIcon(
                                  icon: buttonIcon!,
                                  size: 20,
                                  color: theme.colorScheme.onPrimary,
                                )
                              : const SizedBox.shrink(),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          label: Text(
                            buttonLabel!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
