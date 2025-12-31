import '../widgets/lottie_category_icon.dart';
import '../widgets/flow_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

import '../models/task.dart';
import '../models/category_data.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/goal_provider.dart';
import '../utils/string_utils.dart';
import '../utils/emoji_suggester.dart';
import '../services/notification_service.dart';
import '../widgets/audio_waveform_player.dart';
import 'package:intl/intl.dart' as intl;
import 'goals_screen.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  final Task? task;
  final DateTime? initialDate;
  const AddTaskScreen({super.key, this.task, this.initialDate});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _tagController;
  late TextEditingController _emojiController;
  late DateTime _selectedDate;
  late TaskPriority _priority;
  List<String> _selectedCategories = [];
  List<int> _selectedGoals = [];
  List<String> _tags = [];
  String? _selectedEmoji;
  List<String> _attachments = [];
  RecurrenceConfig? _recurrence;
  bool _isDetailsExpanded = false;
  bool _hasTime = false;
  bool _hasEndTime = false;
  DateTime? _endTime;
  DateTime? _reminderDateTime;
  bool _hasReminder = false;

  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // Emoji Suggestion
  Timer? _emojiSuggestionTimer;
  String? _lastTitleForEmoji; // آخرین عنوانی که برای آن ایموجی پیشنهاد شده

  String _toPersianDigit(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], persianDigits[i]);
    }
    return result;
  }

  String _formatJalali(Jalali j) {
    String weekday = j.formatter.wN;
    if (weekday == 'یک شنبه') weekday = 'یک‌شنبه';
    if (weekday == 'دو شنبه') weekday = 'دو‌شنبه';
    if (weekday == 'سه شنبه') weekday = 'سه‌شنبه';
    if (weekday == 'چهار شنبه') weekday = 'چهار‌شنبه';
    if (weekday == 'پنج شنبه') weekday = 'پنج‌شنبه';
    return _toPersianDigit('$weekday ${j.day} ${j.formatter.mN} ${j.year}');
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _descController = TextEditingController(text: widget.task?.description);
    _tagController = TextEditingController();
    _emojiController = TextEditingController(text: widget.task?.taskEmoji);

    _recurrence = widget.task?.recurrence;
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _selectedCategories = widget.task?.categories ?? [];
    _selectedGoals = List.from(widget.task?.goalIds ?? []);
    _tags = List.from(widget.task?.tags ?? []);
    _selectedEmoji = widget.task?.taskEmoji;
    _attachments = widget.task?.attachments ?? [];

    if (widget.task != null) {
      _hasTime = widget.task!.metadata['hasTime'] ?? true;
      _endTime = widget.task!.endTime;
      _hasEndTime = _hasTime && _endTime != null;
      _reminderDateTime = widget.task!.reminderDateTime;
      _hasReminder = _reminderDateTime != null;
    } else {
      _hasTime = false;
      _hasEndTime = false;
      _hasReminder = false;
    }

    // Logic for date:
    // 1. If it's a new task (no task provided):
    //    - Use initialDate (date user clicked on) or now.
    // 2. If it's a duplicated task (task provided but no ID):
    //    - Use initialDate but preserve time from original task if possible.
    // 3. If it's an existing task (edit, has ID):
    //    - ALWAYS use the task's original dueDate. initialDate should be ignored for edits.

    final isNew = widget.task == null;
    final isDuplicated = widget.task != null && widget.task!.id == null;

    if (isNew) {
      _selectedDate = widget.initialDate ?? DateTime.now();
    } else if (isDuplicated) {
      final isRecurring =
          widget.task!.recurrence != null &&
          widget.task!.recurrence!.type != RecurrenceType.none;

      if (isRecurring) {
        // For recurring tasks, we want to preserve the original start date of the series
        final allTasks = ref.read(tasksProvider);
        final duplicatedFromId = widget.task!.metadata['duplicatedFromId'];
        final originalTask = allTasks.cast<Task?>().firstWhere(
          (t) => t?.id == duplicatedFromId,
          orElse: () => null,
        );

        if (originalTask != null) {
          _selectedDate = originalTask.dueDate;
        } else {
          _selectedDate = widget.task!.dueDate;
        }
      } else {
        // For normal tasks, we can use the target date (e.g. today or selected date)
        final originalDate = widget.task!.dueDate;
        final targetDate = widget.initialDate ?? originalDate;
        _selectedDate = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          originalDate.hour,
          originalDate.minute,
        );
      }

      // If duplicated task's start date is after its recurrence end date, clear the end date
      if (_recurrence?.endDate != null &&
          _selectedDate.isAfter(_recurrence!.endDate!)) {
        _recurrence = RecurrenceConfig(
          type: _recurrence!.type,
          interval: _recurrence!.interval,
          daysOfWeek: _recurrence!.daysOfWeek,
          specificDates: _recurrence!.specificDates,
          dayOfMonth: _recurrence!.dayOfMonth,
          endDate: null,
        );
      }
    } else {
      // isEditing
      // Find the original task from provider to get the true start date (dueDate)
      // because the task passed in widget.task might be a copy from activeTasksProvider
      // which has its dueDate modified to the occurrence date.
      final allTasks = ref.read(tasksProvider);
      final originalTask = allTasks.cast<Task?>().firstWhere(
        (t) => t?.id == widget.task!.id,
        orElse: () => widget.task,
      );
      _selectedDate = originalTask?.dueDate ?? widget.task!.dueDate;
    }

    // Add listener for automatic emoji suggestion
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    final title = _titleController.text.trim();

    // اگر عنوان خالی است، ایموجی را پاک کن (فقط اگر توسط سیستم پیشنهاد شده بود)
    if (title.isEmpty) {
      _emojiSuggestionTimer?.cancel();
      if (_selectedEmoji != null && _lastTitleForEmoji != null) {
        // فقط اگر ایموجی توسط سیستم پیشنهاد شده بود، آن را پاک کن
        setState(() {
          _emojiController.clear();
          _selectedEmoji = null;
          _lastTitleForEmoji = null;
        });
      }
      return;
    }

    // بررسی اینکه آیا باید پیشنهاد جدید بدهیم:
    // 1. اگر ایموجی خالی باشد
    // 2. یا اگر ایموجی توسط سیستم پیشنهاد شده بود (_lastTitleForEmoji != null) و عنوان تغییر کرده
    bool shouldSuggest = false;

    if (_selectedEmoji == null || _selectedEmoji!.isEmpty) {
      // ایموجی خالی است، باید پیشنهاد بدهیم
      shouldSuggest = true;
    } else if (_lastTitleForEmoji != null && _lastTitleForEmoji != title) {
      // ایموجی توسط سیستم پیشنهاد شده بود و عنوان تغییر کرده
      // باید پیشنهاد جدید بدهیم
      shouldSuggest = true;
    }
    // اگر _lastTitleForEmoji == null باشد، یعنی کاربر به صورت دستی ایموجی را انتخاب کرده
    // پس نباید پیشنهاد جدید بدهیم

    if (shouldSuggest) {
      // Cancel timer قبلی
      _emojiSuggestionTimer?.cancel();

      // ایجاد timer جدید با debounce
      _emojiSuggestionTimer = Timer(const Duration(milliseconds: 600), () {
        final currentTitle = _titleController.text.trim();
        if (currentTitle.isNotEmpty && mounted) {
          final suggestedEmoji = EmojiSuggester.suggestEmoji(currentTitle);
          if (suggestedEmoji != null) {
            setState(() {
              _emojiController.text = suggestedEmoji;
              _selectedEmoji = suggestedEmoji;
              _lastTitleForEmoji = currentTitle; // ذخیره عنوان برای بررسی بعدی
            });
          } else {
            // اگر پیشنهادی پیدا نشد و ایموجی قبلی توسط سیستم پیشنهاد شده بود، آن را پاک کن
            if (_lastTitleForEmoji != null) {
              setState(() {
                _emojiController.clear();
                _selectedEmoji = null;
                _lastTitleForEmoji = null;
              });
            }
          }
        }
      });
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        if (!mounted) return;
        FlowToast.show(
          context,
          message: 'خطا در باز کردن فایل: ${result.message}',
          type: FlowToastType.error,
        );
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      if (!mounted) return;
      FlowToast.show(
        context,
        message: 'خطا در باز کردن فایل',
        type: FlowToastType.error,
      );
    }
  }

  @override
  void dispose() {
    _emojiSuggestionTimer?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _audioRecorder.dispose();
    _titleController.dispose();
    _descController.dispose();
    _emojiController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !StringUtils.containsTag(_tags, trimmedTag)) {
      setState(() {
        _tags.add(trimmedTag);
        _tagController.clear();
      });
    } else if (trimmedTag.isNotEmpty) {
      // Clear if it's a duplicate to give feedback it wasn't added
      _tagController.clear();
      FlowToast.show(
        context,
        message: 'این تگ قبلاً اضافه شده است',
        type: FlowToastType.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle for visual cue
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Flexible(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: HugeIcon(
                                  icon:
                                      HugeIcons.strokeRoundedCheckmarkSquare01,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                (widget.task == null || widget.task?.id == null)
                                    ? 'تسک جدید'
                                    : 'ویرایش تسک',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  size: 22,
                                  color: Colors.grey,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                style: const ButtonStyle(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Title and Emoji
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: _emojiController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 26),
                                  keyboardType: TextInputType.text,
                                  decoration: const InputDecoration(
                                    hintText: '🫥',
                                    hintStyle: TextStyle(fontSize: 26),
                                    counterText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value.characters.isNotEmpty) {
                                        final char = value.characters.last;
                                        _emojiController.text = char;
                                        _emojiController.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset: _emojiController
                                                    .text
                                                    .length,
                                              ),
                                            );
                                        _selectedEmoji = char;
                                        // اگر کاربر به صورت دستی ایموجی را تغییر داد،
                                        // _lastTitleForEmoji را null می‌کنیم تا نشان دهیم
                                        // این انتخاب دستی است و نباید با تغییر عنوان تغییر کند
                                        _lastTitleForEmoji = null;
                                      } else {
                                        _selectedEmoji = null;
                                        _lastTitleForEmoji = null;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _titleController,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'چه کاری باید انجام بشه؟',
                                    hintStyle: const TextStyle(fontSize: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Categories
                          Consumer(
                            builder: (context, ref, child) {
                              final categoriesAsync = ref.watch(
                                categoryProvider,
                              );
                              return categoriesAsync.when(
                                data: (categories) {
                                  final cats = categories.isEmpty
                                      ? defaultCategories
                                      : categories;
                                  return SizedBox(
                                    width: double.infinity,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: cats.map((cat) {
                                        final isSelected = _selectedCategories
                                            .contains(cat.id);
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedCategories.remove(
                                                  cat.id,
                                                );
                                              } else {
                                                _selectedCategories.add(cat.id);
                                              }
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? cat.color.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected
                                                    ? cat.color.withValues(
                                                        alpha: 0.5,
                                                      )
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                LottieCategoryIcon(
                                                  assetPath: cat.emoji,
                                                  width: 22,
                                                  height: 22,
                                                  repeat: false,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  cat.label,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? cat.color
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (err, stack) => Text('خطا: $err'),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Collapsible Details Section
                          Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              hoverColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.05),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                'جزئیات بیشتر',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              tilePadding: EdgeInsets.zero,
                              initiallyExpanded: _isDetailsExpanded,
                              onExpansionChanged: (val) {
                                setState(() => _isDetailsExpanded = val);
                              },
                              children: [
                                const SizedBox(height: 8),
                                // Date
                                ListTile(
                                  onTap: () async {
                                    final pickedDate =
                                        await showPersianDatePicker(
                                          context: context,
                                          initialDate: Jalali.fromDateTime(
                                            _selectedDate,
                                          ),
                                          firstDate: Jalali.fromDateTime(
                                            _selectedDate.isBefore(
                                                  DateTime.now(),
                                                )
                                                ? _selectedDate.subtract(
                                                    const Duration(days: 365),
                                                  )
                                                : DateTime.now().subtract(
                                                    const Duration(days: 365),
                                                  ),
                                          ),
                                          lastDate: Jalali.fromDateTime(
                                            DateTime.now().add(
                                              const Duration(days: 365 * 10),
                                            ),
                                          ),
                                        );
                                    if (pickedDate != null) {
                                      final dt = pickedDate.toDateTime();
                                      setState(() {
                                        _selectedDate = DateTime(
                                          dt.year,
                                          dt.month,
                                          dt.day,
                                          _selectedDate.hour,
                                          _selectedDate.minute,
                                        );

                                        // If new start date is after current recurrence end date, clear end date
                                        if (_recurrence?.endDate != null &&
                                            _selectedDate.isAfter(
                                              _recurrence!.endDate!,
                                            )) {
                                          _recurrence = RecurrenceConfig(
                                            type: _recurrence!.type,
                                            interval: _recurrence!.interval,
                                            daysOfWeek: _recurrence!.daysOfWeek,
                                            specificDates:
                                                _recurrence!.specificDates,
                                            dayOfMonth: _recurrence!.dayOfMonth,
                                            endDate: null,
                                          );
                                        }
                                      });
                                    }
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCalendar03,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    _recurrence != null &&
                                            _recurrence!.type !=
                                                RecurrenceType.none
                                        ? 'تاریخ شروع'
                                        : 'تاریخ انجام',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatJalali(
                                      Jalali.fromDateTime(_selectedDate),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),

                                // Time
                                ListTile(
                                  onTap: () async {
                                    final pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        _selectedDate,
                                      ),
                                      builder: (context, child) =>
                                          Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: child!,
                                          ),
                                    );
                                    if (pickedTime != null) {
                                      setState(() {
                                        _hasTime = true;
                                        _selectedDate = DateTime(
                                          _selectedDate.year,
                                          _selectedDate.month,
                                          _selectedDate.day,
                                          pickedTime.hour,
                                          pickedTime.minute,
                                        );
                                      });
                                    }
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.lightGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedClock01,
                                      size: 20,
                                      color: Colors.lightGreen,
                                    ),
                                  ),
                                  title: const Text(
                                    'زمان انجام',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _hasTime
                                        ? _toPersianDigit(
                                            intl.DateFormat(
                                              'HH:mm',
                                            ).format(_selectedDate),
                                          )
                                        : 'بدون ساعت تنظیم شده',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_hasTime)
                                        GestureDetector(
                                          onTap: () => setState(() {
                                            _hasTime = false;
                                            _hasEndTime = false;
                                          }),
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              border: Border.all(
                                                color: Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            child: const Text(
                                              'حذف ساعت',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ),

                                // End Time
                                if (_hasTime)
                                  ListTile(
                                    onTap: () async {
                                      final pickedTime = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          _endTime ??
                                              _selectedDate.add(
                                                const Duration(hours: 1),
                                              ),
                                        ),
                                        builder: (context, child) =>
                                            Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: child!,
                                            ),
                                      );
                                      if (pickedTime != null) {
                                        setState(() {
                                          _hasEndTime = true;
                                          _endTime = DateTime(
                                            _selectedDate.year,
                                            _selectedDate.month,
                                            _selectedDate.day,
                                            pickedTime.hour,
                                            pickedTime.minute,
                                          );
                                        });
                                      }
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedClock05,
                                        size: 20,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                    title: const Text(
                                      'ساعت پایان',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _hasEndTime && _endTime != null
                                          ? _toPersianDigit(
                                              intl.DateFormat(
                                                'HH:mm',
                                              ).format(_endTime!),
                                            )
                                          : 'بدون ساعت پایان',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_hasEndTime)
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _hasEndTime = false,
                                            ),
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                left: 12,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                                border: Border.all(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                ),
                                              ),
                                              child: const Text(
                                                'حذف ساعت پایان',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Reminder
                                ListTile(
                                  onTap: _showReminderPickerSheet,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedNotification03,
                                      size: 20,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  title: const Text(
                                    'یادآور',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _getReminderSubtitle(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_hasReminder)
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _hasReminder = false,
                                          ),
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              border: Border.all(
                                                color: Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            child: const Text(
                                              'حذف یادآور',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ),

                                // Recurrence
                                ListTile(
                                  onTap: _showRecurrencePicker,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedRepeat,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: const Text(
                                    'تکرار',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _getRecurrenceText(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Priority
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: SegmentedButton<TaskPriority>(
                                      segments: const [
                                        ButtonSegment(
                                          value: TaskPriority.low,
                                          label: Text('فرعی'),
                                          icon: HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedArrowDown01,
                                            color: Colors.green,
                                            size: 18,
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: TaskPriority.medium,
                                          label: Text('عادی'),
                                          icon: HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedMinusSign,
                                            color: Colors.grey,
                                            size: 18,
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: TaskPriority.high,
                                          label: Text('فوری'),
                                          icon: HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedAlertCircle,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                      selected: {_priority},
                                      onSelectionChanged: (val) {
                                        setState(() => _priority = val.first);
                                      },
                                      style: SegmentedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        side: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Tags
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: TextField(
                                    controller: _tagController,
                                    onChanged: (value) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'افزودن تگ جدید...',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      prefixIcon: Container(
                                        margin:
                                            const EdgeInsetsDirectional.only(
                                              start: 14,
                                              end: 10,
                                            ),
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedTag01,
                                          size: 20,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                            minWidth: 0,
                                            minHeight: 0,
                                          ),
                                      suffixIcon: IconButton(
                                        icon: const HugeIcon(
                                          icon:
                                              HugeIcons.strokeRoundedAddCircle,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _addTag(_tagController.text),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    onSubmitted: (val) => _addTag(val),
                                  ),
                                ),

                                // Suggestions (Centered and padded like main tags) - Shown first while typing
                                if (_tagController.text.isNotEmpty) ...[
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final suggestions = ref.watch(
                                        tagSuggestionsProvider(
                                          _tagController.text,
                                        ),
                                      );
                                      final filteredSuggestions = suggestions
                                          .where(
                                            (s) => !StringUtils.containsTag(
                                              _tags,
                                              s,
                                            ),
                                          )
                                          .take(5)
                                          .toList();

                                      if (filteredSuggestions.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          12,
                                          12,
                                          0,
                                        ),
                                        child: Center(
                                          child: Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: filteredSuggestions
                                                .map(
                                                  (suggestion) => ActionChip(
                                                    label: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          suggestion,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Icon(
                                                          Icons.add,
                                                          size: 14,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                      ],
                                                    ),
                                                    onPressed: () =>
                                                        _addTag(suggestion),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    backgroundColor:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .primaryContainer
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                    side: BorderSide(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                    ),
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 0,
                                                        ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                // Added Tags (Centered and padded)
                                if (_tags.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Center(
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _tags
                                            .map(
                                              (tag) => ActionChip(
                                                label: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      tag,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.close,
                                                      size: 14,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.secondary,
                                                    ),
                                                  ],
                                                ),
                                                onPressed: () => setState(
                                                  () => _tags.remove(tag),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .secondaryContainer
                                                        .withValues(alpha: 0.3),
                                                side: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary
                                                      .withValues(alpha: 0.2),
                                                ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 0,
                                                    ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // Description (Moved here and styled smaller)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: TextField(
                                    controller: _descController,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'توضیحات بیشتر...',
                                      hintStyle: const TextStyle(fontSize: 13),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Goals (Moved here and center-aligned)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final goals = ref.watch(goalsProvider);

                                    if (goals.isEmpty) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(
                                                context,
                                                rootNavigator: true,
                                              ).push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const GoalsScreen(),
                                                  fullscreenDialog: true,
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.3),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    '🎯',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'هدف جدید!',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                        ],
                                      );
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: goals.map((goal) {
                                              final isSelected = _selectedGoals
                                                  .contains(goal.id);
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    if (isSelected) {
                                                      _selectedGoals.remove(
                                                        goal.id,
                                                      );
                                                    } else {
                                                      _selectedGoals.add(
                                                        goal.id!,
                                                      );
                                                    }
                                                  });
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .surfaceContainerHighest
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                )
                                                          : Colors.transparent,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        goal.emoji,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        goal.title,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                          color: isSelected
                                                              ? Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary
                                                              : Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    );
                                  },
                                ),

                                // Attachments
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _pickFile,
                                        icon: const HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedAttachment01,
                                          size: 18,
                                        ),
                                        label: const Text('پیوست فایل'),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: _toggleRecording,
                                        icon: HugeIcon(
                                          icon: _isRecording
                                              ? HugeIcons.strokeRoundedStop
                                              : HugeIcons.strokeRoundedMic01,
                                          size: 18,
                                          color: _isRecording
                                              ? Colors.red
                                              : null,
                                        ),
                                        label: Text(
                                          _isRecording ? 'توقف ضبط' : 'ضبط صدا',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _isRecording
                                              ? Colors.red
                                              : null,
                                          side: _isRecording
                                              ? const BorderSide(
                                                  color: Colors.red,
                                                )
                                              : BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.5),
                                                ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_attachments.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Column(
                                      children: _attachments.map((att) {
                                        final name = att.split('/').last;
                                        final isVoice =
                                            name.startsWith('voice_') ||
                                            att.endsWith('.m4a');
                                        final isImage =
                                            name.toLowerCase().endsWith(
                                              '.jpg',
                                            ) ||
                                            name.toLowerCase().endsWith(
                                              '.jpeg',
                                            ) ||
                                            name.toLowerCase().endsWith(
                                              '.png',
                                            ) ||
                                            name.toLowerCase().endsWith(
                                              '.gif',
                                            ) ||
                                            name.toLowerCase().endsWith(
                                              '.webp',
                                            );

                                        if (isVoice) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: AudioWaveformPlayer(
                                              audioPath: att,
                                              onDelete: () {
                                                setState(() {
                                                  _attachments.remove(att);
                                                });
                                              },
                                            ),
                                          );
                                        } else {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: InkWell(
                                              onTap: () => _openFile(att),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                height:
                                                    48, // Same height as audio player
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    HugeIcon(
                                                      icon: isImage
                                                          ? HugeIcons
                                                                .strokeRoundedImage01
                                                          : HugeIcons
                                                                .strokeRoundedFile01,
                                                      size: 18,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        name.length > 30
                                                            ? '${name.substring(0, 30)}...'
                                                            : name,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _attachments.remove(
                                                            att,
                                                          );
                                                        });
                                                      },
                                                      child: HugeIcon(
                                                        icon: HugeIcons
                                                            .strokeRoundedCancel01,
                                                        size: 18,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Theme.of(context).colorScheme.surface,
                              Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.8),
                              Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.6, 1.0],
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _saveTask,
                            icon: HugeIcon(
                              icon: widget.task == null
                                  ? HugeIcons.strokeRoundedAddSquare
                                  : HugeIcons.strokeRoundedCheckmarkSquare04,
                              size: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            label: Text(
                              widget.task == null
                                  ? 'ثبت و شروع کار'
                                  : 'ذخیره تغییرات',
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
        ),
      ),
    );
  }

  String _getRecurrenceText() {
    if (_recurrence == null || _recurrence!.type == RecurrenceType.none) {
      return 'بدون تکرار';
    }

    String endDateText = '';
    if (_recurrence!.endDate != null) {
      final jEndDate = Jalali.fromDateTime(_recurrence!.endDate!);
      endDateText = ' (تا ${_formatJalali(jEndDate)})';
    }

    String typeText = '';
    switch (_recurrence!.type) {
      case RecurrenceType.hourly:
        typeText = 'ساعتی';
        break;
      case RecurrenceType.daily:
        if (_recurrence!.interval != null && _recurrence!.interval! > 1) {
          typeText = 'هر ${_recurrence!.interval} روز';
        } else {
          typeText = 'روزانه';
        }
        break;
      case RecurrenceType.weekly:
        typeText = 'هفتگی';
        break;
      case RecurrenceType.monthly:
        typeText = 'ماهانه';
        break;
      case RecurrenceType.yearly:
        typeText = 'سالانه';
        break;
      case RecurrenceType.custom:
        typeText = 'هر ${_recurrence!.interval} روز';
        break;
      case RecurrenceType.specificDays:
        final days =
            _recurrence!.daysOfWeek?.map((d) => _getDayName(d)).join('، ') ??
            '';
        typeText = 'روزهای $days';
        break;
      default:
        typeText = 'سفارشی';
    }
    return '$typeText$endDateText';
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یک‌شنبه';
      case DateTime.monday:
        return 'دو‌شنبه';
      case DateTime.tuesday:
        return 'سه‌شنبه';
      case DateTime.wednesday:
        return 'چهارشنبه';
      case DateTime.thursday:
        return 'پنج‌شنبه';
      case DateTime.friday:
        return 'جمعه';
      default:
        return '';
    }
  }

  void _showRecurrencePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle Line
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Flexible(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedRefresh,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'تنظیمات تکرار',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedCancel01,
                                    size: 22,
                                    color: Colors.grey,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  style: const ButtonStyle(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Options Grid/List
                            _buildRecurrenceOption(
                              RecurrenceType.none,
                              'بدون تکرار',
                              HugeIcons.strokeRoundedCalendarRemove01,
                              setSheetState,
                            ),
                            _buildRecurrenceOption(
                              RecurrenceType.daily,
                              'روزانه',
                              HugeIcons.strokeRoundedCalendar03,
                              setSheetState,
                            ),
                            _buildRecurrenceOption(
                              RecurrenceType.weekly,
                              'هفتگی',
                              HugeIcons.strokeRoundedCalendar01,
                              setSheetState,
                            ),
                            _buildRecurrenceOption(
                              RecurrenceType.monthly,
                              'ماهانه',
                              HugeIcons.strokeRoundedCalendar04,
                              setSheetState,
                            ),
                            _buildRecurrenceOption(
                              RecurrenceType.yearly,
                              'سالانه',
                              HugeIcons.strokeRoundedCalendar02,
                              setSheetState,
                            ),
                            _buildRecurrenceOption(
                              RecurrenceType.specificDays,
                              'روزهای خاص هفته',
                              HugeIcons.strokeRoundedCalendarCheckIn01,
                              setSheetState,
                            ),

                            if (_recurrence?.type ==
                                RecurrenceType.specificDays) ...[
                              const SizedBox(height: 8),
                              _buildSpecifiDaysSelector(setSheetState),
                            ],

                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // End Date Selection
                            InkWell(
                              onTap: () async {
                                final picked = await showPersianDatePicker(
                                  context: context,
                                  initialDate: Jalali.fromDateTime(
                                    _recurrence?.endDate ??
                                        _selectedDate.add(
                                          const Duration(days: 30),
                                        ),
                                  ),
                                  firstDate: Jalali.fromDateTime(_selectedDate),
                                  lastDate: Jalali(1500, 1, 1),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _recurrence = RecurrenceConfig(
                                      type:
                                          _recurrence?.type ??
                                          RecurrenceType.daily,
                                      interval: _recurrence?.interval ?? 1,
                                      daysOfWeek: _recurrence?.daysOfWeek,
                                      specificDates: _recurrence?.specificDates,
                                      dayOfMonth: _recurrence?.dayOfMonth,
                                      endDate: picked.toDateTime(),
                                    );
                                  });
                                  setSheetState(() {});
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedCalendar03,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'تاریخ پایان تکرار',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _recurrence?.endDate != null
                                                ? _formatJalali(
                                                    Jalali.fromDateTime(
                                                      _recurrence!.endDate!,
                                                    ),
                                                  )
                                                : 'نامحدود (همیشگی)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedArrowLeft01,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // Sticky Confirm Button
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Theme.of(context).colorScheme.surface,
                                Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.8),
                                Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0),
                              ],
                              stops: const [0, 0.6, 1.0],
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkSquare04,
                                size: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              label: const Text(
                                'تایید و ثبت تکرار',
                                style: TextStyle(
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
        },
      ),
    );
  }

  Widget _buildSpecifiDaysSelector(StateSetter setSheetState) {
    final days = [
      {'id': DateTime.saturday, 'label': 'ش'},
      {'id': DateTime.sunday, 'label': '۱ش'},
      {'id': DateTime.monday, 'label': '۲ش'},
      {'id': DateTime.tuesday, 'label': '۳ش'},
      {'id': DateTime.wednesday, 'label': '۴ش'},
      {'id': DateTime.thursday, 'label': '۵ش'},
      {'id': DateTime.friday, 'label': 'ج'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((day) {
          final dayId = day['id'] as int;
          final isSelected = _recurrence?.daysOfWeek?.contains(dayId) ?? false;
          return GestureDetector(
            onTap: () {
              setState(() {
                final currentDays = List<int>.from(
                  _recurrence?.daysOfWeek ?? [],
                );
                if (isSelected) {
                  currentDays.remove(dayId);
                } else {
                  currentDays.add(dayId);
                }

                if (currentDays.isEmpty) {
                  // If no days selected, switch to none
                  _recurrence = null;
                } else if (currentDays.length == 7) {
                  _recurrence = RecurrenceConfig(
                    type: RecurrenceType.daily,
                    interval: 1,
                    endDate: _recurrence?.endDate,
                  );
                } else {
                  _recurrence = RecurrenceConfig(
                    type: RecurrenceType.specificDays,
                    daysOfWeek: currentDays,
                    endDate: _recurrence?.endDate,
                  );
                }
              });
              setSheetState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                day['label'] as String,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecurrenceOption(
    RecurrenceType type,
    String label,
    dynamic icon,
    StateSetter setSheetState,
  ) {
    final isSelected = (_recurrence?.type ?? RecurrenceType.none) == type;
    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (type == RecurrenceType.none) {
              _recurrence = null;
            } else {
              _recurrence = RecurrenceConfig(
                type: type,
                interval: 1,
                endDate: _recurrence?.endDate,
                daysOfWeek: type == RecurrenceType.specificDays
                    ? [_selectedDate.weekday]
                    : null,
              );
            }
          });
          setSheetState(() {});
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: color,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReminderPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bool isRecurring = _recurrence != null &&
              _recurrence!.type != RecurrenceType.none;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle Line
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedNotification03,
                          size: 20,
                          color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'تنظیم یادآور',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 22,
                          color: Colors.grey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Permission Warning
                  FutureBuilder<bool>(
                    future: NotificationService().requestPermissions(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data == false) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedAlert02,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'دسترسی اعلان‌ها غیرفعال است. برای دریافت یادآور، لطفا دسترسی را تایید کنید.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await NotificationService().requestPermissions();
                                  setSheetState(() {});
                                },
                                child: const Text('تایید'),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Predefined Options
                  _buildReminderOption(
                    'بدون یادآور',
                    HugeIcons.strokeRoundedNotification01,
                    null,
                    setSheetState,
                  ),

                  if (_hasTime) ...[
                    _buildReminderOption(
                      'در زمان انجام تسک',
                      HugeIcons.strokeRoundedClock01,
                      _selectedDate,
                      setSheetState,
                    ),
                    _buildReminderOption(
                      '۵ دقیقه قبل',
                      HugeIcons.strokeRoundedClock02,
                      _selectedDate.subtract(const Duration(minutes: 5)),
                      setSheetState,
                    ),
                    _buildReminderOption(
                      '۳۰ دقیقه قبل',
                      HugeIcons.strokeRoundedClock05,
                      _selectedDate.subtract(const Duration(minutes: 30)),
                      setSheetState,
                    ),
                    _buildReminderOption(
                      '۱ ساعت قبل',
                      HugeIcons.strokeRoundedClock04,
                      _selectedDate.subtract(const Duration(hours: 1)),
                      setSheetState,
                    ),
                  ],

                  // Time-based options (Morning, Noon, Night)
                  _buildReminderOption(
                    isRecurring
                        ? 'روزهای انجام صبح (۰۹:۰۰)'
                        : 'روز انجام صبح (۰۹:۰۰)',
                    HugeIcons.strokeRoundedSun03,
                    DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      9,
                      0,
                    ),
                    setSheetState,
                  ),
                  _buildReminderOption(
                    isRecurring
                        ? 'روزهای انجام ظهر (۱۳:۰۰)'
                        : 'روز انجام ظهر (۱۳:۰۰)',
                    HugeIcons.strokeRoundedSun01,
                    DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      13,
                      0,
                    ),
                    setSheetState,
                  ),
                  _buildReminderOption(
                    isRecurring
                        ? 'روزهای انجام شب (۲۱:۰۰)'
                        : 'روز انجام شب (۲۱:۰۰)',
                    HugeIcons.strokeRoundedMoon02,
                    DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      21,
                      0,
                    ),
                    setSheetState,
                  ),

                  const Divider(height: 10),

                  // Custom Option
                  InkWell(
                    onTap: () async {
                      final bool isRecurring = _recurrence != null &&
                          _recurrence!.type != RecurrenceType.none;

                      if (isRecurring) {
                        if (!context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            _reminderDateTime ?? _selectedDate,
                          ),
                          builder: (context, child) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: child!,
                          ),
                        );

                        if (pickedTime != null) {
                          if (!context.mounted) return;
                          final finalDateTime = DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );

                          setState(() {
                            _hasReminder = true;
                            _reminderDateTime = finalDateTime;
                          });
                          Navigator.pop(context);
                        }
                      } else {
                        final pickedDate = await showPersianDatePicker(
                          context: context,
                          initialDate: Jalali.fromDateTime(
                            _reminderDateTime ?? _selectedDate,
                          ),
                          firstDate: Jalali.now(),
                          lastDate: Jalali(1500, 1, 1),
                        );

                        if (pickedDate != null) {
                          if (!context.mounted) return;
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              _reminderDateTime ?? _selectedDate,
                            ),
                            builder: (context, child) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: child!,
                            ),
                          );

                          if (pickedTime != null) {
                            if (!context.mounted) return;
                            final finalDateTime = DateTime(
                              pickedDate.toDateTime().year,
                              pickedDate.toDateTime().month,
                              pickedDate.toDateTime().day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );

                            setState(() {
                              _hasReminder = true;
                              _reminderDateTime = finalDateTime;
                            });
                            Navigator.pop(context);
                          }
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: HugeIcon(
                              icon: (_recurrence != null &&
                                      _recurrence!.type != RecurrenceType.none)
                                  ? HugeIcons.strokeRoundedClock01
                                  : HugeIcons.strokeRoundedCalendar03,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_recurrence != null &&
                                          _recurrence!.type != RecurrenceType.none)
                                      ? 'انتخاب دستی ساعت'
                                      : 'انتخاب دستی تاریخ و ساعت',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getReminderSubtitle(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowLeft01,
                            size: 20,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getReminderSubtitle() {
    if (!_hasReminder || _reminderDateTime == null) return 'بدون یادآور';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final reminderDate = DateTime(
      _reminderDateTime!.year,
      _reminderDateTime!.month,
      _reminderDateTime!.day,
    );

    final timeStr = StringUtils.toPersianDigit(
      intl.DateFormat('HH:mm').format(_reminderDateTime!),
    );

    if (reminderDate == today) {
      return 'امروز ساعت $timeStr';
    } else if (reminderDate == tomorrow) {
      return 'فردا ساعت $timeStr';
    } else {
      final jalali = Jalali.fromDateTime(_reminderDateTime!);
      final dateStr = StringUtils.toPersianDigit(
        '${jalali.day} ${jalali.formatter.mN}',
      );
      return '$dateStr ساعت $timeStr';
    }
  }

  Widget _buildReminderOption(
    String label,
    dynamic icon,
    DateTime? dateTime,
    StateSetter setSheetState,
  ) {
    // For "No Reminder", dateTime is null and _hasReminder is false
    final bool isSelected = (dateTime == null && !_hasReminder) ||
        (dateTime != null &&
            _hasReminder &&
            _reminderDateTime?.year == dateTime.year &&
            _reminderDateTime?.month == dateTime.month &&
            _reminderDateTime?.day == dateTime.day &&
            _reminderDateTime?.hour == dateTime.hour &&
            _reminderDateTime?.minute == dateTime.minute);

    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (dateTime == null) {
              _hasReminder = false;
            } else {
              _hasReminder = true;
              _reminderDateTime = dateTime;
            }
          });
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: color,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        _attachments.add(file.path);
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _attachments.add(path);
        });
      }
      setState(() => _isRecording = false);
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      FlowToast.show(
        context,
        message: 'لطفاً عنوان تسک را وارد کنید',
        type: FlowToastType.warning,
      );
      return;
    }

    try {
      final metadata = Map<String, dynamic>.from(widget.task?.metadata ?? {});
      metadata['hasTime'] = _hasTime;

      final task = Task(
        id: widget.task?.id,
        title: _titleController.text,
        description: _descController.text,
        dueDate: _selectedDate,
        endTime: (_hasTime && _hasEndTime) ? _endTime : null,
        priority: _priority,
        categories: _selectedCategories,
        goalIds: _selectedGoals,
        statusHistory: widget.task?.statusHistory,
        createdAt: widget.task?.createdAt,
        updatedAt: widget.task?.updatedAt,
        taskEmoji: _selectedEmoji,
        attachments: _attachments,
        tags: _tags,
        recurrence: _recurrence,
        reminderDateTime: _hasReminder ? _reminderDateTime : null,
        metadata: metadata,
      );

      // Check if reminder is set but permissions are missing
      if (_hasReminder) {
        final notificationService = ref.read(notificationServiceProvider);
        final hasPermission = await notificationService.requestPermissions();
        if (!hasPermission && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('دسترسی به اعلان‌ها'),
              content: const Text(
                'برای ارسال یادآور، نیاز به دسترسی به اعلان‌ها داریم. آیا می‌خواهید تسک بدون یادآور ذخیره شود؟',
                textDirection: TextDirection.rtl,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('خیر، تنظیم دسترسی'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('بله، ذخیره بدون یادآور'),
                ),
              ],
            ),
          );
          
          if (!mounted || proceed == false) return;
        }
      }

      if (task.id == null) {
        final isDuplicated = widget.task != null && widget.task!.id == null;
        await ref
            .read(tasksProvider.notifier)
            .addTask(task, isDuplicate: isDuplicated);
      } else {
        await ref.read(tasksProvider.notifier).updateTask(task);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving task: $e');
      if (mounted) {
        FlowToast.show(
          context,
          message: 'خطا در ذخیره تسک: $e',
          type: FlowToastType.error,
        );
      }
    }
  }
}
