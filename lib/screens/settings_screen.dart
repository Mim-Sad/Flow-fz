import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import 'categories_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final GlobalKey _globalKey = GlobalKey();

  Future<void> _handleThemeChange({
    required VoidCallback updateTheme,
    required Offset tapPosition,
  }) async {
    final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      updateTheme();
      return;
    }

    try {
      final image = await boundary.toImage(pixelRatio: View.of(context).devicePixelRatio);
      
      if (!context.mounted) return;
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      
      overlayEntry = OverlayEntry(
        builder: (context) => _ThemeTransitionOverlay(
          image: image,
          center: tapPosition,
          onFinish: () {
            overlayEntry.remove();
          },
        ),
      );

      overlay.insert(overlayEntry);
      updateTheme();
      
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      updateTheme();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return RepaintBoundary(
      key: _globalKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تنظیمات'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Categories Management
            ListTile(
              title: const Text('مدیریت دسته‌بندی‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('افزودن، ویرایش و حذف دسته‌بندی‌ها'),
              leading: const Icon(Icons.category_rounded),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CategoriesScreen()),
                );
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(height: 32),
  
            // Color Selection (Compact Redesign)
            const Text(
              'رنگ اصلی نرم‌افزار',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ThemeNotifier.availableColors.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = ThemeNotifier.availableColors[index];
                  final isSelected = themeState.seedColor == color;
                  
                  return GestureDetector(
                    onTapDown: (details) {
                      if (!isSelected) {
                        _handleThemeChange(
                          updateTheme: () => themeNotifier.setSeedColor(color),
                          tapPosition: details.globalPosition,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 50 : 40,
                      height: isSelected ? 50 : 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : null,
                    ),
                  );
                },
              ),
            ),
  
            const SizedBox(height: 32),
  
            // Theme Mode
            const Text(
              'حالت نمایش',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('روشن'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('خودکار'),
                  icon: Icon(Icons.settings_brightness),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('تاریک'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {themeState.themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                _handleThemeChange(
                  updateTheme: () => themeNotifier.setThemeMode(newSelection.first),
                  tapPosition: Offset(
                    MediaQuery.of(context).size.width / 2,
                    MediaQuery.of(context).size.height / 2,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTransitionOverlay extends StatefulWidget {
  final ui.Image image;
  final Offset center;
  final VoidCallback onFinish;

  const _ThemeTransitionOverlay({
    required this.image,
    required this.center,
    required this.onFinish,
  });

  @override
  State<_ThemeTransitionOverlay> createState() => _ThemeTransitionOverlayState();
}

class _ThemeTransitionOverlayState extends State<_ThemeTransitionOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onFinish();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ThemeTransitionPainter(
            image: widget.image,
            center: widget.center,
            progress: _controller.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _ThemeTransitionPainter extends CustomPainter {
  final ui.Image image;
  final Offset center;
  final double progress;

  _ThemeTransitionPainter({
    required this.image,
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw the original image
    canvas.drawImage(image, Offset.zero, paint);
    
    // Draw a circular reveal that clears the image
    final maxRadius = size.longestSide * 1.5;
    final radius = maxRadius * progress;
    
    paint.blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawImage(image, Offset.zero, Paint());
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThemeTransitionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
