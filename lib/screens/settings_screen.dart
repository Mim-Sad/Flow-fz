import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/theme_provider.dart';
import 'categories_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _handleThemeChange({
    required VoidCallback updateTheme,
    required Offset tapPosition,
  }) async {
    // Simply update theme without overlay animation for now as requested
    // "Revert to simple state"
    updateTheme();
  }

  @override
  Widget build(BuildContext context) {
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
            // Categories Management
            ListTile(
              title: const Text('مدیریت دسته‌بندی‌ها', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16,)),
              subtitle: const Text('افزودن، ویرایش و حذف دسته‌بندی‌ها',style: TextStyle(fontSize: 10,),),
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedTag01, color: Colors.blue),
              trailing: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.grey, size: 20),
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
                          ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
  
            // Mode Selection (Light/Dark)
            const Text(
              'حالت نمایش',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModeCard(
                    context,
                    ref,
                    title: 'روشن',
                    icon: HugeIcons.strokeRoundedSun01,
                    isSelected: themeState.themeMode == ThemeMode.light,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeCard(
                    context,
                    ref,
                    title: 'تاریک',
                    icon: HugeIcons.strokeRoundedMoon02,
                    isSelected: themeState.themeMode == ThemeMode.dark,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildModeCard(
              context,
              ref,
              title: 'هماهنگ با سیستم',
              icon: HugeIcons.strokeRoundedSettings01,
              isSelected: themeState.themeMode == ThemeMode.system,
              onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
            ),
        ],
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required dynamic icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
