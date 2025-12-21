import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'رنگ اصلی نرم‌افزار',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: ThemeNotifier.availableColors.length,
            itemBuilder: (context, index) {
              final color = ThemeNotifier.availableColors[index];
              final isSelected = themeState.seedColor == color;

              return GestureDetector(
                onTap: () => themeNotifier.setSeedColor(color),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Theme.of(context).colorScheme.outline, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
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
              themeNotifier.setThemeMode(newSelection.first);
            },
          ),
        ],
      ),
    );
  }
}
