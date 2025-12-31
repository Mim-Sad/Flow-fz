import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/animations.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import 'categories_screen.dart';
import 'goals_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const Map<int, String> _poeticColorNames = {
    0xFF6750A4: 'رویای ارغوانی',
    0xFF006494: 'آسمان بیکران',
    0xFF006D3B: 'زمرد سبز',
    0xFFBC004B: 'شکوفه انار',
    0xFF8B5000: 'عطر پاییزی',
    0xFF4355B9: 'موج اقیانوس',
    0xFF00696D: 'فیروزه نیشابور',
    0xFF745B00: 'پرتو آفتاب',
  };

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _exportData() async {
    try {
      final data = await DatabaseService().exportData();
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره فایل پشتیبان',
        fileName:
            'flow_backup_${intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: Uint8List.fromList(bytes),
      );

      if (outputFile != null) {
        // On Desktop, saveFile just returns the path, so we need to write the file.
        // On Mobile (Android/iOS), saveFile handles writing if bytes are provided.
        if (!Platform.isAndroid && !Platform.isIOS) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('پشتیبان‌گیری با موفقیت انجام شد')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا در پشتیبان‌گیری: $e')));
      }
    }
  }

  Future<void> _exportFullData() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('در حال ایجاد پشتیبان کامل...')),
        );
      }

      final zipBytes = await DatabaseService().exportFullData();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره فایل پشتیبان کامل',
        fileName:
            'flow_backup_full_${intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.zip',
        allowedExtensions: ['zip'],
        type: FileType.custom,
        bytes: zipBytes,
      );

      if (outputFile != null) {
        // On Desktop, saveFile just returns the path, so we need to write the file.
        // On Mobile (Android/iOS), saveFile handles writing if bytes are provided.
        if (!Platform.isAndroid && !Platform.isIOS) {
          final file = File(outputFile);
          await file.writeAsBytes(zipBytes);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پشتیبان‌گیری کامل با موفقیت انجام شد'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا در پشتیبان‌گیری کامل: $e')));
      }
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('درون‌ریزی اطلاعات'),
            content: const Text(
              'آیا مطمئن هستید؟ اطلاعات جدید به داده‌های فعلی شما اضافه خواهند شد و موارد تکراری شناسایی می‌شوند.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لغو'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تایید'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          File file = File(result.files.single.path!);
          final fileName = file.path.toLowerCase();

          // Check if it's a ZIP file
          if (fileName.endsWith('.zip')) {
            // Import full backup (ZIP with media)
            await DatabaseService().importFullData(file.path);
          } else {
            // Import JSON backup
            String jsonString = await file.readAsString();
            dynamic data = jsonDecode(jsonString);
            await DatabaseService().importData(data);
          }

          // Invalidate providers to refresh data
          // Instead of invalidating, we directly reload the notifier to ensure immediate state update
          await ref.read(tasksProvider.notifier).reloadTasks();
          ref.invalidate(categoryProvider);
          ref.invalidate(
            themeProvider,
          ); // Also invalidate theme to load imported settings

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('اطلاعات با موفقیت درون‌ریزی و ادغام شد.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در درون‌ریزی اطلاعات: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _deleteMediaData() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حذف فایل‌های مدیا'),
          content: const Text(
            'آیا از حذف امن فایل‌های مدیا (تصاویر و فایل‌های پیوست شده) اطمینان دارید؟ اطلاعات متنی تسک‌ها باقی خواهند ماند.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('حذف مدیا'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await DatabaseService().deleteAllMedia();

        // Reload tasks to recognize attachment removal
        await ref.read(tasksProvider.notifier).reloadTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فایل‌های مدیا با موفقیت حذف شدند')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در حذف فایل‌های مدیا: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllData() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حذف کامل اطلاعات'),
          content: const Text(
            'آیا از حذف کامل تمامی اطلاعات اپلیکیشن (تسک‌ها، دسته‌بندی‌ها و تنظیمات) مطمئن هستید؟ این عمل غیرقابل بازگشت است.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف همه داده‌ها'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await DatabaseService().deleteAllData();

        // Clear SharedPreferences
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.clear();

        // Invalidate and reload providers
        await ref.read(tasksProvider.notifier).reloadTasks();
        ref.invalidate(categoryProvider);

        // Re-initialize theme to defaults
        ref.invalidate(themeProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمامی اطلاعات با موفقیت حذف شد')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در حذف اطلاعات: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Widget _buildIconWithBackground(
    BuildContext context,
    dynamic icon, {
    Color? color,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: HugeIcon(
        icon: icon,
        color: color ?? Theme.of(context).colorScheme.primary,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    if (!themeState.isInitialized) return const Scaffold();

    final theme = Theme.of(context);
    final onCardColor = theme.colorScheme.onSurface;

    final navigationBarColor = theme.brightness == Brightness.light
        ? ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          )
        : ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: navigationBarColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'تنظیمات',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // Categories Management
          FadeInOnce(
            delay: 100.ms,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: onCardColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: const Text(
                  'مدیریت دسته‌بندی‌ها',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'افزودن، ویرایش و حذف دسته‌بندی‌ها',
                  style: TextStyle(fontSize: 12),
                ),
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedArchive02,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: Colors.grey,
                  size: 20,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoriesScreen(),
                    ),
                  );
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Goals Management
          FadeInOnce(
            delay: 120.ms,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: onCardColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: const Text(
                  'مدیریت اهداف',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'افزودن، ویرایش و مشاهده پیشرفت اهداف',
                  style: TextStyle(fontSize: 12),
                ),
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedTarget02,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: Colors.grey,
                  size: 20,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoalsScreen(),
                    ),
                  );
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Backup & Restore
          FadeInOnce(
            delay: 150.ms,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: onCardColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: const Text(
                  'پشتیبان‌گیری و بازگردانی',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'ذخیره و بازیابی اطلاعات برنامه',
                  style: TextStyle(fontSize: 12),
                ),
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedDatabase01,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: Colors.grey,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'پشتیبان‌گیری و بازگردانی',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ListTile(
                              leading: _buildIconWithBackground(
                                context,
                                HugeIcons.strokeRoundedUpload01,
                                color: Colors.blue,
                              ),
                              title: const Text(
                                'خروجی گرفتن از اطلاعات',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'ذخیره تمام اطلاعات در یک فایل JSON',
                                style: TextStyle(fontSize: 10),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _exportData();
                              },
                            ),
                            ListTile(
                              leading: _buildIconWithBackground(
                                context,
                                HugeIcons.strokeRoundedUpload01,
                                color: Colors.purple,
                              ),
                              title: const Text(
                                'پشتیبان‌گیری کامل',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'ذخیره اطلاعات و فایل‌های مدیا در فایل ZIP',
                                style: TextStyle(fontSize: 10),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _exportFullData();
                              },
                            ),
                            ListTile(
                              leading: _buildIconWithBackground(
                                context,
                                HugeIcons.strokeRoundedDownload01,
                                color: Colors.green,
                              ),
                              title: const Text(
                                'وارد کردن اطلاعات',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'بازگردانی اطلاعات از فایل JSON یا ZIP',
                                style: TextStyle(fontSize: 10),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _importData();
                              },
                            ),

                            ListTile(
                              leading: _buildIconWithBackground(
                                context,
                                HugeIcons.strokeRoundedDelete01,
                                color: Colors.orange,
                              ),
                              title: const Text(
                                'حذف فایل‌های مدیا',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'پاکسازی تصاویر و فایل‌های ضمیمه شده برای آزادسازی فضا',
                                style: TextStyle(fontSize: 10),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _deleteMediaData();
                              },
                            ),
                            ListTile(
                              leading: _buildIconWithBackground(
                                context,
                                HugeIcons.strokeRoundedDelete02,
                                color: Colors.red,
                              ),
                              title: const Text(
                                'حذف کامل داده‌های اپ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'پاکسازی تمامی تسک‌ها، دسته‌بندی‌ها و تنظیمات',
                                style: TextStyle(fontSize: 10),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _deleteAllData();
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Power Saving Mode
          FadeInOnce(
            delay: 300.ms,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: onCardColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: const Text(
                  'حالت ذخیره نیرو',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'غیر فعال کردن برخی انیمیشن‌ها',
                  style: TextStyle(fontSize: 12),
                ),
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedFlash,
                  color: Theme.of(context).colorScheme.primary,
                ),
                trailing: Switch(
                  value: themeState.powerSavingMode,
                  onChanged: (value) {
                    themeNotifier.setPowerSavingMode(value);
                  },
                ),
                onTap: () {
                  themeNotifier.setPowerSavingMode(!themeState.powerSavingMode);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Color Selection
          FadeInOnce(
            delay: 200.ms,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildIconWithBackground(
                      context,
                      HugeIcons.strokeRoundedPaintBoard,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'حال و هوامون',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: ThemeNotifier.availableColors.map((color) {
                      final isSelected = themeState.seedColor == color;
                      final name =
                          SettingsScreen._poeticColorNames[color.toARGB32()] ??
                          '';

                      return GestureDetector(
                        onTap: () {
                          if (!isSelected) {
                            themeNotifier.setSeedColor(color);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? color.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? color
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Mode Selection
          FadeInOnce(
            delay: 250.ms,
            child: Column(
              children: [
                Row(
                  children: [
                    _buildIconWithBackground(
                      context,
                      HugeIcons.strokeRoundedMoon,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'شب  و روزمون',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: const Text('آفتاب'),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedSun01,
                          size: 18,
                        ),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: const Text('مهتاب'),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedMoon02,
                          size: 18,
                        ),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: const Text('سیستم'),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedSettings01,
                          size: 18,
                        ),
                      ),
                    ],
                    selected: {themeState.themeMode},
                    onSelectionChanged: (newSelection) {
                      themeNotifier.setThemeMode(newSelection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
