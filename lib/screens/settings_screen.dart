import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // Added for PlatformDispatcher
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart' as ats; // Added
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../utils/app_theme.dart'; // Added
import 'categories_screen.dart';

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
  Offset? _tapOffset;
  
  void _switchTheme({
    required BuildContext context,
    required Color seedColor,
    required ThemeMode themeMode,
    required VoidCallback onUpdateState,
    Offset? offset,
  }) {
    final brightness = themeMode == ThemeMode.system
        ? PlatformDispatcher.instance.platformBrightness
        : (themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);
    
    final newTheme = AppTheme.getTheme(seedColor: seedColor, brightness: brightness);
    
    ats.ThemeSwitcher.of(context).changeTheme(
      theme: newTheme,
      offset: offset,
    );
    onUpdateState();
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
          ref.invalidate(themeProvider); // Also invalidate theme to load imported settings
          
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
    // We only watch isInitialized to know when to show the content.
    // The actual theme values are handled by ThemeSwitcher and Theme.of(context).
    final isInitialized = ref.watch(themeProvider.select((s) => s.isInitialized));
    final themeNotifier = ref.read(themeProvider.notifier);

    if (!isInitialized) return const Scaffold();

    return ats.ThemeSwitcher(
      clipper: const ats.ThemeSwitcherCircleClipper(),
      builder: (context) {
        final theme = Theme.of(context);
        final onCardColor = theme.colorScheme.onSurface;
        // We still need the current state for selection indicators, 
        // but we read it inside the builder to get the current values
        // without subscribing to further updates that might interrupt the switcher.
        final themeState = ref.read(themeProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('تنظیمات'),
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
                      border: Border.all(color: onCardColor.withValues(alpha: 0.1), width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: const Text('مدیریت دسته‌بندی‌ها', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16,)),
                      subtitle: const Text('افزودن، ویرایش و حذف دسته‌بندی‌ها',style: TextStyle(fontSize: 12,),),
                      leading: HugeIcon(icon: HugeIcons.strokeRoundedTag01, color: Theme.of(context).colorScheme.primary),
                      trailing: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.grey, size: 20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CategoriesScreen()),
                        );
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      border: Border.all(color: onCardColor.withValues(alpha: 0.1), width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: const Text('پشتیبان‌گیری و بازگردانی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text('ذخیره و بازیابی اطلاعات برنامه', style: TextStyle(fontSize: 12)),
                      leading: HugeIcon(icon: HugeIcons.strokeRoundedDatabase01, color: Theme.of(context).colorScheme.primary),
                      trailing: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.grey, size: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                                title: const Text('خروجی گرفتن از اطلاعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: const Text('ذخیره تمام اطلاعات در یک فایل', style: TextStyle(fontSize: 10)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _exportData();
                                },
                              ),
                              ListTile(
                                leading: const HugeIcon(icon: HugeIcons.strokeRoundedDownload01, color: Colors.green),
                                title: const Text('وارد کردن اطلاعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: const Text('بازگردانی اطلاعات از فایل ذخیره شده', style: TextStyle(fontSize: 10)),
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
                ),
              ),
              const SizedBox(height: 40),

                // Color Selection
                FadeInOnce(
                  delay: 200.ms,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedPaintBoard, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'حال و هوای جریان',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            final name = SettingsScreen._poeticColorNames[color.toARGB32()] ?? '';
      
                            return GestureDetector(
                              onTapDown: (details) {
                                if (!isSelected) {
                                  _switchTheme(
                                    context: context,
                                    seedColor: color,
                                    themeMode: themeState.themeMode,
                                    offset: details.globalPosition,
                                    onUpdateState: () => themeNotifier.setSeedColor(color),
                                  );
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? color.withValues(alpha: 0.15) 
                                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
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
                const SizedBox(height: 40),
      
                // Mode Selection
                FadeInOnce(
                  delay: 250.ms,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedMoon, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'خورشید و ماه جریان',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Listener(
                          onPointerDown: (event) => _tapOffset = event.position,
                          child: SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedSun01,
                                      size: 18,
                                      color: themeState.themeMode == ThemeMode.light
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('چو خورشید', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedMoon02,
                                      size: 18,
                                      color: themeState.themeMode == ThemeMode.dark
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('چو ماه', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedSettings01,
                                      size: 18,
                                      color: themeState.themeMode == ThemeMode.system
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('سیستم', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                            selected: {themeState.themeMode},
                            onSelectionChanged: (newSelection) {
                              _switchTheme(
                                context: context,
                                seedColor: themeState.seedColor,
                                themeMode: newSelection.first,
                                offset: _tapOffset,
                                onUpdateState: () => themeNotifier.setThemeMode(newSelection.first),
                              );
                            },
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              selectedBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              selectedForegroundColor: Theme.of(context).colorScheme.primary,
                              side: BorderSide(color: onCardColor.withValues(alpha: 0.1), width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class FadeInOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeInOnce({super.key, required this.child, required this.delay});

  @override
  State<FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<FadeInOnce> with AutomaticKeepAliveClientMixin {
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasAnimated) return widget.child;

    return widget.child
        .animate(onComplete: (controller) => _hasAnimated = true)
        .fadeIn(duration: 400.ms, delay: widget.delay)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
        .blur(begin: const Offset(4, 4), end: Offset.zero);
  }
}
