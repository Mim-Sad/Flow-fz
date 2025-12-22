import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
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

  Future<void> _exportData() async {
    try {
      final data = await DatabaseService().exportData();
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره فایل پشتیبان',
        fileName: 'flow_backup_${intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در پشتیبان‌گیری: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('بازگردانی اطلاعات'),
            content: const Text('آیا مطمئن هستید؟ تمام اطلاعات فعلی حذف و با فایل انتخاب شده جایگزین خواهند شد.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تایید')),
            ],
          ),
        );

        if (confirm == true) {
          File file = File(result.files.single.path!);
          String jsonString = await file.readAsString();
          Map<String, dynamic> data = jsonDecode(jsonString);
          
          await DatabaseService().importData(data);
          
          // Invalidate providers to refresh data
          ref.invalidate(tasksProvider);
          ref.invalidate(categoryProvider);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اطلاعات با موفقیت بازگردانی شد.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بازگردانی اطلاعات: $e')),
        );
      }
    }
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
              leading: HugeIcon(icon: HugeIcons.strokeRoundedTag01, color: Theme.of(context).colorScheme.primary),
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
            const SizedBox(height: 16),

            // Backup & Restore
            ListTile(
              title: const Text('پشتیبان‌گیری و بازگردانی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text('ذخیره و بازیابی اطلاعات برنامه', style: TextStyle(fontSize: 10)),
              leading: HugeIcon(icon: HugeIcons.strokeRoundedDatabase01, color: Theme.of(context).colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'پشتیبان‌گیری و بازگردانی',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        ListTile(
                          leading: const HugeIcon(icon: HugeIcons.strokeRoundedUpload01, color: Colors.blue),
                          title: const Text('خروجی گرفتن از اطلاعات'),
                          subtitle: const Text('ذخیره تمام اطلاعات در یک فایل'),
                          onTap: () {
                            Navigator.pop(context);
                            _exportData();
                          },
                        ),
                        ListTile(
                          leading: const HugeIcon(icon: HugeIcons.strokeRoundedDownload01, color: Colors.green),
                          title: const Text('وارد کردن اطلاعات'),
                          subtitle: const Text('بازگردانی اطلاعات از فایل ذخیره شده'),
                          onTap: () {
                            Navigator.pop(context);
                            _importData();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
  
            // Color Selection
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedPaintBoard, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'رنگ اصلی نرم‌افزار',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
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
                            ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: const HugeIcon(icon: HugeIcons.strokeRoundedHeartCheck, color: Colors.white),
                          )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 34),
  
            // Mode Selection
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedMoon, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'حالت نمایش',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    label: const Text('روشن'),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSun01,
                      size: 20,
                      color: themeState.themeMode == ThemeMode.light
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: const Text('تاریک'),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoon02,
                      size: 20,
                      color: themeState.themeMode == ThemeMode.dark
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: const Text('سیستم'),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      size: 20,
                      color: themeState.themeMode == ThemeMode.system
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                selected: {themeState.themeMode},
                onSelectionChanged: (newSelection) {
                  themeNotifier.setThemeMode(newSelection.first);
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  selectedForegroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
